# Independent verification of ticket 59's brief (2026-10-04/05)

Method: fresh copy of the probes in /tmp/v59 with /tmp/p59 rewritten to /tmp/v59/w; all four compilers rebuilt from a fresh
copy of compiler/ plus the author's patches (probe 10, 51 s); every probe re-run; outputs in `verify/`. Box load average 13 to 16
throughout (4 vCPU), so timing is judged by minima and repetition.

## 1. Re-runs

| probe | result |
|---|---|
| 01, 02, 05, 06, 07, 09, 11, 14 | REPRODUCED, byte-identical after stripping temp paths |
| 03 | REPRODUCED for every Code-chunk number (Rec3/Rec8 -12 narrow, 0 wide, +21/+79 proj; IntP 0; IntU +5; Oct 0; Big2 +10). Only whole-file bytes differ by 4-8 B (embedded paths), which the brief says it does not use |
| 04 | REPRODUCED sizes (tagged map +14 at 3 and 8 fields, slope +0.0; id/1 +3, add/2 +5, add/4 +22). Timing tables differ (noise, not used) |
| 08 | REPRODUCED (only "Compiled in" seconds differ) |
| 13 | REPRODUCED: narrow 0 of 8309; wide +9 B (0.11%), 13 functions, 7 modules, Free and Double carry the +9 |
| 10 | REPRODUCED (hashes differ, escript timestamps; changed-line counts 0/1/8/36 equal) |
| 12 | REPRODUCED in direction and order, magnitude slightly higher under heavier load (see 3) |
| 15 | REPRODUCED the deltas; absolute counts differ because I set LANG=C.UTF-8 (below) |

Eunit, one variant at a time, LANG=C.UTF-8 (suite did not abort): base 1307 pass / 2 fail; narrow 1307/2; wide 1305/4; proj 1304/5.
Deltas versus base match the brief exactly: narrow none; wide breaks only `boundary_kind_tests:a_private_function_is_not_guarded_test`
(F24.6) and `boundary_range_tests:a_private_function_carries_no_range_guard_test` (F37.5); proj breaks exactly the three named.
The brief's "5 identical baseline failures" is true of the author's run but 3 of the 5 are a locale artefact: with LANG=C.UTF-8 the
utf8 ones (`a_path_is_utf8_on_the_wire`, `batch_runs_every_entry`, `a_non_ascii_literal_is_advised`) pass (the logs show mojibake
`h�llo`). The remaining 2 are copy-layout artefacts: `every_aoc_program_still_compiles` needs `../aoc` beside the compiler
(body_check_tests.erl:294), `the_diagnostics_gate_passes` needs `bin/check-diagnostics.sh`, which the copy does not have (compiler/bin only has the
check scripts listed above). None touches guard emission; the AoC programs are compiled on every variant by probe 13, so
nothing relevant is masked. The brief's "I did not investigate" is correctable: it is locale plus layout.

## 2. Factual claims

PASS: private `Inner(Order o)` has `map_get('Kind')` test, private `Scale(int)`/`Plain`/`ScaleO` have none (probe 01 asm).
PASS: the third guard (float) is in the same `none when Public` branch (bs_emit.erl guard_one, wide.patch shows it); `boundary_guards` is arity 6.
PASS: forgery arrives via a field or list element; `Direct(bad_tag)` dies at `Direct` in all four variants.
PASS: base `Field(cart 1.5)` returns 3.0; base `FieldBig(:foo)` returns `big`. Nuance: `Field(:foo)` is NOT silent (badarith), and the
brief's row 3 uses only 1.5, which is right.
PASS: 26a +14 flat; 18a +3 to +5; +9 of 8309; proj +21 (3 fields) and +79 (8 fields).
PASS: beam_ssa_type: probe 07 l1 0 guards, l2 kept, l3 (captured) kept, ex kept. Tag test never removed (HotB disassembly keeps
`map_get` on a value typed `t_map`). Header lines 122-125 etc. in compiler-9.0/src/beam_ssa_type.erl were not individually re-opened beyond probe 07's behaviour.
PASS: quote is at wayfinder/issues/18-boundary-defence.md:194-196 verbatim. Note the file is under `wayfinder/issues/`, not `research/`; brief just says the filename. 18:818 ("A value handed to another function counts as unchecked, and is guarded") is in §4 as the brief says, and 18:439 ("interior functions already pay nothing") says the same as the brief's "understates it" point.
FLAG (minor): "+14 vs -12" difference is unexplained (the brief admits it).

## 3. Circularity audit

* Forgeries are built in a hand-written Erlang driver that calls the EXPORTED B# entries (`Forge:Nested/1` etc.) with hand-built maps. Private functions are never called directly (the driver confirms `Forge:Inner` is `undef`). The .beam files are untouched. This is exactly what a non-B# caller (Erlang/Elixir, a message to a gen_server entry) can do, so the construction is legitimate.
* The probes would fail if the claim were false: the control row `Direct(bad_tag)` crashes at the entry on all variants (the entry guard works), while `Nested(bad_tag)` returns 7 on narrow and crashes in `Inner` on base/wide. Same program, difference between narrow and wide is the only variable. Compiled sources are identical across variants.
* Reachability of the "silent 7" and "silent 14": from an exported B# entry only when its caller is not B# (Erlang/Elixir/FFI-declared-wrong). Pure B# cannot produce the value (probe 06: `term` into `Order` refused; foreign returns are guarded, F42/F52). So the threat model is "foreign caller of an exported function", which is the boundary guard's stated purpose; the brief says "hand-built Erlang caller" in §2 but its headline paragraph does not say a B# caller can never do it. FLAG (framing, not correctness).
* The recommendation's central premise is true, but note it is partly the author's own definition of "reaches": the same forged int already passes `Compare` (exported body, no private callee) on every variant except proj, so the exported side is not sound either, as the brief says.
* Timing loop: disassembly of HotB/HotN/HotW `Loop/3` (done by me, `private` loop) shows HotN has no `map_get('Kind')` at all, HotB/HotW keep it (one in Loop, one in Step per iteration), HotW runs exactly one `is_integer(Acc)` per iteration (clause 1 not taken because `n` literal test fails first), and the `is_integer(N)` is gone in all. So the guard survives in wide and is removed in narrow as claimed.
* Timing reruns (5M iterations, rotated, load ~14): wide minus base medians +0.88, +0.96, +0.93 ns (rounds: 25, 41, 41); minima base 12.7-12.8 vs wide 13.4-13.7 (+0.6 to +0.9); narrow minus base -2.69, -2.91, -2.75; noise floor (identical-code control) -0.51, +0.08, -0.40; per-round spread 3 to 14 ns. Brief says +0.70/+0.81 and 1.35 ns per tag test: my values are slightly higher for wide (+0.9) and agree for narrow. Ordering and magnitude order hold; under this load the floor (+-0.5) is comparable to the effect, so treat "0.7 to 1 ns" as the honest range, not "0.7 to 0.8".
* Final-run selection: the overwritten first run (+0.47) was LOWER than the retained ones, so dropping it did not favour widening; the retained numbers are the more adverse. The loaded run is disclosed and excluded. Not cherry-picked in the recommendation's favour. The overwritten run is unverifiable (stated by the brief).
* Hand-written .out files: none found; every re-run matched. Probes that cannot fail: 02, 05, 12 and 15 are reports with no assertion (a reader must see the verdict); no probe greps its own printed output as evidence (01/12 grep disassembly, 14 greps emitter source, 15 greps eunit logs). 03's `-12` versus `+14` is an in-situ versus isolated difference, disclosed.
* One real weakness: the 3/8-field and corpus evidence rests on a corpus with no private record parameter, so the 1.35 ns tag-test figure comes only from the synthetic loop. The brief says so.

## 4. brief.md history

`git log -p` shows brief.md was first committed in 0771462 (inside the "ticket 39 verification" commit, 23:47) as an earlier draft of THIS ticket's
brief (it contained placeholders `PROJ_EUNIT_RESULT` / `PROJ_EUNIT_DELTA`) and was updated in c96c0c7 (23:54). So the "M" was a prior checkpoint of the same
work, not another document. Changes in the diff: timing claim corrected from "0.3 ns per guard, two surviving guards" to "0.7 to 0.8 ns, one surviving guard"
(correct, per the disassembly above), "+79 for 7 fields" to "8 fields", proj eunit filled in, wording on row 9. Nothing substantive was lost; the earlier numbers
survive in the diff and the brief discloses the first timing run.

## Verdict

PASS: reproduction of all probes and counts; eunit deltas (narrow none, wide 2, proj 3); every cited quote/line; circularity (forgeries from a real foreign caller, would fail on wide-vs-narrow if false); disassembly of the timing loop; brief.md history.
FLAG: (a) baseline 5 failures are 3 locale + 2 copy-layout, not unexplained, and with UTF-8 the counts are 1307/2; (b) wide-minus-base is +0.9 here (brief 0.7 to 0.8) and the noise floor under load is as large as the effect; (c) "forged value reaches a private function" requires a non-B# caller, which the brief should state in the headline; (d) the probes are reports with no assertions; (e) Elm claims are cited only (disclosed).

Safe to rely on? **Yes, with caveats** (the correctness argument and the byte numbers are solid; the nanosecond figures are order-of-magnitude only).
