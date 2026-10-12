# Decision brief: ticket 57, negative literals in refinements (ENG-239)

**DRAFT FOR HUMAN REVIEW. Ticket remains open.** Nothing was resolved, committed or sent to Linear.
Prototypes were built from patches against a *copy* of `compiler/`; the tree is untouched.
Date of runs: 2026-10-12 (ticket dated 2026-08-23). Probes live in `artifacts/probes/57-NN/`
(`run.sh` + `out.txt`); each rebuilds what it needs from a clean shell with only `env.sh` sourced.

## 0. The ticket is partly stale. Read this first.

| Ticket claim | Now |
|---|---|
| `-5` reaches the checker as `{e_op,'-',{e_int,0},{e_int,5}}` ("desugars to a subtraction") | **Stale.** F51 (done 2026-09-16, `compiler/features/F51-float.md` finding 2) made it its own node: `{e_neg, L, {e_int,L,5}}`. `bs_parser.yrl:591` `expr_low -> '-' expr_low : negate(...)`; `bs_parser.yrl:947-948` `negate/2` already **folds a negated float literal** into the literal and leaves everything else `e_neg`. |
| `value >= -5` and every refinement with a negative literal is refused | **Still true.** `57-01/out.txt`: `RGeNeg`, `RBoth`, `ROrNeg`, `RFlip`, `RParen` all refused; `ROrPos`, `RNe0` accepted. `38b_divisor_expressiveness.sh` still reports "all 7 probes matched expectation". |
| Only refinements are affected | **Understated.** `refine/3` (`bs_check.erl:1909`) and `apply_guard/3` share `alternatives/1` (`bs_check.erl:4998-5014`) and `comparison/1` (`:5016`). A *guard* `S(n) when n <= -1 -> :neg` is silently given no coverage credit, and the clause set is reported non-exhaustive with the residual `S(<= -1)` (`57-01` `GNeg`). Same defect: the message asks for what was just written. |
| The surface cannot spell a signed domain | **True, and there is no other door.** `type S = -5..5` and `type S = -1 \| 0 \| 1` are syntax errors (`57-02` `TyRange`, `TyLitUnion`). |
| Doing nothing is harmless | **Not quite.** The *expression* `-5` is typed `int`, not `-5..-5` (`bs_check.erl:2889`, `e_neg` branch returns `bs_types:int()`; `:2882` `e_int` returns `range(N,N)`). So `type NonPos = int where value <= 0` + `F() -> -5` is refused today with "not covered: int >= 1" (`57-02` `RetNegLit`). A signed domain would be writable but a literal could not inhabit it. |

## 1. Sub-decisions and the gating one

1. **(gating)** Where does a literal `-N` become a constant: when the parser builds it, or when each consumer reads it?
2. How far a *checker* fold goes (`-5` only / `+ - *` / also `/ %`). Follows from 1 only if the answer to 1 is "checker".
3. Whether the expression `-5` should type as the singleton `-5..-5` (follows from 1: it does iff the fold is in the parser).
4. Whether guards are in scope (they are the same function; follows from 1, no separate choice).

## 2. Gating question, stated alone

> Should `-5` be **one literal node from the parser on** (as `-5.0` already is, and as a pattern's `int_lit` already is), or stay `e_neg(5)` for every consumer to learn to read?

The ticket frames "grammar" as *narrowing the refinement rule* to literals. That is a different thing from
folding in `negate/2`; the refinement stays `refinement -> expr_low` (`bs_parser.yrl:221`) and keeps its
guarantee that it and a guard read the same expression.

## 3. Options

### A. Fold in the parser's `negate/2` (the float precedent, extended to integers)

```csharp
type Delta = int where value >= -100 and value <= 100   // compiles
public Delta Nudge(Delta d)
Nudge(d) -> d
public Delta Go()
Go() -> Nudge(-3)                                       // compiles; -300 is refused as it should be
public atom Sign(int n)
Sign(n) when n <= -1 -> :neg                            // guard now credits coverage
Sign(n) when n >= 0  -> :nonneg
```

Compiler delta: **one clause**, `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I};` beside `bs_parser.yrl:947`
(`57-04/A-parser-fold.patch`, 1 line). No checker, emitter or diagnostic change.

Measured (`57-04/out.txt`, `57-08/out.txt`):
* All refinement forms with `-N`, flipped operands, parens and `- -5` accepted; `GNeg` accepted; `RetNeg` accepted.
* `Delta` + `Go() -> Nudge(-3)` accepted, `Nudge(-300)` refused "hands F an argument it does not accept". Only A does this (see B).
* Residual for `S(>= 1), S(0)` over `Delta` prints `S(>= -100 and <= -1)`, and adding `S(<= -1) -> ...` makes it compile: the residual doctrine round-trips.
* Emitted Code chunk for bodies using `-5` has the **identical md5** to baseline (`4ABB3E92...`); runtime values of `-7/2`, `-7%3`, `-2*3`, `- -4`, `10 - -5`, `-(7)/2` identical (`-3 -1 -6 4 15 -3`).
* All 22 shipped examples (`compiler/examples/*`) give byte-identical compiler output and exit 0 (two of them, `Ledger`, `Frame`, contain negative literal expressions).
* Compile time unchanged within noise (`57-05`: 40-clause module, 9 runs, min/median 478/500 ms vs baseline 398/505 ms).

Strongest counterargument: it changes the **expression** grammar's output for every program, not just refinements: `-5` now types as `-5..-5` instead of `int`, which could shift an inference or message somewhere the 22 examples and a few hand cases do not reach. The eunit suite (`compiler/test`) was **not** run against A. It also cannot ever grow into `2 + 3` (that is a separate, later fold).

### B. Fold in the checker, `-N` only (`comparison/1` accepts `{e_neg,_,{e_int,_,K}}`)

Same B# as A for refinements and guards. Compiler delta: ~8 lines in `bs_check.erl` (`57-04/B-checker-fold.patch`: a `const_b/1` helper and two reshaped `comparison/1` heads).

Measured: refinements `-N` and the guard accepted (same table as A) but
`DeltaOk` (`Go() -> Nudge(-3)`) and `RetNeg` are **refused** ("G hands F an argument it does not accept"). A signed
domain is declarable yet unusable with a literal until `type_of/3` at `bs_check.erl:2889` also learns the same fold,
i.e. the fold is then written twice. `- -5` stays refused.

Strongest counterargument: it keeps the grammar single-meaning with respect to what the parser promises ("unary minus is a node"), and it is the shape the ticket's own text prefers. If a second consumer needs it, `const_int/1` is the single place to grow.

### C. Fold in the checker, constant arithmetic (`+ - *` and unary `-` over literals)

```csharp
type Pct = int where value >= 0 and value <= 10 * 10
Sign(n) when n <= 2 + 3 -> :lo
```

Compiler delta: B plus a recursive `const_c/1` over `e_op` (`57-04/C-checker-fold.patch`, ~14 lines).

Measured: `RSum`, `RSumNeg`, `RProd`, `GSum` accepted (they are refused under A and B); `/ % ` and a variable (`RDiv`, `RVar`) still refused; same `DeltaOk`/`RetNeg` **refusals** as B. Compile time within noise.

Strongest counterargument: nothing in the repo asks for it. No exemplar or ticket needs `2 + 3` as a bound, it invites the "where does it stop" question (`/` truncation, overflow, `%` of negatives, `**`), and it widens what the refinement surface promises before the algebra ticket (20) has said what a bound is.

## 4. What the neighbours do (all citations opened or runs executed)

| Language | `-5` AST | Where the fold lives | Evidence |
|---|---|---|---|
| Erlang | `{op,1,'-',{integer,1,5}}`, parser does **not** fold; `-5.0` also `op` | Consumers: `erl_eval:partial_eval/1` (`{op,'-',5}` gives `{integer,1,-5}`, `2+3` gives `5`), called from `v3_core.erl:2639` (patterns), `erl_lint.erl:2140` (`is_pattern_expr`), bit sizes; `erl_parse.yrl:1815-1820` `normalise` special-cases unary +/- over literals. Pattern `f(2+3)` compiles and matches 5; abstract code after lint still holds the `op` | `57-06/out.txt` |
| Elixir | `{:-, [line: 1], [5]}`; `2+3` is `{:+,_,[2,3]}`; no fold in the parser | Per consumer: `Kernel.Typespec` special-cases exactly unary `+/-` over an integer (`typespec.ex:748`) and `validate_range` re-reads `{:op,_,:-,{:integer,..}}` (`:997`, `:1001`); `1+1..5` is not folded. Guard `x >= -5 and x <= 2*3` works at runtime; pattern `f(2+3)` is a compile error ("cannot invoke remote function :erlang.+/2 inside a match") | `57-06/out.txt` |
| Gleam 1.19.0 | (not inspectable: no source installed) | **Run only:** pattern `-1` ok, guard `n >= -5` ok, `const c = -5` ok, guard `n == 2 + 3` ok, but guard `n == -y` is a syntax error and pattern `2 + 3` is a syntax error, `const c = 2 + 3` "Unsupported operator in constant expression". Behaviour is consistent with a literal-only negative number, not a general negation | `57-07/out.txt` |
| Elm 0.19.2 | **Could not be run.** `elm make` needs `package.elm-lang.org` (HTTP 403 via proxy); even with `elm/core` cloned from github it asks for the registry | The attempt is recorded in `57-07/out.txt`. Elm facts below are knowledge-only | n/a |
| C# / F# | knowledge-only, unverified here | C#: `-5` is a constant expression the compiler folds; relational patterns `<= -1` and `case 2+3:` both legal because constant expressions are evaluated. F#: literal patterns take `-1`; `[<Literal>]` values may be computed | n/a |

Reading: no neighbour folds *in the parser* except Gleam (probably) and B#'s own float rule; the BEAM languages fold
in the consumer, and **Elixir's typespec fold is literal-minus only** (precedent for B). B# differs from Erlang/Elixir
in that its refinement and guard are one checker-side reader of a *type*-forming expression, and
`type_of` is a second reader, which is the argument for A.

## 5. Recommendation

**Option A.** Gating answer: the fold belongs at `negate/2`, for integer *literals only*, extending the rule F51 already
wrote for floats (`bs_parser.yrl:944-948`: "A negated float LITERAL folds to the literal").

1. It is the only variant that makes the new signed domain *usable*: `Go() -> Nudge(-3)` and `F() -> -5 : NonPos` need `type_of` to see a constant, and A gives that for free (`57-04` `DeltaOk`, `RetNeg`: accepted under A, refused under B and C).
2. It repairs refinements, guards and typing with one line, instead of one reader per consumer.
3. It does not narrow the refinement grammar (`refinement -> expr_low` is unchanged), so the ticket's stated worry about a refinement/guard split does not arise; it is the parser's own existing precedent for the float literal.
4. Observed risk is nil on what was run: identical machine code, identical values, 22/22 examples unchanged.

Sub-decision 2 (constant arithmetic, `2 + 3`) should **not** ride with this ticket: nothing needs it, and it is a separate
question to be asked alone only if a program wants it. The brief's C measurements show it costs ~14 lines when someone does.

If the human prefers to keep unary minus a node everywhere, B is the fallback, but then `type_of` must be changed in
the same patch or the signed domain cannot be given a literal.

## 6. Not decided or not measured

* The compiler eunit/verify suite was **not** run on any variant (ticket CLAUDE.md says a clean-checkout pair is ~13 min). Only compile verdicts for 22 examples, 18 hand cases and runtime values.
* `Sign(-1.5)`/float behaviour is unchanged by construction (A touches only `e_int`); not separately probed.
* Whether `-5` typing as the singleton changes any diagnostic *text* in the tour/handoff docs was not checked (examples only).
* `- 2 ** n` or similar higher-precedence forms: the fold fires only when the operand is already a bare literal, so `-7/2` parses as `-(7/2)` and is untouched (values identical, `57-08`); parse-tree shape for other operators not enumerated.
* Elm: not run. C#/F#: knowledge only.
* Residual spelling `S(>= -100 and <= -1)` is accepted back as a clause set (`57-04`), but I did not probe every residual shape (unions, `neg_inf` bounds).
* Incidental, **not this ticket**: a singleton refinement (`value == 5`, or `>= 5 and <= 5`) dies in the emitter with `compile: ...: bad range type` at line 0 (`57-03/out.txt`); `value >= 5 and <= 6` is fine. Worth its own ticket if no existing one covers it (I did not grep every ticket for it).

## 7. Probe index

| Probe | Claim checked | Result |
|---|---|---|
| `probes/57-01/run.sh` | Ticket repro still fails; flipped/paren/arith forms; guards share the defect | Refused for every `-N` and arithmetic form; `value <= 3 or >= 10`, `!= 0` accepted; guard `n <= -1` not exhaustive; pattern `<= -1` accepted |
| `probes/57-02/run.sh` | Expression `-5` is typed `int`; no other syntax names a signed domain | `F() -> -5 : NonPos` refused ("int >= 1"); `-5..5` and `-1 \| 0 \| 1` are syntax errors |
| `probes/57-03/run.sh` | (incidental) singleton refinement | `bad range type` crash for `== 5` and `>=5 and <=5`; two-value range fine |
| `probes/57-04/run.sh` + 3 patches | A/B/C behaviour on 18 cases, residual printing, identical Code chunk | A accepts all `-N`; `DeltaOk`/`RetNeg` pass only under A; C adds `+ - *`; residual `S(>= -100 and <= -1)` round-trips; md5 equal |
| `probes/57-05/run.sh` | Compile time of 40-clause module, 9 runs | base 398/505, A 478/500, C 415/471 ms (min/median): noise. Baseline refuses the signed source in ~250 ms (not comparable) |
| `probes/57-06/run.sh` | AST of `-5` and `2+3` in Erlang and Elixir; where each folds | Both parse to an op node; Erlang folds in `erl_eval:partial_eval`; Elixir typespec special-cases unary minus; Elixir pattern `2+3` refused |
| `probes/57-07/run.sh` | Gleam negative literals/arith in patterns, guards, consts; Elm attempt | Gleam: executed. Elm: **not runnable** (registry 403), outcome recorded |
| `probes/57-08/run.sh` | Does A alter any shipped example or runtime value | 22/22 identical output; runtime values identical |
