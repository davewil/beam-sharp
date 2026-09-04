# Decision brief — ticket 52: dependency provenance

Status: research only. This does not resolve ticket 52; David makes the call. Ticket left open,
nothing in `wayfinder/` touched.

## What's undecided, precisely

Ticket 51 settled that beam-sharp builds no dependency tool: `bsc` reads whatever `ERL_LIBS`
already points at, produced by rebar3 or mix, and needs no compiler change to do it. That leaves a
gap 51 named but didn't close: **nothing in a `.bs` file records which OTP applications the program
actually needs.** `using :'Elixir.Req' { term new(list<(atom, term)> opts) }` names the *module*
`'Elixir.Req'`. It says nothing about the *application* `req`, so a file that compiles cleanly on a
machine whose `ERL_LIBS` happens to include Req's `ebin` will compile just as cleanly on a machine
without it — and then crash at the call site with `error:undef`, having declared nothing. Ticket
52 asks three sub-questions about whether and how to close that gap: name-only or name+version,
per-`using`-block or once-per-module, and what the compiler is meant to *do* with whatever is
declared.

## A load-bearing fact ticket 52's own candidate predates

Ticket 52 (raised 2026-08-21) proposes `[external: elixir, app: req] using :'Elixir.Req' { … }` —
bracket-attribute syntax on the existing `using` line. **Ticket 22, resolved 2026-08-23, measured
that this syntax has never once shipped anywhere in this compiler, and that every time it was
proposed a keyword was built instead:**

| Proposed in prose | What actually shipped | Where |
|---|---|---|
| `[Erlang("ets", "lookup")]` | `using :ets { … }` | `compiler/src/bs_parser.yrl:134-135` |
| `[module: GenServer]` | `behaviour GenServer` | `compiler/src/bs_parser.yrl:127` |

22's own count: *"zero lines beginning with `[` in all 99 `.bs` files in the repo"* (wayfinder/issues/22-how-opinionated.md:94-95), and *"`[` and `]` reach the grammar only in list syntax"* (ibid., confirmed independently below). This is a general architectural fact, not scoped to DDD attributes — 22 states the mechanism plainly: *"a lexer rule, a `decl` arm, an AST node and a checker pass before the first domain attribute exists."* I re-verified it directly against the live grammar rather than trusting the citation:

```
$ grep -n "'\['" compiler/src/bs_parser.yrl
28:  '=' '|' '|>' '|?>' ',' '(' ')' '[' ']' '{' '}' '..' '.' ':' '?'
541:pattern -> '[' ']'          : {p_nil, line('$1')}.
542:pattern -> '[' plist_items ']' :
748:expr -> '[' ']'          : {e_nil, line('$1')}.
749:expr -> '[' elist_items ']' :
```

`[` and `]` are terminals used only for list literals and list patterns, nowhere else. So this
brief treats `[external: …]` as prose shorthand for "an attribute of this kind," not as a candidate
spelling that survives contact with the codebase — any option below that keeps this exact syntax
should be read as importing new grammar (a bracket-attribute production, plus everywhere it
interacts with list-literal parsing) that this project has twice built and twice discarded in
favor of a keyword. The real current grammar for a foreign declaration is flatter than the ticket's
candidate assumes:

```
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.
```
— `compiler/src/bs_parser.yrl:134-135`, confirmed against `wayfinder/prototypes/51a-code-path/Req/req.bs`,
a real `.bs` file that binds Req today: `using :'Elixir.Req' { term new(list<(atom, term)> opts) }`,
flat, no module wrapper, no attribute — despite ticket 32's own resolution prose describing a
`[external: erlang, "ets"] module Ets { … }` shape that also never shipped.

## How real BEAM-family tools solve this — surveyed against real files

**rebar3, this project's own.** `compiler/rebar.config:2` is `{deps, [].}` — no dependency today,
and `compiler/rebar.lock` is `[].` to match. `rebar3 tree` confirms: `└─ bsc─0.1.0 (project app)`,
nothing else. To see the *shape* rebar3 uses when a dependency exists, I generated a fresh
`rebar3 new app` scaffold (which itself writes `{deps, []}.`, matching the compiler's own file —
this is rebar3's standard convention, not something special to this repo) and added
`{deps, [{req, "0.5.6"}]}.`. Running `rebar3 compile` against it:

```
===> Verifying dependencies...
===> Failed to update package req from repo hexpm
===> Package not found in any repo: req 0.5.6
```
(`artifacts/52-dependency-provenance/probes/rebar_probe/rebar3_compile_with_dep.log`)

This is the sharpest single piece of evidence in this brief: **a version constraint in rebar3 is
not inert data — writing one is live input to a resolver that goes and tries to satisfy it.**
`repo.hex.pm` is blocked in this sandbox (403, organization policy — see below), so the specific
failure is a network block, but the *mechanism* it triggered is real: naming a version is naming a
promise rebar3 tries to keep by fetching. This directly informs sub-question 1: version syntax in a
declaration invites exactly the resolution behavior ticket 51 refused to build.

**Elixir/mix.** `mix new probe_app` generates a real `mix.exs`; its `deps/0` is:
```elixir
defp deps do
  [
    # {:dep_from_hexpm, "~> 0.3.0"},
    # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  ]
end
```
(`artifacts/52-dependency-provenance/probes/mix_probe/mix.exs`, before edit) — confirming the shape
is `{atom_name, version_requirement_string, opts}`. I added `{:req, "~> 0.5"}` and ran
`mix deps.get`; it failed for a different, equally real reason — `Could not find Hex, which is
needed to build dependency :req` / `Could not find an SCM for dependency :req` — because `mix
local.hex --force` itself needs network (blocked) to install the Hex archive
(`artifacts/52-dependency-provenance/probes/mix_probe/mix_deps_get.log`). Structurally this
confirms the same point rebar3 did: mix's manifest carries name **and** version range together, and
resolving either needs a live registry.

**Elm.** Both an application `elm.json` and a package `elm.json` are genuinely different shapes —
`"dependencies": {"direct": {...}, "indirect": {...}}` with **exact pinned versions** for an
application, versus version **ranges** for a package — but I could not generate either for real
here: `elm init` needs to fetch `https://package.elm-lang.org/all-packages` *before writing
anything, even for zero dependencies*, and that host is blocked in this sandbox (403, same
organization policy as `repo.hex.pm`). `~/.elm/0.19.1/packages` holds only an empty `lock` file, no
cached index to fall back to. See `artifacts/52-dependency-provenance/probes/elm_probe/elm_init_attempt.log`.
**I am not fabricating `elm.json`'s content** — the exact-vs-range application/package split above
is well-documented public convention, stable across the 0.19.x line, but it is marked `doc` here,
not measured in this environment, and I could not verify it against a freshly generated file as
instructed. It is nonetheless a real, sharp precedent for sub-question 1 if David wants to weigh it:
Elm's own answer to "name only, or name+version" is **neither, uniformly** — it's exact-pin for the
artifact that runs and range for the artifact that gets composed into other things, and a `.bs`
program is structurally the former, not the latter.

**Gleam.** Not installed, cannot be installed here (no apt package, GitHub API blocked). The repo
does hold one real, local `gleam.toml`, from an earlier ticket's prototype
(`wayfinder/prototypes/22a_incomplete_marker_probe/gleam_todo/gleam.toml`):
```toml
name = "gleam_todo"
version = "1.0.0"
target = "erlang"
```
— but this project declares **zero** dependencies, so it is evidence only that `gleam.toml` exists
and has this top-level shape; it says nothing about how a dependency line looks. That part of the
survey is unverified here and marked `doc` per the task's instruction — do not treat any
`[dependencies]`-section claim about `gleam.toml` in this brief as anything but recalled, unrun
knowledge.

## What a compile-time check would actually cost — measured against this compiler

**No existing mechanism checks a *foreign* declared module's presence at compile time.** The only
`code:ensure_loaded/1` / `code:which/1`-adjacent calls in `compiler/src/` are for the compiler's
*own emitted* module, at run time, after compilation has already produced a `.beam` —
`bsc.erl:700` (`repl/2`), `bs_run.erl:26`, `bs_repl.erl:70`, and `bs_batch.erl:249`'s VM-reuse
bookkeeping. None of them touch a foreign atom named in a `using` line, and none of them run during
`bs_check`.

**But the check is cheap, and I ran it standalone rather than estimating it.**
`artifacts/52-dependency-provenance/probes/codepath_probe/probe.sh` (output captured verbatim in
`probe_output.txt`):

```
=== (1) code:which/1, ERL_LIBS unset ===
non_existing
=== (1) code:which/1, ERL_LIBS pointed at the app root ===
".../fauxapp/ebin/fauxmod.beam"
=== (2) application:get_application/1 on a real, loaded stdlib module ===
lists -> {ok,stdlib}
=== (2) application:get_application/1 on fauxmod: on the path, but no .app file names it ===
fauxmod -> undefined
=== (2) same probe against REAL Elixir (Elixir.Enum) ===
which -> ".../elixir/ebin/Elixir.Enum.beam"
get_application (no explicit load) -> undefined
get_application (after application:load(elixir)) -> {ok,elixir}
```

Two findings, both load-bearing:

1. **`code:which/1` is exactly the free, O(1)-ish probe ticket 52 guesses at.** `non_existing` vs a
   real path, controlled purely by `ERL_LIBS`, using nothing but the atom a `using` line already
   carries — no new declaration is needed for *this* check to exist. It reproduces ticket 51's own
   finding (`ERL_LIBS` is honoured by the code server) at the single-module grain a compile-time
   check needs.
2. **The application name is not mechanically recoverable from the module atom when it's missing.**
   `application:get_application/1` returns `undefined` for a module that is perfectly loadable but
   whose `.app` resource hasn't been explicitly `application:load/1`-ed — true even for real
   Elixir's own `Elixir.Enum`, part of the genuine `elixir` OTP application. So `code:which` alone
   can tell you *whether* a foreign module is reachable, but if it says no, it cannot tell you *what
   to fetch*. That gap is exactly what a declared application name is for, and it is evidence
   independent of the version question — this part of ticket 52's candidate earns its keep even
   though the version part is the risky one.

**Where the check would live, concretely.** `compiler/src/bs_check.erl:594-602`, `callees/3`,
already iterates every foreign declaration with the module atom in scope:
```erlang
Foreign = [begin
               admissible_foreign_ret(L, Mod, N, R, Env),
               {{f, Mod, N, length(Ps)}, sig(Ps, R, Env)}
           end
           || {foreign, _, Mod, Sigs} <- Decls,
              {foreign_sig, L, N, R, Ps} <- Sigs],
```
`admissible_foreign_ret/5` (`bs_check.erl:619-623`) is the existing precedent for exactly this
shape of check — a per-declaration compile-time diagnostic raised as
`erlang:error({opaque_ret_at_boundary, Line, Mod, Fun})`. A presence check is the same pattern: one
more clause, `code:which(Mod)`, one more error tuple. This is a grounded, not hand-wavy, estimate —
it is the same site, the same pattern, and the atom is already there.

**One real cost this check would introduce, not zero.** Grepping the currently-gated corpus:
```
$ grep -n "using :'Elixir" LANGUAGE.md TOUR.md
(no matches)
```
No fenced example in `LANGUAGE.md` or `TOUR.md` uses Elixir FFI today, so this check costs nothing
against the existing `check-language.sh`/`check-tour.sh` gates. But the Req exemplar ticket 50
still owes will be exactly such an example, and once it lands, a compile-time presence check makes
*compiling* that file — not just running it — depend on `ERL_LIBS` being correctly set wherever
`bsc` runs, CI included. Ticket 51 already logged that the Req exemplar makes CI "the first gate
here to depend on the network" (for the fetch); a compile-time presence check extends that to "the
first gate whose *compile* step depends on environment," even on a runner that already has the
`.beam` files sitting on disk from a prior fetch.

**A second real limit, orthogonal to cost.** The check can only ever attest to the *build* machine's
`ERL_LIBS`, per ticket 51's own finding that Elixir/Req are build-time-installed and run-time-file-
only. A `.bs` file that compiles clean under this check on the machine that built it says nothing
about the machine it deploys to, unless that machine's `ERL_LIBS` matches. This is not a defect in
the check — it is the honest ceiling of "check presence, don't resolve," and the brief should not
let a green compile read as a stronger guarantee than that.

## Options

**(a) Name-only, per-`using`-block, checked at compile time via `code:which/1`-style probing.**
The check itself needs no new declaration at all — the module atom already in `using :'Elixir.Req'
{ … }` is sufficient input to `code:which/1`, and the site to add it (`bs_check.erl:596-602`)
already exists in the shape this needs. What a name-only declaration *adds beyond the check* is
provenance for a reader/agent: `code:which` failing tells you "not found," an attached app name
tells you what to go fetch. Cheapest to build, matches ticket 22's "keyword, not bracket" precedent
if spelled as an extension to the existing `using`/`foreign_decl` production rather than a new
attribute syntax. Strongest counter: because `code:which` already works off the bare atom, the
*declaration* half of this option is doing less real work than it looks — it is confirmable
documentation, not a new capability the compiler gains, and its only failure mode (someone writes
`app: wrong_name`) is never checked against anything, so it can go stale silently, same as any
comment.

**(b) Name-only, once-per-module aggregate declaration** (a list of application names living in
`index.bs`, decoupled from which specific `using` block needs which). Real basis for where it would
live: ticket 41 §4 (decisions.md:1350-1353) already made `index.bs` the sole home of every `using`
line in a module — *"index.bs is unambiguously the declaration file."* But `wayfinder/prototypes/51a-code-path/Req/req.bs`
is real, run evidence against this shape: its three `using` blocks need **two different**
applications (`req` for `'Elixir.Req'`, `elixir` for `'Elixir.Application'`) plus one needing
**none** (`:maps` is always-present Erlang stdlib). A module-level aggregate can't collapse to one
line even in the simplest real exemplar this project has — it becomes a second list the reader has
to cross-reference against the `using` lines it's meant to describe, paying CLAUDE.md's standing
read-cost tax (the write-cost savings ticket 52 itself flags as "the write cost the standing
constraint prices as near-free" would be real here, but on the wrong side of the ledger — the
reader pays to reassemble a mapping the per-block form gives for free). Weakest of the three on the
evidence gathered.

**(c) Name + version-range, mirroring Elm's app-vs-package split, purely advisory.** The ticket's
own candidate for the riskiest option, and the rebar3 probe sharpens exactly why: in the one real
BEAM-family tool measured here, a version string is not advisory data — writing `{req, "0.5.6"}`
made `rebar3 compile` go try to resolve it against a registry (`===> Failed to update package req
from repo hexpm`). A reader coming from rebar3 or mix — the two tools ticket 51 explicitly made
beam-sharp ride on — will bring that expectation to a `.bs` file's version syntax, and "purely
advisory, never enforced" is a promise the surrounding ecosystem's own tools do not keep for the
identical syntax. This is the sub-question 1 risk the ticket itself names — *"a version constraint
edges into resolution, which is out of scope"* — now backed by a real tool actually doing exactly
that under the identical spelling. Elm's own precedent (unverified live here, but well-documented)
cuts the same way from a different angle: Elm reserves ranges for **packages** meant to be
recombined by others, and pins **exact** versions for **applications** meant to run — a `.bs`
program is the latter, so "mirror Elm" argues for an exact pin or nothing, not a range, which is
not what this option as stated proposes.

## Recommendation

**Option (a), name-only, per-`using`-block** — with two amendments the evidence argues for:

1. **Spell the extension as a `using`/`foreign_decl` grammar addition, not a bracket attribute.**
   Ticket 22's measured finding — every prior `[attribute: value]` proposal in this project's design
   prose shipped as a keyword instead, and there is no bracket-attribute grammar anywhere in
   `bs_parser.yrl` today — predates ticket 52 by two days and applies to it directly. The ticket's
   own candidate spelling should be read as "carry an application name on the declaration," not as
   a commitment to bracket syntax.
2. **The compile-time check (`code:which/1` at `bs_check.erl:596-602`, following the
   `admissible_foreign_ret/5` pattern at `bs_check.erl:619-623`) is worth building independent of
   whether an app-name attribute ships**, because it needs no new syntax at all — only the atom
   already present in every `using` line. It is real, it is cheap, and it is the whole
   "turn a future `undef` into a compile diagnostic" claim ticket 52 speculates about, now
   demonstrated rather than guessed at.

The one piece of evidence that tips it: the rebar3 probe showing a version string is *live input to
a resolver* in the very tool beam-sharp rides on, set directly against ticket 51's unambiguous
refusal of resolution. Option (c) doesn't just risk reopening 51 rhetorically — it risks it in the
one concrete way this survey could actually run and check.

## What I could not verify

- **Gleam's `gleam.toml` dependency-declaration shape.** Gleam is not installed and cannot be
  installed here (no apt package; `github.com`/`api.github.com` return HTTP 403 through the proxy —
  confirmed org egress policy block, not a transient failure). The one real local `gleam.toml`
  found in this repo (`wayfinder/prototypes/22a_incomplete_marker_probe/gleam_todo/gleam.toml`)
  declares zero dependencies, so it evidences the file's existence and top-level keys only, not the
  `[dependencies]` section's shape. Any claim about that section in prior wayfinder text or in this
  brief should be read as `doc`, not measured.
- **A fresh `elm.json`, application or package.** `elm init` requires fetching
  `https://package.elm-lang.org/all-packages` before writing anything at all, even with zero
  dependencies requested, and that host returned HTTP 403 through the proxy (organization policy).
  `~/.elm/0.19.1/packages` holds no cached index. The application-vs-package,
  exact-vs-range distinction cited above is well-established public documentation, stable across
  0.19.x, but it is recalled, not regenerated, in this environment.
- **hex.pm / repo.hex.pm reachability.** Tested directly: `https://hex.pm` (the marketing site)
  returns HTTP 200; `https://repo.hex.pm` (the actual package CDN mix/rebar3/hex fetch from) fails
  with a proxy CONNECT 403, same organization-policy block as `package.elm-lang.org` and
  `github.com`. `mix local.hex --force` therefore could not install Hex, and `mix deps.get` /
  `rebar3 compile` against a real dependency both failed for network reasons rather than completing
  — I captured the real failure text for both rather than the successful fetch, and I'm flagging
  that the *shape* of the manifest (name + version string) is confirmed from the generated files,
  but the full resolve-and-lock behavior (what a populated `rebar.lock`/`mix.lock` looks like for a
  real multi-package tree) is not independently re-verified in this session — it rests on ticket
  51's own prior measurement (`51a-code-path`), which I read but did not rerun, since rerunning it
  hits the identical network block.
- **rebar3's advisory-vs-enforced line beyond what I ran.** I confirmed a version constraint
  triggers real resolution machinery (fetch attempt against hexpm). I did not test what rebar3 does
  with a dependency that's only *named*, no version at all (`{deps, [req]}` with no version tuple)
  — that syntax may not even be legal rebar3; I did not check it, and the brief's claim about
  "name-only is not resolution-shaped" rests on ticket 51's `ERL_LIBS`-only path (`bsc` reading a
  directory nobody asked rebar3/mix to resolve *for it*) rather than on rebar3 itself ever being
  run in a name-only mode.
- **Whether `bs_check.erl`'s existing diagnostic-emission convention (`erlang:error/1` with a
  tagged tuple) is what a user-facing compiler error ultimately renders as**, versus being caught
  and reformatted through `bs_diag`. I read the call site and its sibling
  (`admissible_foreign_ret/5`) but did not trace the exception all the way to `bsc`'s CLI output
  formatting, so "one more clause, one more error tuple" is a grounded estimate for where the check
  goes, not a verified estimate of the full diagnostic text a user would see.
