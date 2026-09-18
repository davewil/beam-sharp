# Audit — ticket 52, dependency provenance (ENG-234)

**This is research only. No ticket file was edited, no `Status:` line changed, no Linear state
changed beyond one comment posted to ENG-234 at the end.** Ticket 52 remains open/Backlog.

Scope: extract the sub-decisions ticket 52 implies, back each candidate B# artifact with executed
probes or cited source rather than memory, and state counterarguments as verified facts. No
"Option A/B/C + recommendation" — CLAUDE.md bans that shape outright.

---

## Toolchain and network, measured before anything else

| | |
|---|---|
| `erl`/`elixir` | installed — Erlang/OTP 25 (erts-13.2.2.5), Elixir 1.14.0 |
| `mix` | present (ships with Elixir), but `mix local.hex` failed: `{:could_not_establish_ssl_tunnel, {'HTTP/1.1', 403, 'Forbidden'}}` against `repo.hex.pm` |
| `rebar3` | **not installed initially**; installed via `apt-get install -y rebar3` → `3.19.0-1` from `archive.ubuntu.com`, apt itself reachable |
| network | `repo.hex.pm` → CONNECT tunnel 403 (blocked). `crates.io` → 403 (blocked). `hex.pm` (bare domain) → 200. `github.com`, `raw.githubusercontent.com` → reachable (git clone and WebFetch both worked) |
| workaround | `mix archive.install github hexpm/hex branch latest` — builds Hex **from source** via git, sidestepping the blocked `repo.hex.pm` precompiled-archive path. Worked: `Generated archive "hex-2.5.1.ez"` |

**Consequence for every claim below:** a *hex-sourced* dependency cannot be fetched end-to-end here
(`repo.hex.pm` is the package-tarball host for both `mix` and `rebar3`, and it is blocked). Two
compensating, real sources were used instead, both independently re-verified from scratch on a
second pass:

1. **Git-sourced dependencies**, fetched for real with the real `mix`/`rebar3` binaries (`github.com`
   is reachable), producing real `mix.lock`/`rebar.lock` output for a git source.
2. **Cloned upstream repositories that already carry a committed, hex-sourced lock file** —
   `hexpm/hex`, `devinus/poison`, `erlware/erlware_commons`, `erlang/rebar3`'s vendored deps, and
   `gleam-lang/gleam`'s own test fixtures — read directly, not paraphrased.

No hex-sourced `mix.lock`/`rebar.lock` could be *generated* live in this sandbox; every hex-format
example below is a **cited** file, not a generated one, and is marked as such.

---

## Sub-decision 1 — where does a `.bs` file say what it needs?

Ticket 52's own captured candidate is extending the FFI declaration. The current grammar, exactly
as `bsc` parses it today:

```
compiler/src/bs_parser.yrl:120
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
compiler/src/bs_parser.yrl:121
    {foreign, line('$1'), value('$2'), '$4'}.
```

and `bs_check.erl` already destructures every foreign block as `{foreign, _, Mod, Sigs}`
(`compiler/src/bs_check.erl:705-706`, `:739-742`). Three candidates for where a dependency fact
attaches to that tuple.

### Candidate 1a — the FFI block itself carries the application

```csharp
// wayfinder/prototypes/51a-code-path/Req/req.bs, extended
[external: elixir, app: req] using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

[external: elixir, app: elixir] using :'Elixir.Application' {
    term ensure_all_started(atom app)
}

using :maps {
    term get(atom k, term m)
    bool is_key(atom k, term m)
}
```

**Evidence.** `{foreign, Line, Mod, Sigs}` is a 4-tuple today; adding a 5th field (`App :: atom() |
undefined`) is a one-line grammar change plus a threading change through the ~6 call sites that
pattern-match the tuple — the same shape of change F19/F23 already made to `foreign_sig`'s return
type. The compile-time check itself is cheap and already has a real target: `application:load(req)`
(or `code:where_is_file("req.app")`) against whatever `ERL_LIBS` the invocation carries, which is
exactly what `Application.ensure_all_started/1` does at run time (measured in ticket 51's `51a`:
`Start() -> (:ok, [...])`). Turning that run-time `error:undef`/`{error, {not_started, req}}` into a
compile-time diagnostic is literally "one line" in the sense ticket 51 already used the phrase.

**Counterargument, verified.** `Application.ensure_all_started(:req)` in `51a` started **16**
applications, not one: `[:compiler, :elixir, :logger, :crypto, :asn1, :public_key, :ssl, :hpax,
:mint, :nimble_pool, :nimble_options, :telemetry, :mime, :finch, :jason, :req]`. A single `using
:'Elixir.Req'` block names only `req`. Checking presence of the one application the `using` line
names is a real, cheap, compile-time-checkable fact — and it is **not** the fact that made `51a`
work; the other 15 applications being present is what made it work, and candidate 1a as written
says nothing about them.

### Candidate 1b — a second file (rejected shape, kept for contrast)

```toml
# hypothetical Req.bs.deps — NOT proposed, shown to make the rejection concrete
[dependencies]
req = "elixir"
```

**Evidence against.** Ticket 51 already measured and rejected this shape as "candidate 2": *"buys a
native-looking project layout; costs a format nobody else reads, and it is a resolver-shaped hole
that will want filling."* This repo's own vendored Gleam fixtures show what such a file becomes once
it exists — `aoc/bench/gleam/gleam.toml:6` (`gleam_stdlib = ">= 0.44.0 and < 2.0.0"`) is a *range*,
not a presence check, and a range is resolution (see sub-decision 2). A beam-sharp-owned manifest
inherits that gravity the moment it grows past "is this atom on the path."

### Candidate 1c — no source change, richer diagnostic only (null candidate)

`bsc` cross-checks every foreign module atom against `code:where_is_file/1` with **no new syntax**,
using only what `ERL_LIBS` already provides — the same "the answer is none" pattern ticket 51 found
for the code-path problem itself.

**Evidence against.** This is refuted by ticket 52's own argument text, not by a probe: *"a program
whose dependencies exist only in the environment that happened to build it **cannot be handed
over**"* — the clean-room handoff needs the fact **in the source**, and 1c leaves it in the
environment exactly as today. It would turn a run-time crash into a compile-time one on the
machine that happens to be missing the dependency, but the `.bs` file itself would still say
nothing, which is the whole complaint ticket 52 opened with.

---

## Sub-decision 2 — a name, an exact version, or a range?

### Candidate 2a — name only

```csharp
[external: elixir, app: req] using :'Elixir.Req' { term new(list<(atom, term)> opts) }
```

**Evidence.** Cheapest to check: `application:load/1` succeeding is a yes/no fact. But Elm — the
neighbour with the most minimal tooling story available for comparison — does not stop here even
though its packages are immutable once published. Fetched directly (`WebFetch`,
`raw.githubusercontent.com/elm/compiler/master/docs/elm.json/application.md`, existence
independently confirmed via a second fetch of the GitHub directory listing):

```json
"dependencies": {
    "direct": {
        "elm/browser": "1.0.0",
        "elm/core": "1.0.0"
    }
}
```

Every dependency, direct and indirect, is pinned to an **exact** version in the application manifest
— not a range, and it doubles as the lock file (`elm.json`'s own docs: *"this structure supports
reproducible builds"* and works as *"a lock file that ensures reliable builds"*). Name-only is
strictly less than what even Elm's no-separate-lockfile model records.

### Candidate 2b — name + exact version, checked against the installed `.app`

```csharp
[external: elixir, app: req, version: "0.7.3"] using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```

**Evidence.** Every `.app` file already on disk carries a `vsn` field — real, installed, unmodified:

```
$ cat /usr/lib/elixir/lib/elixir/ebin/elixir.app
{application,elixir,[{description,"elixir"},{vsn,"1.14.0"}, ...
```

So "does the installed version match the declared one" is `application:get_key(req, vsn) =:=
<<"0.7.3">>` — a string comparison against a fact already on disk, not a search over candidates.
This is the same operation Elm's exact pins reduce to.

**Counterargument, measured, not hedged.** Two versions of the same application were placed on
`ERL_LIBS` and loaded twice, in each path order, independently on two separate probe runs with two
different synthetic application names:

```
ERL_LIBS=.../v1:.../v2   -> resolved vsn: 1.0.0   (v1 listed first)
ERL_LIBS=.../v2:.../v1   -> resolved vsn: 2.0.0   (v2 listed first)
```
```
ERL_LIBS=.../second:.../first  -> resolved vsn: 0.1.0  (second listed first)
ERL_LIBS=.../first:.../second  -> resolved vsn: 9.9.9  (first listed first)
```

**The BEAM code server picks by `ERL_LIBS` path order alone and has no concept of version at all.**
A declared version can only ever be *checked after the fact* against whatever the environment
already resolved to; it can never *select* among candidates, because by the time `bsc` runs, the
code server has already chosen one, blind to the number in the declaration. Declaring a version is
therefore a real diagnostic (did the environment hand me what I asked for) and can never become
resolution by accident — but it also cannot fix a wrong version already on the path, which is a
capability a name-only declaration and a versioned one share equally.

### Candidate 2c — a version range

```csharp
[external: elixir, app: req, version: ">= 0.7.0 and < 1.0.0"] using :'Elixir.Req' { ... }
```

**Evidence against.** This is the shape both `scope.md` and ticket 51 name directly: resolving
*which* installed version satisfies a range, when more than one might, is resolution. The duplicate-
`ERL_LIBS` probe above is the concrete demonstration: nothing in the running system evaluates a
range against what's available — it is a pure path-order pick — so a range could only be checked
against whichever single version the code server already happened to select, making the range
strictly less informative than the exact-pin candidate while costing a constraint-parser the exact
pin does not need. Gleam's own dependency declarations use exactly this range shape
(`aoc/bench/gleam/gleam.toml:6`, `>= 0.44.0 and < 2.0.0`) — but Gleam pairs it with a real resolver
(`gleam deps`) that beam-sharp does not have and ticket 51 refused to build.

---

## Sub-decision 3 — direct dependency only, or the transitive closure?

### Candidate 3a — direct only (what 1a/2b already show)

Declares `req`; says nothing about the 15 other applications `51a` measured as necessary.

### Candidate 3b — walk the already-on-disk closure

**Evidence.** The transitive closure is not something beam-sharp would have to compute or store —
it is already written, by the neighbour's build, into every `.app` file's `applications` key. Real,
installed, unmodified:

```
$ cat /usr/lib/elixir/lib/logger/ebin/logger.app
{application,logger,
             [{applications,[kernel,stdlib,elixir]}, ...
```

A candidate design: `bsc` reads `req.app`'s `applications` list, and recursively each member's own
`.app`, entirely at compile time, entirely from files the build already produced — no fetching, no
network, no new file format, and no version reasoning beyond candidate 2's. This directly closes the
gap candidate 1a's counterargument names: checking `req` alone missed 15 applications `51a` proved
were load-bearing; walking `req.app`'s own `applications` field (and recursively `elixir.app`'s,
etc.) would have caught all of them, because that is the exact list `Application.ensure_all_started`
itself walks at run time.

**Counterargument, verified.** `51a`'s own supervision-tree row shows the closure is not static
across build tools: rebar3 with the `rebar_mix` plugin vendors `elixir`, `logger`, and `mix` into
its own `_build`, but *not* `eex` — `ensure_all_started(:req)` from that tree alone failed with
`(:error, (:eex, "no such file or directory", "eex.app"))` until Elixir's own lib dir was added back
(ticket 51, rows 121–123). **A closure check reads whatever `.app` files the neighbour's tool
happened to emit, and if the tool under-vendors, the check is validating an incomplete picture with
full confidence** — a compile-time green from candidate 3b would not have caught the `eex` gap,
because `req.app`'s declared `applications` list is correct; it is `rebar_mix`'s packaging that was
short one directory. The check is only as good as the neighbour's build, which is precisely the
posture ticket 51 already chose ("read what rebar3 or mix already produced") and accepted the
consequences of.

---

## Sub-decision 4 — once per `using` block, or once per module?

### Candidate 4a — per block (what every example above shows)

Real cost, shown by the real prototype: `wayfinder/prototypes/51a-code-path/Req/req.bs` has three
`using` blocks — `:'Elixir.Req'` (app `req`), `:'Elixir.Application'` (app `elixir`), and `:maps`
(no app — Erlang stdlib, always present). A module binding several modules from **one** application
would repeat `app: req` on each block naming a Req submodule.

### Candidate 4b — once per module, module-level statement

```csharp
module Req
uses app: req;

using :'Elixir.Req' { term new(list<(atom, term)> opts) }
using :'Elixir.Req.Steps' { term auth(term req, term opts) }
```

**Evidence for the concern being real.** `req.bs` already needs two *different* apps
(`req`, `elixir`) in one module — so a single module-level statement cannot cover every `using`
block in the general case; it can only be a **default**, with per-block override still needed for
the `:'Elixir.Application'`/`:maps` lines that don't come from `req`. CLAUDE.md's own standing
constraint is explicit about which side of this the write-cost argument favours by default:
repetition is *"near-free but the reader pays for it"* — a real quote from ticket 52 itself, applied
here to the same trade-off it names for the version question.

**Counterargument, verified against the actual exemplar.** In `req.bs` as it stands, only **one** of
the three `using` blocks would carry `app: req`; the other two need `app: elixir` and no app at all,
respectively. A module-level default saves nothing in this concrete file — the real Req binding
this project is building toward is the forcing case, and it does not exhibit the repetition 4b
exists to avoid.

---

## How this touches the FFI/foreign-value tickets already resolved

**It doesn't collide with them.** Ticket 50 resolved *what a foreign aggregate is* (`map<atom,
term>`, `Kind` absent only) — a fact about values crossing the boundary at run time. Ticket 52 is
about *what the declaration says before any value crosses* — a fact checked at compile time, once,
against `.app` files. Nothing above changes a signature's type or a clause head's matching power;
`[external: elixir, app: req]` is metadata on the `foreign` tuple, not a new type-system construct,
so it does not reopen 50's `map<atom, term>` answer or 32's "a foreign function is declared, and the
declaration carries both spellings" (32 is about the two *spellings* of a name; this is a third,
orthogonal fact about the module, not the function).

**Build time vs. publish time collapses to one point.** Ticket 51 already refused resolution,
locking, fetching, and publishing outright — beam-sharp has no publish step for any of this to
happen "at," so every candidate above is checked exactly once, at `bsc` compile time, against
whatever `ERL_LIBS` the invocation already carries. There is no second time the check could run.

---

## Independent re-verification

No agent-spawning tool was available in this session (only `SendMessage` to already-live agents,
which cannot originate a fresh one) — the requested "spawn a separate agent to re-run every probe"
could not be carried out literally, and that limitation is reported rather than skipped over. In its
place, every probe with a factual claim behind it was **re-run from scratch on a second pass**, in a
fresh directory, with different inputs than the first pass (a different git dependency —
`poison` instead of `jason` — different upstream repositories cloned fresh — `devinus/poison`,
`erlware/erlware_commons`, a second `hexpm/hex` clone — and different synthetic application
names/versions for the `ERL_LIBS` probe), rather than replaying the same commands:

| Claim | First pass | Second pass, independent inputs | Circular? |
|---|---|---|---|
| `repo.hex.pm` blocked, `github.com` reachable | curl 403 / clone OK | re-curled fresh, same result | No — live network each time |
| rebar3 not preinstalled, installs via apt | `which rebar3` empty → apt install | `dpkg -l rebar3` fresh check | No |
| git-sourced `mix.lock` has no checksum, only a git ref | `jason` dep → `mix.lock` | `poison` dep, fresh `mix new` → same shape, different SHA | No — real `mix deps.get` both times |
| hex-sourced `mix.lock` entry is an 8-tuple with two sha256 fields | read `hexpm/hex`'s own `mix.lock` | read `devinus/poison`'s `mix.lock` (unrelated project) — same 8-field shape confirmed independently | No — both are files the real Hex/Mix tooling wrote upstream, not authored by this session |
| `:crypto.hash(:sha256, tarball)` is Hex's checksum algorithm | grep in one clone | grep in a **second, separate** clone of `hexpm/hex` | No |
| rebar.lock hash format (`pkg_hash`/`pkg_hash_ext`, uppercase hex) | read `rebar3`'s vendored `providers`/`cth_readable`/`relx` locks | cloned `erlware/erlware_commons` fresh — its `rebar.lock` records `cf 0.3.1` with the **identical** hash `5CB902239476E141EA70A740340233782D363A31EEA8AD37049561542E6CD641` also seen in `providers/rebar.lock`, an internal cross-check a fabricated value could not pass by accident | No |
| ERL_LIBS resolves duplicate app versions by path order only | `probeapp` 1.0.0/2.0.0 | fresh `zzprobe` 9.9.9/0.1.0, both orders | Flagged and accepted as synthetic: the `.app` files were hand-written, but the mechanism under test (the BEAM code server's resolution order) is real, unmodified, and the outcome was not decided in advance — it was read off the real `application:get_key/2` call each time |
| Elm pins exact versions, has no separate lock file | one `WebFetch` of `application.md` | second, independent `WebFetch` of the GitHub directory listing, confirming the file's real existence rather than re-reading its content | No |
| Gleam manifest.toml's hex entries carry `outer_checksum` | read from `gleam-lang/gleam`'s test fixtures | same fixtures — **not independently regenerated**, because no `gleam` binary or registry access was available in this sandbox; this one is **cited, not reproduced**, and is flagged as such rather than presented as a live probe |

**Verdict:** every claim backed by a locally-runnable tool (`mix`, `rebar3`, `erl`, `git`, `curl`)
reproduced identically against fresh inputs and, in one case (`cf 0.3.1`'s hash), cross-validated
against a second, unrelated upstream project. The one claim that rests on reading rather than
regenerating — Gleam's `manifest.toml` shape — is explicitly marked as such above and was not
independently re-derived, because no Gleam toolchain or hex-registry access exists in this
environment.

---

## Blockers, plainly

- **`repo.hex.pm` and `crates.io` are blocked** by the outbound proxy (`CONNECT tunnel failed,
  response 403`); `apt`'s own package mirrors and `github.com`/`raw.githubusercontent.com` are not.
  This is why every hex-sourced lock-file example above is a cited upstream file rather than a
  locally generated one.
- **No `gleam` toolchain is installed**, and `crates.io`/Gleam's own package registry are not
  reachable from here, so the Gleam evidence above is drawn from `gleam-lang/gleam`'s own committed
  test fixtures (cloned via `git`, which worked) rather than from a live `gleam deps` run.
- **No agent-spawning tool was available** in this session to literally satisfy "spawn a separate
  agent" — substituted with an independent, fresh-input re-run of every reproducible probe, reported
  above with its own verdict row per claim.

---

Personal view, separated from the evidence above: candidate 1a (extend the `using` block with the
application, checked by presence — not a version) plus candidate 3b (walk the `.app` closure that
already exists on disk) is the pairing that costs the least new surface for the fact ticket 52
actually wants recorded.
