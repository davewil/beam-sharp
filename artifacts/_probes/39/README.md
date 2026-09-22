# Probes for ticket 39 — rerun commands

All measured 2026-09-22 on: **OTP 28.5 (erts-16.4)**, built from source at `/opt/otp28-src`
(apt's OTP 25 was used only for `elixir`/`elixirc`, which is built against OTP 24/25 and cannot
boot its own `Logger`/`Kernel` support modules under OTP 28's loader — Elixir results were
produced by compiling with apt's `elixirc` and then loading the resulting `.beam` under the OTP 28
runtime, which is fine since Erlang's BEAM format is forward-compatible in that direction).
**Hardware: Intel Xeon @ 2.80GHz, 4 vCPU, KVM-virtualized, x86_64** — NOT the Apple Silicon /
ARM64 the ticket's original numbers were taken on. Absolute times here are ~4-5x the ticket's
(container overhead, virtualization, or CPU generation — not investigated), but every comparison
below is a same-VM, same-run ratio, which is what the ticket's 20% figure is.

`bsc` built from `/home/user/beam-sharp/compiler` at commit `35dccac` (current `master` tip) via
`cd compiler && PATH=/opt/otp28-src/bin:$PATH rebar3 escriptize` (the apt `rebar3` 3.19.0 crashes
under OTP 28 with `rebar_uri:parse` `undef`; `/usr/local/bin/rebar3` 3.27.0, matching
`.tool-versions`, works).

## 0. Baseline — the whole-fold AoC benchmark, re-run unmodified

Source: `/home/user/beam-sharp/aoc/bench/` (Day01, bench.erl, bench_ex.ex, gleam/), copied
verbatim to a scratch dir and built (Elixir compiled under apt/OTP25, Gleam's `gleam.toml`
dependency on `gleam_stdlib` removed since `bench_gleam.gleam` imports nothing from it and hex.pm
is unreachable through the agent proxy — everything else byte-identical to the tracked files).

```
cd <scratch>/aocbench
erlc -o <out> bench_erl.erl
elixirc -o <out> bench_ex.ex                      # apt OTP 25 elixirc
(cd gleam && gleam build)                          # gleam.toml deps stripped, see above
cp gleam/build/dev/erlang/bench_gleam/ebin/bench_gleam.beam <out>/
/home/user/beam-sharp/compiler/_build/default/bin/bsc -o <out> Day01
erlc -o <out> bench.erl
PATH=/opt/otp28-src/bin:$PATH erl -noshell -pa <out> -s bench main /home/user/beam-sharp/aoc/2025/Day01/input.txt
```

Output: `baseline_wholefold_run1.txt`, `baseline_wholefold_runs2-4.txt` (4 runs total).

## 1. Isolated Spin-loop timing

`spin_isolated.erl`, `spin_isolated.ex`, `spin_isolated_gleam.gleam`, `Day01Isolated_spin_isolated.bs`
each define `Wrap`/`Hit`/`Spin` (private) and a public `Run(left) -> Spin(50, 1, left, 0)`, called
ONCE with `left = 673364` instead of through the whole `Clicks`/`Sign`/`Size`/list-fold — matching
ticket 39 §3 item 1.

**A first version of this harness exported all four Erlang/Elixir/Gleam functions** (matching
nothing in particular) while beam-sharp's stayed `private` by the language's default — see
`isolated_full_disasm_FLAWED_export_mismatch.txt`. That asymmetry alone let Erlang's compiler
prove less about the always-literal `Step` argument than it could prove about beam-sharp's, and
produced a spurious ~20% gap **in beam-sharp's favour**. Corrected by exporting only `run/1` in
every language (`isolated_full_disasm_corrected.txt`), after which all four disassemble
instruction-for-instruction identically, including `{tr, Reg, Type}`.

```
BSC=/home/user/beam-sharp/compiler/_build/default/bin/bsc
PATH=/opt/otp28-src/bin:$PATH "$BSC" -o <out> Day01Isolated/        # Day01Isolated_spin_isolated.bs inside
PATH=/opt/otp28-src/bin:$PATH erlc -o <out> spin_isolated.erl
elixirc -o <out> spin_isolated.ex                                   # apt OTP 25
(cd gleam_isolated && gleam build); cp build/.../spin_isolated_gleam.beam <out>/
PATH=/opt/otp28-src/bin:$PATH erlc -o <out> isolated_bench.erl
PATH=/opt/otp28-src/bin:$PATH erl -noshell -pa <out> -s isolated_bench main
```

Disassembly: `escript disasm.escript <beam> <FunctionName>` (dumps every clause's abstract-format
instruction list via `beam_disasm:file/1`).

Output: `isolated_full_disasm_corrected.txt`, `isolated_spin_timing_otp28_corrected.txt` (3 runs),
`spin_disasm_otp28.txt` (Spin/4 only, from the ORIGINAL non-isolated Day01/bench_erl beams, for a
second confirmation independent of the isolated harness).

## 2. Causal test — does losing `{tr,...}` cost what the ticket measured?

`spin_isolated_normal.erl` / `spin_isolated_no_type_opt.erl` are the SAME source
(`spin_isolated.erl` above, renamed) compiled two ways from one VM session:

```
PATH=/opt/otp28-src/bin:$PATH erl -noshell -eval '
{ok, spin_isolated_normal} = compile:file("spin_isolated_normal.erl", [{outdir, "ebin_causal"}]),
{ok, spin_isolated_no_type_opt} = compile:file("spin_isolated_no_type_opt.erl",
                                                [{outdir, "ebin_causal"}, no_type_opt]),
ok.' -s init stop
PATH=/opt/otp28-src/bin:$PATH erlc -o ebin_causal causal_bench.erl
PATH=/opt/otp28-src/bin:$PATH erl -noshell -pa ebin_causal -s causal_bench main
```

`no_type_opt` is a real (if undocumented in `erlc -h`) option: `compile.erl` in
`compiler-8.2.6.3` (OTP 28.5's bundled `compiler` app, installed at
`/usr/lib/erlang/lib/compiler-8.2.6.3/src/compile.erl`), `expand_opt/2` around line 282, expands
it to `[no_type_opt, no_ssa_opt_type_start, no_ssa_opt_type_continue, no_ssa_opt_type_finish |
Os]` — it exists so OTP's own test suite can recompile a module with the `beam_ssa_type` pass
(and everything downstream of it) turned off, kept specifically "so that it will be recorded in
the BEAM file, allowing the test suites to recompile the file with this option" (compile.erl's own
comment).

Output: `no_type_opt_disasm.txt` (confirms `{tr,...}` count goes from 2 occurrences in `spin/4` to
0, and the interprocedural constant-fold of `Step` also reverts — `no_type_opt` disables more than
just the annotations, see the brief), `no_type_opt_causal_timing.txt` (3 runs).

## 3. Structural question — answered by reading, not running

No probe script; the brief cites `compiler/src/bs_emit.erl` (this repo) and
`/usr/lib/erlang/lib/compiler-8.2.6.3/src/compile.erl` / `beam_ssa_type.erl` /
`beam_call_types.erl` directly, by file and line.
