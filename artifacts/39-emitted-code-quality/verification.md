# Verification of ticket 39 brief (independent)

Verifier re-ran all 19 probes from copies in `verify/probes/` (env.sh edited so W is a fresh temp dir, `/tmp/v39.xw9V`; A points at `verify/`). Same box (4 vCPU, OTP 28.0/erts 16.0, bsc as built, Gleam 1.12.0, Elixir 1.14.0). Load average was 15-23 during runs. Re-run outputs: `verify/probes/*.out`; extra tests: `verify/discr/`.

## 1. Re-run status
All 19 scripts ran, exit 0. Verdicts unchanged in every case.

| probe | status | notes |
|---|---|---|
| 00, 01 | REPRODUCED | |
| 02 | REPRODUCED | bsc/Erlang min = 0.992 / 0.992 / 0.994 (author 0.992-0.994 equivalent). Gleam 10.74-10.77 vs 16.76 = 0.64. Elixir 16.60-16.63 |
| 03, 04 | REPRODUCED (byte-identical .out) | tr: Erlang 8, bsc 7, Gleam 7, Elixir 8 |
| 05 | REPRODUCED | one-rotation 16.51 vs full fold 16.68 |
| 06 | REPRODUCED | bsc no_type_opt 17.21-17.23 vs default 16.64-16.67 = +3.2% to +3.5% (author +3.2%) |
| 07 | REPRODUCED | bsc+inline 10.59-10.84 (author 10.42-10.75). 0.63-0.65 of default. The author's lone 10.42 min did not recur; ratio claim holds |
| 08, 09 | REPRODUCED | 09: plain 49.7-49.8, is_integer 49.8-50.1, range 47.5-47.6 ms (-4.4% / -5%); much quieter than the author's run |
| 10 | REPRODUCED | |
| 11 | REPRODUCED with a caveat | see 2 (11a runs no command) |
| 12 | REPRODUCED | corpus bytes 26,636 -> 26,892 = +0.96% (author 27,400 -> 27,656 = +0.93%; absolute bytes differ, probably paths in debug_info). Compile time: plain 8.5-9.95 s vs inline 9.5-9.9 s, inconclusive, as stated |
| 13 | REPRODUCED | only the file path string in frames differs |
| 14 | REPRODUCED, author's .out is STALE | my run has 10 more lines (gleam spin 91 vs erl 84 JIT lines, JIT comments). Author's .out stops after the two diff counts, so the brief's quoted JIT comments (`add without overflow check`) are not in the shipped .out for 14 |
| 15 | REPRODUCED | is_integer erl=0 bsc=2 default-bsc=0. Slowdown vs b_default 3.0-4.1% |
| 16 | REPRODUCED, author's .out is STALE/EDITED | the Elixir line in the shipped .out reads "user -spec forms for part_two/wrap/spin: 1 (only __info__ and part_two-adjacent...)", text that is not in the shipped .sh (the .sh prints "spec forms in Elixir output: 1 (that one is __info__/1...)") |
| 17, 18 | REPRODUCED | |

## 2. Claim audit
Supported and checked by me: 0.99x; Gleam 0.64x; 26 instrs each; Wrap/Spin identical x86 JIT asm (4 diff lines, names; 0 for Wrap); spec strip no effect; `{tr,..,{0,99}}` on Next, Wrap-guard result and JIT `add without overflow check` + `is_int_in_range`; Gleam header has `inline` (line 2); Gleam spin = 25 instrs with no allocate vs 26 with `allocate,4,4` when inline is removed; inline lowers bsc to 0.63-0.65; `-inlined-f/1-` frame and dropped `trace13:boom` frame; function_clause not converted to case_clause on 28.0; 29 `function_clause` lines in compiler/test; Dial02 refusal text; Dial01 `Wrap` refusal (I ran it by hand and it gives the quoted error).
Source citations, all opened in /tmp/tc/otp_src_28.0 (and compiler-9.0/src, identical for beam_core_to_ssa): beam_core_to_ssa.erl:196 OK; beam_ssa_type.erl:425-440 OK (brief says 424-440); beam_jit_common.hpp:267-279 OK; instr_arith.cpp comment is at line 192 (brief says 191, off by one); compile.erl:77-90 and 112-115 OK (the "24" line is 113).

Unsupported or mismatching:
- **11a is not run.** `11_does_bsharp_know_the_range.sh` prints the heading for (a) with no command, so `11_..out` has no Wrap refusal. The text the brief quotes for 11a ("int <= -1 | int >= 100") is the Dial02 `Succ` output under (b). The claim itself is true (I ran Dial01 by hand: refused, same message) but the cited probe does not demonstrate it.
- **"spec reaches Core (6 matches in lib08.core)"** is `grep -c spec`, which also counts the function name `wrap_spec`. The actual attribute is there (core lines 10-12), so the conclusion holds, but the count is not evidence. Probe 08 also prints a hard-coded "(>0 : the spec IS in Core ...)" line regardless of the count.
- **"+3.5 to 4.4% for stripped bsc"** mixes baselines. Column `min/best` is relative to whichever variant was fastest. Against b_default I get 3.0-4.4% across six runs (author's data: 3.1, 4.2, 4.4); against Erlang `no_type_opt` it is 2.7-3.4%. The range is right-ish, the lower bound is 3.0 not 3.5.
- **Causal claim "because the 2 FFI is_integer guards survive"** is correlational: nobody removed those guards from the no_type_opt bsc build and re-timed. Instruction counts (12 vs 8) support it, timing does not.
- Brief says "22-module examples corpus" but probe 12 says "modules built by bsc: 21" and then 22 `.abstr` files; unexplained one-off.
- "Gleam `spin` has 1 call": not checked in the shipped probes (25 instrs / 0 allocate is checked).
- "Ratios of mins agreed to within 0.5% across every re-run": true for 02, 07, 10, 12 (my spreads: bsc/Erlang 0.992-0.994; e_same vs Erlang null control within 0.3%), but 06's e_default shows 1.005 vs 1.024 across the two of my runs. Fine for conclusions, not strictly every re-run.
- Brief says the load was 11-16 and mins are the column to trust. My medians were much closer to the mins (17.0 vs 16.7), so the author's medians (20-36 ms) were load artefacts as stated.

## 3. Circularity audit
- **Can the harness see a slowdown? Yes.** `verify/discr/`: 3 runs x 150-200 rounds of `bench2`. Null control (`e_same` = copy of bench_erl under another module name) vs `bench_erl`: 0.0-0.5% apart. Injected `Zeros + hit(Next) + (Step rem 7) - (Step rem 7)` (answer unchanged, 6770): +5.2% / +5.7% at min (17.70, 17.79 vs 16.82, 16.90). The same harness shows bsc 0.992 of Erlang, so a ~3% or larger bsc gap would have been seen. (Interesting side result: adding `+ (Left bsr 40)` to the accumulator speeds the Erlang loop up by about 20% (13.3 vs 16.8 ms), so this loop is very sensitive to what type facts reach the JIT. That is consistent with the ticket's 20% being a type-propagation difference on another architecture, which the brief rightly leaves open.)
- **Same compiler?** `beam_lib` compile_info: bench_erl, Day01, bench_gleam, Elixir(re28) all compiler version 9.0 (OTP 28.0). Options: bench_erl [] , Day01 [debug_info, from_abstr], gleam [debug_info]. bsc compiles via `compile:file(.., [from_abstr, debug_info, ...])` (bsc.erl:843). debug_info does not change code; the instruction lists and x86 asm of Wrap/Spin are identical, so the flag difference is moot.
- **Was anything patched so bsc/Gleam look as the conclusion needs?** Gleam's `inline` is Gleam's own output (header line 2, in the generated .erl copied from the build). I removed ` inline` from it, renamed the module, recompiled (`verify/discr/gleam_noinline.out`): g_noinl 16.84-16.86 ms = Erlang (16.8-16.9) = bsc default; g_inl (with inline) 10.77-10.80 = original Gleam. Spin goes 26 instrs with `allocate,4,4` -> 25 instrs without. So the speedup is the inline attribute, nothing else. The brief does not say bsc matches Gleam by default; it says adding inline to bsc's .abstr does (07/12, reproduced).
- **bsc's benchmark source is curated.** `aoc/bench/Day01` carries a comment "written to match the other three EXACTLY"; there is no guard in `Spin`'s recursive clause. The shipped bsc source was last modified in a commit of 2026-09-29, after the ticket (2026-08-15). A bsc that emitted a guard-heavy Spin back then (the comment reads like a fix) would explain a 20% gap that no longer exists. The brief says the 08-15 compiler cannot be rebuilt; it should also say the source may have been changed. Not a flaw in the measurement of what is in the tree.
- **Probes that cannot fail / hand-written output**: none of the 19 probes asserts anything or exits non-zero on contradiction; every verdict is read off the printed table by a human. 11a runs no command. 08 prints a hard-coded sentence about Core. 04 echoes "IDENTICAL-ignoring-order?no" (meaningless text on success). 14 and 16 shipped `.out` files do not match what their `.sh` prints (stale or hand-edited), see section 1. I found no probe that greps its own output to manufacture a pass, and no .out that disagrees in substance with a re-run.

## 4. Elixir caveat
Probe 01 extracts the Erlang forms from Elixir 1.14's debug_info chunk (`elixir_erl` `debug_info(erlang_v1,...)`, which reconstructs forms from stored definitions) on OTP 25 and compiles them with the OTP 28 compiler. It shows: what shape of Erlang (13 forms, `compile no_auto_import`, no inline, no spec on defp) Elixir 1.14 hands to erlc, and that this shape runs at Erlang's speed (16.60 vs 16.77 ms) with 8 tr operands on OTP 28. It does not show: what Elixir 1.19.5 emits (newer versions may change forms or compile options), that the debug_info reconstruction equals the forms passed to `compile:forms` at build time (options such as inlining or line info could differ), or Elixir's real behaviour on OTP 28 (1.14 cannot load there). It is a fair stand-in for "Elixir does not add inline and equals Erlang", a weak one for any Elixir-vs-bsc number; the brief's wording ("measures Elixir's generated code on OTP 28, not Elixir 1.19.5") is accurate. The headline does not depend on it (bsc vs Erlang and Gleam inline are the load-bearing comparisons).

## Verdict
PASS: headline (no gap on x86/OTP 28.0), Gleam-0.64 and its inline cause, identical instructions/tr/JIT asm, spec-not-a-channel, guard-to-JIT range path, inline +0.9% bytes, stack-trace costs, Elixir caveat wording, Option A/B/C descriptions, source line citations (one off-by-one).
FLAG (minor, fix wording or probes): 11a cites a probe that runs no command; "6 matches in lib08.core" is a weak check; "+3.5-4.4%" baseline mixing (3.0-4.4%); no-type-opt cause untested by removal; 14 and 16 shipped .out stale/edited; "22-module" vs 21 built; no assertions anywhere; add that aoc/bench/Day01 source may have been tuned after the ticket.
Overall: **safe to rely on? yes, with caveats** (the 20% non-reproduction is not a harness artefact; it is x86-64/OTP 28.0 only and the ticket's arm64 number stays unreproduced, as the brief itself says).
