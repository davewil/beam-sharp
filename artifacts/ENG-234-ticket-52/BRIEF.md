# Decision brief — ticket 52 (ENG-234): what does a `.bs` file say about what it needs?

**Status: DECISION OPEN. This brief resolves nothing.** Prepared by the scheduled run of 2026-10-27 for
human review. The verifier pass is the parent's step and has not happened in this file.

## Evidence labels (read first)

- **MEASURED here** — I executed it in this session; the probe and its captured `.out` are in `probes/`.
- **RECORDED, not re-executed** — taken from a repo file or from a ticket; cited, not run.
- **Not available** — could not be run in this environment; nothing is asserted about it.

Environment, all of it different from the repo's pin (`.tool-versions`: erlang 28.5):
**OTP 25.3, Elixir 1.14.0, rebar3 3.19.0, Elm 0.19.3.** Every number below is OTP 25. `bsc` cannot be built
here (needs OTP 27's leex `error_location`), so **no claim about what `bsc` does today is measured**; those are
RECORDED from source. **No real Req**: hex.pm returned 403 from the egress proxy (policy denial, not retried),
so the "foreign application" in the probes is a hand-built `fakereq` app and Elixir's own `eex`. **Gleam: not
available** (binary download denied by the permission classifier; not attempted by other means).

## The question, in B# terms

Ticket 51 decided `bsc` builds no dependency tool and reads whatever `ERL_LIBS` already points at. So this
program compiles on David's machine:

```csharp
module Fetcher

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
    term GetOrCrash(binary url) = :'get!'      // per-entry alias, ticket 106
}

public term Fetch(binary url)

Fetch(url) -> :'Elixir.Req'.new([(:url, url)])
```

and on a machine without Req it compiles *identically* and dies at the call. The source says nothing about `req`.

**MEASURED here (`probes/a_undef.sh`)**: with `'Elixir.Req'` absent, `erlc` emits no diagnostic, the module loads,
a call on a never-taken branch is silent, and the executed call fails as
`{undef,[{'Elixir.Req',new,[[{url,<<"x">>}]],[]}|…]}`; `code:which('Elixir.Req')` is `non_existing`. Elixir
renders it `function Req.new/1 is undefined (module Req is not available)`. So the failure is a run-time,
call-site, application-less message: it names the module, never the package that would fix it.

**Syntax correction to the ticket text.** The ticket's `[external: elixir, app: req] using …` is ticket 32's
superseded spelling. RECORDED: shipped grammar is `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'`
(`compiler/src/bs_parser.yrl:170`), `bs_parser.yrl` has no attribute production, and LANGUAGE.md §11 uses
`using :lists { … }`. Any option below adds a *new* grammar element; none "extends an attribute".

## The one gating question

Everything else (where, what the compiler does) only matters if the answer to this is yes:

> **Must a `using` of a module outside `kernel`/`stdlib` name the application that provides it?**

## Sub-decisions that follow (not asked yet)

1. Per `using` block, or once per module. 2. Name only, or name + version. 3. What `bsc` does with it:
check-and-refuse, check-and-warn, or record only. 4. The spelling (a keyword is a cost: ticket 22 counted keywords).
5. Sequencing with ticket 50: **no longer a constraint.** 50 resolved 2026-08-26 (a foreign struct is a
`map<atom, term>`, no new surface) and 106 resolved 2026-09-25 (per-entry alias). Both finished changing the
`using` block; this ticket is the last one that would touch it. RECORDED (`wayfinder/issues/50-…md` Decisions
entry; `106-…md` Decisions entry).

Sub-decision 2 has direct evidence, below: the one neighbour measured that checks this at compile time (Mix) checks the name only. Rebar3, Elm and Gleam were not observed doing so (see VERIFIER.md).

## What a compile-time check can cheaply do (MEASURED, OTP 25, `probes/b_check_cost.sh`, `g_owning_app.sh`)

All hypotheses held except H5, which was falsified for the failing case.

| operation (warm, N=2000, 40 code-path entries) | cost | result |
|---|---|---|
| `code:which(M)`, module present | 290 µs | path of the `.beam`, **module not loaded** |
| `code:which(M)`, module **absent** | **2,801 µs** | `non_existing`; scans every directory — *H5 "< 1 ms" falsified here* |
| `code:lib_dir(App)` | 9.7 µs | dir, or `{error,bad_name}` when absent |
| `file:consult` of `<app>.app` | 612 µs | `applications`, `modules` keys readable |
| `application:load` then `get_key(App, applications)` | 1,252 µs cold / 2.2 µs warm | declared deps, app **not started** |

- The owning application is derivable from the path (`…/fakereq-0.7.3/ebin/Elixir.Req.beam` → `fakereq`),
  and a module found under another app is distinguishable (`probes/b…`, H6). **Caveat:** that derivation uses the
  `name-vsn` directory convention; I built the fixture directories, so this shows the mechanism, not that every
  real tree follows it. The authoritative source is the `.app`'s `modules` key (readable, 612 µs, not exercised
  as a module→app lookup here).
- `kernel` and `stdlib` are the only OTP apps started at boot (`g_owning_app.sh`); `crypto`, `ssl`, `inets`
  modules resolve to apps that are *not* started, so a rule exempting "OTP" wholesale would be wrong; exempting
  `kernel`/`stdlib`/`preloaded` is what the data supports. **Note:** `:erlang`, the module most FFI blocks name,
  returns the atom `preloaded` from `code:which`, not a path. My first run mis-derived `"."` for it
  (`g_owning_app.run1.out`, kept); any check needs that special case.
- **Cost in the artefact**, if provenance is emitted as a beam attribute (`probes/f_attr_cost.sh`, `+no_debug_info`):
  +32 B for one app, +52 B for three, +48 B for one app with a version string; it round-trips through
  `beam_lib:chunks(…, [attributes])` **without loading the module**. `compile:file` medians 3.1 ms vs 3.3 ms, inside
  the run-to-run spread (max 294 ms was a first-run outlier); I do not claim a compile-time delta either way.

## How the neighbours do it

**Erlang/OTP + rebar3 (MEASURED, `probes/c_app_files.sh`).** `applications` in `rb.app.src` is copied verbatim to
`ebin/rb.app`: `{applications,[kernel,stdlib]}`; **no versions anywhere**. `rebar3 compile` of a module calling
`'Elixir.Req':new/1` prints nothing. `rebar3 xref` *does* report it: `src/rb.erl:3: Warning: rb:go/0 calls undefined
function Elixir.Req:new/1 (Xref)`, and so does `xref:analyze(s, undefined_function_calls)` called directly. So the
BEAM toolchain already has an opt-in check for *module absent*, but nothing for *application undeclared*.

**Elixir/Mix (MEASURED, `probes/c_app_files.sh`, `d_elixir_tracer.sh`).** Mix does exactly the check this ticket
describes, at project level. Calling `EEx.eval_string/1` with `extra_applications: []`:

> `warning: EEx.eval_string/1 defined in application :eex is used by the current application but the current
> application does not depend on :eex. To fix this, you must do one of: 1. … include it under :extra_applications
> … 2. … listed under "def deps" … 3. … [xref: [exclude: [EEx]]]`

Declaring `extra_applications: [:eex]` silences it, and `mx.app` gains `eex` — **name only**; a path dep at
version 1.2.3 appears in `mx.app` as `dep1`, no version. A call to an entirely absent module gets a *different*,
module-level warning (`Absent.Thing.run/1 is undefined (module Absent.Thing is not available or is yet to be
defined)`), with no application named. It is a **warning**, not an error, in both cases.
Sources (no `.ex` shipped; cited from the shipped beams' `debug_info`): `lib/mix/tasks/compile.app.ex`,
`handle_extra_applications/2` line 342, `apps_from_runtime_prod_deps/2` line 354, `project_apps/1` line 395;
the checker is `Mix.Compilers.ApplicationTracer` (`/usr/lib/elixir/lib/mix/ebin/`). I could not recover its
source lines; the warning text above is the measured output.

**Elm (partly executed, `probes/e_elm.sh`).** `elm make` on a project with no `elm/core` stops at *MISSING
DEPENDENCY … I need to see an "elm/core" dependency* — even the default imports require a declaration. The
registry is blocked (`package.elm-lang.org` 403), so I **could not** observe the diagnostic for importing a module
from an undeclared package, nor `elm install` writing `elm.json`. That Elm records exact versions is **not
measured here**; Elm also has its own package manager, which 51 ruled out for B#, so it is weak evidence either way.

**Gleam: not available; nothing asserted.**

## Option 1 — No source change; `bsc` derives and records the app

```csharp
// unchanged — no declaration anywhere
using :'Elixir.Req' { term new(list<(atom, term)> opts) }
```

Compiler delta: in the foreign-declaration pass (`bs_check.erl` loops over `{foreign, _, Mod, Sigs}` at
:620, :638, :1076 — RECORDED), call `code:which(Mod)`, derive the app, and have `bs_emit` write
`-bs_requires([…])` into the `.beam`; a `bsc --deps` prints it.

- **Evidence:** all of it measured above: derivation works, +32–52 B, readable without loading.
- **Strongest counterargument:** it records *the environment that happened to build the program*, which is the
  ticket's own objection: a clean-room implementer who has no Req installed gets `non_existing` and **nothing to
  record**; the source still cannot be handed over. It also cannot turn `error:undef` into a diagnostic that names a
  package, because with the module absent it has no package to name.

## Option 2 — A name-only application on each `using` block

```csharp
module Fetcher

using :'Elixir.Req' from :req {
    term new(list<(atom, term)> opts)
    term GetOrCrash(binary url) = :'get!'
}

using :'Elixir.Req.Test' from :req { term allow(term name, pid owner) }
using :'Elixir.Application' from :elixir { term ensure_all_started(atom app) }
using :lists { int sum(list<int> xs) }       // kernel/stdlib/preloaded: `from` not required
```

`from` is placeholder spelling. Compiler delta: one grammar production
`'using' atom_lit 'from' atom_lit '{' …` (today `bs_parser.yrl:170` has none); `{foreign, L, Mod, Sigs}` gains
an app field; one check beside `foreign_rets_decidable/2` (`bs_check.erl:636`, RECORDED):

| module found? | under the declared app? | result |
|---|---|---|
| yes | yes | silent |
| yes | **no** (under another app) | **error**: names both apps (derivable by design; not probed: the fixture takes app names from directories the author created) |
| no | — | **warning**: `Req` not on the code path; the declaration says app `req` |
| a non-`kernel`/`stdlib`/`preloaded` module with no `from` | — | **error**: names the app it was found under, if found |

The "absent → warning, not error" row is what Option 1 cannot offer: the declaration is the only place the
package name can come from when the module is missing, so the run-time `undef` becomes a compile-time message that
says *which package to install*. Mix makes the same choice (warning, not error).

- **Evidence:** Mix's check is the same shape and name-only (MEASURED `d_elixir_tracer.sh`); the repo's own
  bindings show the repetition cost: `51a-code-path/Elx/elx.bs` has 2 blocks for 1 app (`String`, `Enum`, both
  `elixir`), `Req/req.bs` 2 blocks for 2 apps (RECORDED count, `grep` of `using :'Elixir`). Cost of the check:
  ~0.3 ms per present module, about 2-3 ms per absent one (re-runs: 1.75-2.8 ms; present 0.22-0.66 ms) (OTP 25, 40 entries; more entries on a real `ERL_LIBS`).
- **Strongest counterargument:** repetition. A binding of Req with `Req`, `Req.Request`, `Req.Test` repeats
  `from :req` three times, which is the write-cost the ticket flagged; and the declaration names the app that owns
  the *called module*, not the applications the program must *start* at run time (51 measured `ensure_all_started`
  failing on `eex` while the call itself worked), so it does not replace an OTP `applications` list.

## Option 3 — A name-only application list once per module

```csharp
module Fetcher
needs :req, :elixir                            // placeholder spelling; in index.bs

using :'Elixir.Req' { term new(list<(atom, term)> opts) }
using :'Elixir.Req.Test' { term allow(term name, pid owner) }
using :'Elixir.Application' { term ensure_all_started(atom app) }
```

Compiler delta: a new declaration form (grammar + `bs_check` pass); the check is Mix's: every foreign `using`
whose module is not owned by `kernel`/`stdlib`/`preloaded` must be owned by a listed app, else a diagnostic naming the
owner (the Mix wording measured above); each listed app must satisfy `code:lib_dir/1` (9.7 µs); a listed app that no
`using` needs is a warning. Same absent-module row as Option 2.

- **Evidence:** this is the placement Mix and OTP both use (project/app level, name only: MEASURED c, d), and it
  removes the repetition; also it can list an app the program needs without naming one of its modules (the
  `ensure_all_started` gap above).
- **Strongest counterargument:** a B# module is a directory with sibling function files, and a `using` in one file
  reaches its siblings (ENG-440 as cited by the ticket author; no source for it exists in the repo, so treat as unconfirmed), so the list has one home (`index.bs`) far from the
  `using` it justifies; and it adds a new top-level declaration where Option 2 only widens one that exists. A reader of the `using` block
  no longer sees the provenance at the call, which is the thing the ticket wants visible to the spec.

## Recommendation

**Answer the gating question yes, and take Option 2, name only, warning on an absent module.** One question for
David, as a program that compiles under one answer and is refused under the other:

```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }     // compiles today
```

*Should this be refused with "Elixir.Req is in application `req`; write `from :req`"?* If no, Option 1 is the
whole feature and costs about 40 bytes. If yes, the placement (Option 2 vs 3) is the follow-up, and I would
choose 2 because `using` is the one place the source already names a foreign thing (the ticket's own candidate),
because only a declaration can name a package when the module is missing, and because the repetition measured in
the repo's bindings is two blocks per app, not a pattern that outweighs that. If David finds the repetition
unpleasant on reading a Req binding, Option 3 is the same check at the Mix/OTP placement and nothing in the
evidence rules it out. **Version: no.** Mix and rebar3's generated `.app` files (MEASURED; lockfiles and `mix.exs` requirements were not examined) record names only; a version is resolution, which 51
refused. This is a recommendation, not a decision.

## Not verified / limits

- No real Req, Jason or Finch (hex 403); the foreign application is a fixture I built, and Elixir's `eex`.
- OTP 25 / Elixir 1.14, not the pinned OTP 28.5. Timings are one machine, warm loop, not a distribution; the
  absent-module cost grows with code-path length and depends on file-system cache.
- `bsc` was not built: every statement about its grammar, checker and emitter is read from source, not run.
- Module→app by directory name is a convention in my fixtures; the `.app` `modules` key is the authoritative route
  and was read but not timed as a lookup across many apps.
- Elm's undeclared-package diagnostic and its version recording: not observed (registry 403). Gleam: not available.
- Mix's `ApplicationTracer` source lines unrecovered (beams only). `rebar_mix` / `ensure_all_started` behaviour
  is 51's measurement, not re-run.

## Probe index (all under `probes/`; each has a `.out` captured from the run beside it)

| probe | question | verdict |
|---|---|---|
| `a_undef.sh` | what an absent module looks like | held |
| `b_check_cost.sh` | which compile-time checks exist and cost | held, **H5 falsified for absent module (2.8 ms)** |
| `c_app_files.sh` | what rebar3 / mix / xref record | held |
| `d_elixir_tracer.sh` | Mix's application-undeclared warning | held |
| `e_elm.sh` | Elm's missing dependency | partial; registry blocked |
| `f_attr_cost.sh` | beam attribute size / readability | held; compile-time delta inconclusive |
| `g_owning_app.sh` | which app owns modules `using` names | held after fixing my `preloaded` handling (`.run1.out` kept) |


## Verification status
Independently re-run: see `verification/VERIFIER.md`. All 7 probes reproduce. Weak: `e_elm` (Elm stops on missing `elm/core` first, so neither hypothesis was tested), b's wrong-app check (fixture tautology). The measured evidence does not discriminate Option 2 from Option 3; that choice is design judgement plus the Mix precedent. `f` used `+no_debug_info`, bsc uses `debug_info`; verifier rebuilt with it and the byte deltas are unchanged.
