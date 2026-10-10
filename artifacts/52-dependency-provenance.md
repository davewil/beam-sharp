# Ticket 52 (ENG-234) -- Dependency provenance: decision brief

Status: the ticket stays OPEN for David. Nothing under `wayfinder/`, `compiler/` or Linear was edited. Probes:
`artifacts/probes/52/` (`run.sh`, `output.txt`). Measured on Linux x86_64, OTP 28 / erts 16.4, Elixir 1.20.4, rebar3 3.27.1,
Gleam 1.19.1, HEAD `a5af573`. The box was a shared 4-core machine at load average 18-27, so every timing below is CPU time
with its noise floor next to it.

## 1. What the ticket claims, measured

| claim | observed (`output.txt` section 1) |
|---|---|
| ERL_LIBS alone reaches a dependency | **True.** A real mix app and a real rebar3 app, built locally, ran from B# with only `ERL_LIBS` set: `"hello bob"`, `8` |
| a different ERL_LIBS "fails at the call site with `error:undef`, having promised nothing" | **Half right.** The *compile* does not fail: exit 0. The `undef` is the *run* phase (`bsc Mod Fn args` compiles then runs). Same program, ERL_LIBS without the app: `crashed: error:undef` |
| (not claimed, worse) | `using :no_such_mod { int f(int n) }`, a module that exists nowhere, **compiles with exit 0**. `bsc` consults the code path nowhere for a foreign module |
| `[external: elixir, app: req] using ...` | **Not the current surface.** Ticket 32's attribute spelling was superseded: the shipped form is `using :'Elixir.Req' { ... }` (`compiler/src/bs_parser.yrl:170`) and the grammar has no attribute syntax. Ticket 106 (resolved) adds a per-entry `= :'get!'` alias, unbuilt. I use `in :req` below as a placeholder spelling |
| "the spec cannot see the dependency" | **True, and wider:** `ERL_LIBS` appears 0 times in `LANGUAGE.md`, `README.md`, `compiler/README.md`. `bsc` writes `UseEl.beam` and `UseEl.abstr`, no `.app` |

Side finding: `LANGUAGE.md:3116` says of `using :"Elixir.Enum"` that "quoted atoms are not lexed yet". The verifier compiled the double-quoted form
and got `syntax error before: ':'`; only the single-quoted `using :'Elixir.Fakeel'` lexes, compiles and runs. So the sentence is not simply stale:
the single-quoted spelling the ticket uses works and the double-quoted one the doc names does not.

Already decided, so not re-asked: 51 (no build tool; `ERL_LIBS` is the mechanism), 32 and 106 (`using` is the foreign declaration;
entries may bind names), 41 (`LANGUAGE.md:157`: "a file's `using` lines are its dependency list", and 41 section 1 point 3 adds
"in the file, checkable"). No ticket decides whether the source names an *application*: `grep -ln provenance` hits 51, 52 and
unrelated tickets; no decisions entry mentions an application name.

## 2. The gating question, asked alone

**Should `using :'Elixir.Req' { ... }` say `req`?** (Per block or per module, and whether the compiler checks it, follow from the
answer and are not asked here. Section 6 holds what I measured for them.)

### Option A -- no: the block names the module and nothing else (today)

```csharp
module Fetch

using :'Elixir.Req' {
    term new(list<(atom, term)> opts)
}

public term Mk()
Mk() -> :'Elixir.Req'.new([])
```

Compiles on any machine, exit 0, whether or not Req exists (measured, `UseMissing`). Provenance lives in `rebar.config`, `mix.exs`
or an environment variable. Compiler delta: none.

- Evidence: the source of a program using Req records `Elixir.Req` and no more; there is no file in a `.bs` project from which
  the package can be read, because 51 decided there is no manifest.
- Strongest counterargument against A: a stranger cannot recover the application from the module, and the spec is silent. On the
  corpus I could build (OTP 28 + the Elixir distribution + 2 fakes: 42 applications, 1761 modules) the module name predicts its
  application for **590 of 1761** (a module equal to or prefixed `app_`, or an Elixir first segment snake-cased); 25 of 42 applications
  contain a miss (`httpc` is in `inets`, `group` in `kernel`, `ets` in `stdlib`). That corpus is OTP-shaped; Hex libraries
  (`Elixir.Req` in `req`) mostly follow the first-segment rule, which I could not measure here (UNMEASURED: Hex is blocked).

### Option B -- yes: the block names the application (name only, no version)

```csharp
module Fetch

using :'Elixir.Req' in :req {
    term new(list<(atom, term)> opts)
}
```

Prototype built (`proto-v2.diff`, run in `output.txt` section 7). The same source with the application absent, wrong, or mistyped:

```
AppAbsent/appabsent.bs:3:1: error: the application `req` is not on the code path
  `using :'Elixir.Req' in :req` needs its ebin directory; put the directory that
  holds `req/ebin` on ERL_LIBS before compiling.

AppWrong/appwrong.bs:3:1: error: :'Elixir.Fakeel' is not in the application `fakeerl`
  it is in `fakeel`

OtpWrong/otpwrong.bs:3:1: error: :ets is not in the application `erts`
  it is in `stdlib`
```

`using :httpc in :inets`, `:lists in :stdlib`, `:erlang in :erts` compile. Under today's grammar the same text is `syntax error
before: in` (control, measured on the V1 build).

Compiler delta (concrete):
- `bs_parser.yrl`: one extra arm, `'using' atom_lit 'in' atom_lit '{' foreign_sigs '}'`. `in` is already a token (comprehension
  generator), so no new reserved word. yecc conflicts before 6 shift/reduce, after 6 (the repo's 47c method; the 6 are pre-existing).
- `{foreign, L, Mod, Sigs}` becomes a 5-tuple with the application or `none`: 4 match sites, all in `bs_check.erl` (lines 623, 641, 1065, 1103).
- `bs_check:foreign_available/3`, called beside `foreign_rets_decidable` (`bs_check.erl:332`), ownership read from the `.app` file beside
  the beam (`owner_app/1`); `bs_diag` gains two tags. **Prototype: 68 added / 5 removed lines** (`git apply --numstat`; an earlier count of 65 skipped blank lines). Not built: tree-sitter
  (`editor/tree-sitter-beam-sharp/grammar.js`), the vscode and sublime grammars, `LANGUAGE.md` section 11, an F-file.
- Existing tests: with this patch (hard errors) the eunit suite is **1434 passed, 0 failed**, same count as HEAD (HEAD: 7m20s whole;
  prototype run per module because the load made eunit's 5 s timeout cancel runs, `eunit_output_prototype.txt`). That green is partly
  luck of ordering: seven fake modules (`users_db`, `trees`...) appear in tests, but in the ones I opened (`foreign_return_tests`, `strings_tests`, `function_value_tests`) only in tests that expect an earlier refusal, which fires before this check.
  Gates: `check-diagnostics`, `check-examples` (28), `check-tour`, `check-exemplar-frontier` pass. **`check-language.sh` goes red: HEAD
  141 ok / 0 wrong, prototype 139 ok / 2 wrong** -- `LANGUAGE.md:756` and `:770` name `:analytics_db`, a made-up database
  (`gates_output_*.txt`). That red comes from the *check*, not from the `in` clause (see section 4).

- Strongest counterargument against B: of 21 foreign blocks in shipped examples, 20 name OTP modules (`per_file_apps.sh`: only
  `epgsql` in exemplar 25d is outside OTP). If `in` is mandatory, 20 blocks gain `in :stdlib` noise. If optional, absence
  means either "OTP" or "forgot", so the provenance a stranger wants is incomplete exactly where it is cheapest to omit. And a name
  nothing reads is a claim nobody checks, the `@external` shape ticket 18 refused (section 3 shows Gleam's is that shape).

## 3. How the neighbours handle it (probed; the Elixir and Gleam sources are not installed, so these are binary probes)

None of the four puts the application in the *source*. Each puts it in a manifest, and each treats a source-level mention of an
undeclared module differently:

| | where the application is declared | what happens to a call/import of a module not in it |
|---|---|---|
| Gleam 1.19.1 | `gleam.toml`; the generated `p2.app` has `{applications,[lib1]}` | `import lib2` where lib2 is only transitive: **warning** "not a direct dependency ... may become a compile error". `@external(erlang, "no_such_mod", "f")`: **builds, exit 0**, then `runtime error: Erlang error` -- Gleam's FFI is as unchecked as B#'s today |
| Elixir 1.20.4 | `mix.exs` deps, written into `cons.app` `{applications,[kernel,stdlib,elixir,logger,fakeel]}` | `Fakeel.greet` with fakeel only on `ERL_LIBS`: mix **ignores ERL_LIBS** and warns "module Fakeel is not available". Declared as a dep: no warning. A warning, never an error |
| Erlang/OTP | `.app.src` `applications` | `erlc` never checks a remote call. The one place it reads the code path is `-behaviour`: `Warning: behaviour no_such_behaviour undefined` (`erl_lint.erl:1330`, a try/catch around `behaviour_info`). `rebar3 xref`: warns `calls undefined function fakeerl_lib:twice/1` only when the dep is *off* the path; with it on `ERL_LIBS` and undeclared, **0 warnings**. `systools:make_script` on an app listing an absent one: `{error,systools_make,{undefined_applications,[ghostapp]}}` |
| Elm 0.19.3 | `elm.json` | UNMEASURED beyond one fact: `elm make` validates `elm.json` first ("MISSING DEPENDENCY elm/json") and then needs `package.elm-lang.org`, which is blocked, so I could not see its handling of an undeclared import |

What this means for B#: for a source reference to an absent or undeclared module every neighbour *warns* (inference from the probes, not itself probed as a cause; systools errors, but only for a
declared-but-absent application at release time). And the property that makes `ERL_LIBS`-only reach work for `bsc` (51) is one Mix does not honour. B# is the only one of the five with no manifest *and* nothing in the source.
Closest in-source analogue: Gleam's per-module `import` check, which finds the owning package from the manifest and tells the
author which one to `gleam add`. Under B the equivalent is the `in :req` text itself.

## 4. What the compiler could cheaply check, and what it costs (`output.txt` sections 2-4, 8)

| check | Elixir-style app | rebar3 app | OTP app (crypto, inets) | in erts / preloaded | absent |
|---|---|---|---|---|---|
| `code:which(Mod)` | path | path | path | `preloaded` (erlang) | `non_existing` |
| `code:lib_dir(App)` | path | path | path | path (erts) | `{error,bad_name}` |
| `application:load(App)` | ok | ok | ok | ok / `already_loaded` | `{error,{"no such file or directory","x.app"}}` |
| `code:ensure_loaded(Mod)` | `{module,M}` | `{module,M}` | `{module,M}` (loads the module, so runs any `-on_load`; not measured for crypto) | `{module,M}` | `{error,nofile}` |

All four answer the same way for Elixir, rebar3 and OTP layouts. Cheapest and side-effect free: `code:which`. `ensure_loaded` loads the
module (and runs its `-on_load`); `application:load` registers the app. A module name does not name its application, but the `.app` file
**beside the beam** does, exactly: it named `inets` for `httpc`, `stdlib` for `ets`. Three alternatives fail: the directory name
(correct on every standard layout, wrong for a loose `-pa` directory: `loose_mod` -> `clean`, `owner.escript`); the `.app` `modules`
list (3 of 42 apps list fewer modules than they ship: erts 3 unlisted, diameter 8, asn1 21); and the module-name prefix (590/1761).
No module sat in two application directories on this path.

Cost, fresh VM each (15 VMs, microseconds, median / min / max):
`which` present 89 / 50 / 1360, absent 154 / 105 / 949; `lib_dir` 6 / 5 / 11; `application:load` absent 1120 / 784 / 4578 (it scans the
whole path); `ensure_loaded` present 702 / 514 / 10917. Whole-`bsc` CPU, 25 runs: HEAD `UseEl` median 519 ms, HEAD again 480 ms (the
noise floor, 2-39 ms across runs), prototype 476 ms; `Interop` (3 blocks) HEAD 506, prototype 505. **The check costs less than the noise floor** (whole-`bsc` timing only; no positive control showing the harness would see a slower check).

**The cost that matters is not time, it is hermeticity.** A check that reads the code path makes whether a source *compiles* depend on
the machine. Measured on the prototype: `bsc --api UseMissing` (reports signatures, "nothing built") exits 0 on HEAD and exits 1
with the dependency absent. The clean-room judge compiles tickets with the reference compiler as oracle; an oracle whose verdict
depends on `ERL_LIBS` is not a function of the source. That is the reason `check-language.sh` went red above, and why every neighbour
warns. A name in the source is hermetic; a check against it is not.

## 5. Recommendation

**Option B, name only, and nothing else decided with it.** The reason: it is the only choice that puts the dependency in
the file, which 41 already promised ("in the file, checkable") and the handoff needs; the module name cannot stand in
for it (33% on the OTP-plus-Elixir corpus I could build, 590 of 1761 by a snake-case regex and 626 by a plain one, so weak support; the rule is still wrong in the direction a stranger cannot guess). It costs one grammar arm
and zero new conflicts. I would not decide the check in the same breath: the measured trap (a hard error turns the spec's own gate red
and makes `--api` environment-dependent) says the check is a separate question with an answer closer to "warning, or only when
a function is run" than to "error". The unconsumed-name risk is real: make `bsc --api` print the applications a module needs
(UNMEASURED, small) so that something reads the text.

## 6. What follows if B is chosen (pre-measured, not asked)

1. **Per block or per module?** Per block keeps 41's sentence true ("`using` lines are the dependency list"). Repetition is real but
   small: 3 of 10 shipped files with foreign blocks name one application twice (`Interop`: erts, stdlib, stdlib), all in OTP.
2. **Is `in` mandatory?** Mandatory touches 20 of 21 existing blocks (all OTP). Optional makes absence ambiguous (above). A middle rule needs the compiler to know "OTP", which `bs_otp.erl` does not.
3. **Severity of the check.** Hard error: `check-language` 141/0 -> 139/2, `--api` becomes machine-dependent, exemplar 25d (`:epgsql`) can no longer be checked without it installed.
4. **Ownership is only checkable when the `.app` is beside the beam.** A loose `-pa` dir has no owner; the prototype accepts it
   (`LooseOk` ran `8`), so the check has a hole.
5. **Version:** the `.app` carries `vsn` and `application:get_key` reads it, but a constraint is resolution; 51 keeps it out. Not prototyped.

## 7. UNMEASURED

Hex package name vs OTP application name (e.g. `req` -> `req`); first-segment rule on real Hex libraries; Elm's undeclared-import
behaviour; `erl -mode embedded` effect on `ensure_loaded`; a release tool (relx) consuming an `in :app` line; whether modules move between
OTP applications across releases (one OTP installed); tree-sitter/editor grammar patch; the `--api` listing; Elixir and Gleam
source citations (not installed -- behaviour probed instead); the transitive closure of an app's `applications` list (51 saw `eex`
missing from a vendored tree; I did not build the closure check).

## Probes and how to rerun

`cd artifacts/probes/52 && source /tmp/claude-0/env.sh && SCRATCH=$(mktemp -d) ./run.sh > output.txt 2>&1` (about 5 minutes). It builds the two
fake applications, reruns every table above and rebuilds the prototype in a scratch copy from `proto-v1.diff` (module must load) and
`proto-v2.diff` (V1 plus `in :app`). Controls beside each result: the reachable case beside the unreachable, OTP beside the dependency,
the correct application beside the wrong one, HEAD beside the prototype, a loose directory beside a standard layout.
Separately, because they take 20+ minutes: `eunit_by_module.sh <compiler dir>` and `gates.sh <compiler dir>` (outputs
`eunit_output_prototype.txt`, `gates_output_prototype.txt` (a `tail -6`: it holds `exit=1` only; the 141/0 vs 139/2 counts come from the verifier's rerun, `verification/52.md`), `gates_output_head.txt`; HEAD's full `rebar3 eunit`: 1434 passed in 7m20s).

Probe fixes on the way: the first `checks.escript` mislabelled `ets` as an erts module (it is stdlib; relabelled); `short/1` printed nested
iolists; `mk.escript` had a printf escaping bug; the loose-directory probe first copied the wrong beam; `repo_foreign.sh` counted an
empty set as one. All were fixed before the final `output.txt`, and everything was rerun.
