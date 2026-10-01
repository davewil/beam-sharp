# Decision brief — ticket 52 (ENG-234): dependency provenance

Prepared 2026-10-01 by a scheduled run. **Nothing is resolved.** Probes and the prototype patch are
under `artifacts/probes/52/`. `bsc` from HEAD `0dddf8b`, OTP 27.3.4; neighbours: Erlang 25 / Elixir
1.14 (apt), Gleam 1.18.1. **Elm is not measured** (its compile needs `elm/core`, unreachable offline;
the probe script records that it does not measure Elm).

## The premise, re-measured

*"Compile it on a machine with a different `ERL_LIBS` and it fails at the call site with
`error:undef`, having promised nothing."* (`p3_bsc_today.sh`, fake `req` 0.7.3 app, a B# module whose
`using :'Elixir.Req'` block declares `new/1`):

```
ERL_LIBS holds req   -> (:req, [])            exit 0
ERL_LIBS empty       -> crashed: error:undef  exit 1     (compile alone: exit 0, no output)
```
**Confirmed.** `bsc` compiles it silently and the failure is a run-time `undef`.

## Sub-decisions

1. Does the *compiler* check a foreign module's presence at all? (the ticket: "may be the whole feature")
2. Does the *source* name the application (and a version)? Per block or per module?
3. Does the check refuse or warn, given `--api` compiles with nothing built?

## Neighbour survey (`p1_missing_dependency_diagnostics.sh`)

| language | source names a dependency? | compile-time behaviour for a call into an absent module |
|---|---|---|
| Erlang (`erlc`, OTP 25) | no (project-level `.app.src`, rebar.config) | **silent**, exit 0; run time `undef`. `xref` (a separate tool, needs `+debug_info`) reports `[{{e,f,0},{'Elixir.Req',new,1}}]` |
| Elixir (`elixirc` 1.14) | no (project-level `mix.exs`) | **warning**, exit 0: `Req.new/1 is undefined (module Req is not available or is yet to be defined)`; silenced per module by `@compile {:no_warn_undefined, Req}` |
| Gleam 1.18.1 | no (`gleam.toml`) | a Gleam `import` of an absent module is an **error** (`Unknown module`); an `@external(erlang,"Elixir.Req","new")` to an absent Erlang module compiles **silently**, exit 0 |
| Elm | not measured | not measured |

So the closest neighbour to "a foreign `using` block" (Gleam's `@external`, Erlang's remote call) is
silent, and the one that does check (Elixir) **warns, does not refuse**, and declares nothing per
file. No neighbour records an application name at a *foreign call site* (Erlang's `-include_lib("app/include/x.hrl")` does name an app in source, and `erlc` refuses when it is absent, but that is for headers, not calls). Sources for
Elixir and Gleam are not installed in the sandbox: behaviour only, no file:line.

## Measurements

- **What a check can read** (`p2_check_cost.sh`, OTP 25, fake `req-0.7.3` in `ERL_LIBS`):
  `code:which('Elixir.Req')` returns the beam path; `code:lib_dir(req)` returns the app dir; the `.app`
  file gives `vsn "0.7.3"`. Absent: `non_existing` / `{error,bad_name}`. No direct "which app owns this
  module" call exists; it is a path parse.
- **Cost**, 20 000 lookups per sample, median of 5, a noisy box: `code:which` present ≈ 195 µs,
  absent ≈ 1.5 ms on OTP 25 (the verifier, on OTP 27, got ≈ 43 µs and ≈ 0.5 ms; `p2` uses whichever `erl` is first on PATH); `code:lib_dir` ≈ 1.7–3.7 µs either way;
  `ensure_loaded` of a loaded module ≈ 76 ns. Per `using` block, once per compile: not a budget issue.
- **False positives** (`p4`, patch `variant_presence_check.patch`: 15 lines in `bs_check.erl` and
  `bs_diag.erl`, raising an error when a foreign `using` module is neither compiled in this
  invocation nor on the code path). Over the 27 example modules that compile today: **0 flip to
  refused, but this is near-vacuous**: only 4 of the 28 example files contain a `using :Mod` block and all four use always-present OTP modules (`erlang`, `file`, `lists`, `ets`). Over every distinct foreign module the corpus names (examples and exemplars, 9): **8
  present, 1 absent: `epgsql`** (exemplar 25d, which does not compile in its checked-in layout anyway: measured, "no `module` line"; compare ENG-446 for 25e–25g). On OTP 25 `json` would also be absent (it joined OTP in 27).

## Options

**A. Presence check only; no new syntax.** `bsc` looks up each foreign `using` module at compile time.
```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }   // unchanged source
//   error: `using 'Elixir.Req'` names a module that is not on the code path
```
Compiler delta: ~15 lines (`foreign_modules_present/2` and one diagnostic), measured above.
*Strongest counterargument:* it names the **module**, not the **application**, so the message cannot
tell a stranger to install `req`, and it does nothing for the stated destination (a spec an agent
fleet implements without David): the source still does not say what it needs.

**B. A source-level `app` on the `using` block, plus the check.**
```csharp
using :'Elixir.Req' in req { term new(list<(atom, term)> opts) }    // spelling hypothetical
```
Compiler delta: a new grammar rule in `bs_parser.yrl` (the parser has no attribute or `in` clause
today), a field on the `{foreign, ...}` node every consumer of that tuple matches on
(`foreign_wrappers`, `collapse_decl`, the emitter, `--api`), and the check becomes
`code:lib_dir(App)`. Version stays out (a constraint is resolution, which 51 refuses).
*Strongest counterargument:* every `using` of one app repeats it, the declaration can disagree with
`ERL_LIBS` in the other direction (app present, module not), and it adds a second thing to keep in
step with `mix.exs`/`rebar.config` that **no neighbour makes a foreign call site carry**.

**C. Leave it (ticket 51's "reads what rebar3 or mix already produced").**
Compiler delta: none. *Strongest counterargument:* the run-time `undef` is exactly the
silent-promise failure the language's boundary stance (ticket 18) argues against elsewhere.

## Recommendation

**A, as a warning for `--api` and a refusal for a full compile, and revisit B when the clean-room
package is assembled.** The presence check is the part with measured value (turns `undef` into a
diagnostic, no false positives on code that compiles today, microseconds), and ticket 52 itself
suspected it "may be the whole feature". The app-naming half is a *packaging* concern: a handoff
manifest listing apps is a better home than every `using` block, and no neighbour puts it in
source. If David wants B anyway, sequence it with ticket 50 as the ticket says: both extend the same
`using` construct.

## Caveats

- Elm unmeasured; Elixir/Gleam by behaviour only.
- The prototype refuses and does not distinguish `--api`: the verifier measured that HEAD `--api` succeeds with nothing built and the patched build prints the refusal in `--api` mode too. (`bs_check.erl:480`'s comment concerns imports, not `using` blocks.) The warning-only path is unbuilt.
- `code:which/1` on OTP 25 for the lookup cost numbers; the `bsc` build is OTP 27.

## Verification

An independent verifier (`artifacts/probes/52/verify/REPORT.md`) reproduced every probe result, found no probe-specific text in the patch, and added its own control (its patched build refuses `using 'Elixir.Req'` with `ERL_LIBS` empty and accepts it when set). Its corrections are applied above; the material one is that the false-positive result is near-vacuous.
