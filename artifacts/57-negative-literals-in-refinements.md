# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

Status of this brief: **evidence and a recommendation. The ticket is not resolved.**
Probes: `artifacts/probes/57/` (`run.sh` rebuilds all five compilers and re-runs everything; outputs in `out/`).
Environment: OTP 25.3 / Elixir 1.14.0 / Gleam 1.12.0 here, OTP 28 in the tickets. `bsc` is built from `compiler/src` plus a lexer shim (OTP 25's `leex` has no `TokenLoc`), so diagnostic **columns are wrong**; checker verdicts are unaffected. Every variant gets the identical shim. Nothing in `compiler/` was edited; each prototype is a patch applied to a copy.

## 0. The ticket's premise, re-measured (base compiler, today's `compiler/src`)

The ticket's table reproduces exactly (`out/base.txt`, rows T1–T5): `value >= -5`, `-5 and 5`, `>= 1 or <= -1` are **refused**; `<= 3 or >= 10` and `!= 0` are accepted.

Two things in the ticket are stale or understated:

1. **The AST is not what the ticket says.** The ticket says unary minus "desugars to a subtraction" `{e_op,'-',{e_int,0},X}`. Today it is `{e_neg, L, E}` (`bs_parser.yrl:591` calls `negate/2`; `:947-948`). `negate/2` **already folds a negated float literal in the parser** (`{e_float,_,F} -> {e_float,_,-F}`, F51) and nothing else. The int case is the one missing line. (probe `ast-shape.sh`: base comparand is `{e_neg,_,{e_int,_,5}}`, 30 words.)
2. **The defect is wider than refinements.** Guards have it too: `F(n) when n >= -5 -> … ; F(n) when n < -5 -> …` is **refused as not exhaustive** on the base compiler (G1), and so is `when n <= -1` beside `when n >= 0` (L3). The same guard with `0` is accepted (G2), and the relational *pattern* `F(<= -1)` is accepted (G3). A third site: `Id(-1)` into a `value != 0` parameter is refused while `Id(1)` is accepted (L1/L2), because `-1` is typed `int`, not the literal. So four consumers read the same `-5`; only the pattern grammar has a rule for it.

## 1. The sub-decisions

1. **Where does the fold live** — the refinement's grammar, the shared expression reduction, or the checker?
2. **How far does it go** — `-5` only, or `2 + 3`, `0 - 5`, `2 * -3`, a named constant?
3. **Do guards and argument typing move with it** (they share the defect), or does the fix stay inside refinements?

Per CLAUDE.md the question is code and compiler delta, so each option is a program plus a patch.

## 2. The B# program

```csharp
module Ledger
type Delta = int where value >= -100 and value <= 100      // refused today: opaque_refinement

public atom Dir(Delta d)
Dir(>= 1)  -> :up
Dir(0)     -> :flat
Dir(<= -1) -> :down            // delete this clause and the residual is `>= -100 and <= -1`

public atom Sign(int n)
Sign(n) when n >= -5 -> :near   // refused today as non-exhaustive (G1), same literal
Sign(n) when n < -5  -> :far
```

Under every option below `Delta` compiles, and deleting the `:down` clause prints `no clause matches: Dir(>= -10 and <= -1)`; pasting that text back as the clause is accepted (probe `residual.sh`, options A1 and B; on the base compiler step 1 cannot even declare the type). Note the residual is printed in pattern form (`>= -10 and <= -1`), not the ticket's `-10..-1`; that form already round-trips.

## 3. Options

All numbers from `out/*.txt` (probe table, 30+ rows incl. the ticket's five verbatim). For every accepted refinement the probe also checks, by exhaustiveness over patterns, that the type did not silently widen to bare `int` (a cover set must be exhaustive, a set missing one boundary value must be refused). **No `WRONG` marker in any variant.**

### Option A — fold in the checker (`comparison/1` reads a constant)

Prototype `optA-a1.patch` (A1: literal and unary minus over a literal; **+9 lines, 1 file** `bs_check.erl`) and `optA-a2.patch` (A2: also `+ - *` over constants; **+17 lines**).

| | base | A1 | A2 |
|---|---|---|---|
| T1–T3 (ticket rows) | refused | accepted, bounds exact | accepted, bounds exact |
| `-5 <= value`, `-0`, `--5`, `-(5)`, `- 5`, `!= -3` | refused | accepted, exact | accepted, exact |
| `2 + 3`, `0 - 5`, `2 * -3` | refused | refused | accepted, exact (≥5, ≥-5, ≥-6) |
| `value >= n` (variable) | refused | refused | refused |
| G1/L3 guards | refused | **accepted** | **accepted** |
| L1 `Id(-1)` into `!= 0` | refused | refused | refused |
| emitted body of `F() -> -5` | `{op,'-',{integer,5}}` | same | same |
| yecc conflicts | 6 s/r | 6 | 6 |
| eunit delta vs base | — | 0 new failures | 0 new failures |

*Strongest counterargument.* The AST keeps a node that means "a literal" and every consumer must remember to look through it: the checker now knows in `comparison/1`, but **argument typing (L1) does not**, so `Id(-1)` stays refused while `Id(1)` is accepted, and the next pass written to read an int literal will repeat this ticket. A2 additionally forces the "where does it stop" question (is `2 + 3` a literal? `1 bsl 3`?) that has no principled stopping point; Erlang's answer is `erl_eval:partial_eval` (below), a general evaluator, which is a large commitment.

### Option B — fold at the shared expression reduction (`negate/2`), the float precedent

Prototype `optB-parser-negate.patch`: **one line in `bs_parser.yrl`**: `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I};` beside the existing float clause. It does **not** narrow the refinement grammar, so a refinement and a guard are still the same `expr` (the property the comment at `bs_parser.yrl:218-221` protects).

| | B |
|---|---|
| T1–T3, `-5 <= value`, `-0`, `--5`, `-(5)`, `- 5`, `!= -3` | accepted, bounds exact |
| `2 + 3`, `0 - 5`, `2 * -3` | refused (not folded) |
| `value >= n` | refused, original `opaque_refinement` text |
| G1/L3 guards | accepted |
| **L1 `Id(-1)` into `!= 0`** | **accepted** (the only option that fixes the argument site) |
| comparand AST size | 23 words vs 30 |
| emitted body of `F() -> -5` | **`{integer,3,-5}`** instead of `{op,3,'-',{integer,3,5}}` (probe `emitted-form.sh`) |
| run-time value, battery of 15 negative-literal expressions (`-5`, `- 5`, `-(5)`, `--5`, `5 - -5`, `-2 * -3 + 1`, `-5 / 2`, `-7 % 3`, `-9223372036854775808`, `-2147483648 - 1`, …) | **identical to base on all 15** (`expr-equivalence.sh`) |
| yecc conflicts | 6 (unchanged) |
| eunit delta vs base | 0 new failures |

*Strongest counterargument.* It changes what **every** `-5` in an expression *is*, not just refinement operands: the emitted Abstract Format differs for every negative literal in a body. The battery shows values unchanged, but values are not the only observable: the eunit suite is the real regression net and **on this host 584-586 of 1448 tests fail on the base compiler** (OTP 25 and the lexer shim), so "0 new failures" is a weak signal: it cannot see anything in those 586. Anyone diffing `.abstr` files across the change (the clean-room handoff compares output) sees a difference. Also `Id(-1)` becoming valid is a behaviour change to another site; I think it is the right behaviour (`-1 != 0`), but it is a decision the ticket did not ask for.

### Option C — narrow the refinement's grammar to `lident op literal` (the ticket's "grammar" answer)

Prototype `optC-narrow-grammar.patch`: **+17 / −2 lines in `bs_parser.yrl`**, replacing `refinement -> expr_low` with dedicated `ref_or/ref_and/ref_cmp/ref_k` rules over `int_lit`.

| | C |
|---|---|
| T1–T3, `-0`, `!= -3` | accepted, exact |
| `-5 <= value` (literal on the left), `--5`, `-(5)`, `2 + 3` etc. | **refused** (`- 5` and `-0` are accepted with exact bounds: the shared `int_lit -> '-' integer` rule at `bs_parser.yrl:472` lexes `- 5` the same way) |
| `value >= n` | refused, but now **`syntax error before: n`**, not the explanatory `opaque_refinement` text |
| G1/L3 guards, L1 | still **refused** (guards are untouched) |
| yecc conflicts | 6 (unchanged) |
| eunit delta | **1 new failure**: `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test` |

*Strongest counterargument* is the ticket's own: it reintroduces the split between a refinement and a guard that the `expr` grammar was chosen to prevent. Measured here: G1 and L3 show a guard still refusing what the refinement now accepts, and the helpful diagnostic for an unreadable predicate degrades to a bare syntax error.

## 4. Neighbour languages (executed where marked)

* **Erlang** (executed `survey/erlang.escript`): the parser does **not** fold. `f(-5)`, `f() -> -5`, and `X >= -5` all parse to `{op,1,'-',{integer,1,5}}`. Folding is downstream: `erl_lint` checks a type range through `erl_eval:partial_eval/1` (`/usr/lib/erlang/lib/stdlib-4.3.1.3/src/erl_lint.erl:3069-3074`), which handles arbitrary constant arithmetic. Type syntax is `type -> prefix_op type` (`erl_parse.yrl:147`), pattern `pat_expr -> prefix_op pat_expr` (`:270`); `erl_eval.erl:1567-1569` normalises `{op,_,'-',{integer,_,I}}`. All of `-5..5`, `-(5)..5`, `(2+3)..10`, `0-5..5`, `2*-3..5`, `(1 bsl 3)..10` were accepted as `-type`. That is the Option A2 shape, with a general evaluator rather than +17 lines.
* **Elixir** (executed `survey/elixir.exs`): `-5`, `- 5` and `-(5)` all give `{:-, [line: 1], [5]}` in expression, guard and pattern position; `2 + 3` stays `{:+,…}`. Parser folds nothing; consumers do. `--5` is a `SyntaxError` (`--` is list subtract). Elixir's `elixir_parser.yrl` is not installed here, so no file:line.
* **Gleam** (executed; compiled by `gleam 1.12.0`, `survey/gleam.emitted.erl`): the pattern `-5` and the expression `-5` both emit `-5`; `--5` emits `- -5` (so the emitted Erlang for a single negative literal is `-5` and for `--5` is `- -5`; that output cannot tell whether Gleam folds in its parser or merely prints a unary minus, and it does not fold double negation). Gleam's own parser source was **not** fetched, so no file:line; the claim is about emitted output only.
* **Elm**: **not executed**. `elm make` could not load the package list (`package.elm-lang.org` 403, `survey/elm.out`). Nothing is claimed.

Reading: Erlang and Elixir keep the node and fold later (Option A shape). Gleam's output is not evidence either way, and neither neighbour is evidence for narrowing a predicate grammar (Option C).

## 5. Measured cost

* **Parse time** (`cost.sh`; module of 8 refinements, parse only, min of 7 rounds × 400): base 8.44, A1 7.19, A2 6.55, B 7.37, C 7.48 µs/iter. A1/A2/base run the **identical parser** yet differ by 29%, so the noise floor is larger than any difference between options. **No parse-time cost is claimed for any option.**
* **AST size** (`:erts_debug.flat_size`): comparand 30 → 23 words (B), 20 words (C; its literal carries line `0`); whole module 106 → 99 / 96.
* **Compiler delta**: A1 +9, A2 +17 (one file, `bs_check.erl`); B +1 (`bs_parser.yrl`); C +17/−2 (`bs_parser.yrl`).
* **BEAM**: none of the options changes the loaded module except B's literal form, which compiles to the same code (identical answers on the 15-expression battery).

## 6. Recommendation

**Option B.** One line, beside the float line that already exists in the same function, fixes all four consumers (refinement, guard exhaustiveness, argument typing, residual round-trip) by making `-5` a literal at the one place the grammar already treats a negated float as a literal, and keeps the single `expr` grammar the ticket wants kept. Do not fold arithmetic (A2); `2 + 3` stays refused until someone writes a program that needs it.

If David prefers the `.abstr` of existing programs not to move, take **A1** and accept that `Id(-1)` into `!= 0` stays refused (open a separate ticket for argument typing). Reject C: the measurements show it leaves guards broken and worsens a diagnostic.

Decision for David, as code: does this program compile?

```csharp
type Nz = int where value != 0
public int Id(Nz b)
public int Go()
Id(b) -> b
Go()  -> Id(-1)      // B: yes. A: no. C: no.
```

## 7. What is not measured / how this could mislead

* OTP 28 behaviour; the absolute timings.
* The repo's eunit suite is **mostly red on this host** (584-586 of 1448 on base across two runs), so "no new failures" for A and B is weak evidence. A full green baseline on OTP 28 should be rerun before adopting anything.
* `value == -3` and `value == 3` both report `compile: … bad range type` from `erlc` on OTP 25 (a singleton range in the emitted `-spec`; confirmed that the positive case behaves identically). The probe reports these as `accepted-by-checker(erlc-OTP25-singleton-range)`. I believe OTP 26+ accepts it but have not run it.
* The prototypes are mine, so "accepted" proves the patch does what I wrote; the controls (T4, T5, E11, the semantic cover/short checks) are what make the rows meaningful. The probe table's first five rows are the ticket's own.
* Elm unexecuted; Gleam and Elixir parser source not read.

## Independent verification (separate agent, rebuilt all five variants from the patches)

Verdict: **sound with caveats.** Reproduced: the ticket's five rows verbatim against the unpatched compiler (T1-T3 refused with the genuine `opaque_refinement` text); the per-option tables; 6 shift/reduce conflicts on base and on every variant; residual round-trip; AST sizes; the emitted-form difference (only option B changes it). Exact bounds were checked at run time (`value >= -5`: -6 crashes with `function_clause`, -5 and 0 pass). Mutations behaved as predicted (B mutated to `-I + 1` gave 8 WRONG markers; A1 with the negation dropped gave 6; removing B's one line reverted every row). The ticket's stale premise is confirmed: `bs_parser.yrl:591`/`:947-948` produce `{e_neg,_,{e_int,_,5}}`, not a subtraction.

Corrections applied above: option C does **not** refuse `- 5`/`-0`; one cite moved from `bs_check.erl` to `bs_parser.yrl:218-221`; the base eunit failure count is 584-586, not exactly 586.

Caveats: `value == -3` is accepted by the checker only (`erlc` on OTP 25 rejects the singleton range) and has no cover/short check; about 40% of eunit is red on base here, so "no new failures" for A/B is weak; the prototypes are the author's, so independence rests on the 38b control rows, the run-time bound checks and the mutations; Elm not run, Gleam/Elixir rows are executed output without parser-source citations; option B also flips `Id(-1)` from refused to accepted, a behaviour change the ticket did not ask about.
