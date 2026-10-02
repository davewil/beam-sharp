# Verification of artifacts/39-emitted-code-quality.md (independent)

Verifier re-ran `artifacts/probes/39/run.sh` from scratch with RUNS=30 (brief used 60), TMPDIR in scratchpad, gleam 1.12.0
at the given path (also rebuilt the Gleam project from a deleted `build/`: same generated file, `inline` on line 2).
Result: "ALL OBSERVATIONS HOLD", every assertion PASS. Plus my own falsification runs (section 3).
Repo tree unchanged by me except this file.

## 1. Row-by-row comparison (my RUNS=30 vs brief RUNS=60; min over rounds, ms)

Spread seen: min-to-median ~25% (9.0 vs 11.6) as the brief says; min itself moved 1-3% between my runs
(v_erl 8.96 / 9.09 / 9.45(reverse run); v_inline 7.93 / 8.13 / 8.11). With 30 rounds individual rows wobbled up to ~4%
(v_spec_bsc 9.33, v_guard 9.43); 60 rounds is visibly steadier. Only ratios of >5% are decision-grade.

| claim | brief | mine | verdict |
|---|---|---|---|
| JIT VM, OTP 25, Elixir 1.14 | as stated | identical header | CONFIRMED |
| hot loop is ~98% of run | 8.88 vs 9.03 | spin min 8.9 vs full 9.0-9.1 (same columns in every run) | CONFIRMED |
| bsc build path loses nothing in wrap/hit/spin | asm identical | identical (md5 of extracted asm, PASS) | CONFIRMED for hand-written forms; see C1 for what it cannot show |
| remote rem = rem op | identical asm | identical | CONFIRMED |
| spec wide/narrow invisible | 0.998-1.00 | 1.001, 1.003, 0.999 | CONFIRMED |
| strip tr: not slower | 0.984-0.992 | 0.986, 0.991 (and 0.987/0.994 variants) | CONFIRMED (the mechanism is indirect, see C2) |
| bs_emit return guard free w/o inline | 0.999-1.009 | 0.999, 1.006 | CONFIRMED |
| range guards: tr stays `any`, 6+ is_ge, 1.01-1.03 slower | | `{y,2},{t_integer,any}` still; is_ge>=6 PASS; 1.016-1.037 (30 rounds), reverse run 1.155/1.145 vs v_erl 1.192/1.126 (noisy) | CONFIRMED (direction; size 1-4%) |
| optimiser infers wrap return {-99,99} regardless of spec | | `var_info {x,0} {-99,99}` seen in v_inline_bsc asm, identical for spec variants | CONFIRMED |
| -compile(inline) 1.136x faster | 1.136 (0.88) | 1.118-1.137 (full), spin-only 1.146 | CONFIRMED |
| inlined asm has `{tr,{x,0},{t_integer,{0,99}}}` on the hit compare | | seen in v_inline_bsc spin (is_eq_exact on `{tr,{x,0},{t_integer,{0,99}}}`) | CONFIRMED |
| Gleam emits inline; Elixir/Erlang do not | | `-compile([..., inline])` regenerated from clean build; module_info options as listed | CONFIRMED |
| Gleam == Erlang+inline 0.999; Elixir == Erlang 0.998 | | 0.983 (30 rounds), 0.999; Elixir 0.999/1.003 | CONFIRMED |
| guarded wrap defeats default inliner (call wrap/1 remains) | | `{call,1,{f,2}}. % wrap/1` in v_rginline_bsc spin, absent in v_inline_bsc; hit IS inlined | CONFIRMED |
| ...costs ~2% (borderline) | 1.02 | 1.015, 1.020, 1.021 (reverse), 1.045 (other input) | CONFIRMED, honestly labelled "not asserted" |
| explicit inline list inlines guarded wrap, 1.003x | | 0.997, 0.990; asm has no wrap call | CONFIRMED |
| inlining removes frames | `[h,g]` vs `[f]` | identical | CONFIRMED (but see C5: only top-3 frames of a trivial chain) |
| code size "v_erl 1288, bsc-path 1792, inline+bsc 1668" | | v_erl 1288 matches; I get v_erl_bsc 1872, v_retguard_bsc 1948, v_inline_bsc 1748, v_rginline_bsc 1832, v_rgexplicit_bsc 1916 | DISAGREE (1792/1668 match no variant I can build; unlabelled which variant; minor, not decision-relevant) |
| `rec_inline.erl` compiles | | PASS | CONFIRMED (weak: only proves erlc terminates; the test function is not even meaningfully recursive-inlinable; claim "buys nothing" is untested) |
| beam-sharp 1.20x on OTP 28 | not re-run | not re-run; labelled "not verified" | CONFIRMED as honestly labelled (only in README/ticket, aoc/bench/README.md:46,53 says 1.20x, 20%) |
| "return guard did not exist when ticket raised (F42 2026-09-11, F52 2026-09-19; ticket 2026-08-15)" | cited | F42 `Status done 2026-09-11`, F52 `done 2026-09-19` verified in the F-files; ticket date and "20% measured a bsc with no guard" not verifiable | UNVERIFIABLE (labelled cited; ok). Note it is an inference: the README measured date is not given, so it is possible the bench ran later than F42 |

## 2. Citation check (opened each file)

- bs_emit.erl:74-97 forms/1 lists module, export, behaviour, rec_type_attrs, type_atoms_form, file_group (spec/function), validator_forms, reserved_forms. `grep "attribute, ?A, compile"` and `", compile,"` over compiler/src finds nothing. CONFIRMED (caveat: validator_forms/reserved_forms were not opened by the brief; they emit functions, no compile attr found by grep).
- bs_emit.erl:1045 `expr({e_op,...}) -> {op,...}` CONFIRMED. :1120 e_foreign_call -> `{call,{remote,{atom,Mod},{atom,Fn}}}` CONFIRMED (actually starts 1119-1120).
- bs_emit.erl:1120-1131 wrapped/unwrapped return_guard, 1241-1247 `return_guard` emits `case Call of V when type_test -> V end`, 1282-1283 int_tests: CONFIRMED, line numbers accurate. Note the guard is emitted only if the declared ret type is not a supertype of term; `int` -> `is_integer(V)` only, which is what v_retguard uses. CONFIRMED.
- bs_emit.erl:1585-1591 int_part: CONFIRMED (range, non_neg_integer, pos_integer, neg_integer, widening fallback). The comment says widened "no Erlang spelling" as claimed.
- bsc.erl:833-846 build/compile options `[from_abstr, debug_info, {outdir..}, report_errors, report_warnings]`, and bs_emit.erl:2501 `to_abstr` ~p latin-1: CONFIRMED (pipe.escript mirrors both).
- bs_check.erl:156 `foreigns => Foreigns` CONFIRMED (the "call-graph" suggestion is a proposal, not a claim).
- aoc/bench/Day01/bench_bs.bs matches the B# shown in Option 1 (Wrap/Hit/Spin). CONFIRMED; Option 1's declared `using :erlang { int rem(int,int) }` is what makes the guard `is_integer`.
- Claims with no probe: "Spin/Wrap exceed default inline size so guard defeats inlining" is observed output only (compiler source not installed; brief says so). "Option 2: not_recursive needs a call-graph pass the emitter lacks" is unprobed assertion about bs_emit (I did not find a call-graph pass either, but did not exhaustively search). "Compile time not measured" honest.

## 3. Circularity hunt and my own falsification attempts

Variant diffs (v_erl vs each): every variant differs from baseline ONLY in the named attribute/guard/spec/export. v_noanno and v_noanno_inline differ solely by `-export(spin/4)`. No variant shares code with the baseline in a way that hides a difference; v_inline differs only by `-compile(inline)`. The `*_bsc` forms are the same sources re-piped through pipe.escript (all annos 0).

F1. Reversed round order + different input. I ran bench:main with the module list reversed on (a) the real input and (b) a synthetic 20,000-line random L/R input (606,494 clicks, different answer), 40 rounds, including Gleam. Same picture both times: plain/spec/retguard/noanno/guard/Elixir ~1.13-1.19; inline/Gleam/explicit/noanno_inline ~1.00-1.02; rginline ~1.02-1.045 above plain inline. Order or input does not drive the result. (Min of bench_gleam was 6% off in one run, an outlier; the median column agreed.)

F2. Mutations. (a) `v_mut1`: inline variant with extra `rem` work in wrap: 1.25x slower, so the harness resolves a 25% change and is not saturated by the floor. (b) `v_mut2`: hit(0)->2, wrong answer: bench prints `ANSWER MISMATCH v_mut2 ...`. Harness detects it. BUT see C3.

F3. Asm assertions: confirmed non-vacuous. The negative greps (`% wrap/1` absent for inline/explicit) could pass on an empty extraction, so I looked at the extracted spin asm for v_inline_bsc and v_rgexplicit_bsc: it is non-empty, a real loop with `call_only spin/4` and no wrap call. Positive control v_rginline_bsc shows the call.

### Circularity / weakness findings

- C1 (CIRCULAR-SUSPECT for "bsc build path loses nothing", and for the central discrediting of the ticket's mechanism). The ticket's own observation is that beam-sharp's real Spin has bare `{x,0}` operands while Erlang's has `{tr,...}`. The replica reproduces the opposite: forms piped through bsc's build path keep `{tr,..}` (identical to erlc). The brief's `v_noanno` obtains bare operands only by exporting `spin/4`, which the real `private Spin` is not. So the probe family never reproduces the symptom it set out to explain; "the bsc path loses nothing" is true only of hand-written forms chosen to look like bsc output, and the discrepancy with the ticket is left open (brief section 7 admits bsc could not run and the 20% is unexplained, but section 1 states "the hypothesis did not survive" more strongly than this supports). What was shown: on OTP 25, removing tr from this loop costs nothing. What was NOT shown: that real bsc output lacks tr because of anything the probes tested. Possible untested cause: something in real forms (reserved_forms, type_atoms export, boundary guards on head, line annos, file attributes) changing inference. The claim "contradicts the ticket's mechanism" should read "contradicts it as a mechanism for this loop on OTP 25, but does not explain the observed bare operands".
- C2 (weak indirection). The "strip annotations" test is "export the function", which changes more than the tr annotations: it changes callee-visible type info, but the generated code (asm) differs only in operand annotations, as the probe checks. Acceptable, but "strip tr" is a proxy.
- C3 (check gap). `bench.erl` prints `ANSWER MISMATCH` but `run.sh` never greps for it, so the brief's statement "exits non-zero if any observation fails ... answer 6770 checked for every variant" is overstated: a wrong-answer variant would still end with ALL OBSERVATIONS HOLD (I confirmed the print happens for v_mut2, run.sh has no grep for MISMATCH). In the committed results.txt no mismatch is printed, so the actual variants do agree (I also saw no mismatch in my runs). Also the check compares variants to the first module's answer, not a hard-coded 6770 (fine, but the brief's wording "6770 checked" is by transitivity from v_erl).
- C4 (timing thresholds chosen post hoc?). Asserts use +/-3% bands; observed deviations are 0.1-1.6% so the bands are not tuned to pass narrowly, except range guards (a one-sided `>=0.99`, and observed 1.013-1.037, i.e. it asserts only "not faster"). The brief's "1.01-1.03 (slower)" is within noise at the low end: the claim "slower" is directional-only, not demonstrated at 60 rounds. UNDERPOWERED rather than circular.
- C5 (stack frame test is thin). st_plain/st_inline is a 3-function toy; shows frames vanish under inlining (true and expected), says nothing about line numbers or F15's actual requirement. Fine as stated.
- C6 (hit/spin parity relies on hand transcription). The `*_bsc` forms and the retguard text were written by the briefer from bs_emit source (v_retguard.erl uses `V1`/`V2` names; real names come from `wrapper_var("bs@rv", N)`, irrelevant to codegen). Real emitted Spin may add head type guards at the boundary (ticket 18, F3) that v_guard only approximates; Option 2/3 recommendations are therefore measured on a replica. The brief says so in section 7.
- C7 (Option 2 benefit is on a loop that the harness itself notes is 98% hot loop, one workload, one OTP). Stated by the brief.

No variant is baseline-contaminated; no expected value is hard-coded into a pass condition except the asm regexes that encode the claimed observation, and those were checked against the real asm above and have controls (v_rginline_bsc for the "call remains" positive case).

## 4. "Cited, not re-run" labelling

Checked every status cell. Items not measured here are labelled: OTP 28 1.20x ("not verified"), F42/F52 timeline ("cited"), bs_emit.erl:1585 spec widening ("cited (read from source)"), beam_ssa_type behaviour ("cited from output only"). `OTP 28 prints {0,99}` appears in run.sh PASS text as "(cited)". None presented as measured. One mild exception: the brief's "Elm: N/A, not probed" is fine. The "Gleam 1.18.1 no longer emits inline or ticket cause is something else" is flagged as an open alternative; fine. Code size line is presented as measured with `wc -c` but I could not reproduce 1792/1668 (DISAGREE above).

## 5. Verdict list

- JIT/toolchain: CONFIRMED
- hot loop ~98%: CONFIRMED
- bsc build path loses nothing (hand-written forms): CONFIRMED for the replica; CIRCULAR-SUSPECT as evidence about real bsc output (C1)
- remote rem == rem: CONFIRMED
- specs invisible / no time effect: CONFIRMED
- stripping tr does not slow loop (OTP 25): CONFIRMED; "contradicts ticket mechanism": CONFIRMED only narrowly (C1, C2)
- return guard free without inline: CONFIRMED
- guard-timing precedes ticket (F42/F52 dates): UNVERIFIABLE (cited; dates in F-files CONFIRMED)
- range guards do not narrow, add >=6 tests: CONFIRMED; "slower 1-3%": CONFIRMED directionally, near noise
- optimiser infers {-99,99} regardless of spec: CONFIRMED
- inline = 1.12-1.14x: CONFIRMED (robust to reversed order and different input)
- Gleam emits inline / == Erlang+inline; Elixir == Erlang: CONFIRMED (clean rebuild)
- guard defeats default inliner (asm): CONFIRMED; its ~2% cost: CONFIRMED, borderline
- explicit inline list works: CONFIRMED
- stack frames lost: CONFIRMED (toy)
- code-size figures 1792/1668: DISAGREE (1288 matches; others not reproducible)
- "answer checked for every variant / probe exits non-zero": DISAGREE in part (C3: mismatch is printed, not gated)
- OTP 28 / Apple Silicon 1.20x: UNVERIFIABLE (honestly labelled)
- Compiler citations (bs_emit.erl, bsc.erl, bs_check.erl lines): CONFIRMED
- Option 2 `not_recursive` call-graph claim, inliner-size reasoning: UNVERIFIABLE (no source / no probe)

Overall: the measured claims are real and reproducible, robust to my reversed-order, new-input and mutation tests; no variant is rigged
or shares the baseline's code. The weakness is inferential, not numeric: the probes never reproduce the ticket's actual symptom (bare `{x,0}` in real
bsc output, 1.20x), so they establish "annotations and spec are not the lever on this OTP-25 replica, inlining is", not "the ticket's cause is refuted".
Recommendation in section 6 (do not decide yet, run the ticket's own harness on OTP 28) is consistent with that. Fix items: gate MISMATCH in run.sh,
correct or drop the code-size numbers, and soften section 1's "did not survive" to scope it to the replica.
