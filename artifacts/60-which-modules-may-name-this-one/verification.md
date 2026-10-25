# Verification of the ticket-60 brief (independent re-run)

Scratch: scratchpad/verify60/ (probes copied, paths rewritten, fresh prototype built from a fresh copy of
bsc-build/src + within-only.patch; patch applies cleanly, 49 changed lines, yecc 6 shift/reduce both before and after).
compiler/src was identical to bsc-build/src when I started. Repo HEAD has since moved from 1429fdc to ad33427; the cited line numbers (bs_check 495/509) are unchanged.

## 1. Re-run results
| Probe | Result |
|---|---|
| p1, p8, p9 (all 5 cases + run 70 + both controls + --api), p9b, elm, xref (both prefixes), ex | REPRODUCED byte-identical |
| p11 | REPRODUCED, except the stored last line "p11 beams: ..." is NOT produced by p11.sh (hand-appended). I re-ran by hand with the patched compiler: Shop.Orders.beam + Shop.Orders.Internal.beam are emitted, so claim holds, but no script backs it. |
| export | REPRODUCED structurally; absolute sizes 888/896/888 vs stored 840/848/840 (path-dependent), same pattern (friend +8, one == all) |
| gleam | REPRODUCED (only "Compiled in" timings differ). I also did a clean build (rm build dirs) with --warnings-as-errors: exit 0. Control: importing a nonexistent module does fail (exit 1). |
| runtime_guard | REPRODUCED in range (plain 27-51 ns, guarded 427-506 ns) |
| micro | REPRODUCED (95-116 ns/edge) |
| cost | REPRODUCED qualitatively; medians 871/827/726/923 vs 822/838/760/838. Spread +-100 ms; the "within" arm was fastest twice, so order/drift effects exceed any signal |
| p0 | REPRODUCED by grep (add_import :495, add_module_import :509, no friend/sealed/visible_to) |

## 2. Circularity review
No probe is circular in the sense of manufacturing its result. Details:
* **Prototype refusal is by the rule, not the name.** Extra controls I ran: patched compiler with the `within` line deleted accepts Orders2 and Via; the same Orders2 body renamed Shop.Zed is admitted, renamed Zed.Q / Shopx.Q / Shop2 is refused; with `within Shop.Reports`, Shop.ReportsX and Shop.Report refused, Shop.Reports and Shop.Reports.Sub admitted (segment-aware); multiple `within` lines are OR'd. The brief's own control used the HEAD compiler (a different binary) rather than the patched one minus the line; my patched-minus-line run agrees.
* **Weak/tautological: p9b "B2 exit 0".** A caller-declared rule is unfenced when omitted by definition; this illustrates the argument, it does not measure anything.
* **Weak: cost.sh has no positive control and cannot see small effects.** I added one: a deliberately slow check (+2000 loop iterations per edge, about +23 ms/tree) was NOT detected (medians 753/801 vs real-check 844/778); +10000 iterations (about +115 ms) WAS detected (966/957). So the harness resolves roughly >=100 ms (>=12%). "Below measurement" is true but the macro run supports only "no regression above ~100 ms". The real support for "negligible" is micro.escript, which is a re-implementation of namable/4 inside an escript (not the compiler's code, run interpreted/compiled in a loop), so it is an estimate. Positive controls I also ran: the slow check changes compile time in proportion to edges, so visible_or_refuse runs about once per edge in the cost tree; a `within Gen.Zzz` variant of the cost tree is refused, so the "every module within Gen" arm exercises the check.
* **Gleam exit-0 claims are sound.** client is a separate package (path dep), app sets internal_modules matching shop/internal/tax, and the docs control proves the pattern is recognised (recompute_tax and helper hidden, gross shown). Nothing printed between "Compiling client" and "Compiled" (tail -5 was exactly full, so no truncated warning). Caveat: the control proves the pattern is live for docs, not that an import-refusal exists elsewhere; the negative is established by exit 0 alone, which I reproduced cleanly.
* p8 (grammar refuses uident foreign sig, lowercase callback bypass) is fine: Counter compiled and ran {ok,50}.
* No hard-coded or grepped-to-success outputs found; stored outputs are full raw output.

## 3. Citations (sampled 20)
Confirmed: bs_check.erl:495 add_import/7, :509 add_module_import/3, :486 import_env, :524 add_namespace_import, :464 reachable (brief says ~466), F12 readers :296 (=/=), :362, :373, :476, bs_emit.erl:140, bs_api.erl:152 and :158, bs_diag.erl:1358, bsc.erl build/4 (World1 at :227), types_world :286 (brief says :293, inside it), bs_check :2463 vis_source, :3850 and :4391 private_callee, signature greps 21/2/5, ticket 41 lines 497-499 (coexist claim), ticket 24 section 2 text, F12 done 2026-08-17 / ticket 24 resolved 2026-08-13, ticket 60 line 19 (:407-425), 18 line 439, 22 line 128, OTP code_server.erl:23, application_controller.erl:23, xref.erl:106-121, 91 -moduledoc false modules, 8 using edges in 6 of 75 files.
Problems:
* **"ticket 06 already accepts this for `private`"**: ticket 06 contains no text about private or Erlang bypass (only "an Erlang caller sees a normal module"). Also `private` is unexported, so Erlang cannot bypass it; `within` is exported, so it can. The analogy is wrong or at least uncited.
* bs_check :3850/:4391 private_callee sits on the `undefined` (callee not found) path, not the success path; the brief's "check sits at the call site ... on the success path" would be a new site, not the existing one.
* bs_check :1522 also constructs a signature with literal `public` (producer, not a reader); the reader list is otherwise complete.

## 4. Stated as measured but not backed by a script/probe
* "Parent and child directory build as two beams" (p11): no script line; I re-measured by hand, true.
* "Tail call erases the caller frame": no probe; I confirmed with a 5-line test (callee frame absent from the stacktrace).
* "~0.014% of a compile": arithmetic from a replica microbench, not a measurement of the compiler.
* Option C's "~100 ns per resolved call, extrapolated": labelled as extrapolated, fine.
* "49 patched lines ... a few hours of checker work": line count verified (49); the time estimate is judgement.
* Prototype was not run against the repo test suite; the new keywords `within`/`only` reserve identifiers. grep finds them only in comments across examples/ and test/, but no compile of the corpus under the patched compiler was done (so keyword-reservation cost is unmeasured).
* The prototype's `lenient` skip means `--api` on a consumer of a restricted module succeeds (I confirmed); stated in the brief.
* I built the prototype lexer without `{error_location,column}` (rebar xrl_opts); irrelevant to every probe.
