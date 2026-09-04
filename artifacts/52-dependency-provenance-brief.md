# Decision brief: Dependency provenance: what does a `.bs` file say about what it needs? (ticket #52, ENG-234)

## Sub-decisions

The ticket's own text names three, and the survey turned up a split inside the third that the
ticket did not anticipate:

1. **Name only, or a version constraint?**
2. **Per `using` block, or once per module?**
3. **What does the compiler concretely DO with it** — and this splits into two independent
   capabilities the ticket's prose treats as one:
   - **3a. A compile-time presence check** ("is the thing this line names actually reachable right
     now") — turns `error:undef` into a diagnostic.
   - **3b. A durable provenance record** ("what would someone with nothing fetched yet need to go
     get") — the clean-room-handoff argument ticket 51 raised this ticket for.

   The evidence below shows 3a needs **no new syntax at all** — it is answerable from the module
   atom a `using` line already carries — while 3b is the part that actually requires deciding 1 and
   2. Conflating them makes the ticket look like it needs a bigger feature than it does.

A fourth question the ticket does not ask, but which the evidence forces into the open: **is there
any attribute-grammar mechanism to extend in the first place?** The ticket's own candidate
(`[external: elixir, app: req] using :'Elixir.Req' { … }`) assumes yes. Measured against the
checked-in parser: no.

## Evidence

### Preliminary finding: the ticket's own candidate syntax cannot be "extended" — it doesn't exist

Ticket 52's candidate is a bracket attribute, `[external: elixir, app: req]`, stacked on the
`using` line. Ticket 22 (resolved 2026-08-23) already measured this exact question for two other
constructs and found **"no attribute grammar has ever existed"** — `[Erlang("ets","lookup")]` and
`[module: GenServer]` both appear only in `wayfinder/` prose, never in `bs_parser.yrl`, and both
were built as *keywords* (`using :ets { … }`, `behaviour GenServer`) instead. I re-derived this
independently against the current grammar rather than trusting the citation:

- Probe: `artifacts/52-probes/52a_no_attribute_grammar.sh` — claim: "no bracket-attribute
  production exists in `bs_parser.yrl`, and no `.bs` file in the repo has one."
  Output:
  ```
  === 2. The full 'decl' alternation -- every top-level declaration form the parser accepts ===
  79:decl -> module_decl : '$1'.
  80:decl -> type_decl   : '$1'.
  81:decl -> signature   : '$1'.
  82:decl -> clause      : '$1'.
  83:decl -> foreign_decl : '$1'.
  84:decl -> behaviour_decl : '$1'.
  85:decl -> record_decl : '$1'.
  86:decl -> using_decl  : '$1'.

  === 3. The foreign declaration production, verbatim, as it exists TODAY ===
  134:foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
  135-    {foreign, line('$1'), value('$2'), '$4'}.

  === 4. Every .bs file in the repo: does any line begin with '[' (an attribute)? ===
  files with a line starting '[': 2
  ./compiler/examples/exemplars/25e-dynamic-web-page/render.bs:21:  [("content-type", ...
  ./compiler/examples/exemplars/25d-database-querying/sql.bs:14:     [s])
  ...
  ```
  (The two files that matched are wrapped list-literal continuations — `[("content-type", …)]` and
  `[s])` — not attributes; `grep` on line-start `[` was deliberately permissive and still found
  nothing bracket-attribute-shaped.)

**Consequence for the ticket's own framing:** the "candidate 51 captured" is not a cheap extension
of an existing mechanism. It is a new mechanism — a lexer rule, a `decl` arm, an AST node and a
checker pass, per ticket 22's own accounting — for a project that has twice chosen a keyword
instead when it needed exactly this. Any option below that still wants bracket syntax should own
that cost explicitly rather than inherit "it costs no new concept" from the residual text.

### Sub-decision 3a: the presence check needs no new syntax

Ticket 51 already measured that a foreign module's absence surfaces as `error:undef` at the call
site (`'Elixir.String':upcase/1` crashing when `ERL_LIBS` is unset). The question is whether
turning that into a compile-time diagnostic requires the annotation ticket 52 proposes.

- Probe: `artifacts/52-probes/52b_code_which_presence_check.escript` — claim: "`code:which/1`
  distinguishes an absent foreign module from a present one, from the bare atom a `using` line
  already carries, without loading or calling into it."
  Command: `./52b_code_which_presence_check.escript`
  Output:
  ```
  code:which('lists')            = "/usr/lib/erlang/lib/stdlib-4.3.1.3/ebin/lists.beam"
  code:which('Elixir.Req')        = non_existing (before adding it to the path)
  code:which('Elixir.Req')        = "/home/user/beam-sharp/artifacts/scratch/reqebin_stub/Elixir.Req.beam" (after add_patha, ERL_LIBS-equivalent)
  code:is_loaded('Elixir.Req')    = false (never loaded by the check itself)
  ```
  Independently re-run from a clean state: identical output (only the tmpdir name differs across
  runs of the persisted variant).

- Probe: `artifacts/52-probes/52h_foreign_tuple_blast_radius.sh` — claim: "the compiler-side cost
  of a presence check, sized against the nearest existing precedent."
  Output:
  ```
  === the ONE grammar production that builds the {foreign, ...} tuple ===
  134:foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
  135-    {foreign, line('$1'), value('$2'), '$4'}.

  === every HAND-WRITTEN site that pattern-matches {foreign, ...} (excludes generated bs_parser.erl) ===
  src/bs_check.erl:600:               || {foreign, _, Mod, Sigs} <- Decls,
  src/bs_check.erl:678:       || {foreign, _, Mod, Sigs} <- Decls,
  src/bs_check.erl:770:collapse_decl({foreign, _, _Mod, Sigs}, Env) ->

  === precedent: the diagnostic machinery a comparable NEW check costs (reserved_module_name), counted ===
  -- bs_check.erl definition --
  272:reserved_module_name(Module, Sources) ->
  273-    case lists:member(Module, reserved_qualifiers()) of
  274-        false -> ok;
  275-        true  ->
  276-            Line = case [L || {_, D} <- Sources, {module, L, N} <- D,
  277-                              N =:= Module] of
  278-                       [L | _] -> L;
  279-                       []      -> 1
  280-                   end,
  281-            erlang:error({reserved_module_name, Module, Line})
  282-    end.
  -- bs_diag.erl descriptor/2 clause --
  508:descriptor(Path, {reserved_module_name, Module, Line}) ->
  509-    #{tag => reserved_module_name, severity => error, file => Path, line => Line,
  510-      module => Module};
  -- bs_diag.erl message/1 clause --
  882:message(#{tag := reserved_module_name, file := P, line := L, module := Mod}) ->
  883-    {"~s:~p: error: `~s` is a reserved qualifier, so no module may be called it~n" ...
  ```
  A `foreign_module_absent` check follows the same shape: one function in `bs_check.erl` (~10
  lines: iterate `{foreign, Line, Mod, _} <- Decls`, `case code:which(Mod) of non_existing ->
  erlang:error(...); _ -> ok end`), called once more from `check_dir/3` beside
  `Foreigns = foreign_wrappers(Decls, Env)` (`bs_check.erl:131`), plus a `descriptor/2` and a
  `message/1` clause in `bs_diag.erl` (~10 lines). **No grammar change, no change to any of the 20
  existing foreign `using` blocks in the repo** (counted by
  `artifacts/52-probes/52h_foreign_tuple_blast_radius.sh`, second half).

- Survey: **rebar3** — `artifacts/52-probes/52e_rebar3_dependency_provenance.sh` — with a real
  local dependency declared, present: `rebar3 compile` succeeds. With the dependency removed from
  both `rebar.config` and `rebar.lock` and the calling code left untouched, **`rebar3 compile`
  succeeds silently** (exit 0, no warning) — Erlang's own compiler does not cross-check remote
  calls by default. The crash surfaces only at run time: `{'EXIT',{undef,[{rebarlib,greet,...`.
  A *separate*, non-default pass catches it: `rebar3 xref` reports
  `src/rebardemo_app.erl:4: Warning: rebardemo_app:start/2 calls undefined function
  rebarlib:greet/1 (Xref)` and exits 1. This is rebar3's own working precedent for exactly the
  "turn `error:undef` into a diagnostic" move ticket 52 asks about — and it needs no dependency
  *declaration* at all, only a static cross-reference pass, which is closer to what `code:which`
  buys `bsc` than to a manifest check.
- Survey: **Mix** — `artifacts/52-probes/52d_mix_dependency_provenance.sh` — with a dependency
  *declared but not present*, `mix compile` refuses outright before running anything:
  `Unchecked dependencies for environment dev: * libdep (../libdep) the dependency is not
  available ** (Mix) Can't continue due to errors on dependencies` (exit 1). With the dependency
  *undeclared* but still called, `mix compile` only warns —
  `warning: Libdep.greet/1 is undefined (module Libdep is not available or is yet to be defined)`
  — and still exits 0; the crash is deferred to `mix run`:
  `** (UndefinedFunctionError) function Libdep.greet/1 is undefined`. So Mix's *hard* check is
  keyed on its own declared-dependency bookkeeping (analogous to 3b below); its *soft* check
  (source-level, a warning) is keyed on nothing but the call itself, exactly like `code:which`
  would be for `bsc`.

**Conclusion for 3a: buildable now, independent of 1 and 2, at roughly 20 lines across two files.**
It answers "is what this line names reachable" using only the atom the line already has.

### Sub-decision 3b, and why it needs an annotation after all

`code:which/1` only answers the question once *some* build environment already exists (an
`ERL_LIBS` value, a `rebar3`/`mix` tree, however incomplete). It cannot help someone starting from
nothing decide what to fetch — that is ticket 51's "clean-room handoff" scenario, and it is the
actual argument for this ticket existing at all.

- Probe: `artifacts/52-probes/52c_derive_app_from_codepath.sh` — claim: "once a dependency **is**
  on the code path, the OTP application name is mechanically derivable from `code:which/1`'s
  returned path, because rebar3 and mix always lay out `.../<app>/ebin/<Module>.beam` (ticket 51's
  own measured shape) — so no annotation is needed even for *naming* the app, in that case."
  Output:
  ```
  code:which('Elixir.Req')                     = /tmp/.../req/ebin/Elixir.Req.beam
  app dir one level up from ebin/               = /tmp/.../req
  app name derived purely from directory layout = req

  === Control: what happens if the SAME module atom is asked for and it is NOT on the path? ===
  code:which('Elixir.NoSuchDep') = non_existing
  ```
  This sharpens rather than removes the case for 3b: the derivation **only works after the fetch**.
  Before anything is fetched, `code:which` returns `non_existing` for every foreign atom
  uniformly, and the module atom alone does not reliably name the package to go get — ticket 32 §3
  already measured that no mechanical mapping exists between an Erlang/Elixir atom and anything
  else in general (1,920 of 1,924 stdlib+kernel names map, but 265 module names and a quarter of
  Elixir's function names do not, under any rule), and the umbrella case is worse than that: a
  module like `'Elixir.Enum'` ships inside the `elixir` OTP application, not an application called
  `enum` — the segment-lowercasing that works for `Req` → `req` does not generalize.

So **3b is real and is what an annotation would buy**: a fact readable by a human or an agent with
nothing built yet, which the module atom cannot supply and which `code:which` cannot supply until
after the first fetch — the exact moment the fact would already need to be known.

### Sub-decision 1: name only, or a version constraint?

- Survey: **Elixir/Mix** — `mix.exs`'s generated `deps/0`
  (`artifacts/52-probes/52d_mix_dependency_provenance.sh`, opening section) shows the real,
  unedited shape: `{:dep_from_hexpm, "~> 0.3.0"}` — name plus a range.
- Survey: **Gleam** — `gleam.toml`, real output of `gleam new demo`
  (`artifacts/52-probes/52f_gleam_dependency_provenance.sh`):
  ```
  [dependencies]
  gleam_stdlib = ">= 0.44.0 and < 2.0.0"

  [dev-dependencies]
  gleeunit = ">= 1.0.0 and < 2.0.0"
  ```
  Real behavioural test of what a version constraint COSTS at compile time: `gleam build` with
  only the scaffolded dependencies (no source written yet) reaches for the network before
  compiling anything at all:
  ```
    Resolving versions
  error: Dependency resolution failed
  ...
  Unable to determine package versions: error sending request for url
  (https://repo.hex.pm/packages/gleeunit)
  ```
  (This sandbox cannot reach `repo.hex.pm`, captured verbatim as the real error rather than
  worked around — see the Elm section below for the same wall from a different tool, and the
  agent-proxy's own denial log.) The important fact is structural, not that the network is down
  here: **a version *range* is not a fact source can check against anything by itself** — it
  requires a resolver to turn it into one concrete package, and Gleam's own architecture makes
  `gleam build` inseparable from that resolution step, even when nothing in the program has been
  compiled yet. A control with *zero* dependencies declared and none imported builds in 0.3s with
  no network attempt (`gleam build` → `Compiling demo … Compiled in 0.30s`, exit 0) — confirming
  the network reach is caused by the version-range dependency declaration, not by `gleam build`
  unconditionally.
- Survey: **Elm** — `elm.json`. Real fetched application manifest
  (`artifacts/52-probes/elm-real-examples/elm-todomvc.elm.json`, from
  `raw.githubusercontent.com/evancz/elm-todomvc`, on the CDN allowlist):
  ```
  "dependencies": {
      "direct": {
          "elm/browser": "1.0.2", "elm/core": "1.0.2",
          "elm/html": "1.0.0", "elm/json": "1.1.3"
      },
      "indirect": { "elm/time": "1.0.0", "elm/url": "1.0.0", "elm/virtual-dom": "1.0.2" }
  }
  ```
  Elm goes further than a range: application manifests pin **exact resolved versions** and record
  the **whole transitive closure** (`direct` vs `indirect`) directly in the file that ships with
  the program — Elm's `elm.json` folds what Mix and Gleam keep in a separate lock file into the
  same file as the "dependency" declaration. This is even further into resolver territory than a
  range, not less. **I could not execute a live `elm init`/`elm make` in this sandbox** — the
  egress proxy denies `package.elm-lang.org` outright (`ProxyConnectException
  "package.elm-lang.org" 403 Forbidden`, captured in
  `artifacts/52-probes/52g_elm_manifest_and_network_block.sh`'s output, and confirmed independently
  from the proxy's own status endpoint), and Elm's own CLI refuses to write `elm.json` at all
  without first fetching the full package index — so I report the manifest **shape** from real,
  fetched source and explicitly do **not** claim anything about Elm's own compile-time behaviour
  toward a missing dependency, which is untested here.
- Survey: **rebar3** — `rebar.config`'s `{deps, [...]}`. This repo's own
  `compiler/rebar.config` declares `{deps, []}` (no dependencies — `bsc` has none), so it is not a
  positive example of the *shape*, but it is a clean confirmation of ticket 51's premise: a
  beam-sharp-family project can be a real, building rebar3 project with an empty dependency list.
  The scratch project in `52e` shows the populated shape: `{deps, [{rebarlib, {git, "...", {tag,
  "0.1.0"}}}]}` — name plus a source location plus, optionally, a version-ish ref (a git tag or a
  Hex version string); rebar3 does not itself refuse an unpinned `git` dependency, so among the
  four ecosystems it is the least insistent on a version being present at all.

**What this means for beam-sharp specifically:** ticket 51 already decided beam-sharp has no
resolver and never will (scope.md's boundary, upheld without bending). A version constraint written
in a `.bs` file would be unenforceable by `bsc` — there is nothing in the compiler that could ever
check `req >= 0.7` against what's actually on `ERL_LIBS`, because doing so needs exactly the
resolution machinery ticket 51 refused. Every neighbour that carries a version constraint (Mix,
Gleam, Elm) also carries a resolver to make it meaningful; the one neighbour without a mandatory
resolver posture in its dependency line (rebar3, which accepts a bare `git` ref) is also the one
ticket 51 already named as "the neighbour to prefer." A name-only annotation is the only shape that
doesn't write a promise `bsc` cannot keep.

### Sub-decision 2: per `using` block, or once per module?

This one is not open in the way the ticket frames it — ticket 41 §1 already decided the adjacent
question. Quoting `wayfinder/decisions.md`'s entry for ticket 41: *"It also answers 23 §11
directly: **a file's `using` lines are its dependency list.**"* That is a standing, resolved
statement that the `using` line — one per foreign module, per ticket 32 §2's "per function [but]
the binding is per module" precedent — is already where this project puts dependency information,
not a directory-level or module-level manifest. Concretely, `wayfinder/prototypes/51a-code-path/`'s
own `req.bs` has two separate `using` lines side by side, `:'Elixir.Req'` and
`:'Elixir.Application'`, which in a real Req binding are not obviously the same OTP application —
tying provenance to the line that already names the module keeps one fact in one place, rather than
inventing a second place (a module-level "requires" list) that could name an application no
`using` line in the file actually reaches, or omit one that a `using` line does.

## Options

### Option A: no new syntax — a compile-time presence check derived from the existing `using` atom, and the provenance question left open

```csharp
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```
(unchanged from today — see `wayfinder/prototypes/51a-code-path/Req/req.bs`)

Compiler delta: `bs_check.erl` gains one ~10-line function (`foreign_module_present/1`, iterating
`{foreign, Line, Mod, _} <- Decls` and calling `code:which(Mod)`), invoked once more from
`check_dir/3`; `bs_diag.erl` gains one `descriptor/2` clause and one `message/1` clause (~10 lines
combined). No grammar change. No existing `.bs` file needs editing.

- Evidence for: `52b`, `52h` above; ~20 lines total, buildable independent of any answer to
  sub-decisions 1 or 2.
- Strongest counterargument: it does not touch 3b at all. It answers "does the machine building
  this right now have it," never "what would a machine with nothing fetched need to go get" — which
  is the literal scenario ticket 51 wrote this ticket to cover (*"a program whose dependencies
  exist only in the environment that happened to build it cannot be handed over"*). Shipping only
  this closes the ticket's stated motivation without addressing it.

### Option B: extend `using` with a name-only, per-block application atom — no bracket attribute

```csharp
using :'Elixir.Req', :req {
    term new(list<(atom, term)> opts)
}

using :'Elixir.Application', :elixir {
    term ensure_all_started(atom)
}
```

Grammar delta (`bs_parser.yrl:134-135`): add a second production so the annotation is optional and
no existing file needs to change —
```erlang
foreign_decl -> 'using' atom_lit ',' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), value('$4'), '$6'}.
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), undefined, '$4'}.
```
The `foreign` tuple grows one field, touching the 3 hand-written match sites `52h` counted
(`bs_check.erl:600,678,770`, each needs one more wildcard). Combined with Option A's presence
check (which can now also check the *named* application via `application:load/1` / `.app`
resource, not just the bare module), total cost is on the order of 40-50 lines across
`bs_parser.yrl`, `bs_check.erl`, `bs_diag.erl` — no bracket-attribute machinery, and it follows the
project's own precedent (ticket 22) of extending a construct with more of itself rather than
inventing attributes.

- Evidence for: `52c` (the atom cannot always be mechanically mapped to an application name, so
  something must supply it by hand); `52a`/ticket 22 (attribute syntax is the expensive path,
  this is not it); ticket 41 §1 (per-line is already the decided home for dependency facts).
- Strongest counterargument: on the ~1,920-of-1,924 cases where the atom-to-name mapping *would*
  have worked (ticket 32 §3's own census), this is ceremony that says nothing a reader couldn't
  already read off the module atom (`'Elixir.Req'` → `req` is not exactly cryptic) — paying the
  standing constraint's "near-free to write, never free to read" cost on every ordinary case to
  cover the umbrella-app and unspellable-name minority. It is the same regressive-cost shape ticket
  32's own answer rejected once already (Elixir's zero-ceremony FFI, penalizing the common case to
  spare the rare one) — except here the annotation is the thing paying the tax, not the thing being
  taxed, so the argument does not transfer cleanly and is worth someone weighing directly rather
  than assumed either way.

### Option C: do nothing further; leave the residual open

No source change. `ERL_LIBS`/`rebar.config`/`mix.exs` remain the only record, exactly ticket 51's
status quo.

- Evidence for: it is free, and ticket 51 already shipped its half of the story without this.
- Strongest counterargument: it is the option ticket 51 explicitly declined to leave as the final
  answer, in its own words — *"a program whose dependencies exist only in the environment that
  happened to build it cannot be handed over"* is the stated reason this ticket exists at all.
  Choosing C is choosing to re-close the residual 51 deliberately left open, which the ticket's own
  notes say not to do by accident (it says not to *reopen* 51, but reopening 51 and declining to
  answer 52 land in the same place for the clean-room-handoff argument).

## Recommendation

Split 3a from 3b, because the evidence shows they have different costs and different owners. **3a
(the presence check) needs no design decision and no new syntax** — it can be built today, exactly
as Option A describes, and should not wait on this ticket resolving 1 or 2. **3b (provenance for a
clean-room handoff) is where the ticket's real content lives**, and the evidence points at Option
B's shape specifically: name-only (never a version — nothing in `bsc` could ever check one, per
ticket 51's own refusal of a resolver, and every neighbour that carries a version also carries the
resolver machinery to make it meaningful), attached per `using` block (ticket 41 §1's "a file's
`using` lines are its dependency list" already made the line the unit of record, and two
`using` lines in one real file can legitimately name two different applications), and spelled as a
second atom on the existing `using` production rather than as a bracket attribute (ticket 22
already paid for, and rejected, the alternative). The strongest open objection — ceremony on the
~99% of cases where the name is already legible in the module atom — is real and is the one
argument in this brief that evidence alone doesn't resolve; it is a judgment call about whether a
uniformly-applied small tax reads better than a rule with a silent gap, and David has decided that
exact shape of question before (ticket 32's Gleam-vs-C#-vs-mapping choice) by reading the code
rather than a table, so the concrete two-line example above is offered for exactly that reading
rather than as a closed case.

## Verification

**No subagent-spawning tool was available in this environment** (checked via tool search; my own
task instructions additionally direct me not to re-delegate this assignment wholesale), so the
common file's "spawn one verifier subagent" step was performed by me instead, as an independent
re-execution pass rather than a second opinion — a real gap against the intended process, recorded
here rather than silently substituted.

What I did: re-ran every probe script from a clean state a second time (fresh `mktemp -d` working
directories throughout, so no state could leak between runs) and diffed the output against what is
pasted into this brief.

- `52a`, `52b`, `52h`: byte-for-byte identical on re-run.
- `52c`, `52e`: identical modulo the random tmpdir path in the output text (expected, and itself
  confirms the script isn't reading a cached/hard-coded answer).
- `52d`: byte-for-byte identical, including the exact Mix warning and crash text.
- `52f`: identical except the reported compile time (0.30s vs. 0.28s on re-run) — expected
  timing noise, and the network-resolution failure reproduced with the same proxy denial both
  times, which rules out a fluke.
- `52g`: not re-run as a script (it documents a blocked network path, not a computed result); the
  proxy's own `/__agentproxy/status` endpoint was queried directly as a second, independent source
  for the same denial rather than trusting the tool's own error message alone.

Checked for circularity: `52c`'s derivation (app name from `code:which`'s path via
`filename:dirname/1` twice) is generic path arithmetic, not tuned to produce a chosen answer — the
directory shape it relies on (`.../<app>/ebin/<Module>.beam`) is the same shape independently
reproduced by the real `mix compile` and `rebar3 compile` runs in `52d` and `52e`
(`_build/default/lib/rebardemo/ebin`, `_build/dev/lib/libdep/ebin`), not asserted only by the
probe that uses it. No probe in this set asserts a claim about its own output; each one runs a
real external tool (`mix`, `rebar3`, `gleam`, `erl`/`escript`) or greps the actual checked-in
compiler source, and the brief quotes what came back rather than a paraphrase.

One claim I drafted first and then cut for lack of support: an early draft asserted Elm's
`elm.json` "always" separates `direct`/`indirect` the way `elm-todomvc`'s does. That is true of the
one real fetched example but I have exactly one live example and no executed Elm build to
generalize from, so the brief above states it only as "the real fetched example shows" rather than
as a rule.
