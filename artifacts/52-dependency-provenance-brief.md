# Decision brief — ticket 52: dependency provenance

Research only. Ticket 52 (Linear ENG-234) is left **open**; nothing in `wayfinder/issues/` was
edited. This brief is the deliverable.

## 0. Grounding — what 51, 32 and 50 actually decided (grepped, not assumed)

`grep -n "## Decisions entry" -A40 wayfinder/issues/{51,32,50}-*.md` was read in full before writing
anything below.

- **Ticket 51 (resolved)**: beam-sharp builds no dependency/build tool, full stop. `ERL_LIBS` reaches
  a real Req 0.7.3 nine-package tree with **zero** compiler change (measured 2026-08-21,
  `wayfinder/prototypes/51a-code-path/Req/req.bs`). Its own decisions entry states the residue
  explicitly: *"nothing in a `.bs` file records what it needs... the captured candidate is that the
  FFI declaration is already the place a foreign thing is named (→ ticket 52)."* **This brief does
  not reopen 51** — no resolution, no locking, no fetching is proposed anywhere below.
- **Ticket 32 (resolved)**: a foreign function is declared, and the declaration binds a *module*
  name to an atom (`[external: erlang, "ets"] module Ets { list<term> Lookup(atom, term); }`), one
  arity per declaration, no case-mapping. **Important, and load-bearing for this brief**: this is the
  *decided design*, but it is not what `bs_parser.yrl` implements today — see §2.
- **Ticket 50 (resolved)**: a foreign aggregate gets no name of its own; it is a `map<atom, term>`.
  Orthogonal to provenance — not touched here.

## 1. Sub-decisions ticket 52 implies

1. **(a) Record at all, and if so, name only or name+version?**
2. **(b) Per `using`-block or once per module?**
3. **(c) What does `bsc` do with it — nothing, or a compile-time presence check?**

Per CLAUDE.md's rule against matrices where one question gates another: **(a) gates (b) and (c)**.
If the answer to (a) is "nothing is recorded," (b) and (c) do not arise. So (a) is asked first and
alone below, then (b)/(c) follow for the branch where (a) is "yes."

## 2. The measured correction to ticket 51's own framing — read this before the options

Ticket 51's decisions entry calls extending `using` *"a captured candidate"* that *"costs no new
file and no new concept."* **That claim was re-checked against the actual grammar and it is false
for the syntax, though true for the check.**

```
$ grep -n "decl ->" compiler/src/bs_parser.yrl
73:decl -> module_decl : '$1'.
74:decl -> type_decl   : '$1'.
75:decl -> signature   : '$1'.
76:decl -> clause      : '$1'.
77:decl -> foreign_decl : '$1'.
78:decl -> behaviour_decl : '$1'.
79:decl -> record_decl : '$1'.
80:decl -> using_decl  : '$1'.
```

`compiler/src/bs_parser.yrl:124-125`:
```
foreign_decl -> 'using' atom_lit '{' foreign_sigs '}' :
    {foreign, line('$1'), value('$2'), '$4'}.
```
`compiler/src/bs_parser.yrl:146`:
```
module_decl -> 'module' modpath : {module, line('$1'), modatom('$2')}.
```

**Neither production has a slot for anything beyond what's shown.** There is no `[…]`
attribute-list production anywhere in the grammar to hang `app: req` off of. This is not a new
observation — **ticket 22 (resolved 2026-08-23) already measured exactly this**, independently, for
a different pair of candidates:

> *"There is no attribute grammar, and there never has been… zero lines beginning with `[` in all
> 99 `.bs` files in the repo… Twice the language has needed exactly what an attribute is for, and
> twice it has taken a keyword — `[Erlang("ets","lookup")]` became `using :ets {…}`, `[module:
> GenServer]` became `behaviour GenServer`… It is a lexer rule, a `decl` arm, an AST node and a
> checker pass before the first domain attribute exists."*
> — `wayfinder/issues/22-how-opinionated.md`, "Four premises have gone stale," point 1

**Re-verified independently today, on the current 159-file corpus** (up from 22's 99):
```
$ find . -iname "*.bs" | wc -l
159
$ find . -iname "*.bs" -exec grep -Hn "^\[" {} \;
(no output — the two files a looser grep matched contain no attribute lines; confirmed by hand)
```
Zero. Ticket 22's finding still holds, twice-repeated even before this ticket, which is CLAUDE.md's
own bar for "a new check earns a sentence" — here it's a design pattern that's failed **twice** and
a candidate that would be its third attempt using the exact shape ticket 22 already rejected
(`[external: elixir, app: req]` is bracket-attribute syntax, indistinguishable in kind from
`[module: GenServer]`).

**What ticket 51 got right**: the *check* really is near-free, because `bsc` can reuse a mechanism
that already exists, and this was verified live:
```
$ erl -noshell -eval 'io:format("~p~n", [code:lib_dir(kernel)])' \
      -eval 'io:format("~p~n", [code:lib_dir(totally_not_a_real_app_xyz)])' -s init stop
"/usr/lib/erlang/lib/kernel-8.5.4.2"
{error,bad_name}
```
`code:lib_dir/1` is the exact code-server primitive that already makes `ERL_LIBS` work (ticket 51's
own finding), and it is a real, already-shipped, O(1) presence check. **So "the check is one line"
is correct; "the syntax to name what's checked costs nothing" is not** — that is the correction this
brief owes the record.

## 3. Probes run (real commands, real output)

### 3.1 What a real generated `.app` file's `applications` key records — name only, verified twice

Network to hex.pm is blocked in this environment (verified, not assumed):
```
$ mix local.hex --force
** (Mix) httpc request failed with: {:could_not_establish_ssl_tunnel, {'HTTP/1.1', 403, 'Forbidden'}}
```
So the probe uses a real local **path** dependency instead of a hex fetch — this exercises the exact
same `compile.app` code path (path/git/hex all flow through the same `deps_opts/1` →
`apps_from_runtime_prod_deps/2` → `handle_extra_applications/2` pipeline; see §4.1) and is not a
weaker substitute for what's being measured here, only for network fetch, which is irrelevant to
what a `.app` file records.

**Run 1** — `mini_lib` v0.9.5, consumed by `depprobe` via `{:mini_lib, path: "../mini_lib"}`:
```
$ mix compile
==> mini_lib
Generated mini_lib app
==> depprobe
Generated depprobe app

$ cat _build/dev/lib/depprobe/ebin/depprobe.app
{application,depprobe,
             [{applications,[kernel,stdlib,elixir,logger,mini_lib]},
              {description,"depprobe"},
              {modules,['Elixir.DepProbe']},
              {registered,[]},
              {vsn,"0.1.0"}]}.

$ cat _build/dev/lib/mini_lib/ebin/mini_lib.app
{application,mini_lib,
             [{applications,[kernel,stdlib,elixir,logger]},
              {description,"mini_lib"},
              {modules,['Elixir.MiniLib']},
              {registered,[]},
              {vsn,"0.9.5"}]}.
```
`depprobe.app`'s `applications` list carries the atom `mini_lib` and **nothing else** — no `"0.9.5"`
anywhere in the file, confirmed with `file:consult/1` from a real `erl` shell:
```
{ok,[{application,depprobe,
                  [{applications,[kernel,stdlib,elixir,logger,mini_lib]}, ...
```
No `mix.lock` is produced for a path dependency (checked: `ls mix.lock` → No such file or
directory) — locking is Mix's concern, not the compiled artifact's.

**Run 2, independent re-verification, different project, adversarial input** — a fresh scratch
directory, `app_a` v`"7.1.3-verify"` (a deliberately odd version string), consumed by `app_b` via
`{:app_a, "~> 3.0", path: "../app_a"}` — a version **requirement string attached to a path dep**,
which the first run didn't exercise:
```
$ mix compile
Unchecked dependencies for environment dev:
* app_a (../app_a)
  the dependency does not match the requirement "~> 3.0", got "7.1.3-verify"
** (Mix) Can't continue due to errors on dependencies
```
**New finding, not in ticket 51**: Mix *does* enforce a version requirement, even against a path
dependency, but strictly at its own resolution stage (`lib/mix/lib/mix/dep.ex:307-314`'s
`{:nomatchvsn, Vsn}` status) — **before** `compile.app` ever runs. Loosen the requirement to match
(`"~> 7.0"`) and compilation proceeds; the generated `.app` is again name-only:
```
$ cat _build/dev/lib/app_b/ebin/app_b.app
{application,app_b,
             [{applications,[kernel,stdlib,elixir,logger,app_a]}, ...
$ grep -c '3.0\|7.0\|~>' _build/dev/lib/app_b/ebin/app_b.app
0
```
So the version constraint is real, checked, and enforced by Mix — and it lives entirely in Mix's
in-memory resolver and is **discarded** before touching the artifact a beam-sharp program would read
off the code path. This is exactly the boundary ticket 51 already refused (resolution/locking is the
scope-refused track); it corroborates that a version constraint, if beam-sharp records one, has
nowhere to be *checked against* without beam-sharp growing exactly the resolver machinery 51 ruled
out.

### 3.2 Where the app name flows from `mix.exs` to the `.app` — cited, not recalled

`/tmp/elixir-src/lib/mix/lib/mix/tasks/compile.app.ex:354-361` (`apps_from_runtime_prod_deps/2`):
```erlang
defp apps_from_runtime_prod_deps(properties, config) do
  included_applications = Keyword.get(properties, :included_applications, [])
  for {app, opts} <- deps_opts(config),
      runtime_app?(opts),
      app not in included_applications,
      do: {app, if(Keyword.get(opts, :optional, false), do: :optional, else: :required)}
end
```
`:382-389` (`deps_opts/1`, `dep_opts/1`): extracts `elem(config_dep, 0)` — **the app name atom, and
nothing else** — from each `{app, req, opts}` or `{app, opts}` tuple in `mix.exs`'s `deps/0`. The
requirement string (`"~> 1.4"`, the git ref, the path) is in `opts`/discarded here; only the atom and
a required/optional flag survive into `:351`'s `Keyword.put(properties, :applications, required)`,
which is the literal list written into the `.app` file. This is the exact mechanism the two runs
above exercised.

### 3.3 OTP's own `.app.src` — two keys, one checked, one advisory, both real

`/tmp/otp-src/lib/ssl/src/ssl.app.src:84-88`:
```erlang
{registered, [ssl_sup, ssl_manager]},
{applications, [crypto, public_key, kernel, stdlib]},
{env, []},
{mod, {ssl_app, []}},
{runtime_dependencies, ["stdlib-4.1","public_key-1.11.3","kernel-8.4",
                        "erts-10.0","crypto-5.0", "inets-5.10.7",
                        "runtime_tools-1.15.1"]}]}.
```
Two different keys, for two different jobs, per OTP's own kernel docs
(`/tmp/otp-src/lib/kernel/doc/src/app.xml`):

- **`applications`** (lines 149-159): *"All applications that must be started before this
  application… `systools` uses this list to generate correct start scripts."* **Name only. Checked**
  by `systools` at release-build time, for start order.
- **`runtime_dependencies`** (lines 216-244): *"A list of application **versions** that the
  application depends on… specified as runtime dependencies are minimum requirements… The
  `runtime_dependencies` key was introduced in OTP 17.0… Declared runtime dependencies in OTP
  applications are expected to be correct in OTP 18."* **Name+version. Advisory** — no start-order
  role, and OTP's own docs admit its *own* declared entries were not reliably correct for a full
  release cycle.

This is the single cleanest BEAM-native precedent for sub-decision (a): **the platform itself keeps
presence-and-order (name only, checked) and version provenance (name+version, advisory) in two
separate keys, because they do two different jobs.** `crypto.app.src:26` has the same shape
(`{applications, [kernel, stdlib]}`, no `runtime_dependencies` at all — advisory version info is
opt-in per-application, not universal).

### 3.4 Gleam — `gleam.toml` ranges/refs vs `manifest.toml` exact resolved locks, from real fixtures

`compiler-core/src/config.rs:164-195` (`PackageConfig`, i.e. `gleam.toml`):
```rust
pub struct PackageConfig {
    pub name: EcoString,
    pub version: Version,               // the PACKAGE's own version, not a dependency's
    ...
    pub dependencies: HashMap<EcoString, Requirement>,
    pub dev_dependencies: HashMap<EcoString, Requirement>,
```
`compiler-core/src/requirement.rs:17-33` (`Requirement`) — confirms the Hex-vs-Git-vs-Path
distinction the task asked to verify:
```rust
pub enum Requirement {
    Hex { version: Range },
    Path { path: Utf8PathBuf },
    Git { git: EcoString, ref_: EcoString, path: Option<Utf8PathBuf> },
}
```
`compiler-core/src/manifest.rs:182-193` (`ManifestPackage`, i.e. `manifest.toml`):
```rust
pub struct ManifestPackage {
    pub name: EcoString,
    pub version: Version,               // EXACT resolved version, not a range
    pub build_tools: Vec<EcoString>,
    pub otp_app: Option<EcoString>,      // package name vs BEAM application name can differ
    pub requirements: Vec<EcoString>,    // transitive edges — NAMES ONLY, same shape as OTP's `applications`
    pub source: ManifestPackageSource,
}
```

**Real fixture, `test/project_git_deps/`** (git dependency — the strongest form of "range vs.
exact" because a git ref is inherently non-exact):
```toml
# gleam.toml
[dependencies]
gleam_stdlib = { git = "https://github.com/gleam-lang/stdlib.git", ref = "957b83b" }
```
```toml
# manifest.toml (generated by Gleam)
packages = [
  { name = "gleam_stdlib", version = "0.54.0", ..., source = "git",
    repo = "https://github.com/gleam-lang/stdlib.git",
    commit = "957b83bbb6103aa0d96c148ce7409243681cf1ab" },
]
```
Verified programmatically, not by eye: `957b83bbb6103aa0d96c148ce7409243681cf1ab`
(`manifest.toml`'s `commit`) starts with `957b83b` (`gleam.toml`'s `ref`) — `True`.

**Real fixture, `test/project_erlang/`** (a hex dependency tree, 14 packages, including a
package-name-vs-application-name mismatch already present in the tree): `gleam.toml` has
`hpack_erl = "~> 0.1"` (a **range**); `manifest.toml` locks
`{ name = "hpack_erl", version = "0.3.0", ..., otp_app = "hpack", ... }` — **exact version**, plus
the fact that the *Hex package* is `hpack_erl` but the *BEAM application* it produces is `hpack`
(`manifest.rs:204-209`, `application_name/1`, falls back to `name` when `otp_app` is absent). And
`manifest.toml`'s per-package `requirements` are name-only transitive edges, exactly like OTP's
`applications` key: `cowboy`'s is `["cowlib", "ranch"]`, no versions.

**Gap logged, not faked**: the gleam binary at `/tmp/gleam-src/target/release/gleam` (1.19.0-rc1) is
built and runs, but `gleam deps` against a hex dependency needs the same blocked network hex.pm
access as Mix, so it was not exercised end-to-end here — the fixtures above are Gleam's own
committed test corpus, read and cross-checked, not generated fresh by a live `gleam` run.

## 4. Independent re-verification (no Agent/Task-spawn tool available)

The task asked for a separate verifier subagent (Agent tool, `general-purpose`). **No such
tool is exposed in this environment** — `ToolSearch` for spawn/task/agent primitives surfaced only
`SendMessage` (messaging an *already-running* agent) and `TaskStop`; there is no tool that starts a
new isolated subagent from here. Substituted with an independent re-run, in a fresh scratch
directory, using inputs the first run did not use, specifically to catch "constructed backwards from
the desired conclusion":

- Different app names (`app_a`/`app_b`, not `mini_lib`/`depprobe`).
- A deliberately odd real version (`"7.1.3-verify"`) rather than a plausible-looking `"0.9.5"`.
- A version **requirement string on a path dependency** (`{:app_a, "~> 3.0", path: …}`), which the
  first run never declared — this is what surfaced the `nomatchvsn` enforcement finding in §3.1,
  Run 2, which was *not* anticipated going in and is not a plausible outcome to have engineered
  backwards.
- The gleam `ref`-is-a-prefix-of-`commit` claim was checked with a Python regex match against the
  raw files, not eyeballed.
- `code:lib_dir/1`'s success/failure pair was run against a real installed OTP app (`kernel`) and a
  deliberately nonexistent atom (`totally_not_a_real_app_xyz`), both outcomes shown.

**One incident worth recording against this brief's own honesty, since it happened during this
research**: an early probe (`rebar3 version`, then a `gleam --version` call) left the real repo
dirty — `aoc/bench/gleam/gleam.toml` had a dependency line stripped, `aoc/bench/gleam/build/` and
`manifest.toml` were created, and `compiler/rebar3.crashdump` appeared (rebar3 had attempted a real
compile of `compiler/`'s `bs_lexer.xrl` and crashed on it: `{badarg, [{leex,file,...}]}`) — despite
each of those commands being issued with an explicit `cd` into the scratch directory first. Caught
by `git status --porcelain` immediately after, and fully reverted (`git checkout --
aoc/bench/gleam/gleam.toml`; a stray `rm` of the *tracked* `compiler/rebar.lock` during cleanup was
itself caught by the next `git status` and restored the same way). Confirmed clean at
`e67f269` before writing this file, and again just now. Recorded here because CLAUDE.md's own bar
for a check is "seen to fail once," and a research session silently touching the tree it was told
to leave alone is exactly that kind of failure — the concrete lesson for any future automated probe
in this repo is to verify cwd and re-check `git status` after every external-tool invocation, not
just at the end.

## 5. Options — concrete B# code, and what `bsc` must gain

All three are grounded in the grammar **as it exists today** (`using :'Elixir.Req' { … }`,
`module Req`), not in ticket 32's decided-but-unimplemented `module Ets { … }` binding form, since
that form is a separate, unbuilt piece of surface and conflating the two would smuggle a second
decision into this one.

### Option A — record nothing (the status quo, stated as a real option rather than skipped)

```csharp
module Req

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```
**`bsc` gains**: nothing. This is what compiles today.

**Evidence for**: it is what ticket 51 measured as sufficient to *run* the program (`51a`, Req 0.7.3,
zero compiler change) — the capability the language "owes its author" per the scope boundary's own
test is call-time correctness, and that is already served. Every one of §3's probes shows that even
the neighbours' own compiled artifacts (`.app`, `manifest.toml`) don't gate anything at *load* time
on what they record — `applications`/`requirements` control start *order*, and nothing on the BEAM
refuses to load an application because a consumer's declared list omitted it.

**Strongest counterargument**: this is the exact gap ticket 51 raised 52 to close — *"a program
whose dependencies exist only in the environment that happened to build it cannot be handed over"* —
and the clean-room handoff is this project's stated destination (CLAUDE.md, part 3). A stranger
reading `req.bs` alone cannot discover it needs `req`, `mix`, and Elixir itself without also reading
ticket 51's prose.

### Option B — name only, once per module, checked at compile time

```csharp
module Req
requires elixir "req"

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
using :'Elixir.Application' {
    term ensure_all_started(atom app)
}
```
**`bsc` gains** (concrete, cited to the exact functions each change sits beside):
- **Lexer**: no new token — `requires` joins the existing keyword set at `bs_parser.yrl:24` the same
  way `behaviour` did.
- **Parser**: one new `decl` arm, sibling to `module_decl` at `bs_parser.yrl:146`:
  `requires_decl -> 'requires' lident string_lit : {requires, line('$1'), value('$2'), value('$3')}.`
  — an AST node with two atoms (platform tag, app name), matching the shape `foreign_decl` already
  has at `:124-125`.
- **Check**: one new pass, sibling to `foreign_rets_decidable/2` (`bs_check.erl:573-585`) and
  `foreign_wrappers/2` (`:993-997`), which today already walk `{foreign, _, Mod, Sigs} <- Decls`:
  `requires_present(Decls, Env)` walks the (at most one, per module) `{requires, L, _Tag, App}` and
  calls `code:lib_dir(list_to_atom(App))`, erroring at `L` on `{error, bad_name}`. This is the "one
  line" ticket 51 predicted — verified real and available in §2 — now correctly scoped to the check
  alone, not the syntax.
- **Nothing else.** `foreign_decl`'s own AST tuple is untouched — no cross-cutting change to every
  `using` block.

**Evidence for**: matches OTP's own `applications` key precedent exactly (§3.3) — name only,
checked, no version. Matches the "per module" placement of `module_decl` itself, and avoids the
"two declarations of one fact might disagree" failure mode ticket 22 §3 and ticket 32 §6 both flag
elsewhere in this same file (a record's tag is minted from **one** qualified name for the identical
reason). One `requires` line reads as true regardless of how many `using` blocks later draw on the
same application (`req.bs` has three).

**Strongest counterargument**: it invents a second way to say "this module depends on Elixir/OTP
app X" alongside the module-binding shape ticket 32 already decided
(`[external: erlang, "ets"] module Ets {…}`) but never implemented — a reader now has two questions
("what's the syntax for a foreign module binding" and "what's the syntax for its provenance") where
32's own eventual implementation might naturally answer both at once by attaching the app to the
same construct that already names the platform (`elixir`/`erlang`).

### Option C — name+version, per-`using`-block, via the bracket-attribute ticket 51 proposed

```csharp
module Req

[external: elixir, app: req]
using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}
```
**`bsc` gains**: everything Option B needs, **plus** the entire attribute-list grammar ticket 22
measured has never existed and was rejected twice already (§2) — a lexer rule for `[`-led attribute
lists in declaration position (today `[` only opens list literals and patterns, per
`bs_parser.yrl`'s token productions at lines ~498-499, ~728-729), a new `decl`-adjacent production
for `attr_list -> '[' attrs ']'`, and a place to attach it to `foreign_decl` specifically (repeated
per block, so `req.bs`'s three `using` blocks each carry their own `[external: elixir, app: req]`,
identical three times). If a version is added (`app: req, version: "0.7.3"`), `bsc` also needs
somewhere to check that version against — and §3.1 Run 2 shows the only real precedent for checking
a version (Mix's resolver) does so by **fetching and inspecting the actual dependency**, which is
exactly the resolution machinery ticket 51 refused.

**Evidence for**: it is the shape ticket 51 itself proposed, and per-block placement means a `using`
block is fully self-contained — deleting it removes its own provenance with it, with no
module-level line to also update.

**Strongest counterargument, measured rather than asserted**: this is architecturally the *same
shape* as `[Erlang("ets","lookup")]` and `[module: GenServer]`, both of which reached exactly this
grammar and were built as keywords instead (ticket 22, §2 above) — so adopting it here is a third
attempt at a pattern that failed twice for reasons (a lexer rule, a `decl` arm, an AST node, a
checker pass, *before* the first attribute exists) that apply verbatim to this candidate. A
name+version pairing also has nothing on the BEAM to be checked against without also building a
resolver (§3.1 Run 2) — the version half would be recorded and then never verified, which is worse
than not recording it, per CLAUDE.md's own standard that a declaration should not be a promise
nobody checks (the exact objection ticket 32 §8 raised against C#'s unchecked `extern` and Gleam's
unchecked `@external`).

## 6. Recommendation

**Option B** — name only, once per module, via a dedicated `requires` keyword, checked at compile
time with `code:lib_dir/1`. It is the only option of the three that://
- matches a real, checked, BEAM-native precedent (OTP's `applications` key, §3.3) rather than the
  advisory, historically-unreliable-by-OTP's-own-admission `runtime_dependencies` shape;
- does not re-attempt the bracket-attribute pattern ticket 22 already measured has failed twice and
  costs "a lexer rule, a `decl` arm, an AST node and a checker pass" for, verbatim, a third time;
- keeps the version question — which needs a resolver to mean anything checked (§3.1 Run 2) — out of
  the language, consistent with ticket 51's boundary holding without bending; and
- gives the compiler a genuinely one-line check, which is the part of ticket 51's optimism that
  actually survives contact with the grammar.

It is **not free** — it is a new keyword, a new `decl` arm, and a new check pass, contra ticket 51's
"costs no new file and no new concept" framing — but it is the cheapest of the three real options,
and it is the one whose cost the ticket's own prose underestimated for a reason worth recording
rather than repeating.

## 7. Verification

- Real Mix compiles, twice, in separate scratch directories under
  `/tmp/claude-0/.../scratchpad/depprobe` and `/tmp/claude-0/.../scratchpad/verify` (outside the
  repo, per instructions) — `.app` files shown in full above, not excerpted.
- Real `erl` invocations (`code:lib_dir/1`, `file:consult/1`) — output shown in full above.
- Real Gleam test fixtures read from `/tmp/gleam-src/test/project_git_deps/` and
  `/tmp/gleam-src/test/project_erlang/`, cross-checked programmatically (ref-is-prefix-of-commit).
- Real Elixir/Gleam source cited by file and line: `compile.app.ex:354-361,382-389`,
  `dep.ex:53-68,307-314`, `config.rs:164-195`, `requirement.rs:17-33`, `manifest.rs:182-209`.
- Real OTP source cited by file and line: `ssl.app.src:84-88`, `crypto.app.src:26`,
  `app.xml:149-244`.
- Real `bsc` grammar cited by file and line: `bs_parser.yrl:73-80,124-125,146`; real check-pass
  anchor points at `bs_check.erl:573-585,993-997`.
- Independent re-verification performed by the same session in a fresh scratch directory with
  different inputs, per §4, in the absence of a separate Agent/Task-spawn tool in this environment
  (flagged explicitly, not silently substituted).
- Repo left clean: `git status --porcelain` returns nothing at `e67f269`, both before this file was
  written and confirmed again after an accidental dirty state (§4) was caught and reverted. No file
  under `wayfinder/issues/` was touched.
