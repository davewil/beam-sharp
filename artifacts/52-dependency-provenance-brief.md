# Decision brief — ticket 52, dependency provenance

**Autonomous research. Not a decision. Ticket 52 / ENG-234 is left OPEN for David.**

Session: 2026-09-08. Nothing in `wayfinder/issues/52-dependency-provenance.md`, its Linear issue,
or any ticket file was edited to produce this. This file lives at
`artifacts/52-dependency-provenance-brief.md` and is not committed.

---

## 0. A correction this brief owes before anything else

Ticket 52's own candidate syntax is:

```csharp
[external: elixir, app: req] using :'Elixir.Req' { … }
```

This is not buildable as written, and not because of ticket 52 — **ticket 22 (resolved
2026-08-23, nine days after 52 was raised) measured that no attribute-bracket grammar has ever
existed in the compiler**, for either of the two places prose in the tickets had described one:

| Prose in the tickets | What `bsc` actually parses today |
|---|---|
| `[Erlang("ets", "lookup")]` (ticket 22's own citation) | `using :ets { … }` — `compiler/src/bs_parser.yrl:120-121` |
| `[external: erlang, "ets"] module Ets { … }` (ticket 32's *Answer*, 2026-08-14) | same: `using :ets { … }` |

I read the grammar myself rather than trusting either ticket's prose:

```
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.
```
— `compiler/src/bs_parser.yrl:120-121`, confirmed against `compiler/examples/Foreign/foreign.bs`,
`compiler/examples/exemplars/25e-dynamic-web-page/index.bs` and both of 50/51's own prototypes
(`wayfinder/prototypes/50a-elixir-ffi/Elx/elx.bs:10`, `wayfinder/prototypes/51a-code-path/Req/req.bs:37`),
all of which write `using :Module { … }` and none of which write `[external: …]`. Ticket 22 §"1"
found **zero lines beginning with `[` in all 99 `.bs` files in the repo** and corrected ticket 32's
prose in place: *"no attribute grammar has ever existed in the compiler, and both prose attributes
were built as keywords instead."* Ticket 32's `Answer` section was written nine days before that
correction landed and was never updated to match — the two tickets now disagree about the language's
own grammar, and 22 is the one that was checked against code.

**Consequence for 52:** any option that reintroduces bracket-attribute syntax (`[external: …,
app: …]`) is proposing exactly the construct 22 spent itself refusing, for the same reason 22
refused it — it is new lexer + parser + AST machinery for a shape nothing else in the language uses,
where the keyword form 22 found already does the job at `using`. The options below are written
against the real grammar, not the stale sketch.

---

## 1. The three sub-questions, restated against what's already decided

Ticket 52 asks three things. Grepping `wayfinder/issues/` first, per CLAUDE.md:

1. **Where does provenance live?** Nowhere new (ticket 51's manifest — `rebar.config`/`mix.exs` —
   already carries it, checked into the same repo); on the existing `using` declaration; or a new
   file. Ticket 51 (resolved) already ruled out beam-sharp owning a manifest of its own — "beam-sharp
   builds no dependency tool" — so a *new file* is not on the table; that part of 52's own question
   is closed by 51 and 52's Notes section says as much ("do not re-open 51").
2. **What does it record?** Ticket 52 already leans against a version ("a version constraint is
   resolution, which is the boundary's territory and should stay refused") — consistent with 51's
   closed boundary. This brief's measurements back that lean with a mechanism-level reason, not just
   a scope-line one (§3 below).
3. **What's the compiler's obligation?** Ticket 52 guesses "one line… turns a run-time `error:undef`
   into a diagnostic." **Measured below: it is one line, it needs no new syntax at all, and it can be
   built today against the declaration that already exists.**

Ticket 32 (FFI surface, resolved) and ticket 50 (foreign struct naming, resolved) constrain the
shape further: 32 §2 established the module *name* is the thing already bound and that "no
snake_case⇄PascalCase rule anywhere in the language" means the atom is written verbatim, quoted; 32
§8 already accepted that beam-sharp's FFI diverges from both Gleam's and C#'s unchecked precedent —
so a compiler-side check here is the language being consistent with itself, not a new posture.

---

## 2. Real probes run, with real file:line citations

Environment: OTP 25 (`erl`), Elixir 1.14.0, rebar3 3.22.1 (installed via `apt-get install rebar3` —
it was not preinstalled; `apt-cache search rebar3` found it, matching the environment's own guidance
to try apt before giving up). `mix`/`rebar3` package-registry host `repo.hex.pm` is **blocked** by
this session's egress policy (`curl https://repo.hex.pm/... ` → `CONNECT tunnel failed, response
403`; `hex.pm` itself, the marketing site, returns `200` — the two hosts are policed differently).
Git access to `github.com` over the git protocol works even though a bare `curl https://github.com`
returns `403` — confirmed with `git ls-remote`. So every probe below uses a **real, network-fetched
git dependency** rather than a hex one; where a real hex-resolved lockfile was needed, I read one
that a real hex dependency's own already-checked-in `mix.lock` provided (§2.2). Gleam is not
installed and was not touched — nothing about Gleam is claimed here.

### 2.1 A real rebar3 project, a real git dependency, the real build

`rebar3 new app appprobe`, then real `rebar.config`:

```erlang
{deps, [
    {jsx, {git, "https://github.com/talentdeficit/jsx.git", {tag, "v3.1.0"}}}
]}.
```

`rebar3 compile` fetched and built it for real. **`rebar.lock`, in full** (`appprobe/rebar.lock`,
4 lines, 129 bytes):

```erlang
[{<<"jsx">>,
  {git,"https://github.com/talentdeficit/jsx.git",
       {ref,"bb9b3e570a7efe331eed0900c3a5188043a850d7"}},
  0}].
```

**No semantic version anywhere in a git-sourced rebar.lock entry** — only a URL and a resolved
commit SHA. Whatever "version" a git dependency has is not a fact rebar3's own lock format records
for it.

The **compiled** `.app` file it produced is a different story —
`appprobe/_build/default/lib/jsx/ebin/jsx.app`:

```erlang
{application,jsx,
             [{description,"a streaming, evented json parsing toolkit"},
              {vsn,"3.1.0"},
              {modules,[jsx,jsx_config,jsx_consult,jsx_decoder,jsx_encoder,
                        jsx_parser,jsx_to_json,jsx_to_term,jsx_verify]},
              {registered,[]},
              {applications,[kernel,stdlib]},
              ...]}.
```

`{vsn, "3.1.0"}` comes from `jsx`'s own `src/jsx.app.src`, copied through by rebar3 at build time —
it is not recorded by the *lock* file, it is recorded by the **package's own `.app` metadata**,
which is what actually ends up on the code path and is what `ERL_LIBS` resolution can see.

The build layout is exactly the `ERL_LIBS` shape ticket 51 already established:
`_build/default/lib/<app>/ebin/<app>.app` and `.beam` files, one directory per application.

### 2.2 A real hex-resolved lockfile — req's own, fetched for real

`repo.hex.pm` is blocked, so req itself can't be resolved as a hex dependency here — but a *git*
dependency on the real `req` repo (`{:req, git: "https://github.com/wojtekmach/req.git", tag:
"v0.5.18"}` in a real `mix new reqprobe --sup` project, `mix deps.get`) pulls down req's own
already-committed `mix.lock`, generated by the req maintainers' real, hex-resolved
`mix deps.get` — a genuine artifact, not one I fabricated. `deps/req/mix.lock`, 32 lines, 8860
bytes, opening line:

```elixir
%{
  "finch": {:hex, :finch, "0.22.0", "5c48fa...", [:mix], [{:mime, "~> 1.0 or ~> 2.0", [...]}, ...], "hexpm", "b94e83c4..."},
  "jason": {:hex, :jason, "1.4.4", "b92267...", [:mix], [{:decimal, "~> 1.0 or ~> 2.0", [...]}], "hexpm", "c5eb0cab..."},
  ...
```

18 entries total, each `{:hex, name, "semver", outer_hash, [build_tools], [{dep, constraint,
[...]} …], "hexpm", inner_hash}`. This is real, current confirmation of what ticket 51 measured
against the live Req tree in its own environment (nine packages there; 18 including req's dev/test
deps here) — a **mix.lock entry always carries a version and a hash; a rebar.lock git entry never
carries either.** That asymmetry is a property of the *source kind* (registry vs. git), not of the
tool — rebar3 has its own hex-resolved lock shape too, and it looks like mix's (name, version,
hash), just unreachable to demonstrate here for the same network reason.

### 2.3 The load-bearing measurement: `bsc` today says nothing, silently, and it doesn't have to

Fresh dependency (not reusing 50a/51a's Req prototype), against the real, already-built `bsc`
escript at `compiler/_build/default/bin/bsc`:

```csharp
// JsxProbe/jsxprobe.bs
module JsxProbe

using :jsx {
    binary encode(term t)
}

public binary Encode(term t)
Encode(t) -> :jsx.encode(t)
```

Run with a **fully scrubbed environment** (`env -i`, not just an unset variable) to rule out shell
leakage, and independently reproduced twice:

| | command | result |
|---|---|---|
| compiles | `bsc --src-root … JsxProbe` | **exit 0, no output** — compiles whether or not `jsx` exists anywhere |
| runs, no `ERL_LIBS` | `bsc … JsxProbe Encode '#{a => 1}'` | `crashed: error:undef`, exit 1 |
| runs, `ERL_LIBS` at the real fetched jsx | same | `"{"a":1}"`, exit 0 |

This is ticket 52's own opening claim, independently confirmed against a library it didn't use and
the actual current compiler binary, not taken on the tickets' word.

**And the fix is one stdlib call, needing no new syntax**, tested against both an Erlang and an
Elixir foreign module, clean-env, both directions:

```erlang
%% Erlang: jsx, absent then present
code:ensure_loaded(jsx).           %% clean env: {error,nofile}
%%  … ERL_LIBS set to the real fetched build …
code:ensure_loaded(jsx).           %% {module,jsx}
application:load(jsx),
application:get_key(jsx, vsn).     %% {ok,"3.1.0"}

%% Elixir: 'Elixir.Enum', absent then present (ERL_LIBS = /usr/lib/elixir/lib)
code:ensure_loaded('Elixir.Enum'). %% clean env: {error,nofile}; with ERL_LIBS: {module,'Elixir.Enum'}
application:load(elixir),
application:get_key(elixir, vsn). %% {ok,"1.14.0"}
```

Every one of these is `code:ensure_loaded/1` or `application:load/1` plus `application:get_key/2` —
functions already in OTP's `kernel` app, callable from anywhere `bsc` itself runs (it is already a
rebar3 escript on the same VM, per ticket 51). **The atom this needs is already sitting in the
parsed `foreign` declaration** — `bs_check.erl:448-457`'s `callees/3` already destructures
`{foreign, _, Mod, Sigs} <- Decls` for every foreign block in the module; a presence check is one
more clause in that same list comprehension, keyed on the same `Mod`.

---

## 3. Three options, each as B# source plus the compiler delta

### Option A — no new syntax. The compiler checks the module atom that's already there.

```csharp
// index.bs — unchanged from what 50a/51a already write
module Req

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

**Compiler delta:** in `callees/3` (`bs_check.erl:448-457`), for each distinct `Mod` across a
module's `foreign` declarations, call `code:ensure_loaded(Mod)` against whatever `ERL_LIBS` `bsc`
itself was invoked with, and turn a `{error, nofile}` into a compile diagnostic — *"error:
'Elixir.Req' is declared at line 3 but not on the code path (checked $ERL_LIBS)"* — instead of
deferring to `crashed: error:undef` at the call site. §2.3 measured this is exactly one existing
BIF, called on data the parser already produces.

**Evidence:** §2.3, twice, clean-env, both an Erlang and an Elixir foreign module.

**Strongest counterargument — this doesn't answer the ticket.** Ticket 52's actual complaint is the
clean-room handoff: *"a program whose dependencies exist only in the environment that happened to
build it cannot be handed over."* A presence check that passes on a correctly-configured CI machine
tells a stranger nothing about which of the thousands of packages on hex.pm they need to go fetch to
make **their** machine correctly configured — it converts a silent runtime crash into a compile-time
one, on the machine that already has the answer, and is mute on every machine that doesn't. It also
has a narrow false-negative shape: the check is per-atom, so a module that happens to be
coincidentally present under an unrelated `ERL_LIBS` entry passes without actually being the
intended dependency — vanishingly unlikely for an `'Elixir.'`-prefixed atom in practice, but a real
gap for a bare Erlang name.

### Option B — the declaration names the owning application too, no version, no brackets

```csharp
// index.bs — same `using` keyword, one more atom
using :'Elixir.Req' (:req) {
    term new(list<(atom, term)> opts)
}
```

**Compiler delta:** extend `foreign_decl` in `bs_parser.yrl:120-121` from
`'using' atom_lit '{' foreign_sigs '}'` to accept an optional `'(' atom_lit ')'` between the module
atom and the block — one more atom_lit slot, no new token class, no new keyword, no bracket-attribute
grammar (so it does not repeat ticket 22's refused shape). At check time, call
`application:load(AppAtom)` and `application:get_key(AppAtom, vsn)` instead of the bare
`code:ensure_loaded(ModuleAtom)` — the diagnostic can now name the actual OTP application
(`"application 'req' is not on the code path — is it in rebar.config / mix.exs?"`), which is a more
actionable message than naming a bare module atom, and it puts a durable fact — *this module comes
from application `req`* — into the `.bs` source itself, readable with no environment at all.

**Evidence:** §2.3's clean-env `application:load` / `application:get_key` runs, which work
identically whether the atom comes from a bare foreign declaration or a second declared atom — the
mechanism doesn't care where the app name came from, only that one is supplied.

**Strongest counterargument — the census that answered ticket 32 §3 answers this the same way, and
against it.** 32 measured that mechanical name-mapping fails 265 of ~2,200 module names but a
*mapping* was never proposed here — what's proposed is a **second required fact per declaration**,
and the module:application relationship is not 1:1 the way 32's naming question needed it to be:
Elixir's own convention (top namespace segment ≈ app name) is exactly the convention ticket 50
already found broken for macros (`MACRO-__using__` is exported by the `elixir` app under the
`Elixir.Kernel` namespace, not a 1:1 mapping at all), and nothing stops a hex package from exporting
a module whose name shares nothing with its app. So `(:req)` can **lie** — declare the wrong app,
or a stale one after a rename — and nothing catches that until `application:load` fails for a
different reason than the one the message names, which is a worse diagnostic than Option A's, not a
better one, for the cost of new grammar. And for the ~99.8% of foreign declarations that name
`kernel`/`stdlib` modules (`erlang`, `lists`, `maps`, `file`, …, per 32b's census), this is ceremony
that states a fact everyone already knows and the compiler doesn't need told — exactly the
"regressive cost, near-free to write and non-free to read, worst on the trivial cases" shape ticket
32's own Answer already rejected once, for the *same reason*, on a different question.

### Option C — the neighbour's manifest already is the provenance record; nothing in `.bs` changes; ship Option A's check alongside it

```csharp
// index.bs — identical to Option A
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```
```erlang
% rebar.config — checked into the same repo, per ticket 51's resolved answer
{deps, [{req, {git, "https://github.com/wojtekmach/req.git", {tag, "v0.7.3"}}}]}.
{plugins, [rebar_mix]}.
```

**Nothing new is decided here** — this is ticket 51's resolution taken at face value: *"beam-sharp
builds no dependency tool. It reads what rebar3 or mix already produced."* §2.1/§2.2 show that
manifest, once resolved, already **is** a durable, versioned, checksummed provenance record —
`rebar.lock`/`mix.lock` name every transitive dependency with exact version and hash, which is
strictly more than any hand-written `.bs` annotation would state, and it costs nothing new to build
because it already exists and is already how `bsc` reaches Req today. Combine with Option A's
compile-time presence check (free, §2.3) to close the "silent `error:undef`" complaint that opens
ticket 52, without opening any new grammar question.

**Evidence:** §2.1, §2.2 — real, inspected lockfiles, not summarized ones. Ticket 51's own resolution
text, which already reasoned this far and stopped one ticket short of saying it plainly.

**Strongest counterargument — this is the one that doesn't answer the ticket's literal question,
on purpose.** David's own framing in 52 is *"what does a `.bs` file say about what it needs"* — a
**file**, not a repo. A `.bs` file pasted into a spec example, extracted for a test fixture, or read
in isolation by the clean-room implementer 52 exists to serve, says nothing under this option, ever
— the burden is entirely "keep the manifest beside the source," which is a repo-layout convention,
not a language guarantee, and conventions are exactly the kind of thing this project's own working
rules distrust when nothing enforces them. If the spec's answer to *"how does a stranger know what
this program needs"* is *"go find the neighbouring `rebar.config`,"* that may be the right answer —
but it is a different kind of answer than the ticket asked for, and it should be chosen as that,
consciously, not arrived at by default.

---

## 4. Recommendation

**A, framed as the free half of C — not B.**

Build Option A's compile-time presence check now: it is measured, costs one BIF call against data
the parser already produces, needs no grammar change, and directly closes the concrete failure mode
ticket 52 opens with (a silent `error:undef` where the declaration "promised nothing"). Treat actual
provenance-for-handoff as **already answered by ticket 51**, per Option C — the resolved manifest
sitting beside the `.bs` source is a better record than anything cheap to embed in the source itself
(§2.1 vs. §2.2's own numbers: a git dependency's version isn't even recorded by its lockfile, only
its resolved commit — so a hand-written version annotation in `.bs` would be recording a fact that
for a git-sourced dependency **rebar3 itself does not consider well-defined**).

Do not build Option B. Its own census-shaped counterargument is the same one that already won a
prior ticket (32 §3) on the same evidence pattern, and it adds a fact — the owning application —
that can drift from true because module→application is not the 1:1 relationship the declaration
would need it to be, per ticket 50's own finding about Elixir's namespace convention.

If David wants the file-level guarantee Option C explicitly declines to give — a `.bs` file that is
self-describing with **no** neighbouring manifest, for the spec-example or extracted-fixture case —
that is a real, distinct want and Option B is closer to it than A or C; it should be asked for
by that name rather than folded into "provenance" generally, since it is the one thing here that
actually costs new grammar.

---

## 5. Independent verification note

Ground rule 5 asked for a separate verifier subagent via an "Agent tool." **No tool for spawning a
subagent was available in this session** — I checked the deferred-tool list (`ToolSearch` for
`Agent`/`Task`/`TaskCreate`/`SpawnAgent`) and none exists; this session's own instructions describe
it as already the dedicated agent for the task and direct it not to re-delegate the whole assignment
to a single subagent. In its place I re-ran every probe myself from a **fully scrubbed environment**
(`env -i`, not merely an unset variable) in a second pass after the first, specifically adversarial
to the possibility that inherited shell state was doing the work rather than the mechanism claimed:

- `bsc` compile/run-without/run-with sequence (§2.3): identical results, exit codes 0/1/0, jsx probe.
- `code:ensure_loaded` / `application:load`/`get_key` for both `jsx` and `'Elixir.Enum'`/`elixir`,
  clean env, absent-then-present: identical results both times.
- `md5sum` on the generated `rebar.lock` and req's fetched `mix.lock` between passes: unchanged,
  ruling out a probe that mutated its own evidence between the write-up and this check.

I could not independently re-verify the two claims this brief takes on trust rather than measuring
directly: that `repo.hex.pm` being blocked in **this** sandbox generalizes to the environment ticket
51's own measurements were taken in (51's Req numbers are almost certainly from a different, less
restricted environment — its own text implies real HTTP was never itself performed, only build-time
fetches, which this session's network could not repeat for a hex-sourced package). Flagged rather
than asserted either way.
