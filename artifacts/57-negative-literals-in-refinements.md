# Ticket 57 / ENG-239 — decision brief: `value >= -5`

Not a resolution. Nothing outside `artifacts/` was edited. Probes: `artifacts/probes/57/` (`./run.sh`
rebuilds everything from `compiler/src` plus three patched copies, `out/*.out` is the capture).
Measured 2026-10-03 on OTP 29 (the repo pins 28.5), hand-built because rebar3 is broken here.
**PROTOTYPE** marks anything run against a patched copy of `compiler/src`, never the real tree.

## What the probes changed about the question

The ticket asks *grammar or checker*. Three things it does not say, each measured:

1. **The ticket's mechanism is stale.** `-5` is no longer `{e_op,'-',{e_int,0},{e_int,5}}`; F51 made
   it `{e_neg,L,{e_int,L,5}}` (`out/ast.out`; `bs_parser.yrl:589,944`). `negate/2` already folds a
   negated **float** literal to the literal (`:944`) and not an int. That asymmetry is the whole
   defect.
2. **The defect is not only in refinements.** `alternatives/1` is shared (`bs_check.erl:4943`), so a
   *guard* `n >= -5` is unreadable too and credits nothing: residual of `F(n) when n >= -5` is
   `F(n)`, against `F(<= -6)` for the pattern `F(>= -5)` and `F(<= 4)` for `when n >= 5`
   (`out/table.out`, baseline "what the guard credits").
3. **And in bodies.** `type_of({e_neg,..})` answers plain `int` (`bs_check.erl:2874`), where
   `e_int` answers the point type (`:2867`). So a writable signed type is still not *constructible*.
   This fails **today, with no signed refinement at all**:

```csharp
type Nz = int where value != 0
public Nz Neg()
Neg() -> -5          // error: Neg returns a value its signature does not declare
                     //        not covered by the declared return type: 0
public Nz Pos()
Pos() -> 5           // fine
```
(`out/literal_use.out`, BASELINE last rows. The message blames `0` because `-5` was typed `int`.)

The ticket's own table reproduces exactly: all five rows match, and `38b` matches 7/7
(`out/table.out`, `out/38b_shim_base.out`). `38b` as shipped does not run here — it shells out to
rebar3 and exits silently (`out/38b_as_is.out`); the shim changes only the two lines that locate the
compiler.

## The gating question, asked alone

**Is `-5` a literal or an operation?** Everything else in the ticket follows from it (see
*Follows*). One program, compiling under one answer and refused under the other:

```csharp
type Delta = int where value >= -10 and value <= 10

public Delta Low()
Low() -> -5                          // literal: fine.  operation: "returns a value it does not declare"

public atom Band(int n)
Band(n) when n >= -5  -> :near
Band(n) when n <  -5  -> :far        // literal: exhaustive.  operation: "Band is not exhaustive"
```

The answer the grammar already gives for patterns (`int_lit -> '-' integer`, `:470`) and for floats
(`:944`) is *literal*. The ticket's two branches both answer *operation* and then paper over it at
one reader.

## Option 1 — literal, in `negate/2` (the one-clause fix; not either of the ticket's branches)

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int,   IL, I}) -> {e_int,   IL, -I};     %% the whole change  (PROTOTYPE C)
negate(L, E)                 -> {e_neg, L, E}.
```
Compiler delta: one clause, `bs_parser.yrl:945`. No new rule, no checker edit. AST before/after for
`value >= -5`: `{e_neg,_,{e_int,_,5}}` → `{e_int,_,-5}`; `--5` → `{e_int,_,5}`; `-n` stays `e_neg`.

Measured (PROTOTYPE C): every literal form in the table accepted — `-5`, `- 5`, `(-5)`, `-(5)`, `--5`,
`-0`, `-5 <= value`, `!= -3`, the 32-bit span. Guards agree (G1, G2, G4, G5 accepted; guard residual
`F(<= -6)` = the pattern's). Bodies work (`Low() -> -5` accepted; `-50` still refused as outside
the domain). Bonus: `x / -0` is now refused by ticket 38's provably-zero rule; today it compiles
(`-0` was typed `int`). yecc: **6 shift/reduce before and after**; 226 precedence-resolved before
and after. Unit modules: **zero new failures** over 65 modules (`out_eunit/`). Compile time: no
difference outside noise (below).

Strongest counterargument: **it reads nothing but the literal.** `value >= 2 + 3`, `value >= 0 - 5`,
`value >= -5 + 1`, `value >= (2 + 3) * 4` are all still refused (table rows 12–14, 20) with the
very message that recommends "comparisons on `value`" — the exact shape the ticket calls a defect.
A reader who writes `value >= 60 * 60` for seconds-per-hour hits it. Answer on the evidence: this
compiler gives arithmetic no precise type anywhere — `Take(2 + 3)` against a `>= 5` parameter is
refused on **every** build including baseline (`literal_use.out`, last row) — so refusing it in a
refinement is consistent, and nothing in the repo's six refinements uses arithmetic
(`grep -rn "where value" --include=*.bs`). It would be a second ticket on its first real program.

## Option 2 — fold in the checker (the ticket's second branch)

```erlang
comparison({e_op,_,Op,{e_var,_,V},R}) -> case const(R) of {ok,K} -> int_cmp(Op,V,K); error -> unknown end;
const({e_int,_,K}) -> {ok,K};  const({e_neg,_,E}) -> negate(const(E));
const({e_op,_,Op,A,B}) when Op =:= '+'; Op =:= '-'; Op =:= '*' -> ...;   const(_) -> error.
```
Compiler delta: `const/1` (~8 lines) behind `comparison/1`, `bs_check.erl:4949`. Stops at `+ - *` and
unary minus: `/` and `%` are excluded because ticket 38 made `/` truncating division with a zero
precondition, and a fold would need to decide both.

Measured (PROTOTYPE B): table accepted for every refinement row Option 1 accepts, **plus** `2 + 3`,
`0 - 5`, `-5 + 1`, `(2 + 3) * 4`. Guards agree. yecc 6/6, 226. Zero new unit failures.
**But `literal_use.out` is red:** `Low() -> -5` refused, `Take(-5)` refused (an argument that is a
member of `Delta`), `-0` refused. `Delta` is declarable and no program can hand one over. Closing
that means a second fold in `type_of`, which is Option 1's literal made twice. Folding `2 + 3`
in a refinement while `Take(2 + 3)` is refused is a half-consistent language.

Strongest counterargument (for it): it is what Erlang does. The parser never folds: `-5` is
`{op,'-',{integer,5}}` in pattern, guard and expression alike, and `erl_lint` decides legality
afterwards with `erl_eval:partial_eval` (`-(2+3)*4` → `{integer,-20}`, `neighbours/erlang.out`;
`erl_lint.erl:2431-2480`), and `LANGUAGE.md:3337` says a refinement is "a single BEAM guard". It
also keeps the AST true to the source, which F51 chose on purpose for `-0.0` and float mixing.
UNMEASURED: a B+ that also teaches `type_of` the fold; I did not build it.

## Option 3 — narrow the refinement grammar (the ticket's first branch)

Compiler delta (PROTOTYPE A, `proto/A/bs_parser.yrl`): replace `refinement -> expr_low` with a
closed grammar — `refinement -> refinement 'and'|'or' refinement | '(' refinement ')' |
lident cmp ref_int | ref_int cmp lident | lident ('=='|'!=') atom_lit`, `ref_int -> integer | '-'
integer`. It mirrors `int_lit` as the ticket proposed.

Measured: `value >= -5`, `-5 <= value`, `!= -3`, 32-bit span accepted; **everything else with a paren,
`+`, `-`, `*` or a call is now a parse error**. yecc: still 6 shift/reduce, **226 → 230**
precedence-resolved blocks. **One existing unit test goes red**:
`intervals_tests:an_unreadable_refinement_predicate_is_an_error_test`, because `WellFormed(value)`
(the O(n) tier ticket 20 §5 and 29 let you declare) became `syntax error before: 'WellFormed'`
instead of the dedicated `opaque_refinement` explanation (`out/table.out` row 24).
The disagreement the ticket predicted is measured: refinement `value >= -5` readable, guard
`n >= -5` not — `G2` (refinement `-5`, guard `n >= -5` only) is **refused** as non-exhaustive
(`F(>= -5) -> ...`), and the 80-function `HeavyNeg` file is refused at its first function
(`out/bench.out`, exit status 1). Bodies are unchanged: `Low() -> -5` refused.

Strongest counterargument (for it): it is the smallest *conceptual* change — patterns already work
this way, the checker is untouched, and a closed grammar cannot accept something the checker then
misreads. Against it, besides the above: it forecloses declaring an O(n) refinement later.

## Recommendation

**Option 1, answering the gate: `-5` is a literal.** On my evidence it is the only one that is green
on all three sites (refinement, guard, body); it is one line against ~8 or a grammar rewrite; it
adds no yecc conflict and no failing test; and it matches what this parser already does for float
literals and patterns. Reopen `2 + 3` only when a program needs it, as a follow-on ticket whose
answer is Option 2's `const/1` called from **both** `comparison/1` and `type_of`.

One cosmetic cost to state: the folded node carries the digit's position, not the minus's (pass `L`
instead of `IL` to keep the minus).

## Follows from the gate (not asked separately)

- **How far folding goes:** at the literal. `2+3` and `0-5` stay refused; parenthesised `(-5)` and
  `--5` fold (rows 10, 15). **Unary minus on a name** never: `-n` stays `e_neg`, refused as
  opaque (row 19); Erlang agrees (`f(-N)` is `illegal_pattern`, `neighbours/erlang.out`).
  `value >= n` is refused today and stays refused (row 25).
- **Is `expr` load-bearing?** Yes, and Option 1 keeps it: Option 3's disagreement and its red unit
  test are the measurement; `alternatives/1` is the shared reader.
- **`value != -3`, `>= -5 and <= 5`, `>= 1 or <= -1`:** nothing more needed (Option 1 accepts all).
  Two rows stay refused for an **unrelated** reason: `value == -1` and `value > -1 and value < 1`
  say `a.bs:0: bad range type` — a singleton domain emits a one-point range the Erlang linter
  rejects (`-type t() :: 1..1.` → `type_syntax range`, `neighbours/erlang.out`). It fails for
  `value == 5` on the untouched compiler too (rows 27–28), so it is a separate defect to raise.
- **What the printer owes:** nothing new. The residual a clause head prints is already source that
  the surface accepts: `F(>= -10 and <= -1) -> ...` and `F(>= 1 and <= 10) -> ...`, which paste
  back and compile (`out/roundtrip.out`; the JSON diagnostic carries them as `pasteable`). `-10..-1
  | 1..10` is the set description (`bs_types:to_pattern`, the JSON `residual` field); `..` is not
  source in any position and prints the same for `1..2` today. The ticket's "prints a residual the
  surface cannot accept" is true only of a *refinement* spelling, and nothing in `bs_diag` or
  `bs_check` prints one (the only `where value` text is the example at `bs_diag.erl:1962`).

## Neighbours: `-5` as a pattern vs as an expression

| | pattern | expression | where it is decided |
|---|---|---|---|
| Erlang/OTP 29 | `{op,'-',{integer,5}}`, accepted | same node | **checker**: `erl_lint:is_pattern_expr` → `erl_eval:partial_eval` (`2+3` also legal); `f(-N)` illegal (`erl_parse.yrl:331`, `:1984`) |
| Elixir 1.20.4 | `-5` accepted; `2 + 3` refused ("cannot invoke remote function :erlang.+/2 inside a match") | `{:-,_,[5]}` | **expander**; `build_unary_op` never folds (read from `elixir_parser.beam`, no `.yrl` is installed) |
| Gleam 1.18.1 | `-5` accepted; `- 5`, `-(5)`, `2 + 3` refused | `-5`, `- -5`, `0 - 5` fine | **parser**, literal-only: same in `const lo = -5`; `const s = 2 + 3` refused; guards allow `n >= 2 + 3` |
| Elm 0.19 | **refused**: "not possible to pattern match on negative numbers" (source) | `Negate` node | UNMEASURED at run time |

Reading: Gleam is Option 1 (literal-only, spelling `-5` or nothing), Erlang is Option 2, Elixir is
Option 2 for `-` only; Elm refuses the pattern outright, which is the ticket's defect in reverse.
Gleam is the nearest in kind — a language with exhaustiveness and negative literals in guards,
patterns and constants.

## Compile time and grammar

`bench.out`: 80 refinement types + 80 functions, 30 in-VM runs, two rounds, idle machine. Medians,
ms (min in brackets), round 1/round 2: baseline 92.7/92.3 [85.8/85.7]; A 92.1/91.0 [86.0/83.9];
B 96.5/92.4 [89.3/84.3]; C 93.8/91.8 [88.3/86.7]. Spread inside one build is several ms and an
earlier capture of the same script (A and B ~5% slower, different builds each time) reordered them,
so **no delta is distinguishable from noise**. Parse alone is under 1.5 ms in all. Signed file
(`HeavyNeg`), B and C only: 102 and 98 ms; baseline and A exit 1.

| | AST for `value >= -5` | yecc shift/reduce | precedence-resolved | new red unit tests |
|---|---|---|---|---|
| baseline | `e_neg(e_int 5)` | 6 | 226 | 0 |
| A | `e_int -5` (refinement only) | 6 | 230 | 1 |
| B | unchanged | 6 | 226 | 0 |
| C | `e_int -5` (everywhere) | 6 | 226 | 0 |

Row numbers below are the Nth `row` call in `table.sh` (the output does not print them).

## Evidence index (claim → file under `artifacts/probes/57/`)

| claim | file |
|---|---|
| ticket's 5 rows reproduce; extra rows; guard credits nothing | `out/table.out` (BASELINE) |
| `38b` 7/7 on this compiler; as-shipped does not run | `out/38b_shim_base.out`, `out/38b_as_is.out`, `shim38b.sh` |
| `-5` is `e_neg`, float folds, pattern is `p_rel -1` | `out/ast.out`, `ast.escript` |
| A/B/C table, guard agreement G1–G5 | `out/table.out` |
| body typing, `Nz` today, `x / -0`, `2 + 3` | `out/literal_use.out`, `literal_use.sh` |
| diff of each prototype | `out/proto_{A,B,C}.diff`, `proto/` |
| yecc conflicts | `out/conflicts.out`, `out/yecc_*.txt` |
| compile time | `out/bench.out`, `bench.escript`, `gen_heavy.sh` |
| unit modules, 65, baseline vs each | `out_eunit/` (`EUNIT=1 ./run.sh` regenerates) |
| residual pasteable | `out/roundtrip.out`, `roundtrip.sh` |
| Erlang, Elixir, Gleam, Elm | `out/n_*.out`, `neighbours/` |
| first draft of the site rows was broken | `revisions/table_v1_baseline_BROKEN_site_rows.out` |

## Limits

- **Revised probe, kept:** `table.sh`'s first version named modules after labels with spaces, so its
  three pattern/guard rows failed as syntax errors on every build; kept in `revisions/`. The
  refinement rows in that run are identical to the final ones. `gen_heavy.sh` first emitted a dead
  third clause that produced warnings; removed before any timing was recorded. `shim38b.sh` edits
  only how the compiler is found.
- **Prototype A is my reading of "grammar-side"**, a closed comparison grammar; a variant that only
  folds inside `refinement -> expr_low` would also disagree with guards but would keep the
  `WellFormed(value)` diagnostic. Not built.
- **Prototype B has no `type_of` fold**; B+ is UNMEASURED. B's `const/1` also never reaches
  emission, so only the checker's reading was tested, plus runtime of boundary guards
  (`Delta` param, `F(-6)` → `function_clause`, `out/table.out` run-time block).
- **Unit suite:** `cli_tests`/escript paths run through a shell wrapper in place of the escript.
  Eight tests fail on the untouched baseline (conflicts count, AoC corpus, three
  `corrected_signature`, two `diagnostic_term`, one `cli`) — environment, since I did not provide
  `src/`, `aoc/` or rebar3. Only the delta against baseline is claimed. The `the_grammar_has_exactly_its_named_conflicts_test`
  failure means the 6-conflict claim rests on my own yecc runs, which agree.
- **Elm:** the compiler cannot fetch `elm/core` here (package.elm-lang.org returns 403), so nothing
  was compiled; the citation is `elm/compiler` tag 0.19.1, the installed binary is 0.19.2.
  **Elixir:** no `.yrl` installed; behaviour was probed and `build_unary_op` read from the beam.
  **Gleam:** parser is Rust in the binary; behavioural only.
- **Toolchain:** OTP 29, not the pinned 28.5. Timings are in-VM on one 4-core box, not the ticket
  39 Apple Silicon numbers.
- **Not tested:** `ibs`/REPL, the LSP and the tree-sitter grammar (does `grammar.js` take `-5` after
  a comparison?), the emitted `-spec` text for negative bounds, and any `--api` rendering.
- A decision for David, not me: whether the `bad range type` singleton defect gets its own ticket.

## Verifier findings (independent re-run, see probes/57/VERIFY.md)

REPRODUCED, not circular: fresh builds of base/A/B/C give byte-identical output (table, literal use,
round-trip, AST, yecc conflicts 6/6, 38b shim); unit failures identical (8 baseline, +1 for A, 0 for B/C);
bench is noise-level. The verifier's own programs confirm `Nz Neg() -> -5` refused, `value == 5` "bad range
type", guard `n >= -5` credits nothing, and `x / -0` compiles on base but is refused under C. Source
citations all correct; the Elm source is a genuine clone of elm/compiler 0.19.1 (Elm behaviour itself
UNMEASURED; the 403 was not bypassed). Gaps: the other 7 baseline failures are not individually diagnosed;
emitted `-spec` text for negative bounds is untested. The recommendation follows from the evidence.
