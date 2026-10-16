# Independent verification of ticket 57 prototypes (verifier run, 2026-10-16)

Scratch: /tmp/claude-0/verify57/ (binA, binB rebuilt from the patch files via build-variant.sh; base/A/B copies for eunit; extra.sh).

## 1. Rebuild + matrix.sh
- `build-variant.sh patches/57-A-grammar-fold.diff /tmp/claude-0/verify57/binA` and `...57-B-checker-fold.diff .../binB`: both built (fresh, not /tmp/claude-0/proto57).
- Ran matrix.sh against unpatched $BSC, A, B. Raw output differs from the stored files only in FORMAT (stored files use " | " column separators and " ⏎ " for newlines; script prints padded columns and real newlines). After normalising whitespace/separators: baseline, A, B are IDENTICAL to result_baseline.txt, result_A_grammar_fold.txt, result_B_checker_fold.txt. **No outcome divergence.** (Minor: stored files are not byte-for-byte the script's output; they were post-processed.)
- Headline outcomes reproduced: baseline refuses GeNeg/Band/Outer/ParenNeg/Flip/NegExpr/DoubleNeg ("this refinement is not a predicate the checker can read") and ExhGuard ("Sign is not exhaustive"); A and B accept all of those; A still refuses `2 + 3`, `0 - 5` and ExhGuardSum; B accepts them; VarBound refused by all.

## 2. Critical read of matrix.sh and patches
- Row sources: every row is a literal string in one script, run unchanged for each compiler; the only variable is the bsc path. No row differs between runs. Expected outcomes are not in the script at all: it prints the compiler's own answer (accepted iff rc=0 and empty output, else first `error:` line). So no outcome is pre-decided.
- Caveat: "accepted" = rc 0 + no output; it does not check the accepted type means what is intended. Rows alone (matrix.sh) therefore do not show A/B compute the right bound; I added semantic rows (below), which do.
- Patch A: one clause `negate(_L,{e_int,IL,I}) -> {e_int,IL,-I}` beside the existing float clause. General (every int literal under unary minus), no names or magic literals. Side effect: it applies in ALL expression contexts, so `-5` now has the literal type instead of `int()`; I saw no outcome change in my expression rows (E01-E07 identical to baseline under A) and run-time results are identical (`-2147483648 - 1` = -2147483649, `n - -5` with 10 = 15, `-(-5)` = 5 under base/A/B).
- Patch B: `comparison/1` folds `e_neg`, `+ - *` over int literals in both comparands (not for and/or), then calls the original clauses (renamed comparison0). General rule, no name/literal special-casing. Does NOT fold `/`, `%`, floats, or var-containing expressions (confirmed below). It also changes guard analysis, not just refinements (ExhGuard, ExhGuardSum, S13 flip to accepted) - a wider blast radius than ticket 57's question; correct, but worth stating.
- Row selection: the matrix includes rows where each patch is weak (A on Sum/ZeroMinus/ExhGuardSum), so it does not hide A's limits. Not cherry-picked in the patches' favour, but it contains no negative/soundness rows (see below), which I added.

## 3. My extra rows (/tmp/claude-0/verify57/extra.sh, 49 rows, run on base, A, B; outputs x_base.txt x_A.txt x_B.txt)
Base refuses every refinement row with "not a predicate the checker can read". Highlights (A / B):
- X01 empty `value >= -5 and value <= -10`: A, B both "refused: this refinement admits no values at all" (correct diagnosis, not misparse).
- X02 `>= -9223372036854775808`, X03 `>= -9223372036854775809`: both accept (BEAM bignums; ok). X04 big positive accepted by base already.
- X05 `-5 - 1`, X06 `2 * -3`, X07 `-5 + 5`, X09 `5 - -5`, X16 `3 * 4611686018427387904`: A refuses (unfolded binary ops), B accepts.
- X08 `- - -5`, X13 `== -5`, X14 `!= -5`, X15 `-5 <= value and value <= -1`, X17 `-0`: both accept.
- X10 `value + 1 >= -5`, X11 `-value >= 5`, X12 `>= -5.0`, X18 `10 / 2`, X19 `7 % 4`, X20 `-5 <= -3`, X21 `... and true`: refused by ALL (B folds only + - * on ints; not sound-wrong, just still unsupported).
- Semantic exactness (a function over `T`; the guard coverage shows what bound the compiler computed). A and B agree on all A-supported rows, and the answers are right:
  S01 `T>=-5`, guard `n >= -5`: accepted; S02 guard `n >= -4`: "F is not exhaustive" (so bound is exactly -5, not off by one); S03 `>= -6`: accepted; S04 pattern `F(<= -1)` beside a negative refinement: accepted. S09 band exact accepted, S10 band short refused.
  B only: S05 `2+3` exact accepted / S06 `n >= 6` refused; S07 `0-5` exact accepted / S08 `n >= -4` refused; S11 `2 * -3` with `n >= -6` accepted / S12 `n >= -5` refused; S13 `n < 2 * -3` + `n >= -6` accepted, S14 (`n >= -5`, gap at -6) correctly refused.
- Expression-context regression rows E01-E07 (return -5, atom-return -5 refused, `n - -5`, `-(-n)`, `-2147483648 - 1`, `-5 + 1.5` refused as int+float, guard `== -5`): identical outcomes base/A/B.
No flaw found in A or B on these rows. Limitation: neither patch tested against differently-typed (non-int) negation; float path untouched.

## 4. eunit (copies of compiler/ minus _build in /tmp/claude-0/verify57/{base,A,B}, patched; `rebar3 eunit` each, sequential; total ~minutes, not 10)
- base: Failed 5, Passed 1443. A: Failed 5, Passed 1443. B: Failed 5, Passed 1443.
- Identical failing set in all three: body_check_tests:every_aoc_program_still_compiles_test, cli_tests:batch_runs_every_entry_in_one_vm_and_attributes_each, diagnostic_json_tests:a_path_is_utf8_on_the_wire_test, diagnostic_term_tests:the_diagnostics_gate_passes_test, non_numeric_operand_tests:a_non_ascii_literal_is_advised_as_written_test.
- Claim "A and B introduce no failures beyond the baseline" is REPRODUCED (same 5 set, same counts). 
- **DIVERGENCE** from the stated "A and B had the same minus diagnostic_term_tests": in my runs diagnostic_term_tests:the_diagnostics_gate_passes_test fails in base, A and B. Cause found, and it is deterministic, not flaky: it runs bin/check-diagnostics.sh, which errors "no built bsc at .../_build/default/bin/bsc - run rebar3 escriptize" when the tree has not been escriptized. My copies had no _build. After `rebar3 escriptize` in base copy, `rebar3 eunit --module=diagnostic_term_tests` -> "All 13 tests passed"; ran it 3x unbuilt: 3/3 failed. So the author's pass/fail difference is order/state dependent (bsc pre-built or not), not randomness; the "baseline has 5 failures" vs "A/B have 4" comparison was therefore not like-for-like unless the build state is stated. Not a patch effect (base fails identically). The other four failures I did not root-cause (stated environmental, OTP 28.0 vs 28.5); they are identical across variants, so not patch-related.
- Also, build-variant.sh excludes generated bs_parser.erl so A's parser is regenerated from the patched .yrl (confirmed the generated erl contains the new clause after eunit's build for A).

## Verdict
CIRCULAR: no
Reasons: probe rows identical across compilers; outcomes come only from the compiler (no embedded expectations); patches are general rules (no special-casing of names or -5); stored results reproduce exactly modulo formatting; my 49 independent rows, including exactness (off-by-one), empty-range, i64 and operator-fold cases, found no flaw and show the fold computes the correct bound. Caveats, not circularity: (a) stored result files are reformatted, not raw script output; (b) the eunit comparison omitted that diagnostic_term depends on a pre-built bsc; (c) B also changes guard exhaustiveness analysis (wider than refinements) and A changes the type of every negated int literal in expressions - both appear benign on all rows tried; (d) matrix.sh has no semantic-exactness rows, only accept/refuse, which is why the extra rows matter.
