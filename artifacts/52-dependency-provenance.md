# Ticket 52 — Dependency provenance: what does a `.bs` file say about what it needs?

Ticket 52 · [ENG-234](https://linear.app/davewil/issue/ENG-234) · 2026-09-29
**Status: decision open — for human review.** Nothing here resolves the ticket, edits a compiler
source under `compiler/`, or touches Linear. Probes live in `artifacts/probes/52/`; `./run.sh` there
re-runs all of them and prints PASS/FAIL against the expectation written in each file before its first run.

Vocabulary note: *provenance* in `wayfinder/issues/20-untheorised-term-shapes.md` §7 means value
taint (refused). This ticket means **dependency provenance**: which application a foreign module comes from.

## 1. Sub-decisions the ticket implies (gating first)

| # | Question | Gates |
|---|---|---|
| **(a)** | **Does the source record dependencies at all?** The only argument is the clean-room handoff (ticket 52 body), not ergonomics | b, c |
| (d) | What does the compiler do with a foreign module that is not on the code path? | **not gated by (a)**, see the finding below |
| (b) | Name only, or name plus version | only if (a) = yes |
| (c) | Per `using` block, or once per module | only if (a) = yes |

**Finding that reorders the ticket.** The ticket treats (d) as the payoff of (a). Probe P1 shows (d) needs
**no declaration**: the block `using :'Elixir.Req' { … }` already names the module, and `code:which/1` on that
name answers "is it here". So the diagnostic can ship with zero syntax; what only (a) buys is that the
*application* is named, for a reader or a stranger who does not have the machine.

Three facts about the ticket's sketch, none re-opening 51:

- `[external: elixir, app: req] using :'Elixir.Req' {…}` **does not parse and has no grammar to extend.**
  `bs_parser.yrl:170` is `foreign_decl -> 'using' atom_lit '{' foreign_sigs '}'`; there is no attribute rule
  anywhere in the grammar (`'['` is only list syntax, lines 544–783). Ticket 32's `[external: erlang, "ets"] module Ets`
  shape did not ship; LANGUAGE.md §11 ships `using :ets { … }`.
- A third extension to this construct is already decided: ticket 106 (resolved 2026-09-25) adds an entry-level
  alias `term GetOrCrash(binary url) = :'get!'`. It is unbuilt at HEAD (`foreign_sig`, line 178, has no `=`).
  Ticket 50 resolved with no surface. A block-header attribute (this ticket) and an entry alias (106) do not
  overlap, but both change the `{foreign, …}` tuple, so build them together.
- LANGUAGE.md:157 already says *"a file's `using` lines are its dependency list"* and `bs_check.erl:4346`
  comments the same for B# imports. The language already claims `using` is the dependency list; for foreign
  blocks the claim is untested by the compiler.

## 2. Probes

`P` ids match `artifacts/probes/52/run.sh`. **Result** is what was observed; a probe whose expectation was
wrong stays FAIL and is explained, not patched.

| id | claim tested | expected (written before run) | observed | dir |
|---|---|---|---|---|
| P1a–d | Ticket's claim: FFI to an absent module compiles and dies at the call. `:'Elixir.Enum'` (present via `ERL_LIBS=/usr/lib/elixir/lib`) vs fabricated `:'Elixir.Nope'` | both compile, exit 0; Absent `crashed: error:undef`; Present prints 3 only with ERL_LIBS | **PASS.** Absent compiles (exit 0), then `crashed: error:undef`. Present: undef without ERL_LIBS, `3` with | `p1/` |
| P1e–i | The check prototyped in a patched **copy** of bsc (`p1/v1.patch`, 16 added lines) | Absent refused at compile time; Present refused without ERL_LIBS, runs with it; `--api` also refuses; 21 in-repo example dirs unaffected | **PASS.** Message: ``error: `using :'Elixir.Nope'` names a module that is not on the code path`` exit 1. `--api Absent` is refused too. 21/21 example dirs still compile | `p1/` |
| P2-E1..E5 | Erlang's cheap answers: `lib_dir/1`, `which/1`, `application:load/1`, module-only beam | `lib_dir(elixir)` bad_name unset / path with ERL_LIBS; `which` non_existing / beam path; module-only beam seen by `which`, not by `lib_dir`; `load` ok / "no such file … elixir.app" | **PASS** (all five) | `p2/` |
| P2-E6 | Timing | `lib_dir` single-digit µs; `which` on unloaded ≥ 50× slower | **PASS**, numbers in §4 | `p2/` |
| P2b | `lib_dir/1` on a path added with `code:add_patha` | `lib_dir(bare)` for a beam in a dir not shaped `<app>/ebin` stays `{error,bad_name}` | **FAIL, expectation wrong.** It returned `"./bare"`: `lib_dir/1` matches any path entry by **directory name**. (`lib_dir(myapp)` after add_patha of `myapp/ebin` works: P2b-2 PASS.) So `lib_dir` is a naming convention, not an app registry | `p2/` |
| P2c | App derivable from a module with nothing declared | `get_application` undefined until loaded; beam path gives app dir | **PASS.** `.../elixir/ebin/Elixir.Enum.beam` → `elixir`; `.../stdlib-4.3.1.3/ebin/lists.beam` → `stdlib-4.3.1.3` (name and version, by directory convention) | `p2/` |
| P3a,c | mix: does a missing app / undefined module fail `mix compile`? | `extra_applications: [:nope_app]` compiles silently; `Nope.Module.call/1` compiles with a warning | **PASS.** `nope_app` is written into the `.app` list and fails only at start (`could not find application file: nope_app.app`); the undefined call is a *warning* ("module Nope.Module is not available"), exit 0 | `p3/` |
| P3b | mix with a hex dep, no hex | "Unchecked dependencies" error; `--no-deps-check` compiles | **FAIL, probe could not reach the check.** Without Hex, mix stops earlier: `Could not find an SCM for dependency :req`, both with and without the flag. Redone as P3d | `p3/` |
| P3d1–3 | The same deps check, offline, with **path** deps | missing dep dir: refused, exit 1; `--no-deps-check` compiles; present-uncompiled dep: mix builds it | **PASS.** `Unchecked dependencies … the dependency is not available`, exit 1; with `--no-deps-check` `Generated d app`, exit 0; the uncompiled dep is built | `p3/` |
| P4a–d | Erlang precedent | `erlc` accepts a call to a missing module and an unknown `-required_app(...)` attribute silently; xref reports the call; `ensure_all_started`/`systools` catch a missing app | **PASS.** erlc exit 0, no warning; attribute is stored (`[nope_app]`) and nothing reads it; xref: `[{{caller,f,0},{'Elixir.Nope',count,1}}]`; `application:load` ok, `ensure_all_started` → `{error,{nope_app,{"no such file or directory","nope_app.app"}}}`; `systools:make_script` → `{undefined_applications,[nope_app]}`. Setup trap: xref on a beam **without** `+debug_info` silently reports `[]` (P4c0) | `p4/` |
| P5a–c | Gleam 1.12.0 offline | `@external` to a missing module builds; a `gleam.toml` dep fails at resolution; `import` of an undeclared package fails | **PASS.** `@external(erlang,"Elixir.Nope","count")` builds (exit 0); dependency resolution fails on `repo.hex.pm`; `import nope_pkg/thing` → `error: Unknown module` | `p5/` |
| P6a,b | Elm 0.19.2 offline | expected to fail fetching elm/core before saying anything about `import Http` | **P6a FAIL, expectation wrong:** Elm fails *earlier* on a local outline check (`MISSING DEPENDENCY … elm/json`), no network. **P6b PASS:** with elm/json added it reaches the registry, proxy answers 403, exit 1, never reaches `import Http` | `p6/` |
| P7b | Cost of the test itself | µs on loaded modules, ~0.3–0.6 ms on an unloaded one | **PASS**, §4 | `p7/` |
| P7c | Corpus modules outside OTP 25 | `json`, `epgsql` non_existing; `lists`, `erlang` found | **PASS** | `p7/` |

Suite result: the three FAILs are P2b, P3b and P6a, each a pre-stated expectation that was wrong (kept, not
patched). P2-E6 failed once on a bad awk field in the harness, not in the claim, and was fixed and rerun.
Final counts are in `probes/52/out-run.txt`; per-probe raw output is in `probes/52/captured/`.

## 3. Neighbouring languages

No neighbour's **source** is installed (OTP has `ebin` only; Elixir `lib/mix` has `ebin` only; Gleam and Elm are
binaries), so nothing below cites a neighbour file:line. Behaviour is probed via the named command.

| | What the source declares | What the toolchain does when it is missing | Probe |
|---|---|---|---|
| **Erlang** | `.app.src` `applications` list names dependencies; a call names only a module | `erlc` checks nothing (P4a); the `.app` list is checked at **start** (`ensure_all_started`) and at **release** (`systools:make_script`), not at compile; `xref` finds the call after compile, and needs `debug_info` | P4 |
| **Elixir/mix** | `mix.exs` `deps` and `extra_applications` | `extra_applications` is not checked at compile (P3a); a missing **dep** is refused before any source compiles, and `--no-deps-check` waives it (P3d); a call to an absent module is only a warning (P3c) | P3 |
| **Gleam** | `gleam.toml` `[dependencies]`; `@external` names a module string | `@external` is never checked (P5a); an `import` of a module in no declared package is a **compile error** (P5c) | P5 |
| **Elm** | `elm.json` `dependencies`, checked for shape (elm/core, elm/json) before any network | An import of an uninstalled package: **not measured** (registry blocked, P6b) | P6 |

What the table says: every neighbour that checks anything at compile time checks **the manifest against
the source's imports**, and a manifest is a second file. None checks a foreign call against the machine's code
path at compile time; Elixir's is a warning, Erlang's is a separate tool. The ticket's candidate is different
from all four: the declaration would sit **in the source**, beside the name it qualifies. Neither Gleam nor
Erlang has a precedent for that (Erlang's `-required_app(...)` shape is accepted and ignored, P4b).

## 4. Measurements (OTP 25, this machine; units and N stated)

| what | value |
|---|---|
| `code:lib_dir(elixir)` hit or miss | min 2.14–2.56 µs, median ≈ 2.2–2.6 µs (N = 20 000 × 7) |
| `code:which/1` on a **loaded/preloaded** OTP module, fresh VM, first call | 3–31 µs (3 runs × 5 modules); 8 modules in 1.1–2.0 ms total when 3 are unloaded |
| `code:which/1` on an **unloaded** module, hit | min 561 µs, median 620 µs (N = 200 × 7, 37 dirs on path) |
| `code:which/1` on a **miss** | min 548 µs (31 dirs) and 957 µs (37 dirs): scales with path length; no cache |
| `code:where_is_file("elixir.app")` | min 513–520 µs (N = 200 × 7) |
| `application:load(nope)` miss | min 540–942 µs; `load(elixir)` when already loaded 3.5 µs |
| `lib_dir` vs `which` | ≈ 250× apart (2.2 µs vs 561 µs) |
| whole compile, `examples/Interop` (3 foreign blocks), HEAD vs patched | min 18.7 / 19.3 ms (HEAD) vs 19.9 / 18.8 ms (patched); medians 23.8 / 23.9 vs 28.0 / 33.4 ms, N = 41 × 2. **The difference is inside the noise**; max spread within one series is 26 ms |
| size of the check in bsc | **16 added lines**: `bs_check.erl` +8 (call after line 325; function before `foreign_rets_decidable`, line 631), `bs_diag.erl` +8 (`built/2` beside line 656, `message/1` beside line 2030). No parser or emitter change |
| corpus | 30 foreign `using :` blocks in 18 `.bs` files outside `artifacts/` (`grep -rn '^using :' --include=*.bs . | grep -v '^./artifacts/' | wc -l` = 30). 24 name an OTP module; 6 do not: `:json` (25f), `:epgsql` (25d), and four `Elixir.*` in the 51a prototypes |

Reading the timing: the reachability test costs ≤ 1 ms per not-yet-loaded module and microseconds per OTP
module, i.e. a few percent of a ~19 ms compile at worst. Cost is not the objection to any option.

## 5. Options

### Option A — nothing in the source; one sentence in the handoff spec

```csharp
module Fetch

using :'Elixir.Req' {
    term get(binary url)
}

public term Page(binary url)
Page(u) -> get(u)
```

**Behaviour**: exactly today's. Compiles anywhere (P1a); on a machine without Req the call ends in
`crashed: error:undef` (P1b), with no word of which package.
**Compiler delta**: none. **Handoff delta**: one sentence, *"a program naming a non-OTP module needs the
application that contains it on `ERL_LIBS` at build and run time"*, in `handoff/README.md`.
**Evidence**: P1a–d; P4a (Erlang's own compiler behaves the same); P5a (Gleam's `@external` too).
**Strongest counterargument**: the ticket's own. The source names `Elixir.Req`, not `req`, and a module name
does not determine its package: P2c derives the app from a *beam path on a machine that has it*, but a stranger
without the machine has only the atom. (The claim that no computable module→package map exists is
reasoning from how hex names work, **not measured**.) A fleet implementing against the spec can then build the
compiler and not know what to install to run the exemplar.

### Option B — nothing in the source; `bsc` refuses a foreign module that is not on the code path

Same program as A. Under B, on a machine whose `ERL_LIBS` lacks Req:

```
Fetch/fetch.bs:3:1: error: `using :'Elixir.Req'` names a module that is not on the code path
  this machine's code path holds no 'Elixir.Req'.beam. Put the dependency's ebin on
  ERL_LIBS (or build it) before compiling; otherwise the call fails at run time with error:undef.
```

(the real text printed by the patched copy for `Elixir.Nope`, P1e), exit 1; with `ERL_LIBS` set it compiles
and runs (P1g).

**Compiler delta (concrete, applied to a copy in P1e–i)**:
1. `bs_check.erl`: `foreign_modules_reachable(Decls)`, `code:which(Mod)` per `{foreign,_,Mod,_}`, raising
   `{foreign_module_unavailable, Line, Mod}`.
2. `bs_diag.erl`: one `built/2` clause and one `message/1` clause (`built` at :656 and `message` at :2030 are
   the models).
3. **Where it is called is a decision inside B.** Placed in `declared/4` (line 325, as patched) it also refuses
   `bsc --api` (P1h), because `exports_of` calls the same function in lenient mode (`bs_check.erl:353`) and
   `--api` is what tooling reads. Placing it only under `Mode =:= strict` keeps `--api` working on a machine
   without the dependency.
4. `LANGUAGE.md` §11 needs a `<!-- diagnoses: foreign_module_unavailable -->` example (`check-language.sh:32`
   is the gate that reads it).

**Evidence**: P1e–i; §4 cost. **Correction (verifier):** the earlier text here said no warning class exists; that is false. `{warning, ...}` terms are emitted at `bs_check.erl:3737/3739/3741/3767/3821` and printed as `warning:` at `bs_diag.erl:1017/1024/1033`. What is unchecked is only whether `declared/4` can emit a non-fatal one for a foreign declaration; none exists for that today.
**Strongest counterargument**: **the verdict on one source file now depends on the machine.** P1e vs P1g is
the same `present.bs` refused with `ERL_LIBS` unset and accepted with it set. That is an environment-dependent
compile result in a project whose stated judge is the reference compiler (CLAUDE.md, part 2): a fleet
member without Req is refused by the oracle for a reason the spec does not state. The corpus already contains
the case: exemplar 25f names `:json`, which OTP 25 lacks (`code:which(json) = non_existing`, probe P7c; and the patched compile of 25f prints
"`using :json` names a module that is not on the code path"). An OTP-version change flips the verdict with the source unchanged. Second: the message names a module,
never an application (`'Elixir.Req'.beam` says nothing to a reader about `req`). Third: a build machine that
compiles here and deploys elsewhere is refused for a module it never runs.

### Option C — the block header names the application (name only, optional), and the compiler checks it

Per-block, the ticket's candidate with `external:` dropped (below), spelled as the ticket wrote it:

```csharp
module Fetch

[app: req] using :'Elixir.Req' {
    term get(binary url)
}

[app: elixir] using :'Elixir.Enum' {
    int count(list<term> xs)
}

[app: elixir] using :'Elixir.String' {     // same application, written twice
    binary upcase(binary s)
}
```

Refused under C: an unknown key (`[vsn: "~> 0.7"]`, see (b)); an `app:` naming an application whose `.app` is not
found (`code:lib_dir/1`, 2.2 µs, P2). Accepted under C and refused under B: nothing. Accepted under C and
today: the same programs with no attribute, if the attribute is optional (needed, see below).

**Compiler delta**:
1. Grammar: a decl-prefix `'[' attr_items ']'`, which does not exist. New rules in `bs_parser.yrl` beside
   line 170 plus the tree-sitter mirror (`editor/tree-sitter-beam-sharp/grammar.js:183`); the highlighters in
   `editor/{vscode,zed,nvim,syntect}` follow. The yecc conflict count needs measuring as 106's delta says for its own alias:
   **not measured here**.
2. AST: `{foreign, Line, Mod, Sigs}` gains a field. Four match sites change (`bs_check.erl:615, 633, 1054, 1092`);
   `grep '{foreign,'` finds none in `bs_emit`, `bs_lower` or `bs_api`. Ticket 106's alias touches the same tuple.
3. Check: `code:lib_dir(App)`; on `{error, bad_name}` raise `foreign_app_unavailable` naming the **application**
   (unlike B), same `built`/`message` pair as B, same strict-only placement question.
4. **An OTP exemption is required or the attribute is noise**: 24 of the 30 in-repo blocks name OTP modules
   (`:erlang` alone is 13). `bs_otp.erl` is a behaviour table, not a module catalogue, so "is this OTP" needs a new
   table or a `code:root_dir()` prefix test on the resolved beam, which brings the machine back in. Simplest rule:
   the attribute is **optional**, checked when present.

**(b) version: refused, and the program shows why.** `[app: req, vsn: "~> 0.7"]` needs a constraint grammar,
which is resolution (ticket 51's boundary). An exact `vsn: "0.7.3"` could be checked against the `.app` file
(P2c reads `vsn "1.14.0"` from `elixir.app`), but it is a lockfile entry; neighbours already write one
(`mix.lock`, `rebar.lock`, ticket 51).
**(c) per block vs per module**: above, per block costs the second `[app: elixir]` line, which the reader
pays. In-repo it occurs once (`51a-code-path/Elx/elx.bs`: `String` and `Enum`, same app) and never in the
other 17 files. Per module (`[apps: req, elixir] module Fetch`) is the alternative; it separates the name from the
block that uses it, so a reader must correlate them, and `--api` then has module-level attributes to print.
Evidence is one file, so this brief does not choose; the case for per block is locality, the case for per module is
the one repeated line.
**Why `external: elixir` is dropped**: nothing in `bsc` could act on it, `app:` identifies the package already, and
ticket 51 measured the Elixir build-time requirement as a property of the *package*, not of the declaration.

**Evidence**: P2 (checks cost 2.2 µs), P2b (`lib_dir` is a directory-name convention, so a passing check does
not prove the module is inside that app), P4b (Erlang accepts and ignores exactly this shape),
P3a (mix does *not* check its `extra_applications`, so the neighbour with an app list in a manifest leaves the
same run-time gap).
**Strongest counterargument**: **it is a manifest written into the source, and it can lie.** `[app: req]` is
checked for presence, not for containing `'Elixir.Req'` (P2b: `lib_dir` matches directory names), so a wrong
`app:` passes and misleads the stranger it was written for. The honest form would also check that the module
is inside the app, which is `code:which` again, and then the `app:` line adds nothing the compiler could not
derive (P2c). Second: it makes the source name a package manager's unit (an application), which is the
scope boundary's territory, and the second and third extensions (version, `external:`) each have a case, so
the boundary is a slope here, not a line. Third: it does not remove B's problem (the verdict is still per
machine); it only names the missing application.

## 6. Recommendation

**Decide (a) first, then take (d) regardless.** (d) is available without (a) at 16 lines and no syntax (B),
and it turns run-time `error:undef` into a compile diagnostic. What is still open is whether that diagnostic may
depend on the machine.

1. **Adopt the diagnostic, but keep it out of the language's verdict.** B's strongest counterargument stands:
   an environment-dependent compile result. The smallest way through, in this brief's judgement, is B placed
   at `strict` mode only (so `--api` and the editor work without the dependency) **and** the spec saying the
   reference compiler's verdict on a foreign block is relative to the code path it is given. That is a spec
   sentence, not syntax.
2. **Answer (a) with "no source syntax yet"**, and put provenance where the handoff already puts the pinned
   toolchain, in `MANIFEST.lock` (`handoff/README.md`, "a `MANIFEST.lock` naming the source revision, the pinned
   toolchain…"). P2c shows the compiler can derive *name and version* of each resolved application from the
   beam paths it just checked, so a generated lock line costs the compiler no source syntax. That derivation is
   **shown, not built**, and it records what the *building machine* had, which is what a lockfile is.
3. **Hold C.** Its own counterargument (the `app:` line can lie, and needs an OTP exemption) is stronger than
   the gap it closes while B plus a lock covers the handoff. Revisit if a stranger's build actually stalls on
   "which package".

This departs from the ticket's sketch (C as the "right home") because the probes found a cheaper route to the
ticket's own destination; David may still prefer C for readability of the source, which is a judgement about
whether a reader wants `req` written next to `Elixir.Req`, not something a probe decides.

## 7. Not measured / limits

- **OTP 25, not 28.** The tickets (32, 51) measured on OTP 28.5; here `/tmp/claude-0/tools/otp-27.3.tgz` and
  `otp-28.0.tgz` are not valid archives, so only OTP 25 ran. `code:lib_dir/1`, `code:which/1` and
  `application:load/1` are old, stable interfaces, but the timings are OTP 25 on this machine and the
  `:json` verdict (missing on 25) is a fact about 25. That `json` exists in OTP 27+ is **not measured here**.
- **Gleam 1.12.0**, not 1.18.1 (ticket 32). Only offline behaviour: no hex, so package resolution success and
  the shape of an installed-dependency import were not seen.
- **Elm**: the behaviour of an `import` of an uninstalled package is **not measured**; the registry is blocked.
- **Elixir 1.14.0**, hex not installed: P3b could not reach the hex-dep check; the path-dep form (P3d) stands
  in for it. mix's behaviour on a hex dep missing from `deps/` is **not measured**.
- `rebar3` is not installed: rebar/xref's `undefined_function_call` report as rebar3 runs it was not run;
  `xref` itself was (P4c). The ticket named rebar3 xref; only OTP's `xref` was probed.
- **No parser prototype for C.** Its grammar cost (yecc conflicts, tree-sitter) is listed, not measured.
- Compile-time end-to-end noise: 41 runs each, spread larger than the check, so "a few percent" is an upper
  bound from the isolated numbers, not a measured end-to-end delta.
- `--api` under B was measured at `declared/4` only; the strict-only placement was not built.
- Whether a module→package map is computable from the atom alone is argued, not measured.
- The corpus counts (30 blocks, 24 OTP-only) come from `grep`, not the compiler.

## 8. Reproduce

```sh
cd /home/user/beam-sharp/artifacts/probes/52
TMPDIR=/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/52/tmpd ./run.sh
# individual probes
env -u ERL_LIBS ./p2/probe.escript ; ERL_LIBS=/usr/lib/elixir/lib ./p2/probe.escript
./p2/probe2b.escript ; ERL_LIBS=/usr/lib/elixir/lib ./p2/derive.escript
./p3/run.sh ; ./p4/run.sh ; ./p5/run.sh ; ./p6/run.sh
env -u ERL_LIBS ./p7/which.escript
# p1 by hand (reference compiler, HEAD):
B=/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/bsc.sh
cd p1; env -u ERL_LIBS $B --src-root . -o out Absent Count "[1,2,3]"       # crashed: error:undef
ERL_LIBS=/usr/lib/elixir/lib $B --src-root . -o out Present Count "[1,2,3]" # 3
# the patched copy is rebuilt by run.sh from p1/v1.patch; HEAD sources are never edited
```

## Verifier corrections (independent re-run, 2026-09-29; full text `probes/52/verify/REPORT.md`)

35 PASS / 3 FAIL reproduced; the three FAILs (P2b, P3b, P6a) are honest wrong expectations; the P2-E6 fix did not manufacture a pass; three mutations (module on path, patch reverted, patch refusing a real module -> 4 of 21 dirs fail) all behaved as predicted. Corrections:
- **Timings:** `code:which/1` on an unloaded OTP module (`zip`) is about 100-130 us warm; the 0.5 ms figure holds for an unloaded Elixir module or a miss on a 36-dir path (verifier: warm repeat 395-728 us; first call 0.6-1.5 ms), not for OTP modules generally. Verifier timings were taken at load average about 10. 'At most about 1 ms per module' stands.
- **No-false-positive claim (P1i)** covers only the 21 non-exemplar example dirs. Under B in strict mode, exemplar 25d (`:epgsql`, non_existing) and the 51a prototypes would also be refused on a machine lacking those dependencies; any gate compiling them needs `ERL_LIBS`.
- The claim that a patched compile of 25f prints the json refusal has no author probe (verifier reproduced by hand; HEAD refuses that invocation earlier with a directory-mismatch error).
- The four `Elixir.*` blocks are all in `wayfinder/prototypes/51a-code-path` (Req/req.bs:37,43; Elx/elx.bs:13,17), none in 50a. `check-language.sh` is at `compiler/bin/`.
- The lock derivation (P2c) works only for an `<app>/ebin/<mod>.beam` layout; escripts, archives and rebar `_build` layouts are unprobed.
- Gleam P5c cannot distinguish 'undeclared' from 'nonexistent' offline. Whether `json` exists in OTP 27+ is not measured.
- Nothing in the probes resolves the environment-dependent-verdict objection; the 'spec sentence' step is judgement.
