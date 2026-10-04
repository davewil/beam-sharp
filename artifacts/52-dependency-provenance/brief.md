# Decision brief — ticket 52 (ENG-234): does a `.bs` file record what it needs?

Prepared 2026-10-04. Nothing under `wayfinder/` or `compiler/` was touched; nothing committed.
Every number below comes from a probe in `probes/` with its captured `.out` beside it. All probes
re-run from `probes/NN_*.sh` (they source `probes/env.sh`, build fixtures into `/tmp/p52`).

## 0. What the repo already says (grepped, not assumed)

- **The spelling in the ticket does not exist.** `[external: elixir, app: req] using …` combines two
  things that were decided and never shipped: ticket 32's `[external: …]` attribute and ticket 41's
  attribute-target syntax. `grep -rn '\[external' compiler/src compiler/features` finds nothing; the
  parser has no attribute production at all (`bs_parser.yrl`). What shipped is LANGUAGE.md §11:
  `using :'Elixir.Req' { term new(...) }` (`bs_parser.yrl:170`, AST `{foreign, Line, Mod, Sigs}`).
  There is no `elixir` tag; the module is written as the atom it is.
- **A foreign block is already module-wide.** Probe 08: a block written in `yell.bs` is visible to the
  sibling `hi.bs`; blocks in `index.bs` are visible to every file. So "per block vs per module" is not a
  scope question; it is only a question of where the app name is written and how often.
- **50 and 56 extend `using` by nothing** (50: a foreign struct is a `map<atom, term>`; 56 /
  F23: no grammar change). The sequencing hazard 52 names is now with **ticket 106**
  (resolved, unbuilt): an *entry-level* alias, `term GetOrCrash(binary url) = :'get!'`. A header-level
  word on the block and an entry-level `= :'atom'` occupy different positions and do not collide.
- **A repo corpus exists.** Probe 20 parses all 161 non-artifact `.bs` files with the real parser: 30
  foreign blocks in 18 files; 25 are `erts`/`kernel`/`stdlib`; **5 are not**: `Elixir.Req` and
  `Elixir.Application` (51a `Req/req.bs:37,43`), `Elixir.String` and `Elixir.Enum` (`Elx/elx.bs:13,17`),
  `:epgsql` (exemplar 25d `index.bs:12`). Most blocks in one file: 3.
- `Req/req.bs:69` already writes `ensure_all_started(:req)`: the app name is in that program as a runtime
  value; no declaration ties it to the `using :'Elixir.Req'` block above.
- `LANGUAGE.md:2944` says quoted atoms "are not lexed yet". Measured: `:'Elixir.Greeter'` lexes and runs
  (probe 02); `:"Elixir.Greeter"` is `syntax error before: ':'` (probe 08 C). The line is stale.

## 1. Sub-decisions, extracted

| # | Sub-decision | What measurement bears on it |
|---|---|---|
| S1 | Name only, or name + version | probes 05, 09, 14 |
| S2 | Written per `using` block, or once per module | probes 08, 10, 20 |
| S3 | What the compiler does with it: nothing / check the module / check the app / check transitive apps / emit | probes 02, 03, 04, 12, 13, 21 |
| S4 | Spelling, and whether it needs a reserved word | probe 10 |
| S5 | Which modules are exempt (OTP core) | probes 04, 20 |
| S6 | Interaction with 50 / 56 / 106 | section 0 |
| S7 | Severity: does an absent dependency stop compilation | probes 15, 14, 16 (neighbours) |

S3 splits into things that are cheap and settled by measurement (below) and one that is a real choice:
**whether the source carries the app at all**, since the module-presence check needs no app (probe 12, option C).

## 2. Facts the options stand on

1. **Reproduced (51's claim).** With `ERL_LIBS` pointing at a mix-built library, `bsc` calls it:
   `"hello, bob"`. With `ERL_LIBS` unset or pointing elsewhere: `crashed: error:undef`. Compiling
   without the library succeeds silently, exit 0 (probe 02, fixture: a local mix-built `Greeter`; no Req
   here, see caveats). Gleam behaves the same way (probe 14: `@external(erlang, "Elixir.Greeter", "hello")`
   builds with exit 0, then `undef`).
2. **The run-time message today names nothing.** `bsc.erl:640-641` prints `crashed: error:undef` and
   drops the stack; the stack's head is `{'Elixir.Greeter',hello,[<<"x">>],[]}` (probe 19).
3. **The code server can tell "application missing" from "module missing"** (probe 03):
   `code:lib_dir(req)` -> `{error,bad_name}`; `application:load(req)` ->
   `{error,{"no such file or directory","req.app"}}`; `code:ensure_loaded` -> `{error,nofile}` for *both*
   cases, so it cannot distinguish them. `code:which` does not load the module; `ensure_loaded` does and
   **runs `-on_load` code in the compiler's VM** (probe 21).
4. **`lib_dir` + `which` alone does not verify that a module belongs to the named app.**
   `check(kernel, lists)` and `check(greeter, lists)` both return `ok` (probe 03). Membership needs the
   path shape `<lib>/<app>[-vsn]/ebin/<mod>.beam` or the `.app` `modules` list.
5. **Module -> app by path shape worked everywhere an application directory exists**: `lists`->`stdlib`,
   `crypto`, mix `Elixir.Greeter`, rebar3 `rlib_util`, gleam `glib`, both apps of a mix umbrella
   (flat `_build/dev/lib/{alpha,beta}`), and from inside an escript (which inherits `ERL_LIBS`).
   **It breaks** for a beam in a plain `-pa` directory (`{no_app_dir,"/tmp/p52/orphan"}`) and for mix's
   `consolidated/` protocol directory. `code:lib_dir(orphan)` also returns a directory for a `-pa` dir
   merely *named* `orphan`: a false positive (probe 04).
6. **The `.app` is the authoritative table** and costs a file read: `modules`, `applications`, `vsn` for
   greeter/rlib/glib/alpha/beta/stdlib (probe 04). Gleam's `.app` lists `modules [glib, glib@@main]` and
   `applications []`. **Beams carry no application name** in any toolchain: attributes are `[{vsn,[hash]}]`
   (probe 22).
7. **The application cannot be derived from the module atom.** The "obvious" guess (first segment,
   snake-cased, for Elixir; `mod == app` or `app_` prefix for Erlang) is right for **39.8%** of the 422
   modules in Elixir 1.14's six apps (`Elixir.String` -> `string`, but it lives in `elixir`) and
   **34.9%** of 890 OTP 28 modules; it fails for at least one module in 18 of 29 OTP apps (probe 11).
8. **A version is not safely checkable.** With `rlib-1.0.0` and `rlib-2.0.0` both on `ERL_LIBS` the code
   server silently picks 2.0.0 (the call reaches the 2.0.0 beam); a directory named `rlib-3.0.0` whose
   `.app` says `1.2.0` is chosen first and reports 1.2.0 (probe 05). The version is readable (`.app`
   consult ~140-270 us) but matching it is resolution.
9. **The beam already names the foreign module** (`imports` chunk lists `{'Elixir.Greeter',hello,1}`),
   and OTP's xref reports the call as undefined after the fact, but only if told to use the code path;
   its default library path is empty (`xref.erl:1160`), so with the dependency *present* it still reports
   undefined (probe 09). xref names a function, never an application.
10. **Cost.** Per using-block check (`lib_dir` + `which`): **~18 us** warm, **~0.26 ms** for three blocks
    in a fresh VM (what `bsc` pays), against **~0.7 s** for `bsc` to compile the same program, about
    0.04%. First `which` miss on a 534-entry path: 2.9-13.7 ms across runs (noisy), ~0.4-2% of a build.
    `application:load`+`unload` ~95-163 us. Transitive `applications` closure ~1.0-1.4 ms and gave a
    **false positive** on the fixture (flags `elixir`, `logger` missing although `Greeter.hello` runs; probe
    13). Reading a declared function's exports without loading: ~85 us (probe 21).
11. **Emission cost.** `-bs_requires([req])` adds **44 bytes** to a 852-byte beam; with a version string
    60; three apps in one attribute 64; as three attributes 112. Readable with `beam_lib:chunks` without
    loading, 3.9 us (probe 09).
12. **Grammar cost.** On a copy of the real grammar, the per-block form and both module-level forms add
    **no conflicts** (yecc reports 6 resolved before and after in all four variants; probe 10). `from` is
    an ordinary identifier **17 times** in the repo's `.bs` files (`app` once), so a reserved `from` would
    break existing programs; a contextual word does not. `requires` appears 0 times.

## 3. The options

### Option 1. The block names its application, once, as an atom

```csharp
// Req/req.bs, as 51a would be written
module Req

using :'Elixir.Req' from :req {
    term new(list<(atom, term)> opts)
}

using :'Elixir.Application' from :elixir {
    term ensure_all_started(atom app)
}

using :maps {                               // erts/kernel/stdlib: no `from`
    term get(atom k, term m)
}

using :epgsql from :epgsql {                // exemplar 25d
    ConnectOutcome connect(list<term> opts)
}
```

Rules: `from :app` is **required** for any foreign module outside `{erts, kernel, stdlib}` (a closed
table beside `bs_otp.erl`'s hand-written ones; 25 of 30 corpus blocks need nothing, 5 gain a word). Name
only; no version. `crypto`, `ssl`, `inets` etc. are OTP but not core, so they are written
(`using :crypto from :crypto`), matching how OTP's own `.app` files list them (`crypto.app:28`,
`sasl.app:44`).

What it prints (prototype pass over the patched grammar, probe 12; the pass is not in `bsc`):

```
a_ok.bs:2:1: error: `using :'Elixir.Greeter'` needs application `greeter`, which is not on the code path
  searched ERL_LIBS=/tmp/p52/other_libs (33 entries). Build it with rebar3 or mix and put its lib directory on ERL_LIBS.
a_typo.bs:5:1: error: application `greeter` is on the path (…/greeter) but has no module `Elixir.Greeter.Nope`
a_wrongapp.bs:2:1: error: `using :'Elixir.Greeter'` is in application `greeter`, not `kernel`
  say `from :greeter`
a_nofrom.bs:2:1: error: `using :'Elixir.Greeter'` is not an OTP module and names no application
a_noapp.bs:2:1: error: `using :'Greet'` is on the path at /tmp/p52/orphan, outside any application directory
  `from :orphan` cannot be checked; it is accepted unverified.
```

Compiler delta, as work:

- `bs_parser.yrl`: one production, `foreign_decl -> 'using' atom_lit lident atom_lit '{' foreign_sigs '}'`
  with a contextual check that the word is `from` (wrong word reports ``expected `from`, found `by` ``).
  AST becomes `{foreign, L, Mod, Sigs, App | none}`; four match sites in `bs_check.erl` (lines 622, 640,
  1061, 1099) take the fifth element, or keep the 4-tuple and add a side node.
- A pass (prototype `probes/prov_check.erl`, ~100 lines with diagnostics): per block, `code:lib_dir(App)`,
  then `code:which(Mod)`, then module-owner by path shape; **accepted unverified** when there is no app
  directory. `bs_diag` gains four tags: app not on path, module not in app, module in other app, non-core
  module without `from`.
- Symbol table: the module collects `Apps :: [atom]` from its blocks. Emission: one
  `{attribute, _, bs_requires, Apps}` (44 bytes for one app). `bsc --api` can print the same list.
- Surfaces that mirror the grammar: tree-sitter `grammar.js:183-190` (`foreign_declaration`), the
  sublime-syntax and vscode grammars; LANGUAGE.md §11 (and the stale line at 2944).
- Gate for the feature (CLAUDE.md: test first): fixtures build offline in 0.6-1.6 s each (probe 01); an
  Erlang (`rebar3`) fixture needs only OTP, so the gate needs neither network nor Elixir.

**Strongest counterargument.** The claim is checkable only where it is least needed. When the
environment has the dependency, path shape already yields the app (fact 5), so `from :req` restates
what the machine would say; when the environment lacks it, which is the handoff case the ticket cites,
nothing can verify the claim, and a stranger's compiler only needs the *module* to be present (option 3
prints a comparable diagnostic). It also repeats: `Elx/elx.bs` writes `from :elixir` twice for two
modules of one app (worst case measured in the corpus: 2).

### Option 2. The module names its applications once, in `index.bs`

```csharp
// Req/index.bs
module Req

requires :req
requires :elixir

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Application' {
    term ensure_all_started(atom app)
}
```

`index.bs` is already "the module's declaration file — using, type, record and behaviour"
(`bs_diag.erl:2054`), and probe 08 shows the blocks are module-wide anyway. `requires` is the module's
dependency list, the same shape as the `.app` `applications` key (`inets.app:100`).

What it prints (probe 12, mode b):

```
b_norequires.bs:2:1: error: `using :'Elixir.Greeter'` is in application `greeter`, which this module does not require
  add `requires :greeter` to index.bs
b_unused.bs:3:1: error: `requires :rlib` is not used by any `using` in this module
b_ok.bs:2:1: error: `requires :greeter`: application `greeter` is not on the code path
  searched ERL_LIBS=/tmp/p52/other_libs (33 entries). …
```

Compiler delta, as work:

- `bs_parser.yrl`: `decl -> lident atom_lit` with contextual word `requires`, or a reserved `requires`
  (0 existing uses; both variants: no new conflicts, probe 10). AST `{requires, L, App}`; no existing match
  site changes.
- The same pass, but each non-core `using` must be **attributed** to a `requires` through
  module-owner-by-path-shape (fact 5). Where that fails (no app directory, `consolidated/`) the block
  cannot be attributed, so it is accepted unverified. Four tags as in option 1, plus unused-`requires`.
- Same attribute emission, same editor grammars (`decl` instead of the foreign production).

**Strongest counterargument.** Option 2 is correct only as far as the module-to-app map is, and that map
is a path-shape heuristic with two measured holes (fact 5); option 1 uses the same heuristic only to
*explain a failure*, option 2 uses it to decide pass/fail. It also puts the app a line away from the
`using` that needs it, and invites `requires :ssl`, which no `using` names and nothing can verify.
(Its real advantage is that last property: it is the one place a runtime-only dependency could be said.)

### Option 3. The source says nothing new; the compiler checks the module and the error text improves

```csharp
// unchanged
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

```
c_ok.bs:2:1: error: `using :'Elixir.Greeter'` names a module that is not on the code path
  searched ERL_LIBS=/tmp/p52/other_libs (33 entries). Put the directory holding its ebin on ERL_LIBS.
crashed: 'Elixir.Greeter':hello/1 is undefined -- module 'Elixir.Greeter' is not on the code path (ERL_LIBS=unset)
```

(probe 12 mode c; probe 19 for the run-time text.)

Compiler delta, as work: no grammar change. One loop over foreign blocks calling `code:which(Mod)` and
emitting a diagnostic; one `report_run` clause at `bsc.erl:640` that reads the stack head for `undef`
and asks `code:which` whether the module is absent or merely lacks the export. `bsc --api` can list the
foreign modules (the beam's `imports` chunk already does, fact 9).

**Strongest counterargument.** It answers "what does `bsc` do with a dependency" and declines the
question the ticket was raised on. The source still names no application, and the application cannot be
recovered from the module name (39.8% / 34.9%, fact 7). A reader of the `.bs` alone still cannot say
what to install, so the handoff argument is unanswered, and the ticket says that argument is the
reason for the ticket.

## 4. Recommendation

**Option 1, name only, per block, required outside `{erts, kernel, stdlib}`**, with these edges, each
backed by a probe:

1. **Name, not version** (fact 8). The code server picks silently among versions and directory names can
   disagree with the `.app`; any constraint is resolution, which 51 refused. The diagnostic can *print*
   the found version for free (the `.app` is already read); rebar.lock / mix.lock / Gleam's
   `manifest.toml:5` already own versions.
2. **The environment check is a warning, the missing `from` is an error.** `from` is syntax the source owes
   the handoff; the environment may legitimately lack the dependency (editor, `--api`, a build machine that
   is not the run machine). Elixir does the same: undefined module, warning, exit 0 (probe 15);
   Gleam checks nothing (probe 14). `bs_diag` already has a `warning` severity.
3. **Do not check transitive applications** (fact 10: ~1 ms and a false positive on the fixture). Leave
   that to `Application.ensure_all_started`, whose run-time error already names the missing app
   (`{:error, {:req, {'no such file or directory', 'req.app'}}}`, probe 15; Erlang's equivalent for a
   listed-but-absent app: probe 16).
4. **Never `ensure_loaded` in the compiler**; use `lib_dir` + `which` (no load, no `-on_load`; fact 3).
   An export check on the declared function is possible without loading (~85 us, probe 21) but is a
   separate scope question and is not part of this recommendation.
5. **Emit `-bs_requires`** (44 bytes). It is what lets a release tool build an `applications` list without
   parsing `.bs`; no neighbour's beam carries an app name (probe 22).
6. **Ship option 3's `undef` text regardless**; it is an improvement to a message, not a language
   decision, and it needs no ticket.

Why 1 over 2: the block that needs the app carries it; no attribution step; a wrong claim is positioned on
its own line. Why 1 over 3: it is the only one that puts the app in the source. The cost is one word on
the 5 of 30 corpus blocks that are not core. If David finds `from :elixir` twice in one file ugly,
option 2 is the answer to that specific complaint, at the price in its counterargument.

## 5. What the neighbours do (all opened this session)

| Toolchain | Where provenance lives | Does the compiler check an FFI target against it? | Evidence |
|---|---|---|---|
| Gleam 1.12 | `gleam.toml` `[dependencies]` (`gleam.toml:15-19` as generated); resolution in `manifest.toml:5` (name, version, source) | **No.** `@external(erlang, "Elixir.Greeter", "hello")` names module and function only; it compiled, exit 0, and emitted `'Elixir.Greeter':hello(Name)` (`app.erl:14`); `undef` at run time. A missing *Gleam* import is an error (`Unknown module`) | 14 |
| Elixir 1.14 | `mix.exs` `deps` (`mix.exs:5`); the `.app` `applications` list is **inferred** from it (`probeapp.app:2` -> `[kernel,stdlib,elixir,logger,greeter]`); source never names the app | **Warning, not error:** `Nonesuch.Thing.run/1 is undefined (module … is not available or is yet to be defined)`, exit 0. With the dep removed, the call to `Greeter` gets the same warning: "undefined module", never "dependency missing" | 15 (Elixir's `.ex` sources are not installed; no source file is cited) |
| Erlang/OTP 28 | `.app` `applications` (`kernel.app:161` `[]`, `sasl.app:44`, `crypto.app:28`, `inets.app:100`) and `rebar.config` deps | **Not at compile.** `rebar3 compile` is silent about an undeclared `crypto` use and a nonexistent listed `nonesuch`; `rebar3 xref` reports only the undefined *function* (`Elixir.Greeter:hello/1`). The listed-but-absent app is refused at **start** by the application controller | 16, `xref.erl:1160`, `:1542` |
| Elm 0.19.2 | `elm.json` `dependencies` (`elm.json:5-8`, hand-written here), edited by `elm init`/`elm install` | A **manifest-level** check ran before any import: `MISSING DEPENDENCY … I need to see an "elm/json" dependency`. The import-level check and the `install` flow need the registry and could not run | 17 (inconclusive for imports) |

Reading across: every neighbour declares dependencies in a **manifest**, none in the source that makes the
foreign call; none *verifies a foreign call target's application at compile time*; and the nearest thing
to the ticket's candidate is Elm's compiler reading `elm.json` before resolving imports. B# adopting
`from` would be doing something its four neighbours do not, which is the argument for it (the ticket's
handoff reason) and the argument against it (no precedent for the cost/benefit) at once.

## 6. Claims not reproduced / caveats

- **OTP 28.0** here, not the tickets' 28.5; **Elixir 1.14.0** (tickets: 1.19.5); **Gleam 1.12.0** (1.18.1);
  Elm 0.19.2. Absolute timings are a 4-vCPU container and noisy (the first-miss range 2.9-13.7 ms across
  two runs); only ratios are meaningful.
- **Elixir 1.14's own beams do not load on OTP 28** (`beam_load.c … bs_add`; probe 00), so everything
  involving Elixir *runtime* modules (Kernel, protocols) was not reproduced. The fixture `Greeter` was
  built with OTP 25 + Elixir 1.14 and deliberately calls nothing in `Elixir.Kernel`; "ERL_LIBS reaches it"
  and "a different ERL_LIBS gives `error:undef`" reproduce on it (probe 02), but **not on Req**, and 51's
  rebar_mix / `eex` finding was not retried. Ticket 51's statement that Req's nine packages work is
  neither confirmed nor contradicted here.
- **No network**: hex and the Elm registry are unreachable (a probe was refused by the sandbox classifier
  and I did not pursue it). Gleam's manifest is therefore shown for a **path** dependency, and the
  default-deps build failure is in the probe 14 output. Elm: the import check and `elm install` are
  inconclusive; Elm's kernel-import mechanism was not examined.
- The prototype pass, the patched grammars and the AST shapes are **scratch copies in `/tmp/p52/proto`**;
  the real `bs_check` was not changed, so "four match sites" is a `grep` count (`grep -n "{foreign,"
  compiler/src/*.erl`), not a built change. The tree-sitter, sublime and vscode grammars were located, not
  edited. The parse of the full corpus under the patched grammar was not run (only conflict counts and four
  sample files).
- **Not measured**: effect on the REPL (`ibs`), `--api` and LSP compiles when the dependency is absent
  (the warning-severity recommendation reasons from the neighbours, not from a probe); `-pa` dirs that a
  *release* adds; rebar3 umbrella layout (only a mix umbrella was built); `otp_owned/1` by `root_dir` prefix
  was exercised only through the `a_nofrom` case.
- `application:load` first-call cost and `code:lib_dir` false positives for a `-pa` directory merely
  *named* like an app (probe 04) mean `lib_dir` alone must not be the proof of "application present".
- The probe numbering has gaps (06, 07, 18) because planned probes were folded into others.

## 7. Probe index

| Probe | Claim tested | Result |
|---|---|---|
| `00_toolchain` | toolchain versions; Elixir on OTP 28 | OTP 28, rebar3 3.24, gleam 1.12, elm 0.19.2 run; **Elixir 1.14 fails to boot on OTP 28** (beam load error) |
| `01_build_fixtures` | local libs buildable offline per toolchain | mix 1.2 s, rebar3 1.6 s, gleam 0.6 s; Greeter/rlib/glib `.app` + beams produced |
| `02_erl_libs_reaches_elixir_dep` | 51: ERL_LIBS alone reaches an Elixir-built dep; other ERL_LIBS -> `undef` | **Reproduced** on Greeter: unset -> `error:undef`; right path -> `"hello, bob"`; other dir -> `undef`; compile without dep exits 0 silently |
| `03_what_the_code_server_can_say` | can `lib_dir`/`which`/`application:load`/`ensure_loaded` split app-missing from module-missing | `lib_dir`+`which` yes; `application:load` yes for app; `ensure_loaded` no (nofile both); **`check(kernel,lists)` is `ok`: membership unchecked**; `which` does not load, `ensure_loaded` does |
| `04_module_to_app_mapping` | cheap module->app and where it breaks | path shape right for OTP, mix, rebar3, gleam, mix umbrella, inside an escript; **breaks** for `-pa` dir and `consolidated/`; `.app` gives modules/applications/vsn; false `lib_dir` for a `-pa` dir named like an app |
| `05_versions_on_the_path` | can a version be checked | highest dir wins silently; dir name 3.0.0 vs `.app` 1.2.0 disagree; same module twice resolves to one beam |
| `08_using_scope_across_files` | per-block vs per-module scope today | a foreign block anywhere in a module is visible to every file; `:"…"` not lexed, `:'…'` is |
| `09_emitted_metadata_and_xref` | what the beam already records; cost of `-bs_requires`; does xref answer | `imports` chunk lists the foreign MFA; xref default library path misses a present dep, `code_path` fixes it; +44 B (`[req]`), +60 (with version), +64 (3 apps), +112 (3 attrs); 3.9 us to read |
| `10_grammar_delta` | grammar cost of each spelling | 0 new conflicts (6 -> 6) in per-block, module-contextual, module-keyword; AST shapes shown; `from` is an identifier 17x in corpus |
| `11_module_name_does_not_encode_app` | can the app be derived from the module atom | 39.8% (Elixir, 422 modules), 34.9% (OTP 28, 890 modules); no |
| `12_prototype_check_and_diagnostics` | what the compile-time check prints, three options | 12 scenario diagnostics (app absent, module typo, wrong app, no `from`, no app dir, missing/unused `requires`, module-only) |
| `13_cost_of_the_check` | cost | ~18 us/block warm, ~0.26 ms/3 blocks cold, vs ~0.7 s compile; first miss on 534-entry path 2.9-13.7 ms; closure ~1-1.4 ms with a false positive |
| `14_survey_gleam` | Gleam provenance | `gleam.toml`, `manifest.toml:5`, `@external` carries no app and is unchecked; hex unreachable |
| `15_survey_elixir` | Elixir provenance | `mix.exs:5`; `.app` inferred; undefined-module is a warning, exit 0; `ensure_all_started` error names app |
| `16_survey_erlang` | Erlang provenance | OTP `.app` `applications` lines; `rebar3 compile` silent; `xref` function-level; app controller refuses at start |
| `17_survey_elm` | Elm provenance | manifest-level check observed; **import check and `elm install` inconclusive** (no network) |
| `19_undef_text_today_and_after_one_clause` | the run-time message can name the module | stack head carries the MFA; prototype text distinguishes absent module from absent export |
| `20_repo_corpus_foreign_blocks` | what `from` would cost existing code | 30 blocks/18 files; 5 non-core (Req, Application, String, Enum, epgsql); max 3 per file |
| `21_export_check_without_loading` | adjunct: confirm the declared function exists | `beam_lib` exports, ~85 us, no load; `ensure_loaded` runs `-on_load` in the compiler VM |
| `22_beam_attributes_name_no_app` | does a beam say its app | no: `[{vsn,[hash]}]` for mix, rebar3, gleam, bsc, OTP |

Helper files: `env.sh`, `prov.erl`, `prov_check.erl` (the prototype pass), `10_patch.py` (the grammar
patches), `fixtures/` (sources for the Elixir, Erlang, Gleam, escript, on-load and `.bs` fixtures).
