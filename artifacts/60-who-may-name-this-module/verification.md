# Independent verification of brief.md (ticket 60 / ENG-242)

Verifier run 2026-10-11. `compiler/src` is unchanged since `019533d` (`git diff 019533d HEAD -- compiler/src` is empty), so the brief's measuring rev still describes the code. Work dir: `$S/verify60/` (probes and patches copied there, patches re-applied to fresh copies of `compiler/src`, all four compilers rebuilt from scratch into `$S/verify60/proto/ebin_{base,A,B,C}`, so there is no stale-ebin question).

## Verdict: VERIFIED WITH CORRECTIONS

Every probe reproduces; every headline refutation holds under programs I wrote myself; the four-door claim holds and I found no fifth door. The corrections are wording and measurement-scope, listed at the end. None changes the recommendation.

## 1. Probe re-runs (clean state, diffed against the committed `.out`)

| Probe | Verdict | Notes |
|---|---|---|
| `a_checker_today.sh` | reproduces | Only the `repo rev` header line differs (HEAD moved to `6887dd0`; compiler/src identical). |
| `f_unclassified_helper.sh` | reproduces | Byte-identical, including case 4 (test file in `Cart/` ships `TestRecompute/1` in the production beam). |
| `gleam_internal.sh` | reproduces | Only "Compiled in 0.NNs" timings differ. |
| `elixir_probe.sh` | reproduces | Byte-identical. |
| `erlang_xref.sh` | reproduces | Byte-identical. |
| `elm_probe.sh` | reproduces | Byte-identical: cannot run (package server 403), as the brief says. |
| `go_internal.sh` | reproduces | Byte-identical. |
| `rust_pub_in.sh` | reproduces | Byte-identical. |
| `e_prototype.sh` | reproduces | Byte-identical, run against compilers I built from the patches. |
| `e_emit_unchanged.sh` | reproduces | Only the beam md5s differ; the brief says these are non-reproducible and compares `.abstr`, which are identical as claimed (Reports identical; Orders differs only by the `Friends.bs` file attribute). |
| `e_micro` | reproduces within noise | A no-friend 11.6 ns (brief 11.5); A listed 19.9 (brief 31); A refused 139 (153); B no-segment 366 (450); B with segment ~910-945 (~1000). Same ordering and magnitude. |
| `e_cost.sh` | reproduces qualitatively, not numerically | Sweep: 28/28 compile in all four builds. Timings: see section 5. |

## 2. Claim ledger and numbers re-measured

| Item | Result |
|---|---|
| Patch sizes A 64/8, B 57/6, C 10/4 | Correct if blank added lines are not counted (`grep '^+[^+]'`). Counting every added line the true figures are A 71/9 (bs_check 51), B 61/6, C 11/4. Per-file: A bs_check 44, bs_diag 13, parser 5, lexer 1, bsc 1 = 64 non-blank. |
| 8 `using <Module>` over 75 files; 4 in the 46 exemplar files; aoc 3 files, none | Correct. The 8: `Support.Triage`, `Jev`, `Support.Triage` (jev/triage), `Shop.Orders` (25a), `Shop.Collections` (Pipeline), `Shop.Collections.Ints`, `Shop.Collections` (Totals), `Shop` (Billing). The other 18 `using` lines are foreign `using :erlang {` blocks. aoc's three `using` lines are all `:erlang`. |
| 28 example module dirs compile | Correct, but the sweep script excludes `exemplars/` (see correction 2). |
| `bs_check.erl:512-525` `add_module_import/3` | Correct (def at 512, ends 525). `add_import` 498, `add_namespace_import` 527, `qualified_module` 4420, `require_imported` 4428, `imported_types` 1307, `hinted` 441-457, `private_callback` 297, `internal` comments at 188 and 4928: all correct. |
| Seven visibility reads | Correct: bs_check 299, 365, 376, 479; bs_emit 141; bs_api 152, 158 (and bs_emit 35 reads the same via `is_public`). |
| `bs_diag.erl:1349-1353`, `LANGUAGE.md:364-366`, `22:91-93`, `22:434-435`, `24:402`, `40:438`, `24:219` | Correct. |
| `erl_lint.erl` 357-358, 1087-1088, 1199; `xref_base.erl` 402-403, 428-429 | Correct. |
| `bs_parser.yrl` still 6 shift/reduce with `friend` rule | Confirmed (base 6, A 6). |
| `friend` collides with an existing identifier in the corpus | No: zero `.bs` files outside the artifact use the word. |
| Four doors | Confirmed, see section 4. |

## 3. Headline refutations, independently re-tested

(a) **Gleam 1.19.1 does not enforce `@internal` / `internal_modules` at compile time. CONFIRMED.** I built `lib2` and `app2` from scratch (path dependency, no stdlib): `lib2` has `@internal pub fn hidden_fn`, `@internal pub type Secret`, and `lib2/internal/vault`. `app2` imports `lib2/internal/vault`, builds `lib2.Secret(3)`, calls `lib2.hidden_fn()`. `gleam build` exit 0 and `app2:main()` returns `1044` (3 + 41 + 1000, so all three were reached). Control: calling `lib2.nonexistent()` fails with "does not have a `nonexistent` value". `gleam export package-interface` lists only `open` (hidden, not forbidden), as the brief says.

(b) **Elixir `defp` from another module is a warning plus run-time error. CONFIRMED.** `Aa.priv/1` is `defp`; `Bb.go` calls `Aa.priv(n)`. `elixirc` exit 0 with `warning: Aa.priv/1 is undefined or private`; running gives `function Aa.priv/1 is undefined or private`. (Note: a top-level call during compile makes `elixirc` itself fail, but that is a compile-time evaluation, not a static refusal; the brief's probe avoids that.)

(c) **Ticket 24's "helper lands unclassified" is stale. CONFIRMED.** My own module `Acct` has an unmarked `Fee`; `AcctTest` (`using Acct`, calls `Fee(n)`) and `AcctTest2` (calls `Acct.Fee(n)`) are both refused: "calls Fee/1, which Acct declares `private` ... Mark it `public` in Acct". F12 status line: done 2026-08-17; ticket 24 resolved 2026-08-13 and line 219 does say "every function in an aggregate is exported today". The diagnostic's "Mark it `public`" first offer is real.

Also re-confirmed with my own program: variant C refuses another module calling `Init` unqualified (`CT3`) and `Cart.HandleCast` qualified (`CT4`) while `Cart` itself compiles; base accepts both. The wrong message ("declares `private`" for a public callback) is as the brief admits.

## 4. Circularity audit

**Patches change only what the brief says.** I read all three. A: `friend` token and two grammar rules, a `friends` World field, `allowed/3` + `may_name`/`nameable`/`type_gate`, a `denied` map consulted in `require_imported`, one resolver clause, two diagnostics. B: the same plumbing with `allowed/3` computed from the module name; no lexer/parser/bsc change. C: a `callback_keys/1` helper applied in `add_module_import`, `qual_table`, `private_table`. Nothing hard-codes a test module name or fixture. Guards are `strict`-mode only, as stated.

**Negative controls are real.** Each variant refuses the unlisted caller and passes the listed one; the unmodified compiler accepts the unlisted caller on the same sources (fixture with `Friends.bs` removed, so base does not just trip over the unknown `friend` keyword). I checked the listed-caller "clean" is a real compile, not a silent skip: `Shop/Reports` under A exits 0, runs (`Report 5` -> `105`) and writes the beams; the refused one exits 1. I rebuilt every compiler from the patches into new directories and `code:which(bs_check)` points at my A build, so no stale ebin.

**My own programs (not the author's), variant A, against base:**

| Program | A | base |
|---|---|---|
| D1 `using Shop.Orders`, call `Secret` | refused | clean |
| D2 `using Shop`, `Orders.Secret` (namespace door) | refused | clean |
| D3 type position `Shop.Orders.Thing` via `using Shop.Reports` | refused | clean |
| D6 qualified alias type `Shop.Orders.Alias` in a return type | refused | clean |
| E1 `type Mine = Shop.Orders.Thing` declaration | refused | clean |
| E2 record field typed `Shop.Orders.Thing` | refused | clean |
| E3 `list<Shop.Orders.Thing>`, E5 tuple member, E6 `fn(Thing)->int` | refused (each) | clean |
| D4 value of type `Thing` flowing out of `Shop.Reports.Mk`, reading `.Id` | clean | clean |
| D7 `Shop.Orders.Secret` with no `using` | "never imported" | same |
| `friend Shop.Admin.*`: `Shop.Admin.Tools` and `Shop.Admin` pass, `Shop.AdminX` refused | as stated | n/a |

Variant B, my own tree (`Shop.Orders.Internal.Pricing` with a record): `Shop.Orders.Total` (descendant) clean, `Shop.Reports` (reaches it only through Total) clean, a stranger `X1` refused, type position `X2` refused, namespace-style `Internal.Pricing.Calc` via `using Shop.Orders` refused; base accepts all.

**Unlisted door: record constructor and pattern naming a denied record.** The brief flags these as unprobed. In this grammar a qualified record construction (`Shop.Orders.Thing { Id = n }`, `Orders.Thing { ... }`) and a qualified type in a clause-head pattern are *syntax errors in both base and A* (`syntax error before: '{'` / `'.'`), so there is no such position to leave open: an unqualified record name enters only via `using`, which is door 1 or the namespace tier. A value of the denied type can still flow through a listed module (D4), which is the same hole every visibility system has and is outside "who may name it". Not tested: `implements` / protocol declarations, `behaviour <Module>`, the `ibs` REPL (lenient mode skips every check by design). I found no fifth door in the positions I could write.

**Circular or manufactured probes: none found.** Two points of weaker evidence, not circularity:
- `e_micro.erl` times *copies* of the predicates, not the patched compiler, and the copies match the patches. Fine for what it measures; it does not measure `type_gate` running over all of `World` (section 5).
- The "demand in corpus" count is a grep of `using` lines. It supports "no demand" only weakly; the brief says as much in section 7.

## 5. Cost measurements: meaningful?

The brief's conclusion ("inside the machine's noise") is right; the individual numbers are not reproducible. I re-ran `e_cost.sh` (8 interleaved rounds x 10, fresh VM per build per round, n=80 per build): base median 12920, A 11558, B 11978, C 11587 us; cold 268/266/284/282 ms. The brief's run had A at +18% and C at +13% over base; mine has A and C 10% *below* base. A sign flip between two identical protocols is the proof that the timing is noise. The floors (min, p10) agree across builds in both runs. So: the warm and cold numbers support only "no measurable difference at this resolution", and the brief's table should not be quoted as an effect.

Two things the cost section underweights:
1. The workload (`examples/Shop/Reports`) declares no `friend` and has no `Internal` segment, so A runs only its empty-list fast path and B never refuses. It cannot show the cost of a refusal, which is a one-off anyway.
2. "A module with ten `using` lines pays at most ~10 us" is the wrong scaling. `type_gate/3` runs once per module in `World` for every file's `imported_types`, so the cost is O(modules in the build), not O(usings). At the micro figures that is about 12 ns x W for A and about 370 ns x W for B (30x). For W = 100 that is ~37 us for B per compiled module; for W = 1000, ~0.4 ms against a ~12 ms compile (about 3%). Still small, and the brief does list "a large `World`" as unmeasured, but the headline "under 0.1%" is for the usings only and B's whole-World scan is the larger term.

## 6. Corrections for the orchestrator (brief.md untouched)

1. Section 4 table / patch sizes: the line counts exclude blank added lines. Say "non-blank" or give A 71/9, B 61/6, C 11/4.
2. Section 4 "Regression sweep": the 28 directories exclude `compiler/examples/exemplars/` (46 files, 4 of the 8 cross-module `using` lines, including `25a` which uses `Shop.Orders`). Add "(exemplars not swept)". The sweep also contains no `friend` or `Internal` module, so it proves only "no regression where the rule is inactive" (and that `friend` as a new keyword collides with nothing: zero other `.bs` uses of the word).
3. Section 4 cost: cite that a repeat of the interleaved run flipped the sign of the A and C differences, and replace "ten usings pays at most ~10 us ... under 0.1%" with the O(World) scaling above (B ~370 ns per module in `World` per file).
4. Section 0 item 1 / section 5: the `Ty` finding (a module in the dependency closure can be named in type position without its own `using`) is *specified* behaviour: `LANGUAGE.md` ~line 162 says the qualified spelling is "legal wherever the module is reachable through a `using` line". Say so, so David does not read it as a checker bug.
5. Sections 5/7 "constructor and pattern positions ... not probed": they are not writable. Qualified record construction and qualified types in patterns are syntax errors in base and A. Replace "not probed" with that measured fact (keep `implements`, `behaviour <Module>` and the REPL as unprobed).
6. Claim 10 (C# `internal` assembly-scoped) is honestly marked as carried; no change.
7. Minor: the brief's section 0 item 4(a) and Option 0 both treat C's message as a gap ("Mark it `public`" is false for a callback). Confirmed; the number of lines to fix (~8) is an estimate, not measured.

Nothing was committed; nothing outside `$S/verify60/` and this file was written. (A stray `/dev/null.erl` that my yecc conflict check created was removed.)
