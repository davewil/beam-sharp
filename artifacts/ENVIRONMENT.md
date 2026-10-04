# Probe environment (recorded 2026-10-04)

Everything below was installed in the session container; none of it is the author's machine.

| tool | version | how | path / setup |
|---|---|---|---|
| Erlang/OTP | **28** (erts 16.x) — matches the tickets' OTP 28 | built from source (otp_src_28.0) | `export PATH=/opt/otp28/bin:$PATH` |
| Erlang/OTP | 25 (Ubuntu) | apt | `/usr/bin/erl` — **do NOT use for bsc**: `leex` `error_location` needs OTP 26+ |
| Elixir | 1.14.0 (compiled with OTP 24) | apt | `/usr/bin/elixir`, `mix` — older than the tickets' 1.19.5; say so where it matters. Running it on OTP 28 may or may not work; try `PATH=/opt/otp28/bin:$PATH elixir` first, else use OTP 25 |
| Gleam | 1.12.0 | release tarball | `/tmp/tc/gleam` (tickets measured 1.18.1) |
| Elm | 0.19.2 | npm | `elm` |
| rebar3 | 3.24.0 | release escript | `/tmp/tc/rebar3` (apt's rebar3 is OTP-25-only and crashes on 28) |
| bsc | built from this checkout | `cd compiler && PATH=/opt/otp28/bin:$PATH /tmp/tc/rebar3 escriptize` | `compiler/_build/default/bin/bsc` (already built) |

Machine: 4 vCPU Linux container, not Apple Silicon. Absolute timings are NOT comparable to the
tickets' numbers; only ratios within one run are.
