# Decision briefs, 2026-10-02

Five oldest open decision tickets: 39 (ENG-211), 52 (ENG-234), 57 (ENG-239), 59 (ENG-241), 60 (ENG-242).
Every ticket is still open; nothing here resolves one. Each `NN-*.md` is a brief, `probes/NN/` holds the probes
(`bash artifacts/probes/NN/run.sh`), and `NN-verification.md` is an independent re-run that hunted circular probes.
Each brief was revised after its verification report.

Limits that apply to all five: the sandbox had OTP 25, Elixir 1.14.0, Gleam 1.12.0 and Elm 0.19.2 (Elm could not
fetch packages, so no Elm claim is measured). The repo pins OTP 28.5, which was unreachable. `bsc` could not run
(its lexer needs OTP 26+), except in 57, where the real parser and checker were built through a shim. Elsewhere
every claim about `bsc` is read from source or cited from tickets, and the briefs label it so.
