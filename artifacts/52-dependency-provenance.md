# Ticket 52 (ENG-234): does a `.bs` file say what it needs? Decision brief

Not a resolution. Nothing outside `artifacts/` was edited. Every number below came from a probe in
`artifacts/probes/52/`; anything not executed is marked **UNMEASURED**. Toolchain per ENV.md:
OTP 29, Elixir 1.20.4, Gleam 1.18.1, Elm 0.19.2 (the repo pins OTP 28.5, so absolute sizes are OTP 29).
`PROTOTYPE` means a patched copy of `compiler/src` built by `probes/52/proto/build.sh`; the repo is untouched.

## What the ticket got slightly wrong (measured, p01 / p04 §0)

The ticket says a program on a machine with a different `ERL_LIBS` "fails at the call site with
`error:undef`". Closer:

- **It compiles.** `bsc Probe` with no `ERL_LIBS` exits 0 (p04 §0). Nothing about the library is needed to build.
- It fails when **run**, with `crashed: error:undef`. That line names neither module nor application.
  The module (`Elixir.String`) appears only in a raw stack trace (p01 §C), and an app name never does.
- The shipped grammar has no `[external: …]` attribute (`bs_parser.yrl:170` is `using atom_lit { … }`).
  Ticket 32's attribute spelling was not what landed. The prototype spells the app `in :req` only because
  `in` is already a keyword (`bs_lexer.xrl:54`). The spelling is a later, taste question.

## The gating question, asked alone

**Should the source of a foreign `using` block name the application, so that `bsc` can hold the
program to it?** Everything else (where, version, what lands in the `.beam`) follows from the answer
and is not asked yet.

The same program under both answers:

```csharp
module Fetch

using :'Elixir.Req' in :req {          // yes: a promise the compiler holds
    term new(list<(atom, term)> opts)
}
using :'Elixir.Req.Request' {          // no: exactly today's language
    term put_header(term req, binary k, binary v)
}
```

## Option A: the source says nothing; the compiler only checks the module is reachable

```csharp
using :'Elixir.Req' {                  // unchanged source
    term new(list<(atom, term)> opts)
}
```

Compiler delta (PROTOTYPE `BS52=module`, `bsc.erl` ~25 lines): one `code:which(Mod) =/= non_existing`
per foreign decl before `bs_check`, plus a `bs_diag` descriptor.

| measured | result | probe |
|---|---|---|
| diagnostic | `error: module 'Elixir.Req' is not on the code path` and *"nothing here says which application provides it"* | p04 §1 |
| emitted bytes | 0 | p05 |
| cost | `code:which` hit 5.5 to 6.8 us; a miss grows with path length (10 us at 42 entries, 1.1 ms at 142, 4.1 ms at 542) and is paid only on the error path | p03 (a) |
| shipped examples | 21 of 21 `compiler/examples/*` give the same result as today | p09 |

**Strongest counterargument, measured: it adds a build-machine requirement for no promise.** Two
programs in the repo compile today with no `ERL_LIBS` and are refused under this check:
`wayfinder/prototypes/51a-code-path/Req` and `…/Elx` (p09). Ticket 51 said Elixir is needed where `.ex`
deps compile, not wherever `bsc` runs. That is a real tension for the editor and `--api` path
(**UNMEASURED**: no LSP exists to try). It also fails the ticket's actual argument. The module cannot
tell a stranger what to install, because the app is not derivable from the module name: of 1,736
modules in 41 installed applications the obvious rule ("first `_` segment is the app") holds for 32.8%
of Erlang-style modules and `Elixir.<First>` for 35.8% of Elixir modules, and for **0 of the 237**
modules of app `elixir`: `String`, `Enum` and `Map` all live there (p06).

## Option B: the block names the app, optionally, name only, per block

```csharp
using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}
```

Compiler delta (PROTOTYPE `BS52=app`, patch in `proto/proto52.patch`): one production in the parser
(`decl` stays a 4-tuple after a strip, so `bs_check` was not touched); a check of
`code:lib_dir(App)`, then `code:which(Mod)` and a test that the beam lives under that app's dir.
A block with no `in` behaves as today.

Diagnostics (p04 §2 to §4), lib missing, wrong app, absent app:

```
Probe/probe.bs:3: error: application 'elixir' (declared for module 'Elixir.String') is not on the code path
  put its directory on ERL_LIBS, or fix the name after `in`.
Probe/probe.bs:3: error: module 'Elixir.String' resolves to …/elixir/ebin/Elixir.String.beam, outside application 'eex' (…/lib/eex)
```

| measured | result | probe |
|---|---|---|
| cost | `code:lib_dir` is flat, 1.7 to 3.3 us at any path length. Inside the prototype, 1/20/60 blocks gave no difference outside the plus-or-minus 1 ms noise; the analytic bound is 0.4 ms at 60 blocks | p03 |
| what the check can name | the application, so the reader knows what to install; the module-only check cannot | p04 |
| the corpus | 30 foreign blocks in 16 directories. 25 are in `erts`/`kernel`/`stdlib`; 5 are not (`Req`, `epgsql`, and 3 of app `elixir`) | p07 |
| per block vs per module | 12 of 30 blocks sit in 4 modules where several blocks share an app. But annotating only non-OTP blocks costs 5 annotations per block against 4 per module across the whole corpus: **one line of difference** | p07 |

**Strongest counterargument: optional means unenforced, and the check can be wrong.** Three parts:

1. A program that omits `in` is silently the status quo. The handoff gap survives wherever the author did
   not write it. Making it required everywhere puts `in :stdlib` on 25 of 30 blocks for no benefit.
   Making it required only outside `erts`/`kernel`/`stdlib` is a cheap rule (5 blocks, 2 of them
   third-party) but needs the spec to list the exempt apps. That second rule is **UNMEASURED**; it was
   not built.
2. The app check false-positives on a layout that works. Put `Elixir.String`'s beams on a bare `-pa`
   directory with no `elixir/ebin` shape: the module check passes and runs, the app check refuses
   (`code:lib_dir(elixir)` is `{error,bad_name}`, p02 §4, p04 §5).
3. Every neighbour keeps package names out of the source file (survey below), and ticket 51 chose rebar3,
   whose `rebar.config`/`.app.src` already names deps. A second statement in the `.bs` can disagree with
   it, and no mechanism compares the two (**UNMEASURED**, nothing reads a rebar manifest).

## Option C: once per module (the same check, a different home)

```csharp
module Fetch
needs :req, :elixir                    // one list; the blocks below are unchanged

using :'Elixir.Req' { … }
using :'Elixir.Application' { … }
```

Compiler delta: a `needs` declaration (new decl kind, new parser/lexer token) and the same
`lib_dir` check; membership (is each foreign module under *some* needed app) replaces the pairing.
Not built, so its cost is **UNMEASURED**. Two measured facts only: it saves one line over B in the corpus
(p07), and it cannot catch a module paired with the wrong app, which B caught (p04 §3). Its shape is the
shape of the `.app` `applications` list (`ssl.app:101`). The counterargument is that it adds a *new*
construct where the ticket's own argument was that `using` already is the one place a foreign thing is
named. It is the pair to be asked second (block vs module), only if the gating answer is yes.

## Follow-on questions (not asked until the gate is answered)

- **Version: name only.** Not one neighbour's application-level list carries one. `ssl.app:101` is
  `{applications, [crypto, public_key, kernel, stdlib]}`, bare atoms (version is a separate `vsn` key, `ssl.app:10`);
  `extra_applications` in a generated `mix.exs:17` is atoms; versions appear only in dependency manifests
  (`mix.exs` deps, `gleam.toml:16`, `elm.json`). A version range is resolution, which 51 refused.
  Reading an installed version is possible (`code:lib_dir` returns `eex-9.9.9`, p02 §4); comparing ranges is not attempted.
- **Landing in the `.beam`.** **Nothing in OTP reads a custom attribute** (p10 §1: an app whose beam says
  `-bs_needs([crypto])` starts with crypto unstarted). It survives `compile:file from_abstr`, `beam_lib:chunks`
  and `module_info(attributes)` (p05 §A), and `-external(foo)` is accepted but is just a wild attribute.
  Bytes on the 856-byte baseline module (p05 §C): app list +44 (5%), two (app,module) pairs +92 (11%),
  50 pairs +1.2 KB, **on_load check function +508 (59%)** and it aborts the load with
  `{bs_missing_dependency,elixir,'Elixir.String'}` instead of `undef` at the call (p05 §D).
  The `.app` `applications` key is what OTP enforces: a missing app fails `ensure_all_started` naming
  it, `{req,{"no such file or directory","req.app"}}` (p10 §2, p08 erlang §5). But `bsc` emits no `.app`
  (only its own `bsc.app.src:5`), so that is a packaging artefact, which is 51's territory.
- **Reading it back.** `bsc --api` would be the natural reader for the handoff harness
  (**UNMEASURED**, not prototyped).

## Neighbours: what the source file says versus a separate manifest

| | the source file says | the manifest says | missing, what happens | probe |
|---|---|---|---|---|
| Erlang | modules only, **except** `-include_lib("app/include/x.hrl")` (`ssl_cipher.erl:38`), which names an app | `.app.src`/`.app` `applications` (`ssl.app:101`, `bsc.app.src:5`); `optional_applications` exists (`debugger.app:53`) | call into an absent module: `erlc` rc 0, no word. `-include_lib` of an absent app: **compile error** `can't find include lib` (rc 1). Missing app at start: names the app | p08 erlang |
| Elixir | modules only (`Req.get!`) | `mix.exs` `deps/0` (`:22`), `extra_applications` (`:17`) | `elixirc`/`mix`: **warning** `Req.get!/1 is undefined (module Req is not available…)`, rc 0, names no app. Declared dep absent: `the dependency is not available`. No warning for a `:crypto` call missing from `extra_applications` (1.20.4) | p08 elixir |
| Gleam | `import gleam/io` (module path); `@external(erlang,"crypto","hash")` names no app | `gleam.toml` `[dependencies]` (`:15-16`); `[erlang] extra_applications` puts `crypto` into the generated `.app` | `error: Unknown module` at the import. `@external` to an absent module compiles clean, **the same as B# today** | p08 gleam |
| Elm | `import Html` (module) | `elm.json` `dependencies` | no `elm/core`: `MISSING DEPENDENCY … elm.json`. Missing package: registry fetch fails (blocked here) | p08 elm |

Read together: four of four keep package names out of the module source; the one place a source line names an
application (Erlang's `-include_lib`) is checked at compile time with the same `lib_dir` Option B uses, and
the compiler checks it as an **error**. Elixir's undefined-module check is a **warning**. Gleam's FFI is
unchecked, like B#'s today. None of them has a manifest-free toolchain (51: B# has no build tool),
so none is a direct precedent for a language whose handoff is `.bs` files alone.

## Recommendation

**Answer the gate yes, and build B in its smallest form:**

1. `in :app` optional on a foreign block, name only, no version.
2. The compiler refuses a block whose **named** app is absent from the code path, or does not contain
   the module. A block that names nothing is checked for nothing.
3. No `.beam` attribute in the first cut; nothing reads it (p10) and the only reader proposed, `--api`,
   is **UNMEASURED**.

Why this and not A: A's check fires on programs that make no promise and so adds a build-machine
requirement for nothing (p09: 2 corpus modules newly refused). B makes the check an *opt-in*, so
every program that compiles today still does (21 of 21 examples, p09). Why not C: it needs a new
construct and loses the module-to-app pairing, for a one-line saving (p07).

The unresolved risk is the first counterargument above. If the handoff must *guarantee* provenance
rather than offer it, the follow-up is "required outside `erts`/`kernel`/`stdlib`", which turns the
5 third-party corpus blocks into compile errors until annotated. David should judge that by reading
`using :epgsql in :epgsql {` against `using :epgsql {`.

## Evidence index

| claim | probe |
|---|---|
| bsc compiles with the lib missing; failure is `crashed: error:undef` at run time naming no module | `p01_undef/run.out`, `p04_diagnostics/run.out` §0 |
| `lib_dir` / `which` / `where_is_file` / `application:load` answers with lib present and absent; `application:load` has a side effect | `p02_presence/run.out` §1-2 |
| module-to-app by directory; versioned dir; bare `-pa` makes `lib_dir` fail while `which` succeeds | `p02_presence/run.out` §3-4 |
| primitive and in-compiler cost of the check | `p03_check_cost/run.out` |
| diagnostics before and after; wrong app; absent app; bare `-pa` false positive | `p04_diagnostics/run.out` |
| attribute survives `from_abstr`, `beam_lib`, runtime; byte costs; on_load failure text | `p05_beam_cost/run.out` |
| app not derivable from module name | `p06_module_to_app/run.out` |
| corpus: 30 blocks, 16 dirs, per-block vs per-module counts | `p07_corpus_survey/run.out` |
| Erlang / Elixir / Gleam / Elm survey | `p08_neighbours/{erlang,elixir,gleam,elm}/run.out` |
| no false positive on 21 shipped examples; 2 prototype modules newly refused | `p09_corpus_false_positives/run.out` |
| OTP ignores the attribute; `.app` is enforced | `p10_attribute_inert/run.out` |
| the PROTOTYPE patch and build | `proto/proto52.patch`, `proto/build.sh`, `proto/bsc52.sh` |

Every `run.sh` rebuilds from scratch (the prototype from `compiler/src`) and prints what its `run.out` holds.

## Limits

- **No network for registries.** `repo.hex.pm` and `package.elm-lang.org` are blocked by the sandbox proxy
  (`gleam add` failed on `repo.hex.pm`; `elm make` on `package.elm-lang.org`). No real `gleam add` or `elm init`
  project was built; Gleam's `gleam.toml` is from `gleam new` and its `[dependencies]` block was hand-edited.
  Elm's `elm.json` is hand-written, and what Elm says about an `import` from a package not in `elm.json` is
  **UNMEASURED**. Hex itself was unreachable, so `mix` was only tested with a path dep.
- **Req is not installed.** Elixir's own `elixir` application stands in for a third-party library;
  the missing-lib behaviour is identical but no Hex package was exercised. `epgsql` is not installed either.
- **Mix and Elixir `.ex` source** is not installed (only `.beam`), so mix citations are the file `mix new`
  generated, not Mix's own source. Whether Elixir's `extra_applications` warning exists in other versions is not claimed.
- **Prototype scope.** Diagnostics are printed directly rather than through `bs_diag` (the real change needs a
  descriptor term and `--diagnostics term|json`, F16/F47: **UNMEASURED**). The mode is an env var. `--batch`,
  `ibs`, `--api` and the `bsc` escript were not exercised. The `in` spelling is a stand-in.
- **Timing** is noise-dominated (about plus-or-minus 1 ms on 3 to 8 ms compiles, 4 cores, shared machine). The claim made
  is the analytic bound from the primitives, not a measured delta. Absolute `.beam` sizes are OTP 29, and `bsc`'s own
  `.beam` for the same source was 920 vs 856 bytes in the variant harness (it adds a `Line` chunk), so use the deltas.
- The corpus is 16 directories of this repo's own examples. It says nothing about how real third-party programs distribute blocks.
- Not tested: umbrella/release layouts, `-mode embedded` loading, relx or reltool reading attributes, and
  a B# project built by a rebar3 plugin (none exists).

## Verifier findings (independent re-run, see probes/52/VERIFY.md)

Largely REPRODUCED: every probe but p03 matched its captured output when rebuilt from a fresh
`compiler/src`; no tuned patch or fixture found; the ticket correction, the `Req`/`Elx` refusals,
the .beam size deltas and the citations all hold. Corrections owed:

1. **Timing:** "4.1 ms at 542 entries" is not in `run.out`; the verifier measured 2.5-3.2 ms over 3 runs.
2. **p09 for Option B:** "21 of 21 still compile" is true by construction (no example uses `in`, so B never fires). It is not evidence of safety.
3. **Gleam step 5** used `crypto`, which exists; the verifier re-tested with a truly absent module and the claim holds.
4. **"0 of 237" is overstated as an argument:** outside app `elixir`, the module-name rule holds for 148 of 176 (84%). "Cannot tell a stranger what to install" applies to the `elixir` app chiefly.
