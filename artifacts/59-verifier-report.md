# Verifier report: ticket 59 brief

Scratch: /tmp/claude-0/verify59 (probes copied; full run.sh re-run there, ~27 s; rebuilt Guard.abstr is byte-identical to the author's).

## 1. Re-runs
| probe output | result |
|---|---|
| emitted-erlang, forge-emitted, forge-stripped, forge-widened, sizes, disasm, corpus, bsc-forged, bsc-compile | REPRODUCED (byte-identical) |
| gleam/probe, gleam/emitted, elixir/probe, elixir/warn, erlang/dialyzer, erlang/plt | REPRODUCED |
| bench.out | DIFFERS, as expected for timing. Mine: record emitted 29.4 [26.9..32.5], stripped 31.0 [29.1..31.8], widened 31.7; int emitted 22.4, widened 22.0. Ranges overlap in every pair; the sign of the difference flips between runs on the int side. The "no measurable difference" claim holds. |
| disasm-exported.out | DIFFERS. The saved file has only the AS EMITTED section. run.sh and disasm.escript also print a TAG TEST STRIPPED section (a no-op for an exported fn). The saved file looks stale or truncated. No effect on E11. |
| bsc-compile.out | REPRODUCED but it is EMPTY (0 bytes). The brief cites "bsc-compile.out + emitted-erlang.out" for E1. Only emitted-erlang.out carries the evidence. |

## 2. Claim vs probe, and circularity hunt
- **stripped variant: faithful.** It deletes exactly the abstract-format node bsc emitted (`{op,_,'=:=',erlang:map_get('Kind',_),{atom,_}}`; I printed Inner's real guard AST and it matches the pattern). It touches only non-exported functions. My count: 1 node removed from private functions, 6 from all functions. The forgery does not pass trivially, as the controls below show.
- **widened variant:** hand-built `is_integer` on spec-integer params. It is a model of option 3, not a compiler output (the brief says so in section 6). It is not tuned to the result: valid input still passes (NestedInt(3) = 4).
- **Negative controls, run by me (/tmp/claude-0/verify59/neg.escript):**
  - Stripping the tag test from ALL functions, exported included, makes Outer(forged Invoice) return 99. So the exported test is what refuses on E2's path, and the strip really does disable a test.
  - With only the private tests stripped, Nested(a Cart tagged Invoice) still raises function_clause in `Nested`. The exported guard still rejects a forged top-level value.
  - With only the private tests stripped, Totals([forged]) returns [99]. E4 holds.
  - The real bsc CLI (`bsc-forged.out`) raises on forged input for both Nested and Outer. That is the status quo, with no patching.
- **Byte costs (E9, E10):** measured on the same function (Inner, IInner) with and without exactly one guard. Code chunk 395 -> 383 B (-12) and 395 -> 400 B (+5), with the disasm instruction counts 8->6 and 6->7. This is a matched comparison. "Matches 26a's +14 B" is loose: the +14 B figure is in ticket 26, line 302, for a whole map_get.
- **Corpus (E13): the number reproduces, the label is wrong.** I recounted independently with a different scanner (any atom 'Kind' in a private function's heads or guards): 25 .abstr files, 21 private functions, 0 hits. **But 7 of the 21 are compiler-generated `bs@validate@*` helpers in Intake.** User-written private functions number 14, still with 0 tag tests. The file list has Shop twice (25 rows, 24 distinct modules). Conclusion unchanged, wording overstated.
- **Benchmark noise handling:** honest. 7 runs of 5M calls, median plus min/max, and the brief says "no difference measurable". It does not claim a cost. The record-stripped vs emitted ordering is inverted in my run, which supports "noise".
- **E8 note:** the "strip" cannot touch the union case (pattern-form tests). The brief says this itself.

## 3. Citations opened
Verified: bs_emit.erl:275-293, :330-333 ("deliberate" at :333), :177-182; bsc.erl:843; 18 :815-818, :613-617, :190-195 (in wayfinder/issues/, not research/); 46 :213-222, :247-250; F37 :170-178; boundary_kind_tests.erl:88; boundary_range_tests.erl:122; guard_kind_tests.erl:14-15; F24 §6 "Privacy is what makes it silent" (line 200). Minor: the brief's "bs_emit.erl:284" is `none when Public` (correct); "26a" should be ticket 26.
Interpretive note: 18 :190-195 argues for guards at the export so interior omission is sound. That reads as support for the exported-guard-plus-interior-omission shape. The brief uses it only for the premise "foreign values reach private functions", which is accurate.

## 4. Per-claim verdicts
E1 confirmed (via emitted-erlang.out; bsc-compile.out is empty). E2 confirmed. E3 confirmed, including by negative control. E4 confirmed. E5 confirmed. E6 confirmed. E7 confirmed. E8 confirmed. E9 confirmed (the 26a attribution is loose). E10 confirmed. E11 confirmed (the saved disasm-exported.out is partial). E12 confirmed as "no measurable difference". E13 confirmed in conclusion; "21 private" includes 7 compiler-generated helpers (14 user-written). E14 confirmed. Neighbour survey: Gleam, Elixir and Dialyzer outputs reproduce. The Elixir types.ex and Dialyzer source line citations were not independently re-read, and the brief does not claim more than a read.

## Overall: PASS WITH CAVEATS
Caveats: (a) E13's "21 private functions" includes 7 compiler-generated helpers; (b) bsc-compile.out is empty and disasm-exported.out is stale; (c) the stripped and widened builds are modelled, not compiler output (disclosed); (d) the corpus has no private record parameter, so E13 shows only latency of the asymmetry, as the brief says. No circular probe found.
