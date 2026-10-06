# Brief — ticket 52, dependency provenance (ENG-234)

Ticket: `wayfinder/issues/52-dependency-provenance.md`. Status when written: open. Written 2026-10-06 against
`compiler/src` at HEAD (working tree clean of compiler changes; every compiler variant below is a patched
**copy** built in a scratch dir, never the repo). Nothing under `wayfinder/`, `compiler/` or docs was edited.

Probes live in `artifacts/probes/52/`; each `.sh` has a header naming the claims, a control that goes red if the
claim is false, and a captured `.out`. They were run by me; a verifier has not re-run them.

## The question, restated

51 showed `ERL_LIBS` alone reaches Req. 52 asks whether a `.bs` file should say which OTP **application** each
foreign module comes from, so a program is not a statement about the machine that happened to build it. The
destination is the clean-room handoff: a stranger gets `LANGUAGE.md`, the feature record and the example corpus
(`handoff/MANIFEST`), implements `bsc`, and is marked against the reference compiler.

## Four things in the ticket that are wrong or stale against the current tree

1. **The proposed syntax does not exist and cannot be "extended".** `[external: elixir, app: req] using :'Elixir.Req' { … }`
   is a syntax error at the `[` (p2 S2), and so is ticket 32's own `[external: erlang, "ets"] module Ets { … }` (S3) and
   `[module: GenServer]` (S5). The parser has **no declaration-level `[`** (S6: every `'['` production is a list, pattern
   or comprehension). Ticket 22 measured this on 2026-08-23 ("There is no attribute grammar, and there never has been",
   `22-how-opinionated.md:89`) and settled on keywords: `using :ets { }` and `behaviour GenServer` are what got built. So
   the real question is a *keyword-shaped* extension of `using :atom { }` (`bs_parser.yrl:170`), not an attribute.
2. **There is no `elixir` tag.** An Elixir module is written as its atom, `using :'Elixir.Req' { }`. That form compiles
   today (p2 S1), so `LANGUAGE.md:2946` ("quoted atoms are not lexed yet") is itself stale (`bs_lexer.xrl:131`
   lexes them; 51a and ticket 106 use them).
3. **"One line" understates the check, slightly.** The check itself is ~10 lines of `bs_check` (p8: 21 changed lines in
   `bs_check.erl` including the tuple-width plumbing, 7 in `bs_diag.erl`, 1 in `bs_emit.erl`, 5 to 8 in the parser).
   That is small; it is not one line.
4. **The ticket's central claim is TRUE and is the thing to keep.** A missing application compiles cleanly and dies
   `error:undef` at the call (p1 C1/C2, control C3 with the app present returns 42). Worse than the ticket says: the
   compiler checks nothing about a foreign declaration's *existence at all*. A function that exists nowhere in a module
   that does (`:lists.nope/0`) and a module that exists nowhere both compile (p1 C5, C6), and the `.beam` is the same
   whether or not the app is present (C4, compared with `beam_lib:cmp`; raw bytes differ only because `compile_info`
   embeds the `-o` path).

Ticket 50, the one 52 asks to be sequenced with, is **resolved** (a foreign struct is a `map<atom, term>`, no new
surface), so there is no second design to collide with. The other pending extension of the same construct is
ticket 106's per-entry alias `term GetOrCrash(binary url) = :'get!'` (resolved, unbuilt, ENG-250). It adds to an
*entry*; anything here adds to the *header*, so they do not compete for a grammar position.

## Sub-decisions, in the order they gate each other

1. **Does the source name the application?** Gates everything below. Ask this one alone.
2. *(if yes)* **What does `bsc` do with the name?** Nothing but record it, or consult the machine.
3. *(if yes)* **Where is it written?** On the `using` block, once per module, or as an attribute.
4. *(if yes)* **Is it required on every block?** (`:erlang` has no application; 29 existing blocks.)
5. **A version?** Not a question. Closed below with evidence; asking would reopen 51.

Ask 1. If David says no, 2 to 5 do not exist.

---

## Q1. Does a `using` block say which application its module comes from?

### Option A: no. Provenance stays with the neighbour's manifest (the status quo, and 51's answer)

```csharp
module Req

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Application' {
    term ensure_all_started(atom app)
}
```

Compiler delta: none. The handoff documents say "run under an `ERL_LIBS` holding req and elixir". Every neighbour works
this way (survey below): the dependency list is in a file beside the code (`.app`/`rebar.config`, `mix.exs`,
`gleam.toml`, `elm.json`) and the foreign call names no application.

**Strongest counterargument.** The application cannot be recovered from the module name, so a stranger holding only
the `.bs` file has to guess. Measured over every `.app` in OTP 28 and Elixir 1.20.4 (p3 D5, method: read each
`modules` list, N = 1,279 OTP modules and 413 `Elixir.*` modules): the module name equals the app name for **2.0 %** of
OTP modules, and the first segment of an `Elixir.*` module (snake_cased or lowercased) equals the app for **42.4 %** of
them (237 of the 238 misses are the one app `elixir`, which owns `Access`, `Enum`, `Application`, `Agent`…; the
heuristic fails exactly on the library everyone calls first). The corpus already has an instance: exemplar 25d
declares `using :epgsql { … }` (`compiler/examples/exemplars/25d-database-querying/index.bs:12`), a non-OTP application
named nowhere in the tree, and `code:lib_dir(epgsql)` is `{error,bad_name}` on this machine (p3 D6).

### Option B: yes, per block (spelling is Q3; shown here as `in :app`)

```csharp
module Req

using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Application' in :elixir {
    term ensure_all_started(atom app)
}
using :maps in :stdlib {
    term get(atom k, term m)
}
using :erlang in :erts {
    int system_time(atom unit)
}
```

This module compiled and ran under a patched copy of the compiler with all four applications present (p10 R2: prints
`:post`). Compiler delta, measured on the patched copy (p8): `foreign` AST node gains a fifth element (`{foreign, L,
Mod, Sigs, App}`, four match sites in `bs_check` updated), one `apps_on_code_path/1` pass, one diagnostic clause in
`bs_diag`, one attribute form in `bs_emit`, one production in `bs_parser.yrl`. Total 34 to 37 changed lines depending on
spelling. The yecc conflict count is **232 before and 232 after** for all three spellings (p8 P4). All 34 module
directories under `compiler/examples` compile to `beam_lib:cmp`-identical beams under stock and each patched
compiler (P5; 7 of the 34 are refused by stock itself and are refused identically). The editor grammars would also
need the production: `editor/` holds five targets (tree-sitter `grammar.js`, nvim, syntect, vscode, zed) and F44 shows
`editor/bin/check-corpus.sh` is the gate that notices (counted, not changed or measured here).

**Strongest counterargument.** No neighbour does this (survey): Erlang, Elixir, Gleam and Elm all keep the application
off the foreign call. B# would be the first language to hang a package name on an FFI declaration, with no precedent
to borrow; and it extends `using` while 106 is also extending it. The cost of being wrong is a syntax users must unlearn.

**My lean: B.** The handoff argument in the ticket survives measurement (D5: the app is not derivable, and 25d already
needs one). Both options are cheap; the asymmetry is that A leaves the stranger guessing.

---

## Q2 (if Q1 = yes). What does `bsc` do with the name?

### Option 1: record it, never consult the machine

Compiler delta: the `-bs_needs([req,elixir,stdlib,erts])` module attribute (emitted after `behaviour` forms in
`bs_emit:forms/1`, `bs_emit.erl:78`), no new diagnostic. Measured on the 51a Req binding rebuilt by `bsc` (p9 Z1, N = 3
compiles per variant, all stable): baseline 1,728 bytes; one app adds **36 bytes**, three **60**, nine **152**, twelve
**180** (roughly 12 to 14 per extra name; the attribute lands in both the `Attr` and `Dbgi` chunks). As an exported
function `'bs@needs'/0` it is 72 / 96 / 200 / 232 bytes, so the attribute is the cheaper encoding. For scale, the
existing per-module `bs@type_atoms/0` costs 108 bytes. Per-block repetition (three `{Mod,App}` attributes) is +136
bytes. It is readable without loading the module: `beam_lib:chunks(Bin,[attributes])` gave `bs_needs = [req,jason]`,
and the stock beam gives `undefined` (Z5, control). A `--api` field would show it in query mode (not built).

```
$ bsc --src-root R -o out Req          # req absent from ERL_LIBS
(no output, exit 0; out/Req.beam carries -bs_needs([req,elixir,stdlib,erts]))
```

**Strongest counterargument.** It is an unchecked claim, which is the exact shape ticket 18 refuses at the FFI boundary
and ticket 32 §8 is proud to diverge from ("because 18 checks, beam-sharp emits the `-spec` … and unlike Gleam's it is
not a lie"). Nothing stops `using :lists in :ssl`. And it does not deliver the thing the ticket promised: `undef` at the
call site is unchanged.

### Option 2: record it and refuse at compile time when the application is not on the code path

```
$ ERL_LIBS=<elixir lib only> bsc … Req
src/Req/Req.bs:2:1: error: application `req` (needed by :'Elixir.Req') is not on the code path
  add its lib directory to ERL_LIBS, or remove the declaration
```

(real output of the patched compiler, p10 R3; the same source under the stock compiler compiles and then dies
`crashed: error:undef`, R3b). Delta: `bs_check:apps_on_code_path/1` calling `code:lib_dir(App)` and a `bs_diag` clause.
`code:lib_dir/1` costs 3.9 µs a hit and 3.5 µs a miss (p9 Z7, 2,000 calls); whole-compile time is not distinguishable
from noise (p9 Z6: min of N = 15 was 6.4 ms stock-rebuilt vs 7.3 ms patched, medians 9.4 vs 8.8 ms; the machine was
under load average 14 to 34, so read this as "no large effect", not a measurement of a small one).

A stronger check than name-only is also decidable: "module M's beam lives under app A's lib dir". It is true for the
real pair, false for `lists in ssl` and for `fakelib_mod in stdlib`, and `erlang` (preloaded) needs a special case
(p3 D7). That catches the false claim Option 1 cannot. Not built into the compiler; shown in `erl` only.

**Strongest counterargument.** The verdict is a fact about the compile machine, not the source. One query,
`code:lib_dir(fakelib)`, returns `{error,bad_name}` with `ERL_LIBS` unset and `".../fakelib-1.0"` with it set (p3 D1);
it keys on the **directory name**, not the `.app` file (D3: a dir with `ebin/` and no `.app` counts as present; a dir
whose `.app` says another name is not found under that name); and a plain `-pa` directory runs the module (51 measured
beams "copied to a plain directory work identically") while `lib_dir` says `bad_name` (D2), so the check refuses a
program that runs. Three consequences for this repo specifically:

- **The artefact is currently independent of the environment** (p1 C4). Option 2 makes `bsc`'s accept/refuse depend on it.
  That bears on the handoff: the audition marks a worker's diagnostic **tag set** against the reference compiler's
  (`handoff/audition-switch/CONTRACT.md`, "Marking"), and the worker runs with "no network and no package installs".
  Any case naming a non-OTP app would get a different tag on the two machines. The existing audition cases are
  `switch` diagnostics and name no foreign app, so nothing breaks today; but the spec would owe a sentence that
  `app_not_on_code_path` is excluded from marking, and `LANGUAGE.md` ("compiled by CI block by block") could not carry a
  block naming a non-OTP app without that app on CI.
- **51 already warned that an exemplar binding Req makes CI fetch nine packages.** Under Option 2 *compiling* the Req
  exemplar needs them; under Option 1 only *running* it does.
- **B# has no warning class**, so Elixir's softer behaviour is unavailable: `bs_diag.erl` has 55 `severity => error`
  sites and none that is a warning. Softening it is a new concept, not a flag.

**My lean: Option 2 with the name-only presence check, error severity.** Reasons: the language's own stance is that a
declared claim gets checked (18, 32 §8), and the measured cost is nil. Ecosystem flows that produce `.beam`s already
have the dependencies present when they compile (rebar3 and mix fetch first; 51), and Elixir and `systools` both
check at build time. I would take the larger check (module under app dir) later, on a second occurrence of a wrong
declaration (CLAUDE.md's rule for new gates). I am less sure of this than of Q1: if David weighs "`bsc` is a pure
function of the source" above the diagnostic, Option 1 is the honest answer, and the diagnostic can come later as a query
(`bsc --api` listing each needed app and whether it resolves; unprototyped).

---

## Q3 (if Q1 = yes). Where is the name written?

All three were built as patched copies and run (p8: stock refuses each, patched accepts each; with the app present each
prints 42; with it absent each is refused at compile time).

### Option 1: on the block, `using :M in :app { }` (no new keyword; `in` already exists, `bs_lexer.xrl:54`)

```csharp
using :fakelib_mod in :fakelib {
    int hello()
}
```
Parser delta: 5 changed lines (one production, `foreign_decl -> 'using' atom_lit 'in' atom_lit '{' … '}'`).

### Option 2: once per module, `needs :app`

```csharp
needs :fakelib

using :fakelib_mod {
    int hello()
}
```
Parser delta: 7 changed lines, and `needs` is a new contextual word (`decl -> lident atom_lit`, checked in the action;
zero new yecc conflicts). It cannot say which block's module comes from which app, so a reader of
`using :'Elixir.Application'` cannot see that it is `elixir`.

### Option 3: the ticket's attribute, `[app: fakelib] using :fakelib_mod { }`
Parser delta in my prototype: 8 changed lines, **because it special-cases the word `app`**. That is not a general
attribute facility. Ticket 22 priced that at "a lexer rule, a `decl` arm, an AST node and a checker pass" and chose
keywords, so this is the option that reopens a settled question.

**Strongest counterargument to Option 1.** A library with many modules repeats its application on each block
(`Req`, `Req.Test`, `Req.Request` are all app `req`). The ticket calls this "the kind of write-cost the standing
constraint prices as near-free but the reader pays for". In the Req binding written for 51a (p10) no application
repeats: four blocks, four applications (`req`, `elixir`, `stdlib`, `erts`), because a module belongs to exactly one
application (it is a member of exactly one `.app`'s `modules` list). So per-block is only redundant for a binding that
reaches several modules of one library.

**My lean: Option 1**, because it is the only spelling that adds no word to the language, matches the rule that a
foreign block names one module, and puts the application on the line a reader is already reading.

---

## Q4 (if Q1 = yes). Required on every block?

### Option 1: required

All 18 `using :atom` blocks under `compiler/examples` and the 11 in `LANGUAGE.md` would need an edit (p10 R5), and
`:erlang`, the module in 8 of those 18, belongs to **no application**: it is preloaded (`application:get_application(erlang)`
is `undefined`, `code:which(erlang)` is `preloaded`; p3 D6). The only spelling that works is `in :erts`, and the
natural guess `in :erlang` is refused (p10 R4, control). The rule is purely syntactic, so it is the same on every
machine: a recipient can implement it without an environment and the audition could mark it.

### Option 2: optional; written where the module is not part of the always-present OTP applications

`using :lists { … }` stays as it is. Reading cost stays low on the most common blocks (`using :lists in :stdlib` adds
a clause to a line that already names `lists`).

**Strongest counterargument to Option 1:** noise on every `:lists`/`:maps` block, for a fact that is true of every BEAM.
**To Option 2:** provenance is incomplete by construction and nothing says which omissions are deliberate; an
agent can omit it for a non-OTP module and compile cleanly. Under Q2's Option 2 the omission is also exactly the case the
check cannot see.

**My lean: Option 1 (required).** This is the weakest of my recommendations. The deciding point is that it is the
only variant whose rule needs no environment, which is what the handoff wants, and the churn is mechanical.

---

## Q5. A version: closed, not asked

The ticket says a version "is resolution and should stay refused". The evidence supports that without reopening 51:
OTP records **names** in the `.app` and versions elsewhere. Installed examples: `ssl.app:101`
`{applications, [crypto, public_key, kernel, stdlib]},` and `inets.app:100` `{applications,[kernel,stdlib]},`; the exact
versions live in the release file that `systools:make_script` consumes (p5 E2, `{release,…,[{kernel,"10.6.3"},…]}`, my
fixture). Gleam splits the same way: `gleam.toml` declares, `manifest.toml` locks (p6 G5). B# is on the library side of
that line, and the compiler's own `bsc.app.src:5` lists `{applications, [kernel, stdlib, compiler, syntax_tools]}`
with no versions.

---

## How neighbouring languages solve it (what each records, where, and when it checks)

None puts the application on the foreign declaration. Where Elixir or Gleam sources would be quoted, none is installed:
only `.beam`s for Elixir, the compiled `gleam` binary, and the Elm binary. Behaviour is shown by running, and no
file:line is cited for them.

| | Records | Where | Checked | Probe |
|---|---|---|---|---|
| Erlang/OTP 28 | `{applications,[…]}` (names) | `.app` (`systools_make.erl:734` `check_item({_,{applications,Apps}},I)`; `application.erl:85`) | `systools:make_script` refuses (`systools_make.erl:824`, `:2386` "Undefined applications"); `erlc` checks nothing; `xref` flags `undefined_function_calls` only if asked; `ensure_all_started` returns a value naming the missing `.app` | p5 E2, E5, E4, E3 |
| Elixir 1.20.4 | `deps` in `mix.exs`, copied to the generated `.app` (`{applications,[kernel,stdlib,elixir,logger,liba]}`) | `mix.exs` | compile-time **warning**: "LibA.hi/0 is undefined (module LibA is not available…)"; and `ERL_LIBS` alone does **not** satisfy it, mix prunes to the manifest | p4 M1 to M3 |
| Gleam 1.18.1 | `[dependencies]`, `extra_applications` copied to the `.app` (`{applications, [dep, inets]}`); `manifest.toml` locks | `gleam.toml` | nothing about `@external(erlang, "fakelib_mod", "hello")`, which names a module in no declared app and compiles | p6 G1 to G5 |
| Elm 0.19.3 | `dependencies.direct/indirect` | `elm.json` | refuses an `elm.json` missing `elm/json` before fetching; the import-vs-declared check **not probed** (needs the registry, blocked) | p7 L1 to L3 |
| B# today | nothing | nothing | nothing | p1 |

The nearest analogues of Q2's Option 2 are Mix's warning and `xref`, both against a manifest or an explicit path set,
never against whatever happens to be installed. `rebar3` is not installed here, so `rebar.config`/`.app.src`
behaviour was not run; `bsc.app.src:5` is the only rebar-side evidence cited.

## Interaction with the clean-room handoff

- The package ships spec, feature record and corpus, never the compiler (`handoff/MANIFEST`), so a recipient writes
  `bsc`. Whatever Q2 chooses becomes a conformance clause they implement. Option 1 (record) asks them to emit an
  attribute. Option 2 asks them to call `code:lib_dir` against *their* machine, and the spec must say the diagnostic is
  excluded from tag marking.
- The corpus is "the oracle". It already names a non-OTP application (`:epgsql`, 25d, not compiling today for an
  unrelated reason: out-of-slice, "no `module` line"). Under Q1 = yes + Q4 = required, 25d gains `in :epgsql` and a recipient
  can see which library the exemplar needs; under Q2 Option 2 they must also have it installed to compile it.
- `check-handoff-package.sh` question 6 compiles the package's examples against the reference compiler, so with
  Option 2 the author's machine must have each named app. No example that compiles today needs this (25d, the only one naming a non-OTP app, is out of slice).

## Probe index

| Probe | Claim | Result | Control |
|---|---|---|---|
| `p1_missing_app_surfaces_at_call.sh` | absent app compiles clean, dies `error:undef` at call; beam identical either way; nonexistent function / module also compile | held | same source with app on `ERL_LIBS` prints 42; beam of a different program does not compare equal; a real syntax error is refused |
| `p2_ticket_syntax_is_stale.sh` | ticket's `[external: …, app: …]`, 32's `[external: …] module`, `[module: …]` are syntax errors; no declaration-level `[` in the grammar | held | the shipped `using :'Elixir.Req' { }` is accepted |
| `p3_name_check_decidability.sh` + `p3_census.escript` | `lib_dir` verdict flips with `ERL_LIBS`; module-present/app-absent disagree; keys on dir name; app not derivable from module name (2.0 % OTP, 42.4 % Elixir); `erlang` has no app; membership check decidable | held | present-case and wrong-pair cases in the same script |
| `p4_mix_records_dependencies.sh` | mix copies deps into `.app`; compile-time warning when absent; `ERL_LIBS` alone doesn't satisfy mix | held | declared case has no warning; plain `erl` does see the module |
| `p5_erlang_prior_art.sh` | `.app` `applications`; `systools` refuses at release time; `erlc` silent; `xref` flags; runtime returns a value | held | each has its present-case twin |
| `p6_gleam_records_dependencies.sh` | gleam.toml deps → `.app`; `@external` names no app and compiles; manifest.toml | held | removing the dep empties `applications` |
| `p7_elm_records_dependencies.sh` | only what runs offline: elm.json is the record, refused before any fetch | held (narrow) | network-dependent steps fail visibly, recorded |
| `p8_prototype_cost.sh` + `patch_compiler.py` | three spellings parse, check, emit; stock refuses all three; 232 yecc conflicts unchanged; 34/34 example modules identical; 34 to 37 changed lines | held | stock compiler is the control; absent-app run is refused at compile time |
| `p9_beam_size.sh` + `p9_beam_size.escript` | +36 bytes first app, ~+12 to 14 each; attribute cheaper than function; compile-time noise; `lib_dir` 3.9 µs | held | stock beam has no `bs_needs`; determinism (3 compiles equal) |
| `p10_realistic_binding.sh` | four-block Req binding compiles with 4 distinct apps; absent `req` refused at compile time; `:erlang` needs `erts` | held | stock compiles and dies `error:undef`; `in :erlang` refused |

## Not verified

- **Real Req / hex packages.** hex.pm is blocked, so `req` in p10 is a six-line stand-in with the same module name.
  51's measurements of the real tree were not repeated.
- **Elm's import-vs-declared-dependency check** (needs the package registry). Only elm.json handling that runs offline
  was observed (p7).
- **No Elixir, Gleam or Elm source lines are cited**: none is installed. Behaviour was run; mechanisms are not claimed.
- **`rebar3`, `rebar.config`, `.app.src` expansion** not run (rebar3 not installed). `mix.lock` not inspected.
- **Hex package name vs application name divergence** (not probed; relevant if the name were ever fetched, which this
  design does not do).
- **Tree-sitter and the four other editor grammars** were counted, not patched; the "new production" cost there is
  unmeasured.
- **Option "module under app dir" (Q2)** and a **`--api` needs field** were not built into the compiler; only the
  membership test in plain `erl` (p3 D7).
- **Compile-time timing** was taken on a shared box at load average 14 to 34; only "no large effect" is claimed.
- The three compiler variants were not run against the compiler's eunit suite (`rebar3` missing); regression control
  is p8 P5 (34 example modules, beam-identical) plus the unchanged yecc conflict count.
- The patched compilers' check runs on the author's `ERL_LIBS`; I did not test a Windows or a releases-layout
  (`lib/<app>-<vsn>/ebin` under a release root) machine.
