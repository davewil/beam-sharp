# Ticket 52 (ENG-234) — what does a `.bs` file say about what it needs?

Decision brief for David. Nothing is resolved, edited or committed. Probes are in `artifacts/52/probes/`, each a
script plus its captured `.out`; `p06` is a model of the compiler change, run on real B# files.

**Environment, stated up front.** OTP 25, Elixir 1.14.0, Gleam 1.12.0, no `rebar3`. The repo pins OTP 28.5, so I built
`bsc` by hand (`probes/build-bsc.sh`): leex on OTP 25 has no `TokenLoc`, so I rewrote it in a *copy* of the lexer
(columns in any diagnostic are wrong; lines are right). Nothing under `compiler/` was edited and the eunit suite was not
run. hex.pm and package.elm-lang.org are refused by the proxy, so there is **no real Req**: the stand-in is `libdep`, a
real `mix`-built Elixir application (`.app`, `applications: [kernel,stdlib,elixir,logger]`, unversioned dir). Ticket
51's own Req numbers are quoted from 51, not re-run.

## Question

51 settled that beam-sharp builds no dependency tool and `ERL_LIBS` reaches Req unchanged. Left open: a `.bs` file names
a foreign *module* (`using :'Elixir.Req' { … }`) and says nothing about the *application* it lives in, so a program
handed over on its source alone does not say what to install. **Does the source name the application, and what does
the compiler do with it?**

**The ticket's spelling is stale, and it should be read as a placeholder.** `[external: elixir, app: req] using …`
names a construct that does not exist. Ticket 32 decided `[external: erlang, "ets"] module Ets {…}`; what shipped is
`using :ets { … }` (LANGUAGE.md §11, `bs_parser.yrl:170`), as ticket 106 records. The grammar has no attribute
construct at all (`[` leads no declaration). Tickets 50 and 56 are resolved and added nothing to the declaration, so
the "sequence with 50" warning no longer has anything to collide with.

## Sub-decisions, gating one first

1. **GATING. Does the source name the application, or does the compiler only check the module?** If no, everything
   below is moot. This is the only question asked now.
2. Severity: is a missing dependency an error or a warning? (Asked second. Evidence below favours warning.)
3. Depth: check the named application only, or walk its `.app` `applications` closure? (Evidence below: the closure.)
4. Name only, or a version too? (Evidence below: name only; 51's boundary already refuses resolution.)
5. Does naming an application start it? (Evidence below: no.)
6. Only if 1 is "yes, in source": per block or once per module, and the spelling. Shown inside options B and C.

## Evidence

| # | Claim | Probe | Result | Status |
|---|---|---|---|---|
| 1 | Ticket: "compile it on a machine with a different `ERL_LIBS` and it fails at the call site with `error:undef`" | p02 | Compile exits **0**; `Shout` then `crashed: error:undef`. The failure is at run time, not compile time | **NOT CONFIRMED as a refutation (verifier).** The ticket itself says run-time `error:undef`; it never claimed a compile-time failure. The facts (exit 0, undef at run time) stand. Not evidence for or against B |
| 2 | A mistyped foreign module gets the same treatment | p02 D/E | `using :lits { … }` compiles (exit 0) and crashes `undef` at run time | VERIFIED |
| 3 | The `using :m { }` block is the only way a foreign module is named | p06a | `:lists.sum` with no block: `error: Total calls :lists.sum/1, which nothing declares` | VERIFIED |
| 4 | Nothing in the source records the application | p16 | `bsc --api` output is identical with and without `ERL_LIBS` and lists no dependency | VERIFIED |
| 5 | "Checking the application is on the path is one line … may be the whole feature" | p15 | Module presence is one `code:which`. But with `libdep` (the *declared* app) present and `elixir` absent, the run still ends `crashed: error:undef`, because `libdep.app` lists `elixir` and `logger`. A closure walk over `applications` flags both (`MISSING application elixir`, `logger`) | **REFUTED** that one line is the whole feature; the closure is about ten more lines |
| 6 | The application name is derivable from a module | p04 | Two methods (dir name; the `*.app` beside the beam) agree on 4 layouts: versioned (`stdlib-4.3.1.3`), unversioned mix (`_build/dev/lib/libdep`), unversioned Elixir install, two-version. `erlang` is `preloaded` (no path), so it needs a special case (`erts`). `application:get_application/1` returns `undefined` until the app is loaded, so it cannot be used | VERIFIED |
| 7 | A version is not checkable without resolution | p04 | With `acme-1.2.0` and `acme-1.3.0` both under `ERL_LIBS`, the VM puts **only 1.3.0** on the path and loads it silently. Which version is present is the environment's answer; a constraint like `~> 0.7` needs a comparison grammar and is 51's refused territory | VERIFIED |
| 8 | "Several `using` blocks may draw on one application" | p03 | 30 foreign blocks in 161 `.bs` files, 14 distinct modules. 4 blocks repeat an application already named in their directory; **1** of those is non-OTP (51a/Elx: `Elixir.Enum` and `Elixir.String`, both `elixir`). The corpus holds only two third-party blocks (Req, epgsql), so it cannot settle per-block vs per-module | VERIFIED, small sample |
| 9 | Most blocks need no declaration | p03 | 24 of 30 resolve to `erts` (13), `kernel` (1), `stdlib` (10). Another (`:json`) is OTP-27+ `stdlib`. 5 are non-OTP: 3 Elixir stdlib modules, Req, epgsql | VERIFIED |
| 10 | The OTP release is itself an undeclared dependency | p03, p17 | `:json` is non-existent on this OTP 25. Exemplar 25f (`using :json`) still compiles, exit 0. No application name would record this; `.tool-versions` does | VERIFIED |
| 11 | Presence on the path is not readiness | p13 | `ticker` on the path, never started: `Cold()` gives `crashed: exit:{noproc,{gen_server,call,[ticker_srv,get]}}`. After `:application.ensure_all_started(:ticker)` in the program, `Warm()` returns `42` | VERIFIED |
| 12 | An application atom is unambiguous beside a module atom | p11 | **12 of 27** applications on the path own a module of the same name (`ssl`, `inets`, `mnesia`, `crypto`, `kernel`, `elixir`, …). A bare `using :ssl` could mean either | CONFIRMED as a number. No ticket claimed the atoms are unambiguous, and it matters only for the bare `using :app` spelling, which the yecc count already rejects |
| 13 | The grammar can carry an application | p12 | Baseline 6 shift/reduce on this yecc. `using :M in :app { }` 6; new keyword `using app :x` 6; `[app: x] using …` 6; bare `using :app` **7**. Scratch copies of `bs_parser.yrl`; first run of this probe was vacuous (productions landed after `Erlang code.`) and is kept as `p12…first_run_vacuous.out` | VERIFIED |
| 14 | A new keyword `app` is not free | grep | `wayfinder/prototypes/51a-code-path/Req/req.bs:44` has a parameter `atom app`; `fn` and `raise` already left the variable namespace this way (`bs_lexer.xrl`) | VERIFIED |
| 15 | A presence check is cheap | p05 | `code:which` on an *absent* module: 0.5-0.6 ms (30 path entries); 3-5 ms (236 entries). 14 absent modules: 8-9 ms and 40-60 ms (the two runs disagreed; min/max in `.out`). Present + `.app` read, 8 modules: ~0.5 ms. "Present" figures are for already-loaded modules; I did not time a cold one | VERIFIED |
| 16 | Recording the app in the `.beam` is cheap and readable | p14 | `-bs_requires([libdep])`: +52 bytes (one app), +76 (three); `beam_lib:chunks(B,[attributes])` reads it without loading | VERIFIED |
| 17 | A check keyed on `code:which` misfires on build order | p06 | `my_helper.erl` exists beside the project, not compiled yet: `code:which(my_helper) = non_existing` | VERIFIED |
| 18 | The compiler already has a slot for a warning | `bs_diag.erl:1017` etc. | warnings exist beside errors (unreachable arm, unreachable clause) | VERIFIED (read) |
| 19 | Real Req 0.7.3 and its 9-package tree | — | hex.pm refused | **UNVERIFIED** here; stand-in only |
| 20 | `code:which`/`ERL_LIBS` behave the same under the built `bsc` escript | — | I ran `bsc:main/1` from a code path, not the rebar3 escript | **UNVERIFIED** (51 measured `ERL_LIBS` through the escript) |

## Survey

Erlang and Elixir sources are not installed here (only `ebin/`), so I cite measured output, not file:line.

- **Erlang** (p08). `erlc` accepts a remote call to a module that is nowhere (exit 0, no warning); `xref` reports it
  (`undefined_function_calls: {ok,[{{calls_missing,go,0},{libdep,hello,1}}]}`). The one place Erlang puts an
  *application name in source* is `-include_lib("libdep/include/libdep.hrl")`: absent, that is an **error**,
  `can't find include lib`; present (`stdlib/...`) it compiles. Name only, no version, resolved through the code path.
- **Elixir** (p07, p07b, p18). Without a manifest entry, `elixirc` *warns*: `Libdep.hello/1 is undefined (module Libdep
  is not available or is yet to be defined)`. A typo warns identically. Under `mix`, the warning is keyed on the
  **application**: `Libdep.hello/1 defined in application :libdep is used by the current application but the current
  application does not depend on :libdep`, with three fixes and an exclude list; declared in `deps:` it is silent. So
  Elixir's check is module to application to declared list, name only, **warning**. Its only in-source declaration is
  `Mix.install/2` for scripts (docs chunk, p18: "Installs and starts dependencies").
- **Gleam** (p09). `@external(erlang, "libdep_not_there", "hello")` builds (exit 0) and dies at run time, `A function was
  called but it did not exist`: today's B# behaviour exactly. A missing *Gleam* import is refused at compile time
  (`error: Unknown module`, p09); that dependency graph is declared in `gleam.toml`, not in the source.
- **Elm** (p10). **UNVERIFIED**: package.elm-lang.org is refused. The one message obtained said `MISSING DEPENDENCY …
  elm.json`, (Correction after verification: that run had an incomplete `elm.json`; it is not evidence that Elm checks imports against a manifest. Treat Elm as no data.)
- **B# side** (read): `bs_parser.yrl:170` (the one foreign production, a 4-tuple `{foreign, L, Mod, Sigs}`);
  `bs_check.erl:615, 633, 1054, 1092` (the four sites that match that 4-tuple); `bs_emit.erl:73-78` (module
  attributes); `bs_api.erl:60` ("read and never built"); `bs_lexer.xrl:131` (quoted atoms lex);
  `editor/tree-sitter-beam-sharp/grammar.js:183` (the second grammar).

## Measurements

The numbers are in the table (rows 8, 9, 15, 16). Two not in it. The compile-time work is small: an absent-module
diagnostic costs one `code:which` per distinct foreign module (14 in the whole corpus). Elixir-stdlib touches are the
only place repetition bites: any Elixir-library binding that also calls `Application`, `Enum` or `String` needs
`elixir` beside the library's own application.

## Options for the gating question

All three keep `bsc` building nothing and resolving nothing. Programs use the `libdep` stand-in where I ran them.

### A. No source change. The compiler checks that each foreign module is on the code path

```csharp
module Fetch

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

**Compiled form:** unchanged. **Author sees** (new, warning): `fetch.bs:3: warning: module 'Elixir.Req' is not on the
code path`. **Compiler delta:** a pass in `bsc.erl` between parse and check that collects the `{foreign,…}` modules and
calls `code:which/1`; one `bs_diag` tag with its F16 term, prose, and an entry in the F47 per-tag wire roster; skipped
in `--api` (p16 shows `--api` is environment-free today). No grammar, no tree-sitter change. **Measured:** p02 D/E
(typo compiles today), p05 (cost), p17 (25f would warn on OTP < 27).

**Strongest counterargument:** it does not do what the ticket asked. The source still says `'Elixir.Req'` and nothing
else, so a clean-room recipient cannot tell from the file that `req` is the application, and the diagnostic cannot say
what to install when the module is absent. Guessing the application from the module atom fails on the commonest case:
`Elixir.String` lowercases to `string`, and p04 shows it lives in `elixir`.

### B. The block names its application: `using :M in :app { … }` (per block)

```csharp
module Fetch

using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}

using :'Elixir.Application' in :elixir {
    term ensure_all_started(atom app)
}

using :maps {                      // OTP: stdlib. No `in` needed.
    term get(atom k, term m)
}
```

**Compiled form:** unchanged by default; optionally one `-bs_requires([req, elixir])` attribute (+76 bytes for three,
readable with `beam_lib`). **Author sees** (p06, run on real files with a scratch parser that accepts this spelling):

```
dep.bs:3   'Elixir.Libdep'  declared=libdep   ok     module is in declared application libdep
wrong.bs:3 'Elixir.Libdep'  declared=libdpe   ERROR  declared `in :libdpe` but the module belongs to application libdep
noapp.bs:3 'Elixir.Libdep'  declared=none     NEEDS  module is in application libdep, which is not OTP: write `in :libdep`
(ERL_LIBS unset)  ... ERROR module 'Elixir.Libdep' is not on the code path; declared application libdep is not on the path either
```

(The prototype labels every failure ERROR or NEEDS; the recommendation below downgrades most to warnings.)

**Compiler delta:**
1. One production (`'using' atom_lit 'in' atom_lit '{' foreign_sigs '}'`), **0 new conflicts** (p12), no new keyword
   (`in` exists). Emit a separate `{requires, L, Mod, App}` decl and leave the 4-tuple `{foreign,…}` alone, so the four
   `bs_check` sites are untouched.
2. The pass from A, plus: the application of a present module (the `*.app` beside its beam; `preloaded` means `erts`);
   compare with the declared one; closure walk over `applications` (p15). A module found under `code:lib_dir()`'s
   root needs no `in`.
3. `bs_diag`: three tags (absent, mismatch, closure-missing) with F16 terms, prose and F47 wire entries.
4. `tree-sitter-beam-sharp/grammar.js:183`, LANGUAGE.md §11 with `diagnoses:` blocks. Gate fixtures are hermetic:
   absent-module needs no fixture, mismatch and closure need two tiny fake application dirs (as in
   `setup.sh`). No network and no Elixir.
5. Optional: `bsc --api` lists `applications` (`bs_api.erl:60`), which is the field a handoff reader would want.

**Measured:** rows 5-9, 13, 15-17.

**Strongest counterargument:** it duplicates what each application's own `.app` already says, and adds a second thing
that can be wrong (`in :libdpe` is caught only if the module happens to be present). Elixir gets by with a manifest
plus a *warning* and no per-call annotation. And every Elixir binding writes `in :elixir` on each block that touches
`Application`, `Enum` or `String`.

### C. The module names its applications once, in `index.bs`

```csharp
// index.bs
module Fetch
using app :req, :elixir            // spelling provisional, see below

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

**Compiled form:** as B. **Compiler delta:** as B, plus the check "a non-OTP foreign module belongs to a listed
application" and "a listed application has no module using it" (one more diagnostic); a `requires` decl per listed
app instead of per block. F15 already puts `using`, `type`, `record`, `behaviour` in `index.bs`.

**The spelling is the real cost, and it is measured.** Bare `using :req` is **ambiguous** (row 12: 12 of 27 applications
share a module's name) and adds a yecc conflict (7 vs 6). `using app :req` parses with no new conflict but makes `app`
a keyword, which breaks the repo's own `atom app` parameter (51a `req.bs:44`) and is a ticket-65 reservation. `[app: req]`
parses but introduces the language's first attribute, which ticket 32 cited as if it existed.

**Strongest counterargument:** the provenance sits away from what it qualifies. A reader of `using :'Elixir.Req' { … }`
has to look in `index.bs` to learn which application that is, which is exactly the read cost ticket 32 said to pay
write cost to avoid.

## Recommendation

**Answer the gating question "yes, the source names the application", with Option B.** Reasons, each from above:
the ticket's own argument (a program whose dependencies live only in the environment cannot be handed over) needs the
application name in the file, which A does not supply (row 4, the `Elixir.String` example); B has a measured grammar
cost of zero and no reserved word, where C needs a keyword, a bare atom that collides, or a construct the language lacks
(rows 12-14); and B keeps the application next to the module it qualifies.

Defaults for the follow-ups, to be asked *after* the gating answer and open to David:

- **Severity (2): a warning for "not on the code path" and for closure gaps; an error only for a declared application
  that does not match the module's actual one.** Mismatch needs the module present, so it cannot be a build-order
  artefact; absence can be (row 17), and the repo's own exemplar 25f would go red on OTP < 27 (row 10). Elixir's check is
  a warning (p07b).
- **Depth (3): walk the closure.** Checking only the named application leaves the `undef` of row 5 in place.
- **Version (4): none.** Row 7; the name is what a neighbour's manifest resolves.
- **Start (5): declaring does not start.** Row 11. Starting is program logic, as 51a's `Start()` does it; making the
  declaration start applications is the first step toward the package manager 51 refused.
- **OTP implicit:** a module resolved under OTP's own `lib` needs no `in`; one may still be written and is checked.
  25 of 30 corpus blocks would otherwise carry ceremony that tells the reader nothing.

## Open risks

- **B versus A is a judgement, not a measurement (verifier).** No probe shows A is worse for a clean-room handoff; B rests on the ticket's handoff argument plus a cheap grammar. Rows 1 and 12 were framed as refutations and are not evidence either way.
- **p06 models the parser change with a 5-tuple `{foreign,..,App,..}`**, which contradicts delta 1 (leave the 4-tuple, emit a separate `{requires}` decl). The parser already splices lists (`bs_parser.yrl:74`), so delta 1 is feasible but untested.
- **p15's closure walk over-approximates** (flags `logger`, not needed). The census count of 4 repeated blocks comes from `p03_census_with_elixir_libs.out`; the default output says 5. Yecc conflict counts are OTP 25 only. The C comparison did not try reusing the `in` token.

- **The 1-line claim is refuted and the rest of the ticket's three sub-questions are only partly settled by the corpus.**
  Two third-party blocks cannot decide per-block vs per-module; the Elixir-stdlib repetition is the only signal.
- **Severity interacts with the editor and the handoff.** A warning per un-built dependency will show in `ibs` and the
  LSP on every machine without deps; an error would make `check-examples.sh` and the handoff package depend on the
  environment (51 already flagged the first network-dependent gate). Not measured.
- **Deriving the application from the `.app` beside the beam** is sound for mix, rebar3 and OTP layouts (row 6). A
  hand-written `.app` with an empty `modules` list would break the `modules`-scan method, which is why the prototype
  reads the `.app` in the same `ebin` and does not scan `modules`. Not exercised with rebar3 output (no rebar3 here).
- **Interaction with ticket 106's alias** (`= :'get!'`, unbuilt, ENG-250): `in :app` and `= :'atom'` sit in different
  positions of the same entry, but I measured no grammar with both.
- **The OTP release is an undeclared dependency** (row 10) that no application name captures; today `.tool-versions`
  carries it. A `stdlib` version would be the only spelling, and row 7 says versions are out.
- **`code:which` under the real `bsc` escript** and **Req itself** are UNVERIFIED (rows 19-20).
- Probe-hygiene log: eight probes were corrected after a first run (all probe bugs, none a changed expectation), and each first run is kept beside its fix
  (`*.first_run_*.out`): p03 format crash, p06 `-pa` order, p08 missing `+debug_info`, p10 incomplete `elm.json`, p12
  vacuous productions, p13 `_started` parameter name, p15 unbuilt syntax, p18 module not loaded. A first p17 tried to
  compile exemplar directories that do not compile standalone; it was replaced, not kept.

## Reproduce

From a clean shell, with `erl`, `erlc`, `elixir`, `mix`, and `/tmp/tools/{gleam,elm}` present:

```
cd /home/user/beam-sharp/artifacts/52/probes
./setup.sh      # fixtures in /tmp (mix libdep, acme-1.2.0/1.3.0, ticker, 200 dirs); builds bsc into /tmp/bsc52
./run-all.sh    # reruns every probe and rewrites each .out (p03, p05 figures vary by machine and run)
```

One by one (each after `setup.sh`):

| Probe | Command |
|---|---|
| p01 code path | `env -u ERL_LIBS escript p01_code_path.erl; ERL_LIBS=/usr/lib/elixir/lib escript p01_code_path.erl` |
| p02 baseline | `./p02_baseline.sh` |
| p03 census | `escript p03_census.escript` |
| p04 module to app, two versions | `ERL_LIBS=/usr/lib/elixir/lib:/tmp/mixdeps52b/consumer/_build/dev/lib:/tmp/fakelibs52 escript p04_module_to_app.escript` |
| p05 cost | `escript p05_which_cost.escript; ERL_LIBS=/usr/lib/elixir/lib:/tmp/manylibs52 escript p05_which_cost.escript` |
| p06 modelled check | `./p06_run.sh` |
| p06a undeclared call | `./p06a_undeclared_call.sh` |
| p07 / p07b Elixir | `./p07_elixir_undeclared.sh; ./p07b_mix_undeclared_dep.sh` |
| p08 Erlang | `./p08_erlang.sh` |
| p09 Gleam | `./p09_gleam.sh` |
| p10 Elm (unverified) | `./p10_elm.sh` |
| p11 app/module names | `ERL_LIBS=/usr/lib/elixir/lib:/tmp/mixdeps52b/consumer/_build/dev/lib escript p11_app_module_name_collision.escript` |
| p12 grammar | `./p12_grammar_conflicts.sh` |
| p13 started vs present | `./p13_present_is_not_started.sh` |
| p14 beam attribute | `escript p14_beam_attribute_cost.escript` |
| p15 closure | `./p15_transitive_closure.sh` |
| p16 `--api` | `./p16_api_is_environment_free.sh` |
| p17 exemplar 25f | `./p17_exemplars_with_absent_modules.sh` |
| p18 Mix.install doc | `elixir p18_elixir_mix_install_doc.exs` |
