# Verification of brief.md (ticket 39, ENG-211)

Verifier: independent agent, 2026-09-28/29. Same host as the brief: OTP 25 (erts-13.2.2.5, JIT), compiler-8.2.6.3, x86-64 4-vCPU shared VM.
Source used: installed `/usr/lib/erlang/lib/compiler-8.2.6.3/src/` (no download needed).
Nothing outside this file was written. Scratch work was under the session scratchpad.

## Verdict table

| # | Item | Verdict | One line |
|---|---|---|---|
| 1 | `+no_type_opt` costs +0.15% on the Day-01 loop (OTP 25) | CONFIRMED | Reproduced with my own loop and harness (+0.10%, +0.18%), and by a full 300-rep `run.sh` rerun (+0.14%, +0.3%, +0.08%). |
| 1b | `no_type_opt` really removes the annotations, and the timed beams are two different builds | CONFIRMED | md5 differs; 6 `{tr,` in the typed `.S`, 0 in the nt `.S`; Type chunk 116 B vs 26 B. |
| 1c | "The JIT does not exploit annotations on OTP 25" (implied by E4/E5c) | REFUTED (as a general reading) | A control I built shows a 2.02x slowdown with `tr` erased and an identical instruction stream. The Day-01 null holds, but the JIT does consume `{tr}`. See F1. |
| 2a | Six emitter-shaped variants keep all 6 annotations | CONFIRMED-WITH-CAVEAT | Reproduced. The variants are not circular, since the `.abstr` -> `from_abstr` -> `debug_info` path is built as `bsc.erl:843` does. But no single variant combines every emitter feature, and it is not real bsc output (F5). |
| 2b | +6.3% guard cost on exported `spin` (E10) | CONFIRMED | 13.951 vs 13.109 (+6.4%) on my rerun; +6.4% and +6.1% on the other two VMs; stdev is 0.6-1.4 ms and the min is stable to 0.05 ms. It is well above the noise floor. |
| 2c | `v_wrap` "-1.5%, costs nothing" (E11) | CONFIRMED-WITH-CAVEAT | The right comparator is `v_exp` (13.057 vs 13.109, -0.4%), not `v_base`. The -1.5% is the same +1.4% "exported is faster" effect as E12, not a wrapper win. "Costs nothing" is shown, but against a comparator the brief does not name (F6). |
| 2d | Positive control (E5c): tuple loop slows 40% but its instruction count changes | CONFIRMED-WITH-CAVEAT | The instruction counts are right (6 -> 11). It is a valid "no_type_opt can slow things" control, but it is not a control for annotation-only effects. My control is (F1). |
| 2e | Binary control: equal instruction count, "+1..+3% on min, medians +0.3..+3%" | CONFIRMED-WITH-CAVEAT | Instruction counts are equal (13 = 13). The checked-in `control.out` shows +1.1% min and +2.0% median; my rerun shows +0.9% and +0.8%. The "+3%" and "+0.3%" figures are in no checked-in file (F8). |
| 2f | Predictions P1-P10 honestly scored | CONFIRMED-WITH-CAVEAT | P6, P7 and P10 are honestly reported as wrong. The scoreboard omits or softens four other misses (F7). File mtimes are consistent with predictions written before results, but this cannot be proved. |
| 3a | Source claims E1, E5, E7s | CONFIRMED | `beam_ssa_type.erl` 119-121, 381-391, 432-441, 689-695, `compile.erl` 277-288 and `v3_kernel.erl:148` say what the brief says. |
| 3b | E8 "comparison bifs are excluded from type annotation (:629-636)" | REFUTED | The source says the opposite (F2). The conclusion, that no relational operator narrows integer ranges, stands. |
| 3c | E8 `infer_type` clause list and fallback | CONFIRMED-WITH-CAVEAT | The clause list is right. The fallback is at `:2370`, not 2369. |
| 3d | E15b: Erlang spin Pos is `{-99,99}` on OTP 25, not `{0,99}` | CONFIRMED | `tr_summary.out` and my own `my_a.S` line 17 show `{t_integer,{-99,99}}`. |
| 3e | Elixir equivalence probes are real | CONFIRMED-WITH-CAVEAT | `elixirc` really produced `Elixir.BenchEx.beam`; the sizes come from it (spin 19, wrap 4, Type 116 B). The `{tr}` listing comes from recompiling the debug_info forms, which the brief says. Its module count of 8 is `grep -o` occurrences while the Erlang rows use `grep -c` lines (6). Cosmetic. |
| 4a | Every MEASURED row maps to a real output | CONFIRMED-WITH-CAVEAT | Yes, except E2's ".beam 1344 B" (it depends on the build path: 1392 B in my directory) and E5c's "+3% / +0.3%" (F8). |
| 4b | Nothing labelled MEASURED concerns OTP 28, Gleam or bsc | CONFIRMED | |
| 4c | Honest framing: OTP-25-only, 20% could be real on OTP 28 | CONFIRMED-WITH-CAVEAT | Stated repeatedly and correctly. Two sentences still overreach (F3, F4). |
| 4d | Recommendation (run §3.2 on OTP 28 against real bsc `.abstr`) follows from the evidence | CONFIRMED | It is the only step that can discriminate. My additions to it are in F9. |

## Findings

### F1. The JIT does consume `{tr}` on OTP 25, and the brief's reading of its own controls is too weak (benchmark validity)

**Brief.** "Whether the JIT consumes `{tr}` at all on OTP 25 - not shown", and "on OTP 25 I saw slowdowns only where the instruction stream changed, never from annotations alone" (E5c).

**Control I built.** `pc.erl` is a loop of ten adds over `band`-bounded values. Compiled with and without `+no_type_opt`, the two `.S` files are identical after erasing `{tr,R,_}` to `R`. I checked this by consulting both and comparing: 17 instructions each, empty differences both ways, and the same opcode list.

**Result.** The typed build runs in 23.97 ms and the nt build in 48.49 ms (min of 240 samples each, ABBA order, answers equal). That is 2.02x.

**What it means.**
- The harness style can see annotation-only effects, and the OTP 25 JIT does use them.
- The Day-01 null is therefore a property of this loop on this CPU and JIT. It is not JIT blindness.
- The null is stronger than the brief lets it be. It now carries a sensitive positive control instead of only the tuple one.
- It also sharpens the question for OTP 28. The JIT can use the annotations, so whether bsc's real output differs there is a fair question.

I also tried the obvious rescue, that two `idiv`s dominate the loop and mask the annotations. A `wrap` variant with no `rem` (`w_a`/`w_b`) runs at 10.87 ms and is still null (+0.5% min). Division is not the explanation. The loop is call-bound and list-bound.

**Correction requested.** Change the E5c and "What I could not verify" text. Drop "never from annotations alone", and cite a control like this one.

### F2. E8 mis-states `beam_ssa_type.erl:629-636` (source claim)

**Brief.** "comparison bifs are excluded from type annotation."

**Source.** `benefits_from_type_anno({bif,Op}, Args) -> not erl_internal:bool_op(Op, length(Args))`. `erl_internal:bool_op` is true only for `and`/`or`/`xor`/`not`. I ran it: `bool_op('<',2)` is `false`, and `comp_op('<',2)` is `true`. So comparisons are annotated. The brief's own `tr_summary.out` shows it: the `is_ge` tests in `v_exp_rng` carry `{tr,{x,0},{t_integer,any}}`.

**What survives.** The conclusion is right. `infer_type/4` has no relational clauses (lines 2260-2370), so a comparison consumes the argument type and never narrows it. The wrong sentence should be replaced with that.

### F3. Headline wording "did not survive its own §3.2 experiment" reads as a refutation (framing)

The next sentence scopes it to OTP 25 and to "Erlang alone", and the caveats are correct. A reader who stops at the headline still takes away "hypothesis dead". Suggested change: "was not reproduced on OTP 25". The brief also says "I could not reproduce the missing-annotation state at all" (sub-decision a). That is contradicted by its own E1m and E4, which do reproduce a missing-annotation state (`v_exp`: 3 of 6 `tr` gone; nt: 0 of 6) and show it is not slow. Say instead that the bsc-shaped private form never lost annotations.

### F4. The "identical modulo register liveness" advice is an over-reach

The 2-vs-4 live-count difference is between typed and untyped Erlang. It is a consequence of the type information: the typed `+` cannot overflow, so it needs fewer live registers. It is not evidence about the ticket's beam-sharp-vs-Erlang comparison.

The ticket says the instruction lists were `A =:= B`. The brief's own data shows a stripped-annotation build has a different live count. So if the real beam-sharp `+` had lacked its type, the ticket's `A =:= B` would probably have failed on OTP 28 too. That hints the real difference is narrower than "Spin's operands are bare". It is a hint only, not a measurement.

The brief also does not reconcile "26 instructions each" (ticket) with 19 + 4 = 23 here. Do not tell the ticket to reword "identical" on this evidence.

### F5. Circularity hunt: emitter-shaped variants (no circularity, but limited)

**Checked against source.**
- `bs_emit.erl:21` is `-define(A, 0)`.
- `bsc.erl:838-845` builds with `[from_abstr, debug_info, ...]` on the `.abstr` text.
- `bs_emit.erl:72-75` adds the exported `'bs@type_atoms'/0`.
- `bs_emit.erl:1330-1336` emits a `-spec` for every function.
- `mkabstr.erl` writes `~p.` forms with every anno mapped to 0 and calls `compile:file(from_abstr, debug_info)`.

The variants were not built so that they cannot differ. `v_exp`, `v_exp_rng` and the nt builds all do differ from base, and the identity check asserts non-empty streams.

**Gaps.**
- `v_abstr` uses BSSHAPE + SPEC_WIDE + BSATOMS but not REMOTE. `v_remote` is built by `erlc`, not through `from_abstr`. I built the full combination (`v_all`: BSSHAPE, REMOTE, SPEC_WIDE, BSATOMS, line 0, `from_abstr`, `debug_info`). It keeps all 6 `tr`, and its time is 13.248 vs 13.299 ms (base), also null.
- `'bs@type_atoms'/0` is `#{}` in the probe. The real one interns literal atoms.
- No `-file` attributes, no B#-specific name mangling and no real clause lowering (`kind_tested`, `strip_rels`) are present.
- Real `Day01.abstr` has never been seen. The brief says so. The only proof would be compiling it.

### F6. E10/E11/E12 noise floor and comparators

**E10 (+6.3% guard).** Reproduced closely: 13.951 vs 13.109 (+6.4%) on my rerun, +6.4% on the checked-in first run, and +6.4%, +6.1% on the two extra VMs. Min stdev across processes is about 0.05 ms and the effect is about 0.84 ms. It is a real difference.

The guard adds 6 instructions to `spin` (19 -> 25), so a cost is expected. The brief's own caveat applies: it is a microbenchmark on exported self-recursion that no shipped exemplar pays.

**E12 (exported is 1.3-1.5% faster).** Reproduced on all three VMs. The brief is right that the cause is uninvestigated. It should not be read as a benefit of losing ranges. In the first run `v_exp_spec` shows -2.5% against `v_base`, but -0.4% against `v_exp`, so "1.3-1.5%" holds only for the later runs.

**E11 (v_wrap -1.5%).** The stable -1.5% is E12's exported-args effect. Against `v_exp` the wrapper is -0.4%, i.e. free. The brief says "costs nothing" and that is right, but the comparator should be `v_exp`.

**E7 vs E12.** The brief calls 12.941 vs 13.101 ms (`v_exp_spec` vs `v_exp`, 1.2%) "within run noise" and calls 1.4% (exported vs private) real. Both are defensible only because the extra VMs put `v_exp` and `v_exp_spec` within 0.03 ms of each other. State that reason.

### F7. Predictions P1-P10 scoring (honesty)

**Order and editing.**
- The header lists P1-P6, P8, P9, P10, then P7. P8-P10 carry "written before X first ran" notes. P7 is appended last, out of order.
- `run.sh` and `loop.erl` have the same mtime as the results, 23:38, and `timing.out` is 23:40. The mtimes are consistent with predictions being written first, but there is nothing to prove it. P3, P4 and P5 also cite source lines, so they are source-informed, not blind.

**Honestly reported as wrong.** P6 (predicted 5-25%, saw +0.15%) and P7 (predicted slower, saw 1.4% faster) are scored honestly.

**Softened or missing.**
- P10 predicted "within 1% of v_base". The result was -1.5% (12.94-13.08 vs 13.27), outside the stated tolerance. The brief calls it "wrong in direction only", which understates it. It is wrong on the number that the prediction gave.
- P1 predicted `{0,99}`-style ranged annotations on Pos. The result is `{-99,99}`. The brief records this in E15b but the scoreboard ("P2-P9 held") does not list P1.
- P3 predicted "no change to the instruction sequence". The brief's own identity check shows the `+` live-count change (2 vs 4). The brief says P3 held.
- `ctl.erl`'s own header predicted "tuple loop: none expected" and "binary-match loop: expected measurably slower". The tuple loop slowed 40%, and the binary loop slowed about 1%. Both predictions were wrong. `run.sh` P9 says "may or may not", so the brief scores P9 as exploratory and not wrong.
- P8 held (v_remote is identical to base in `tr` and time).

### F8. Label discipline on measured numbers

- E5c "+1%..+3% on min, medians +0.3%..+3%" for the binary control appears in no checked-in `.out`. `control.out` has +1.1% min and +2.0% median. My rerun has +0.9% and +0.8%. The claim should quote the checked-in numbers.
- The same control's min and p10 both move about +1.1%. That is the magnitude the brief treats as real in E12 and as "noise-level" in E5c. Treat it consistently.
- E2's "`.beam` 1344 B" depends on the build directory (compile info embeds the path). Not reproducible byte-for-byte, and it is not a claim that matters.
- E17 (RECORDED): "ticket 20's intervals are 'exact'" is not what `20-untheorised-term-shapes.md:720-725` says. That range says integer ranges are quantised in `erl_types`. The "exact" wording comes from ticket 39 §2 and CDuce (`:279`). Cite ticket 39 §2 for the ticket's own claim.
- Line references: `beam_ssa_type.erl` fallback is `:2370`, not `:2369`.
- I could not verify the claim that `bsc` cannot be built because it needs OTP 28 leex `TokenLoc`. The brief flags it as not verified, and I did not test it.

### F9. What the brief should also say (omitted hypotheses and additions to Option 1)

- **Harness order.** The ticket's `aoc/bench/bench.erl` times the four implementations sequentially in fixed order (Erlang, Elixir, Gleam, beam-sharp last), and `aoc/bench/README.md` documents that the fib harness measured GC order. I ran four copies of identical Erlang in `bench.erl`'s sequential style (25 runs each, three repeats). The mins agree within 0.9% and there is no last-slot penalty on OTP 25. So order bias is unlikely on 25, but it is untested on OTP 28. Option 1's interleaved harness would rule it in or out. It should be listed as a competing explanation.
- **Diff the real forms first.** Before the timing step of Option 1, diff `{tr}` and live counts on the real `Day01.abstr` under `erlc +to_asm`. This is 5 minutes and could settle it without a timing run.
- **Wrap range.** OTP 28's Erlang `spin` reportedly carries `{0,99}` (ticket) against `{-99,99}` here, so OTP 28's range analysis is finer. That is another reason OTP 25 is a weak proxy for the sign and size of any effect.

## What the brief says correctly

- The null is scoped to OTP 25 in the header, sub-decision a, "What I could not verify" and Option 1's counterargument.
- Option 3's OTP-28 comparison caveat is honest.
- Nothing about Gleam or bsc output is labelled MEASURED.
- The recommendation (Option 1 first) follows from the evidence, and the "advances nothing under the CLAUDE.md progress rule" note is fair.

## Overall verdict

**May go to a human after corrections. It does not need re-running.** The core measurements reproduce: the +0.15% null, the +6.3% guard cost, the annotation counts and the source citations. There is no circularity in how the variants were built. The recommendation stands.

Required corrections before it goes out:
1. **F2.** Fix E8's statement about `benefits_from_type_anno`, and point at the missing `infer_type` clauses instead.
2. **F1.** Replace "JIT consumption not shown / never from annotations alone" with the fact that the JIT consumes `{tr}` on OTP 25 (cite an identical-stream control). Add the control to `probes/` if it is to be cited.
3. **F3.** Soften the headline ("was not reproduced on OTP 25") and the "could not reproduce the missing-annotation state at all" sentence.
4. **F4.** Drop or hedge the "identical modulo register liveness" advice, or state that it comes from typed-vs-untyped Erlang and says nothing about the ticket's beam-sharp build.
5. **F7.** Rescore P1 and P3 as partial misses, P10 as outside its stated tolerance, and count `ctl.erl`'s two wrong predictions.
6. **F6.** Name `v_exp` as the comparator for the wrapper result.
7. **F8.** Quote the checked-in control numbers, and fix the E17 and `:2369` citations.

F9 is optional but worth adding to Option 1.
