# Verification of artifacts/52/brief.md (ticket 52 / ENG-234)

Verifier: independent re-run, 2026-09-30. Nothing in the brief, ticket, Linear or git was edited or committed. Committed `.out` files were backed up first and restored with `git checkout` after each run. `git status` for `artifacts/52/probes` is clean. Outputs from the two re-runs are in `/tmp/claude-0/-home-user-beam-sharp/2e35dc52-b5e4-5ac3-801c-9c12d8324568/scratchpad/verify52/{committed,new,clean}`.

## Verdict

The brief's probes reproduce. I found no circular prototype, and every cited file:line checks out. The evidence shows the recommendation (B) is feasible and cheap. It does not show B beats A, so B rests on the ticket's handoff argument. Four rows are overstated or mis-framed (rows 1, 8, 12, 5). Row 1 is the most important.

## 1. Probe re-runs

I ran the re-run twice. The first run used the existing `/tmp` fixtures with `setup.sh` (idempotent) and `run-all.sh`. The second run first deleted every `/tmp` fixture (`mixdeps52b`, `fakelibs52*`, `manylibs52`, `bsc52`, `helper52`), then ran `setup.sh` and `run-all.sh` again. The mix-built `libdep` was rebuilt from scratch and hex was not needed. The two runs agree. `run-all.sh` takes about 20 s.

| Probe | Result |
|---|---|
| p01, p02, p03 (both outputs), p04, p06, p06a, p07, p07b, p08 | REPRODUCED (byte-identical) |
| p11, p13, p14, p15, p16, p17, p18 | REPRODUCED (byte-identical) |
| p10 (Elm) | REPRODUCED (same proxy 403 message). Brief marks it UNVERIFIED |
| p05 (timing) | REPRODUCED in conclusion. Figures vary, see below |
| p09 (Gleam) | REPRODUCED. The only difference is `Compiled in 0.67s` vs `0.38s` |
| p12 (yecc) | REPRODUCED. The only difference is the `mktemp` directory name in each line. Counts are identical: 6 / 6 / 6 / 7 / 6 |
| Eight `*.first_run_*.out` files | Static records. `run-all.sh` does not regenerate them, and they match their description |

p05 timing variance (committed vs mine):

| Measurement | Committed | Mine |
|---|---|---|
| 14 absent modules, 30 path entries | median 8.8 ms | median 7.1 ms |
| 1 absent module, 30 path entries | 0.58 ms | 0.47 ms |
| 14 absent modules, 236 entries | 59 ms (min 45, max 141) | 49 ms (min 36, max 76) |
| 1 absent module, 236 entries | 4.5 ms | 4.6 ms |
| Present + `.app` scan, 8 modules | 0.46 ms | 0.43 ms |

The brief states 8-9 ms and 40-60 ms for 14 absent modules. My 7.1 ms is slightly under that range; the 49 ms fits. The conclusion is unchanged: the cost is milliseconds. "Present" figures are for already-loaded modules, as the brief admits.

## 2. Circularity hunt

No probe hardcodes its expected output. I found no `|| true` or `2>/dev/null` swallowing a failure in the load-bearing probes. All failures are captured with `2>&1` and an `exit=` line. The one `|| true`, in `build-bsc.sh:16`, sits on an `erlc | grep error` pipeline, so it cannot hide the result of any probe.

### The eight first-run pairs

All eight fixes are legitimate probe bugs. None changed an expectation.

| Pair | Finding |
|---|---|
| p03 format crash | The `io:format` field-width pattern crashed. No logic change. |
| p06 `-pa` order | The scratch parser was shadowed by the repo's parser, so it failed with `syntax error before: in`. The fix is path order. The shadowing is what the probe needs: the repo's parser refuses `in` and the scratch one accepts it. |
| p08 no `+debug_info` | xref needs debug info. The `erlc` exit 0 result was the same in both runs. |
| p10 missing `elm.json` | See the Elm finding below. |
| p12 vacuous | The author caught it himself: productions landed after `Erlang code.` The first run shows `terminal symbol app not used`. The fixed run is non-vacuous, and I confirmed this by re-deriving the counts (below). |
| p13 `_started` | `_` is not a legal parameter name in B#. The fix changes only the identifier. |
| p15 unbuilt syntax | The first `total.bs` used `in :libdep`, which the repo parser refuses. The current `total.bs` has no `in`. That is correct, because p15 tests run-time behaviour on the real compiler. |
| p18 not loaded | The first run printed `Mix.install/2 exported: false` because the module was not loaded. `Code.ensure_loaded` gives `true`. Legitimate. |

### p12 re-derived from a clean baseline

I copied the repo's pristine `compiler/src/bs_parser.yrl` and ran yecc with `verbose` on OTP 25:

- **Baseline:** 6 shift/reduce.
- **Bare `using :app` (C2):** 7. The new conflict is `Reduce to decl from using atom_lit` against shift `{` in state 60. That is a real conflict: a bare `using :x` versus the start of a `using :x {` block.
- **`using :M in :app { }` (B), added beside the existing production:** 6.
- **Is B live?** It is, and not merely absent from the output. p06 parses `in` with the B parser, and the repo parser rejects it (first-run file).
- **Is `app` used in variant C?** Yes. The fixed output has no "not used" warning.
- **Caveat:** the counts are on OTP 25 yecc. The brief says "this yecc", which is fair. They are not verified on the repo's pinned OTP 28.5.

### p15 closure walk

The probe is real. `libdep.beam` calls `Enum.sum`. With only `libdep` reachable, the run ends `crashed: error:undef`, and it returns `6` once the Elixir lib dir is added. The closure script is a separate escript written by the same author, and nothing forces it to agree with the run. It did.

| Finding | Severity |
|---|---|
| The closure over-approximates. It flags `logger` as MISSING. `libdep` does not call `logger`, so a missing `logger` would not have caused the `undef`. The probe shows that closure-missing is a superset of crash causes, but the brief presents the closure as the cure for the `undef`. | LOW |
| The closure walk lives in a heredoc at `p15_transitive_closure.sh:14-23`, written to `/tmp/closure52.escript`. It is not in a named probe file. | LOW |
| The "about ten more lines" claim is fair. The script is 11 lines. | none |

### p03 census selection

I independently counted `grep -E '^\s*using :'` over `.bs` files excluding `artifacts/`. The result is **30 lines in 161 `.bs` files**, matching the script. `using` lines without `{` do not exist, so the regex is not hiding cases.

| Finding | Severity |
|---|---|
| **Prototype-heavy corpus.** 9 of 30 blocks are in `wayfinder/prototypes/*` (50a, 51a, 63d). Only `51a/Req` holds a real third-party application (Req). The one other third-party block, epgsql, is in exemplar 25d. All three Elixir-stdlib blocks are in 51a prototypes. The brief says "only two third-party blocks" (true) and "small sample" (honest). The corpus is one project's own programs, not an independent sample. | MEDIUM as context, not a fault |
| **Unresolved modules are lumped into one app.** `p03_census.out` (the default run, which the Reproduce table cites) has no Elixir on the path. `Req`, `Application`, `Enum` and `String` all map to `unresolved`, so the script reports **5 blocks repeating an application**. The brief says **4**. Four comes only from `p03_census_with_elixir_libs.out`, where they resolve to `elixir`. The brief cites neither file for the 4, and the Req directory's "3/2/1" in the default output is an artifact. The true number is 4: Interop 1, 25g 2, Elx 1. One of those is non-OTP. | LOW |
| **`app_of` uses the dir-name heuristic**, not the `.app`. That is fine here, since p04 shows the two agree. | none |

### Probes that cannot fail (tautological by design)

- **p06 is a model, and the brief says so.** It is an escript the author wrote to implement the proposed check. It cannot be evidence that the check is worthwhile. It shows only that the logic is about ten lines over a scratch-parser AST, and that the `.app` beside the beam gives the application. The `ERROR`/`NEEDS` strings come from the prototype's own `case`. The brief's "Author sees" block presents this output, and its caption says "run on real files with a scratch parser". Severity LOW. The brief also omits the fifth p06 line, `my_helper declared=my_project ... ERROR`, which is the build-order row.
- **p06 models a 5-tuple, but the recommended delta is a separate decl.** `build_parser_b.sh` makes the B production emit `{foreign, L, M, App, Sigs}`, and p06 matches that 5-tuple. That would break the four `bs_check` sites that match the 4-tuple. The brief's delta item 1 instead says "emit a separate `{requires,…}` decl and leave the 4-tuple alone". The grammar already supports this: `bs_parser.yrl:74` splices a list returned by a `decl`, as `clause_block` does. But one production returning `[{requires,…},{foreign,…}]` is not tested anywhere. MEDIUM-LOW. The conflict count is unaffected, since conflicts depend on the productions and not on their actions.
- **p14** measures synthetic abstract forms through `compile:forms`, not a real `bsc` module. The brief cites `bsc.erl:843 from_abstr`. That matches `bsc.erl:838-848`, where the `build` options include `debug_info`. The +52/+76 bytes figure is fair for an attribute of that shape.
- **p16** holds trivially today: there is no dependency field in the AST for `--api` to print. The claim is only that `--api` is environment-free now. That is true and is worded as such.

### Elm (p10)

The brief says the one message obtained "said `MISSING DEPENDENCY … elm.json`, so Elm checks source against a manifest." That first-run message (`p10_elm.first_run_missing_elm_json.out`) says Elm needs an `elm/json` dependency in `elm.json`. It came from the author's incomplete `elm.json` fixture, not from a source `import`. It does not show Elm cross-checking source imports against a manifest. The committed final output is the proxy 403. The brief labels the row UNVERIFIED, which is right. The inference drawn from it is unsupported. Severity LOW-MEDIUM.

## 3. Citation and number spot-checks

All confirmed.

- **Source lines:**
  - `bs_parser.yrl:169-170` is the `foreign_decl` production. The brief's `:170` is its action line.
  - `bs_check.erl:615, 633, 1054, 1092` are the four `{foreign, _, Mod, Sigs}` sites.
  - `bs_emit.erl:73-78` are the module attributes.
  - `bs_api.erl:60` is "read and never built".
  - `bs_lexer.xrl:131` lexes quoted atoms.
  - `grammar.js:183` is `foreign_declaration`.
  - `bs_diag.erl:1014-1018` holds the `unreachable_arm` warning.
  - `req.bs:44` has `atom app`.
  - The `fn`/`raise` keywords are at `bs_lexer.xrl:79` and `:86`.
  - The `in` keyword exists at `bs_lexer.xrl:54`.
  - `LANGUAGE.md` §11 is at line 2894 and uses `using :ets {`.
- **Ticket 32:** `wayfinder/issues/32-ffi-surface.md:177` has `[external: erlang, "ets"]`.
- **Tickets 50 and 56:** both are resolved (2026-08-26 and 2026-08-22). Ticket 65 is open, so the "ticket-65 reservation" is accurate.
- **Ticket 52 text:** the brief's quote of the ticket, and the `[external: elixir, app: req]` spelling, are accurate.
- **Numbers:**
  - 30 foreign blocks in 161 files: confirmed.
  - 14 distinct modules: confirmed.
  - erts 13, kernel 1, stdlib 10, `:json` the 25th OTP: confirmed. The 5 non-OTP are 3 Elixir blocks, Req and epgsql (blocks, not modules).
  - 12 of 27 applications share a module's name: confirmed. The list is crypto, elixir, eunit, ftp, inets, kernel, mnesia, public_key, runtime_tools, sasl, ssl, tftp.
  - Conflict counts 6 vs 7: re-derived.
  - Only `1.3.0` on the path with two versions: confirmed.
  - `+52` / `+76` bytes: confirmed.

## 4. Evidence-table verdicts

| # | Verdict | Note |
|---|---|---|
| 1 | **NOT CONFIRMED as a refutation (strawman)** | p02 is correct: compile exits 0 and the run crashes with `undef`. But the ticket itself says the failure is "a run-time `error:undef`", in the last bullet ("turns a run-time `error:undef` into a diagnostic"). The ticket never claimed a compile-time failure. The brief reads "Compile it on a machine… fails at the call site" as compile-time failure. The facts stand, but **"REFUTED" is wrong framing**. |
| 2 | CONFIRMED | |
| 3 | CONFIRMED, slightly overstated | p06a shows an undeclared *static* call is refused. It does not rule out dynamic naming, such as `:erlang.apply` with a module variable, or a module name given to a behaviour. For a compile-time check, only static names matter, so the conclusion holds. |
| 4 | CONFIRMED (trivial) | |
| 5 | CONFIRMED, with the over-approximation caveat | "One line is not the whole feature" holds: the `undef` is real. But `logger` is flagged although it is not needed, so the closure is a superset check. |
| 6 | CONFIRMED | `get_application/1` is `undefined` for `libdep` and `elixir`, though it returns `{ok,stdlib}` for `lists` because stdlib is running. The brief's "cannot be used" is right for the cases that matter. |
| 7 | CONFIRMED | |
| 8 | CONFIRMED on a small sample | The count of 4 comes from the with-Elixir run, not from the default `p03_census.out`, which says 5. See the p03 finding. |
| 9 | CONFIRMED | |
| 10 | CONFIRMED | |
| 11 | CONFIRMED | The p13 argument ordering is sound: the argument is evaluated before `Ready`'s body runs. |
| 12 | CONFIRMED as a fact, **the claim is a strawman** | No ticket claimed application and module atoms are unambiguous. The collision bites only spelling C2 (`using :req` with no block), and that spelling is also rejected on the yecc count. The 12-of-27 figure is mostly OTP. Third-party Elixir applications rarely collide, because Elixir modules carry an `Elixir.` prefix. |
| 13 | CONFIRMED | Re-derived. The 6-versus-7 difference is a real conflict, not noise. |
| 14 | CONFIRMED | |
| 15 | CONFIRMED (timing conclusion) | The mild variance is listed above. |
| 16 | CONFIRMED | |
| 17 | CONFIRMED (trivial) | |
| 18 | CONFIRMED | |
| 19 | UNVERIFIED, correctly labelled | I did not attempt Req. |
| 20 | UNVERIFIED, correctly labelled | |

No row is CIRCULAR. p06 and p14 are models. Their outputs show that the logic is small, not that the design is correct. The brief states that they are models.

## Does recommendation B still follow?

**It follows, but the evidence selects the gating answer less than the brief suggests.**

- **What the evidence supports.** It supports saying "yes, the source names the application". Rows 4 and 6 show the application name is absent from the source and derivable from the environment. B costs 0 conflicts and no new keyword (rows 13, 14). The compiler change is small (p05, p06, p14).
- **What it does not show.** It does not show that A is worse for the actual goal of a clean-room handoff. That argument is the ticket's, and no probe tests it. The brief leans on the strawman rows 1 and 12. Strip those two out and the case for B is still the ticket's premise plus a cheap grammar. That is a legitimate basis, but it is a judgement call for David, not a measured result.
- **A gap in the C comparison.** C's rejection rests on the bare-atom conflict (7) and the `app` keyword. The brief did not test a non-keyword spelling, for example reusing the `in` token as in `using :req in :req;`. So "B has zero cost and C does not" compares B against the C spellings the author tried.
- **Two points David should see before deciding.** They are the row-1 framing (the ticket already said run-time) and the delta-1 gap (separate-decl form untested, though the parser precedent exists).
