# Decision brief — ticket 57 (ENG-239): a refinement cannot say `-5`, though a pattern can

**Status: the decision stays open.** Nothing here resolves the ticket, edits the tracked compiler, or commits.
Prepared 2026-10-27 by an automated run. Probes are in `probes/`; each has a stated hypothesis, a way to fail,
and its captured `.out`.

## How to read the evidence

- **MEASURED** = executed here, output saved next to the probe.
- **RECORDED, not re-executed** = read from source or the ticket, never run by me.
- **Environment.** OTP **25.3**, Elixir 1.14.0 (the repo pins OTP 28.5). The real `bs_lexer.xrl` needs OTP 27's leex,
  so `probes/00_build_scratch.sh` builds the *real* `bs_parser.yrl`, `bs_check.erl`, `bs_types.erl`, `bs_emit.erl`,
  `bs_diag.erl` unchanged, plus a **scratch lexer shim**: `TokenLoc` becomes `{TokenLine,1}`, so every column is 1.
  Gleam was unavailable (binary download denied); Elm 0.19.3 is installed but cannot compile (package server 403).
- The four fixes are **scratch variants** (`probes/fix_*.patch`). They exist to measure, not as the proposed patch.

## The question, in B# terms

```csharp
type Delta = int where value >= -100 and value <= 100   // refused today: opaque_refinement
public atom Sign(int n)
Sign(<= -1) -> :neg                                      // compiles: patterns have `int_lit -> '-' integer`
```

**Gating question (ask this one alone): is `-5` a literal or an expression?** Where the fold belongs follows
from it. How far a fold reaches (`2 + 3`? a named constant?) only exists as a question under one of the answers,
so it is *not* asked here.

## What I measured that the ticket does not say

1. **The ticket's AST is stale.** Since F51, unary minus is `{e_neg, L, {e_int, L, 5}}`, not `0 - 5`
   (`bs_parser.yrl:587-591`, `negate/2` at `:947`). MEASURED, `01_baseline.out`. The defect is unchanged, only its
   shape differs: `alternatives/1`'s `comparison/1` (`bs_check.erl:5154-5155`) matches only `{e_int,_,K}`.
2. **It is not a refinement-only defect. Guards lose coverage the same way.** `apply_guard/3`
   (`bs_check.erl:5121`) goes through the same `alternatives/1`. MEASURED, `02_guards.out`:

   | clauses (each pair covers every `int`) | verdict |
   |---|---|
   | `when n >= 0` / `when n < 0` | accepted |
   | `when n >= -1` / `when n < -1` | **refused `inexhaustive`**, residual = all of `int` |
   | `when n != -1` / `when n == -1` | **refused `inexhaustive`** |
   | the same pair as `switch` arms | **refused `switch_inexhaustive`** |

   The author sees "your clauses are not exhaustive" for two clauses that are. The guard is silently credited
   nothing (`bs_check.erl:5127`), which is the *right* refusal reported in the wrong words.
3. **A negative literal in a *body* is typed `int`.** `type_of({e_neg,…})` returns `bs_types:int()`
   (`bs_check.erl:2963-2973`). MEASURED, `04_matrix.out` / `11_e2e.out`: with `type NonPos = int where value <= 0`,
   `NonPos Back() -> -1` is refused `return_not_declared` **even though the type is writable and `-1` is in it**.
   So a refinement fix alone does not make a signed domain usable (see evidence in the options).
4. **`n / -0` passes the zero-divisor check and crashes.** `divisor_diags` reads the divisor's *type*
   (`bs_check.erl:4338-4346`); `-0` is typed `int`, so F26's refusal of `n / 0` does not fire. MEASURED,
   `11_e2e.out`: baseline compiles it and `Div(10)` returns `{error,badarith}`; ticket 38's check silently has
   this hole.
5. **No test or example in the repo uses a negative literal in a refinement or a `when` comparison** (grep over
   `compiler/test`, `compiler/examples`; RECORDED as a grep, not a probe). That is why a green suite never saw it.

## Option 1 — `-<int>` is a literal, decided by the parser

```csharp
type Delta = int where value >= -100 and value <= 100
public Delta Clamp(int n)
Clamp(n) when n < -100 -> -100
Clamp(n) when n > 100  -> 100
Clamp(n) -> n
```

**Compiler delta (concrete, one clause):** `bs_parser.yrl` `negate/2`, beside the F51 float clause:

```erlang
negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};   %% fix_A1.patch, 1 line
```

The refinement stays an `expr` (`bs_parser.yrl:221`), so the F2.5 rule "a refinement and a guard cannot disagree"
is untouched. `-5` simply stops being a node, as `-5.0` already has not been since F51. The diagnostic text
(`bs_diag.erl:2019-2026`) wants one phrase changed, from "comparisons on `value`" to "comparisons of `value` with
an integer literal".

**Evidence (MEASURED, variant A1):**
- Every `-N`-only refinement row is accepted: `>= -5`, `>= -5 and <= 5`, `>= 1 or <= -1`, `!= -1`, `-5 <= value`,
  `-(-5)` (`04_matrix.out`).
- Guards and arms: all three `-1` pairs now accepted. Body `NonPos F() -> -1` accepted. `n / -0` refused as
  `divide_by_zero` (`04_matrix.out`, `11_e2e.out`).
- End to end, real `bs_emit:forms` then `compile:forms` then run: `Clamp(-99)=-10, Clamp(4)=4, Clamp(99)=10`;
  `Band(-1)=high, Band(-2)=low` (`11_e2e.out`). The emitted `{integer,L,-5}` compiles.
- Residual round trip: `Delta` with only `F(0)` prints `F(>= -10 and <= -1)` and `F(>= 1 and <= 10)`, and pasting
  those back is accepted (`09_residual_roundtrip.out`). This answers ticket 38's worry: the residual is spelled in
  *pattern* syntax, which already took `-N`; the only unwritable place was the refinement declaration.
- No new yecc conflicts (6 shift/reduce before and after, `03_build_variants.out`). Compile cost is below noise:
  `check/1` on one input measured 129-154 µs across two runs and builds (`10_cost.out`; baseline 152 and 129 for the same code).
- Eunit: the failing set is identical to baseline (`05_regression_diff.txt`; see limits, this is weak).

**Strongest counterargument:** it settles `-5` and nothing else. `value >= 1 - 2`, `value >= 2 + 3` and
`value >= 7 / 2` stay `opaque_refinement` (MEASURED, A1 rows). The first request for a bound like `Max - 1` or
`-Limit` needs a second mechanism, and the parser fold is the wrong place for it. It also changes the AST for
*every* expression, not only refinements: anything downstream matching `{e_neg,_,{e_int,…}}` (RECORDED: only
`bs_check.erl:2675`, `:2963`, `bs_emit.erl:743`, `:1067` mention `e_neg`) now sees a literal. I did not run the
F51 float gates against it.

## Option 2 — `-5` is an expression; the checker folds literal arithmetic

```csharp
type Delta = int where value >= -2 * 50 and value <= 10 * 10    // reads as -100..100
public Delta Clamp(int n)
Clamp(n) when n < -100 -> -100                                  // still needs the body fix below
```

**Compiler delta:** `bs_check.erl`, in `comparison/1` (`:5154-5155`) read the comparand through a new
`const_int/1`: literal, `e_neg` of a constant, and optionally `+ - * / %` over constants, with a zero divisor
left unreadable. About 12 lines (`fix_B1.patch` negation only, `fix_B2.patch` with arithmetic). It also needs one
`type_of` clause so a body `-1` has range `-1..-1` (`fix_B3.patch`, +1 line), or Option 2 leaves the signed
domain unusable.

**Evidence (MEASURED):**
- B2 accepts every arithmetic row: `2 + 3`, `1 - 2`, `2 * 3`, `-2 * 3`, `7 / 2`, `5 % 3`, `0 - 5`. It keeps
  `1 / 0`, `1 % 0`, `-5.0`, `value >= value` and `value >= (-5) + value` refused (`04_matrix.out`, last block).
  The residual of `value >= -2 * 3 and value <= 2 + 3` with `<= 0` handled is `1..5`, as it should be.
- Guards: `n >= 1 - 2` / `n < 1 - 2` and `n >= 2 + 3` pairs go from refused to accepted. Option 1 does not do this.
- **B2 alone does not make `Clamp` compile:** `P1` and `P3` stay `return_not_declared` because `-1`/`-100`
  in a body are still `int` (`11_e2e.out`, B2 rows). **B3 (B2 plus the `type_of` clause)** reaches the same
  end-to-end results as Option 1 (`Clamp(-99)=-10` etc.) and also refuses `n / -0`.
- Zero cost visible: B2 `check/1` 138-139 µs vs baseline 129-152 µs over two runs (`10_cost.out`), within noise.
- Eunit failing set identical to baseline, except B1 loses one `cli_tests` test, a flake (`05_regression_diff.txt`).
- Neighbour: **Erlang does exactly this.** Its parser keeps `{op,1,'-',{integer,1,5}}` in patterns and guards
  (`06_erlang.out`; `erl_parse.yrl:270`, `pat_expr -> prefix_op pat_expr`), and a *later* stage folds. A pattern
  `f(1+2)` and `f(7 div 2)` compile; `f(Y+2)` and `f(1 div 0)` are refused `illegal_pattern`
  (`erl_lint.erl:1880-1893`, `is_pattern_expr` then `erl_eval:partial_eval`). A guard `X >= -5 + 1` reaches
  Core Erlang as `erlang:'>='(X, -4)` (`06_erlang.out`). That is the same boundary B2 draws: constant arithmetic
  reads, a zero divisor and a variable do not.

**Strongest counterargument:** the fold becomes a *second implementation of B# arithmetic* inside the checker.
`/` is truncating `div` and `%` is `rem`, signed by the dividend (`bs_lexer.xrl`, ticket 38); the checker must
agree with the emitter on negative operands for ever, and every operator added is a new place to disagree. The
"where does it stop" question is real: B2 stops at the five operators, but nothing in the design says why those.
It also needs **two** edits (fold plus body typing) where Option 1 needs one, and forgetting the second gives a
green refinement test and an unusable type (the B2 rows above).

## Option 3 — narrow the grammar at the refinement site only (the ticket's first option, as written)

```csharp
type Delta = int where value >= -100 and value <= 100   // accepted
Clamp(n) when n < -100 -> -100                          // still refused: inexhaustive
public Delta Clamp(int n) ...                           // still refused: return_not_declared
```

**Compiler delta:** a refinement-only walk in the grammar action, `refinement -> expr_low : fold_neg('$1')`
(`fix_A2.patch`, about 8 lines), or a dedicated comparand production mirroring `int_lit`.

**Evidence (MEASURED, variant A2):** all `-N` refinement rows accepted, **but** guards still `inexhaustive`, arms
still `switch_inexhaustive`, `NonPos F() -> -1` still refused, `n / -0` still compiles and returns `badarith`,
`-(-5)` still refused, and `P3` (`Clamp`) is refused with two `return_not_declared` (`04_matrix.out`,
`11_e2e.out`).

**Strongest counterargument:** none that survives the measurements as an end state. Its one merit is that it
touches only the refinement (smallest blast radius), but the defect is shared with guards and body typing, so
this option delivers a type you can declare and cannot use. I list it because the ticket names it, not because the
evidence favours it.

## Recommendation (the decision is David's)

**Option 1 as the gating answer: `-5` is a literal.** One parser line fixes the refinement, the guard credit,
the body typing and the `n / -0` hole together (A1 is the only variant that fixed all four with one edit), it
matches what `int_lit` and F51's float clause already do, and it takes the bounded-domain case
(`-100..100`) the ticket cares about to a compiling, running program.

**Decide the second question only if a program asks for it.** `value >= Max - 1` or `2 * 50` is the first thing
Option 1 refuses; Erlang's lint/eval split (`06_erlang.out`) is the existing precedent for adding a fold then,
and Option 2's `const_int/1` is the shape. Nothing here needs it today: no `.bs` file in the repo spells one.

Two companion changes follow from Option 1 whichever way the gate goes, and neither is a second decision:
- reword the `opaque_refinement` text (`bs_diag.erl:2019`) to say "an integer literal";
- the missing test, `where value >= -5` and `when n >= -1`, which no existing test covers.

**Ticket 38's residual concern is already answered by measurement:** the residual prints in pattern syntax, which
parses `-N` today; the gap was only the refinement declaration (`09_residual_roundtrip.out`).

## Not verified / limits

- **OTP 25, not 28.5**, and the lexer is a shim with every column 1. Nothing about positions, columns or
  diagnostics' `file:line:col` was measured. Real `bsc` was not built or run.
- **The eunit comparison is weak.** 635 of about 1,495 test functions fail on baseline here, so a regression in a
  failing test would be invisible. Only "no passing test turned red" is supported. I did not triage the causes
  (one seen: generated code calls `maps:iterator/2`).
- **Not run:** `bin/verify.sh`, the gates (`check-float.sh`, `check-language.sh`), and the tour. Whether
  folding `-5` in the parser disturbs F51's float gates is RECORDED as unchecked.
- **Not surveyed by execution:** Gleam (compiler unavailable) and Elm (compile needs a blocked package server,
  `08_elm.out`). **Elixir:** `07_elixir.out` shows its reader keeps `{:-, _, [5]}`, `def f(-5)` compiles,
  `f(1 + 2)` and `f(x + 2)` in a pattern are refused, and its emitted Erlang forms hold the *unfolded*
  `{op,1,'-',{integer,1,5}}`, so Elixir leaves folding to the Erlang compiler. My prediction that Elixir folds
  earlier was **falsified**; the Elixir source is not installed (`.beam` only), so no file:line is cited for it.
- The scratch fixes are measurement instruments. `fix_B*` fold with Erlang's `div`/`rem` and were not checked
  against `bs_emit`'s lowering on negative operands.
- Cost numbers are single-machine micro-timings under noise, not a benchmark.

## Probe index

| probe | what it tests | output |
|---|---|---|
| `00_build_scratch.sh` | builds the real compiler modules on OTP 25 with a lexer shim | `00_build_scratch.out` |
| `01_baseline.sh` + `table.erl` | AST shape; the ticket's refinement table at HEAD; extra spellings | `01_baseline.out` |
| `02_guards.sh` + `guards.erl` | same literal in clause guards and `switch` arms | `02_guards.out` |
| `03_build_variants.sh` | builds A1, A2, B1, B2, B3 from the real source (`fix_*.patch`) | `03_build_variants.out` |
| `04_matrix.sh` + `more.erl` | table, guards, residual interval, body literal, `-0` divisor, must-not-change rows, per build | `04_matrix.out` |
| `05_regression.sh` | repo eunit modules per build | `05_regression.out`, `05_regression_diff.txt` |
| `06_erlang.escript` | Erlang parse, lint, Core folding of `-5` and constant arithmetic | `06_erlang.out` |
| `07_elixir.exs` | Elixir quoted form, compile acceptance, emitted forms | `07_elixir.out` |
| `08_elm.sh` | attempt to compile Elm negative-literal patterns | `08_elm.out` (blocked) |
| `09_residual_roundtrip.sh` + `roundtrip.erl` | ticket 38's residual: printed text and paste-back | `09_residual_roundtrip.out` |
| `10_cost.sh` + `cost.erl` | `check/1` and parse timing, AST words | `10_cost.out` |
| `11_e2e.sh` + `e2e.erl` | check, real `bs_emit`, compile, load, run; `n / -0` | `11_e2e.out` |
