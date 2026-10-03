# Independent verification of ticket 39 brief

Method: probes copied to a scratch tree (`scratchpad/v/`, with `aoc` and `compiler` symlinked so `common.sh` resolves).
Every `run.sh` was re-run from scratch (01 through 08, plus `04-variants/types.sh`) and diffed against the captured `.out`.
The machine was noisier than during capture (IQRs 3-7 ms against 0.3-1 ms captured). Judged on min, ratios and ordering.

## Reproduction of probes

| Probe | Result |
|---|---|
| 01 rerun | REPRODUCED. Repo harness: Erlang/Elixir/beam-sharp all min 16.6-16.9 ms. Rotated harness medians: beam-sharp 0.97, 0.99, 1.07x (noise run), Gleam 0.61-0.63x. Gleam min is 10.8 ms every run. |
| 02 asm | REPRODUCED. Only diffs are absolute source paths. Counts tr=2/2/6/2 (Spin only). Elixir `Spin` is identical to Erlang's apart from line numbers (I diffed it myself). |
| 03 equivalence | REPRODUCED byte for byte. wrap, hit, spin, clicks and pt are identical; the `Type` chunk hex is identical. Code is 404 vs 406 bytes (the brief says only "Type chunk"). sign/size differ by source clause order, as stated. |
| 04 variants | REPRODUCED. Sizes, tr and instr counts match exactly (Gleam beam size differs by 52 B, immaterial). Timings: b0, b1 and b4 are 0.97-1.11x of e0 (the 1.11 was one noisy invocation). b2 is 1.02-1.10x and e1 1.00-1.03x. b3 is 0.64-0.68x, e2 0.62-0.66x, g0 0.61-0.66x, g1 1.00-1.02x. b5 is 1.02-1.09x (always at or above b0 in min: 17.6 vs 16.7). Variants are real: sizes and asm differ, and the `no_type_opt` asm has 0 tr. |
| 05 from-asm | Mechanically reproduced, but see CIRCULAR below. |
| 06 bs-range | REPRODUCED exactly, including the rejection text and the `Twice` `{0,99}` against `Plain` `any`. |
| 07 inline | REPRODUCED. Wrap-only 0.69-0.73x, Hit-only 0.56-0.65x, both 0.59-0.64x, blanket 0.61-0.66x, size100 0.56-0.60x, none 0.96-1.02x. Compile options and crash shapes are identical. |
| 08 corpus | Sizes REPRODUCED exactly: 22196 -> 22100 (-0.4%); 5 modules changed (Pipeline -13.5%, Stats +9.1%, Names +6.6%, Aliasing -3.9%, Foreign -3.0%); 17 unchanged. Compile times are noise (566 vs 750 ms here, 576 vs 637 captured); the brief says so. |

## Equivalence of sources (circularity hunt)

`bench_erl.erl` and `bench_bs.bs` compute the same thing with the same loop shape (same `Wrap`, `Hit`, `Spin`, `Clicks`).
The only source difference is `Sign` (a third `0` clause in Erlang) and `Size` (clause order). The brief discloses both.
The timing harness times only `PartTwo` (`timer:tc`) after a 20x warm-up, with rotated order and the answer 6770 asserted on every call, so startup is excluded.
Variant edits (`NoSpec`, `narrow`, `guard_fact`, `inline`, `no_type_opt`) visibly changed the artifacts.

## CIRCULAR finding: probe 05 `a1_true_fact` and `a2_LIE_step`

1. The `var_info` edits **do not change anything the JIT reads**. The `Type` chunk of a0, a1 and a2 is byte-identical.
   Editing the `{tr,..}` operand instead (line 71 of the listing) does change the `Type` chunk. I confirmed this with `c1_tr` and `c2_trlie`, which were built and loaded, and both return 6770.
   So "a1 true fact 1.00x" and "a2 lie same answer" were guaranteed by construction. They say nothing about whether injected facts speed up or break the loop.
   The brief's channel-table row "`from_asm` `{var_info}`/`{tr}`: Yes (carries a range into beam_ssa_type)" is UNSUPPORTED as written.
   - `from_asm` bypasses `beam_ssa_type`.
   - `var_info` only reaches `beam_validator`, which does `meet` it unproven (`beam_validator.erl:1190-1195`, verified).
   - A real claim about the JIT needs the `{tr}` edit; the `{tr}` lie was accepted by erlc.
   - My `{tr}` timing was too noisy to say anything.
2. Fixture defect: the sed loop (`n`) skips the module rename, so a1 and a2 keep `b0_bs_as_is` in the `func_info` atoms of Spin onward. It is harmless to the answer but sloppy.

## Claim verdicts

| Brief claim | Verdict |
|---|---|
| Headline table row 1 (0.99x, no gap) | REPRODUCED (ratios 0.97-0.99 on quiet runs; one noisy run 1.07x within IQR) |
| Row 2 (`Spin` identical, `Type` chunk identical) | REPRODUCED |
| Row 3 (spec stripped or narrowed gives same asm and speed) | REPRODUCED |
| Row 4 (no interval arithmetic, `Digit Wrap` rejected) | REPRODUCED. The citation `bs_check.erl:4138-4140` is real (`'%'` at 4140, `'+'` at 4135) |
| Row 5 (the optimiser does not read a spec) | REPRODUCED (b1 and b4 have 70 instructions and 9 tr, same as b0). The cited `beam_ssa_type.erl:444-451` is real |
| Row 6 (`no_type_opt` 1.00x for Erlang, 1.02-1.04x for beam-sharp) | REPRODUCED in direction. Mine 1.02-1.10x for b2 and 1.00-1.03x for e1 under noise |
| Inlining is the lever (Gleam 0.64x, minus `inline` 1.00x, Erlang plus inline 0.64x, bs plus inline 0.64x) | REPRODUCED. `bench_gleam.erl:2` has `inline`, verified |
| Guard channel `{0,99}`, b5 1.05x slower | REPRODUCED (min 17.6 vs 16.7 ms every run) |
| Exported refined parameter channel | REPRODUCED |
| Inline channel and `beam_bounds.erl:316-322` | REPRODUCED, citation real |
| `from_asm` channel "Yes" and "a1 1.00x" | UNSUPPORTED and CIRCULAR (above). "A lie accepted" is true for `var_info` only |
| Elixir and neighbours, `module_info` options | REPRODUCED |
| `compile.erl` quotes | REAL, but the cited lines are off by 1-3. The "never default" text is at about 88-89 and `compile.erl:78-79` says `function_clause` becomes `case_clause`. The brief discloses its probe kept `function_clause` |
| `compile.erl:1185-1191`, `beam_ssa_type.erl:2729-2733` | REAL |
| Option B sizes and crash shape | REPRODUCED. `bs_emit.erl:~74` is the export attribute site, verified |
| "Gleam only 3% ahead in the ticket, unexplained" | The ticket does say Gleam 1.00x against Erlang 1.03x. The brief's UNMEASURED label is honest |
| Option C "no runtime payoff" | UNSUPPORTED by probe 05 (vacuous); only the guard cost (b5) and the inline results back the neighbouring claims. It is labelled UNMEASURED in the brief, so partly covered |

## Overall

The brief's central conclusions (no gap, `{tr}` claim false, spec irrelevant, no interval synthesis, inlining as the lever) are REPRODUCED with no manufactured results found in probes 01-04 and 06-08.
One probe is circular: 05 (`from_asm`). Its "Yes" row and its "no gain" evidence should be weakened to "`var_info` is validated only and never reaches the loader; the `{tr}` channel is untested for speed".
This does not affect the recommendation (Option B), which rests on probes 04 and 07.
