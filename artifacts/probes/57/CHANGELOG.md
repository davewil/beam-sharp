# Probe changes after first output (ticket 57)

Every edit to a probe made after seeing its output, and why. None changes a
claim's refute condition to make it pass; raw first-run output is kept where a
change replaced rows.

1. `04_variant_matrix.sh` row `value == -3` replaced by `value > -3 and value < 0`.
   Reason: `value == -3` was refused under EVERY variant, and so was `value == 3`
   on the unpatched compiler, for a reason unrelated to negative literals:
   a singleton range `3..3` in the emitted `-spec` fails erl_lint
   (`erl_lint.erl:3440-3444` requires `X < Y`, message "bad range type"). My
   expectation (accepted) was wrong, not the compiler. The singleton defect is
   reported separately in the brief. First-run raw output: `out/04_first_run_raw.txt`
   (regenerated only by editing this file's history; not by run.sh).
2. `04_variant_matrix.sh` expectation for `value >= --5` / `value >= - -5` under
   g1b changed accepted -> refused. Reason: my g1b folds only a single `e_neg`
   over a literal; the first run showed it refuses double negation. That is a
   property of that 6-line implementation (and of a literal-only grammar), recorded as such.
3. `04_variant_matrix.sh` "domain mean exactly -100..100" block rewritten. First
   version expected a `_` clause AFTER an exact three-clause cover to be refused;
   that is wrong (the residual is empty, so there is nothing for `_` to be a
   catch-all over). Replaced by three checks: exact cover accepted, one-short cover
   refused with the missing integer printed, and `_` over the closed residual {0} refused.
4. `05_expression_typing.sh` DIFF program first used `public int A() -> ...`
   (invalid B# syntax: signature line then clause) and then a directory not named
   after its module. Both were my authoring errors; the probe printed INVALID-style
   syntax/ module errors, not a result. Fixed; also added an INVALID guard if base
   does not compile.
5. `05_expression_typing.sh` N5/N8 prediction for c2 (`x / -0` accepted) was wrong
   and was NOT changed: c2 refuses it, the printed `refused!=accepted` stays.
6. `06_emission.sh`: added the `is_ge` presence check so "identical disassembly"
   cannot be satisfied by two identical failures.
7. `01_ticket_table.sh`: the shipped 38b script wrote `.beam`/`.abstr` into the
   caller's cwd (the repo root, gitignored); now run from the scratch dir, and the
   strays from my earlier manual runs were deleted from the repo root.
8. `lib.sh` build_variant also copies `aoc/` (a sibling of `compiler/` that
   `body_check_tests:every_aoc_program_still_compiles_test` reads); the first
   baseline eunit run without it showed that one failure (1311 pass, 1 fail),
   which is an artefact of the copy, not of the compiler.
9. `10_eunit.sh` ran the five variants in parallel; with the machine also busy,
   `clause_block_tests:a_comma_closes_a_lambda_or_a_switch_body_test` timed out
   (`bs_process:collect/2`) and eunit CANCELLED the run (228/177 tests "passed" of
   ~1312, `One or more tests were cancelled`). That is load, not a verdict: the run
   is now sequential and the parallel output was discarded.
10. `10_eunit.sh` takes `ONLY="g1"` to run a subset. The first sequential g1 run
    timed out at the same subprocess test (228 tests, cancelled) because I ran
    probe 12 (several bsc invocations) while it was in progress; that output is
    kept as `evidence/10_g1_run_overlapped_with_other_probes.txt` and the g1
    suite was re-run alone on an idle machine. Nothing else about the run changed.
    Do not run other probes while 10_eunit.sh is running.
