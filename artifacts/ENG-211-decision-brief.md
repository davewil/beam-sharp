# Decision brief — ticket 39 (ENG-211): why is instruction-identical code 20% slower, and what is the ceiling?

Status of the ticket: **left open.** Nothing here resolves, claims or comments on it.
Probes: `artifacts/probes/ENG-211/` (`./run-all.sh` re-runs all of them and rewrites every `*.out`).

## Read this first: what could and could not be run

| | |
|---|---|
| Host | Intel Xeon 2.8 GHz, 4 cores, **OTP 25 (BeamAsm JIT)**, Elixir 1.14.0, Elm 0.19.1 (`env.out`). The ticket's numbers are OTP 28 / Apple Silicon. This host's absolute times are ~3x larger (17.5 ms against ~5.5 ms for the same loop) and are **not comparable**; only ratios within this host are used. |
| `bsc` | **Not built, not run.** The repo pins OTP 28.5 (`.tool-versions`); the lexer needs a newer leex than OTP 25's, and `bs_run.erl:351` uses `~kp`. I did not patch the compiler to force it. Every statement about what `bsc` emits is read from `compiler/src/*.erl` and marked **[cited, not re-executed]**. |
| Gleam | Not installed, no source read. **Not surveyed.** (A prebuilt-binary download was refused by the sandbox; I did not work around it.) |
| Elm | Installed, but it targets JavaScript, not BEAM; there is no emitted-BEAM comparison to make. Not surveyed beyond that. |
| Input | The real AoC input is not in the repo. `bench39.erl` generates 4732 rotations / 671,458 clicks from a fixed LCG. Answers are checked equal across variants, not against 6770. |

**The central limit:** I could reproduce the *mechanism* the ticket points at (lost operand types) in hand-written Erlang. I could not look at `bsc`'s actual output for `Spin`, so I cannot say whether `bsc`'s Day01 has lost them.

## Sub-decisions the ticket implies

1. **Is the premise still true?** The ticket (2026-08-15) measured `bsc` before F42 added a return guard around foreign calls (F42, done 2026-09-11 per `compiler/features/F42-foreign-return-guard.md:3`). Does a current `bsc` still emit instruction-identical `Spin`?
2. **Cause: do missing operand types (`{tr,…}`) explain the gap, or merely accompany it?** (§3.2)
3. **Can the emitter carry ranges into the optimiser, and does the optimiser trust them?** (§3.3)
4. **The ceiling:** should the emitter spend code to try to beat Erlang's inference, or stop at parity?

## Measurements (all on this host, OTP 25; `timings.out`, three independent runs of 31 interleaved fresh-process rounds)

Hot loop = the repo's `Spin`/`Wrap`/`Hit`, hand-written in Erlang variants. Min of 3 runs; noise (spread of the three medians) ≤ 0.4 ms.

| variant (`src/`) | what it is | `{tr,…}` operands in `spin/4` (`tr_annotations.out`) | min ms | vs baseline |
|---|---|---|---|---|
| `v_a_ops` | the repo's `bench_erl.erl` shape | 2 | 17.46 | 1.00 |
| `v_b_remote` | `erlang:'rem'(…)` remote calls, as `bs_emit.erl:1138` writes an FFI call | 2 | 17.55 | 1.01 |
| `v_c_retguard` | remote call + F42 `case … of V when is_integer(V)` (`bs_emit.erl:1259-1266`) | 2 | 17.64 | 1.01 |
| `v_d_spec` | every function `-spec`'d `integer()` (`bs_emit.erl:1448-1459`) | 2 | 17.49 | 1.00 |
| `v_g_exported` | **all functions exported** — the "annotations stripped" experiment | **1** | 17.23 | **0.99** |
| `v_h_spin_exported` | only `spin/4` exported | 1 | 16.97 | 0.97 |
| `v_k_spec_exported` | `spin/4` exported **with narrow `-spec spin(0..99,-1..1,…)`** | 1 | 16.95 | 0.97 |
| `v_j_guarded_exported` | `spin/4` exported, ranges as **guards** (`Pos >= 0, Pos =< 99, …`) | **7** | 18.17 | **1.04** |
| `v_m_guarded_private` | private + redundant range guards | 2 | 17.66 | 1.01 |
| `v_s_extra_guard` | control: one extra `Left > 0` guard (the README's own first mistake) | 2 | 18.86 | 1.08 |

Other measurements:

- **The harness resolves ~1%.** The control `v_s_extra_guard` (one extra comparison per click) reads +8% in all three runs, so a real 20% would be unmistakable.
- **The `bsc` build route is not the cause** (`abstr_route.out`): the same module sent through `.abstr` → `compile:file(from_abstr, debug_info)`, with function and attribute annotations set to 0 as `bs_emit.erl:20` does, keeps `tr=2` in all four modes.
- **Elixir 1.14** (`elixir_tr.out`): `defp` version of the benchmark keeps `tr=2`, same as Erlang.
- `.beam` sizes 1244–1364 bytes (`beam_sizes.out`); compile time of the Erlang side 0.25 s/module for both baseline and return-guard variants (`compile_time.out`), no difference.
- The ticket says Erlang infers `{t_integer,{0,99}}`; on OTP 25 it infers `{-99,99}` for the same code (`tr_annotations.out`). So the ticket's example does not transfer between OTP versions.

## Neighbour survey

| source | file:line | what it shows |
|---|---|---|
| Erlang compiler 8.2.6.3 | `beam_ssa_type.erl:119-122` | exported functions' argument types start at `any`; local ones are propagated from call sites |
| | `beam_ssa_type.erl:432-441` | `exported=false` -> uses joined `arg_types`; `exported=true` -> "can't infer the parameter types of exported functions" |
| | `beam_ssa_type.erl:683` | callee arg types updated only for `exported=false` callees |
| | `beam_asm.erl:197-200` | types travel to the JIT in a `Type` chunk |
| Elixir 1.14 | `elixir_tr.out` (measured; `elixir_erl` source is not installed) | `defp` keeps both annotations — private-ness is what matters, not the front end |
| `bsc` **[cited, not re-executed]** | `bs_emit.erl:32-35`, `:140` | private functions are unexported; `-spec` on every function |
| | `bs_emit.erl:324-360` | `is_integer` + range guards emitted for **exported** refined-int params only |
| | `bs_emit.erl:1138-1148`, `:1259-1266` | foreign calls become remote calls wrapped in a return-guard `case` unless the declared type is `term` |
| | `bsc.erl:843` | `compile:file(.abstr, [from_abstr, debug_info, …])` |
| Gleam, Elm | — | not surveyed (see above) |

## Decision 1 — settle the cause, once

**Option 1a: run the §3.2 experiment on OTP 28.** `./run-all.sh` on an OTP 28 host, unchanged. Reading rule stated before running: if `v_g_exported` is not at least ~10% slower than `v_a_ops`, lost operand types do not explain a 20% gap and the emitter is innocent of it.
- Evidence here: on OTP 25 `v_g_exported` loses the `{tr,…}` operands (2 -> 1) and runs **1% faster**, `v_k` 3% faster (`timings.out`). So on this VM, types are correlation, not cause.
- Strongest counterargument: OTP 28's JIT may consume type info far more aggressively than OTP 25's. I have no evidence either way; this result may simply not transfer.

**Option 1b: diff `bsc`'s real output for Day01 against `bench_erl`.** On a host with OTP 28: `bsc -o out aoc/bench/Day01`, then `erlc +from_abstr -S out/Day01.abstr` and `erlc -S aoc/bench/bench_erl.erl`; compare `var_info` / `{tr,` in `Spin`, and look for any remote-call/`case` shape the Erlang lacks.
- Evidence here: none for `bsc` itself. Every candidate I could mimic (remote call, F42 return guard, `integer()` specs, line-0 annotations, `from_abstr`+`debug_info`) leaves `tr=2` and times within 1% (table above).
- Strongest counterargument: it cannot say *why* if the output differs, only *that* it does; and my mimicry is hand-written from source reading, so a hidden difference in the real forms would not show up in it.

## Decision 2 — can the emitter carry ranges?

Under each answer the same B# program, `Spin` with private `Wrap`, emits differently:

**Option 2a: no emitter change (status quo).** Emits `v_a_ops`: private functions, `-spec integer()`, no guards. Compiler delta: none.
- Evidence: private functions already receive propagated argument types (`tr=2`); `-spec`s are inert for the optimiser (`v_k_spec_exported`: narrow spec, `tr=1`, same as no spec).
- Strongest counterargument: it forfeits the ticket's "ceiling above Erlang" idea entirely, and an exported function never gets argument types (`beam_ssa_type.erl:438-441`).

**Option 2b: emit refinement ranges as entry guards on exported functions.** Extends `int_guard/6` (`bs_emit.erl:324-360`, already doing this for declared refinements) to a function whose checker-proved parameter range is narrower than its declaration. Emits `v_j`.
- Evidence: the optimiser does trust guards: `tr` goes 1 -> 7 in `spin/4` (`tr_annotations.out`).
- Strongest counterargument: on OTP 25 it is **4% slower** (18.17 vs 17.46 ms, stable across 3 runs) because the tests run on every call and the extra annotations bought nothing measurable. Whether OTP 28 reverses that is unknown.

**Option 2c: ranges only via a new "assert" form (e.g. a `case` the optimiser can fold).** Compiler delta: a new emitted pattern in `bs_emit` plus a checker note per call site. **Not probed** — I have no evidence for it, and 2b already answers "does the optimiser use AF-carried ranges" (yes, for guards; no, for specs).

## Recommendation

1. **Do 1b first** (an hour on an OTP 28 host; no design needed): it says whether `bsc`'s `Spin` actually differs from Erlang's. If it does not differ, the 20% is not an emission problem and the ticket should be reframed. Then **1a** to see whether types matter at all on the pinned OTP.
2. **Take 2a (no change) until 1a shows a type-sensitive gap of ≥10% on OTP 28.** Measured here: the only mechanism that makes the optimiser use a range (guards) costs 4% on OTP 25, and specs do nothing.
3. Fix the ticket's premise when it is resolved: it predates F42 (the `bs_emit.erl:1259` return guard) and its `{0,99}` is an OTP 28 observation not reproducible on 25.

## Evidence limits

- Nothing about `bsc`'s actual emitted `Spin` was observed (OTP 28 needed).
- The result "types don't matter" is for OTP 25 on x86; the ticket's observation is OTP 28 on Apple Silicon (a different JIT backend).
- Synthetic input; ratios only.
- Records and dispatch (the ticket's open axis in §3.4) were not touched.
- Gleam not surveyed; Elm has no BEAM emission to survey.

## Probes (re-run with `artifacts/probes/ENG-211/run-all.sh`)

| file | output | claim it backs |
|---|---|---|
| `src/v_*.erl`, `bench39.erl` | `timings.out` | the timing table and the 1% resolution |
| `run-all.sh` step 1 | `tr_annotations.out` | which variants keep `{tr,…}`; guards carry ranges; specs do not |
| `mk_abstr.escript` | `abstr_route.out` | the `from_abstr`/`debug_info`/line-0 route is not the cause |
| `elixir_tr.exs` | `elixir_tr.out` | Elixir behaves like Erlang |
| — | `beam_sizes.out`, `compile_time.out`, `env.out` | sizes, compile time, host |

Circularity check: no probe was tuned after seeing a result. The `v_g/h/k` outcome (faster, not slower) was unexpected given the ticket's hypothesis and is reported as measured.
