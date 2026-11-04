# 52 — Dependency provenance: evidence

## 2026-11-04 — what the BEAM and `bsc` do today

**Toolchain: OTP 25 (Ubuntu apt) in a sandbox that could not build the pinned OTP 28.5.**
`.tool-versions` pins 28.5. The compiler could not be built here either: `leex` on OTP 25 rejects
the `{error_location, column}` option in `compiler/rebar.config`, so `rebar3 escriptize` crashes in
`bs_lexer.xrl`. Nothing below ran `bsc`; the compiler claims are read from source, and say so.

### Probe: `wayfinder/prototypes/52a-app-presence/run.sh` (OTP 25)

A stand-in `Elixir.Req` module inside an application `req` 0.7.3, called with and without
`ERL_LIBS` pointing at it.

| | no `ERL_LIBS` | `ERL_LIBS` set |
|---|---|---|
| `'Elixir.Req':new([])` | `{'EXIT',{undef,[{'Elixir.Req',new,[[]],[]},…` | `[]` |
| `code:lib_dir(req)` | `{error,bad_name}` | `"…/libs/req"` |
| `code:which('Elixir.Req')` | `non_existing` | `…/ebin/Elixir.Req.beam` |
| `application:get_key(req, vsn)` | — | `{ok,"0.7.3"}` |

So the application is checkable at compile time with one call, `code:lib_dir(App)`, and the version
is readable from the same place. (`code:which/1` on the module also works and needs no application
name; the ticket's question is whether the *source* names the application at all.)

### Read from source (not run)

- `compiler/src/bs_parser.yrl:170` — the foreign form is `'using' atom_lit '{' foreign_sigs '}'`
  producing `{foreign, Line, Module, Sigs}`. It carries one atom, the module.
- No attribute syntax exists in the grammar. Ticket 32's `[external: elixir, "Enum"]` was replaced
  by the `using :mod { … }` form; the ticket's `[external: elixir, app: req]` candidate therefore
  names a construct that is no longer in the language.
- `compiler/src/bsc.erl` has no code-path flag (the options are `--src-root`, `--diagnostics`,
  `--api`, `--repl`, `--batch`) and nothing in `src/` calls `code:lib_dir` or checks a foreign
  module for presence. A `using :'Elixir.Req'` block compiles on a machine with no Req and fails at
  run time with `error:undef`, which is what ticket 51 recorded.
- Ticket 51's decision: `ERL_LIBS` carries the code path, rebar3 declares the dependency in
  `rebar.config`. The dependency *is* declared, in the neighbour's manifest; this ticket is about
  whether the `.bs` file says it too.
