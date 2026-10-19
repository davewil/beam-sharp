# Decision briefs, 2026-10-19

Five oldest unresolved decision tickets on the beam-sharp map (Linear `Backlog`, numbered, `wayfinder:grilling`):
52 (ENG-234), 60 (ENG-242), 62 (ENG-252), 66 (ENG-309), 82 (ENG-382). Skipped as not decision tickets: 25
(ENG-191, a prototype) and ENG-250 (a bug). **No ticket is resolved. Every decision is left to David.**

| Brief | Ticket | Probes |
|---|---|---|
| [52-dependency-provenance.md](52-dependency-provenance.md) | ENG-234 | `probes/52/` |
| [60-which-modules-may-name-this-one.md](60-which-modules-may-name-this-one.md) | ENG-242 | `probes/60/` |
| [62-the-outbound-abi.md](62-the-outbound-abi.md) | ENG-252 | `probes/62/` |
| [66-a-union-name-in-pattern-position.md](66-a-union-name-in-pattern-position.md) | ENG-309 | `probes/66/` |
| [82-a-failed-encode-at-run-time.md](82-a-failed-encode-at-run-time.md) | ENG-382 | `probes/82/` |

## Environment the probes ran in (the container had none of these)

| Tool | Version | How obtained |
|---|---|---|
| Erlang/OTP 25 + Elixir 1.14.0 | apt | probes 52, 60, 62 |
| Erlang/OTP 28.0 | built from `otp_src_28.0` (the repo pins 28.5, unreachable) | probes 66, 82 and every `bsc` run |
| `bsc` | `rebar3 escriptize` on a **copy** of `compiler/` at `019533d`, in `/tmp/dl/compiler-build`; the repo tree is untouched | 66, 82 |
| Gleam 1.12.0 | release binary | 52, 60, 62, 66 |
| Elm 0.19.1 | release binary, **cannot compile**: `packages.elm-lang.org` is unreachable | none; every Elm claim below is marked unmeasured |

Not available: Hex (`repo.hex.pm`), so no Jason, `gleam_json` or `gleam_stdlib`. Source archives for Elixir and Gleam
(`github.com/.../archive`, `codeload`) return 403, so **citations into those compilers are probe output, not source lines**.
OTP 28 source is real and cited by path and line (`/tmp/dl/otp-src/lib/stdlib/src/json.erl`).

## Probe corrections made during the run (kept visible)
- 62: first run named the file `shop.erl` for module `'Shop'`; `erlc` refused and every call reported `undef`. Renamed and re-run.
- 52: first xref run skipped the beam (no `debug_info`) and reported `{ok,[]}`; re-run with `+debug_info`. Gleam's first build
  failed on a module named `gl` (collides with an OTP module); renamed.
- 60: a `sed` meant to add a call to `@internal` did not apply; rewritten by hand before the result was read.
