# Probes behind the five decision briefs (tickets 39, 52, 57, 59, 60)

Everything here was run in a scheduled, unattended session on 2026-10-18. Nothing in `compiler/`, `wayfinder/` or the other
repo content was changed; prototypes are patches (`*/proto*`) applied to **scratch copies** of `compiler/src`.

## Toolchain (not in the image; installed this session)

| tool | version | source |
|---|---|---|
| Erlang/OTP | 29 (erts-17.1.1), and 28 (erts-16.4, env `otp28`, used by ticket 39 only) | conda-forge via micromamba (`conda.anaconda.org` was the only reachable package host; github.com, hex.pm, package.elm-lang.org were refused by the egress proxy) |
| Elixir | 1.20.4 (compiled with OTP 27) | conda-forge |
| Gleam | 1.19.1 | conda-forge |
| Elm | 0.19.1 | npm `@lydell/elm`. **It cannot compile anything** (needs elm/core from package.elm-lang.org), so it contributes no probe output |
| `bsc` | built from `compiler/src` with `leex`/`yecc`/`erlc`, **not** rebar3 | `build-variants.sh` |

`env.sh` puts these on `PATH` and defines `bsc`; `PROBE_ROOT` overrides the scratch root, `BSC_EBIN` selects a bsc variant.
`build-variants.sh` rebuilds the baseline `c` and every prototype variant from the patches.

## Known limits that apply to every brief

- **No gate was run.** There is no rebar3 for OTP 29 here. The eunit suite, driven by hand, fails **448 tests on the
  unmodified compiler** (diagnostic text tests see empty output under this setup); the failing set is identical for the
  ticket-57 variants (`57/eunit.sh`), so it is no regression signal either way. `./bin/verify.sh` must still be run on whichever option is chosen.
- Elixir and Gleam sources are not installed, only their binaries; they are cited by executed behaviour, not file:line.
  Erlang sources are (`stdlib-8.1.1/src/erl_parse.yrl`, `compiler-10.0.7/src/sys_core_fold.erl`).
- Timings are on a shared x86-64 VM with 1–5 % run-to-run noise.

## Layout

`39/` bench, asm, timing, order, ceiling · `52/` probe, prototype · `57/` probe, variants, neighbours, measure, eunit ·
`59/` probe, cost, neighbours · `60/` probe. `output-*.txt` is the saved output of each script, produced with `LC_ALL=C.UTF-8`.
