# Brief: ticket 52 (ENG-234) — what does a `.bs` file say about what it needs?

Decision brief only. Nothing under `wayfinder/`, `compiler/` or Linear was touched. Probes: `artifacts/probes/52/`
(`bash artifacts/probes/52/run.sh` reruns all ten from scratch; last run: ALL PROBES HELD).
Toolchain: OTP 25 (not the repo's 28.5), Elixir 1.14.0, Gleam 1.12.0. `bsc` cannot be built here, so every claim
about it is read from source (file:line) or cited from a ticket, and labelled.

## 1. Question and the gating sub-decision

**Gating question: does a `.bs` source name the *application* a foreign module comes from, or only the module?**
Everything else follows from the answer: if no, there is no syntax and nothing is left to ask. If yes, then
per-`using` vs per-module, name-only vs version, and what bsc does with it are questions about a clause that
exists. Ticket 51 decided there is no manifest of beam-sharp's own, so a single-file exemplar has nowhere else to say it.

Two things the ticket states that the probes contradict (section 2, rows 2 and 6):

- **"Compile it … and it fails at the call site with `error:undef`."** The *compile* succeeds, silently, even under
  `erlc -Wall`; only the *run* fails.
- **"Checking the application is on the code path is one line … that may be the whole feature."** The one line
  (`code:lib_dir(App)`) answers `{error,bad_name}` for a dependency that is on the path, if its directory is not
  named `app` or `app-vsn`. And the check that catches the `undef` needs no application name at all: it is a
  *module* presence check, which bsc can already make from the `{foreign, _, Mod, _}` declarations it holds.

## 2. Evidence

| # | claim | probe | result | status |
|---|---|---|---|---|
| 1 | Source can't say which app; today nothing does | grep `wayfinder/issues/*.md` for `ERL_LIBS`, `provenance`, `\.app`, `app:` | 51 and 52 only; no ticket decides it. `bs_parser.yrl:170` `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'` has no slot for it | cited, not re-run |
| 2 | Compiling a call to an absent module is silent; run is `error:undef` | [p1](probes/52/p1_undef_and_tools.sh) | `erlc -Wall +debug_info`: exit 0, no output. Run: `error:undef` | measured here |
| 3 | The `.beam` already records the remote MFA | p1 | `beam_lib:chunks(F,[imports])` -> `[{'Elixir.Req',new,1},…]` | measured here |
| 4 | A stock `.beam` names no application | p1 | `lists`, `gen_server` attributes carry `vsn`/`dialyzer` only; no `app`/`application`/`applications` key | measured here |
| 5 | xref flags it, but only with debug info | p1 | with `+debug_info`: `[{{uses_missing,go,0},{'Elixir.Req',new,1}}]`. **First run, without it: `Skipping ./uses_missing.beam (no debug information)` and `[]`** — a silent green. bsc passes `debug_info` (`bsc.erl` `build/3`, `Options = [from_abstr, debug_info, …]`) so xref would work on bsc output | measured here |
| 6 | `code:lib_dir(App)` is not a reliable presence test | [p3](probes/52/p3_presence_checks.sh) | `ERL_LIBS` with `req-0.7.3/ebin`: ok. rebar3 layout `_build/default/lib/req/ebin`: ok. `-pa libC/anything/ebin` (module reachable): **`{error,bad_name}`**. `code:which(Mod)` is right in all three | measured here |
| 7 | Compile-time `code:ensure_loaded` runs foreign code | p3 | module with `-on_load` printed `ON_LOAD RAN` on `ensure_loaded`; `code:which` and `beam_lib:chunks(F,[exports])` ran nothing and returned `[{module_info,0},{module_info,1},{new,1}]`. `function_exported` is `false` until loaded | measured here |
| 8 | A compiled module can carry an app attribute via the route bsc already uses | [p2](probes/52/p2_attribute_cost.sh) | `{attribute,1,bs_app,req}` in `.abstr` -> `compile:file(…,[from_abstr,debug_info])` clean; `m1:module_info(attributes)` -> `[{bs_app,[req]}]`; readable from the file without loading | measured here |
| 9 | Module name does not give the app | [p4](probes/52/p4_module_to_app.sh) | 925 modules in 24 installed apps: name equals app for **11 (1.2%)**; rule "lowercase first `Elixir.` segment" right for 140 of 388 Elixir modules. Biased sample (core Elixir, `Elixir.Access` is in app `elixir`); it shows no rule exists, not what hex looks like | measured here, sample caveat |
| 10 | The BEAM's dependency vocabulary is names | [p8](probes/52/p8_app_files_are_name_only.sh) | 25 `.app` files, 52 dependency entries, **0 carry a version**. OTP's own `runtime_dependencies` does carry versions ("stdlib-4.1"), is advisory, on 19 of 25 files, **none of the Elixir ones** | measured here |
| 11 | The VM reports a missing app by app name | [p5](probes/52/p5_vm_speaks_app_names.sh) | `ensure_all_started(req)` -> `{error,{req,{"no such file or directory","req.app"}}}`; with req present, dep absent -> `{error,{mint,…"mint.app"}}` | measured here |
| 12 | Corpus: what B# programs `using` today | [p9](probes/52/p9_corpus_usings.sh) | 27 `using` blocks, 14 distinct modules: 11 owned by OTP/Elixir apps, **3 owned by nothing installed** — `Elixir.Req`, `epgsql`, and `json` (stdlib only from OTP 27; the repo pins 28.5, this box is 25) | measured here |
| 13 | bsc today does no environment query in the checker | grep `code:`/`file:`/`filelib:` in `compiler/src/bs_check.erl` | no hits; `code:` appears only in `bs_batch.erl`, `bs_repl.erl` | read from source |
| 14 | A `using` of an absent module compiles | ticket 51 table (`50a` against `'Elixir.String'.upcase/1`: compiles, "crashed: error:undef") | cited, not re-run | cited |

## 3. Neighbour survey

**Erlang.** The `.app` file's `applications` is the declaration, and it is a list of bare names (p8: 52 of 52
entries atoms). Modules are not tied to it in source: p1 row 4, a `.beam` names no app. xref is the checker and
works on the `imports` chunk (p1 row 5), needing `debug_info`. rebar3 and `.app.src` are not installed, no Erlang
source is installed, and I cite nothing about them.

**Elixir.** The source declares nothing; `mix.exs` does. [p6](probes/52/p6_elixir.sh): a call to an absent module
compiles with `warning: Req.new/1 is undefined (module Req is not available or is yet to be defined)`, exit 0.
Separately, mix **infers the application from the used module and checks it against the manifest**: using `Logger`
with `extra_applications: []` gives `Logger.info/1 defined in application :logger is used by the current
application but the current application does not depend on :logger`; with `[:logger]` in a separate project, 0
warnings. Only `ebin` is installed for Elixir, so no file:line. *Original p6 run:* editing `mix.exs` in the same
directory and recompiling still warned; cause not isolated (stale build state is my guess), so p6 now uses two
directories.

**Gleam.** [p7](probes/52/p7_gleam.sh): `@external(erlang, "Elixir.Req", "new")` naming a module that does not exist
builds clean (`Compiled in 0.42s`), emits `'Elixir.Req':new([])`, runs to `error:undef`. The declaration names the module only,
as in B# today. `gleam.toml [dependencies]` governs Gleam imports: `import gleam/io` with no stdlib dependency is
`Unknown module … No module has been found` (the message does not say which package to add). Gleam binary only;
no source.

**Elm.** Not probed. `elm init` needs the package server and failed here with "Are you somewhere with a slow
internet connection? … no internet?". I make no Elm claims.

## 4. Measurements

All from p2/p3/p10, OTP 25, this box.

| what | number | command |
|---|---|---|
| `.beam` with no attribute | 708 B | p2 `m0` |
| + `-bs_app(req)` | 744 B (+36) | `m1` |
| + `{req,<<"~> 0.7">>}` | 776 B (+68) | `m1v` |
| 5 apps, names / with versions | 868 B (+160) / 972 B (+264) | `m5` / `m5v` |
| for scale: `-behaviour(gen_server)` | 772 B (+64, plus 3 lint warnings in that stub) | `mbeh` |
| loaded term, `erts_debug:flat_size` of the attribute | 7 / 13 / 35 / 65 words for the four rows | p2 |
| `code:lib_dir(absent)` | 1-3 µs | p3, p10 |
| `code:which(absent)` | 115 µs (short path), **965 µs** (36 path entries) | p3, p10 |
| `beam_lib:chunks(F,[exports])` | 67-92 µs | p3 |
| scan every `.app` on the path once (module->app map, 25 apps) | 11-13 ms | p10 |

The attribute lives in the abstract-code chunk as well as the attributes chunk, which is why bytes exceed twice the
words. A 14-module program checked in full is about 14 ms for the `which` form and one ~12 ms scan for the `.app`
form. Neither is on a path anyone waits for. For comparison, bsc already emits `'bs@type_atoms'/0` on every
module (`bs_emit.erl:75-77`), so a per-module artefact is not new.

## 5. Options

Whichever is chosen, **the module-presence warning comes with it for free** (row 7, p3): in the driver, not
`bs_check` (row 13), `code:which(Mod)` for each `{foreign,_,Mod,_}` and a warning, not an error, because the
generated code is complete from the signatures and an error would break the LSP, `--api`, and every machine without
the dependency installed (row 12: 3 of 14 corpus modules are absent here). The decision below is only about what
the source *says*.

### Option 1: the `using` names its application

```csharp
module Fetch

using :'Elixir.Req' in :req {
    term New(list<(atom, term)> opts) = :new
    term GetOrCrash(binary url) = :'get!'        // ticket 106's alias form
}
using :'Elixir.Req.Request' in :req {
    term Put(term req, atom k, term v) = :put_header
}
using :gen_server { term call(term ref, term msg) }   // OTP/Elixir-bundled: nothing to say
```

*Spelling `in :app` is a follow-on, chosen because `'in'` is already a token (`bs_parser.yrl:29`, `'for' 'in'`)
and ticket 65 says B# reserves no identifier, so `from` would be the first one.*

**Compiles to.** The same remote calls as today, plus one attribute per `using ... in`:
`-bs_uses({req,'Elixir.Req'}).` (p2: ~36 B each).

**Compiler delta (concrete):**
1. `bs_parser.yrl:170`: `foreign_decl -> 'using' atom_lit 'in' atom_lit '{' … '}'`, App optional.
2. The AST `{foreign, L, Mod, Sigs}` is matched in four places (`bs_check.erl:615, 633, 1054, 1092`); each gets the
   extra element, or the app travels in a side map.
3. `bs_emit.erl:78`, next to the `behaviour` comprehension: one `{attribute, ?A, bs_uses, {App,Mod}}` per entry.
4. A driver pass (not `bs_check`): scan `code:get_path()` for `*.app` (not `code:lib_dir`, row 6), warn if the app
   is absent, and warn if `Mod` is not in that app's `modules` (this is the check that catches a wrong `in :mint`
   on a Req module; option 3 cannot make it).
5. One descriptor in `bs_diag` (F16: the diagnostic is a term), and a `bsc --uses` listing read from the attribute.

**Counterargument.** It is a second statement of a fact the project's `rebar.config` or `mix.exs` already holds
(ticket 51 made a project a rebar3 or mix project). The two can drift, and bsc has no way to compare `in :req`
with `rebar.config`; Erlang's `.app.src` against `rebar.config` is the same shape. Also, 24 of the corpus's 27
`using` blocks would not need it, so the clause is noise for most readers and is only meaningful when present.

### Option 2: once per module

```csharp
module Fetch
needs :req            // like `behaviour GenServer`: one line, module level (bs_parser.yrl:165)
using :'Elixir.Req' { … }
using :'Elixir.Req.Request' { … }
```

Delta: one `behaviour_decl`-shaped rule, a module-level list, one attribute `-bs_needs([req])`. It saves the
repetition (a Req binding that wants `Req`, `Req.Request`, `Req.Response` repeats `in :req` three times) and can
state an app no `using` calls (`:ssl`, started but never called). It gives up item 4's membership check, and a
reader cannot see which `using` came from which app. **Counterargument:** it can lie freely: a typo, or a stale
line after the last `using` of that app is deleted, is undetectable; the declaration then claims more than the
checker can verify. This is a variant of option 1, not a rival: if the answer to the gating question is yes,
the unit follows from it.

### Option 3: the source says nothing; tooling derives it

```csharp
module Fetch
using :'Elixir.Req' { … }     // exactly as today
```

Delta: the module-presence warning above, and a `bsc --uses` that reads the `imports` chunk (row 3), maps module to
app through the `.app` files on the path (row 9 machinery, ~12 ms) and compares with the project's manifest, which
is Elixir's mechanism (row 6 p6). No grammar change, no attribute, no new keyword.
**Counterargument, and the reason it is not the pick:** the map exists only if the dependency is installed
and the module name cannot rebuild it (row 9: 1.2% match). The ticket's case is exactly the machine where the
dependency is absent, and there the source of an exemplar like `25d` (`using :epgsql`, a single directory, no
`rebar.config`) names a module and no application. A stranger handed that source learns *a* module, not what to
install. A manifest closes that for projects (51) and not for the single-file exemplars the handoff is made of.

## 6. Recommendation

**Option 1, with `in :app` optional, name only, and the check a warning.** Reasons: it is the only option that
lets the diagnostic say *what to install* and the only one that can catch a wrong app (membership, item 4); the
cost is a few tokens on the lines that need them, which the standing constraint (write cost near-free, read cost
full weight) prices as a reader seeing where a foreign thing comes from, which is the same bargain ticket 32 took
for the declaration. **Name only** because the whole BEAM vocabulary is names (row 10: 0 of 52 entries carry a
version) and Elixir's own check (p6) is by name; a version is resolution, which 51 refused. **Per-`using`** because a
module has exactly one owning application, so the unit is the module, and that is the unit a check can verify.

What would change my mind: if the audition's tickets always arrive as a rebar3/mix project with a manifest (then
row 14's gap is already closed and option 3 costs less); if the `in :app` line is observed drifting against
`rebar.config` in a real binding (the Req exemplar, ticket 50's owed work, is the place to see it); or if the
module-presence warning alone proves enough for the handoff's judges. The Req exemplar is where to measure
whether the repetition is noise.

## 7. Not verified here / limits

- **OTP 25, not 28.5.** `json` is absent on 25 (row 12) and present on 27+, so the presence check's result for it
  differs between this box and the repo's pin; `code:which`/`lib_dir`/`beam_lib` behaviour on 28 not re-run.
- **bsc not runnable** (lexer needs OTP 26+ leex; no rebar3). Rows 1, 13 and 14 are read from source or cited.
  Every compiler-delta item is a plan, not a built change. I did not check that an extra tuple element in
  `{foreign,…}` leaves the other consumers (`bs_diag`, `--api`, the LSP) alone.
- **Real Req was not built** (hex unreachable), so the module-to-app match rate for third-party packages is
  unmeasured; p4 uses OTP and Elixir core only and is biased toward mismatch for Elixir modules.
- **Elm** unprobed (network). **rebar3, `.app.src`, `systools`, Gleam internals, mix source** not available; no
  claim made from memory.
- The `-bs_uses` / `bs_app` attribute name is a probe label, not a proposal. Whether `rebar3` or `reltool`
  would use such an attribute to include the app in a release is unprobed (they read `.app.src`, I believe;
  not verified).
- Row 5's silent `[]` is a falsifier I hit, not one I designed: a probe that had stopped at the first run would
  have reported "xref does not see it".
