# Verification of the ticket 57 brief

Verifier run 2026-10-07. Own bsc built from `compiler/src` (leex with `{error_location,column}`, yecc, erlc; OTP 28), own copies of each patch applied with `patch`, scratch in `/tmp/claude-0/vf57`. No repo file other than this one was touched. A container restart killed the first eunit run; its outputs survived, and the two variants it had not finished (v2, v2c) were completed on the relevant modules (below).

## Verdict

**Brief is VALID with caveats.** Every probe reproduces byte-identically (paths normalised). Option A fixes all four symptoms and runs correctly. No circularity found. Corrections are listed at the end.

## Per-probe verdict

| Probe | Verdict | Notes |
|---|---|---|
| 57a repro table | VALID | Re-run: output identical to `.out` (18 ok, fails=0). Ticket's five rows hold. Controls can fail: `ZeroRejected` and `GuardNegWithCatchAll`. Weakness: `probe` records only accepted/refused, not why; I checked first diagnostic lines, all `opaque_refinement` text except `GuardNegCovers` ("S is not exhaustive"). `NegFloat` is refused for an unrelated reason (float comparand, never read by `int_cmp`); it is not evidence about `negate/2`. |
| 57b `-3` typed int; bare `=` | VALID | Identical. `Id(-3)` diagnostic `int >= 4`; `PosBare` reaches a different diagnostic, so the control separates sign from structure. |
| 57c Erlang/Elixir | VALID | Identical. Erlang `-5` is `{op,'-',{integer,5}}`, `0-5` is a binary op, `normalise` gives -5, `is_pattern_expr(2+3)` true, `X-5` false; `neg.erl` compiles and returns a b yes; `bad.erl` gives `illegal pattern`. Elixir `{:-,_,[5]}`, `n - 5` pattern refused. |
| 57d Gleam 1.18.1 | VALID | Identical. Pattern `-5` and guards `>= -5`, `>= 2 + 3`, `>= m` compile (the emitted Erlang keeps `(2 + 3)`, so Gleam does not fold in the guard); `- -5` is a syntax error; controls refused. |
| 57e matrix | VALID-WITH-CAVEAT | Case matrix, bare-`=` diagnostics, abstract-code diffs, Code-chunk md5 (390D44...) identical to `.out`. Caveats: (1) `.beam` byte sizes are path-dependent. In my build v0=1156, v1=1148, v2/v3=1156, v2b/v2c=1160; the brief's 1344/1332 came from other directory names. Only "v1 smaller" survives; "A is 12 bytes smaller" and "all others equal" do not. (2) The matrix collapses refusal reasons: v3's `Call_refinement`, `Var_comparand`, `Neg_residual` "refused" are syntax errors, v0's are `opaque_refinement`. (3) Timing, see below. |
| 57f eunit | VALID-WITH-CAVEAT | Full run (65 modules) completed for v0, v1, v2b, v3; v2 and v2c stopped at 60 modules when the container restarted. Failed-test lists: v0, v1, v2b identical (5, md5 equal); v3 = those 5 plus `intervals_tests:an_unreadable_refinement_predicate_is_an_error_test` (assertException: got `{error,{{4,24},bs_parser,...}}`, a parse error, not `{opaque_refinement,_}`). v2 and v2c: their 60 completed modules show the same 5 failures and nothing else; the refinement/guard-relevant modules (intervals, guard_kind, guard_call, heads, boundary_range, negation, float, division, validate_as, switch, types, comprehension, corpus) re-run on both pass. Caveat on the 5 baseline failures: confirmed harness artefacts. `every_aoc_program_still_compiles_test` needs `<project>/../aoc`, which a copy of `compiler/` lacks (the repo has `aoc/`, 3 programs); the three `corrected_signature_tests` call unexported `bs_check:declared_text/2` (no `TEST` define without rebar3); `the_diagnostics_gate_passes_test` runs a repo gate. To cover the AOC gap I compiled all 62 module directories of `compiler/examples`, `wayfinder/prototypes` and `aoc` with each variant: output (accept/refuse and first diagnostic) is **identical to v0 for v1, v2, v2b, v2c, v3** (the prototypes fail identically in all builds for a wrong source root; not meaningful beyond "no change"). |
| 57g singleton crash | VALID-WITH-CAVEAT | Identical; also reproduced on unpatched v0 directly (`type T = int where value == 1` gives `compile: .../a.bs:0: bad range type`) and persists in v1 and v2c. Wording: it is a reported late compile failure with position `:0`, not an Erlang crash/stack trace. erlc on `-spec f(1..1)` gives the same message, `1..2` rc 0. |

## Claims checked beyond the probes

- **`-5` parses to `{e_neg,L,E}` since F51:** checked with the parser directly (`escript` over `bs_lexer`/`bs_parser`). v0: `-5` gives `{e_neg,P,{e_int,P,5}}`, `-(5)` the same, `- -5` nested, `-2.5` gives `{e_float,P,-2.5}`. F51's date (2026-09-16) comes from the F-file's `**Status** done 2026-09-16` line. **`git log` cannot confirm it: the repo history begins 2026-09-29 (64 commits)**, and the earliest commit touching `e_neg` in the parser is that first one.
- **`negate/2` folds floats, not ints:** `bs_parser.yrl:944-945`, and the parse output above.
- **`-2 * 3` precedence:** probed. v0 parses it as `{e_neg,{e_op,'*',2,3}}`; `-2 + 3` as `{e_op,'+',{e_neg,2},3}`. Under v1: `-2 * 3` stays `e_neg` of a product, `-2 + 3` becomes `{e_op,'+',{e_int,-2},{e_int,3}}`. The brief's statement is correct and no longer "from reading only".
- **OTP citations (stdlib-7.3):** `erl_parse.yrl:269` is `expr -> prefix_op expr`; `:1819` is `normalise({op,_,'-',{integer,_,I}}) -> -I;`; `erl_lint.erl:2134` starts `is_pattern_expr`, the `partial_eval` call is at 2140; `erl_eval.erl:2204` is `partial_eval(Expr)`. All correct. Compiler citations: `bs_parser.yrl:589` (`expr_low -> '-' expr_low`), `:944` (float clause), `bs_check.erl:4931-4955` (`alternatives`/`comparison`); `:2874` is the head of the `e_neg` clause, the `int()` result is at 2882 (loose).
- **Patch sizes** (+/- lines): v1 +1; v2 +10/-2 (12); v2b +11/-2 (13); v2c +16/-2 (18); v3 +18/-2 (20). Matches "12-18" and "20". yecc reports 6 shift/reduce conflicts for v0, v1, v2*, and v3 alike.
- **Compile-time medians** (N=7, run with nothing else running; ms): v0 339, v1 334, v2 356, v2b 351, v2c 333, v3 356; minima 281-324. The with-load run in the brief's matrix gave 424-472. No difference visible; the brief's numbers (370-417) are plausible, none support a ranking.

## Circularity hunt

1. **Patches vs description.** `diff -r` of each patched copy against v0: v1 touches one line of `bs_parser.yrl`; v2/v2b/v2c touch only `bs_check.erl`; v3 only `bs_parser.yrl`. The `comparison/1` rewrite in v2* is behaviour-preserving apart from the intended case: the guards `element(1,R) =/= e_var/e_atom` keep the var-vs-var and atom clauses reaching their old clauses, and non-literal operands still end in `unknown`, as before. Applied each patch fresh: all apply cleanly.
2. **"Accepted" arising from loosened acceptance?** The brief's matrix had no rejection controls for negative bounds. I added them (`/tmp/claude-0/vf57/neg`), run on v0, v1, v2, v2b, v2c: `S` with `n >= -5` / `n < -6` (gap at -6) is still "not exhaustive"; passing 101 or -101 to `-100..100`, `-1` to `!= -1`, or an unconstrained `int` to `>= -5` is still refused ("Go hands Id an argument it does not accept"). So the patched compilers enforce the negative bounds rather than ignore them.
3. **"Fixes all four symptoms" run, not just compiled.** One program (`/tmp/claude-0/vf57/run/Prog`) with `type Delta = int where value >= -100 and value <= 100`, the guard pair `S`, `Take(-3)` against `value <= 3`, `!= -1` and relational patterns: v0 refuses it; v1, v2b, v2c compile it and executing the BEAM gives `S(-5)=a S(-6)=b S(0)=a Take(-3)=-3 Go=-3 Id(-100)=-100 Sign(-1)=neg Sign(0)=nonneg NNGo=-2`, the expected values. **v2 (no `type_of` clause) refuses it**, exactly as claimed (`Go hands Take ... int >= 4`; `NN(-2)` refused with `-1` shown). Note `NN(-2)` is refused by v2 for the same sign-typing reason, not only `Take`.
4. **Flip test (mutants).** m1 = v1 with `-N` changed to `N`; m2 = v2b with `-K` changed to `K`. Both turn red: `Prog` no longer compiles ("bad range type": the bounds collapse to a singleton), the gap control `S` (n >= -5 / n < -6) is wrongly **accepted** by both, and m2 also wrongly accepts `Id(-1)` against `!= -1`. The controls can fail.
5. **Eunit failures.** Same five names in v0, v1, v2, v2b, v2c (md5 of the failed-test lists equal for the four complete runs); v3 differs by exactly the one claimed. The five are attributable to the harness as above, not to the variants.
6. **Controls that cannot fail:** `Neg_eq_single*` is refused in every column (57g), so it carries no information about the variants; the brief says so. `Neg_residual` is refused everywhere because it really is non-exhaustive (negatives uncovered); it is a valid control but not a test of any variant.

## Corrections to the brief

1. `.beam` size: not stable across directories. Drop "1344 vs 1332 / 12 bytes smaller"; keep the Code-chunk md5 (reproduced) and the 3-node abstract-code difference (reproduced: guard, literal body, `n + -5`).
2. F51 date: say "F51 `done 2026-09-16` per its F-file"; git history only reaches 2026-09-29, so `git log` cannot show it.
3. 57g: "crash" should read "late compile failure `bad range type`, position `:0`"; it reproduces on v0 and every variant.
4. Option A "moves no existing test": true for the suite, but the suite's AOC test and gate tests did not run in the harness; add that I compiled all 62 corpus directories (examples, prototypes, aoc) under each variant with no change from v0.
5. Matrix refusals under v3 are syntax errors, not `opaque_refinement`; add a note, and note `Take(-3)`/`NN(-2)` v2 refusal arises from `-3` typed `int`.
6. `bs_check.erl:2874` is the clause head; the `int()` result is line 2882.
7. Timing: the brief's medians are fine as "no difference"; mine (idle machine) were 333-356 ms.

## Not verified

Elm (as in the brief); Elixir/Gleam source; `./bin/verify.sh` and `bin/check-*.sh` on any variant; v2 and v2c full 65-module eunit (60 modules plus the relevant subset passed).
