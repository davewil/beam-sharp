# Build note for these briefs (read first)

Run on 2026-10-08 in a cloud sandbox: **Erlang/OTP 25.3, Elixir 1.14.0** (apt), Elm 0.19 CLI via npm (cannot fetch packages), **no Gleam** (github.com and repo.hex.pm are denied by organisation egress policy; not retried).
The repo pins OTP 28.5 (`.tool-versions`). `rebar3` crashes here, so the compiler is built by `artifacts/build-bsc.sh`, with a lexer shim that makes diagnostic columns wrong and nothing else.

Consequences every brief inherits:
- `./bin/verify.sh` and the gates were **not** run. No variant here is gate-clean or committed to `compiler/`.
- Running `compiler/test/*_tests.erl` under eunit on OTP 25 gives 466–467 failures on the **unmodified** compiler (e.g. `maps:iterator/2` is OTP 26+). Comparisons are therefore set differences against that baseline, never absolute pass counts.
- Statements about Gleam and Elm are marked unverified wherever they appear.
