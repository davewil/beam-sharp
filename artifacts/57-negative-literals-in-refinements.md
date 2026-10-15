# 57 -- A refinement cannot say `-5`, though a pattern can

**Status**: brief only; ticket left OPEN for David. ENG-239. Compiler HEAD 019533d. Probes: `artifacts/probes/57_*`.
Every number and diagnostic below was produced by those probes; their last output is in the matching `.out`.

## What the ticket asks, and what changed since 2026-08-23

`int where value >= -5` is refused with `opaque_refinement` while the pattern `Sign(<= -1)` compiles. Ticket asks: does the
fold of `-5` belong in the grammar or in the checker?

Stale or wrong at HEAD (details under Findings):
1. The AST in the ticket (`{e_op,'-',{e_int,0},{e_int,5}}`) is gone. F51 made unary minus a node of its own:
   `{e_neg,L,{e_int,L,5}}` (`bs_parser.yrl:591`, `negate/2` at `:947`). The refusal is unchanged; the diagnosis shifts.
2. "A residual the compiler prints and the surface cannot accept" is **false** since F29 (2026-08-27): the residual
   prints as a pasteable clause head (`F(>= -10 and <= -1)`) and pasting it compiles.
3. "`bs_check.erl` says so at the `refinement` rule" -- the comment is in `bs_parser.yrl:218-220` (and F2.5), not `bs_check.erl`.
4. Unmentioned by the ticket and the bigger defect: a **guard** with `-5` silently credits nothing. `F(n) when n >= -5` /
   `F(n) when n < -5` over `int` is refused as "F is not exhaustive ... F(n)". Same cause, same `alternatives/1`.

Decided nearby (grepped `wayfinder/issues`, `compiler/features`): ticket 23 s2 / ticket 42 (a relational-pattern bound is a
literal and may be negative; `int_lit`, `bs_parser.yrl:468-472`), ticket 20 s5 + 29 (a refinement is read by `alternatives/1`),
F2.5 (guard and type refinement must agree), F51 finding 2 (negated float literal folds to the literal; `-x` is `e_neg`),
ticket 38 s2 (refuse a provably-zero divisor). Nothing decides integer-literal folding. This ticket is the first.

## The gating question (alone)

**Does `-5` stay a one-operand node until the checker, or is an integer literal with a sign a literal from the moment it is parsed?**

Everything else follows: whether `-(-5)` reads, whether `-5 + 10` / `2 + 3` read (that is a second, separable question: does
the checker fold arithmetic, asked only if David wants it), what a literal `-100` types as, and whether `n / -0` is a provably
zero divisor. The ticket's framing ("grammar at one site vs. checker") hides that the grammar option has two different meanings:
a fold at the *expression* level (shared with guards) and a *refinement-only* production. They behave differently (Findings 3, 4).

## Findings

Setup: `57_build_variants.sh` builds stock + four patched copies of `compiler/` in a mktemp dir (never the repo's):
`gramA` parser `negate/2` also folds `{e_int}` (1 line, beside the existing float clause); `gramB` new yecc rule
`expr_low -> '-' integer`; `gramC` refinement-only fold on the `refinement` rule; `chk` constant fold in
`bs_check:comparison/1` (`e_neg`, `+`, `-`, `*`; not `/`, `%`). All build warnings-as-errors.

**F1. The ticket's repro table is CONFIRMED at HEAD** (`57_stock.sh`, R01-R05): R01-R03 refused, R04 (`<= 3 or >= 10`) and R05
(`!= 0`) accepted. Control `57_nonzero.sh`: `!= 0` really excludes 0 (`Id(0) -> crashed: error:function_clause`; residual of `F(>= 1)` over it is `F(<= -1)`).
It is wider than the table: `value > -1`, `-5 <= value`, `value == -3`, `value != -3`, `value >= -0` are all refused (R15-R20).

**F2. The AST claim is STALE** (`57_ast.sh`). Stock: `{e_op,l,'>=',{e_var,l,value},{e_neg,l,{e_int,l,5}}}`. gramA/gramB: `{e_int,l,-5}`.
Note `{e_float,l,-5.0}` is already folded in stock (`bs_parser.yrl:947`), so a float literal and an int literal are treated differently today.

**F3. Guards use the same path -- CONFIRMED, and it is a silent loss** (`57_variants.sh` G01/G02/G04, `57_residual.sh` C):
```
public atom F(int n)            // stock
F(n) when n >= -5 -> :a
F(n) when n < -5  -> :b         // error: F is not exhaustive / no clause matches: F(n) -> ...
```
The same program with `0` is accepted (G02). The diagnostic suggests the whole domain is missing: the unread guard is never named.
Runtime is unaffected (`57_guard_runtime.sh`: `F(-6),F(-5),F(0) = :b :a :a` on every build).

**F4. The ticket's worry (a grammar fix splits refinement from guard) is REAL for gramC and ABSENT for gramA/gramB** (`57_guard_runtime.sh`):
gramC accepts `type T = int where value >= -5` but still refuses the guard pair (`L2 G is not exhaustive`); gramA, gramB, chk
accept both. The "grammar" answer is only safe if the fold sits where the guard also passes (expression level), which is also where F51 put the float fold.

**F5. A patterns-vs-expressions asymmetry is visible in typing, which the ticket did not see** (`57_variants.sh` E01/E03):
`e_int` types as the exact range `-100..-100`, `e_neg` types as `int` (`bs_check.erl:2882`, `:2889`). With a signed refinement writable:
```
type Delta = int where value >= -100 and value <= 100
public Delta Low()
Low() -> -100      // gramA/gramB: accepted.  chk: refused:
                   //   error: Low returns a value its signature does not declare
                   //     not covered by the declared return type:  int <= -101 | int >= 101
                   //     no signature is offered: what the clauses return has no spelling as a type yet.
```
The checker-side fold fixes the refinement and leaves this: it needs a second fold at `type_of/3`. `-101` stays refused on all builds (E02 control).

**F6. A grammar-level fold changes ticket 38's zero-divisor check, in the right direction** (D01): `n / -0` is accepted on stock (`-0` types
`int`), refused on gramA/gramB (`divide_by_zero`), accepted on gramC and chk. `n / (0 - 0)` is accepted everywhere (D03), as before. Not a regression;
it is a behaviour change that needs one test line.

**F7. Fold boundary** (`57_variants.sh` R06-R14): all five builds keep `value >= n`, `value >= 5 - value`, `5 - value >= 0`, `-value >= 5` refused (R11-R14),
and `>= -5 and <= -10` refused (R22, as `empty_refinement`). They differ on arithmetic: `-(-5)` reads on gramA and chk, not gramB/gramC;
`-5 + 10`, `2 + 3`, `2 * 3` read only on chk; `10 % 3` is refused by all (chk deliberately does not fold `/` `%`).

**F8. The signed Delta works end to end** (`57_boundary.sh`, gramA and chk): `type Delta = int where value >= -100 and value <= 100`,
exported `Id(Delta)`: `Id(-101)` and `Id(101)` crash `function_clause`, `Id(-100)`, `Id(0)`, `Id(100)` return; `Sign(<= -1)/Sign(0)/Sign(>= 1)` is total over it.
So F37's boundary check handles negative bounds with no further change.

**F9. The residual over a signed domain is writable now** (`57_residual.sh` A, E, F; `57_algebra.escript`). `subtract(-10..10, 0)` =
`ints => [{-10,-1},{1,10}]` (confirmed). On stock a bare-`int` program with `F(<= -11) F(>= 11) F(0)` prints
```
F(>= -10 and <= -1) -> ...
F(>= 1 and <= 10) -> ...
```
and pasting those two heads compiles (REFUTES "the surface cannot accept it"). What stock cannot do is *name* `-10..10` as a type to
get that residual (B); after gramA it can (E), and the pasted heads again compile. `bsc --api` prints `Sign(-100..100)`; that is a display form,
not source: `type X = 1..5` is refused even with positive bounds (`57_api.sh`), so this is not a negative-literal gap.

**F10. Machine code is unchanged** (`57_emit.sh`): `beam_lib:md5` (code chunks) is identical on all five builds for a program with `-5`, `n + -5`, `1 - -5`, `-(-5)`,
`-2 * 3`, `-7 / 2`, `-5 % 3`, `-9223372036854775808`; results `Lit=-5 Sum(10)=5 Mix=6 Neg2=5 Mul=-6 Div=-3 Rem=-2 Big=-9223372036854775808` on all.
Only the debug-info abstract code differs (`{integer,L,-5}` vs `{op,L,'-',{integer,L,5}}`); the .beam is 16 B smaller on gramA, 20 B on gramB.
gramB changes grouping of `-2 * 3` from `-(2*3)` to `(-2)*3` (`57_ast.sh`): equal for ints, including truncating `/` and `%` (Div, Rem above).

**F11. Existing tests** (`57_eunit.sh`, `SUMMARIZE_ONLY=1` over logs of the real run): `rebar3 eunit` on stock, gramA, gramB, chk: each `Failed: 4. Passed: 1444`,
the same four names (`every_aoc_program_still_compiles`, `batch_runs_every_entry_in_one_vm...`, `a_path_is_utf8_on_the_wire`, `a_non_ascii_literal_is_advised_as_written`). Stock fails them too in this
sandbox, so they are environmental; no patched build adds a failure. gramC was not run through eunit.

## Neighbours

**Erlang** (OTP 28.5, stdlib-7.3.0.3): the parser never folds. `erl_parse.yrl:269` `expr -> prefix_op expr`, `:301` same for patterns; `-5` parses to
`{op,L,'-',{integer,1,5}}` (`57_erlang.out`), so Erlang has the same node as B#'s `e_neg`, and `-(-5)`, `-2 * 3` stay trees. Fold sites are later:
`erl_lint.erl:2140` `erl_eval:partial_eval(Expr)` for patterns (`erl_eval.erl:2204`, `ev_expr({op,_,Op,L,R}) -> erlang:Op(...)` at `:2214`), so pattern
`f(2+3)`, `f(-(-5))`, `f(10 div 3)` are all accepted and `f(N+1)` is `illegal_pattern`; `erl_parse.yrl:1819` `normalise({op,_,'-',{integer,_,I}}) -> -I` for constant terms;
`sys_core_fold.erl:906` `fold_lit_args` for guards/expressions (`X >= -5` and `X >= 2+3` reach Core as `>= -5`, `>= 5`). Erlang folds arithmetic and does it after parsing, but it has no
checker that needs the literal before linting.
**Elixir** (1.18.5; the .erl sources are not in the nix store, read from GitHub v1.18.5): `Code.string_to_quoted!("-5")` = `{:-, [line: 1], [5]}` (`57_elixir.out`), no parser fold
(`elixir_parser.yrl` `build_unary_op`, line 759-760). The fold is at expansion and **only for a literal operand in a match or guard**: `elixir_expand.erl:931-932`
`{erlang, '+', [Arg]} when is_number(Arg) -> {+Arg, SL, E}; {erlang, '-', [Arg]} when is_number(Arg) -> {-Arg, SL, E}`. Hence `f(-5)` accepted, `f(-(-5))` and `f(2 + 3)` refused
("cannot invoke remote function :erlang.-/1 inside a match"), while the guard `when x >= -(-5)` / `>= 2 + 3` is accepted. That is the gramA shape (literal sign, nothing else) with the
expander as the site.
**Gleam** 1.19.2 (binary; no source available, program output only, `57_gleam.out`): `-5` accepted as expression, constant, pattern (`case x { -5 -> ... }`), and in guards
(`n if n >= -5`, `n if n >= 2 + 3`); `- -5` is accepted in an expression with the warning "Unnecessary double negation (--) on integer" but is a syntax error in a pattern and in a guard; `2 + 3` is a syntax error
as a pattern and `const lo = 2 + 3` is refused ("Unsupported operator in constant expression"). `n if n >= -5` / `n if n < -5` with no catch-all: "Inexhaustive patterns", i.e. Gleam never credits guards.
**Elm** 0.19.2 (binary, `57_elm.out`; registry faked offline, see header): `v = -5`, `v = -(-5)`, `x >= -5`, `x >= 2 + 3` accepted; a **negative pattern is refused**: `case x of -5 -> ...` is
"PROBLEM IN PATTERN ... I wanted to parse a pattern next" (a surprise: B# patterns are more permissive than Elm's). `2 + 3` as a pattern is a parse error; `case` with `5`/`0` and no `_` is "MISSING PATTERNS"
(control for the Int-exhaustiveness check). Elm has no refinements or guards, so there is no analogue to this ticket.
Summary: none of the four folds in a refinement; Erlang and Elixir keep the node and fold after parsing; Elixir and B#'s own `int_lit` fold only a signed literal; only Erlang folds arithmetic, and in patterns, not in the parser.

## Measurements (n = runs; us = microseconds; wall = `date +%s%N` around the CLI)

| | stock | gramA | gramB | gramC | chk | n |
|---|---|---|---|---|---|---|
| lex+parse, 30-clause module, min..median (us) | 77..113 / 89..128 | 88..128 | 86..116 | 78..115 | 101..130 | 2000 |
| `bs_check:check`, min..median (us) | 1261..1643 / 1223..1637 | 1247..1537 | 1227..1609 | 1482..1613 | 1486..1638 | 500 |
| same, signed source (`>= -100`), check min..median (us) | refused | 1515..1626 | 1206..1554 | 1545..1631 | 1223..1355 | 500 |
| CLI wall, min..median (ms) | 398..466 / 480..494 | 396..440 | 384..486 | 428..487 | 422..485 | 9 |
| .beam size, 8-function program (B) | 1392 | 1376 | 1372 | 1392 | 1392 | 1 |
| `bsc` diff in compiler source (lines added) | 0 | 1 | 1 | 6 | 25 | |

Stock appears twice per row (noise control); the two stock rows differ by 38 us at check-min and by 28 ms (median) / 82 ms (min) at CLI level. An earlier, uncommitted run of the same probe (before gramC was added)
read check min 1211..1226 for all builds, and the committed run 1206..1545: the spread is machine noise, **no build is distinguishable from stock**; the fold costs less than the noise. Call-time loop: not measured
(machine code is byte-identical by `beam_lib:md5`, F10). Compile memory: not measured.

## Options

All three are shown as the same B# input against the compiler. Prototype results are on patched copies (named), measured; nothing was applied to `compiler/`.

### Option 1 -- the sign is part of the integer literal, folded where `-5` is parsed (gramA)
```
type Delta = int where value >= -100 and value <= 100      // accepted
public Delta Low()
Low() -> -100                                              // accepted: -100 is the exact literal -100..-100
F(n) when n >= -5 -> :a ; F(n) when n < -5 -> :b           // accepted: the guard is read too
n / -0                                                     // now: divide_by_zero (stock: accepted)
type T = int where value >= -5 + 10                        // still refused: opaque_refinement (R07)
```
Compiler delta: `bs_parser.yrl:947`, one clause `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I}.` beside the float clause (gramA; 57_gramA.patch). Optionally rewrite the stale comment at `:586-590`.
Tests/gates to add first (CLAUDE.md order): F2 scenarios 6-8 (R01, R21, G01), one for E01, one for D01; `check-division.sh` row for `n / -0`; update `opaque_refinement` text to mention that arithmetic is not read.
Evidence: R01-R03, R15-R21, S01, G01, E01, E03 flip refused -> accepted; D01 flips accepted -> refused; eunit 1444/4 same as stock; beam code identical; `-(-5)` also reads (folded by recursion).
**Strongest counterargument, as its proponent for Option 2 would say it:** "The ticket's own design intent is that the refinement is an `expr` so the checker owns what is readable. Folding in the parser means
the checker can never see that the user wrote a *negation*; the day someone wants `-x` for a typed variable to carry the sign in a diagnostic, or `value >= -LIMIT` for a named constant, the parser has already thrown the shape away, and you'll be
writing the constant folder anyway -- you'll have two folds (parser for the literal, checker for the rest), which is exactly the double bookkeeping you were avoiding. And you changed `n / -0` and literal typing as a side effect of a refinement ticket."
(Reply: the F51 precedent already folds `-1.5` at that site for the same reason; F6 is a bug fix in ticket 38's direction.)

### Option 2 -- the sign stays a node; the checker folds constant arithmetic before it compares (chk)
```
type T = int where value >= -5 + 10          // accepted (R07);  value >= 2 + 3, 2 * 3 accepted;  10 % 3 refused (by choice)
public Delta Low()
Low() -> -100                                // REFUSED, with a misleading diagnostic (E01, quoted in F5)
n / -0                                       // still accepted (D01)
```
Compiler delta: `bs_check.erl:5016-5017` (`comparison/1`) reads its comparand through a new `const_int/1` (`e_int`, `e_neg`, `+ - *`) -- 25 added lines in 57_chk.patch; **plus** a second fold in
`type_of({e_neg,..})` (`bs_check.erl:2889`) to make E01/E03 compile (not prototyped -- stated, not measured); plus a decision for `/` and `%` (ticket 38's rounding rules) and for float comparands (R23 stays refused).
Evidence: R06-R09 and G04 accepted (only this option reads arithmetic); guards read it too (G01, G04); eunit 1444/4 same as stock; check time not distinguishable from stock.
**Strongest counterargument, as Option 1's proponent would say it:** "You are building an arithmetic evaluator in the type checker so the user can write `value >= -5 + 10`, which nobody has asked for (the ticket's only demand is `-5`; its examples are `-100`, `-5`, `-1`).
Every shape you fold is a spelling the residual printer must now also be able to produce and a spelling the clean-room implementers must replicate (the handoff is judged against this compiler): `2 * 3` accepted, `10 % 3` refused is a rule an outsider can only learn by trying.
And after all that, `Low() -> -100` is still refused with the 'no signature is offered' message -- the language would accept a type it cannot return a literal of."

### Option 3 -- narrow grammar at the refinement site only (gramC; the ticket's literal first option)
```
type T = int where value >= -5                              // accepted
F(n) when n >= -5 -> :a ; F(n) when n < -5 -> :b            // still refused: F is not exhaustive (F4)
public Delta Low() ; Low() -> -100                          // refused (E01)
```
Compiler delta: `bs_parser.yrl:221` `refinement -> expr_low : fold_refinement('$1')` plus a 4-line walker (57_gramC.patch). Measured: it passes R01-R03/R15-R21 and nothing else moves.
**Strongest counterargument, as its proponent would say it:** "It is the smallest change that touches only the thing the ticket is about; a guard that doesn't credit `-5` is its own defect with its own ticket, and bundling it risks the stale
claims in F2.5. It cannot change typing or ticket 38's divisor check, and no test anywhere can move." (Reply, measured: it creates the exact refinement/guard split F2.5 forbids, and it leaves the same literal unreadable one clause away.)

## Recommendation

**Option 1**, and treat arithmetic folding as a separate, optional later ticket (not gating, nobody asked for it). Reasons, each measured: it is one line (the float line it sits beside shipped in F51 for the same reason), it fixes the refinement,
the guard (F3) and the literal's type (F5) with a single change, it keeps refinement and guard in agreement (F4), it changes no emitted code (F10) and no test (F11), and its one behavioural side effect (`n / -0` now refused) is a case where
ticket 38 already says the answer. It also matches the two ecosystems that fold a sign at all (Elixir's expander `elixir_expand.erl:932`, B#'s own `int_lit`).
What would change my mind: (a) David wants `-5 + 10`/`2 + 3`/`2 * 3` readable -- then Option 2's checker fold is needed *in addition* (not instead); (b) a consumer (LSP, tree-sitter, `bs_api`) that wants the user's `-` spelling preserved; none found in `compiler/src`
(`e_neg` is read only at `bs_check.erl:2601,2889`, `bs_emit.erl:743,1067`); (c) if the D01 change is judged unwanted, gramC is the only no-side-effect choice, at the price of F4.

## Probe log

- `57_cases.sh` first version used signature-less functions; the compiler requires a signature (`public atom F(int n)`), so G/P rows were rewritten before any conclusion was drawn. Case labels were shortened (R22, E02) after a column overflow.
- First read of the ticket's table predicted every row refused by the same cause. It is, but G01 (guard) was not predicted: stock accepted *nothing* for it, and the diagnostic is misleading -- the biggest surprise.
- Expected `chk` to fix E01 (typed literal). It does not (F5): the two folds are independent sites.
- Expected gramB to be equivalent to gramA. It is not: `-(-5)` stays refused (the inner `-5` became `e_int`, the outer is still an `e_neg`), and `-2 * 3` regroups. yecc reports the same "6 shift/reduce, 0 reduce/reduce" for both.
- Elm: the first run was **confounded**. Missing `elm/json` made every row "refused", and after fixing that, my "no catch-all, should be refused" row failed for the wrong reason (it contained a `-5` pattern, which Elm refuses outright). Both fixed before the committed output; the added rows are `pattern 5 + catch-all (control)` and `no catch-all, no negative`. This is the ticket's own lesson (two features at once) recurring.
- Timing: stock's two rows differ by 38 us at min, which is why no timing claim is made beyond "not distinguishable"; a second full run (the committed one) gave different absolute numbers.
- `57_eunit.out` was produced by `SUMMARIZE_ONLY=1 57_eunit.sh` over logs of a real run (the run takes ~4 min x 4 builds in parallel); `57_run_all.sh` excludes it (too slow). gramC and the later api/boundary probes postdate it.
- `57_api.sh` was added after `57_run_all.sh` was first run and its line added to the runner; `57_build_variants.sh` got a comment-only edit after the final run.
- Not measured: call-time (code is identical), memory, tree-sitter/LSP behaviour on `-5` in `type ... where`, `ibs` REPL, non-`int` bases (`float where value >= -5.0` is refused on all builds, R23, and is outside this ticket), eunit on gramC, and Elixir/Erlang compile time.

## Probe index (run `cd /home/user/beam-sharp/artifacts/probes && . ./env.sh`; `./57_run_all.sh` rebuilds and reruns all except eunit, then `export V57=...` as it prints)

| probe | command | output that REFUTES the claim it supports |
|---|---|---|
| `57_build_variants.sh` | `./57_build_variants.sh` | any `BUILD FAILED` (patches do not apply to HEAD) |
| `57_stock.sh` (+`57_cases.sh`, `57_lib.sh`) | `./57_stock.sh` | R01-R03 accepted, or R04/R05 refused on stock |
| `57_variants.sh` | `V57=<dir> ./57_variants.sh` | a MUST-refuse row (R11-R14, R22, P03, E02) accepted on a patched build; gramC G01 accepted; chk E01 accepted |
| `57_ast.sh` / `57_ast.escript` | `V57=<dir> ./57_ast.sh` | stock block showing `{e_op,..'-',{e_int,..,0}..}` (ticket's AST) |
| `57_guard_runtime.sh` | `V57=<dir> ./57_guard_runtime.sh` | run results differing between builds; gramC guard row accepted |
| `57_residual.sh` / `57_algebra.escript` | `V57=<dir> ./57_residual.sh` | pasted heads in A/E/F printing `REFUSED`; algebra not `[{-10,-1},{1,10}]` |
| `57_boundary.sh` | `V57=<dir> ./57_boundary.sh` | `Id(-101)` or `Id(101)` returning a value; `Id(-100)` crashing |
| `57_nonzero.sh` | `./57_nonzero.sh` | `Id(0)` returning |
| `57_emit.sh` / `57_emit.escript` | `V57=<dir> ./57_emit.sh` | differing `beam_lib:md5` between builds, or differing `run:` lines |
| `57_timing.sh` / `57_timing.escript` | `V57=<dir> ./57_timing.sh` | a patched row's median clearly above stock's two rows' spread |
| `57_eunit.sh` | `V57=<dir> ./57_eunit.sh` (~4 min) | a failed-test name present in a patched build and absent from stock |
| `57_api.sh` | `V57=<dir> ./57_api.sh` | `type X = 1..5` accepted on stock |
| `57_erlang.escript` | `./57_erlang.escript` | parse output `{integer,_,-5}` for `-5.`; `f(2+3)` refused |
| `57_elixir.exs` | `elixir 57_elixir.exs` | `string_to_quoted!("-5")` returning the bare integer; `f(2 + 3)` compiling |
| `57_gleam.sh` | `./57_gleam.sh` | `-5` pattern or `n if n >= -5` refused; `2 + 3` pattern accepted |
| `57_elm.sh` | `./57_elm.sh` | `x >= -5` refused; `case x of -5` accepted |
