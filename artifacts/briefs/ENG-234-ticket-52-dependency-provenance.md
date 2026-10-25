# Ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

**State: open. Nothing here resolves it.** Written 2026-10-25 from `artifacts/probes/52/`; the verifier's report is `artifacts/verification/ENG-234.md`.

## The question, asked alone

Does a `.bs` file have to *name* its dependencies, or is it enough that the compiler *checks* them? The two come apart cleanly, and the ticket bundles them.

## What the probes established

Setup: Hex is unreachable here, so Req 0.7.3 was replaced by a stand-in Elixir application `demo-1.2.3` laid out as rebar3/mix leave one (`ebin/demo.app`, `ebin/Elixir.Demo.beam`). The claims below are about that shape, not about Req's nine-package tree (see "Not covered").

```csharp
using :'Elixir.Demo' {
    int double(int n)
}
public int Run(int n)
Run(n) -> :'Elixir.Demo'.double(n)
```

| step | unpatched `bsc` |
|---|---|
| S1 `ERL_LIBS` has the app: compile, `Run 21` | prints `42` |
| S2 same source, `ERL_LIBS` unset: compile only | **exit 0**, no diagnostic |
| S3 the S1 `.beam` on a VM without the app | `error:undef`, top frame `{'Elixir.Demo',double,[21],[]}`: no application, no version |
| S4 can the compiler find the owner itself? | yes: `code:which` gives `.../demo-1.2.3/ebin/Elixir.Demo.beam`; scanning every `.app` on the code path for one whose `modules` lists it gives `{demo,"1.2.3"}` (the first version of this probe hard-coded the candidate; the verifier caught it and it was rewritten) |
| S5 what the `.beam` records | `imports` lists `'Elixir.Demo':double/1`; `attributes` holds only `vsn` |

So the ticket's premise holds: the promise is never checked and the failure names no application. S4 is new: **the owner and version are derivable from the code path with nothing written in the source.**

## Options

### 1. Check, do not declare

Source unchanged. For every `using :mod { .. }`, the checker asks whether `mod` loads, and refuses at compile time if not.

Compiler delta: in `check_dir1` (`bs_check.erl:~93`), over the `{foreign, Line, Mod, _}` declarations (grammar at `bs_parser.yrl:170`):

```erlang
[case code:ensure_loaded(M) of {module, _} -> ok; _ -> erlang:error({foreign_module_absent, L, M}) end
 || {foreign, L, M, _} <- Decls]
```

plus a message in `bs_diag` (it has no catch-all: an unknown error tag crashes instead of printing). Patch `v52-Q` does the five lines and borrows an existing tag.

Measured: S1 still succeeds; S2 now exits 1 at compile time. **The prototype's text is wrong**: it reuses `unknown_module`, which says `using Elixir.Demo names no module and no namespace. a module is a source file this invocation can reach`. A purpose-written message is part of the work. Lookup cost: `code:which` 5 µs. `compiler/test`: 1494 passed, 4 failed, the unpatched baseline.

**Strongest counterargument.** It does not touch the ticket's stated reason: a stranger given only the `.bs` file still learns "module `Elixir.Demo` is missing", not which application to install. For Elixir the module-to-app guess is usually right (`Elixir.Req` to `req`); for Erlang modules it is not.

### 2. Declare the application by name on the `using`, and check it

```csharp
using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}
```

(`in` is an existing token; the spelling is illustrative. The ticket's `[external: elixir, app: req]` needs an attribute construct that the parser does not have: `[` is list syntax only, `bs_parser.yrl:32,546,780`.)

Compiler delta: one grammar rule; the `foreign` node gains a field, and four sites match its 4-tuple (`bs_check.erl:623, 641, 1078, 1116`); the checker verifies `code:lib_dir(App)` exists and that the app's `modules` list owns `Mod`; two diagnostics (app absent; module not in that app). Not prototyped; only the lookups are measured.

Measured: with the name given, the lookup is one `.app` file, about 0.3 ms. Without it, finding the owner by scanning costs roughly 0.25 to 0.35 ms per installed application (verifier's re-run: 3.0 to 3.4 ms at 10 apps, 15 to 17.5 ms at 60, 63 to 67 ms at 200; my own runs were somewhat higher; `p52_cost.sh`). These are a lower bound: the stand-in `.app` files are one-module files, and the cost script times `code:lib_dir` over names it created rather than discovery. Recording provenance in the `.beam` as `-bs_needs([{demo,"1.2.3"}])` adds 60 bytes for one dependency, 112 for three, on a 640-byte module.

**Strongest counterargument.** It restates what `rebar.config` or `mix.exs` already say (ticket 51 chose to ride on those), so the two can drift, and the compiler can check the name against the code path but cannot check it against the manifest. It also adds a clause to every `using` of a foreign module, including `:erlang` and `:file`, which belong to no application worth naming.

### 3. Name and exact version

`using :'Elixir.Req' in :req "0.7.3" { .. }`, checked against the `.app` file's `vsn` (S4 shows it is available at compile time).

Measured: same lookup cost as option 2. **Cost is not the argument against it.** A version in source is lock content, which is the resolution that ticket 51 and `scope.md` refuse, and `Mix.install` shows the shape it takes in practice (below).

**Strongest counterargument.** For a script with no project around it, this is what Elixir does and it works (below). If the handoff package has no manifest at all, the version has nowhere else to live.

## Recommendation

**Option 1 now; option 2 only if the audition shows a ticket failing for lack of source-level provenance.** Option 1 delivers the diagnostic that the ticket suspects is "the whole feature", changes no source, and costs about five lines and one message. It does not need option 2's decision, so it can ship first and nothing is lost by waiting.

The gating question for David, if option 2 is wanted: *must a stranger be able to read the application name from the `.bs` file alone?* The ticket argues yes ("cannot be handed over"). Nothing measured so far says that has failed.

## Neighbours (executed; `p52_neighbours.sh`)

| language | where the dependency is named | when a missing one is caught |
|---|---|---|
| Erlang | `-include_lib("demo/include/demo.hrl")` names the app in source; a plain `Mod:fun()` names no app | the include: at compile time, `can't find include lib`. The call: never at compile time (`erlc` exit 0). `systools:make_script` on a `.rel` naming an absent app: `{error, systools_make, [{error_reading,{demo,{not_found,..}}}]}` |
| Elixir | `mix.exs`; or in a script `Mix.install([{:demo_proj, path: ..}])` (ran, printed 42) | an absent module compiles with a warning; `UndefinedFunctionError` at run time |
| Gleam | `gleam.toml` `[dependencies]`; `@external(erlang, "Elixir.Demo", "double")` names no package | the external: never at compile time (`gleam build` exit 0), same as `bsc` today. `import nopkg`: compile error `Unknown module` |
| Elm | `elm.json` | not executed: the registry is blocked |

Gleam's `@external` is the closest relative of `using :mod { .. }` and behaves exactly as `bsc` does now.

## Not covered by the probes

- **Transitive dependencies.** Req's tree has nine packages. Options 1 and 2 as written check only the module the source names. Walking the `applications` list of the `.app` file is a few lines on top of option 2, but it was not run.
- **Q's test coverage is thin.** No existing test names a foreign module that is absent at compile time, so `compiler/test` staying at its baseline says only that Q breaks nothing that was tested.
- **Beam size** was measured by inserting the attribute into a saved 640-byte fixture with `compile:forms`, not through `bsc`.
- **Real Hex packages.** The stand-in has no `applications` chain, no `priv` directory, no NIFs.
- Ticket 52's note "sequence it with ticket 50": 50 is resolved (a foreign struct is a `map<atom, term>`, no new surface), so that sequencing no longer constrains this.
