# Verification of the ticket 57 brief (independent re-run, 2026-10-04/05)

Method: fresh copies of `compiler/` (tar, no `_build`; `compiler/` is byte-identical to `662e92f`, `git diff 662e92f HEAD -- compiler` is empty) under
`<scratchpad>/v57/{base,grammar,checker_min,checker_wide,checker_full,refine_only,real_c}`; each patch applied by me with `patch -p0`, rebuilt
with `rebar3 escriptize` on OTP 28. Nothing under `compiler/`, `wayfinder/`, the brief or the author's probes was edited. Re-run outputs are in `verify/`.

## 1. Probe re-runs

| probe | result |
|---|---|
| 00 (ticket's 38b) | REPRODUCED, byte-identical (`verify/00_38b.out`) |
| 01, 03, 04, 05, 06, 07, 08, 17, 18, 19 on every variant | REPRODUCED. Identical to the author's `.out` after normalising tmp paths. The only differences are additions (the author kept `refine_only` in separate files; 05 omits it). Files: `verify/*.allvariants.out`, `05_composite.out` |
| 02, 21 (AST) | REPRODUCED (`{e_neg,L,{e_int,L,5}}` base and B-full; `{e_int,L,-5}` under A) |
| 10 Erlang, 11 Elixir | REPRODUCED, identical |
| 12 Gleam | REPRODUCED (diff is only compile time and a tmp path) |
| 13 Elm | NOT REPRODUCED, confirmed. `elm make` and `elm repl` both stop at `package.elm-lang.org` 403 through the proxy, and `~/.elm` is empty. `github.com/elm/core` also returns 403. No Elm claim is made in the brief beyond that, which is correct |
| 14, 20 | REPRODUCED |
| 15 timing | Check-phase reductions REPRODUCED exactly (4,843,371 / 4,581,074 / 4,666,328). Parse reductions are NOT stable: they moved by about 1% run to run, base 520,275 vs 523,310. The brief calls reductions "load-independent", which is only roughly true. The conclusion (no option has a cost worth noting) stands |
| 16 eunit | REPRODUCED. Per module on base, grammar (A) and checker_full (B-full): 65 modules, 1309 tests, 0 failures, 0 retries, and per-module lines identical across the three and identical to the author's (`verify/16_eunit_*.out`) |

No verdict changes anywhere.

## 2. Factual claims

- AST: the ticket's `{e_op,'-',{e_int,0},..}` is stale. The ticket line 51 quotes the pre-F51 rule. Today it is `negate/2` giving `e_neg` (`bs_parser.yrl:589` the rule, `:944-945` the float fold then `e_neg`). CONFIRMED.
- `bs_parser.yrl:470` `int_lit -> '-' integer`, `:221` `refinement -> expr_low`, `:218-220` the comment: CONFIRMED.
- `erl_lint.erl` (stdlib-7.0): `:2134-2147` is `is_pattern_expr` using `erl_eval:partial_eval` (the call is at 2140); `:3432-3436` is the range check requiring `X < Y`; the message `bad ~tw type` is at 555. CONFIRMED. `sys_core_fold.erl:896/906` (`fold_call_2`/`fold_lit_args`) exist, in compiler-9.0.
- `bs_emit.erl:704-711` `kind_expr`; `:669` `rel_expr` builds `{e_int,_,K}` with negative K; `bs_check.erl:2867` and `:2874-2884`; `comparison/1` at 4949-4955: CONFIRMED.
- (a) guard `n >= -5` earns no exhaustiveness credit, and a catch-all after it gets no unreachable warning: CONFIRMED (base: GuardNeg_Complete refused; CatchAllNeg no warning).
- (b) the printed residual from `LANGUAGE.md` §3 (lines 449-465) pasted back is refused again on base and `refine_only`, accepted on A, B-min, B-wide and B-full: CONFIRMED.
- (c) `F(:x)` returns `:hi` with `n >= -5` and `:other` with `n >= 5`: CONFIRMED. The claim that the emitter skips the kind test: CONFIRMED by the source (`kind_expr` matches only `{e_int,..}`) and by behaviour.
- (d) `-5` is typed `int`, not `-5..-5` (`NegCall`, `NegReturn` refused on base, accepted on A and B-full): CONFIRMED.
- `x / -0`: crashes with badarith on base, refused as "always zero" under A and B-full: CONFIRMED.
- `value == 3` gives `compile: a.bs:0: bad range type` on unpatched HEAD (`EqPos`): CONFIRMED. No hit for `bad range type` in `wayfinder/issues` or `compiler/features`: CONFIRMED.
- Flag, minor. "No existing test pins a negative integer literal in an expression": false as worded. `comprehension_tests.erl:321` (`Both([1, -1], [2])`) and `:430` (`[(0, -5)]`) have negative literals in B# source. They pass under every variant because they do not depend on the type or the coverage. The conclusion (nothing pins symptoms 1-4) holds.
- Flag, minor. Probe 08 does not by itself separate B-min from base: `NegLit` and `NegLitCredited` give the same output on base (`:hi`, `:int_hi`) as on `checker_min`. The runtime divergence is the pre-existing emitter hole. See 3(iii) for the demonstration that does separate them.

## 3. Circularity audit

(i) Discrimination. Every probe that the brief uses for a claim shows a different result on unpatched `bsc` (for example `GuardNeg_Complete` refused on base and accepted on A, B-min, B-wide and B-full). Positive-literal controls (`PosCall`, `GuardPos_Complete`, `PastedPos`, `PosLit`) are accepted on base, so the probes can go both ways. Probes 02, 05, 21 pipe through `grep`, but only to select lines. Their output comes from the real lexer, parser and `bsc`.
No hand-written `.out` was found. `00_*.out` has no `.sh` beside it, but it is the output of the ticket's own `wayfinder/prototypes/38b_divisor_expressiveness.sh`, which I re-ran and which matched.

(ii) Option C. The brief says a genuine narrowed grammar "was not built" because yecc "has no clean way". I built one (`verify/realC_grammar.diff`): `refinement` becomes its own `or`/`and`/comparison ladder whose comparand is `int_lit` (or an atom for `==`/`!=`), about 20 lines. Result:
 - yecc conflicts: 6 shift/reduce on base and 6 on real C. It adds none, so "no clean way" is overstated.
 - The ticket table is fixed (6/6 accepted), exactly as `refine_only`.
 - Symptoms (a)-(d) all remain, identical to `refine_only`: `GuardNeg_Complete` refused, `Pasted` refused, `NegCall` and `NegReturn` refused, `F(:x)` returns `:hi`, `x / -0` still crashes (`verify/realC_all.out`). The brief's claim "C leaves (a)-(d)" is CONFIRMED on the real thing.
 - Differences from the proxy that the brief does not mention: `value >= -(5)`, `(-5)` and `- -5` become syntax errors (the proxy accepted the first two); every unreadable refinement (`value >= n`, `value + 1 >= 5`, `WellFormed(value)`) becomes a bare `syntax error before: ...` instead of the `opaque_refinement` message; and the existing test `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test` FAILS (it expects `{opaque_refinement,_}`). The other 8 refinement-related modules pass (`verify/realC_eunit_subset.out`).
 - Verdict: the proxy is a fair, even generous, stand-in for C on the ticket table and on (a)-(d). It is not rigged. The brief's stated reason for not building C is wrong, but its conclusion about C holds, and the real C has an extra cost the brief missed.

(iii) B-min / B-wide unsoundness. Reproduced as stated (`F(:a)` returns `:int_hi` on `checker_min` and `checker_wide`). A sharper reproduction that separates them from base (`verify/iii_bmin_callee.out`):
```
public int G(int x)
G(x) -> x + 1
public int F(int | atom n)
F(n) when n >= -5 -> G(n)
F(_) -> 0
```
 base: refused ("argument 1 is not covered ... atom"); `refine_only`: refused; A and B-full: accepted, `F(:x)` returns 0; B-min and B-wide: ACCEPTED, then `F(:x)` crashes with `function_clause` in `G`. So B-min and B-wide let a program through that the checker called well-typed and that breaks its own signature at run time. Unsound CONFIRMED, and it is stronger evidence than the brief's probe 08.

(iv) Other flags.
 - The kept `eunit_whole_suite_aborted_*.log` files: the brief says load aborted them. Not quite. Base and checker_min logs are identical (302 lines, same cut-off point). Each contains a real `*timed out*` (`clause_block_tests`, load) AND deterministic environment failures: `body_check_tests:297` (`../aoc` not beside the copy) and `cli_tests:355` (locale). The cause is not a patch (the base copy fails the same way), but "load-related" is only half the story. The per-module runs fixed the environment, and I reproduced them with no retries at all.
 - No probe was found edited after a prototype failed it. The runner `16_eunit_per_module.sh` retries up to 4 times, but nothing retried in my run.
 - The brief gives `checker_min`, `checker_wide` and `refine_only` no eunit run. It says so itself.

## 4. Neighbours
Erlang, Elixir 1.14 and Gleam 1.12 outputs match the brief's quotes. Elm: not reproducible offline (see 1).

## Verdict
PASS: all probe re-runs; AST and citation claims; (a)-(d); `x / -0`; S6 `bad range type`; eunit 65/1309 on three builds; neighbour surveys.
FLAG: (1) the reason given for not building C is wrong, and a real C fails an existing test; (2) probe 08 alone does not separate B-min from base, so use the `G(n)` program; (3) "no existing test pins a negative literal" is too broad; (4) the abort logs are load plus environment, not load alone; (5) reductions are about 1% noisy.
Safe to rely on: YES, WITH CAVEATS. The recommendation (A, or B-full if the type of `-5` must not change; never B-min or B-wide; C leaves the four symptoms) is supported by everything I re-ran.
