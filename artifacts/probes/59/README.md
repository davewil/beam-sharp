# Probes for ticket 59 (ENG-241) — the boundary guard's two scopes

Run `./run.sh`. Everything here was run on **OTP 25.3 / Elixir 1.14.0 / Gleam 1.12.0 /
x86_64 Linux (BeamAsm JIT)**; the tickets' numbers are OTP 28.5 arm64. Compare ratios and
shapes, not nanoseconds.

`bsc` was built from `compiler/src` on OTP 25, which has no `TokenLoc` in leex (added in 26): the
lexer shim in `build_variants.sh` gives every token column 1. Diagnostics' columns are therefore
wrong; nothing the probes read (emitted Erlang, run results, accept/refuse) depends on a column.
`rebar3` itself crashes on this host, so `build_variants.sh` runs leex/yecc/erlc directly.

Variants (built from a copy of `compiler/src`, `patches/*.patch`; `compiler/` is never edited):

| | tag test (record) | kind test (int / float / range) |
|---|---|---|
| v0 | every function | exported only (today) |
| v1 | exported only | exported only |
| v2 | every function | every function |
| v3 | exported only | every function |
| v4 | exported or escaping | exported or escaping |

*Escaping* = the function's name is taken as a value somewhere in the module (`Free`, `Double/1`:
ticket 75 / F46). The checker already records every such site in `fnames`.

Probes: 01 repro, 02/02b escaped-fun and foreign-callback reach, 03 reach attempts A-E, 10 cross-file escape (option C's blast radius), 04 all variants, 05-07 bytes and time, 08 eunit (`eunit_results.txt` holds a captured run), 09 corpus, `survey/`. The brief is `../../59-boundary-guard-scope-asymmetry.md`.
