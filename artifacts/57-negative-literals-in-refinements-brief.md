# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

Status: **decision left open for review.** Nothing was resolved, claimed or edited in `wayfinder/` or `compiler/`.
Prepared 2026-10-08 by a scheduled run. Probes: `artifacts/probes/57/`. Patches: `artifacts/probes/57/patches/`.

## The question, restated

Where does the fold of `-5` belong — **parser** or **checker** — so that `type Delta = int where value >= -100 and value <= 100` can be written?

## Stale premises (the ticket describes a compiler that no longer exists)

1. The ticket says `-5` reaches the checker as `{e_op,'-',{e_int,0},{e_int,5}}`. **Since F51 (2026-09-16) unary minus is its own node `e_neg`** (comment at `bs_parser.yrl:587-591`, rule at 592, `negate/2` at `bs_parser.yrl:946-947`). The refusal reproduces unchanged, but the mechanism differs.
2. **The parser already folds one negation.** `negate(_L, {e_float, FL, F}) -> {e_float, FL, -F}` (`bs_parser.yrl:946`) folds a negated *float* literal "so `Sign(-1.5)` is a head" (F51 §finding 2). So "fold in the grammar" is not a new principle for this compiler; it is the existing rule applied to ints, which F51 left out.
3. **The ticket's option 1 (narrow the grammar only at the refinement site) is not what the code offers.** `refinement -> expr_low` (`bs_parser.yrl:221`) shares the expression grammar with guards. Any parser fold therefore happens for every expression, not only refinements. This is the real shape of "the grammar" option and it is a one-clause change.

## Finding the ticket did not have (this changes the decision)

**A negative literal is typed `int`, not `-5`, so a signed refined parameter cannot be called with a negative literal even if the declaration is fixed.** `type_of({e_neg,…})` returns `bs_types:int()` for any numeric operand (`bs_check.erl:2882-2893`; the `e_int` clause above it returns a point range). Measured (probe `matrix.sh`, `RefNegAdmits`): with the *checker-only* fold, `type T = int where value >= -5` compiles, but `Id(-5)` is refused with `argument 1 is not covered by Id's declared type: int <= -6`. The refinement becomes writable and unusable at the same time.

## Sub-decisions, in gating order

1. **Is `-<int literal>` a literal (one token's worth of meaning) or an operation on one?** Gates everything. F51 already answered it for floats (a literal). Decide for ints.
2. *Follows:* how far folding goes — only `-N`, or arithmetic over literals (`2 + 3`, `0 - 5`)?
3. *Follows:* does the interval algebra type `-x` precisely (`x: 1..3` ⇒ `-3..-1`)? Out of scope here; ticket 20 owns the algebra.

## Options (each is a compiler delta plus a program)

The program is the same for all three:

```csharp
module Delta
type Delta = int where value >= -100 and value <= 100
public int Id(Delta d)
Id(d) -> d
public int Ok()  -> Id(-100)     // must compile
public int Bad() -> Id(-101)     // must be refused
public atom S(int n)             // guard form of the same literal
S(n) when n >= -5 -> :a
S(n) when n < -5  -> :b          // exhaustive, no catch-all
```

### Option A — fold in the parser: `negate/2` also folds `{e_int}` (1 line)

Compiler delta: one clause in `bs_parser.yrl`, beside the float one:
`negate(_L, {e_int, IL, N}) -> {e_int, IL, -N}.` (`patches/A-parser.patch`, 10 diff lines including context).

Evidence (`matrix.sh`, `shape.sh`):
- Declaration, call site and guard all work: `RefNegGe`, `RefNegRange`, `RefNegAdmits`, `GuardNegExh` accepted; `RefNegExcludes` (`Id(-9)` into `>= -5`) is refused with `-9 is not covered` **on A and D only** (on base it is refused because the refinement is unreadable, on B/C because `-9` types as `int`), so it shows A and D do not silently widen. `NegArgToNonNeg` (`Id(-5)` into `>= 0`) is refused on every build including base, so it is a control, not evidence for A.
- Unit suite, 1326 tests on OTP 25: 466–467 fail on the unmodified compiler (the author's run had one extra, `modules_tests:a_fully_qualified_call_needs_no_unqualified_scope_test`; the verifier's did not) (environment: `maps:iterator/2` is OTP 26+, lexer shim), **the same failures occur with A**; set difference empty (`comm` of sorted failure names).
- Emitted form: `K() -> -5` changes from `{op,_,'-',{integer,_,5}}` to `{integer,_,-5}` (`shape.out`). Both are valid Erlang abstract format; the second needs no run-time or compile-time negation.
- Compile time: 400–560 ms per run, dominated by VM boot; A and base ranges overlap (`shape.out`). No measurable cost.

Strongest counterargument: **CLAUDE.md-level principle, from the ticket's own text** — a refinement is deliberately an `expr` so a refinement and a guard cannot disagree about meaning. A parser fold keeps that (both see `e_int -5`), but it does mean `-5` can no longer be told apart from `5` negated in diagnostics or source-faithful tooling (the LSP/formatter would have to read the token, not the node), and `x - -5` prints the literal as `-5`. The same cost was already paid for floats.

### Option B — fold in the checker, two sites (`comparison/1` and `type_of/3`)

Compiler delta: `comparison/1` (`bs_check.erl:4960`) reads `{e_neg,_,{e_int,_,K}}` as `-K` on either side of the comparison, **and** `type_of({e_neg,_,{e_int,_,N}})` returns the point range `-N` (`patches/B-check.patch` is the checker fold alone; `patches/D-check.patch` is B plus the typing clause and is a complete diff against `compiler/src`; "D" in the probe output).

Evidence:
- Checker fold alone (variant B) fixes declarations and guards but **fails** `RefNegAdmits` (`Id(-5)` refused). With the typing clause (variant D) the whole matrix matches A.
- Unit suite with D: same failure set as baseline, none new.
- Emitted form unchanged (`{op,'-',{integer,5}}`), which is Option B's selling point for tooling that wants the node.

Strongest counterargument: it is two folds in two places that must agree forever (the guard reader and the expression typer), where the parser fold is one. The ticket asked "where does the fold belong" — this measures that a checker fold needs *two* homes, and the second one was invisible until the call-site probe.

### Option C — checker folds literal arithmetic (`+ - *`, `e_neg`) in `comparison/1`

Compiler delta: a `cfold/1` helper (~6 lines) plus a `comparison/1` clause (`patches/C-check.patch`).

Evidence: `RefSumFold` (`value >= 2 + 3`) accepted, which A and D still refuse. **First attempt regressed** `string_literal_type_tests:a_guard_comparing_a_literal_closes_test` (a defect in my prototype: the clause shadowed the `e_str`/`e_atom` clauses); fixed by restricting to `e_op`/`e_neg` right-hand sides, after which the failure set equals the baseline. It still inherits B's call-site gap (`RefNegAdmits` refused).

Strongest counterargument: the ticket itself asks "where does it stop: `-5` certainly, `2 + 3` probably, `value >= n` never." Nothing here measured demand for `2 + 3` in a refinement; folding it invites `1 <<< 4`, `2 * 8`, and constants by name, i.e. a constant evaluator, which belongs with ticket 20's algebra rather than a bug fix.

## Neighbours (executed, not recalled)

| Language | Result | Source |
|---|---|---|
| Erlang/OTP 25 | Parser keeps `-5` as an op node in expressions, guards **and patterns**: `f(-5) -> a` parses to `{op,1,'-',{integer,1,5}}`; folding happens later (`erl_parse:normalise/1` at `erl_parse.yrl` normalise clauses `-> -I`, `erl_lint` calls `erl_eval:partial_eval` on an expression at `erl_lint.erl:1886`; lines 1997 and 2051 are bit-size checks and are not evidence here) | `probes/57/neighbours_erlang.out`; `/usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_parse.yrl:240,270`, `…/erl_lint.erl:1886` |
| Elixir 1.14 | `x >= -5` quotes to `{:>=, _, [x, {:-, _, [5]}]}`: operator node kept; a `defguard` with `>= -5` works at run time (`{:in, :out}` for -5 / -6) | `probes/57/neighbours_elixir.exs`, `.out` |
| Elm 0.19 | **Not executed** — the compiler binary runs but `elm make` needs package downloads, blocked by egress policy | — |
| Gleam | **Not installed**, cannot be (github/hex blocked) — no claim made | — |

Reading: both executable BEAM neighbours keep the op node at the parser and fold downstream, i.e. they sit nearer Option B. That is evidence about convention, not about cost, and B is the option that needs a second site in B#.

## Recommendation

**Option A.** It is a single clause, repeats a fold the parser already performs for floats, fixes declaration, call site and guard in one place, widens nothing (refusals measured), and leaves the existing test results unchanged. Take C's `2 + 3` question out of this ticket and attach it to ticket 20.

If the reviewer prefers the neighbours' convention (keep the op node), Option B is viable **only with its typing clause**; the ticket's own text understated that cost.

## Not measured / could not run

- **Toolchain is OTP 25, repo pins OTP 28.** Built by hand with a lexer shim (`TokenLoc → {TokenLine,1}`); diagnostic columns are wrong, parser/checker/emitter behaviour is unchanged. The ~467 baseline unit-suite failures are an artefact of this. `rebar3` could not run, so `./bin/verify.sh` and the gates were **not** run; none of A/B/C is gate-clean.
- Elm and Gleam behaviour (see above).
- No `-x` interval precision (sub-decision 3) and no non-literal consts.
- Call-time cost is nil for all options (nothing emitted differs except A's literal form), so none was measured.

## Reproduce

```
cd artifacts/probes/57 && ./matrix.sh           # BUILDS="base A D" ./matrix.sh to narrow
./shape.sh; elixir neighbours_elixir.exs
```
Variants are scratch builds `/tmp/bsb_{A,B,C,D}` made by applying `patches/*` to `compiler/src` and rebuilding (see `artifacts/BUILD-NOTE.md`).
