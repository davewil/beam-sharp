# Verifier report, ticket 57 (ENG-239) brief

Verified 2026-10-27 by an independent run. Temp dir: `.../scratchpad/verify57` (scripts copied there, `W` pointed at a fresh scratch build, so no author file was written). OTP 25.3, Elixir 1.14.0. Fresh outputs are `verification/*.rerun.out` and `verification/extra_*.out`.

## Verdict in one paragraph

The four "findings the ticket doesn't state" reproduce exactly and are not artefacts of the lexer shim. The recommendation (Option 1) is supported on the narrow facts measured. But three things need softening. (a) The `n / -0` finding is real, but the hole is wider than the brief says, and A1 closes only the literal spelling. (b) The Elixir paragraph is incomplete. (c) The "no regression" claim rests on a test run in which the checker-diagnostic tests cannot run at all. Details below.

## Per-probe reproduction

| probe | reproduced | notes |
|---|---|---|
| 00_build_scratch | yes | Builds. Shim is exactly `TokenLoc` -> `{TokenLine,1}` plus `adjust_col/3`; I diffed it against `compiler/src/bs_lexer.xrl` and nothing else differs. All other `compiler/src` files are byte-identical to the scratch copy. |
| 01_baseline | yes, byte-identical | AST `{e_neg,_,{e_int,_,5}}`; pattern `{p_rel,_,'<=',-1}`; the ticket table holds. |
| 02_guards | yes, byte-identical | Control `>= 0 / < 0` accepted; `-1`, `!= -1`, `1 - 2`, `2 + 3` refused `inexhaustive`; switch arm `switch_inexhaustive`. |
| 03_build_variants | yes | 6 s/r conflicts everywhere. The regenerated patches differ from the author's only in the timestamp header. |
| patches | yes | I applied each `fix_*.patch` with `patch -p0` to a pristine copy of `compiler/src` (`bs_parser.yrl` or `bs_check.erl`). Each result is byte-identical to the author's variant source. Changed lines: A1 1, A2 5, B1 10, B2 20, B3 21. |
| 04_matrix | yes, byte-identical (all six builds) | I also diffed each variant against baseline row by row. Every claim in the brief about acceptance and refusal matches. |
| 05_regression | yes (635 failing tests in all 6 builds, same sets) | B1's one-test difference did not recur in my run, so it is a flake. See the regression section. |
| 06_erlang | yes, byte-identical | OTP citations `erl_parse.yrl:270` and `erl_lint.erl:1880-1893` are correct for the installed stdlib 4.3.1.3. |
| 07_elixir | yes, byte-identical | The falsification is reported honestly. The summary is incomplete; see below. |
| 08_elm | yes (403 as expected) | I did not work around it. |
| 09_residual_roundtrip | yes, byte-identical | |
| 10_cost | not byte-comparable (timing) | Same conclusion: within noise (my range 121-146 µs for check/1). |
| 11_e2e | yes, byte-identical | |

## The four findings

1. **AST is `e_neg`, not `0 - 5`.** Stands. `bs_parser.yrl:591` is the rule (the brief's "587-591" is the comment block plus the rule), `negate/2` is at `:947`. The shim only changes locations, so it cannot affect this.
2. **Guards refused as inexhaustive.** Stands. I printed the full refusal (`extra_residual_text.out`): residual `ints => [{neg_inf,pos_inf}]`, exactly "all of int". A one-clause catch-all makes the same program accepted, so the guard is credited nothing and no other defect is involved (`extra_probes.out`). Citation drift: the "credited nothing" line is `bs_check.erl:5125-5126`, not `:5127`.
3. **Body `-1` typed `int`.** Stands. `NonPos F() -> -1` refused `return_not_declared` at baseline, `Pos F() -> 1` accepted as the control. The `:2963-2973` citation is right.
4. **`n / -0` passes and badariths.** Stands and reproduced at run time (`Div(10) -> {error,badarith}`). But see "must soften" below: `n / (1 - 1)` and `n / (0 - 0)` are also accepted at baseline and are still accepted under A1. The hole is "any provably-zero divisor that is not a bare literal", not "-0". A1 fixes only the spelling that the brief tested.

**Could the shim (every column = 1) affect these?** Not these four. Each is a verdict from `check/1` on a program with one construct per line, and none reads a column. Two real shim hazards exist and the brief mentions neither. (i) `bs_check.erl:114-120` keys internal notes (valve prunes, bare-name arities) by `{Path, Line, Col}`, so with all columns equal, two nodes on one line collide. None of the probe programs has a note-bearing construct twice on a line, so I found no effect on the probes, but the eunit comparison below is exposed to it. (ii) OTP 25 leex reports lexer errors with an integer line, not `{L,C}`; `negation_tests:bang_is_taught_test` fails at baseline in `bs_diag:message/1` with `function_clause` for that reason. I could not build a real-column shim: OTP 25 leex rejects `{error_location,column}`.

## Regression claim (assess)

- 635 failing of 1466 `_test()` plus 29 `_test_()` generators reproduces exactly, in 48 of 73 modules, in every build. The failing sets are identical across baseline, A1, A2, B1, B2, B3 in my run (`05_regression_failset.rerun.out`).
- The failures are only partly explained by the environment. I counted 37 `maps:iterator/2` undefs (OTP 26+ function, so OTP 25), 25 `no_escript` throws (the bsc escript is not built), and 16 other `undef`s. The remaining ~500 are `assert` or `assertEqual` failures. The tests I opened (`non_numeric_operand_tests`, `corrected_signature_tests`) call `bs_test_support:run_cli`, which drives the bsc escript. The CLI is not usable here, so its output is empty and the assertions on diagnostic text fail. That is consistent with an environment cause, but the brief says "I did not triage" and I only triaged a sample.
- That makes the comparison blind exactly where the patches act: diagnostics, residuals, floats. At baseline, 10 of 36 `float_tests` fail (including `a_negative_zero_head_is_its_own_case`), all 16 of `float_reads_integer_tests` fail, 5 of 35 `intervals_tests` fail and the whole `corrected_signature_tests` residual group fails. The ~860 passing tests did not turn red under any patch. "Identical failing set" is therefore supported, but it is not evidence that A1 is safe against F51's float behaviour, and the brief does say so in its limits. It should say it in the Option 1 evidence bullet too, not only at the end.
- The `05_regression_diff.txt` in the author's folder is not produced by `05_regression.sh` (the script only prints failing module lists). The 635 counts and the diff are reproducible only by the extra step I ran (counting `*failed*` lines in `result.txt`); the script has no such step.

## Circular, weak or overstated

1. **B3 is tuned to the probe that it is then said to pass.** B2 failed `P1`/`P3`, so B3 adds exactly the `type_of` clause that was seen to be missing. "B3 reaches the same end-to-end results as Option 1" is true by construction. The honest evidence is that Option 2 needs two edits; the brief says that, and I only flag that B3's green is not independent support.
2. **A2 is a strawman for Option 3, with an artefact.** A2's `fold_neg/1` does not recurse into `e_neg`, so "A2 still refuses `-(-5)`" says something about that patch, not about Option 3. And the claims "guards still inexhaustive, `n / -0` still compiles" are true of any refinement-only fix by definition. The brief's "Strongest counterargument: none" overreaches. A refinement-only fix plus a separate guard fix is a fair rival that no variant tested.
3. **"A1 is the only variant that fixed all four with one edit"** is correct, but it is partly a tautology: making `-N` a literal everywhere necessarily fixes everything that consumed the literal. It is a fair reason, not an independent measurement.
4. **Option 1 example vs measured program.** The brief shows `Delta` as -100..100 with `Clamp(n) when n < -100 -> -100`, but the e2e probe ran -10..10. The shown program was never run. The quoted results (`Clamp(-99)=-10`) belong to the ±10 variant.
5. **Residual probe cannot see the lower bound** when the clauses cover `<= 0` (rows `>= -5 and <= 5` show only `1..5`). Only `09_residual_roundtrip` (`F(0)` alone, ±10) shows both bounds. Fine, but the matrix residual rows do not by themselves prove the -5 bound is right.
6. **The round trip is checker-agreeing-with-itself.** The pasted-back text was typed by the author, not extracted from the rendered residual by the probe. It shows the printed residual is readable, not that tools can round-trip it. "Answers ticket 38's worry" is a little strong.
7. **Cost numbers are selective.** The author's `10_cost.out` holds three runs; the brief quotes 129-154 µs and omits values from 83 to 146 for the `-5` inputs. The conclusion (noise) holds; the range is cherry-picked. B2 `+ - * / %` is called "about 12 lines" but the patch is 20 changed lines.
8. **"Not checked against bs_emit's lowering on negative operands" is discharged by reading**: `bs_emit.erl:1431-1432` lowers `/` to `div` and `%` to `rem`, the same operators B2 folds with. Only the claim about float operands remains open, and B2 folds integers only.
9. **A1 side effect not listed.** `to_param/1` and `to_match/1` (`bs_parser.yrl:885, 933`) accept `{e_int,...}`, and A1 makes `-1` such a node. I measured it: `(-1) => 0` is a parse error at baseline ("a lambda's parameter is a pattern ...") and under A1 it parses and reaches the checker (`lambda_param_refuted`). That is a language-surface change (arguably good) that the brief's "anything downstream matching `e_neg`" list does not mention. The grep behind "only four sites mention `e_neg`" is RECORDED, and my grep agrees for `src/`.
10. **Claim 5 (no negative literal in a refinement or `when` in tests or examples)** holds for `compiler/test` and `compiler/examples`. But tickets 42, 43 and 23 write guards such as `Classify(n) when n <= -1` as the "real head"; those would be refused by the checker today. This supports the brief and could be cited.

## Elixir (must soften)

The author's prediction (Elixir folds early) was falsified for guards, and the brief says so honestly. But the summary "Elixir leaves folding to the Erlang compiler" is incomplete. I compiled `def f(-5)` and read the emitted forms (`extra_elixir_pattern.out`): the pattern head holds `{:integer, [...], -5}`, a folded literal. The guard form keeps `{:op,1,:-,{:integer,1,5}}`. So Elixir folds `-N` into a literal in pattern position (Option 1's behaviour, done in the expander, not the reader) and leaves it unfolded in guards. The neighbour evidence is split, not one-sided toward Option 2. Also, Elixir rejects `f(1 + 2)` in a pattern, which the brief states. The Erlang evidence stands as written.

## Citations checked

| citation | verdict |
|---|---|
| `bs_parser.yrl:587-591`, `:947`, `:221` | correct (591 is the rule; 587-590 comment) |
| `bs_check.erl:5154-5155`, `:5121`, `:2963-2973`, `:4338-4346` (real `:4338-4348`) | correct / close |
| `bs_check.erl:5127` | off by 1-2 (the line is 5125-5126) |
| `bs_diag.erl:2019-2026` | correct (message continues one line further) |
| `bs_check.erl:2675`, `:2963`, `bs_emit.erl:743`, `:1067` for `e_neg` | correct |
| `erl_parse.yrl:270`, `erl_lint.erl:1880-1893` | correct for OTP 25 (repo pins OTP 28.5; lines may differ there) |
| "ticket 38 ... `bs_lexer.xrl`" for `/` = div | the lexer comment is at `:182`; the lowering is `bs_emit.erl:1431-1432`, which is the better citation |

## What stands, and what must change

Stands (reproduced): the AST shape; the guard and switch exhaustiveness refusals; the body typing; the `-0` run-time `badarith`; every acceptance row in the matrix for A1, A2, B1, B2, B3; the e2e results for A1 and B3; no new yecc conflicts; the Erlang survey; Elm blocked; Gleam unavailable; Elixir `{:-,_,[5]}` reader shape and `1 + 2` refusal.

Soften or fix before the brief is used:
- Finding 4: say that any constant-arithmetic divisor (`n / (1 - 1)`) still passes under every variant, so A1 narrows the hole and does not close it.
- The Elixir bullet: the pattern form is folded to a literal by the expander; only guards stay unfolded.
- Option 3's "no counterargument": note that A2 is a deliberately minimal patch and that a refinement-only fix paired with a guard fix was not tested.
- The Option 1 end-to-end line: say the program run was ±10, not the ±100 program shown.
- The Option 1 eunit bullet: say there that 635 of ~1,495 fail at baseline, including F51 float tests (10 of 36), and that the failing tests are CLI-driven, so the comparison cannot see diagnostics or residual text.
- Add the A1 side effect on lambda parameters and bare `=` patterns.
- Cost range and "about 12 lines" (actually 20).
