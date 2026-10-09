# Verification of the ticket 57 brief (negative literals in refinements)

Verifier run 2026-10-08. Own builds in /tmp/verify57/{base,A,B,C,D} (built with build-bsc.sh and the committed patches). Nothing in compiler/, the brief or the probes was edited.

## Verdict: PASS WITH CORRECTIONS

Every measured claim in the brief reproduces. Corrections are needed in three places:
1. The probe helper `probe()` counts a missing ebin or a bsc crash as "refused", so every "refused" expectation is vacuous against a broken build.
2. `NegArgToNonNeg` is cited by the brief but is in no committed probe file.
3. Under B and C, `RefNegExcludes` is refused for the same reason as `RefNegAdmits`, so it proves nothing there. It is meaningful only under A and D.

Smaller items: the baseline failure count (466 vs 467), a few citations, and an overstated Erlang neighbour row (all below).

## Reproduced

Builds: patches apply cleanly. diff vs compiler/src:
- A: parser only, 1 added line (`negate(_L, {e_int, IL, N}) -> {e_int, IL, -N};`, immediately before `negate(L, E)`). `bs_check.erl` is untouched. The patch file is 10 lines including context, as the brief says.
- B: 2 added `comparison/1` clauses and nothing else.
- C: `comparison/1` clause plus a `cfold/1` helper (10 diff lines).
- D: B's 2 clauses plus 1 added `type_of({e_neg,_,{e_int,_,N}})` clause. It is a complete diff against compiler/src.
- The empty `A-check.patch`, `B-parser.patch` and `C-parser.patch` are 0-byte placeholders. They are harmless but unmentioned.

Matrix (my paths; `!!` = differs from matrix.sh's committed expectation):

| probe | base | A | B | C | D |
|---|---|---|---|---|---|
| RefNegGe (acc) | refused (!!, expected: unfixed) | ok | ok | ok | ok |
| RefNegRange (acc) | refused (!!) | ok | ok | ok | ok |
| RefSumFold (acc) | refused (!!) | refused (!!) | refused (!!) | accepted | refused (!!) |
| RefVarRhs (ref) | ok | ok | ok | ok | ok |
| RefNegExcludes (ref) | ok (wrong reason) | ok `-9` | ok `int <= -6` | ok `int <= -6` | ok `-9` |
| RefNegAdmits (acc) | refused (!!) | ok | refused (!!) | refused (!!) | ok |
| GuardNegExh (acc) | refused: "S is not exhaustive" | ok | ok | ok | ok |
| PatNegExh (acc) | ok | ok | ok | ok | ok |

The `!!` marks sit exactly where the brief says each variant fails: RefSumFold under A, B and D, and RefNegAdmits under B and C. The brief's claims match.

Extra probes I wrote (not in the repo):
- NegArgToNonNeg (`Id(-5)` into `>= 0`) is refused on all five builds. The text under A and D is `argument 1 is not covered by Id's declared type: -5`. Under base it is `int <= -1`.
- The Delta program from the brief, `Id(-100)` / `Id(-101)`: DeltaOk is accepted under A and D and refused under base, B and C. DeltaBad is refused everywhere.

Unit suite (eunit, all 67 test modules, OTP 25), failure counts:

| build | failed |
|---|---|
| base | 466 |
| A | 466 |
| B | 466 |
| C | 466 |
| D | 466 |

`comm` of the sorted failure names between base and each variant is empty in both directions, so A, B, C and D add no failures. The causes are environmental, e.g. `maps:iterator/2` is undefined on OTP 25. The conclusion "no new failures" is confirmed.

C regression: I rebuilt C with the guard on the new `comparison/1` clause removed, since the original unfixed prototype is not committed. `a_guard_comparing_a_literal_closes_test` then fails: string_literal_type_tests goes from 5 to 6 failures. With the committed C patch it is back to base. The shadowing explanation is consistent with C-check.patch. The `element(1,R) =:= e_op; =:= e_neg` guard exists precisely so that the `e_str` / `e_atom` clauses below are reached.

shape.sh reproduced:
- base `K() -> {op,{3,1},'-',{integer,{3,1},5}}`
- A `{integer,{3,1},-5}`
- D `{op,...}` (same as base)

Compile times are noisy: mine ran at 500–1700 ms because five eunit runs were running concurrently. The brief's "no measurable cost" is not contradicted, but it is not independently shown either. The brief is also not wrong about D being slower in its own table (D's range is higher than base's in shape.out).

Neighbours: the Elixir probe reproduces exactly (`{:-,_,[5]}` kept, `{:in,:out}`). Erlang: I re-parsed `f(X) when X >= -5 -> -5.` and `f(-5) -> a.` with erl_scan and erl_parse, and both give `{op,1,'-',{integer,1,5}}`. This matches neighbours_erlang.out.

## Mismatches
- The brief and /tmp/runtests.sh say 467 baseline failures. My clean run gives 466 for every build. The author's /tmp/tests_base has one extra failure, `modules_tests: a_fully_qualified_call_needs_no_unqualified_scope_test`. It passes for me, so it is environment-dependent (likely cwd or /tmp state). Either way, the base-vs-variant sets are identical in both runs. The "467" figure is off by one, not stable.
- Passed/failed totals: 859/467 (author) vs 860/466 (mine). Same cause.

## Circularity flags
- (c) VACUITY FLAW, prominent. `probe()` in lib.sh decides refused/accepted only from "stderr+stdout non-empty". I set `BSC_EBIN=/nonexistent/ebin` and ran `probe Vac refused 'public int K()\nK() -> 1'`. It printed `ok Vac refused (expected refused)`, with the body `{"init terminating in do_boot",{undef,[{bsc,main,...`. A valid program was then "refused" and an expectation of `refused` was marked `ok`. `bsc` returns exit 0 via `halt(0)` and the helper never checks for a real diagnostic. Impact: any `refused` row (RefVarRhs, RefNegExcludes, NegArgToNonNeg, base columns) would pass on a missing or crashed build. In this run the diagnostics were visible in the indented output and I read them, so the matrix results above are not tainted, but the committed harness cannot catch it by itself. Suggested fix, not applied: require `error:` in the output for `refused`.
- (a) RefNegExcludes. Under A and D the diagnostic is `Bad hands Id an argument it does not accept / argument 1 is not covered by Id's declared type: -9`. This is the intended argument-coverage error. Under base it is refused with "this refinement is not a predicate the checker can read" (an unrelated error). Under B and C it is refused with `int <= -6`, the same wrong-typing cause as RefNegAdmits (the literal is typed `int`), so it cannot show non-widening there. Only A and D give evidence for "does not silently widen". The brief's claim is stated only for A, so it is not false, but the matrix expectation is satisfied for the wrong reason on base, B and C.
- NegArgToNonNeg: the diagnostic is the argument-coverage error (see above), not a syntax or opaque_refinement error. But the probe is refused on every build including base (via `int <= -1`), so it does not discriminate A from base. Also, it is not in any committed probe file (`grep -rn NegArgToNonNeg artifacts` hits only the brief), so the brief cites a measurement the reader cannot re-run.
- (b) RefNegAdmits under B and C. Cause confirmed: bs_check.erl:2882-2893 `type_of({e_neg,L,E},...)` returns `bs_types:int()` for any numeric operand, so the literal `-5` is `int`. The diagnostic is `int <= -6` (the part of `int` outside `>= -5`). D adds a single clause `type_of({e_neg,_,{e_int,_,N}}) -> range(-N,-N)` and the same probe flips to accepted. This is causal, not an artifact of the probe.
- (d) Expectation edits. matrix.sh expects post-fix behaviour (RefNegGe, RefNegRange, RefSumFold, RefNegAdmits, GuardNegExh accepted). p57.sh is the older base-oriented probe (NegGe refused, etc.). I found no expected value changed to fit a result. The only suspicious point is the one inherent in the design: matrix.sh's `accepted` rows are written for the best variant, so B and C `!!` lines are expected and are not failures. The brief explains them.
- GuardNegExh is live. The base build refuses it with "S is not exhaustive", so a pass under A is a real exhaustiveness proof.

## Citation errors
Checked against the files.
- erl_parse.yrl:240 (`expr -> prefix_op expr`) and :270 (`pat_expr -> prefix_op pat_expr`): correct, in stdlib-4.3.1.3 (OTP 25).
- erl_lint.erl:1886, 1997, 2051: lines are correct, but they are not all pattern folding. 1886 is in `is_pattern_expr` (a validity check). 1997 and 2051 are in `pat_bit_size` and `bit_size`, which are bit-syntax size checks. The brief's gloss "folding happens later" cites them as general evidence. This is approximate and only 1886 is on point. The OTP 25 source is cited, while the repo targets OTP 28.
- erl_parse `normalise` `-> -I` clauses: they are at erl_parse.yrl:1440-1442 and are real, but `normalise/1` is for turning abstract terms into data (attributes, etc.), not for function-head patterns. The brief's phrasing is loose.
- bs_parser.yrl:221 (`refinement -> expr_low`): correct.
- bs_parser.yrl:587-596: the `'-' expr_low` rule is at 591 only, with a comment at 587-590. Lines 592-596 are unrelated rules (atom_lit, string_lit, interp). The range is loose, not wrong.
- bs_parser.yrl:946-947 `negate/2`: correct. The float clause is at 946 and the generic clause at 947. The brief also says the float fold is "at :946", also right.
- bs_check.erl:2882-2893 (e_neg `type_of`): correct. The e_int clause is at 2875.
- `comparison/1`: the brief says `~4955`. The actual first clause is at bs_check.erl:4960. It is marked approximate, but off by five lines.
- "F51 (2026-09-16)": F51-float.md Status says done 2026-09-16, and finding 2 at line 105 says "A negated float literal folds to the literal so Sign(-1.5) is a head". Both are correct.
- The ticket's `{e_op,'-',{e_int,0},{e_int,5}}`: ticket line 55 is as the brief describes (the stale premise holds).

## Things the brief overstates
- "RefNegExcludes ... refused with `-9 is not covered`, so it does not silently widen". True under A and D only. See Circularity.
- "Strongest counterargument ... both executable BEAM neighbours ... sit nearer Option B". Fair as stated, but the Erlang row implies Erlang's pattern fold is a deliberate "downstream" step demonstrated by the cited erl_lint lines. Only line 1886 and the compiler's later passes support that. 1997 and 2051 are bit sizes.
- "467 fail ... identical 467 fail with A". In a clean run the number is 466 (the set equality is correct).
- "no measurable cost" for compile time rests on noisy 10-run VM-boot-dominated samples (the author's own D range is visibly higher than base's). The brief says so itself ("dominated by VM boot"), so it is a mild point.
- The "Reproduce" line says `BUILDS="base A D" ./matrix.sh`, but matrix.sh hardcodes /tmp/bsbuild and /tmp/bsb_*. It requires make-variants.sh first (mentioned in the brief only in passing). The brief says nothing about B's and D's patch filenames needing different build calls (D builds from `D-check.patch` alone).
- Elm and Gleam: the Neighbours table asserts nothing about either. Elm says "Not executed" and Gleam "no claim made". Compliant. (The sentence "both executable BEAM neighbours" correctly excludes them.)
