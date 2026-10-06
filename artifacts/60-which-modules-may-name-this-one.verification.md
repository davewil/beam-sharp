# Verification of the ticket 60 brief (ENG-242)

Verifier run 2026-10-06. Scratch: `scratchpad/verify60/` (four fresh builds from `compiler/src`:
pristine, patched, caller, path; plus `adv*`/`gl` break-tests). Nothing in the repo was edited.
`compiler/src` is unchanged between `712b9e9` and HEAD (`git diff --stat` empty).

## Overall verdict: VALID-WITH-CAVEATS

Every probe reran and matched its captured `.out` (timing probes within noise; one hash line is
path-dependent by design). No probe is circular in the sense of "the refusal is produced by the patch
text alone": in each prototype the refusal is conditional on the predicate, and flipping the sources
turns it green. The caveats are small and listed under "Claims to correct".

## Per-probe table

| Probe | Rerun vs captured | Break test I ran | Verdict |
|---|---|---|---|
| 60a | match | walker returns `[]` for dynamic forms by construction (bespoke walker, not a real checker); runtime results are real, control `undef` real | VALID-WITH-CAVEAT |
| 60b | match (also with a bsc built fresh from HEAD, so `$BSC` == HEAD behaviour) | Peek control exits 1 | VALID |
| 60c | match | rebuilt from scratch, see Gleam section: path dep, warnings-as-errors, still exit 0 | VALID-WITH-CAVEAT (path dep only) |
| 60d | match | controls present and red/green as claimed | VALID |
| 60e | match | `ignore_xref`: I grepped all of the OTP install, not only `src`: 0 hits. Line cites `xref.erl:53`, `edoc_tags.erl:93-95`, `edoc_data.erl:165` correct | VALID |
| 60f | match (V1..V7) | set `visible_to Lab.Web`: Web compiles, Billing refused. `visible_to Lab.Bill`: `Lab.Billing` refused (prefix needs the dot). No decl: compiles | VALID |
| 60g | structure matches; numbers differ, noise | rerun medians: a 2529, b 1328, c 1336, a' 1516 ms (pristine slower than patched this time) | VALID-WITH-CAVEAT (supports "not detectable" only) |
| 60h | match in shape; absolute 1.3 to 3.3 ms for the 1-entry case (2.0 captured), 10.7 to 21.6 ms for 16 (17.2 captured) | control accepts 0/595 reproduced | VALID-WITH-CAVEAT |
| 60i | chunk results and 980 vs 980 match; the sha256 line differs | see 60i note below | VALID-WITH-CAVEAT |
| 60j | match (also with HEAD-built bsc) | outputs as captured | VALID |
| 60k | match | `forbids Lab.Grp.Core` refuses; changed to `forbids Lab.Other`: compiles | VALID-WITH-CAVEAT (K3 is true by design) |
| 60l | match (`go1.24.7`; pkg.go:1473-1475 and :1574 correct) | control `web2` exit 0 | VALID |
| 60m | match | renamed `Internal` to `Intern`: Web compiles; back to `Internal`: refused | VALID |
| 60n | match, but only with `PATCHED` = the `--patch` (`visible_to`) build; the script's header does not say so, and with the `--patch-path` build N2 fails with `undef` | N1 is by construction (tag derives from the module name) | VALID-WITH-CAVEAT |

## Prototype deltas (diff of each patched copy against `compiler/src`)

| Patch | Measured delta | Brief says | Agrees |
|---|---|---|---|
| `--patch` | `bs_check.erl` +24/-2; `bs_diag.erl` +7; `bsc.erl` +1; lexer +1; parser +4/-2 | +24, +7, +1, "+5 parser" | yes (parser is +4/-2, net +2; trivial) |
| `--patch-caller` | `bs_check.erl` +5 (inside `import_env`, which is at :488), diag +5, lexer +1, parser +4; `bsc.erl` 0 | "five lines in `import_env`", no `World` field, no `bsc.erl` change | yes |
| `--patch-path` | `bs_check.erl` +18, diag +7; lexer, parser, `bsc.erl` 0 | +18, +7, no syntax | yes |
| namespace branch | 10 added lines plus one modified, in the `--patch` copy | "12 of them" | roughly (11) |

Circularity hunt, by patch:
- Messages live in the patch, but each is raised only from `erlang:error({not_visible_to,...})` guarded by
  the predicate (`Ok orelse erlang:error`). Flip tests above show the predicate decides.
- 60g (c): I verified the check really runs in the cost workload. A `visible_to Nope` on a generated
  module makes `Gen.M1` fail; `visible_to Gen` compiles. So (c) is not a no-op.
- 60h is a standalone fun, not the checker. It is an upper bound on the predicate alone (includes
  `lists:seq` and comprehension overhead, excludes the `maps:get` and `World` lookup, which are tiny).
  The "about 0.1%" claim holds as an order of magnitude. Do not quote 2.0 / 5.1 / 17.2 ms as stable:
  my rerun gave 1.3 to 3.3 / 3.4 to 7.6 / 10.7 to 21.6.
- The brief says the check skips `--api`/lenient. Backed by me, not by a captured probe: with an
  offending `using` and `visible_to Lab.Web`, `bsc --api` on `Lab.Billing` exits 0 and prints the module.
  No probe in `artifacts/probes/60/` captures this.

## 60i note

The brief says "raw file hashes differ even for identical input". True. I compiled the same pristine
sources three times: `.beam` sha256 differs each time, `.abstr` sha256 is identical. All-chunk
comparison (`beam_lib:all_chunks`, including `Dbgi`, `Line`, `LocT`, `CInf`) shows only `CInf` (the
compile-info chunk) differing, both run-to-run and pristine-vs-patched+decl. So the evidence is stronger
than the 8 chunks the probe lists. The `.out`'s sha256 prefixes are not reproducible (the source path
is a `mktemp` dir and ends up in the `.abstr`/`Line` data); only the equalities within one run matter.
Caveat: the probe shows the prototype emits nothing, which is true by construction of the patch (it adds
no emit code). It confirms the declaration does not leak into emission by accident. It does not show a
production implementation could not choose to emit metadata.

## Gleam `internal_modules`, rechecked

Built fresh (not the probe's script): `liba` with `internal_modules = ["liba/internal","liba/secret"]`,
and a separate `appb` with `liba = { path = "../liba" }` (a different package), importing both
`liba/internal/helper` and `liba/secret/vault`.
- `gleam build`: exit 0. `gleam build --warnings-as-errors`: exit 0. No diagnostic at all.
- One package, `internal_modules = ["solo/internal"]`, another module in the same package importing it: exit 0.
- So the brief is not misreading scope: the cross-package case is exactly the one tested, and the
  compiler does not refuse it. 60c's G1..G3 also use a path dependency from another package.
- Caveats: only a path dependency, not a hex dependency (no network). Gleam's documented intent (docs
  and LSP hiding, publish-time type-leak check) is consistent with "no refusal"; I could not retrieve the
  doc text (Context7 returned nothing for the query) and did not test the LSP, so "Gleam does not refuse
  an importer" is empirical for `gleam build` 1.18.1 only. The `strings` evidence for the publish-time
  check is a string in the binary, not behaviour.

## Brief claims: backed or not

| Claim | Backed by | Status |
|---|---|---|
| abstr identical, both beams 980 bytes, 3 chunks differ on body change | 60i, rerun | backed |
| +24 lines (check), +7 diag, +1 `bsc.erl` | diff of patched copy | backed |
| 201 modules / 595 edges | 60g header, rerun | backed |
| ~1.6 s build | 60g medians 1.3 to 2.5 s | backed as order of magnitude |
| Gleam does not refuse | 60c and my rebuild | backed (path dep only) |
| Apply bypasses using/xref | 60b B3 (runs, prints 4), 60e, 60d | backed |
| `add_module_import/5` is now `/3` at `bs_check.erl:511`, called from `add_import/7` at :497 | grep: `:511`, `:497`, call at `:499`; ticket text lines 18 and 57 say `/5`; F32:96 says `/3` | backed |
| ":407-425 is now `qualify_refs`" | `qualify_refs` clauses at 408 to 425 | backed |
| `private_callee/3` :4268, `private_table/1` :554, call sites :3653 and :4196, `bsc.erl:227` | grep; :227 is the `World1` entry inside `build/4` (starts :222) | backed |
| `unclassified` premise stale | 60j (J1, J2, control, J3), F12 amended 2026-08-17; ticket 60 itself opened 2026-08-23, after F12. `boundary/callbacks/unclassified` appears nowhere in compiler or wayfinder besides tickets 22/24 | backed |
| The `unclassified` tag in `bs_diag.erl` and `F47` | is a diagnostic tag, unrelated to the ticket's term; no confusion in the brief | n/a |
| Record tag changes under `Internal` | 60n N1 (by construction, two sources at two paths) | backed, weakly: no real "move" was run |
| "An Erlang caller of `'Lab.Core.Pricing':'New'` breaks" | not run; my accidental run of N2 with the wrong build produced `undef` for the missing module, which agrees | unbacked as a probe |
| Check skips `--api`/lenient | my probe, not a captured one | unbacked in the repo |
| Signature-level form delta | code reading only; brief says so | labelled |
| "Nothing under wayfinder/ edited" | `git status` shows no `wayfinder/` change | backed |

## Claims to correct in the brief

1. Header says `bsc` built at `712b9e3`. That object does not exist. The commit is `712b9e9`.
2. 60h numbers (2.0 / 5.1 / 17.2 ms) are reproducible only to within roughly 2x on this machine; quote a range or say "a few ms".
3. 60g row a' (median 2351 ms) is noise, as the brief says. My rerun flipped the ordering (pristine slowest). Keep "not detectable"; do not read any ordering into the rows.
4. Add that `--api`/lenient skipping the check has no captured probe (or add one). Same for the Erlang-caller-breaks claim.
5. 60n header: state that `PATCHED` must be the `--patch` build, not `--patch-path`.
6. 60k K3 (`Web2` compiles) follows from the design ("naming module writes"). Say it is an illustration, not a finding of the prototype. No pristine arm exists for 60k because pristine cannot parse `forbids`.
7. Gleam row: say "path dependency, `gleam build` 1.18.1" so a hex-dependency case is not implied.
8. Minor: the parser delta is +4/-2, not +5; the namespace branch is about 11 lines.
