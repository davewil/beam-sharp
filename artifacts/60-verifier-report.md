# Verifier report: ticket 60 brief (compiler at 712b9e9)

Scratch: /tmp/claude-0/verify60 (p = probe copy, c = controls, comp = patched compiler copy, t = test src). Brief, probes, compiler/ untouched.

## Overall: PASS WITH CAVEATS

## 1. Re-runs (all via `sh run.sh` in a copy)
| probe | result |
|---|---|
| bsc | REPRODUCED (byte-identical) |
| go | REPRODUCED |
| elixir | REPRODUCED |
| elm | REPRODUCED (same 403/offline output, so still unverified) |
| erlang | REPRODUCED |
| gleam | REPRODUCED except `Compiled in 0.65s` vs `0.52s` (timing only) |
| proto | DIFFERS only in timing: mine 767 ms (1.00 us); saved run.out says 2316 ms (3.03 us) |

Proto caveat: the brief cites "866 ms = 1.13 us" and attributes it to `proto/run.out`. That figure is in `proto/run_proto.out`; the saved `proto/run.out` says 3.03 us. Observed spread over runs is 0.93 to 3.03 us, so "no spread" understates it. Conclusion (microseconds, cheap) is unaffected.

## 2/3. Claims and circularity checks
- **Go `internal` is a subtree rule**: CONFIRMED. billing and other refused; orders and orders/sub build. Negative control: renamed `internal` to `internals`, all packages build (exit 0), so the refusal is caused by the directory name. Source cites ok (see 4).
- **Gleam internal_modules refuses nothing**: CONFIRMED, not circular. Build exits 0 for a dependent that imports the internal module and calls the `@internal` fn. Extra control: with NO internal_modules config, a dependent importing `lib_pkg/internal/helper` also builds, so Gleam 1.19 does not enforce for path deps either way. Caveat A: the probe's docs check (`grep -c` on top-level `*.html`) cannot fail, since module pages live in a subdirectory (`lib_pkg/lib_pkg/util/helper.html` in my control). The docs-hiding claim is still true: with a better check, no `helper*` page exists and `search-data.json` and `package-interface.json` have 0 hits, while a non-internal control module is listed. Caveat B: path dependency only; hex dependencies unprobed (brief says so). Note `lib_pkg/internal` is probably also a default, so the config line may be redundant.
- **F12 refuses a private call from a test module**: CONFIRMED. Probe `Other.Tests` -> `Probe calls Shop.Orders.RecomputeTotal/1, which Shop.Orders declares private`, exit 1. Control: change `private` to `public`, same caller compiles, exit 0. Caller does use `using Shop.Orders`, so the refusal is from F12, not a missing import.
- **`using` required** (finding 5): CONFIRMED (`never imported`, exit 1).
- **Nested Internal module is nameable today** (finding 6): CONFIRMED, prints 8, exit 0. Also confirmed the unmodified compiler accepts my `Other.Thing` and `Shop.OrdersX` programs.
- **"88 modules / 0 pairs refused"**: REPRODUCED but nearly TAUTOLOGICAL. No corpus module has an `Internal` segment, so 0 refused is guaranteed and says only "no existing name collides". Negative control: adding 4 modules (one `Shop.Orders.Internal.Cache`) gives 92 modules, 8370 pairs, 90 refused, so the counter can fail. The brief states "0 such segments" itself, so it is not hidden, but the table's "unaffected" verdict is weaker than it looks. Also: mods.txt is a subset (88) of 113 distinct module names under compiler/wayfinder/aoc/handoff; the 25 left out (Bands, Calls, Day01, ...) have no `Internal` either. Provenance of the 88 is undocumented.
- **Segment-aware prefix trap**: CONFIRMED (`lists:prefix` flat = true; rule refuses `Shop.OrdersX`). Reproduced in the real compiler copy (`Shop.OrdersX` refused).
- **Elixir / Erlang docs-only and xref lists-only**: CONFIRMED by re-run; probes test the stated claims. Elm: unverified, honestly marked.
- **Prototype expectations edited** (two corrected): disclosed in brief and comments; the corrected expectations follow Go's rule, plausible, not a manufactured pass.
- **~25-line cost**: CONFIRMED by an actual implementation. In a /tmp copy I patched `add_import` (call before `add_module_import`, strict mode only), a namespace-children filter, `internal_visible/2`, and a `bs_diag` built/message pair. Added lines: 18 in bs_check.erl plus 5 in bs_diag.erl = 23, in 2 files. It builds (`rebar3 escriptize`), refuses `Other.Thing` and `Shop.OrdersX`, accepts `Shop.Orders` and the Internal module itself, and the unmodified compiler accepts the same programs. The error tag needed no other routing site (`unknown_module` appears only in bs_check and bs_diag). Not done: full test suite, `--api` mode, `using Shop` namespace case, beam bytes.

## 4. file:line citations (all opened)
OK: bs_check.erl 497-507 (add_import), 511-525 (add_module_import), 527-535, 589-596, 370/383/1547 (`lenient`), 204/236/251/270; bs_api.erl:93; bsc.erl:459, 227, 293; bs_parser.yrl:192; bs_diag.erl 358-359, 652-653, 1325, 2029; F15 lines 25-36; Go pkg.go:1472, 1563-1564, 1582-1596; str/path.go:16-28. Ticket's `bs_check.erl:407-425` is stale (60 line 19), as the brief says. `grep F12|private` in ticket 24 is empty, as claimed. Brief says ticket 22 wrote the "not what internal means anywhere else" line; that text is in ticket 60 line 33 (my grep of 22*.md found nothing), so attribute it to 60 at least. Not checked: Elixir module.ex lines, xref.erl, erl_lint.erl:361, editor grammar claims.

## Caveats summary
1. Corpus 0-refused is true by construction (negative control shows it can fail).
2. Timing cited from the wrong file; real spread about 1 to 3 us.
3. Gleam docs assertion in the probe is weak, though the claim holds under a stronger check.
4. Gleam and Elm findings limited to path deps / unverified; the brief says so.
