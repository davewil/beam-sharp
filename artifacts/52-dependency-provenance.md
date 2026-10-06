# Decision brief: ticket 52 (ENG-234), what a `.bs` file says about what it needs

Prepared 2026-10-05. Nothing in `compiler/`, `wayfinder/` or the docs was edited; no git, no Linear.
Probes: `artifacts/probes/52/` (`run.sh` re-executes all; raw output in `out/`; edits logged in `CHANGELOG.md`).
Prototype: `artifacts/probes/52/compiler-prototype.patch`, built only in a copy (`04-build-patched-bsc.sh`).
Every `Pnn` below is `probes/52/nn-*.sh`, output `probes/52/out/nn-*.txt`.
Environment: OTP 28, Elixir 1.19.5, gleam 1.18.1, elm 0.19.0, rebar3. hex.pm is blocked, so "Req 0.7.3" is replaced by a
local mix-built Elixir app `mylib` (modules `Elixir.MyLib`, `Elixir.MyLib.Request`) with the same on-disk shape.

## 0. What is already decided (grepped, so this brief does not call it open)

- **51** (resolved): no tool; `ERL_LIBS` is enough. It left provenance open and named the FFI declaration as the candidate.
- **50** (resolved 2026-08-26): a foreign struct is a `map<atom, term>`. **It added no syntax to the FFI declaration.** The ticket-52
  note "sequence it with 50 or two sessions extend the same construct" is stale; the only pending extension of the construct is
  **106** (resolved 2026-09-25, unbuilt, ENG-250): a per-entry alias `term GetOrCrash(binary url) = :'get!'`. A block-level
  marker composes with a per-entry alias (different grammar levels), but 106's grammar is not built, so that composition is untested.
- **32** decided "the declaration carries both spellings". What shipped is `using :ets { ... }` (`bs_parser.yrl:170`).
  32's `[external: erlang, "ets"]` attribute syntax was never built (P15).
- **41 §1**: `using` is one construct; "a file's `using` lines are its dependency list, in the file, checkable". For **native** `using`
  that is already enforced (P15: `using Shop.Nowhere` is `error: names no module and no namespace`, exit 1). For **foreign** `using`
  nothing is checked (P01).
- `scope.md` (cited by ticket 52) no longer exists (CLAUDE.md: cut 2026-09-05).

## 1. Sub-decisions the ticket implies

1. **Name only, or version too?** (ticket's own question)
2. **Where is it written:** on each foreign `using` block, once per module, or nowhere (existing `using` becomes checked)?
3. **Is it required** on OTP modules (`:erlang` is in `erts`, `:ets` in `stdlib`) or only where an author chooses?
4. **What does `bsc` do with it:** (a) refuse at compile time, warn, or ignore; (b) *what* is verified (app directory exists /
   module found / module found inside the declared app); (c) emit it into the `.beam`?
5. **Severity vs. who compiles:** a hard error blocks every machine that only type-checks (the clean-room fleet, a docs gate).
6. **Who reads the emitted attribute** (if anyone), and is emission part of this decision or a later one?
7. **Grammar:** `[ ... ]` as a declaration prefix does not exist today (P15). A marker needs a new production either way.

## 2. Executed facts

**F1. Today the compiler checks nothing about a foreign module, and the failure is lazy.** (P01)
`bsc -o O Pure` with `ERL_LIBS` unset: `[exit=0]`, no output. `bsc ... Pure Make` (touches the dependency): `crashed: error:undef`, exit 1.
`bsc ... Pure Two` (does not touch it): `2`, exit 0. A different `ERL_LIBS` (OTP-style apps only) gives the same `undef`. Missing function
(`MyLib.nope/0`, module present), missing module (`Elixir.NoSuchLib`) and missing app give **the identical text** `crashed: error:undef`.
**Ticket claim partly refuted:** "Compile it ... fails at the call site" is wrong for compile: compile succeeds silently; only *running the
call* fails. `ERL_LIBS` is honoured by the escript (B: `{__struct__ = :'Elixir.MyLib.Request', method = :get, opts = []}`), reproducing 51's mechanism.
The `.beam` already carries the called **modules**: `imports=[{'Elixir.MyLib',new,1},...]`; its attributes hold only `vsn`.

**F2. "One line" is true only of a weak check.** (P02, escript, three `ERL_LIBS` values; `kernel/src/code_server.erl:1035-1038`,
`:642-651`, `:126-150`.) `code:lib_dir(App)` is a lookup in a name table keyed by *directory basename*; it never reads a `.app`.

| target | `code:which(Mod)` | `code:lib_dir(App)` | `.app` found | `application:load(App)` |
|---|---|---|---|---|
| mix-built Elixir dep, `ERL_LIBS` set | `mylib/ebin/Elixir.MyLib.beam` | `.../mylib` | yes | `ok ; "0.3.1"` |
| same, `ERL_LIBS` unset | `non_existing` | `bad_name` | none | `{error,no such file or directory: mylib.app}` |
| OTP `crypto` (not loaded at boot), `ERL_LIBS` unset | found | `crypto-5.8.3` | yes | `ok` |
| `.app` file only, no beam (`ghost`) | `non_existing` | **`ghost-1.0.0` (present)** | yes | `ok ; "1.0.0"` |
| loose beam via `-pa`, no `.app` (`loose`) | found | **`loose` (present)** | none | `{error,...loose.app}` |
| absent | `non_existing` | `bad_name` | none | `{error,...}` |

So `lib_dir` calls a `.app`-less directory and a beam-less app "present"; `code:which` answers a different question (module);
`application:load` is the `.app` test but has side effects and is ~70x dearer (F9). `application:get_application(Mod)` (module to app)
is `undefined` until the app is loaded (`mylib`, `crypto`, `elixir` before `application:load`), so it cannot derive the app at compile time.
(An OTP preloaded module: `erlang` maps to `erts` only after `application:load(erts)`; P17.)

**F3. The version has two homes that can disagree, and the pick among several is the code server's.** (P03)
Dir `mylib-9.9.9` holding a `.app` with `vsn "0.3.1"`: `lib_dir=.../mylib-9.9.9`, `application vsn=0.3.1`.
`mylib-0.3.1` beside `mylib-0.10.0`: `lib_dir=.../mylib-0.10.0` (numeric-aware, not lexicographic). Two `ERL_LIBS` entries: the first listed wins
(0.3.1 first loads 0.3.1; reversed loads 0.10.0). **Ticket-52 premise not refuted but also not supported:** in the installed toolchain **40 of 40**
`.app` `vsn` values are dotted-numeric. I could not sample Hex pre-release forms (blocked), so "versions are too irregular to compare" is unmeasured.

**F4. The app cannot be derived from the module atom.** (P14, all 40 installed `.app` files) Rule "app = snake_case(first segment after `Elixir.`)":
**42.2%** of 412 Elixir modules; for Erlang modules (`app = module`) **2.0%** of 1314. The most-used app, `elixir` (`Enum`, `String`, `Access`), has **no** module that derives.
A hex app whose first module segment is its name (`Req`, `Jason`) derives; this is convention, not law.

**F5. If every `using` had to carry an app, authors would write `erts` for `:erlang`.** (P17) `erlang`: `undefined` until `erts` is loaded, then `{ok,erts}`;
`ets`, `lists`, `maps`, `binary`, `string`, `gen_server`, `json` are `stdlib`; `file` is `kernel`. Repo corpus (`.bs` under `compiler/examples`
and `wayfinder/prototypes`): `:erlang` x10, `:maps` x4, `:gen_server` x2, others x1.

**F6. A prototype makes the failure a compile-time diagnostic.** (P05, `compiler-prototype.patch`) Marker `[app: mylib] using :'Elixir.MyLib' {...}`, `ERL_LIBS` unset:
```
ShopA/shop.bs:3:1: error: application `mylib` is declared here and is not on the code path
  (declared for `:'Elixir.MyLib'`; no `mylib` or `mylib-<version>` directory with an ebin
  was found in the code path or in ERL_LIBS)
[exit=1]
```
With `ERL_LIBS` correct, ShopA/ShopB/ShopC all run and print `:get`. A typo `[app: mylb]` is refused (module reachable, call would have worked).
**The cheap check (`lib_dir`) accepts a wrong app:** `[app: stdlib] using :'Elixir.MyLib'` compiles and runs (`:get`, exit 0). A "strong" check (module found,
and its path inside `lib_dir(App)`) refuses it. **Per-module marker, wrong app, dependency absent:** `[app: stdlib] module ShopBLie` compiles clean even under
the strong flag and then `crashed: error:undef`, because a module-level marker names no module to verify against (prototype lines: `_ when RM =:= module -> ok`).
My expectation that per-`using` would print one diagnostic per marker was **refuted**: the checker raises on the first, so ShopA (2 markers) and ShopB (1) each print one.
Whether a real implementation reports all is a choice, not a measurement. `bsc --api ShopA` with `ERL_LIBS` unset prints `module ShopA / atom Verb()`, exit 0:
the prototype's check sits in `check_dir1`, which `--api` does not enter.

**F7. A module-presence check with no marker (variant C) is cheap but refuses spec material.** (P07; hook `BS_PROTO_CHECK_MODULES`) Corpus atoms not loadable
in a plain VM: `analytics_db`, `epgsql`, `Elixir.Application/Enum/Req/String`. All 21 `compiler/examples/*` modules still compile with the hook (they use only OTP modules), so
**my expectation that C breaks shipped examples was refuted.** It does displace the diagnostic LANGUAGE.md's gated block expects: the
`<!-- diagnoses: foreign_ret_beyond_one_guard -->` block with `using :analytics_db` yields `... a foreign return may promise only what one guard checks in O(1)` today and the
module-absent error under the hook, so `check-language.sh` would turn red. Epgsql (exemplar 25d, which does not compile today for other reasons) would be refused too.

**F8. Native `using` of a missing module is already an error; foreign is silent.** (P15) See section 0. This asymmetry is what C removes and A/B leave.

**F9. Costs measured.** (P06)
- Beam bytes, 10 `using` blocks over 4 apps (Req-shaped, stub bodies): none **1180** (repo bsc without patch also 1180), per-module `[app: req, finch, mint, jason]` **1312 (+132)**,
  per-using 10 markers **1580 (+400)**. Two usings / one app: 1144 / 1204 (+60, per-module) / 1244 (+100, per-using). Payload alone: 267 bytes (10 pairs) vs 32 (4 atoms) as `term_to_binary`;
  the rest is chunk and atom-table overhead. Scale: shipped example beams are 1632-3664 bytes, so +60..+400 bytes is roughly 2-25% of those. **My claim "tens of bytes, under 1%" was refuted.**
- Check cost inside one escript VM, 20000 calls, 540 path entries: `lib_dir` hit **2.9 us**, miss 1.7 us; `code:which` ~40 us hit or miss; `where_is_file` ~35 us;
  `application:load`+`unload` **213 us**.
- End to end, prototype `bsc` compiling the 10-using program, 40 alternating runs each: no markers median 685 ms (min 526, max 1104); 10 markers median 741 ms (min 549, max 1055).
  The 56 ms median gap is inside the 500 ms run-to-run spread and 10 checks cost ~30 us by the microbenchmark: **no measurable end-to-end difference**; I make no claim beyond that.
- Compiler work (prototype, `04`): parser +14 lines, **0 new yecc conflicts (6 s/r before, 6 after)**; checker +10/-1 core; emitter +4; diagnostics +8. About 36 core lines
  (the checker patch also carries 23 lines of probe-only hooks). Repo suite on the patched copy: 227 passed, 1 failed; **the same 1 fails on the unpatched copy**
  (`body_check_tests:every_aoc_program_still_compiles_test`; cause not investigated) (`recorded/16-prototype-suite.RUN_EUNIT.txt`).

**F10. Nothing in the BEAM toolchain reads a custom attribute; the toolchain already detects the missing module without it.** (P08)
- xref `undefined_function_calls` over the emitted beam, dependency not in scope: `[{{'ShopC','Verb',0},{'Elixir.MyLib',new,1}},{{'ShopC','Verb',0},{'Elixir.MyLib.Request',method,1}}]`;
  **identical** for the beam carrying `bs_requires` (ShopA). `xref_reader.erl:92` ignores every attribute but `xref` and `on_load` (`:86`, `:90`).
- dialyzer `-Wunknown`: `Unknown functions: 'Elixir.MyLib':new/1 (.../ShopC/shop.bs:16:42)` with a **`.bs` line and column**, same with or without the attribute.
- systools: a `.rel` listing `shopapp` builds (`make_script: ok`, the script never mentions `mylib`). With `mylib` in the `.app` `applications` the script mentions it (6 times);
  with it absent from the path, `{error,systools_make,[{error_reading,{mylib,{not_found,"mylib.app"}}},...]}` (`systools_make.erl:592`). It reads the `.app`, never the beam.
- rebar3 (P09, no source; behaviour only): `rebar3 compile` accepts an `applications` entry naming an absent app (exit 0) and a call into an unlisted app (exit 0). `rebar3 xref` warns
  `hostapp:go/0 calls undefined function Elixir.MyLib:new/1`. At run time: listed-but-absent is `{error,{mylib,{"no such file or directory","mylib.app"}}}` at **start**;
  called-but-unlisted starts fine and dies `{'EXIT',{undef,[{'Elixir.MyLib',new,[[]],[]}...`.
- Consumption by a script (P13): `bs_apps.escript`, **26 lines**, prints `declared (bs_requires): [mylib]`. The same tool can **infer** `[mylib]` from the beam's `imports` chunk via `code:which`
  only when the dependency is present; with it absent: `imported, no app inferable: ['Elixir.MyLib','Elixir.MyLib.Request']` and `inferred: []`.

**F11. Neighbour behaviour** is in section 3.

**F12. Ticket text I could not reproduce or found stale.** See section 7 (list).

## 3. Neighbour survey (real installed output; "no source" where none exists)

- **Erlang.** The `.app` `applications` key is the provenance (`systools_make.erl:592` reports a listed app it cannot read). Listed-but-absent fails at *start*, by name (P09 step 3: `{error,{mylib,{"no such file or directory","mylib.app"}}}`);
  unlisted-but-called fails at the *call* as `undef` (step 2). rebar3 compile cross-checks neither (P09, no rebar3 source installed: behaviour only); xref (`xref_reader.erl:86-93`) and dialyzer find the undefined remote without any declaration.
- **Elixir.** Provenance is the manifest, never the source file: `deps` plus `extra_applications`; the `.app` `applications` is inferred from them (P10: `{applications,[kernel,stdlib,elixir,mylib]}`;
  docs chunk of `Mix.Tasks.Compile.App`, doc lines 14-18 and 46-50: "By default, this list is automatically inferred from your dependencies"). **The compiler then enforces it at the call site:**
  with nothing declared, `MyLib.new/1 is undefined (module MyLib is not available or is yet to be defined)` and the same for `:ssl.versions/0`; declaring the path dep and `extra_applications: [:ssl]` makes both compile
  clean; declaring only the dep leaves the `:ssl` warning (P10 V1-V3). Run time: `Application.ensure_all_started(:nosuch)` is `{:error, {:nosuch, {~c"no such file or directory", ~c"nosuch.app"}}}`;
  `Code.ensure_compiled(NoSuch)` is `{:error, :nofile}`. No Elixir `.ex` source is installed; cited output only. It is a **warning**, not an error.
- **Gleam.** `@external(erlang, "Elixir.MyLib", "new")` names a module and no app; with the module nowhere, `gleam build` exits 0 and `gleam run` fails
  `A function was called but it did not exist. ... Elixir.MyLib.new unknown source` (P11 G1; generated `build/dev/erlang/gl1/ebin/gl1.app` has `{applications, []}`).
  Provenance lives in `gleam.toml`: `[erlang] extra_applications = ["mylib"]` makes the `.app` say `{applications, [mylib]}` and moves the failure to start-up, by name (`{error,{mylib,{"no such file or directory","mylib.app"}}}`) (G2).
  A `[dependencies]` entry could not be resolved here: `error: Dependency resolution failed ... https://repo.hex.pm/packages/gleam_stdlib` (G3, network). No Gleam compiler source installed.
- **Elm.** **Could not be run:** `elm make` stops at `HTTP PROBLEM ... https://package.elm-lang.org/all-packages ... Status {statusCode = 403 ...}` (P12) before reading `elm.json`'s `dependencies`. Elm's model (dependencies in `elm.json`, imports checked against them) is from memory and is not claimed as measured.

Pattern across the three that ran: **declaration at project level (manifest), not at the import**; only Mix turns a missing/undeclared dependency into a compile-time diagnostic, and it does it as a warning.
B# has no manifest of its own (51), so the source file is the only place a declaration can live.

## 4. Options

All three are programs that compile under one answer and not under another. Syntax `[app: x]` is a placeholder: the `[ ]` prefix is new either way (P15: `syntax error before: '['`).

### Option A: the app is named on each foreign `using`, optional, name only

```csharp
module Shop

[app: mylib] using :'Elixir.MyLib' {            // provenance next to the module it vouches for
    term new(list<(atom, term)> opts)
}
[app: mylib] using :'Elixir.MyLib.Request' {    // repeated: one block per module, one marker per block
    atom method(term r)
}
using :maps { term get(atom k, term m) }        // OTP: no marker, unchanged from today (the 14 corpus blocks cost nothing)

public atom Verb()
Verb() -> :'Elixir.MyLib.Request'.method(:'Elixir.MyLib'.new([]))
```
- Compiles with `mylib` on the path; with `ERL_LIBS` unset: `error: application mylib is declared here and is not on the code path` (F6), exit 1 (today: compiles, `undef` at run).
- `[app: stdlib] using :'Elixir.MyLib'` is refused **only** by the strong check (module found inside the declared app); the cheap `lib_dir` check lets it through (F6).
- **Compiler delta.** Grammar: `decl -> app_attr foreign_decl` (+14 lines, 0 conflicts). Symbol table: one entry `requires => [{App, Mod}]` on the checked-module map (bs_check.erl:93 `check_dir1`, returned beside `foreigns`).
  Pass: `requires_present`, per marker `code:lib_dir(App)` (2.9 us) and, for the strong form, `code:which(Mod)` (40 us). Emitted: optionally one `-bs_requires([{mylib,'Elixir.MyLib'},...])` attribute in `bs_emit:forms/1` (lines 73-78 region): **+100 bytes for 2 markers, +400 for 10** (F9). Diagnostic: one new tag in `bs_diag` (+8 lines).
- Evidence: F2, F6, F9, F10. Verified: typo caught; wrong app caught (strong). Not verified: reporting every marker rather than the first.
- **Strongest counterargument.** The marker is the same fact written once per block: a Req-shaped surface (10 blocks, 4 apps) carries 10 markers, and the reader pays for every one while the author's write cost is the near-free side
  of the standing constraint. It also introduces the first `[ ]` declaration prefix, which two decided tickets (32's `[external]`, 50's `[external] record`) once proposed and neither built.

### Option B: the apps are named once on the module, name only

```csharp
[app: mylib] module Shop                          // one line; may list several: [app: req, jason]

using :'Elixir.MyLib' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.MyLib.Request' {
    atom method(term r)
}
using :maps { term get(atom k, term m) }

public atom Verb()
Verb() -> :'Elixir.MyLib.Request'.method(:'Elixir.MyLib'.new([]))
```
- Same compile/diagnostic as A for the absent app. **Differs:** `[app: stdlib] module ShopBLie` over the same usings **compiles with the dependency absent, even under the strong flag**, and dies `crashed: error:undef` (F6): there is no module to check the app against.
- **Compiler delta.** Same grammar (+14, 0 conflicts) with `app_attr module_decl`; same pass but one check per listed app (no per-module work); attribute `[{mylib, module}]` or just `[mylib]`: **+132 bytes for 4 apps, +60 for 1** (F9; payload 32 bytes).
- Evidence: F6, F9. It is the closest to Erlang/Mix/Gleam, which all list applications per project and never per import (section 3), and `bs_apps.escript` consumes it with no change.
- **Strongest counterargument.** The list is tied to nothing in the module, so it can be wrong or stale and the compiler cannot say so. Mix needs a compile-time *call-site* tracer to stop its manifest drifting; here the check would have to be
  the call-site one (does each foreign module's directory belong to a listed app?), which is Option A's strong check run from a different place. B without it is a promise nobody checks, the exact thing ticket 32 refused for FFI.

### Option C: no marker; the existing foreign `using` becomes checked (module must be loadable)

```csharp
module Shop

using :'Elixir.MyLib' {                          // no change to source at all
    term new(list<(atom, term)> opts)
}
...
```
- Refused with `ERL_LIBS` unset (prototype hook), accepted with it. **Also refused**, which today is accepted: the LANGUAGE.md block `using :analytics_db { map<string, term> latest_row(binary site) }` (its gate wants `foreign_ret_beyond_one_guard`;
  it would get the module-absent error instead), and exemplar 25d's `using :epgsql` (F7). All 21 `compiler/examples` still compile (F7).
- **Compiler delta.** No grammar. One pass: `code:which(Mod)` per foreign `using` (40 us each). No attribute (the `imports` chunk already lists the modules, F1). A ~9-line hook in the prototype. Needs an opt-out for fictional modules
  (spec blocks, a type-check-only run), and that opt-out is a marker again.
- **Strongest counterargument.** It records nothing in the source, which is the ticket's stated argument (a stranger given only `.bs` cannot learn what to install; F4: neither `Elixir.Enum` nor `:erlang` derives its app from the atom). It is also the
  only option that turns programs the repo already ships as valid into errors, and a fleet that only type-checks cannot run it without the dependencies installed.

## 5. Recommendation

**Option A, name only, optional on OTP modules, with the strong check (module found inside the declared app) as a compile error; emission of the attribute is a second, separable step.**

Reasons, each from a measurement above:
1. The check is the cheap, certain part: ~3 us per marker, no measurable end-to-end cost (F9), and it turns `crashed: error:undef` into a line-numbered diagnostic (F1, F6).
2. Only A can verify **module belongs to app**. B compiles a wrong app clean and dies `undef` (F6); the cheap `lib_dir` check alone is also fooled (F2, F6). That mismatch is the one this feature exists to catch.
3. Name only: the `.app` `vsn` and the directory name can disagree (F3) and the ticket's own boundary says version selection is resolution; no evidence here argues for crossing it.
4. The marker must be optional on OTP: authors cannot guess `erts` for `:erlang` (F5) and 14 corpus blocks would carry no information.
5. Emission: no tool reads the attribute (F10: xref, dialyzer, systools, rebar3 all ignore it) and the beam already lists modules via `imports` (F1). It earns its +100..+400 bytes only if a consumer
   (an `applications` generator, 26 lines, F10) is wanted; deferring it loses nothing the check does not already give. This is the one part of the recommendation I hold loosely.

What this does **not** settle: Option A's marker spelling (`[app: x]` is a placeholder) and whether the check is an error or a warning (Mix warns; Gleam and rebar3 do nothing; native `using` errors, F8). It is also silent on Hex package name vs app name (not measurable offline).

## 6. Prototype commands

`cd artifacts/probes/52 && ./run.sh` (about 6 minutes, dominated by the dialyzer PLT in P08; `RUN_EUNIT=1` adds ~6 minutes more). Everything else, including the patched `bsc`, is built under
`/tmp/claude-0/.../scratchpad/p52work`; the repo's `compiler/` is read, never written.

## 7. What I could not verify, and ticket statements refuted or not reproduced

Refuted or stale:
1. "Compile it ... fails at the call site with `error:undef`": compile exits 0 silently; only running the call fails (F1).
2. "`[external: elixir, app: req] using ...`": `[` as a declaration prefix is a syntax error today; `[external: ...]` was never built (P15). The shipped form is `using :'Elixir.X' { ... }`.
3. "Checking the app is on the code path is one line": one call, but `lib_dir` answers directory-basename presence, not application presence or module membership (F2).
4. "Sequence it with ticket 50": 50 resolved with no extension to the FFI declaration; the pending one is 106's alias (section 0).
5. "`scope.md`" no longer exists (CLAUDE.md).
6. LANGUAGE.md §11's `using :"Elixir.Enum"` (double quotes): `syntax error before: ':'` (P15); the single-quoted form works and is what 50a/51a use. (Aside, not this ticket's question.)
7. My own expectations refuted: "attribute costs under 1%" (F9: 11-34% of a 1.2 KB stub); "per-using prints one diagnostic per marker" (F6); "C breaks shipped examples" (F7: only spec blocks and exemplars).

Could not verify:
- **Req 0.7.3 itself** (51's measurement): hex.pm is blocked; a local mix-built app stands in. The `ERL_LIBS` mechanism reproduces, the specific nine-package tree does not.
- **Elm** in full (P12: network). **Gleam `[dependencies]`** resolution (P11 G3: network). No Elixir `.ex`, Gleam or Elm compiler source is installed; those are cited by output only.
- **rebar3 behaviour beyond what ran** (no source): whether `rebar3 release`/`relx` consume `applications` the way systools does was not run; systools is the stand-in.
- **mix / rebar3 reading `-bs_requires`**: not run directly (absence is not provable by a probe); xref, dialyzer and systools do not read it (P08), and Mix's documented inference reads `deps`.
- **Hex pre-release version strings** (F3): only the installed 40 `.app` files were sampled.
- **Embedded-mode releases** (fixed code path at boot), **Windows `ERL_LIBS` separator**, **archive (.ez) application layout**: not probed.
- Whether a real checker should report every marker (prototype stops at the first), and the error-vs-warning choice (a design decision, not a measurement).
- Timing noise: the end-to-end bsc comparison has a ~500 ms spread, so it can only rule out a large cost, not measure a small one.

## Verification errata (independent verifier, `probes/52/VERIFICATION.md`)

The verifier re-ran all 18 probes from a fresh copy; F1–F10 and the neighbour survey reproduce. Corrections to the text above — **read these before relying on the recommendation**:

1. **Option B's "a wrong app compiles clean" is an artefact of the prototype, not of the option.** The patch has `_ when RM =:= module -> ok;`, so a module-level marker is never checked against anything. A 7-line change that checks each foreign `using` module against the listed apps refuses `[app: stdlib] module ShopBLie` and still passes the correct `ShopB`. So **B can catch the wrong-app case**, and the claim "only A can verify module-belongs-to-app" (recommendation reason 2, finding F6) describes the prototype. A's real advantage over B is locality (the marker sits beside the block it describes), not checkability.
2. **F9 timings are stale.** The final `out/06` gives end-to-end medians 800.9 / 766.2 ms and `lib_dir` 5.5 / 8.2 µs (about 41× vs `application:load`), not 685 / 741 ms, 2.9 / 1.7 µs and about 70×. "No measurable end-to-end difference" still holds (verifier's own medians 731.7 vs 838.9 ms inside a 500–700 ms spread); it only rules out a large cost.
3. **"14 corpus blocks" is unsupported.** `out/17` shows `:erlang` ×10 and about 22 OTP blocks in total.
4. **"About 36 core compiler lines" for A excludes the strong check** (module-found-in-app), which exists only as probe hook code; the recommendation needs it, so A's cost is understated.
5. The strong-check diagnostic prints "no `stdlib` directory was found" when `stdlib` exists (wording bug in the prototype).
6. Probe 16 (eunit) was not re-run by the verifier; only the author's 227 pass / 1 fail (same on unpatched) is on file, and the cause of the one failure was not investigated.
7. Mutation checks held: neutralising the `lib_dir` check makes the module compile then die with `undef`; the unpatched compiler rejects `[app:]`; removing the dependency from the Mix consumer restores its warning.
