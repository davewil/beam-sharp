# Decision brief: ticket 52, dependency provenance (ENG-234)

Prepared 2026-10-08 for a human decision. Nothing here resolves the ticket. Nothing under `wayfinder/`,
`compiler/` or Linear was touched; every claim below that is behaviour was executed, and its probe is
named. Probes live in `artifacts/probes/52/` (`run-all.sh` reruns them; each prints its own result and
`*.out` is the captured output). The compiler used is the OTP 25 scratch build with a lexer shim
(diagnostic COLUMNS are wrong, shown as `:1`; parser, checker and emitter are byte-identical to
`compiler/src`, checked with `cmp` for the four files patched here).

## 1. The question

`using :'Elixir.Req' { ... }` names a module and says nothing about the application `req`. Does a `.bs`
file record what it needs, and if so where? The ticket's candidate is `[external: elixir, app: req] using ...`.

## 2. Stale premises (checked against the current compiler and tickets)

| # | Ticket says | Now | Evidence |
|---|---|---|---|
| S1 | The candidate is `[external: elixir, app: req] using :'Elixir.Req' {...}` | **B# has no attribute syntax.** The `[ ... ]` prefix is a syntax error, and so is any `[app: req]`. Ticket 32's `[external: erlang, "ets"] module Ets` form never shipped; what shipped is `using :M { }` (LANGUAGE.md:2986 "attaches types to the name Erlang already has"). The `external: elixir` half is also redundant: the `Elixir.` prefix on the atom already says it. | `p2-syntax-census.out` (AttrApp, AttrOnly refused; PlainQuoted accepted) |
| S2 | "Sequence it with ticket 50" | Ticket 50 is **resolved** (2026-08-26): a foreign struct is a `map<atom, term>`, no new surface, so it adds nothing to the construct. The live sibling is **ticket 106** (resolved 2026-09-25, **unbuilt**): a per-entry alias `term GetOrCrash(binary url) = :'get!'` on the same `using` block. That one extends the same construct and is the one to sequence with. | 50 `## Decisions entry`; 106 `## Decisions entry`; `p2-syntax-census.out` AliasT106 refused (unbuilt) |
| S3 | The presence check "would be the first thing `bsc` does with a dependency" | `bsc` already checks and compiles dependencies named by the **native** form: `using Nope.Gone` is refused at compile time ("names no module and no namespace"), and a present module is compiled and emitted. Ticket 41 §1 already says "a file's `using` lines are its dependency list". The difference is that the native check is keyed on `--src-root` (an explicit argument), not on an ambient environment variable. | `p17-native-using-precedent.out`; `bsc.erl:617`; 41 `## Decisions entry` |
| S4 | The check "turns a run-time `error:undef` into a diagnostic"; the declaration is what enables it | **The check needs no declaration.** A bare `using :'Elixir.Enum' { }` with no app named is refused by the same check ("module is not on the code path"). The ticket bundles two features that separate cleanly. | `p8-prototype-52x.out` (Noapp rows) |
| S5 | "It fails at the call site with `error:undef`" | Correct for **run** time, but note the compile verdict: today `bsc` accepts the file (exit 0, beam emitted) whatever the code path holds. The premise is true as stated; it is also the property any check would remove. | `p1-premise-undef.out` |
| S6 | (nearby, not the ticket's) LANGUAGE.md:3006 says quoted atoms "are not lexed yet" | They lex and compile today; every probe here uses `:'Elixir.X'`. A doc line to correct, not a decision. | `p1`, `p2` |

Not stale: ticket 51's measurement (`ERL_LIBS` alone reaches Req) and its non-decision; nothing in 51 is reopened.

## 3. Sub-decisions the ticket implies, and what gates what

1. **Q1 (gating, ask alone): may `bsc`'s accept/refuse on a `.bs` file depend on what is on the machine's code path?** Today it cannot: the same source gives a byte-identical `.abstr` under three different `ERL_LIBS` (`p13`). Every "check at compile time" answer says yes. This gates all of Q2-Q5, because without a check the declaration only *records*.
2. Q2: does the source name an application at all (or is the module, already in the `.beam`'s imports, enough)? Gated by Q1 only in value, not logic: the check works with or without it (S4).
3. Q3: if named, per `using` block or once per module? Needs Q2.
4. Q4: required or optional? Needs Q2.
5. Q5: severity of a failed check (error or warning), and whether it runs in compile or as a separate step. Needs Q1.
6. Q6: where the record goes (an exported `bs@needs/0` like F55's `bs@type_atoms/0`, an `.app` file, or nowhere). Needs Q2.
7. Q7 (not asked here, ticket already leans the same way): a version. Name only; a version is resolution.

Ask Q1 first, as one program that compiles on one machine and is refused on another (section 5, option 1).

## 4. What the neighbours do (all executed or read from installed files)

| Language | Where the dependency is declared | What the compiler does with it | Evidence |
|---|---|---|---|
| Erlang/OTP 25 | Hand-written `applications` list in `<app>.app.src`/`.app`, outside the module | The `.beam` records only the called MFAs (`imports` chunk). Nothing compares them with `applications` at compile time; `xref` is a separate post-hoc tool and reports `undefined_function_calls`. | `/usr/lib/erlang/lib/ssl-10.9.1.3/ebin/ssl.app:85` `{applications, [crypto, public_key, kernel, stdlib]}`; `asn1.app.src:12`, `xmerl.app.src:42`; `p6-erlang-xref.out`; `p3-beam-records.out` |
| Elixir 1.14.0 | `mix.exs`: `deps` and `extra_applications` | The compiler maps each remote call to its owning application (via the code path) and **warns, exit 0**, if the application is not listed; an absent module is a different warning. The app list is also written into the generated `demo.app`. | `p5-elixir-mix-xref.out` (a, c, f). Surprise: declaring `:ssl` *after* a first compile in the same directory still warned; a fresh project was clean (b2). Elixir's compiler sources are not installed, so no `file:line` into them. |
| Elm 0.19.3 | `elm.json` | **Could not run**: `elm init` fails fetching the package list; the one hand-written `elm.json` probe stopped on a missing `elm/json` and says nothing about imports. No claim about Elm is made. | `p7-elm.out` |
| Gleam | **UNVERIFIED-NOT-EXECUTED** (not installed, not installable). The repo shows only that `@external(erlang, "lists", "keyfind")` names target, module and function and no application: `wayfinder/prototypes/32a_gleam_external.gleam:3`. Ticket 51:53-54 says Gleam "consumes hex directly". I found no `gleam.toml` evidence in the repo and assert none. | | |

Two things the neighbours show. (a) The two that do this at all keep the list **outside the module**, in a manifest the build tool owns; 51 decided beam-sharp has no such manifest. (b) The only compile-time cross-check (Elixir) is a **warning**, because the environment can legitimately differ from the author's.

Also measured: the compiler can derive module -> (application, version) from the code path with no source help (`p4-derive-app.out`: `lists` -> stdlib 4.3.1.3, `ssl` -> ssl 10.9.1.3, `'Elixir.Enum'` -> elixir 1.14.0). The control cases fail as they should: a module in a flat `-pa` directory has no `.app` and derives nothing, an absent module derives nothing, and `application:get_application(ssl)` returns `undefined` for an app that is installed but not loaded.

## 5. Options, as programs

All three use the same realistic program. The Req stand-in is Elixir's own lib dir (`/usr/lib/elixir/lib`) because Req cannot be fetched here.

### Option 1: no source change; `bsc` checks that the module is present

```csharp
module Fetch
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
public term Go(list<(atom, term)> o)
Go(o) -> :'Elixir.Req'.new(o)
```

Accepted when `ERL_LIBS` reaches `req`; refused when not:
`error: module :'Elixir.Req' is not on the code path`. Same file, two machines, two verdicts.

**Compiler delta**: one pass over the foreign declarations in `bs_check:check_dir1/3` calling `code:which/1` (about 12 lines), one `bs_diag` tag. No grammar, no AST change.

**Measured**
- Prototype 52x (`patches/52x-app-clause-and-check.diff`) refuses the bare form when absent and accepts it when `ERL_LIBS` is set: `p8` (Noapp rows).
- Blast radius over this repo: 23 distinct foreign modules named across `.bs` files and `compiler/test/*.erl`, 13 of them **absent** on the default path (`p9-census.out`). Seven are fake names used by tests on purpose (`users_db`, `trees`, `session_store`, `store`, `m`, `analytics_db`, `accounts_db`: 13 occurrences, e.g. `compiler/test/foreign_return_tests.erl:83`), so a hard check breaks test fixtures that need to compile with a module that does not exist. Of the 18 `.bs` files with a foreign `using`, stock accepts and the prototype refuses 2 (`wayfinder/prototypes/51a-code-path/{Elx,Req}`): exactly the programs this is about.
- Cost: `code:which` is about 0.75 ms per call in-VM (`p10`), negligible against a 430-550 ms process. Compile wall time with the check on vs off is inside the spread in every pair (`p10-timing-size.out`; N=15, median/min/max reported; batches drift by about 100 ms between runs, so only the on/off pairs are comparable).
- No `.beam` size change.

**Strongest counterargument**: the verdict stops being a function of the source. Measured: `.abstr` is byte-identical across three `ERL_LIBS` today; the code-bearing `.beam` chunks too (`p13-verdict-purity.out`; the whole-file `.beam` differs only because `CInf` embeds the output path, a surprise noted in the probe). `compiler/README.md:272` leans on portability across OTP 24-28. The reference compiler is the oracle for a blind clean-room fleet, and an oracle whose answer depends on the fleet's install is a weaker oracle. It also does nothing for the stated destination: the source still says nothing about `req`.

### Option 2: per-`using` application clause, checked in compile (what the ticket sketched, spelled in the grammar that exists)

```csharp
module Fetch
using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Application' in :elixir {
    term ensure_all_started(atom app)
}
using :maps {                      // OTP: no clause needed
    term get(atom k, term m)
}
```

`in` is an existing keyword (comprehensions); the clause is optional. With `req` absent the diagnostic names it:
`module :'Elixir.Req' is not on the code path / this file says it belongs to application 'req'; is 'req' in ERL_LIBS or --lib?`
With the module present but under another application:
`module :'Elixir.Enum' is not in application 'stdlib'  found at /usr/lib/elixir/lib/elixir/ebin/Elixir.Enum.beam`.

**Compiler delta** (prototyped, 59 lines added / 7 removed across four files; `patches/52x-app-clause-and-check.diff`)
- `bs_parser.yrl`: one production `foreign_decl -> 'using' atom_lit 'in' atom_lit '{' foreign_sigs '}'`. **No new grammar conflicts**: 6 shift/reduce before and after, and a deliberately ambiguous control copy rises to 16 reduce/reduce, so the count can move (`p20-yecc-conflicts.out`).
- AST: `{foreign, Loc, Mod, Sigs}` becomes `{foreign, Loc, Mod, Sigs, App | none}`. Exactly **four** pattern sites in `bs_check.erl` (`callees`, `foreign_rets_decidable`, `foreign_wrappers`, `collapse_decl`) and the parser; no other file matches `{foreign,` (`p14-ast-shape.out` shows both shapes, and stock refuses the new form).
- `bs_check`: a `foreign_dep_check/3` (presence, then ownership via `code:lib_dir(App)` prefix of `code:which(Mod)`), two `bs_diag` tags.
- Optional emission: an exported `bs@needs/0` returning the declared apps, the same device as F55's `bs@type_atoms/0` (`bs_emit.erl:77`, `:1481`). The emitted `Withapp.beam` answers `[elixir]` and still imports `Elixir.Enum:count/1` (`p8`).

**Measured**
- Size: +76 bytes for the first declared app, then about +12 to +20 per further app (0/1/2/3 apps: 1200/1276/1288/1308 bytes, `p16-needs-size.out`). `bs@needs` is emitted only when an app is declared, unlike `bs@type_atoms`, which is on every module; that is a choice, not a necessity.
- The ownership check only fires when the module **is** present. When it is absent and the declared app is wrong, the diagnostic repeats an unverified claim (`p8`, Wrongapp with `ERL_LIBS` unset names `stdlib`).
- Repetition cost on this repo: 30 foreign blocks in 18 files, 27 distinct (file, application) pairs, so a per-block clause repeats an application in 3 places and a per-module header would save 3 lines (`p15-repetition.out`). The corpus is OTP-heavy; a real Elixir binding (Req, Req.Test, Req.Response) would repeat more, and that was **not measurable here**.
- Informative blocks: of those 30 blocks only 3 name an application that is not derivable from OTP or Elixir's install (`epgsql`, `json`, `Req`). `:erlang` is the preloaded module of `erts` (`p15`), and 21 of 37 OTP applications share a name with one of their modules (`p12-name-collision.out`), so a required clause would force `in :erts` on 13 of 30 blocks (the `:erlang` ones) for no information.
- A name is one node; the thing that must be present is a closure: `ssl` declares 1 name and needs 6 applications, `logger` needs 5 (`p11-app-closure.out`). Ticket 51 measured 16 for Req. The declaration does not give a reader that closure; the `.app` files do.

**Strongest counterargument**: the same as Option 1's, now with a new surface attached, plus drift. `rebar.config`/`mix.exs` still has to declare `req` with a version and a source (ticket 51 decided that), so the program states the dependency twice, and the language copy cannot be checked against the manifest without reading `rebar.config`, which is tooling territory. The name alone does not make the program self-sufficient: no version, no fetch source, and `epgsql` or `req` is still a string the stranger must resolve.

### Option 3: declaration recorded, never consulted by compile; the check is a separate explicit step

Same source as Option 2. Compile is unchanged in behaviour: accepted whatever the code path holds. The application list is exported as data, and a separate step (a flag on `bsc`, or a 10-line escript for a first cut) reads it:

```
$ ERL_LIBS=... escript needs.escript out       # App needs elixir: found at /usr/lib/elixir/lib/elixir
$ ERL_LIBS=    escript needs.escript out       # App needs elixir: MISSING
```

**Compiler delta**: the grammar, AST and `bs@needs/0` parts of Option 2 (no `foreign_dep_check`, no diagnostics). The check is outside compile; prototype in `p18-post-hoc-needs-check.sh`, which uses a prototype build with the compile check switched off (`BSB_DEP_CHECK=off`) and shows `elixir` MISSING in one environment and found in the other, with `stdlib` found in both as a control.

**Measured**: compile wall time and `.beam` sizes as Option 2 (the check costs nothing at compile because there is none). `.abstr` output stays environment-independent (`p13`), with the one addition of the `bs@needs` function.

**Strongest counterargument**: a failing dependency is no longer a compile error. The author learns of a missing `req` only by running the second step, and the ticket's own sketch ("turns a run-time `error:undef` into a diagnostic") is not delivered at compile. It also builds a record whose only consumer is a step nobody has written yet (the LSP, a `rebar.config` generator), which CLAUDE.md's "a gate guards the language or the handoff" rule would want a consumer for.

A compile-time **warning** variant of Options 1 and 2 is a fourth point, not a fourth option: `bsc` has a warning class that does not block (the documented `unreachable_arm` compiles, exit 0, beam emitted, `p19-warning-severity.out`; producer `bs_diag.erl:694`), and the prototype's `BSB_DEP_CHECK=warn` emits the beam with `warning: module ... is not on the code path` (`p8`). It keeps Elixir's behaviour (P5: warning, exit 0) but the *output text* of a compile still varies by machine.

## 6. Evidence the destination argument is real

The handoff package ships `compiler/examples *` (`handoff/MANIFEST:49`). That tree includes exemplar 25d, `using :epgsql` (`index.bs:12`, a hex package) and 25f, `using :json` (`index.bs:44`). On the OTP 25 box neither module resolves (`p9-census.out`); on the repo's pinned OTP 28 `json` is probably present, but that **was not run** (section 8). Nothing in either file says where `epgsql` comes from. The exemplars are documented as not compiling yet, so no verdict is flipped today; the point is that the provenance gap is in the shipped corpus now. The `req.bs` prototype also holds the application name only as **data**: `:'Elixir.Application'.ensure_all_started(:req)` (`wayfinder/prototypes/51a-code-path/Req/req.bs:69`), where the compiler cannot use it.

## 7. Recommendation

Ask **Q1** alone and first: *may `bsc`'s verdict on a `.bs` file depend on the machine's code path?* My answer would be **no for the verdict**, which makes Option 3 the shape, and in that case keep the clause **optional and per block**, because:

- the verdict stays a function of the source (`p13`), which the oracle role needs;
- the clause is written only where it carries information: 3 of 30 corpus blocks, and exactly the ones the clean-room handoff cannot reconstruct;
- per block keeps ticket 41's rule that "a file's `using` lines are its dependency list" literally true, and costs 3 repeated writes across this repo's 18 files (`p15`);
- required would force `in :erts` onto every `:erlang` block;
- no new grammar conflicts and a 5-tuple change at four sites (`p20`, `p14`).

Two cautions that argue for stopping at "record, don't enforce" until a consumer exists: the application name does not replace the manifest (no version or source), and a check that reads an ambient environment variable contradicts S3's own precedent (the native check is keyed on the explicit `--src-root`). If David wants the ticket's original promise (a compile-time diagnostic) the cheapest honest form is Option 1's check as a **warning**, with the application clause added only if the diagnostic needs to name the missing application (it cannot otherwise: it does not know the name, `p8` Noapp). Sequence with ticket 106's alias, which also edits the `using` block.

## 8. Not measured / could not run

- **Gleam**: not installed; nothing about Gleam was executed. The only Gleam citation is the repo file at section 4.
- **Req / hex packages**: cannot be fetched. Elixir's own lib dir stands in for Req. Req's real module/application layout (how many `using` blocks a real Req binding repeats, whether its `.app` lists what 51 measured) is **not measured here**; 51 measured 16 applications.
- **OTP 28 pin**: only OTP 25 is installed. That `:json` exists on 28, and any behaviour of `code:which`/`.app` layout on 28, is not run. The scratch compiler is an OTP 25 build with a lexer shim; **diagnostic columns are wrong** and every `:line:1` above is a shim artefact.
- **Elm**: could not run beyond the failure in `p7`.
- **Elixir compiler source**: not installed (only `ebin`), so no `file:line` into Mix; Mix behaviour is from executed output only. The stale-state surprise in `p5` (b) was reproduced once and not explained.
- **rebar3**: does not work here; rebar's `applications` handling and `rebar_mix` are taken from ticket 51, not re-run.
- **Combination with ticket 106's alias** (`in :req` on the header plus `= :'get!'` on an entry): not prototyped, since 106 is unbuilt. The grammar interaction is a prediction.
- **A per-module header spelling** (`needs req`): not prototyped; only its repetition saving (3 lines) was counted. The brace-less form `using :req` collides with module names for 21 of 37 OTP apps (`p12`), so it is not proposed.
- **Exemplars 25d-25g**: the batch run refused them for unrelated directory/module-name reasons (invoked as directories, not as the exemplars' own layout), so `p9`'s stock-vs-prototype rows for them say nothing about dependencies.
- **Timing** was taken with other agents running on the same machine: batch medians drifted 430-720 ms between runs. Only on/off pairs inside one batch are comparable, and all of them overlap within their min-max range.
- The prototype is a scratch copy at `/tmp/bsb_52_x` (not in the repo); the patch is `artifacts/probes/52/patches/52x-app-clause-and-check.diff`. Probes P8, P10, P13, P14, P16, P18 and P20 need that build and the stock one at `/tmp/bsbuild`.

## Probe index

| Probe | Question | Control that can fail |
|---|---|---|
| `p1-premise-undef` | compile ok, run `undef`? | `lists` runs |
| `p2-syntax-census` | which spellings parse today | plain form accepted vs attribute/alias/keyword refused |
| `p3-beam-records` | what a `.beam` records | module with no foreign call lists none |
| `p4-derive-app` | module -> app/vsn from the path | flat dir, absent module, `get_application` |
| `p5-elixir-mix-xref` | Mix warning on undeclared app | declared-from-start project is clean |
| `p6-erlang-xref` | Erlang's post-hoc check | `NoDep.beam` alone gives `[]` |
| `p7-elm` | Elm | only the failure |
| `p8-prototype-52x` | clause, check, ownership, `bs@needs`, severity | stock accepts; stock refuses new syntax; correct app accepted |
| `p9-census` | blast radius over repo sources | per-file stock vs prototype |
| `p10-timing-size` | time (N=15), sizes, `code:which` cost | check on vs off |
| `p11-app-closure` | what a name says vs the closure | `stdlib` closure of 2 |
| `p12-name-collision` | app/module name collisions | Elixir apps (1 of 6) |
| `p13-verdict-purity` | is output environment-independent today | changed source differs |
| `p14-ast-shape` | the AST change | stock refuses the app form |
| `p15-repetition` | blocks vs distinct apps | per-file table |
| `p16-needs-size` | bytes of the record | 0 apps |
| `p17-native-using-precedent` | native `using` already checked | present module accepted |
| `p18-post-hoc-needs-check` | Option 3's separate check | stdlib found in both environments |
| `p19-warning-severity` | a non-blocking diagnostic exists | clean switch has none |
| `p20-yecc-conflicts` | grammar conflicts | duplicated production raises the count |
