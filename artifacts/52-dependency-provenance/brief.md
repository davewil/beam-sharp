# Decision brief — ticket 52 (ENG-234): does a `.bs` file record what it needs, and where?

Status: research for David. Nothing resolved, no ticket or compiler file touched. Labels: **MEASURED**
(probe run here, `probes/<file>` + captured `.out`), **SOURCE** (file:line of an installed/repo source),
**RECORDED** (a ticket/README says so; NOT re-run), **UNVERIFIED**. Gleam: **not probed**.
Environment: OTP 25.x, Elixir 1.14.0, Elm 0.19.1 (`probes/versions.out`). `bsc` cannot be built here
(needs OTP 28), so **no claim below is about what `bsc` does when run**; compiler deltas are read from source.

## Question

`using :'Elixir.Req' { … }` names a *module*. Nothing in the file names the *application* `req`, so a
machine with a different `ERL_LIBS` compiles it and fails at run time with `error:undef`. Does the
language record its dependencies, and where? Ticket 51 is closed (no tool) and is not re-opened.

## Two premises of the ticket that the repo contradicts

1. **The spelling `[external: elixir, app: req] using …` is not the language.** The shipped grammar has
   exactly `using atom_lit { foreign_sigs }` → `{foreign, Line, ModAtom, Sigs}` (SOURCE
   `compiler/src/bs_parser.yrl:165-166`); there is no attribute syntax anywhere in the grammar
   (SOURCE grep of `bs_parser.yrl`, no `[`-prefixed declaration production). 32's `[external: erlang, "ets"] module Ets`
   was superseded by LANGUAGE.md §11's `using :ets { }` (SOURCE `LANGUAGE.md:2741-2770`; RECORDED ticket 106 header).
2. **"Sequence with 50" is stale.** Ticket 50 resolved 2026-08-26 with *no declaration change* (a foreign
   struct is a `map<atom, term>`; shape 1's `[external] record` stays unbuilt) (RECORDED
   `wayfinder/issues/50-naming-a-foreign-struct.md:290-318`). The FFI-declaration extension that *did* land
   is 106's per-entry alias `term GetOrCrash(binary url) = :'get!'` (RECORDED `106-a-using-alias.md`, unbuilt,
   ENG-250). So (d) becomes: keep 52's addition off the *entry* line 106 is editing.

## Evidence

| # | Claim | Label | Source |
|---|---|---|---|
| E1 | `erlc` compiles a module calling an absent module with **no error and no warning**, also under `-Wall`; exit 0 | MEASURED | `p1_missing_module.out` |
| E2 | Run time: `error:undef`, top frame `{'Elixir.Req',new,[[{url,<<"x">>}]],[]}`. The caller `go/0` is **absent** from the stack (tail call) | MEASURED | `p1_missing_module.out` |
| E3 | `xref` sees the edge (`UM=['Elixir.Req']`, `undefined_function_calls=[{{caller,go,0},{'Elixir.Req',new,1}}]`) **only if the beam has `debug_info`**; without it every query returned `[]`. My first prediction (p1 xref section) was wrong for that reason; p1b re-ran with `+debug_info` | MEASURED | `p1_missing_module.out`, `p1b_xref.out` |
| E4 | Elixir 1.14: call to absent `Req.new/1` compiles (exit 0) with warning `Req.new/1 is undefined (module Req is not available or is yet to be defined)`; run time `function Req.new/1 is undefined (module Req is not available)` | MEASURED | `p2_elixir_missing.out` |
| E5 | Elixir: `%Req.Request{}` of an absent module is a **hard compile error** (exit 1); `import Req` also exit 1 (`module Req is not loaded and could not be found`) | MEASURED | `p2_elixir_missing.out` |
| E6 | `code:lib_dir(App)` answers "app on path?" with no loading: dir, or `{error,bad_name}`; works for versioned (`app_a-1.0`) and unversioned (`app_c`, Elixir's `lib/logger`) dirs and for an ebin with **no .app file** (`app_d`) | MEASURED | `p3_lookup.out`, `p6_real_elixir_and_cost.out` |
| E7 | It goes by **directory name**, not the .app name: `libE/foo-1.0/ebin/bar.app` → `lib_dir(foo)` ok, `lib_dir(bar)` bad_name, yet `application:load(bar)` = ok and `load(foo)` = error. The two APIs disagree | MEASURED | `p3_lookup.out`; SOURCE `kernel/src/code_server.erl:1015-1018` (`lookup_name`), `:609-618` (`get_name`) |
| E8 | `code:which(M)` = path or `non_existing`; finds a module in a **non-app dir** (`loose_mod`), but then no app can be derived (`{not_in_an_ebin,"loose"}`) | MEASURED | `p3_lookup.out` |
| E9 | Two apps ship module `shared`: `which` returns the first on the path; `ERL_LIBS=A:B` → app_a, `B:A` → app_b. A `.app` scan returns both (`[app_a,app_b]` / `[app_b,app_a]`). Module→app by path parse is order-dependent | MEASURED | `p3_lookup.out` |
| E10 | Module→app by path parse can be **wrong against the .app**: `e_mod` parses to `foo`, `.app` scan says `bar` | MEASURED | `p3_lookup.out` |
| E11 | `code:which` returns the *already-loaded* file first, and only otherwise walks the path | SOURCE | `kernel/src/code.erl:810-816` |
| E12 | `ERL_LIBS` is read by the code server at boot, so `bsc`'s compile-time view of the path is the process environment | SOURCE | `kernel/src/code_server.erl:103` |
| E13 | Cost, µs/call on a 44-entry path: `lib_dir` hit 2.5–3.0, miss 2.2; `which(lists)` (loaded) 5.3; `which` miss 708; `.app` scan of the whole path 8,500–9,000 (not worth it); `application:load` cold 417, warm 2.5; `ensure_loaded` of a beam 758. A 9-app `lib_dir` check: ~61 µs. `erlc` on a trivial module: 213–290 ms wall | MEASURED | `p3_lookup.out`, `p6_real_elixir_and_cost.out` (timings vary run to run) |
| E14 | Real `.app` files carry `applications` as **names only**: `ssl` → `[crypto,public_key,kernel,stdlib]`, `inets` → `[kernel,stdlib]`, `elixir` → `[kernel,stdlib,compiler]`, `logger` → `[kernel,stdlib,elixir]`; `vsn` is the app's own | MEASURED | `p4_appfiles.out` |
| E15 | OTP's `ssl.app` *also* has `runtime_dependencies, ["stdlib-4.1","public_key-1.11.3",…]` — versioned. Whether any OTP tool enforces it at run time: not probed | MEASURED (key exists) / UNVERIFIED (enforcement) | `p4_appfiles.out` |
| E16 | mix (throwaway project, path deps, offline): the generated `proj.app` has `applications=[kernel,stdlib,elixir,ssl,dep_run]` — the dep and `extra_applications` are **inferred/added automatically**; `only: :test` and `runtime: false` deps are **absent** | MEASURED | `p4_appfiles.out` |
| E17 | mix keeps the requirement `"~> 1.2"` in `mix.exs` only (0 matches in the `.app`); mix itself refuses the build when the dep is 0.9.0 (`the dependency does not match the requirement "~> 1.2", got "0.9.0"`) | MEASURED | `p4_appfiles.out` |
| E18 | Installed Elixir ships **no `.ex` source** (0 files), so `Mix.Tasks.Compile.App` cannot be cited by line. The installed beam defines `apps_from_runtime_prod_deps/2`, `runtime_app?/1`, `handle_extra_applications/2`, `language_apps/1` | MEASURED (function list only) | `p4b_mix_beam.out` |
| E19 | Elm: `elm init` needs the package registry; here it fails (`ProxyConnectException … 403`). Stopped there, no workaround. Nothing about elm.json is claimed | MEASURED (failure) | `p5_elm.out` |
| E20 | Gleam | not probed | — |
| E21 | Ticket 51: `ERL_LIBS` alone reaches Req 0.7.3; both neighbours emit one dir per app with an `ebin`; rebar_mix vendors `elixir` but not `eex` | RECORDED | `51-a-build-and-dependency-tool.md:69-133` |
| E22 | `bsc` today has no foreign-module presence check: the only `code:` uses in the compiler are `add_patha`/`ensure_loaded` of its own output and `bs_batch`'s path snapshot/cleanup | SOURCE | `compiler/src/bsc.erl:691-692`, `bs_run.erl:19-20`, `bs_batch.erl:170,202` |

## Sub-decisions (each gets its answer inside the options; the evidence is above)

- **(a) Name only, or name + version.** A name is checkable for ~3 µs (E6, E13). A version is *technically*
  cheap too (`application:load` + `get_key(vsn)`, ~0.4 ms cold, E13) but **not always present in the
  directory name** (E6: `app_c`, Elixir's own `lib/logger`), so it needs the `.app`, which E7 shows can
  disagree with the dir name. The `.app` `applications` list has no versions (E14); mix keeps them in
  `mix.exs` and enforces them itself (E17). The refusal of a version is therefore a **boundary** argument
  (resolution belongs to mix/rebar3), not a cost one; I did not find a measurement that forces it either way.
- **(b) Per block or once per module.** Real modules will draw several `using` blocks on one app
  (`'Elixir.Req'`, `'Elixir.Req.Request'` are both app `req`, and module→app is not derivable by name in
  general, E10). Per block repeats it; once per module states each app once.
- **(c) What the compiler does.** `code:lib_dir(App)` → diagnostic instead of `undef` (E6, E13). Nothing
  else measured is needed. The tool comparison: erlc says nothing (E1), Elixir warns for a call and errors for
  a struct/import (E4, E5), xref can find it but needs a second tool and `debug_info` (E3). So a bsc check would
  be **stronger than either neighbour's compiler**.
- **(d) Sequencing.** See the two premises above: 50 asks nothing of the declaration now; keep the new syntax
  off the entry line that 106 owns.

## Options

### Option A — no new syntax: check the *module* the `using` already names

```csharp
module Fetch

using :'Elixir.Req' {                       // unchanged from today
    term new(list<(atom, term)> opts)
}
```

Compiler delta: a pass after parse over `{foreign, _, Mod, _}` (the tuple `bs_check.erl:606` already
walks) calling `code:which(Mod)`; on `non_existing` emit a diagnostic through `bs_diag` naming the module
and `ERL_LIBS`. Zero grammar change, zero declaration bytes. Cost ~5 µs for a loaded module, **~708 µs for
a miss** (E13), tiny against a 200+ ms compile (E13).
Records nothing: the *app* is still not in the source, so the handoff still cannot say what to install
(the diagnostic can only name a module).

Strongest counterargument: it fixes the symptom, not the ticket's argument. A clean-room implementor is told
"module `Elixir.Req` not found" and must guess the app (E10: module name → app is not mechanical, and
the parse trick works only when the module is *present*, i.e. when no diagnostic is needed). It also makes
type-checking depend on the machine (LSP/`--check` on a box without deps would error; UNVERIFIED for
the LSP, no editor probe was run).

### Option B — name only, on each `using` block (the ticket's candidate, reworded to compile)

```csharp
[app: req] using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

[app: req] using :'Elixir.Req.Request' {
    term to_map(term r)
}
```

Compiler delta: (1) grammar: an attribute production before `using atom_lit {` — new, since no `[…]`
declaration prefix exists (SOURCE, premise 1); conflict count must be re-measured with `bs_parser.yrl`
(not done here: `bsc` unbuildable). (2) AST: `{foreign, Line, Mod, Sigs}` gains an app field. (3) a pass calling
`code:lib_dir(App)`; `{error,bad_name}` → diagnostic "application req is not on the code path" (~3 µs each,
E13). (4) Optionally `bs_emit` writes `-bs_requires([req])` into the beam so tooling can read the fact back
(UNVERIFIED that the emitter has an attribute hook; not read). Declaration cost: +11 bytes per block
(`probes/p6…out`: 21 → 32 bytes).

Strongest counterargument: **two sources of truth**. mix and rebar3 already record the app list (E16: mix
*infers* it from `deps`), so `[app: req]` restates `mix.exs`/`rebar.config` inside every block and the two can
drift; and the repeat is exactly the write-cost the ticket flags. It is also one more construct on the line
106 is adding an alias to.

### Option C — name only, once per module, in the header

```csharp
module Fetch
requires :req, :jason;                      // spelling illustrative; a module-level list

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' {
    term to_map(term r)
}
```

Compiler delta: (1) one header production after `module`, AST `{module_decl, …}` gains `requires` (the
`using` tuple is untouched, so no interaction with 106's entry alias); (2) the same `code:lib_dir` pass as B,
run once per name; (3) optional second pass, **only when the module resolves**: `which(Mod)` + path parse
must land in a declared app, else "undeclared dependency `req`" (E10 shows the parse can be wrong when
`.app` name ≠ dir name, E9 that it is order-dependent — so I would make it a *warning* or skip it).
Spec-visible in one line at the top of the file. Declaration cost: one line, 14 bytes per app, once.

Strongest counterargument: the fact is far from the `using` that needs it, and the declaration can go
stale in the other direction — an app listed that no block uses passes silently unless the optional pass
runs. It has the same two-sources-of-truth problem as B (E16), and adds a header construct the language does
not have.

## Recommendation

**Option C, name only, with the single check `code:lib_dir(App)` as an error, and no version.** Reasons from
the evidence: a name is ~3 µs to check and the check beats both neighbours' compilers (E1, E4, E5); a
version has no cheap uniform source (E6/E7/E14) and its enforcement is already mix's (E17); once-per-module
keeps the entry line free for 106 (premise 2) and avoids repeating an app that several `using` blocks share
(E10). Take Option A's `code:which` check *as well* if you want a message for a module missing from a declared
app, but do not rely on it for provenance. If you judge two sources of truth (E16) to be the real cost, the
honest alternative is **A alone**, plus a spec sentence that the handoff ships the `mix.exs`/`rebar.config` —
which is what the neighbours do, and it moves nothing into the language.

## What I could not verify here

- **`bsc` was never run.** Every compiler delta is read from source (`bs_parser.yrl:165`, `bs_check.erl:606`,
  `bs_batch.erl`), not exercised. The parse-conflict count for a new attribute or header production is
  unmeasured; whether `bs_emit` can write a module attribute is unread.
- **OTP 25, not 28.** Probes ran on OTP 25.x / Elixir 1.14.0 (built for OTP 24). `code:lib_dir`/`which` semantics
  may differ in OTP 28; I have no evidence either way. Timings are one sandbox VM, single runs; the
  order of magnitude, not the digits, is the finding.
- **Gleam: not probed.** **Elm: only that `elm init` cannot fetch offline** (E19); its `elm.json` is unexamined.
- **mix source not cited by line** (E18): the apt Elixir has no `.ex` files; E16/E17 are behaviour of a
  throwaway project with `path:` deps, not hex deps, and `mix.lock` was not exercised.
- **Real Req tree absent** (`req.app` not on this machine), so the Req-specific cases (E10's `Elixir.Req` →
  `req`, the sixteen-app start-up) rest on ticket 51 (RECORDED), not on a run here.
- **Application start** (`ensure_all_started`, a supervision tree) is a separate run-time fact from "on the
  path"; no check here covers it. The OTP `runtime_dependencies` enforcement (E15) is unprobed.
- **Whether OTP's own apps (`kernel`, `stdlib`) should be exempt from declaring** — the rule "needs no
  declaration" is unmeasured; `lib_dir(stdlib)` resolves under the OTP root (E6) so the check would pass anyway.
- **LSP/`--check` behaviour** when a dependency is absent from the editor's environment: reasoning only.
