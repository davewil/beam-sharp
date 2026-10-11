# Decision brief: ticket 57 / ENG-239, negative literals in refinements

Ticket stays open for David. Everything below was run against HEAD (`5681928`) with OTP 28 / erts 16.4 on Linux x86_64;
probes and prototype diffs are in `artifacts/probes/57/` (rerun: `./run.sh`; captured: `output.txt`).

## 1. The ticket's repro still holds, but its mechanism is stale and one claim is wrong

`probes/57/table.sh`, baseline compiler, every row of the ticket's table: `value >= -5`, `... and value <= 5`,
`value >= 1 or value <= -1` are refused with `opaque_refinement`; `value <= 3 or value >= 10` and `value != 0` compile.
**All five rows hold.** Also refused on HEAD, none of which the ticket listed: `-5 <= value`, `value == -3`,
`value != -3`, `value >= -0`, `value >= - 5` (the literal's spelling does not matter, a minus in front of any integer does).

Three corrections to the ticket, all measured:

1. **The AST moved.** Ticket: `-5` desugars to `{e_op,'-',{e_int,0},...}`. Since F51 it is its own node:
   `bs_parser.yrl:591` `expr_low -> '-' expr_low : negate(...)`, and `negate/2` (`bs_parser.yrl:947-948`) already folds a
   negated **float** literal to the literal and wraps everything else in `{e_neg,L,E}`. The cause is the same
   (`alternatives/1` at `bs_check.erl:4997` reads only `{e_int,_,K}` comparands, `comparison/1` at `:5015-5016`), but the
   repair site looks different: there is a fold for floats one line above where integers would go.
2. **"A residual the compiler prints and the surface cannot accept" is wrong at HEAD.** F29 prints a residual as clause
   heads, not as a type. `probes/57/residual.sh` R3a: bare `int` with clauses `<= -11`, `>= 11`, `0` is refused with
   `Sign(>= -10 and <= -1) -> ...` and `Sign(>= 1 and <= 10) -> ...`; R3b pastes both heads back and it **compiles
   (rc 0) on the unpatched compiler**. What the surface cannot write is the *type* `-10..10` in a signature, not the
   residual. The residual doctrine is not capped by this ticket; the ability to name a signed bounded domain is.
3. **"Guards accept -5" is half true** (section 3): a guard `when x >= -5` is accepted by the parser and then silently
   not read, so it earns no coverage credit.

Side finding, unrelated to negation and present on the unpatched compiler: any single-value refinement
(`value == 3`, `value >= 3 and value <= 3`, `value > 0 and value < 2`) fails with `compile: P/p.bs:0: bad range type`
(`probes/57/baseline_singleton.sh`). `value == -3` and `value > -1 and value < 1` hit this after any fix; do not read
them as fix failures. This wants its own ticket.

## 2. The gating question

**Is `-5` a literal everywhere an expression is read, or a computation that one site (the refinement) happens to fold?**

The ticket frames it as grammar versus checker. The probes show the real axis is *how many sites read the literal*:
refinement comparand, guard comparand, and a literal in value position (an argument). Ask this alone; the
`2 + 3` question follows from it.

## 3. The same two programs under each answer

Program 1, the ticket's own motivating type, plus a call that uses a value the type admits:

```csharp
module P

type Delta = int where value >= -100 and value <= 100

public atom Take(Delta d)
Take(<= -1) -> :neg
Take(0)     -> :zero
Take(>= 1)  -> :pos

public atom Lit()
Lit() -> Take(-5)          // -5 is in Delta
```

Program 2, a guard over bare `int` that must be proved exhaustive without a catch-all:

```csharp
public atom F(int x)
F(x) when x >= -5 -> :a
F(x) when x < -5  -> :b
```

| | baseline | A1 / A2 (refinement-only grammar) | B (`-<int>` is a literal) | C (checker folds) | C2 (checker folds, two sites) |
|---|---|---|---|---|---|
| `type Delta = int where value >= -100 and value <= 100` | refused | compiles | compiles | compiles | compiles |
| Program 1 `Lit() -> Take(-5)` | n/a | **refused**: `argument 1 is not covered ... int <= -101 | int >= 101` | compiles | **refused**, same text | compiles |
| Program 2 | refused: `F is not exhaustive` | **refused** (the guard still is not read) | compiles | compiles | compiles |
| control `value >= n`, `value + 1 >= 3`, `value >= -x` | refused | refused (A2: syntax error) | refused | refused | refused |
| `value >= 2 + 3`, `>= 0 - 5`, `>= -(2+3)`, `>= 5 * 2` | refused | refused (A2: syntax error) | refused | **compiles** | **compiles** |
| `value >= -(5)`, `-5 <= value` | refused | compiles | compiles | compiles | compiles |
| `value >= --5` (reads as `5`) | refused | refused (A1), syntax error (A2) | compiles | compiles | compiles |

(`probes/57/output.txt`, sections "repro table", "guards and patterns", "a negative literal in value position".)
Bad-value controls hold everywhere: `Take(-500)` is refused under B and C2 with `argument 1 is not covered ... -500`,
and `value >= -5 and value <= -10` reports `admits no values at all` under every fix.

What each compiles to, from `probes/57/delta_program.sh` (C2; B is identical): `Sign` over `Delta` is exhaustive with three
heads and no catch-all, `Sign(-100) = :neg`, `Sign(0) = :zero`, `Sign(100) = :pos`, `Sign(101)` and `Sign(-101)` crash with
`function_clause` (the exported boundary check from F37 enforces a negative lower bound). The residual of `Sign(0)` alone over
`-10..10` prints `Sign(>= -10 and <= -1)` / `Sign(>= 1 and <= 10)` and pastes back clean (R1a, R1b).

## 4. The options

### Option B: the parser folds `-<integer literal>` into the literal (recommended)

Compiler delta, one line, the integer twin of the existing float rule:

```erlang
negate(_L, {e_float, FL, F}) -> {e_float, FL, -F};
negate(_L, {e_int,   IL, N}) -> {e_int,   IL, -N};     % new
negate(L, E)                 -> {e_neg, L, E}.
```

`bs_parser.yrl:947`; patch `patch-B-parser-negate-fold.diff`, +1 line. Because `{e_int,_,-5}` is an ordinary literal, every
site that reads literals sees it: `comparison/1` (refinements and guards), and `type_of({e_int,..})` at `bs_check.erl:2882`,
which gives `-5` the point type `-5..-5` instead of `int` (the `e_neg` clause at `:2889` returns `int`, which is why
Program 1's `Lit()` is refused under every option except B and C2).

Evidence: eunit 1434/1434, 10 gates green (`check-diagnostics`, `residual-pasteable`, `guard-calls`, `negation`, `division`,
`boundary-range`, `examples`, `helper-agrees`, `switch-diagnostics`, `tagged-union`; `verify-results.txt`). Observable program
behaviour unchanged (`probes/57/body_literal.sh`: `-5`, `x - -5`, `3 - 5 * -2`, `-(-5)`, `-x` give the same results; only the
emitted abstract form changes from `{op,'-',{integer,5}}` to `{integer,-5}`). Guards and refinements agree: Program 2
compiles and `value >= -5` compiles.

Strongest counterargument: it makes the lexical shape decide meaning. `-(5)` and `- 5` also fold, and `3 - -5` still
parses as before, but `-5 + 0` is now `(-5) + 0` over a literal while `value >= -5 + 0` stays refused, so a reader will meet
a refusal that looks like `2 + 3`'s. B also removes `e_neg` for integer literals from the AST that F48's
AST-as-a-value feature exposes (the tree now carries `{e_int,_,-5}`), so a program that pattern-matches a `-5` it received as `e_neg` changes
shape. UNMEASURED: whether any shipped exemplar or F48 test does that; the 1434 tests do not.

### Option C / C2: the checker folds literal arithmetic

Compiler delta: a `const_int/1` (`{e_int}`, `{e_neg}`, `+ - *` over constants) and `fold_int/1`, applied to both sides in
`comparison/1` (`bs_check.erl:5015`), which fixes refinement and guard together (C). C alone leaves `Take(-5)` refused
(the `e_neg` typing at `:2889`), so the full answer is C2: also a `type_of({e_neg,_,{e_int,..}})` clause returning
`range(K,K)`. Patches `patch-C-checker-fold.diff` (+26 -7, 7 of them a rename of `comparison` clauses to `comparison1`) and
`patch-C2-...diff` (+30 -7). eunit: C2 1434/1434; C 1433 plus the diagnostics-gate test, which failed only because no escript
was built yet and passes (rc 0) afterwards, not rerun in full. Gates 10/10 for both.

It is the only option under which `value >= 2 + 3` and `value >= -(2 + 3)` compile. Division and `%` are deliberately left
out of the fold (ticket 38 owns their meaning).

Strongest counterargument: it is the option that matches the design-intent comment at `bs_parser.yrl:217-221` literally (one
grammar, one reader, `alternatives/1`), and Erlang does the same thing: `erl_parse` keeps `{op,A,'-',{integer,A,5}}` as an
operator node (`erl_parse.yrl:269` for expressions, `:301` for patterns) and the constant is recovered afterwards, in
`erl_lint:is_pattern_expr` via `erl_eval:partial_eval` (`erl_lint.erl:2140`, `erl_eval.erl:2204`) and `erl_parse:normalise`
(`erl_parse.yrl:1818-1820`). I confirmed the effect on OTP 28: `f(1+2)`, `f(-1)` and `X >= -5, X =< 2+3` all compile
(`probes/57/survey_erlang_elixir.sh`). So C2 buys constant arithmetic nobody has asked for, at 30 lines across two sites, to
fold something B folds in one.

### Option A: only the refinement site learns `-5` (the ticket's "grammar" answer)

Two ways to do it, both built. A1: `refinement -> expr_low : refine_neg('$1')`, a 6-line tree walk in the parser
action (`patch-A1-...`, +7 -1). A2: a separate predicate nonterminal whose comparand is the existing `int_lit`
(`patch-A2-...`, +19 -2; yecc reported no conflicts). Both make Program 1's declaration compile, and **both leave Program 2
refused and `Lit() -> Take(-5)` refused**: `type T = int where value >= -5` and `F(x) when x >= -5` now mean different things,
which is the split `bs_parser.yrl:217-221` says the shared `expr` exists to prevent. Eunit A1 1434/1434, gates 10/10.
**A2 fails an existing test**, `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test`: the documented O(n)-tier
form `int where WellFormed(value)` becomes a syntax error and no longer produces the `opaque_refinement` message that
explains the tier. Under A2, `value >= n` and `value + 1 >= 3` are syntax errors too.

Strongest counterargument: it is the smallest change that touches only the reported site, and what it leaves broken (guards)
is, today, equally broken and silent. A guard never errors; it just credits nothing, and an author who always writes a
catch-all (Program 2 plus `F(x) -> :b`, rc 0 in every variant, G6) will not notice.

## 5. Guard and refinement agreement, measured

`probes/57/guards.sh`. On HEAD a guard `when x >= -5` **is accepted by the parser and not read**: `alternatives/1` returns
`unknown`, `apply_guard/3` (`bs_check.erl:4984-4994`) then credits no coverage, so Program 2 reports `F is not exhaustive`
while the same function with a trailing catch-all compiles. So on HEAD the two sites already agree (both unreadable) and
differ only in severity: the refinement is a hard error, the guard a silent non-credit. The positive-literal control
`when x >= 5` / `when x < 5` compiles (G0), and a two-variable guard `x >= y` stays refused under every fix (G7).
Patterns already accept it: `F(>= -5)` / `F(< -5)` and `F(-5)` compile (P1, P2), via `int_lit -> '-' integer`
(`bs_parser.yrl:471-472`).

## 6. How neighbours do it

- **Erlang** (above): operator node in the parser, folded after parse; arithmetic included.
- **Elixir 1.20.4**: `Code.string_to_quoted("-5")` is `{:-, [line: 1], [5]}`, an operator node, and `x >= -5`, `a(-1)` and
  `x >= -5 and x <= 2 + 3` all compile and match (`survey_erlang_elixir.sh`). Parser source (`elixir_parser.yrl`) is not
  installed here, so this is a binary probe, not a file:line citation.
- **Gleam 1.19.1**: `-1` is a pattern, `n if n >= -5` and `n if n >= 2 + 3` compile; `n if n >= - 5` and `-{ 2 }` are syntax
  errors ("This operator has no value on its right side"): the minus must touch the digit, which is B's position
  (`-<digit>` is a literal, nothing else is). Gleam's exhaustiveness also ignores Int guards (G-g: `n if n >= 0 / n if n < 0`
  is `Inexhaustive patterns`), so there the guard/pattern asymmetry is by design. The Gleam stdlib could not be fetched (hex.pm
  blocked); the probes use no dependency.
- **Elm 0.19.3**: UNMEASURED. `package.elm-lang.org` is blocked (`survey_elm.sh` shows the failure), so not even `elm make` of a
  `case x of -1 ->` could run. Elm has neither refinements nor guards, so little is lost.

## 7. Recommendation

**Option B.** One line at `bs_parser.yrl:947` mirrors the float fold already there and the `int_lit` rule patterns already use,
and it is the only cheap option under which refinement, guard and value position all agree: Program 1 and Program 2 both
compile, the controls (`value >= n`, `value + 1 >= 3`, `value >= -x`, bad bounds) all stay refused, and the 1434 tests and ten
gates stay green. C2 gets there too but costs 30 lines at two sites to also admit `2 + 3`, which no program has asked for; A
leaves the guard split that the design comment forbids.

Whichever is chosen, **F2 needs a negative-bound scenario** (all five of its scenarios are non-negative, which is how the gap
survived a gated feature), and the **gate to write first** is a `--self-test` pair: `value >= -5` compiles and `value >= n`
is still refused, plus Program 2 compiling.

## 8. Not measured

- Whether any exemplar, F48 quote test or tooling (LSP, tree-sitter) depends on `e_neg` wrapping an integer literal (B).
  The tree-sitter grammar was not read.
- Compile-time or run-time cost: not measured, because no option changes emitted code except B's `{integer,_,-5}` form for
  literals; no timing claim is made.
- `check-helper-agrees` on the baseline copy was red only because no eunit beams existed there; it is green on all
  prototypes (which had run eunit). Not a defect of any option.
- The first A1/A2/B verification runs used a stale generated `bs_parser.erl` (they tested the baseline). Found when the
  rebuilt compilers still refused `value >= -5`; all numbers above are from the rerun after deleting it, and
  `build-variants.sh` now always deletes it.
- Elm (above). Elixir parser source (above).

## 9. Probes and how to rerun

`cd artifacts/probes/57 && ./run.sh > output.txt` (about 3 minutes; builds the six compilers from `git archive HEAD` into a
scratch dir, applies `patch-*.diff`, then runs everything). Needs `/tmp/claude-0/env.sh` for the toolchain.

| file | answers |
|---|---|
| `table.sh` | the ticket's table plus 18 controls, per compiler |
| `guards.sh` | guards and patterns with `-5`, `0 - 5`, `2 + 3`, `x >= y` (G0-G7, P1-P2) |
| `literal_arg.sh` | `Take(-5)`, `Take(-500)`, `Neg(-5)` against refined parameters |
| `residual.sh` | residual printing and paste-back, with and without a refinement |
| `delta_program.sh` | `Sign` over `Delta`, run at and beyond the bounds |
| `body_literal.sh` | B changes the AST of `-5` but not any result |
| `o_tier.sh` | `WellFormed(value)` diagnostic per fix (A2 regresses) |
| `baseline_singleton.sh` | the unrelated "bad range type" crash |
| `survey_erlang_elixir.sh`, `survey_gleam_elm.sh`, `survey_elm.sh` | neighbours |
| `build-variants.sh`, `patch-*.diff` | the five prototypes |
| `verify-eunit.sh`, `verify-gates.sh`, `verify-results.txt` | suite and gate results per prototype (slow; not in `run.sh`) |
