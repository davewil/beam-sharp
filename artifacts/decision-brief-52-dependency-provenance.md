# Decision brief: ticket 52, dependency provenance

Ticket 52 ([ENG-234](https://linear.app/davewil/issue/ENG-234)) · 2026-10-29 · **DECISION OPEN — for human review**

Probes: `/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/52/`
Copy: `/home/user/beam-sharp/artifacts/probes-52/`

## 1. What is actually being asked

Ordered, gating question first. The ones after it only exist under some answers to it.

1. **Does a `.bs` file record which application it needs at all, and if so where?** (gating)
2. If yes: **name only, or name plus version?**
3. If yes: **what does `bsc` do with it** (nothing, warn, refuse)?

Two facts about the repo that change how the ticket reads:

- **The ticket's sketch syntax is not shipped syntax.** `[external: elixir, app: req] using :'Elixir.Req' { … }`
  has no attribute prefix to extend. The shipped production is `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'`
  (`compiler/src/bs_parser.yrl:170`, RECORDED, not re-run). `[external: …]` was ticket 32's spelling of a `module`
  declaration that LANGUAGE.md §11 (`using :ets { … }`) superseded. `external: elixir` is also redundant: the `Elixir.`
  prefix already says it. Any option below is therefore new grammar, and I have not checked the spellings against the lexer's keywords.
- **LANGUAGE.md:157 already says "a file's `using` lines are its dependency list."** That is true for B# modules
  (the compiler resolves them to source, :179) and only half true for foreign ones, which name a module atom and
  nothing a stranger could install.
- **`bsc` emits no `.app` file** (`grep applications\|\.app compiler/src/*.erl` outside bs_check: no hits). A name in
  the source therefore has no consumer today except `bsc` itself, or a `.beam` attribute (see Option C delta).

## 2. Evidence

All rows MEASURED-HERE (OTP 25, Elixir 1.14.0, Gleam 1.12.0, rebar3 3.19) unless marked. `bsc` could not be built here, so
nothing below says what `bsc` does today beyond the RECORDED rows.

| # | Probe | Claim | Result |
|---|---|---|---|
| 1 | `p1_missing.erl` `p1_out.txt` | Ticket premise: a missing dep surfaces as `error:undef` that names no application | **Confirmed.** `{undef,[{'Elixir.Req',new,[[]],[]}…]}` is the whole message. `code:which` → `non_existing`; `code:ensure_loaded` → `{error,nofile}`; `code:lib_dir(req)` → `{error,bad_name}`; `application:load(req)` → `{error,{"no such file or directory","req.app"}}` |
| 1b | same | A fake app whose `.app` lists a ghost dep | `application:load(fakeapp)` → `ok`; `ensure_all_started(fakeapp)` → `{error,{ghostdep,{"no such file or directory","ghostdep.app"}}}`. Control (ghost removed, app unloaded first): `{ok,[fakeapp]}`. Cite `kernel/src/application.erl:141-166`. An earlier run of the control failed because `application:load` caches the old spec; I added `unload` and said so |
| 2a | `p2_erlang/proj` `p2_rebar3_out.txt` | Does Erlang tooling check provenance at compile time? | `rebar3 compile` exit 0 for a call to a nonexistent `'Elixir.Req':new/1`. `rebar3 xref` flags that module (exit 1) and does **not** flag `ssl:start()` from an app absent from `applications`. xref checks module existence, not app declaration |
| 2b | `p2_erlang/rel` `p2_systools_out.txt` | Where is `.app` `applications` enforced? | Release build only: `systools:make_script` → `{error,systools_make,{undefined_applications,[ghostdep]}}`; control with all apps present: `{ok,…}`. Cite `sasl/src/systools_make.erl:813-817,1357`. Never at compile of a `.erl` |
| 2c | `p2_elixir/run.sh` `p2_run_sh_out.txt` | What does Mix do? | **Does exactly the ticket's idea, as a warning (exit 0).** Module found on the path, app not in deps/`extra_applications`: `Widget.Thing.new/1 defined in application :widget_core is used by the current application but the current application does not depend on :widget_core`. Module not found anywhere: a different, weaker warning (`Ghost.Nothing.f/0 is undefined (module … is not available or is yet to be defined)`). Control: `extra_applications: [:logger,:ssl]` removes the `:ssl` warning. Mix Elixir sources are not installed: behavioural only |
| 2d | same | Is Mix's check stable? | **No, in this version.** Reusing one `_build` for identical inputs changed the output (case C2: `:ssl` warned although declared). `run.sh` therefore deletes `_build` per case. Inference only: Mix reads a cached app spec |
| 2e | same | `Mix.Task.run` (module in app `mix`, not declared) | Produced **no** warning. Unexplained; I did not chase it |
| 2f | `p2_gleam` `p2_gleam_out.txt` | Gleam | `import widget` with no `[dependencies]` entry: **hard error** `Unknown module`. Path dep `widget = { path = "../widget" }`: builds. `@external(erlang,"ghost_mod","f")`: **compiles, no check**, runtime `undef`. So Gleam's FFI is exactly today's `using :atom {…}`: unchecked. gleam.toml holds name and version/path; stdlib sources not installed, behavioural |
| 3a | `p3/p3_map.erl` `p3_out.txt` | Ticket premise: Elixir module name ≠ application name | **Confirmed, and no prefix rule recovers it.** `Elixir.Kernel`, `Elixir.Enum` → app `elixir`; `Elixir.Mix.Task`, `Elixir.Mix.Tasks.Compile` → `mix`; `Elixir.Logger` → `logger`; `Elixir.ExUnit.Case` → `ex_unit`; `Elixir.EEx.Engine` → `eex`. Erlang too: `OTP-PUB-KEY` → `public_key`. **Req and Jason are not installed and the proxy blocks hex, so the ticket's `Elixir.Req` → `req` example was NOT tested.** I built `Widget.Thing` in app `widget_core` to get a real mismatch (2c) |
| 3b | `p3/p3_map.erl` | `application:get_application/1` | Returns `undefined` for every module of an app that is not loaded (all Elixir rows, `ssl`); only `{ok,stdlib}` for the already-running app. Useless at compile time |
| 3c | `p3b_escript_out.txt` | Module embedded in an escript | `code:which(emb)` = `…/emb.es/emb.beam`; `lib_dir(emb)` → `{error,bad_name}`; `get_application` → `undefined`. **`bsc` is itself an escript**, so any module bundled into it is un-mappable |
| 3d | `p3c_out.txt` `p3d_two_roots.txt` | Module in two apps | Path parse names whichever sits first on the path: `appb` for `dup` in `libs/`; flipping which `ERL_LIBS` root comes first flips the answer (`rootA`→`appa`, `rootB`→`appb`). Scanning `.app` files instead returns `[appa,appb]`: ambiguity is visible, not decided |
| 3e | same | Beam with no `.app`; beam not listed in its `.app` | Path parse invents an app name from the directory (`orphan`, `liar`). `.app` scan returns `[]` for both |
| 3f | `p3/p3_map.erl` | Preloaded modules | `erlang`, `init`, `prim_file`: `code:which` → `preloaded`, no path. Only the `.app` scan answers (`erlang` → `[erts]`) |
| 3g | `p3e_dirname_vs_appname.txt` | `code:lib_dir/1` key | Keyed on **directory name**, not `.app` name: dir `dirname` holding `realname.app` → `lib_dir(realname)` = `{error,bad_name}` while `application:load(realname)` = `ok`. Cite `kernel/src/code_server.erl:1015`. mix and rebar3 name dirs after the app, so this bites only hand-laid trees |
| 4 | `p4/p4_cost.erl` `p4_out.txt` (rerun in `p4_out_rerun.txt`) | Cost on a 44-entry path, min of 7×200 runs | `code:lib_dir(App)`: **1.5-1.9 µs**. `code:which(Mod)` unloaded, present or missing: **1.5-1.7 ms** (scans the path every call). `code:where_is_file("req.app")`: 0.34 ms present, 1.7 ms missing. One `file:consult` of an `.app`: 0.35 ms. Full `.app` scan: **13-16 ms**. Noise: medians run up to 30% over the minimum on a 4-core shared box. All are free next to a compile |
| 4b | `p4/p4b.erl` `p4b_out.txt` | Cost of carrying the names into the `.beam` as `-bs_requires([{req,'Elixir.Req'}])` | 668 → 720 bytes for one entry, 772 for three (about 52 bytes each); readable through `beam_lib:chunks(…,[attributes])` and `module_info(attributes)`. Hand-written Erlang attribute, not what `bsc` would emit |
| R1 | RECORDED `wayfinder/issues/51-…md` (Answer) | `ERL_LIBS` alone reaches Req 0.7.3 with no compiler change; `ensure_all_started(:req)` brought up 16 apps | **Not re-run** (no Req, no network) |
| R2 | RECORDED `wayfinder/issues/50-…md` | A record-typed foreign return type-checks and then `function_clause`s at run time | **Not re-run** (no `bsc`). Relevant because a missing dep and a wrong declaration are both "accepted, then crash" |

**What the evidence changes about the ticket's premises**

- "Checking the application is on the code path is one line": **partly.** `code:lib_dir(App)` is one line and 2 µs but is
  keyed on directory name (3g). The form that matches the `.app` name is `code:where_is_file("<app>.app")` (0.3-1.7 ms).
- "Name is checkable, version is resolution": **supported.** The only version the BEAM exposes is the `.app` `vsn`
  string (read in 0.35 ms); comparing it to a range is a semver parser, which is resolution-shaped.
- **The check the ticket wants (does the app that owns this module match the declared `app:`) is unsound** in four measured
  cases: preloaded (3f), escript-embedded (3c), duplicate (3d), no-`.app` or unlisted (3e). **The check "the module is
  present" is sound** in all of them, because it asks the question the call asks.
- **Neighbours split name from version.** Erlang: `applications` (names) in `.app.src`, versions in `rebar.config`.
  Elixir: `extra_applications` (names) vs `deps` (names and versions). Gleam: one `[dependencies]` table with ranges.
  None records the application *per foreign call site*. They all record it once per project.
- **Mix compares a module's discovered app with the project's declared deps.** B# has no manifest (ticket 51), so the
  right-hand side of that comparison exists only if the source carries it.

## 3. Options

Written as B# programs. The `using` spellings are illustrative and unchecked against the lexer.

### Option A: nothing in the source; `bsc` checks only the module

```csharp
module Shop.Fetch

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' {
    term put_header(term req, binary k, binary v)
}

public term Build(binary token)
Build(token) -> :'Elixir.Req.Request'.put_header(:'Elixir.Req'.new([]), "authorization", token)
```

Compiles today. With a check, on a machine where `Elixir.Req` is absent:
`warning: foreign module 'Elixir.Req' (line 3) is not on the code path`.

**Compiler delta:** one pass over `{foreign, _, Mod, _}` decls (the shape `bs_check.erl:620` already walks): `code:which(Mod) =:= non_existing` → diagnostic.
No grammar, no symbol-table entry, no emitted code. ~1.7 ms per distinct module.

**Evidence:** 1, 3c (sound in every failure case). **Cost:** a new diagnostic class and a decision whether it is an error
(breaks compiling on a machine without the dep) or a warning (what Mix does, 2c).

**Strongest counterargument:** it does not answer the ticket's own argument. The file still does not say *which
application* provides `Elixir.Req.Request`; a stranger gets "module not found" and must guess `req`. The handoff
property (the source alone says what to install) is not delivered. It also can never say more than "absent".

### Option B: the application on each foreign block

```csharp
module Shop.Fetch

using :'Elixir.Req' in req {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' in req {
    term put_header(term req, binary k, binary v)
}
using :lists {                       // OTP: stdlib is implied, no application written
    int sum(list<int> xs)
}

public term Build(binary token)
Build(token) -> :'Elixir.Req.Request'.put_header(:'Elixir.Req'.new([]), "authorization", token)
```

Refused: `using :'Elixir.Req' in reqq { … }` when `reqq.app` is not found: `application 'reqq' (named at line 3) not found`.

**Compiler delta:** grammar `foreign_decl -> 'using' atom_lit 'in' atom_lit '{' …` (an optional third element of the
`{foreign, Line, Mod, Sigs}` tuple, which `bs_check.erl:620,638,1076,1114` all pattern-match, so each needs touching);
a pass doing `code:where_is_file("req.app")` per distinct app (0.34-1.7 ms); optional emission of the pairs as a
`-bs_requires` attribute (52 bytes each, row 4b). Do **not** add an ownership check ("module belongs to app"): 3c-3f
show it would be wrong or ambiguous in four real layouts.

**Strongest counterargument:** repetition, and the repetition can disagree. Two blocks on one application means two
`in req`, and nothing stops `in req` on one and `in reqq` on the other, which the compiler cannot call wrong because
the ownership check is unsound. The ticket already priced this write cost as near-free, but the reader pays it
(`Req`, `Req.Request`, `Req.Response` is three). It also cannot detect a stale entry: delete the last call to Req and
the `in req` stays, since "unused dependency" needs module-to-app mapping.

### Option C: once per module, a line of its own

```csharp
module Shop.Fetch

requires req                          // name only; no version, no range
requires jason

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' {
    term put_header(term req, binary k, binary v)
}
```

`index.bs` already holds the directory's shared `using` lines (LANGUAGE.md:187), so a module directory states its needs
once in `index.bs`, and the per-file spelling is the exception.

Refused: `requires req` with no `req.app` on the path: `application 'req' not found (required at line 3)`.

**Compiler delta:** one new declaration `{requires, Line, App}` in the parser (like `using_decl`, `bs_parser.yrl:185`,
which already "introduces no name"); the same `where_is_file` pass, run per `requires`, not per block; an
optional module check as in A for each foreign module; the `-bs_requires` attribute (about 52 bytes per app, 4b)
so a release tool or a human reading the `.beam` sees the list. The foreign blocks are unchanged, so `bs_check`'s
pattern matches stay as they are. This is the only option that reads like Erlang's `applications` and Mix's
`extra_applications`.

**Strongest counterargument:** the `requires` line and the `using` blocks that need it can drift apart, and the
compiler cannot join them (the module-to-app mapping is unsound, 3c-3f). A reader at `using :'Elixir.Req.Request'`
sees no app and scrolls up. A new keyword is added to a language that has just removed machinery (CLAUDE.md, 2026-09-05).
A forgotten `requires` is not detected unless the module check from A is also run.

### Sub-decisions 2 and 3, under B or C

- **Name only vs version.** Every option above is name-only; a range is written nowhere and checked nowhere. Evidence for
  keeping it so is in section 2 ("changes about the premises"): the BEAM exposes one version string and neighbours keep
  ranges in their manifest. Whether David wants a version for the *handoff* is a judgement, not something I measured.
- **Error or warning.** Mix warns (2c) and exits 0; Gleam errors for `import` (2f) and says nothing for `@external`.
  A hard error makes `bsc` unusable on a machine that holds the source but not the dependencies, which is the fleet's
  situation until it builds them. I did not test what the fleet's environment looks like.

## 4. Recommendation

Option C, name only, with two diagnostics: **module absent** (from A, sound) and **application absent**, both warnings.
No ownership check. Emit the names as a `.beam` attribute only if a consumer exists; there is none today, so I would not
build that yet.

## 5. Limitations

- **`bsc` was not built here** (repo pins OTP 28; this box has OTP 25). Every statement about the compiler's present
  behaviour is RECORDED from repo files. I wrote no B# and ran no `bsc`; the B# above is design text. The delta
  sizes are read from `bs_check.erl` and `bs_parser.yrl`, not tried.
- **Req and Jason are not installed**, so the Req tree's `req.app`, its `applications` list and the premise's
  `Elixir.Req` → `req` mapping are only RECORDED from ticket 51. The mismatch evidence uses installed `mix`, `logger`,
  `elixir`, `ex_unit`, `eex` and my own `widget_core`.
- **Elm: not probed (not installed).** Gleam's hex resolution was not exercised (no network); path dependency only.
- **Elixir/Mix internals are behavioural**; no sources installed. The Mix cache-staleness in row 2d is observed, not explained.
- **OTP 25, not 28.** The code server behaviour cited (`code_server.erl:1015`) may differ in OTP 28.
- **Unproven:** how a clean-room fleet's environment is set up; whether `ERL_LIBS` exists at `bsc` compile time there;
  whether any consumer of a `-bs_requires` attribute would exist.

## 6. Probe index

From `/tmp/claude-0/-home-user-beam-sharp/e462f18b-47b0-5059-896d-359d243949c1/scratchpad/probes/52` (or `/home/user/beam-sharp/artifacts/probes-52`; `.beam` and `_build` are not kept):

```
erlc p1_missing.erl && erl -noshell -pa . -eval 'p1_missing:main(),halt().'
(cd p2_erlang/proj && rebar3 compile; rebar3 xref)
(cd p2_erlang/rel && erlc rel.erl && erl -noshell -eval 'rel:main(),halt().')
p2_elixir/run.sh
(cd p2_gleam/app && GLEAM=<gleam-bin>/gleam; $GLEAM build)       # cases A,B,C in p2_gleam/p2_gleam_out.txt; edit gleam.toml to toggle the dep
(cd p3 && erlc p3_map.erl && erl -noshell -pa . -eval 'p3_map:main(),halt().')
(cd p3 && ./mkfix.sh && escript es/emb.es)
(cd p3 && erlc p3c_fixtures.erl && ERL_LIBS=$PWD/libs:/usr/lib/elixir/lib erl -noshell -pa . -eval 'p3c_fixtures:main(),halt().')
(cd p3 && ERL_LIBS=$PWD/rootA:$PWD/rootB erl -noshell -eval 'io:format("~s~n",[code:which(dup)]),halt().')   # then swap
(cd p3 && ERL_LIBS=$PWD/renamed erl -noshell -eval 'io:format("~p ~p~n",[code:lib_dir(dirname),code:lib_dir(realname)]),halt().')
(cd p4 && erlc p4_cost.erl && erl -noshell -pa . -eval 'p4_cost:main(),halt().')
(cd p4 && erlc p4b.erl base.erl && erl -noshell -eval 'p4b:main(),halt().')
```
