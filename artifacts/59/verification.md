# Verification of artifacts/59/brief.md

Verifier run on 2026-09-30, OTP 25, from a copy of `probes/` at
`/tmp/claude-0/-home-user-beam-sharp/2e35dc52-b5e4-5ac3-801c-9c12d8324568/scratchpad/verify59/`.
Nothing committed was overwritten (`git status` is unchanged). `compiler/src` is unchanged since the brief's `0dddf8b`,
so the "base" build is the unpatched compiler.

## 1. Probe reruns

Method: copy of `probes/` with the build dir redirected to scratch, `run_all.sh` run unmodified, then outputs diffed
against the committed `.out` files (tmp dir names normalised).

**Defect in the Reproduce section: `run_all.sh` does not build variants A/B/C on this toolchain.** `erlc -o ebin variants/bs_emit.A.erl`
fails with `Module name 'bs_emit' does not match file name 'bs_emit.A'` (`env.sh` build_compiler, the `erlc -o "$ebin" "$emit"` line). `ebin-A/B/C` end up
with no `bs_emit.beam`; every variant output is an `undef bs_emit:forms` crash, and P9 reports 796 failures for A, B and C. The committed outputs
cannot have come from this script as committed (the patch headers show `/tmp/bs59-build/var/A/bs_emit.erl`, i.e. a file actually named `bs_emit.erl`).
I fixed it in my copy only (copy the variant to `<ebin>.src/bs_emit.erl` before `erlc`) and reran every variant-dependent probe. The brief should fix the script.

| Probe | Result |
|---|---|
| P1 base, A, B, C | REPRODUCED (byte-identical after fix) |
| P2 base, A, B, C | REPRODUCED |
| P3 base, A, B, C | REPRODUCED |
| P4 base/A/B/C | REPRODUCED for counts and `Code` bytes (8443 / 8443 / 8452 / 8486). DIFFERS only in `file_bytes` (57732 vs 55296 base, same +/-2.4KB offset in all four), which is beam debug-info path length; brief does not cite it |
| P5 erlc -S | REPRODUCED |
| P5b (13 added, 2 survive) / P5c (Free/1, Double/1 escape=true) | REPRODUCED |
| P6 | REPRODUCED in conclusion: base 9052/9263/8977 us, B 9106/9227/9049 us, no difference |
| P7a Gleam | REPRODUCED (only "Compiled in 0.32s" vs 0.34s) |
| P7b Elixir | REPRODUCED |
| P8 | Conclusion reproduced (noisy, bimodal). base 42.6/38.9/42.5 ms, B 53.7/40.7/54.1, C 41.8/37.5/40.9. Pooled over both runs B is high in 4 of 6 rounds, base in 1 of 6, C in 1 of 6. The mins are all 34-37 ms. "Not resolved" holds; "UNVERIFIED either way" is right, but the pooled medians lean B-slower, which the brief's table does not show |
| P9 | REPRODUCED in conclusion. Base 449 failures here, not 451 (2-test environment variance); A and C fail the identical set as base, B adds exactly `boundary_kind_tests:a_private_function_is_not_guarded_test` and `boundary_range_tests:a_private_function_carries_no_range_guard_test`. Set comparison is by `comm` on normalised names, so "same set" is real, not just equal counts |

## 2. Circularity hunt

No probe is hardcoded, filtered to an expected result, or has swallowed failures that change a reported result. Variants are real `bs_emit` builds; probes
apply funs and call functions from Erlang and print what the BEAM returns. The variant sources match their patches (diffed). Findings, by severity:

- **MEDIUM, `variants/bs_emit.C.erl:271` / `variant_C.patch` hunk 2: variant C contains variant A.** C = A's "no private tag test" plus the wrapper. The
  recommendation says keep the private tag test until 46 §4 lands, so **the recommended configuration (wrapper, private tag test retained) was never built or measured.**
  All of "P2 under C is silent", "P9 under C changes nothing" and "corpus +43 bytes" describe A+wrapper. The recommended build should close P2 `ViaRec` (tag kept) and is not shown to.
  The brief's prose says the tag test "moves into the wrapper", which fits C, but the Recommendation then contradicts what C is. Not wrong, but unmeasured.
- **MEDIUM, `probes/p4_corpus_measure.sh` (`find ... -not -path '*/exemplars/*'`): the corpus filter excludes `compiler/examples/exemplars/`.** The brief's "0 of 26
  private functions have a record parameter; the private tag test protects nothing shipped" is true of the compiling corpus, but the exemplars contain private functions
  with record parameters (`exemplars/25e-dynamic-web-page/rows.bs:15` `Row(OrderRow o)`, `25d-database-querying/summary.bs:14,19` `Tally`/`Add(Totals t, ...)`, `25g-jev-server/triage_answer.bs:13`).
  The exemplars do not compile today (I tried 25a-g on base: 25b/25c syntax errors, the rest need module/root fixes; exemplars README line 3 says none compile), so the exclusion is defensible, but it is not stated in the brief. Also "26 private"
  includes generated functions (only 15 `private` declarations appear in the 26 directories), so "0 of 26 declared private fns" is loose wording.
- **LOW, P3/P2 fixtures are constructed.** P3 `Keep`/`Total` and P2's tuple projection are written to exhibit the escape. They are legitimate: `examples/Shop/Pricing` is a shipped instance
  of the escape (P5c shows `Free/1`, `Double/1` are real), and the P2 hole is the documented 46 §4 "owed" case. The evidence is "a hole exists", not "C closes it in general".
  That C closes P3 is close to true by construction (it wraps exactly the `e_fname` site P3 uses); C's real test is the regression surface (corpus, P9), which held.
- **LOW, superseded P2 v1 (`superseded/README.txt`): legitimate.** v1's `InRec(Order o)` tests `Kind` in the head (F22), so ViaRec refused under every build and could not
  discriminate. v1's base output is identical to the final base output (diffed), so the change did not alter the base result; it only made variant A distinguishable. The change was after seeing output and is disclosed, with both files kept. It did not move toward a wanted result: the final probe exposes the hole that counts against Option 1.
- **LOW, P9 blind spot (`p9_suite_delta.sh`): the failing set hides tests near the change.** The 449-451 base failures include `function_value_tests` (5, including `the_corpus_program_runs_test`, which runs Shop/Pricing through the CLI), `visibility_tests` (4), `api_tests:a_private_*` (2)
  and `foreign_guard_tests` (2). They fail for toolchain reasons (CLI escript / `json`), and the same set fails under every variant. I covered the most relevant one by hand: `Pricing.bs Charged :member 250` -> 150, `Charged :staff 250` -> 0,
  `Doubled [1,2,3]` -> `[2, 4, 6]` under base, A, B and C. The brief's "no runnable test changes" is accurate and its caveat is stated; I found no test asserting the private tag test (grep in `compiler/test`).
- **LOW, baseline identity:** P9 builds the base from the unmodified `compiler/src/bs_emit.erl` (`env.sh`), and A/C diff empty against it. "Measured against an unpatched baseline" is CONFIRMED.
- No stderr-discard problem found that changes a result. `2>/dev/null` in `build_compiler` is what hid the variant build failure from the author's own script, though; the committed outputs are nonetheless reproducible once the file is named `bs_emit.erl`.

## 3. Citation and number spot-checks

| Claim | Result |
|---|---|
| `LANGUAGE.md:3455` "on an exported record parameter"; `:3456` "exported refined int" | CONFIRMED (3455 tag, 3456 int) |
| `bs_emit.erl:267` `guard_one/7`, `:276` `none when Public`, `:174` `IntOnly`, `:325` "asymmetry is deliberate" comment, `:37-56` ctx, `:1063` `e_fname` | CONFIRMED (1063 is within 1 line: the clause starts at 1062/1063) |
| 18 §1 "impossible ... one entry label" (`18-boundary-defence.md:440`), §4 "no further / handed to another function ... guarded" (`:818`) | CONFIRMED; 18's own example (Describe/Format) guards the exported caller, so evidence row 8's reading is right |
| 46 §1 (`46-...md:102,129,166`), F37.5 (`F37-boundary-range.md:168`), F24.6 (`F24...md:229`), ticket 59 text | CONFIRMED |
| Ticket 75 / F46 do not decide the escape guard | CONFIRMED (grep: no boundary decision for a private-name escape) |
| `examples/Shop/Pricing` `Rule(:staff) -> Free` | CONFIRMED (`Pricing.bs:20`) |
| +9 `Code` bytes (8443 -> 8452) | CONFIRMED |
| +43 (8486) | CONFIRMED |
| 13 private int guards added in B; 11 of 13 removed by erlc | CONFIRMED (`int private=13`; bytecode survivors 1 -> 3, so 2 survive) |
| 0 of 26 private fns with record params | CONFIRMED for the measured corpus (base `tag private=0`); see exemplars caveat above |
| ~30 line prototype | CONFIRMED (C patch adds about 33 lines including 2 that are variant A; `variant_B.patch` is 18 lines as stated) |
| 1303 tests / 451 failing on base | 1303 CONFIRMED; 449 failing here (variance of 2, stated in my table) |
| Elixir 1.14 / Gleam 1.12.0 behaviour | CONFIRMED by rerun |

## 4. Evidence-table verdicts

| # | Verdict | Note |
|---|---|---|
| 1 | CONFIRMED | P1 |
| 2 | CONFIRMED | spec says exported, compiler emits the tag test on private |
| 3 | CONFIRMED (runnable subset) | A changes no test. No test asserts the private tag test |
| 4 | CONFIRMED | `WholeRec` function_clause under all builds |
| 5 | CONFIRMED | base `ViaRec` function_clause, A gives `order`, `DirectRec` 9 under all builds |
| 6 | CONFIRMED | `{ok,1.5}`, `{ok,foo}` |
| 7 | CONFIRMED | `{type,local}`, `Rule(staff)(foo)` -> `foo` |
| 8 | CONFIRMED (REFUTED-as-read is correct) | per 18's own example |
| 9 | CONFIRMED (partly refuted) | wrapper is a second entry label; direct call bare |
| 10 | CONFIRMED | OTP 25 only. The "+3-5 bytes per is_integer" is 18's figure, whereas the corpus shows under 1 byte per added guard net |
| 11 | CONFIRMED | |
| 12 | CONFIRMED | |
| 13 | NOT CONFIRMED either way, as the brief says | pooled P8 leans B slower but C (same per-element guard) is not; treat as noise |
| 14 | CONFIRMED | exactly F24.6 and F37.5 |
| 15 | CONFIRMED (REFUTED today) | |

No row is circular.

## Does Option 3 still follow?

Yes, as a direction: the escape hole (P3, `Shop/Pricing`) is real and reproduced; Option 1 widens it; Option 2's cost rests on erlc. Three things to correct before David reads it:
(a) say that variant C includes A, and that the recommended "C plus retained private tag test" is unbuilt and unmeasured (P2/P9/P4 numbers describe A+wrapper);
(b) fix `run_all.sh`/`env.sh` so variant sources are compiled as `bs_emit.erl` (as committed, the Reproduce section fails for A/B/C);
(c) note the exemplars exclusion beside "0 of 26", and that the exemplars hold private record-parameter functions that will matter when they compile.
The brief's own open risk that C was not reviewed against other `e_fname` users (List.Map inlining, behaviour callbacks) stands; I did not review it.
