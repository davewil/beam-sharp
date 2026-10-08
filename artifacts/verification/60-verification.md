# Verification of the ticket 60 brief (ENG-242)

Verifier: independent rebuild in /tmp/verify60/ (stock, A, B, C), every probe re-run against those builds. Nothing in compiler/, wayfinder/, the brief or the probes was edited. No commit, no Linear.
Environment as in BUILD-NOTE.md (OTP 25, Elixir 1.14, lexer shim). Go 1.24.7 IS installed (/usr/local/go).

## Verdict: PASS WITH CORRECTIONS

The brief's evidence reproduces and its recommendation (defer) is supported by grounds 1 and 2. Four numerical or provenance claims are wrong or unsupported (B cost "2%", corpus denominators, p6 .out truncated, "diff against compiler/src"), and the caller-declared-direction dismissal is argued more strongly than the argument allows. None flips the recommendation.

## Reproduced

| # | Claim | Result |
|---|---|---|
| 1 | stock/A/B/C build; sizes A "27 added, 2 changed, 2 files", B "53/13/6", C "31/3/5" | TRUE. Unified diffs count +27/-2, +53/-13, +31/-3; files 2, 6, 5. Parser conflicts "6 shift/reduce" for stock, A, B, C. BUT see Mismatch 4 on how the diffs apply. |
| 2 | p1 (current private/unmarked/qualified/no-using) | .out identical (columns normalised) |
| 3 | p2 foreign + `:erlang.apply` with no `using` prints 6; private gives `error:undef` | identical |
| 4 | p3 bypass (controls refused, fun handout 7, beam exports, apply Priv undef) | identical |
| 5 | p4 option A (unpatched accepts all four; patched refuses Billing_bad; ns branch misleading error; run = 11, 11) | identical |
| 6 | p5 option B (Orders/Tests/Billing_pub accepted, unq/qual refused, Billing_fun accepted -> 10, 10, beam exports Recompute, apply -> 10) | identical |
| 7 | p6 option C | content true, but the committed p6_optC.out is TRUNCATED (Mismatch 3) |
| 8 | p11 F15.11: compiling Acme/Orders emits two beams, each exporting only its own functions | identical |
| 9 | p12: B record Order nameable from a module whose only function is internal; A refuses whole module incl. record | identical |
| 10 | (a) bs_check.erl:511 `add_module_import/3`, :497 `add_import/7`, :4276 `private_callee`, :4200 `call/6`, :3657 `fname_type`, :554 `private_table`, :358, :476, :297, bs_emit:141, bsc.erl:239, bsc.erl:204-209, bs_api:152,158, polys_of :375 | all correct. 407-425 now holds `qualify_refs` (stale premise confirmed) |
| 11 | (a) 18-boundary-defence.md:439-440 (one entry label); 22:435 and 22:436; 41 s5 line 490 "SUB-MODULE, source-only"; 24 s2 line 219 "every function ... exported today"; F15.11 at F15:105 | all correct |
| 12 | (b) F12 refuses a test module naming an unmarked helper, with control | REPRODUCED in a 3-module tree: `Acme.Orders` (unmarked `RecomputeTotal`, public `Shared`); `Acme.Orders.Tests` -> `T1 calls RecomputeTotal/1, which Acme.Orders declares private` (refused); `Tests3` qualified -> refused; `Tests2` naming public `Shared` -> accepted (empty output). |
| 13 | (c) dynamic reach, executed against each OPTION's own target (author only executed it for B and for private) | `:erlang.apply(:'Acme.Orders.Internal.Pricing', :'Compute', [5])` compiled with the A build, no `using`: runs, prints `10` while static `using` from the same Ext module is refused. Same on C (`Acme.Pricing`) -> `10`, static Billing refused. Same on B (`Acme.Orders`, `Recompute`) -> `10`, static Billing_unq refused. So the Erlang/apply bypass is real for all three, and is a bypass of the new check, not of the old private check. |
| 14 | (d) corpus | script reproduces 138/9/5/1/0 on the working tree, but see Mismatch 2 (denominator is inflated) |
| 15 | (e) s4 Go | Reproduced. Go 1.24.7 is installed; orders and orders/sub build (exit 0), billing fails "use of internal package ... not allowed" (exit 1). Cited `alldocs.go:2742-2745` (the "Internal Directories" text) and `pkg.go:1472` (`func disallowInternal`) are exact. Represented fairly as executed, and the brief says it is outside the requested list. |
| 16 | s1 Erlang/xref, s2 Elixir | reproduced; xref.erl:606 `analysis()` type is right. s3 Elm has no script, only a narrative .out (not re-runnable; Elm cannot fetch packages, labelled UNVERIFIED) |
| 17 | (g) metadata sizes | REPRODUCED: baseline Shop entry {18688, 8996}; B 1/5/20 internals = 72/232/832 heap bytes; C 1/3/10 friends = 16/48/160. Hand-check: 20-key flat map = (3+20)+(1+20)+20*3 = 104 words = 832 B. These are model terms built from the patch's shape, not extracted from a patched compile; adequate. |
| 18 | (f) p9 micro | A 3.5 us / 1.1 us, C 2.0 us / 61 ns, B view 93 us (author 105 us): within noise |
| 19 | (f) p7b in-VM timing, 12 runs x 3 VMs = 36 per cell | table below |
| 20 | reserved words: `internal`/`friend` as tokens, `Internal` path segment | 0 hits (also 0 including comments) |
| 21 | Parser/yecc | 6 shift/reduce in all four builds |

### Timing re-run (ms, in-VM, median / IQR, n=36)

| Config | N=50 | N=200 |
|---|---|---|
| baseline A-shaped | 224 / 52 | 918 / 87 |
| A | 211 / 43 | 926 / 71 |
| baseline B-shaped | 228 / 28 | 982 / 82 |
| B | 246 / 39 | 1044 / 76 |
| baseline C-shaped | 244 / 19 | 957 / 133 |
| C | 208 / 26 | 930 / 101 |

The A-shaped and C-shaped baselines are the identical tree on the identical compiler: they differ by 9% (N=50) and 4% (N=200). C is faster than its baseline at both sizes (-15%, -3%). Author's finding "not resolvable, noise floor about 10%" HOLDS and my numbers have the same character. My B is +8% / +6% over its baseline where the author's was -2% / -3%: the sign flipped between campaigns, so no precision beyond the noise floor is supportable. The brief does not claim any, except for B's "2%" (next section). I did not re-run the whole-process p7 (15-run blocks); the brief's p7 statements rest on the author's .out.

## Mismatches (brief or .out versus re-run)

1. **B's checker cost "about 21 ms, roughly 2% of a ~1.1 s build" is wrong by about 5x.** The brief says `view/2` runs "once per compiled module in the prototype". Counting calls with `erlang:trace_pattern({bs_check,view,2}, true, [local, call_count])` on the B build compiling a 200-module tree: `view/2 calls: {call_count,1000}`, `import_env/4 calls: {call_count,1000}`. `import_env` is called from bs_check.erl:325, :370, :383 and :1571 (check, exports_of, polys_of, and one more), so view runs 5 times per module. 1000 x ~100 us = ~100 ms, about 8-10% of the 1.0-1.3 s build, i.e. at the noise floor, not under it. p9 also (i) benchmarks a copy of `view/2` that omits the `private => maps:merge(...)` work present in optB.diff, although the brief says "copied verbatim", and (ii) uses 200 tiny synthetic entries (2 exports each) rather than real ones. The qualitative conclusion "not a differentiator" survives only because the whole measurement is noise-limited, which the brief says; the "2%" figure does not survive and p9 does not support it.
2. **Corpus denominators are inflated.** `find . -name '*.bs'` = 424, but 210 of those are under `compiler/_build/test/bsc_eunit/run-*/` (gitignored eunit scratch, created 2026-10-08 23:26 by this session's own test runs). Tracked: 214 files; `p10` on a `git ls-files` export gives `modules: 132; dotted: 9; edges: 5; importers all inside own subtree: 1 of 4 (Shop <- Shop.Billing); Internal segments: []`. So "138 modules" -> 132 and "0 of 424 files" -> 0 of 214. Edges, dotted count and the own-subtree finding are unchanged. Also the script counts only `using` of exact known modules: the corpus has 8 non-foreign `using` lines (5 to known modules, 2 namespace imports `Shop.Collections`, 1 `Shop.Orders` naming nothing in the corpus). "5 cross-module using edges in total" is true only for module-to-module edges.
3. **p6_optC.out is truncated** at `Acme/Billing           REFUSED` (14 lines). The brief quotes from it: Reports refused, the Reports-accepted-after-`friend Acme.Reports` step, and the `Acme.Ordres` typo. The re-run produces exactly those lines (Reports REFUSED with "names its friends: Acme.Orders"; after adding the friend Reports accepted and Billing refused; typo message "Acme.Ordres, Acme.Reports", Reports still accepted because the earlier friend line remained), so the facts are true but the cited artefact does not contain them.
4. **"Their diffs against compiler/src ... applies cleanly" is not literally true.** (i) `build-bsc.sh` takes only the first `---` filename and feeds the whole multi-file diff to it: A, B and C each fail with `2 out of 2 hunks FAILED -- saving rejects to file bs_check.erl.rej` / `1 out of 1 hunk FAILED`. The author's /tmp/bsb_60_* must have been produced another way. (ii) optB.diff and optC.diff's `bs_lexer.xrl` hunk is against `/tmp/bsbuild/bs_lexer.xrl`, the SHIMMED lexer (`{TokenLine,1}`), not `compiler/src/bs_lexer.xrl` (`TokenLoc`); it cannot apply to compiler/src. I applied the other files per file onto a copy of compiler/src (clean, no fuzz reported) and the lexer hunk after the shim. The size claims are therefore true, with "6 files" (B) and "5 files" (C) each including that lexer file; the real lexer delta is a single line.
5. **Elixir "run-time UndefinedFunctionError"** is not in s2_elixir.out (ctl.ex is compiled, never run). I ran it: `UndefinedFunctionError`. True, unrecorded.
6. `0b761f6` (the commit the ticket measured at) is not in this clone (59 commits), so "drifted from 407-425" can only be checked at HEAD, where those lines hold `qualify_refs`. Consistent, not provable as of 0b761f6.

## Circularity flags

- **p9 benchmarks the check bodies, not the compiler.** For A and C the copies match the diffs verbatim (checked) and the figures are credible. For B it is not verbatim (see Mismatch 1) and omits the call multiplicity. It cannot support a percentage of build time.
- **`lib60.sh` has no vacuity guard.** `run()` in p4/p5/p6 treats any non-empty output as REFUSED and empty as accepted. `lib.sh` `probe()` got a guard ("verifier finding 2026-10-08"); lib60 did not. A missing build would print an erl error and read as REFUSED. The committed .out files do show genuine `error:` diagnostics under each REFUSED, and my re-run confirms each, so no result here is vacuous; but p1, p3 and p2 have no machine verdict at all (human reads `head -3`).
- **Controls exist** for every refusal: p4 (unpatched accepts the same tree; Billing_ok and Orders/Sub accepted), p5 (Billing_pub and Tests accepted), p6 (unpatched control with the friend line removed, all four accepted), p3 (direct and value-position controls).
- **Patches do not make probes tautological**: the diagnostics are new tags that exist only in the patched build, and the unpatched builds accept the same trees.
- **Expectations were not machine-checked**, so adjusted expectations cannot be ruled out from the scripts; I found none that mismatch behaviour.
- **"Corpus shows no demand" is partly circular**: the corpus was written when no way to express "who may name this" existed, and has one multi-module aggregate (Shop). Absence of use is weak evidence against a feature that could not have been used. The brief's "what would change this" partially acknowledges it.
- **"Bypass" of the fun-handout kind is not a circumvention**: in p3 and p5 the callee's own public function (`Handout`) deliberately returns the protected function, an owner-written grant. It bypasses no checker rule. For A and C the handout was never executed (and under A a handout from Acme.Orders is also allowed by the rule). The genuine bypass is the dynamic route, which I executed for all three (row 13); the author executed it only for B and for private.

## Citation errors / mis-citations

- Brief "Sub-decision 4": "CLAUDE.md puts that outside the language ('a gate guards the language or the handoff')". That CLAUDE.md sentence is about gates over the tracking layer (tickets, index, glossary), written after the tracking layer generated its own commits. It says nothing about layering rules in project configuration. Misapplied.
- Brief "What would change this": "second occurrence test CLAUDE.md applies to new checks". CLAUDE.md applies it to new checks on tickets, the glossary or the checks themselves, not to language features. An analogy, presented as a rule.
- Brief Gleam note: "the repo has no source I can cite". `wayfinder/research/48-map-type-prior-art.md:194` discusses Gleam's `opaque`, and research 74 and 09 show `pub fn`/`pub type`. These concern type opacity, not module-internal visibility, so the conclusion stands; the grep as worded ("Gleam-with-visibility returns no hit") is inaccurate.
- All other file:line citations opened and correct (list in rows 10-11, 15, 16).
- Gleam and Elm: every statement is labelled UNVERIFIED-NOT-EXECUTED; I found no unlabelled assertion about either.

## Overstatements

1. "Checker cost ... B about 2%" (Mismatch 1).
2. "424 .bs files" / "138 modules" (Mismatch 2).
3. "Every number and diagnostic below comes from a *.out" is false for p6 and for the Elixir runtime error.
4. "These apply to all three options" (bypass) is stated with p3/p5 evidence, which covers private and B only; true, but it needed the A/C dynamic runs I added.
5. "Caller-declared direction needs no prototype (argued only)": the argument is "a restriction declared by the caller restrains only the party that writes it". The same holds for every callee-side option in the agent-drift scenario the ticket names: an agent that edits the caller can equally edit the callee's `friend` list, move a file out of `Internal/`, or change `private` to `public` (the brief itself notes C requires editing the callee for each new caller). The distinction that survives is ownership and review of the declaring file, not a technical protection. A caller-declared form (a closed `using` list or a subtree layering rule, "Acme.Domain may not `using` Acme.Infra") would protect an architectural direction, which is what ticket 60 item 2 says is "closer to what `using` already does". p2 even shows `using` is already an enforced dependency list ("B is called but never imported"). So the dismissal is under-argued, and it is the one sub-decision the brief closes by assertion. Not prototyped, and it is cheap (one check at the same `add_import` site).
6. **Is "defer" supported or convenient?** Grounds 1 (private-by-default already closes the test-targets-helper drift, reproduced with a control) and 2 (5 module-to-module edges, 1 inside its own subtree, no Internal) are real and sufficient. Ground 3 ("no option is a boundary") is weak: the existing `private` check is the same kind of lint (ticket 22 accepts that explicitly), so it argues against the feature class, not against deferral in particular. Deferral also coincides with the ticket's own "Not owed a decision soon". The brief does state what would un-defer it. Missing from that statement: what would make the caller-declared direction worth building, and that a corpus written before the feature existed under-measures demand.

## Files

- Report: /home/user/beam-sharp/artifacts/verification/60-verification.md
- Scratch (re-runnable): /tmp/verify60/ (stock, A, B, C builds; probes copy with paths rewritten; byp.sh, f12.sh, cnt.erl added by the verifier; my_*.out)
