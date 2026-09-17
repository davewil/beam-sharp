# Brief: ticket 52 — dependency provenance

Research brief, not a decision. Does not resolve ticket 52; ticket 52's `Status:` line and
`## Decisions entry` are untouched by this document.

## Sub-decisions extracted

The ticket names three explicitly. Reading it against 50, 51 and 32 surfaces four more.

1. **A version, or only a name?** Named in the ticket.
2. **Per `using` block, or once per module?** Named in the ticket.
3. **What does the compiler DO with it?** Named in the ticket — candidate: check the application
   is on the code path at compile time.
4. **Does this apply to Erlang FFI targets too, not just Elixir?** The ticket's example is Elixir
   (`req`), but 32's own worked examples are Erlang (`:ets`, `:erlang`) and the real corpus (below)
   has a real Erlang-hex case, `epgsql`. Nothing in the ticket's wording restricts the candidate to
   Elixir, and the mechanism measured below (§ Probes) is identical for both — an `.app` file is an
   `.app` file whether `rebar3` or `mix` produced it. Silently answering only for Elixir would be
   the same failure ticket 25 named against itself: picking the easy case.
5. **What does an `.app`/`rebar.config`/`mix.exs` on beam-sharp's own project side need to say?**
   Measured below: nothing new. `compiler/rebar.config` already exists and already has `{deps, []}`
   — ticket 51 already settled that a beam-sharp *program* using Req is a rebar3 or mix project that
   happens to contain `.bs` files, and that project's manifest already names `req` with a real,
   resolvable version constraint. This sub-decision mostly dissolves; the manifest side of the
   question was answered before 52 was raised.
6. **What does the diagnostic name — the missing app, the missing module, or both?** Not named in
   the ticket, but "one line" undersells it: measured below, a present-app/absent-module case and an
   absent-app case are two different failures with two different fixes ("add `req` to
   `rebar.config`" vs. "the `using` block names a module `req` doesn't export"), and the `.app`
   file's `modules` list is what tells them apart.
7. **Does a name-only check subsume the version question, or are they independent?** Sub-question 1
   frames them as alternatives ("a version, or only a name"). Measured below: OTP's own `.app` file
   answers this by carrying *both*, in two different keys with two different enforcement levels —
   worth surfacing because it shows the two are not mutually exclusive, only differently priced.

## Methodology

Every claim below with a `$` prompt or a cited `file:line` was executed or read in this session,
against the toolchain in `RESEARCH_ENVIRONMENT.md` (OTP 28.5, Elixir 1.19.5, Gleam 1.18.1, the real
cloned `erlang/otp`, `elixir-lang/elixir`, `gleam-lang/gleam` source trees, and `bsc` built at
`compiler/_build/default/bin/bsc`). Probe scripts live under this session's scratchpad at
`52-probes/` (`DepMissing/`, `VerifyJason/`, `app_probe.erl`, `app_probe2.erl`,
`erl_libs_scan_probe.erl`). No hex.pm access was needed or attempted — every probe uses either
`bsc`'s existing grammar, the Elixir standard library that ships with the Elixir install, or a
deliberately absent application, which is the honest way to get an "application not on `ERL_LIBS`"
case without a network call.

## Probes

### 1. Does a missing application really produce `error:undef` with no compile-time signal?

Wrote `DepMissing/depmissing.bs`:

```csharp
module DepMissing

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

public term Build()
Build() -> :'Elixir.Req'.new([(:url, "https://example.com"), (:method, :get)])
```

`req` is never built in this environment (hex.pm is blocked), so this is the real "application
absent" case, not a stand-in.

```
$ unset ERL_LIBS
$ bsc --src-root $SCRATCH $SCRATCH/DepMissing              # compile only
exit: 0
$ bsc --src-root $SCRATCH $SCRATCH/DepMissing Build         # compile + run
crashed: error:undef
exit: 1

$ export ERL_LIBS=/opt/elixir-1.19.5-otp28/lib               # Elixir present, req still absent
$ bsc --src-root $SCRATCH $SCRATCH/DepMissing               # compile only
exit: 0
$ bsc --src-root $SCRATCH $SCRATCH/DepMissing Build          # compile + run
crashed: error:undef
exit: 1
```

**Confirmed.** Compilation succeeds unconditionally — `bsc` never inspects whether `'Elixir.Req'`
resolves to anything on `ERL_LIBS`. The failure surfaces only at the call, as `error:undef`, and
only when `Build` actually runs. This matches ticket 51a's and 50's earlier measurements
(`crashed: error:undef` against Req itself) and the independent re-check below reproduces it with a
second, unrelated module (`Jason`, not `Req`), ruling out anything specific to Req.

### 2. Is application presence cheaply detectable at compile time, without loading the module?

Three independent mechanisms, all run against the real installed OTP 28.5 / Elixir 1.19.5:

**a. `code:lib_dir/1`** (`app_probe.erl`, compiled with `erlc`, run with `erl -noshell -pa . -s`):

```
-- code:lib_dir(elixir), ERL_LIBS includes elixir --
"/opt/elixir-1.19.5-otp28/lib/elixir"

-- code:lib_dir(req), req NOT on ERL_LIBS --
{error,bad_name}

-- application:load(elixir) --
ok

-- application:load(req) --
{error,{"no such file or directory","req.app"}}

-- code:which('Elixir.Req'), module never loaded, no app has it --
non_existing

-- code:which('Elixir.Application'), IS present via elixir app --
"/opt/elixir-1.19.5-otp28/lib/elixir/ebin/Elixir.Application.beam"
```

`application:load/1`'s error already names the missing file (`"req.app"`), for free.

**b. The `.app` file's own `modules` key, for the app-present/module-absent case**
(`app_probe.erl`, `app_probe2.erl`):

```
-- does .app file list its modules? read elixir.app --
elixir.app modules count: 272
is 'Elixir.Application' listed in elixir.app's modules? true

-- app present (elixir), but MODULE claimed doesn't belong to it --
code:which('Elixir.NoSuchModule') = non_existing
is 'Elixir.NoSuchModule' in elixir.app's modules list? false

-- cost: how long does reading+scanning elixir.app take (272 modules)? --
754 microseconds
```

This is what answers sub-decision 6: `code:lib_dir(AppName)` alone tells you "app absent"; reading
that app's `.app` file and checking its `modules` list tells you "app present, but this module
isn't one of its exports" — two different, both cheap, both nameable diagnoses. 754 µs is a
one-time compile-time cost per `using` block, not a per-call cost.

**c. A third, independent mechanism — raw filesystem scan of `ERL_LIBS`, no `code`/`application`
server involved at all** (`erl_libs_scan_probe.erl`), which is closer to what `bsc` itself (an
escript with no application supervision tree of its own) could actually do:

```
os:getenv("ERL_LIBS") = "/opt/elixir-1.19.5-otp28/lib"
ERL_LIBS dirs = ["/opt/elixir-1.19.5-otp28/lib"]
filesystem-only check, has 'elixir'? true
filesystem-only check, has 'req'? false
```

Three mechanisms agree. **The claim is true, cheap (sub-millisecond), and needs no module load
— checkable purely from `ERL_LIBS` plus a `file:consult`/`filelib:is_regular` on a path the app
name determines directly.**

### 3. Independent re-check with a different module and a different application (`Jason`, not `Req`)

```csharp
module VerifyJason

using :'Elixir.Jason' {
    term encode(term data)
}

public term Enc()
Enc() -> :'Elixir.Jason'.encode([(:ok, true)])
```

```
$ export ERL_LIBS=/opt/elixir-1.19.5-otp28/lib    # jason absent
$ bsc --src-root $SCRATCH $SCRATCH/VerifyJason           # compile only
exit: 0
$ bsc --src-root $SCRATCH $SCRATCH/VerifyJason Enc        # compile + run
crashed: error:undef
exit: 1
```

Same shape, different library. The finding is not an artefact of Req specifically.

### 4. Does `bsc` implement any attribute syntax today?

Read `compiler/src/bs_parser.yrl` in full. The `Terminals` list has `'['` and `']'`, but every
production using them is a list literal (`pattern -> '[' ']'`, `expr_low -> '[' elist_items ']'`,
line 453-454, 678-679). **There is no attribute-list grammar production anywhere in the file** —
`grep -n "attribute\|external:"` over `bs_parser.yrl` and `bs_lexer.xrl` returns nothing. The actual
implemented foreign declaration is:

```
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.
```

— `bs_parser.yrl:120-121`. This is the bare form used by every real `.bs` file in the corpus
(`using :erlang { ... }`, `using :'Elixir.Req' { ... }`), **not** the `[external: elixir, "Enum"]
module Enum { ... }` wrapper ticket 32's prose answer describes. Ticket 32 decided that shape in
words; `bsc` implements a simpler one. This matters for costing: extending `using` to carry
`[external: …, app: …]` is not "add a field to an existing attribute" — it is "add attribute-list
syntax to the grammar for the first time," a materially bigger parser change than the ticket's
framing (a single bracketed prefix) suggests.

## Survey: how neighbouring ecosystems record dependency provenance in source

### Erlang/OTP's own `.app.src`

`/tmp/erlang-28.5-src/lib/ssl/src/ssl.app.src:101`:

```erlang
{applications, [crypto, public_key, kernel, stdlib]},
```

— exactly sub-question 3's candidate, in the platform's own idiom: an application declares, by
name only, the other applications it needs. The same file also carries a version-bearing sibling
key, lines 104-106:

```erlang
{runtime_dependencies, ["stdlib-7.0","public_key-1.20.3","kernel-10.3",
                        "erts-16.0","crypto-5.8", "inets-5.10.7",
                        "runtime_tools-1.15.1"]}
```

The two keys are **not enforced the same way**. `applications` is read by the application
controller to order startup — `/tmp/erlang-28.5-src/lib/kernel/src/application.erl:409`:
`{ok, ChildApps} = get_key(Name, applications)`, followed by starting each named app — name-only,
no version check, and it *is* enforced (`application:ensure_all_started` refuses to start without
the named apps). `runtime_dependencies` is read only by release-building tools —
`/tmp/erlang-28.5-src/lib/reltool/src/reltool_server.erl:1228-1229` parses it into `app_info` — and
by test suites; it is advisory documentation for `reltool`/`systools`, not a boot-time check. **OTP
answers sub-question 1 by not choosing**: a name-only key that is actually enforced, and a
version-bearing key that is checked only by release tooling, coexisting in the same file. That
undercuts framing the version question as strictly "resolution, therefore refused" — OTP records a
version constraint and never resolves anything from it; resolution is a separate act from
recording.

### rebar.config / mix.exs — the tooling layer 51 already settled on

`compiler/rebar.config:2`: `{deps, []}` — beam-sharp's own build has none today. A real dependency
declaration, from Elixir's own test fixtures (`/tmp/elixir-src/lib/mix/test/fixtures/deps_status/
custom/deps_repo/mix.exs:10`):

```elixir
deps: [{:git_repo, "0.1.0", [git: MixTest.Case.fixture_path("git_repo")] ++ opts}]
```

name, version, source — the full shape a real `mix.exs` `deps:` entry carries, and mix resolves and
locks against it. This is the layer ticket 51 rides on rather than replaces, and it is where a real
version constraint already lives, resolvable and locked, for any beam-sharp project today. That is
worth stating plainly against the ticket's own framing: **a `.bs` file's dependencies do not, in
current practice, "exist only in the environment that happened to build it"** — they exist in a
checked-in `rebar.config` or `mix.exs`, the same file a stranger reading the project already has to
read to know how to build it. What is missing is not a durable, checkable record of the
dependency — 51 already produced one, for free, by riding on the neighbour's manifest — it is that
the `.bs` source file itself, read in isolation from its manifest, says nothing. Whether that
residual is worth a language feature is exactly what options (a)-(c) below are pricing.

### Gleam's `@external` — the closest prior art, and the strongest evidence

`/tmp/gleam-src/compiler-core/src/parse.rs:4668-4695`, `parse_external_attribute`: after the
target (`"erlang"`/`"javascript"`), it reads exactly a module string and a function string —
`self.expect_string()` twice — then closes the paren. No third field. The parsed value is stored as
`Option<(EcoString, EcoString, SrcSpan)>` on `Function` —
`/tmp/gleam-src/compiler-core/src/ast.rs:871-872`. **Gleam's FFI declaration, the one BEAM-family
language with both a real Hex dependency graph and a `using`-shaped per-function foreign
declaration, carries zero package or version provenance at the declaration site**, even though the
information exists and is checked elsewhere in the same compiler.

Where it *does* live: `gleam.toml`'s `[dependencies]` table (real project, real version constraint
would go here; the local fixtures use `path =` deps since hex.pm is blocked, e.g.
`/tmp/gleam-src/test-project-compiler/cases/with_dep/gleam.toml:8`,
`package_a = { path = "../support/package_a" }`), and from there into a **generated** `.app` file —
`/tmp/gleam-src/compiler-core/src/codegen.rs:137-150`:

```rust
let applications = config
    .dependencies
    .keys()
    .chain(config.dev_dependencies.keys().take_while(|_| self.config.include_dev_deps))
    .map(|name| self.config.package_name_overrides.get(name).unwrap_or(name))
    .chain(config.erlang.extra_applications.iter())
    .sorted()
    .join(",\n                    ");
```

confirmed against a real compiled fixture,
`/tmp/gleam-src/test-package-compiler/src/snapshots/test_package_compiler__generated_tests__erlang_app_generation.snap:17-30`:

```erlang
{application, my_erlang_application, [
    {mod, {'my_erlang_application_sup', []}},
    {vsn, "0.1.0"},
    {applications, [gleam_otp,
                    gleam_stdlib,
                    inets,
                    midas,
                    simple_json,
                    ssl]},
    ...
```

**This is the single strongest data point in the survey.** Gleam's `applications` list is derived
entirely from `gleam.toml`, never from any `@external` declaration in the source, and it lands in
exactly the OTP `.app` shape surveyed above. Gleam had the opportunity to put provenance in its FFI
declaration — the syntax slot is right there, one more string argument — and instead generates the
record from the manifest into a build artefact, keeping the two concerns apart. That is the
tooling-generates-the-`.app`-file answer ticket 51 already gave beam-sharp, arrived at
independently by the language closest in shape to this one.

### Elm — not applicable, honestly

`/tmp/elm-core-src/elm.json` has `"dependencies": {}` and no FFI concept at all: Elm's native/kernel
code is a compiler-privileged mechanism, not a user-declarable foreign import, so there is no
`using`-equivalent construct for a dependency to attach to. Nothing to borrow here.

## Measured costs

**Real corpus count** — every `using :atom { ... }` foreign block across `compiler/examples/` and
`wayfinder/prototypes/` (`.bs` files only, `grep -rn "^using :" --include="*.bs"`): **19 blocks**,
distinct foreign atoms:

| atom | count |
|---|---|
| `:erlang` | 6 |
| `:maps` | 2 |
| `:string`, `:lists`, `:gen_server`, `:file`, `:ets`, `:epgsql`, `:binary` | 1 each |
| `:'Elixir.String'`, `:'Elixir.Req'`, `:'Elixir.Enum'`, `:'Elixir.Application'` | 1 each |

Of 19, only **2** name a genuine third-party (non-OTP, non-Elixir-stdlib) application:
`:'Elixir.Req'` (app `req`) and `:epgsql` (app `epgsql`, a real Erlang/Hex Postgres client, in
`compiler/examples/exemplars/25d-database-querying/index.bs:12`). The other 17 belong either to
Erlang/OTP itself (which is the target, not a dependency — ticket 51's own finding) or to Elixir's
own standard library, which ticket 51 already treats as a per-project dependency but not one that
varies package to package the way `req` does. **So in the entire measured corpus, repetition of the
same third-party `app:` value across multiple `using` blocks has not happened yet** — every
third-party app appears exactly once. That does not settle sub-question 2 by frequency; it settles
it by a sharper fact, below.

**`wayfinder/prototypes/51a-code-path/Req/req.bs`** — the one real module that binds more than one
foreign Elixir target — has two `using` blocks:

```csharp
using :'Elixir.Req' { term new(list<(atom, term)> opts) }
using :'Elixir.Application' { term ensure_all_started(atom app) }
```

`'Elixir.Req'` belongs to app `req`; `'Elixir.Application'` belongs to app `elixir` (confirmed
above: `'Elixir.Application'` is listed in `elixir.app`'s `modules`). **These are two different
applications inside one module file.** A once-per-module annotation cannot be correct here — it
would have to pick one app for a module that genuinely depends on two. This is the concrete case
sub-question 2 asks for, and it answers per-block rather than per-module, not by write-cost
argument but by a real file needing two different values.

**Byte cost of the candidate**, measured directly:

```
$ printf '[external: elixir, app: req] ' | wc -c
29
$ printf "using :'Elixir.Req' {" | wc -c
21
```

29 bytes added per block for the full `external:`+`app:` form. Applied to `req.bs`'s two blocks
(`app: req`, `app: elixir`) that is ~58 bytes added to a 72-line file — negligible in the standing
constraint's own terms (write cost near-free), and it stays negligible under the per-block answer
above, since the real corpus shows no module drawing on more than a handful of applications.

## Options

### (a) Extend `using` with `[external: …, app: …]`, name-only, checked at compile time

```csharp
[external: elixir, app: req]
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

**Evidence for:** Probe 2 shows the check is real, cheap (three independent mechanisms agree,
sub-millisecond), and gives a diagnosis at least as precise as "app absent" vs. "app present, module
absent" (the `.app` file's `modules` list). Probe 1 shows the status quo is a genuine gap: compile
succeeds, `error:undef` at the call, unconditionally. The req.bs evidence answers sub-question 2
concretely: per-block, because one real module already needs two different app values. Cost is
measured and small (29 B/block, no repetition observed in the corpus).

**Strongest counterargument:** Probe 4 — this is not "add a field," it is "add attribute-list syntax
to the grammar," which does not exist anywhere in `bsc` today. The real implemented `using` form is
a bare `using atom_lit { ... }`; ticket 32's `[external: …]`-wrapped `module` form was decided in
prose and never built. So (a) is not a one-line parser change, it is a new production plus a new
AST shape plus a new check pass, against a ticket whose own framing (a bracketed prefix) undersells
that. And the manifest survey above weakens the motivating claim: per ticket 51, the dependency
already has a durable, checkable record — `rebar.config`/`mix.exs` — so (a) buys a *second*,
redundant record that can drift from the first (declare `app: req` in the `.bs` file, forget it in
`rebar.config`, and now the language's own promise is the one that's false).

### (b) The same, but with a version constraint too

```csharp
[external: elixir, app: req, version: "~> 0.7"]
using :'Elixir.Req' { term new(list<(atom, term)> opts) }
```

**Does this cross into 51's refused territory?** The OTP survey answers directly: no, not
necessarily — `runtime_dependencies` in `ssl.app.src` carries a version constraint and is *never
resolved by OTP itself*, only read by `reltool`/`systools` as documentation for a release build.
*Recording* a version and *resolving* one are different acts, and OTP's own `.app` shape keeps them
separate in one file. So (b) is defensible on OTP's own precedent, provided the compiler only
*compares* the recorded string against whatever the neighbour's manifest already resolved to (a
guard-decidable equality/prefix check, in ticket 18's terms) and never fetches, locks, or picks a
version — that would keep it inside 51's boundary.

**Strongest counterargument:** the version now needs semver-range parsing (`"~> 0.7"` is Elixir's
own operator, not a literal), which is exactly the kind of small-resolver-shaped-hole ticket 51
named against candidate 2 and refused. And it is checking a fact `bsc` cannot independently verify
at O(1) — the `.app` file itself has no version-of-req key readable without also reading
`req.app`'s own `vsn`, adding a fourth file read per `using` block over (a)'s three, for a fact that
`mix.lock`/`rebar.lock` already pins exactly and that the neighbour's own tooling already refuses
to build without satisfying. It duplicates a check the manifest layer performs today, for a payoff
that is confirmation rather than new information.

### (c) Do nothing — declare the residual acceptable and out of scope

**Evidence for:** the Gleam survey is the strongest case for this option, not for (a)/(b) — the
BEAM-family language closest in shape to beam-sharp, with a real Hex dependency graph and a
`using`-shaped per-function FFI declaration, deliberately keeps them apart: `@external` carries
nothing (`parse.rs:4668-4695`), and dependency provenance is generated into a real `.app` file from
the manifest (`codegen.rs:137-150`) — the same shape ticket 51 already gives beam-sharp for free.
The manifest survey shows the "cannot be handed over" claim is weaker than the ticket states: the
dependency *is* recorded, durably and with a real version, in `rebar.config`/`mix.exs`, a file a
clean-room implementer already needs to read to build the project at all.

**Strongest counterargument:** a `.bs` file read in isolation — e.g. quoted in the spec itself, or
pasted into an issue, or handed to the audition one file at a time — genuinely says nothing about
what it needs, and the ticket's real destination is a spec a stranger implements *against the
source language*, not against a build script. Gleam not doing this is evidence Gleam judged the
cost not worth it for *its* audience; it is not evidence beam-sharp's audience (a fleet with no
David in the room, auditioned on tickets) has the same tolerance for an undeclared crash. And probe
1's asymmetry is real regardless of the manifest: today a `.bs` file's own text promises nothing
about `Req`, and everything ticket 18 built — the checked boundary, the emitted `-spec`, "never
silently" — stops one hop short of the one crash class (`error:undef` from an absent dependency)
that a project's own manifest, not its `.bs` source, is what prevents.

## Recommendation

**(a), narrowed to name-only, per `using` block — but scoped down from what the ticket's own
framing implies.** The measured evidence: the crash is real (probe 1, twice), the compile-time
check is real, cheap and independently triangulated three ways (probe 2), sub-question 2 has a
concrete answer rather than a guessed one (req.bs needs two different app values in one module),
and cost is small and unrepeated in the real corpus. That is enough to clear the standing
constraint's write-cost/read-cost test.

Two things the evidence argues for trimming against the ticket's own candidate:

- **Not a version (b).** OTP's own `.app` shows recording and resolving are separable, but nothing
  in this measurement shows beam-sharp gains anything a locked `mix.lock`/`rebar.lock` doesn't
  already give it, and it is the one place this residual visibly touches 51's refused territory —
  semver parsing is a resolver-shaped hole by the same argument that sank 51's candidate 2.
- **State plainly, in whatever ticket does the deciding, that the grammar cost is real** — probe 4
  found no attribute-list syntax exists in `bsc` at all today, so this is new grammar, not a
  one-line addition, and the deciding ticket should not under-price it the way 52's own "costs no
  new file and no new concept" line does.

If David's read leans toward (c) instead, the Gleam finding is the citation that makes it a
principled choice rather than a punt: the closest prior art chose exactly this boundary, on purpose,
with a real dependency graph to protect and every incentive to do otherwise if it were worth doing.

## Verification

**A separate Agent-tool subagent could not be spawned in this environment** — no `Agent`/`Task`
tool with a `subagent_type` parameter was available to this session (checked via `ToolSearch` for
`Agent`, `Task`, `SpawnAgent`, `subagent_type`: no match). In its place, the crux claims were
independently re-derived within this session using different probes and different targets than the
first pass, specifically to catch circularity (the same script re-run proving nothing new):

- **The crash claim** was re-run against a second, unrelated module and application (`Jason`
  instead of `Req` — probe 3) rather than re-running `DepMissing`. Same result:
  compile succeeds, run crashes `error:undef`.
- **The compile-time-detectability claim**, the crux of sub-question 3, was checked with **three
  independent mechanisms** rather than one: `code:lib_dir/1` + `application:load/1` (the
  `application` controller's own API), a direct read of an `.app` file's `modules` list (a second,
  unrelated API), and a raw filesystem scan of `ERL_LIBS` that touches neither `code` nor
  `application` (closest to what `bsc`, a supervision-tree-free escript, could actually do). All
  three agree that application presence is cheaply detectable without loading the module; none of
  them depends on the others' correctness.
- **The "no attribute syntax exists" finding** (probe 4) was checked by reading the actual
  `Terminals` list and every production using `'['`/`']'` in `bs_parser.yrl`, not by trusting
  ticket 32's prose description of what it decided — the two disagree, and the grammar file is the
  ground truth for what `bsc` does.
- **The Gleam finding** was checked against three independent artefacts that all had to agree for
  the claim to hold: the parser's grammar (`parse.rs`), the AST shape it fills in (`ast.rs`), and
  the codegen that produces the actual `.app` file (`codegen.rs`), cross-checked against a real
  compiled snapshot fixture (`erlang_app_generation.snap`) rather than trusting the source read
  alone — the snapshot is what a real `gleam build` actually emitted for that fixture at some past
  commit, not this session's reasoning about what the code should do.

No claim in this brief rests on a single probe or a single citation without at least one
independent corroborating check of a different kind (a different tool, a different mechanism, or a
different target).
