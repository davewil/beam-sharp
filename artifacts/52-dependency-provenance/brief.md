# Ticket 52 — Dependency provenance: what does a `.bs` file say about what it needs?

- **Ticket**: 52, [ENG-234](https://linear.app/davewil/issue/ENG-234)
- **Status**: OPEN — undecided. This brief is a recommendation; the ticket file, Linear and `wayfinder/` are untouched.
- **Date**: 2026-10-11
- **Environment**: OTP 29 (erts-17.1), Elixir 1.20.4 (compiled with OTP 27), Gleam 1.19.1, Elm 0.19.0, repo `d8a3bd8` (`compiler/src` unmodified; the prototype below is a patched *copy*).
- **Probes**: `artifacts/52-dependency-provenance/probes/` (index in `probes/README.md`; `./run-all.sh` reproduces every `.out` in about four minutes). Prototype: `artifacts/52-dependency-provenance/prototype/`.

---

## 1. The questions, in dependency order

**Q1 (gates everything). Does a `.bs` file name an *application*, or is the module on its `using` line all the source says?**
Measured below: the ticket's failure (a different machine, no `req`) is detectable from the module name alone, with no new syntax. So Q1 is really "what does naming the application buy that the module does not?"

Only if Q1 is yes:

- **Q2. Per `using` block, or once per module?** And is it spelled as an attribute `[app: req]` or as a keyword `in req`? (The attribute spelling needs the language's first attribute grammar; see §3.)
- **Q3. A name or a version?** Follows from Q1; §5 shows the ticket's premise here is partly wrong.
- **Q4. When the application is absent at compile time, is that an error or a warning?** Follows from Q1/Q2.

## 2. Claim ledger

| # | Claim (source) | Probe | Result |
|---|---|---|---|
| 1 | "Compile it on a machine with a different `ERL_LIBS` and it fails at the call site with `error:undef`" (ticket) | `p1_undef_only_at_call_site` | **Partly refuted.** *Compiling* succeeds, exit 0, no output at all. The failure is at *run* time, and `bsc` prints `crashed: error:undef` with **no module name** (the name only appears in a raw Erlang stack). See 2a. |
| 2 | "A name is checkable at compile time (is the application present?)" (ticket) | `p2_presence`, `p5_prototype` | **Confirmed, with a trap**: `code:lib_dir/1` is the wrong primitive (2b). |
| 3 | "A version constraint is resolution, which is the boundary's territory" (ticket) | `p2b` (version section) | **Partly refuted.** *Reading* the installed version is a cheap read of the `.app` (278 us); *resolving* (choosing, fetching) is what the boundary refuses. The cost of a version is the constraint grammar, not resolution. |
| 4 | "Checking the application is on the code path at compile time is one line" (ticket) | `p5_prototype`, `m3` | **Confirmed for presence** (`code:where_is_file("req.app")`). Telling whether the application *owns the module* is a second, costlier step (28 us vs 5 us, `m3`). |
| 5 | "Extending `using` costs no new file and no new concept" (ticket) | `prototype/deps.patch` | **Partly refuted.** No new file, but `[external: …] using` is a decl form the grammar does not have: ticket 22 found "there is no attribute grammar, and there never has been" (`wayfinder/issues/22-how-opinionated.md:89`). Cost is three yacc rules; conflict count unchanged at 6 shift/reduce (before and after). |
| 6 | `external: elixir` carries information (ticket's spelling) | `p5_prototype` (A-wrong-kind) | **Refuted as new information.** The atom already says: `:'Elixir.X'` is Elixir, `:ets` is Erlang. The key can only be *inconsistent* with the atom, never informative. |
| 7 | "`mix` / Erlang record dependencies in the project file, not in source" | `p3a`, `p3b` | **Confirmed.** See §4. |
| 8 | "Several `using` blocks may draw on one application, and repeating it is a write cost" (ticket) | `m2_beam_size` | **Confirmed in bytes**: per-block records grow 176 B (3 blocks) to 604 B (12 blocks); one deduped attribute is a flat 60-64 B. |

### 2a. What exactly happens (probe `p1`)

Fixtures are built here, not downloaded: a mix-built Elixir app `exdep` (module `Elixir.ExDep`, app name `exdep`), an `erlc`-built `erldep`, and the Elixir install itself. Machine 1's `ERL_LIBS` has them; machine 2's has the Elixir install but not `exdep`/`erldep`.

```
-- machine 1:  bsc bs/Dep ViaExDep '<<"hi">>'    -> "HI"            exit=0
-- machine 2:  bsc bs/Dep ViaExDep '<<"hi">>'    -> crashed: error:undef   exit=1
-- machine 2:  bsc bs/Dep ViaStdlib ...          -> "HI"            (Elixir.String is present)
-- machine 3 (apps present, Elixir install absent):  ViaExDep   -> crashed: error:undef
-- control, machine 2:  bsc bs/Dep Pure 41        -> 42              (compile did not fail)
-- compile only on machine 2:  bsc -o OUT bs/Dep  -> no output, exit 0, Dep.beam written
-- Erlang node on machine 2, calling that beam:
   {error,undef,{'Elixir.ExDep',shout,[<<"hi">>],[]}}      code:which('Elixir.ExDep') = non_existing
-- same beam on machine 1:  {ok,<<"HI">>}
```

Two findings the ticket did not state. First, `bsc` throws away the one fact the user needs: its output `crashed: error:undef` does not say *which* module is missing. Second, machine 3 shows the declaration problem is wider than the module on the `using` line: `exdep` is present but its own dependency `elixir` is not, and the failure is the same bare `undef`. A name-only `app: exdep` would not have caught that; the `.app`'s `applications` key (`[kernel,stdlib,elixir,logger]`) is where the transitive information lives.

### 2b. Which presence primitive is right (probe `p2_presence`, 15 cases)

Source: `kernel-11.0.4/src/code_server.erl`. `lib_dir/1` is `do_dir({lib_dir,Name}, …)` → `lookup_name(Name, NameDb)` (`:1036-1039`). The name database is keyed by **directory name** via `get_name_from_splitted` (`:643-652`: the segment before `ebin`, truncated at the first hyphen). It never reads a `.app`. `ERL_LIBS` only adds `<dir>/*/ebin` for directories that have an `ebin` (`get_user_lib_dirs_1`, `:141-151`), again without reading a `.app`.

| Case | `code:lib_dir(App)` | `code:which(Mod)` | `where_is_file("App.app")` | `application:load(App)` |
|---|---|---|---|---|
| mix app on `ERL_LIBS` (`exdep`, `Elixir.ExDep`) | ok | ok | ok | ok |
| Elixir stdlib: `Elixir.String` lives in app `elixir` | ok (`elixir`) | ok | ok | ok |
| naive app name guessed from the module (`string`) | `{error,bad_name}` | **ok** | non_existing | error |
| module on `-pa`, in **no** app | `bad_name` | ok | non_existing | error |
| ebin dir with beam but **no `.app`** | **ok** | ok | non_existing | error |
| dir `dirname_mismatch/` holds app `realname`; ask by **app** name | `bad_name` | ok | **ok** | ok |
| ...ask by **dir** name | **ok** | ok | non_existing | error |
| `.app` has `modules=[]` but the beam exists | ok | ok | ok | ok (`.app` key lists nothing) |
| `.app` lists `ghostmod`, beam absent | ok | **non_existing** | ok | ok (key says present) |
| nothing at all | bad_name | non_existing | non_existing | error |
| module loaded from memory only (`load_binary`) | `bad_name` | `[]` | n/a | n/a |

Conclusions, each from rows above:

- `code:lib_dir/1` answers "is there a directory with this name on the path", not "is there an application". It says present for a directory with no `.app`, and absent for an app whose directory is named differently. **Do not use it.**
- `code:where_is_file("<app>.app")` answers the question asked: is an application of that name on the path. It is side-effect free, found both mix- and erlc-built apps, and is not fooled by directory naming.
- `application:load/1` also answers it but registers the app's environment in the node. It is 190 us cold against 5 us (`m1`). Use it only if the check is meant to start the app.
- The `.app` `modules` key lies in both directions (`bareapp`: lists nothing yet the beam is there; `ghostapp`: lists a module that is not there). `code:which(Mod)` is the arbiter for a module.
- The Elixir stdlib edge: `Elixir.String` is in app `elixir` and neither a lowercased module name (`string`) nor `req` for `Elixir.Req` can be derived by rule. `p4_derivable` shows the *reverse* map (module to owning app) **is** derivable on a machine where the module is present: walk `code:which(Mod)` to the `.app` beside the beam (`'Elixir.String'` → `elixir`, `'Elixir.ExDep'` → `exdep`, `erldep` → `erldep`). It fails exactly where it is needed, when the module is absent (`non_existing`), which is why a declared name is the only way to say what to install.
- A module on the path that belongs to no app (`orphanmod`) is real; any "must belong to an app" rule would reject it.
- The check is a statement about the **compiling VM** only. `p2b`: under `-mode embedded` (how a release runs) the same `ERL_LIBS` gives `lib_dir(exdep) = {error,bad_name}` and `ensure_loaded` returns `{error,embedded}`; `code_server.erl:104-114` consults `ERL_LIBS` only `case Mode of interactive`. A compile-time pass proves nothing about the release. Also `code:ensure_loaded/1` actually loads the module (and would run an `-on_load`); `code:which/1` does not (`p2b`: `is_loaded` false → true).

## 3. How the neighbours record it (probes `p3a`-`p3d`)

| Language | Where the declaration lives | What the toolchain says about an undefined remote module / absent dependency (real output) |
|---|---|---|
| **Elixir / mix** | `mix.exs` `deps:` (build) and `application/0` `extra_applications:` (runtime); mix writes `{applications,[kernel,stdlib,elixir,logger,exdep]}` into the compiled `.app`. **Nothing is in the `.ex` source and nothing about deps is in the `.beam`** (`beam_lib:chunks(…,[attributes])` gives only `vsn`). | `warning: Nonexistent.Mod.go/1 is undefined (module Nonexistent.Mod is not available or is yet to be defined)`. The same text, plus a naming hint, when the app exists on disk but is **not listed in deps** (mix prunes the code path to listed deps): `ExDep.shout/1 is undefined (module ExDep is not available or is yet to be defined). Make sure the module name is correct …`. A listed dep with a function that does not exist: `ExDep.nope/1 is undefined or private`. Stdlib (`String`) is silent. It is a **warning**, the build succeeds. Elixir sources are not installed here (beams only), so there is no file:line to cite; the citation is the run. |
| **Erlang** | `.app.src` `applications` (runtime) and `rebar.config` `deps` (build). There is **no `-application` attribute**: `-application(some_app).` compiles as an inert wild attribute (`wild:module_info(attributes)` shows `{application,[some_app]}`, nothing reads it). rebar3 itself is not installed, so rebar.config and `.app.src` handling is not probed. | `erlc +warn_all`: silent, exit 0. `xref` `undefined_function_calls` → `[{{caller,go,1},{missing_dep_mod,run,1}}]`; **trap**: on a beam compiled without `debug_info`, xref returns `[]` with no error. `dialyzer`: `Unknown functions: missing_dep_mod:run/1 (erl/caller.erl:4:10)` (`dialyzer_cl.erl:739`). Run time: `application:ensure_all_started(missing_dep_app)` → `{error,{missing_dep_app,{"no such file or directory","missing_dep_app.app"}}}`; a release naming an absent app → `systools:make_script` `{error,systools_make,[{error_reading,{missing_dep_app,{not_found,"missing_dep_app.app"}}}]}` (`systools_make.erl:638`). |
| **Gleam 1.19.1** | `gleam.toml` `[dependencies]` only; the compiled `.app` gets `{applications,[dep3]}`. | `@external(erlang, "nonexistent_mod", "f")` in a project with no dependencies: **`Compiled in 0.52s`, exit 0, no warning**; running it: `error:undef {nonexistent_mod,f,[1],[]}`. The Gleam compiler does *not* check an Erlang FFI target. A missing Gleam package is checked: `error: Unknown module … No module has been found with the name dep3`. A hex version range in `gleam.toml` needs the registry (`Dependency resolution failed … error sending request for url (https://repo.hex.pm/…)`, blocked here, so no hex package was resolved). |
| **Elm 0.19.0** | `elm.json` `dependencies`. | **Not probed to completion**: the registry is unreachable; even `elm make` on a module with no imports stops at `HTTP PROBLEM … https://package.elm-lang.org/all-packages … 403`. Nothing is cited about Elm beyond that. Elm has no Erlang FFI so it is a weak comparison in any case. |

The shared pattern: **every neighbour keeps the dependency in the project file and none puts it in a source file.** Gleam, the language whose `@external` syntax ticket 32 borrowed, does not check that the FFI target exists, and Erlang/Elixir only complain through optional analysers (xref, dialyzer, the mix xref pass). The ticket's proposal would put `bsc` ahead of all four on this one point, which is a reason to do it only if the cost is small; the next section measures that.

## 4. Measurements

All counts are from the final `run-all.sh` run; `.out` files hold the full output.

### 4.1 Cost of the presence check in the `bsc` pipeline (`m1`, `m3`, `m4`)

| Primitive | Cold, first call in a fresh VM (median of 25 VMs; range) | Warm per call (200k loop) |
|---|---|---|
| `code:where_is_file("exdep.app")` | 4.7 us (4.3 to 15.6) | about 4 us present, 15-30 us absent |
| `code:which(Mod)`, present | 20.2 us (18.3 to 26.1) | about 4-6 us |
| `code:which(Mod)`, **absent** | n/a | 18 us, **30 us with 300 extra apps on the path** (it scans the whole path) |
| `code:lib_dir(App)` | 11.0 us (9.5 to 31.2) | about 3 us present, 1.9 us absent |
| `application:load(App)` | 186.8 us (152 to 535) | 1.8 us once loaded |
| read the `.app` for its `vsn` (`file:consult`) | n/a | 278 us |

Cold figures run the four calls in a fixed order in one VM, so `lib_dir` carries the first `code_server` message round-trip. With 300 extra application directories on `ERL_LIBS` the cold numbers do not move (`lib_dir` 11.4 us); only the *absent* warm lookups grow (≈ 2x). The harness sees a slow call (control: `timer:sleep(1)` reads 2.0 ms, the sleep granularity here).

The prototype check inside a real compile (`m3`, in-VM, three declarations): first call 3.8 ms (loads `filelib`, first path scan), warm median **0.54 ms**, against a whole `bsc:file_to_dir` (parse, check, emit, `erlc`) of **7.1 ms median** (6.3 to 51 ms). Where the time goes: `where_is_file` 8 us, `which` 8 us, owner-by-directory-listing (`filelib:wildcard`) 28 us, owner-by-directory-name 5 us; the rest of the 0.54 ms is the prototype's own list handling and `os:getenv`, not the BEAM primitives, so the check is *not* worth optimising.

CLI wall clock (`m4`, includes a 264 ms bare VM boot; 20 runs each): stock `bsc` 481 ms, prototype with three declarations 474 ms, prototype on an undeclared module 505 ms, with ranges (about 420-630 ms) that overlap completely. **The cost of the check is not resolvable at CLI level.**

### 4.2 Cost in `.beam` bytes (`m2`, forms written by hand, compiled with `compile:forms`)

Baseline is the module bsc actually emits (`Dep`, 3 `using` blocks; `Many`, 12 blocks over 3 apps), the attribute inserted after `-module`/`-export`.

| Variant | Dep, +B (no debug_info / debug_info) | Many (12 blocks), +B | Term words |
|---|---|---|---|
| V1 one `-bs_dep({Mod,elixir,App})` per block | +140 / +176 | +548 / +604 | 18 / 72 |
| V2 one `-bs_deps([App,…])` per module, deduped | **+40 / +64** | **+36 / +60** | 8 |
| V3 per block, with a version string | +164 / +216 | +656 / +732 | 57 / 228 |
| V4 per block, long app names (control) | +260 / +308 | +1028 / +1100 | 18 / 72 |

`compile:forms` time is indistinguishable (30 runs each, medians 1.0-2.1 ms; the spread within a variant exceeds the difference between variants). The attribute is readable **without loading** the module: `beam_lib:chunks(Bin,[attributes])` → `{bs_deps,[erldep,exdep,string]}`. The module names themselves cost nothing to record because the beam's import table already carries them (`p4_derivable`: `beam_lib` `imports` of the compiled `Dep` lists `'Elixir.ExDep'`, `'Elixir.String'`, `erldep`).

A detail from `m2` worth keeping: with the naive derivation "lowercase the tail of the module" the recorded apps were `[erldep,exdep,string]`: **`string` is wrong** (the app is `elixir`). Any rule that fills `app:` in automatically from the module name writes a lie for the Elixir standard library.

## 5. The three options

All three were run through a prototype `bsc` (`prototype/build.sh` builds a patched copy of `compiler/src`; the patch is 32 added lines in `bs_parser.yrl`, `bsc.erl`, `bs_emit.erl` plus the 79-line `bs_deps_proto.erl`). Output is in `p5_prototype.out`. `ELIXIR_LIB` below is the Elixir install on `ERL_LIBS`.

### Option A — on each `using` block (the ticket's candidate)

```csharp
module Client

[external: elixir, app: exdep] using :'Elixir.ExDep' {
    binary shout(binary s)
}

[external: erlang, app: erldep] using :erldep {
    int double(int n)
}

public binary Go(binary s)
Go(s) -> :'Elixir.ExDep'.shout(s)
```

Keyword spelling that needs no attribute grammar (ticket 22's precedent: the language took keywords, `behaviour`, `using :ets`, rather than attributes): `using :'Elixir.ExDep' in exdep { … }`.

*Run (prototype)*:

```
machine 1                 -> "HI"                                         exit=0
machine 2 (no exdep)      -> bsc: error: line {4,1}: application `exdep` (for :'Elixir.ExDep') is not on the code path (ERL_LIBS=FX/libB:ELIXIR_LIB)
                             bsc: error: line {8,1}: application `erldep` (for :erldep) is not on the code path ...   exit=1
wrong app name (ex_dep)   -> bsc: error: line {4,1}: application `ex_dep` (for :'Elixir.ExDep') is not on the code path
app exists, wrong owner   -> bsc: error: line {4,1}: module :'Elixir.ExDep' belongs to application `exdep`, not `erldep`
external: erlang on an Elixir.* atom -> bsc: error: line {4,1}: external: erlang but :'Elixir.String' is an Elixir.* atom
```

*Compiler delta*: a grammar arm (`decl -> '[' dep_attrs ']' foreign_decl`, or `'using' atom_lit 'in' lident '{' … '}'`) that returns `[{requires,…}, {foreign,…}]` (the `program` rule already flattens a list-valued decl, `bs_parser.yrl:74`, so `{foreign,…}` and every pass that matches it are untouched); consume `requires` before `bs_check:check_dir`; one pass of about 50 lines that calls `where_is_file` per app and an owner lookup per `using`; `bs_emit` writes `-bs_deps([...])` once per module. `bsc --api` is unaffected: on machine 2, `--api` of the annotated module answers normally (`p5_prototype.out`).

*Evidence*: the ticket's failure becomes a compile-time diagnostic that names the **application**; the ownership check catches a wrong name the module-only check cannot (and `external:` adds nothing the atom did not say). Grammar conflicts: 6 shift/reduce before, 6 after.

*Strongest counterargument*: the declaration **duplicates the project file's dependency list** that ticket 51 put in `rebar.config`. Two lists, one of which the compiler can check against the code path and neither against the other. And as written the check is **an error that blocks the build** on any machine lacking the app: machine 2 above cannot even compile the `Pure` function that touches nothing foreign. Making it a warning removes that, but then the declaration is documentation the compiler half-enforces.

### Option B — once per module

```csharp
module Client in exdep, erldep, elixir

using :'Elixir.ExDep' {
    binary shout(binary s)
}

using :erldep {
    int double(int n)
}

using :'Elixir.String' {
    binary upcase(binary s)
}
```

Attribute spelling: `[app: exdep, app: erldep, app: elixir] module Client`.

*Run (prototype)*: machine 1 runs; machine 2 reports each missing `using` module and each missing app; a module that **forgets to list** an application is refused, which Option A cannot do:

```
bsc: error: line {4,1}: :'Elixir.ExDep' belongs to application `exdep`, which the module does not list (lists: [erldep,elixir])
```

*Compiler delta*: as A, minus per-block syntax; the pass additionally maps each `using` module to its owning app and demands membership in the list (OTP's own libraries are implicit, by path prefix of `code:lib_dir()`; `elixir` is *not* implicit, which writes ticket 51's "Elixir is a per-project dependency" into the source). The beam attribute is the same single deduped `-bs_deps`: 60-64 B regardless of block count.

*Strongest counterargument*: completeness is checked only on a machine where every module is present, because the owner of an absent module is underivable (§2b). On machine 2 the listing check cannot run and degrades to "is each listed app present". Also `module Client in …` reads as "module is in application", which is a different meaning than the OTP "belongs to".

### Option C — nothing in the source; the project file owns it (decision 51 as it stands) plus a module-keyed warning

```csharp
module Client

using :'Elixir.ExDep' {
    binary shout(binary s)
}
```

This is today's source. The only change is in `bsc`: for each `using :M { … }`, `code:which(M)`. Prototype run on machine 2:

```
bsc: warning: line {4,1}: using :'Elixir.ExDep' -- the module is not on the code path of this machine; a call will fail with error:undef (no application is declared)
bsc: warning: line {8,1}: using :erldep -- the module is not on the code path of this machine; ...
crashed: error:undef                                    exit=1   (only when the function is then called)
```

*Compiler delta*: no grammar, no AST node, no beam attribute. One loop over the `{foreign, L, Mod, _}` decls `bsc` already has (`bs_check.erl:623`/`641`/`1065` match them), calling `code:which/1`; warning on stderr. About 12 lines.

*Evidence*: it catches the ticket's scenario with the information the source already carries. It costs one `code:which` per `using` (about 20 us cold, 5 us warm, 18-30 us when the module is absent, `m1`). It never lies about ownership because it never claims any.

*Strongest counterargument*: it names a **module**, not the thing to install. A stranger handed only the `.bs` source and the spec sees `:'Elixir.ExDep'` and cannot derive that the package is `exdep` (nor, for `Elixir.String`, that it is `elixir`: §2b). The ticket's own argument, that a program must be handable on its source alone, is exactly this gap, and only A or B closes it. C relies on the `rebar.config` that ticket 51 already says travels with a project.

## 6. Recommendation

**Take Option C now, and spell A (keyword form) only if David decides the handoff must be source-only.**

Reasons, in order of weight:

1. **The measured failure is fixed without syntax.** The ticket's scenario (different `ERL_LIBS`, no `req`) is caught at compile time by `code:which/1` on the module the `using` line already names (§5 C). The extra thing A/B add is the *application name*, and that only helps the human reading the diagnostic; the compiler's decision does not need it.
2. **The declaration would duplicate `rebar.config`.** Ticket 51 decided dependencies live there with `rebar_mix`; every neighbour does the same (§3: Elixir, Erlang, Gleam all keep it in the project file, none in source). A second list the compiler cannot reconcile with the first is the drift the standing rule warns about.
3. **The attribute form is not free.** The language has no attribute grammar (ticket 22), so `[external: elixir, app: req] using …` makes this ticket the first `[`-leading declaration; the prototype shows it is cheap (three rules, no new conflicts), but the keyword form `using :M in app { }` needs no such precedent. `external:` should be dropped either way: the atom already says it (ledger 6).
4. **Make it a warning, never an error.** A declared-but-absent app as a hard error stops `bsc` compiling anything on a machine without the dependency, including a function that touches none (§5 A). `--api` is unaffected either way (§5 A). And whatever the check says, it speaks for the compiling VM only: a release runs in embedded mode, where `ERL_LIBS` is not consulted (§2b), so the release's `.app.src` `applications` key remains what actually decides the runtime.
5. **Improve what `bsc` prints at run time regardless**: `crashed: error:undef` drops the module and function that the Erlang stack carries (`{'Elixir.ExDep',shout,[<<"hi">>],[]}`). That is a one-line change and helps all three options.

If A is chosen: **name only, `app` only, one deduped `-bs_deps` attribute per module** (60-64 B) rather than a record per block (176-604 B), and use `where_is_file("<app>.app")`, never `lib_dir`.

**What would change this**

- If the clean-room handoff is defined as "`.bs` files plus the spec, no project file", Option A (keyword) wins on that ground alone; its measured cost is small.
- If any tool will read `bs_deps` (for example to generate `.app.src` `applications`), take Option B's single attribute. No neighbour tool I ran reads a custom beam attribute, so today there is no consumer.
- If a hex package ever ships a module the owner of which is another application, or two apps ship one module, ownership checks become load-bearing and A's check earns its keep.
- A version: add it only for a case name-only cannot express. One exists (a `using` signature written against `req` 0.5 compiles fine against 0.7 where an arity changed, then fails with `undef`); reading `vsn` is cheap (278 us). But it needs a constraint grammar, and nothing in the exemplars needs it yet. I did not add a version option to the prototype.

## 7. Limits

- hex.pm, GitHub and package.elm-lang.org are unreachable. **Req was not used**; the Elixir fixture is a tiny mix-built app (`exdep`), which has the same layout (`ebin/*.beam` plus `.app`) as `req`, but real hex packages with larger dependency trees (ticket 51 measured nine) were not exercised.
- **rebar3 is not installed**, so `rebar.config` / `.app.src` handling and `rebar_mix` are cited from ticket 51 only, not re-measured. Erlang's dependency record is probed only through `erlc`, `xref`, `dialyzer`, `application` and `systools`.
- **Elm** was not probed beyond the registry failure. **Elixir sources are not installed** (beams only), so the Elixir warning is cited from a run, not a file:line. Gleam is a binary: its citation is the run.
- A check at compile time can only speak for the compiling VM. Release (embedded mode) behaviour was probed with `erl -mode embedded` only for `lib_dir`, `which`, `ensure_loaded`, not by building a release.
- An escript archive or an OTP release with apps inside an `.ez` archive was not tested; `lib_dir` / `where_is_file` have archive code paths (`code_server.erl:843-870`) that were read but not run.
- The prototype threads the dependency list as a decl the parser returns and `bsc.erl` strips before the checker; it was not run through the repo's gates and it is not a proposal for how the code should be written. The prototype `bsc` was not run against the exemplar corpus, so I do not claim the grammar change is conflict-neutral beyond the yecc count (6 and 6).
- Timings: `m1`'s cold numbers measure one fixed call order per VM; the CLI wall times (`m4`) are too noisy to separate the check from boot, and the VM here is shared. `m3`'s 0.54 ms is the prototype's cost, mostly its own plumbing.
- The scratchpad `bsc` wrapper (`erl -run bsc main "$@"`) cannot accept a leading `--src-root` (erl consumes it); `probes/bsc.sh` forwards flags intact. That is a defect of the wrapper, not of the compiler, and I did not touch either.
