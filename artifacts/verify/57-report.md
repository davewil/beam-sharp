# Verification of the ticket 57 brief (negative literals in refinements)

Verifier: independent. Reruns in `/tmp/v57.aRvAKk/probes` (copy of probes) with variants built in `/tmp/p57w.4F7CGR`. Nothing in the repo was edited except the new `artifacts/verify/57/` files and this report. My own probes and logs: `artifacts/verify/57/`.

## Bottom line: YES WITH CORRECTIONS

Recommendation (option 1, one line in `negate/2`) is supported. I could not refute (c) or (d). Corrections (all small) are listed at the end.

## 1. Probe table (rerun with the listed commands; `57_run_all.sh` run from a copy, 3m20s)

| probe | verdict | note |
|---|---|---|
| 57_build_variants | REPRODUCED | all 5 builds OK, warnings-as-errors; patches apply to HEAD |
| 57_stock (R01-R05..) | REPRODUCED | identical to saved |
| 57_variants | REPRODUCED | identical verdict table, all MUST-refuse rows hold |
| 57_ast | REPRODUCED | stock = `{e_neg,l,{e_int,l,5}}` |
| 57_guard_runtime | REPRODUCED | |
| 57_residual / algebra | REPRODUCED | |
| 57_boundary | REPRODUCED | |
| 57_api | REPRODUCED | |
| 57_nonzero | REPRODUCED | |
| 57_emit | REPRODUCED (md5), size DIFFERS | beam_lib code md5 identical on all 6; gramA size 1380 B now vs 1376 B saved (stock 1392). So "16 B smaller" is 12 B this run; size shifts with debug-info path text. Immaterial. |
| 57_timing | REPRODUCED in substance | absolute numbers differ (noise) |
| 57_erlang / 57_elixir | REPRODUCED | |
| 57_gleam | REPRODUCED | only temp-dir paths differ |
| 57_elm | REPRODUCED | only progress-bar text differs |
| 57_eunit | REPRODUCED (see below) | |

### Compile time (mine, n=15 CLI wall, interleaved, 2 stock rows as control; ms min/median)
stock 350/384, stock2 381/403, gramA 356/406, gramB 339/395, gramC 348/409, chk 344/393. In-VM check n=500 x3 repeats: all builds 1204-1578 us min, 1278-1880 us median, with stock-to-stock spread as large as any variant difference. Claim "not distinguishable from stock" REPRODUCES. (File `v57_g_timing.out`.) Brief's table size/diff-line counts: gramA +1, gramB +1, gramC +6/-1, chk +25/-2 confirmed from the patches.

### eunit, full run, stock and gramA (each ~2.5 min, run in parallel)
Both: `Failed: 4. Skipped: 0. Passed: 1444.` Identical failure list (logs `eunit_stock.log`, `eunit_gramA.log`):
1. `body_check_tests:every_aoc_program_still_compiles_test` -- `length(Dirs) >= 3` false
2. `cli_tests:batch_runs_every_entry_in_one_vm_and_attributes_each` -- expected `"héllo"`, got `"h\xFFllo"`
3. `diagnostic_json_tests:a_path_is_utf8_on_the_wire_test` -- `café.bs` not found in output
4. `non_numeric_operand_tests:a_non_ascii_literal_is_advised_as_written_test` -- `café` vs `caf\xFF`

Is "environmental" true? YES, and I proved it: failures 2-4 are the shell having `LANG`/`LC_ALL` unset (POSIX locale). Failure 1 is because the test looks for `<project_root>/../aoc` and the mktemp copies have no sibling `aoc/`. With `LC_ALL=C.UTF-8` and a symlink `aoc` next to the copy, those four test modules (114 tests) all pass on BOTH stock and gramA.
Caveat the brief does not state: because test 1 failed, the eunit run did NOT exercise the aoc corpus for either build. I compensated: `v57_f_corpus.sh` compiles all 38 module dirs in `aoc/` and `compiler/examples/` (incl. exemplars) with stock and gramA: diagnostics byte-identical in all 38 and the 29 resulting beams have identical `beam_lib:md5` (`v57_f_corpus.md5s`). gramB/chk/gramC eunit not re-run by me (brief only claims gramB/chk).

## 2. Circularity review
No circular probe found. Every patched-variant claim has an unmodified stock control run through the same harness (`57_stock.sh <bsc>` per build), and the saved results come from running, not from hard-coded expectations. Weak spots:
- `try()` in 57_lib.sh calls a row "accepted" when the declaration compiles; it never uses the type. R17 (`value == -3`) reads "accepted" on gramA but using it in a function crashes the compiler: `compile: a.bs:0: bad range type`. This is a PRE-EXISTING bug for any one-value refinement, positive too: stock `type T = int where value == 5` / `>= 5 and <= 5` / `> 4 and < 6` / `== 0` crash the same way (`v57_c_singleton.out`). So not a regression of the fix, but R17 "flips to accepted" is overstated and the pre-existing crash is unreported. Rows `>`, `!=`, `>= -0`, `>= -5` etc. I verified usable (`v57_e_usable.out`; crashes at -3 are correct function_clause for excluded values).
- 57_eunit.out is a SUMMARIZE_ONLY summary of logs; it matches what I got (4 same names).
- 57_elm.sh header claims "(1) `-5` accepted as a pattern", the output (and the brief) say refused. Stale header text, not the finding.
- Pasted-heads probe (57_residual) greps the diagnostic's heads and requires an empty compiler output; warnings would count as REFUSED, so it is conservative. Confirmed independently (below).

Patched variants (applied to fresh stock copy by the build script; `diff` of src):
- gramA: `bs_parser.yrl`, +1 line: `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I};`. Stock differs on the same inputs (table above).
- gramB: +1 line: new rule `expr_low -> '-' integer`. Regroups `-2 * 3`; stock differs.
- gramC: +6/-1, `refinement -> expr_low : fold_refinement('$1')` plus a 3-clause walker (refinement-only).
- chk: `bs_check.erl` +25/-2: `comparison/1` reads comparands via new `const_int/1` (e_int, e_neg, + - *).
Stock differs from each on R01 and (gramA/gramB/chk) G01, as claimed.

## 3. Headline claims
(a) AST claim stale: CONFIRMED. Stock `{e_op,l,'>=',{e_var,l,value},{e_neg,l,{e_int,l,5}}}`; negate/2 is `bs_parser.yrl:947-948`, rule at `:591`.
(b) "Unspellable residual" false: CONFIRMED on stock with my own program. `F(<= -11) F(>= 11) F(0)` over bare `int` prints `F(>= -10 and <= -1)` / `F(>= 1 and <= 10)`; pasting both compiles and runs (`F(-5)=:n F(5)=:p F(0)=:z F(-11)=:a`).
(c) Option 1 makes refinement, guard and literal type work: CONFIRMED, could not refute. Refinement (`>= -5`, `>= - 5`, `>=-5`, `-5 <= value`, `-(5)`, `- -5`, `-0`, `-9223372036854775809`, alias in a record field) accepted and behaves right at runtime; guard pair `n >= -5` / `n < -5` exhaustive; `Low() -> -100` into `Delta` accepted, `-101` refused; dead-clause warning works with negative bounds (`F(<= -6)` over `>= -5` warns "matches no value"). `5 - 3`, `x-5`, `x - 5`, `x -5`, `a - -5`, `-x - -5`, `2 - 3 - 4`, `-2 * 3`, `-2 + 3`, `-7 / 2`, `n / -1`, `5.0 - -3.0`, `x - -5.0`, `-0.0` give identical results on stock and gramA (`v57_a_expr.out`). Float `-5.0` refinement still refused on both (outside scope). `n -1` as call-like text is a syntax error on both (not a regression).
A bonus the brief undersells: stock refuses `F(-1)` into `NZ = int where value != 0` ("hands F an argument it does not accept") and `var k = -1; G(k)`; gramA accepts (literal now typed exactly). Real bug fixed by the same line.
(d) `n / -0` becomes divide_by_zero: CONFIRMED (stock: compiles, runtime `badarith`; gramA refuses "right-hand side of `/` ... is always zero"). Extension: `n % -0` flips the same way. `n / (0 - 0)` unchanged.
Other side effects found: bare-match LHS `-5 = n` changes diagnostic from "left of a bare `=` must be a literal pattern" to "this bind can fail" (same as `5 = n`); still refused, no acceptance change.
Not testable: record-field inline `where` does not exist as syntax (`record R { Temp: int where ... }` is a syntax error on both); the alias form works.

## 4. Citations
- elixir_expand.erl: fetched v1.18.5; lines 931-932 `{erlang,'+',[Arg]} when is_number(Arg) -> {+Arg,SL,E}; {erlang,'-',...}` CORRECT (brief cites :932 and :931-932). It sits in the `true ->` branch of `expand_remote` for atom receivers outside `Context =:= nil`, i.e. match/guard. Matches the brief's description.
- Erlang (stdlib-7.3.0.3, compiler-9.0.6.3 in the nix store): `erl_parse.yrl:269, 301, 1819` CORRECT; `erl_lint.erl:2140` `erl_eval:partial_eval` CORRECT; `erl_eval.erl:2204` partial_eval and `:2214` `ev_expr({op,_,Op,L,R})` CORRECT; `sys_core_fold.erl:906 fold_lit_args` CORRECT.
- B# cites: `negate/2` :947, rule :591, `e_neg` consumers only at bs_check.erl:2601, 2889, bs_emit.erl:743, 1067 -- CORRECT (grep). `type_of({e_int..})` -> exact range, `e_neg` -> operand-kind: CORRECT (bs_check ~2882-2889).
- Gleam 1.19.2: rerun, all rows identical (pattern -5 ok, `- -5` expr ok with warning, guard and pattern syntax error, `2 + 3` pattern syntax error, `const lo = 2 + 3` refused, inexhaustive for guarded pair).
- Elm 0.19.2: rerun identical. Could the faked registry cause the negative-pattern refusal? No: the failure is a PARSE error ("I wanted to parse a pattern next") raised after "Dependencies ready!"; positive-pattern control `5 -> ... _ ->` and `x >= -5` are accepted in the same environment, and elm/core is the real cloned package. The refusal is syntactic. (I did not independently confirm against a stock registry.)

## 5. My extra probes (artifacts/verify/57/)
- `v57_a_expr` / `v57_b_typing` / `v57_d_more` / `v57_h_pat`: ~80 expression, typing and pattern programs run on stock vs gramA (lexing, `-0`, big literals, bignum refinement bound, floats, record alias, switch ranges, refined-argument typing, dead-clause warnings, match LHS). No case where stock accepts and gramA refuses; only expected flips.
- `v57_c_singleton`, `v57_e_usable`: found the pre-existing one-value-refinement compiler crash and the shallow-"accepted" issue.
- `v57_f_corpus`: 38 real module dirs, diagnostics and beam code identical stock vs gramA.
- eunit stock and gramA in full, plus UTF-8/aoc rerun proving "environmental".
- `v57_g_timing`: independent timing, n=15 interleaved.

## Corrections to the brief
1. R17 (`value == -3`) "accepted" is a declaration-only result; any use crashes the compiler with `bad range type`, a pre-existing bug shared by positive one-value refinements on stock (say so; do not list R17 as fixed in use).
2. F11 / eunit: say that the aoc test fails in the mktemp copies for a layout reason, so aoc was not exercised; I covered it (38 dirs identical).
3. `.beam` size delta on gramA is 12 B this run (varies by path); D01 side effect also covers `n % -0`.
4. `-5 = n` diagnostic changes (minor side effect, no acceptance change).
5. 57_elm.sh header text contradicts its output.
