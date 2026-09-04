# Probes for ticket 39

All run on this sandbox's only available toolchain: **Erlang/OTP 25 (erts
13.2.2.5), compiler-8.2.6.3, JIT enabled, x86_64-pc-linux-gnu, 4-vCPU Xeon
VM** — NOT the ticket's original OTP 28/erts-16.4/Apple Silicon. Elixir
1.14.0, Gleam 1.9.1 (`gleam --version`).

Network note: `repo.hex.pm` is not reachable from this sandbox, so the real
`aoc/bench/gleam` (which declares an unused `gleam_stdlib` dependency) cannot
`gleam build` here. `gleam-scratch/` and `gleam-spin/` are copies of the
benchmark's Gleam source with the dependency line removed (the source never
actually imports `gleam_stdlib`), built locally with no network access.
`aoc/bench/` itself is untouched.

| File | Purpose |
|---|---|
| `build.sh` | Same as `aoc/bench/build.sh`, pointed at `gleam-scratch/` instead of `aoc/bench/gleam/`. Builds all four Day 1 implementations into `/tmp/beam-sharp-bench-39/day01`. |
| `bench_more.erl` | `aoc/bench/bench.erl` with 200 runs instead of 25 and p10/p25/median reported, for lower-variance reproduction of the ticket's headline number. |
| `probe_erl_spin.erl`, `probe_ex_spin.ex`, `gleam-spin/`, `ProbeBsSpin/` | Verbatim copies of each language's `wrap`/`hit`/`spin` (no list traversal, no `Clicks` fold), each with a new `spin_only/2` entry point, to isolate the loop itself (sub-decision 1). |
| `bench_spin.erl` | Times the four `spin_only/2` probes above directly. |
| `dump_s.escript` | Reads a `bs_emit`-produced `.abstr` file and feeds it through `compile:forms/2` with `'S'`, printing the same `{function,...}` terms `beam_disasm` would show for a real `.beam` — used to inspect beam-sharp's JIT-facing instructions from source. |
| `disasm_compare.erl` | Disassembles the REAL, already-built `Day01.beam` and `bench_erl.beam` from a `build.sh` run with `beam_disasm:file/1` (ships with OTP's `compiler` app) and prints `Wrap`/`wrap` and `Spin`/`spin` side by side. Output saved at `listings/disasm_compare_output.txt`. |
| `xmod_a.erl` / `xmod_b.erl` | Causation probe: the exact same `wrap`/`hit`/`spin` logic as `probe_erl_spin.erl`, except `wrap`/`hit` live in a separate module from `spin`, forcing a `call_ext` (cross-module) call. Confirmed by disassembly to reproduce the ticket's described "bare `{x,0}`" shape with no `{tr,...}`. |
| `xmod_a_specd.erl` / `xmod_b_specd.erl` | Same as above but `xmod_a_specd` carries an explicit, exact `-spec wrap(integer()) -> 0..99.` — tests whether an exact `-spec` on the callee changes the caller's inferred type at a cross-module call site. |
| `bench_causation.erl` | Times `probe_erl_spin:spin_only/2` (same-module, fully annotated) against `xmod_b:spin_only/2` (cross-module, bare) side by side, same VM, same run — the direct causation test the ticket's §3.2 asks for. |
| `bench_spin_reordered.erl`, `bench_more_reordered.erl` | Ordering-confound controls: identical to `bench_spin.erl`/`bench_more.erl` except beam-sharp is timed FIRST and Erlang LAST (the reverse of `aoc/bench/bench.erl`'s own `Impls` order, which always times beam-sharp last). Used to test whether the occasional elevated "min" for whichever implementation is timed last is a real per-language effect or a shared-VM ordering artifact — see the brief's Sub-decision 1. |
| `listings/` | Saved `.S`/disassembly output referenced in the brief. |

To reproduce from scratch: `bash build.sh`, then the `erl -pa /tmp/beam-sharp-bench-39/day01 -noshell -s <module> main ...` invocations shown in the brief's Evidence section.
