# VERIFIER: ticket 39 / ENG-211 brief

Independent rerun. Same box: OTP 25.3, JIT, 4-vCPU Xeon @2.8GHz. All scripts re-run from copies with the author's hard-coded scratchpad paths rewritten to `.../verify39/w`. The author's files are untouched. Reruns are `*.rerun*.out` in this directory. My interleaved harness is `ilv.erl` here.

## 1. The shim

- `diff -r compiler/src <shim>/src` shows the only source change is `bs_lexer.xrl`. Every `TokenLoc` becomes `{TokenLine,1}`, and an `adjust_col/3` helper is appended. `bs_emit`, `bs_check`, `bs_parser` and `bsc` are byte-identical to the repo. I rebuilt it from scratch.
- My `Day01.abstr` is `cmp`-identical to the author's. The build is deterministic.
- Could the shim bias results? I tested it directly. I took the emitted `Day01.abstr` and rewrote every column (1, 23, and bare line numbers with no column). Compiling with `+from_abstr +debug_info` gave an **identical `Code` chunk** (md5 equal) in all three cases. Columns never reach the optimizer, so the shim cannot alter instructions or `{tr}` annotations.
- `bs_emit` uses `?A = 0` for most forms. Token annotations are only line information.
- I could not build a shim that keeps columns. OTP 25 leex has no `TokenCol`, so I checked on the `.abstr` instead. Residual risk for the code under test is nil.
- The shim does not exercise the checker or diagnostics, as the brief admits.

## 2. Per-probe table

| probe | reproduced? | notes |
|---|---|---|
| 00 shim build | yes | `.abstr` identical to the author's. `00` honours `$W`; the other scripts hard-code the author's scratchpad and are not portable. |
| 01 Day01 timing | **yes for "no gap"; no for the spreads** | See section 3. The brief's "Erlang 1.07-1.29x, Elixir 1.00-1.23x, order flips" is harness noise, not a measurement of Erlang. |
| 02 strip types | yes (counts exact), timing direction differs | tr 6 to 0, var_info 11 to 0, beams 1324/1376/1264 B reproduced exactly. 3 reruns of `+no_type_opt` vs default: min **+7.2, +4.7, +3.2%**, median +5.9, +4.1, +2.6%. Control d2 vs d: +1.8, -1.5, -3.6%. In my reruns stripping was consistently slower by about 3-7%, never 20%. |
| 03 carry ranges | yes | Instruction text identical. Absolute beam sizes are **path-dependent** (800 B here vs 792 B recorded, because paths are embedded). The brief's "+20 B" delta (800 to 820) holds. The literal "792 B" does not reproduce elsewhere. |
| 04 guard cost | partly | Tests-in-Spin counts (1,1,2,1,3) and sizes reproduced. `when Left > 0` min vs plain: **+9.1, +7.8, +5.4%** (author +11.1, +12.7). Median **+1.4, +2.0, -0.9%**. Redundant guard (vc) is -0.6, +1.5, -0.4% min, about 0. True guard on Zeros (vd) is -1.5, -0.9, -1.0% min, about 0. The brief's "+11-13%" is the high end of a 5-13% min spread. |
| 05 record dispatch | yes, and clearer than the brief says | 3 reruns, hand Erlang with tag test vs no tag test: min **+32, +31, +29%**, median +27, +16, +17%. bsc RecLoop vs no tag test: min +27, +24, +23%. Noise control within 0-3%. Direction and rough size survive. "Minima unresolvable" was that day's machine, not a property of the test. |
| 06 public boundary | yes | Output differs only in absolute `.bs` paths. Next carries `is_integer andalso >= andalso =<`, and the `+` operand stays `{t_integer,any}`. |
| 07 `{tr}` equality | yes | See section 4. Not vacuous for Spin, Wrap, Hit, Clicks. **Vacuous for Sign and Size (0 = 0).** |
| 08 wrapper erased | yes | Output identical. Sign and Size DIFFER, as disclosed. Normalisation is lossy (section 4). |

## 3. Timing: noise floor and what survives

My interleaved harness (`ilv.erl`, output `01_interleaved_mine.rerun.out`):
- 120 round-robin rounds per run, 4 run orders.
- Four contenders: `bench_erl`, a **byte-identical renamed copy** of it (`erl2`), Elixir, and bsc Day01.
- Answer checked before timing.

Results over 4 orders:
- Min spread across ALL four contenders is **0-2.7%**.
- Identical-code (erl vs erl2) difference is 0.1-0.7%.
- bsc rel-min is 1.000-1.009. Erlang is 1.007-1.027.
- Medians agree within about 3%.

**bsc is not slower than Erlang on OTP 25.** The claim is true, and stronger than the author's own harness shows.

The author's harness (`bench4`) times each implementation in its own sequential block, in fixed order Erlang, Elixir, bsc. In it, identical-class code (Erlang vs Elixir) spread up to 1.19-1.29x across the author's 6 runs and my 3. So that harness's noise is **about 20-30%** at min, not the "~5% at min" in the brief's Limits section. The 1.2x readings there are drift, not signal. Bsc being fastest in 5 of 6 author runs is partly an ordering artefact. The conclusion holds only because my interleaved rerun reaches it independently.

Claims versus the noise floor, against the 10% bar:
- "No time gap on OTP 25": **stands**, per my interleaved run.
- `+no_type_opt` (02): the brief's "inconclusive, -3.1 / +12.5%" is too pessimistic. A clean 3-7% slowdown shows in 3 of 3 reruns. It is under 10% and far under 20%. That is **evidence against** stripped annotations explaining 20% on OTP 25.
- `Left > 0` (04): +5-13% at min, about +1% at median. "+11-13%" must not be cited as the cost of a loop-carried compare in Option B's evidence.
- Tag test (05): holds at about +17-30%.

## 4. Differ and control checks

- The `07` differ's regex matches real data. Spin yields 9 annotations (4 `{tr}` plus 5 var_info), ranges included, e.g. `{tr,{x,0},{t_integer,{-99,99}}`.
- `grep -c '{tr,'` gives bench_erl.S = 6, Day01.S = 6, nt/bench_erl.S = 0. Raw counts agree with the differ.
- The `+no_type_opt` self-test fires. The author's `tail -4` hid most of it. Full output (`07_selftest_full.rerun.out`) shows DIFFERENT on Wrap, Hit, Spin and Clicks, with 0 `{tr}` on the Erlang side. The control is real.
- **Weak spot:** the self-test never shows the differ catching a range-only difference (`{0,99}` vs `{-99,99}` vs `any`). The range text is in the counted string, so it would, but nothing demonstrates it.
- **Vacuous rows:** `sign` and `size_` report SAME with 0 annotations on both sides. They add nothing, and their sources differ anyway.
- **Not testing the ticket's exact claim:** on OTP 25, Erlang's Spin has `{-99,99}`, `{-1,1}`, `{0,1}` and no `{0,99}`. The ticket's `{t_integer,{0,99}}` is an OTP 28 artefact that cannot appear here. So 07 shows "no gap on 25". It cannot show the ticket's observation is wrong.
- 08 normalisation maps every `{f,N}` to a constant, drops `{line}`, `{label}`, `var_info` and call dealloc operands, and strips function names. Sequences are compared modulo jump targets. "Identical" means opcode and operand order, not control-flow graph. Acceptable, but it should be stated.
- 08 **depends on 07's output directory** (`v07`). The Probe index's "each .sh runnable alone after 00" is false for 08.

## 5. Circularity and weakness hunt

- **Variant d of 04** was replaced after a false guard (`Pos =< 98`) crashed the answer check. The replacement (`Zeros >= 0, Zeros =< 1000000`) is a true guard on a different variable. I judge it fair: the original could not have produced a valid timing, and the brief discloses it. Not circular.
- **05's fixture:** Erlang sides are hand-written from the emitted semantics. The with-tag and no-tag pair differ only in the `when map_get(...)` guard, so the pair isolates the tag test. bsc's own RecLoop is consistent with the with-tag version. The brief already admits "not bsc output". Fine.
- **Fixture source differences:** Sign and Size differ in source (2 clauses vs 3). The brief discloses this. They also execute only 4,732 times.
- **03's carriers are Erlang sources**, not bsc output. `-spec f(0..99)` is narrower than bsc's widened spec. So "spec inert" is shown for the compiler, not for bsc's own emitted specs, although the ticket's own earlier strip test covers that.
- **Claims with no probe, or RECORDED passed off as measured:**
  - "no installed language injects a declared type": the Gleam half is unchecked and says so. There is no Elixir source.
  - The "OTP 28 does something different" speculation has no probe, and none is possible here.
  - `beam_ssa_type` ignoring user specs: the citation is real and the grep for `spec` is correct, but it is OTP 25 source only.
  - fib dead heat, ticket 59's +14 B and ticket 18's +3-5 B are correctly marked RECORDED. I checked them against the tickets.

## 6. Citations checked

- `beam_ssa_type.erl:18-26` OK. `:629-655` is really 628-655, OK. `:812` `opt_ranges` OK. The spec hits at 78, 424, 471, 743, 812 and 2166 are real.
- `compile.erl:268-283` OK. The r24 clause is at 276-277, so ":277" holds for `no_ssa_opt_ranges`.
- `bsc.erl:843` OK. `bs_emit.erl:274` is `guard_one/7`, OK. `:335` is `int_guard/6`, OK.
- **Wrong citation:** BRIEF sub-decision 2 says Wrap's range is re-inferred "(07, 01 asm)". `01` prints no assembly. The evidence is the `Day01.S` that `07` builds (Wrap shows `{-99,99}` and `{1,199}` there). No recorded `.out` captures those ranges, since 07 prints only counts.
- Ticket 59 line 59 (+14 bytes) OK. Ticket 18 lines 438 and 599 (+3-5 B) OK.

## 7. Verdict

**Stands (reproduced):**
- The shim cannot bias the emitted code.
- On OTP 25, bsc Day01 equals Erlang in time (my interleaved run, under 3%), and Spin, Wrap, Hit and Clicks carry equal annotation multisets.
- Wrapper erasure (08).
- `-spec` inert on this compiler (03 c1).
- `is_integer` guard carried, range guard not carried (03, 06), on OTP 25.
- A redundant guard is free.
- The private-function tag test costs about 17-30% in a record-update loop (05).

**Must be softened:**
1. **"gap does not reproduce on OTP 25":** keep it, with two qualifiers. First, cite interleaved numbers, not 01's: 01's spreads are noise of 20-30%, and the "~5% noise" in Limits is wrong for that harness. Second, say it holds for OTP 25.3 on a machine about 3x slower than the ticket's (18 ms vs 5-6 ms), where the workload mix may differ.
2. **"ticket 04 thesis refuted at emission level" (and Option C's version):** overreach. What is shown is that the optimizer sees only forms, declarations never reach it, and on OTP 25 there is no gap to explain. The ticket's thesis is that the checker's declared `int` discards a narrower range and so caps the ceiling. The brief never tests the checker and admits it did not run it. At best: "not needed to explain any difference on OTP 25". Do not instruct the ticket to be corrected.
3. **02 "inconclusive":** restate as "3-7% min slowdown, consistent over 3 reruns, under 10%, nowhere near 20%". The earlier +12.5% run was noise.
4. **04:** change "+11-13%" to "+5-13% at min, about 0-2% at median".
5. **07:** say Sign and Size are 0 = 0 and uninformative.
6. **Probe index:** 08 is not standalone, and all scripts hard-code the author's scratchpad paths.
7. **03 "792 B":** quote only the +20 B and +4 B deltas, since absolute beam size depends on the build path.
8. The recommendation (Option A, re-run 07 and 01 on OTP 28.5) is sound, and `ilv.erl` is a better template for it than `bench4`. Option B's evidence should use the softened 04 numbers.
