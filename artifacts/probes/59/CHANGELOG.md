# Probe changelog (ticket 59)

Rule: a probe is not edited after its output is seen merely to make it pass. Every edit after first
output is logged here with the reason.

1. `src/Deep/deep.bs`, `drive_deep.escript`, `p02_forged.sh`: added `Doubled`/`Twice` (private function
   handed to `List.Map`) and cases C11/C12 AFTER the first p02 run, because the first run showed only
   the list-element route and the library-walker route was a separate claim. Expectations for C12 were
   written before C12 was run (silent under base/a, refused under b/c).
2. `p05_bytes.sh`: first run printed `FAIL` because the awk column index was off by one (the table's `|`
   separator shifted the fields). Reason: script bug, not a measurement change. Table values were not
   touched; only the two awk column numbers (`$6`->`$7`, `$7`->`$8`).
3. `p03_elision.sh`: label-equality assertion (call_only target == entry label) added after the first
   run, to turn an eyeballed line into a checked one. No earlier assertion was weakened.
4. `p07_elixir.sh`: added `only_proven` and a non-vacuity check after noticing `priv_int` retains
   `is_integer` because my own `run/1` also captures it (`&priv_int/1`): a second, capture-free `defp`
   was needed to show the elision.
5. `p08_gleam.sh`: the first version asserted `pub_amount(not_a_record)` returns `{ok,_}`. WRONG
   prediction: output was `{error,badarg,{erlang,element,...}}` (the body's `element/2` objects).
   Replaced with the accurate claims: no guard emitted at either scope; a forged 3-tuple passes through a
   private function silently; a float passes silently. The wrong prediction is kept here on purpose.
6. p10_corpus.sh: first run double-counted dotted modules compiled as dependencies of another directory (30 abstr files for 27 module dirs); fixed by deduping on module name before counting. Per-module delta columns also corrected. Totals before the fix were inflated, not selectively.
7. build.sh: now also copies the repo's aoc/ next to each compiler copy. Reason: p11's first base run had 1 failure (body_check_tests:every_aoc_program_still_compiles_test) that was an artefact of my copy lacking ../aoc, not of any option.
8. (correction to entry 6) the dedupe edit of entry 6 did not apply on the first attempt (the replace string did not match); the p10 output captured before this entry still contained duplicates. Re-applied here.
9. p11 first run: variants b and c were cut short (c.log ends in 'SIGTERM received'; b ran 228 of 306 tests) by an outside SIGTERM on the shared host; only base and a completed. p11 re-run from scratch via run.sh. The b/c numbers from that first attempt are not used.
10. p11: the full-suite run is cancelled by per-test timeouts on this loaded shared host (variant a: 306 of 1312 ran, then 'One or more tests were cancelled'), so p11 now defaults to the 13 modules that exercise the guards (FULL=1 for the whole suite). The one complete full-suite run, base (All 1312 tests passed), is kept in out/p11_base_full.log.
