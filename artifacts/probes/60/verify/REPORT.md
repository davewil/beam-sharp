# Independent verification: brief 60 (which modules may name this one)

Environment: OTP 27 (/tmp/tools/otp27), Gleam 1.18.1, Go 1.24, repo HEAD a0199d6 (brief says HEAD 0dddf8b; the only later commit is the brief itself, compiler identical).
Patched build and baseline built by me from `git archive HEAD compiler`; patch applied cleanly (`patch -p1 -d compiler`).

## Per-claim verdicts
| Claim | Verdict |
|---|---|
| Gleam consumer importing an `internal_modules` module compiles, exit 0, no warning (p1, p2) | REPRODUCED |
| Setting only changes `export package-interface` (['lib'] vs ['lib','lib/hidden']) | REPRODUCED |
| `@internal` on a function: consumer compiles | REPRODUCED. Also tested `@internal` on a TYPE (consumer imports `T` and constructs it): compiles exit 0. |
| "docs/interface filter only" | REPRODUCED. `gleam docs build` omits the `internal_modules` module page, and omits `@internal` type and function from lib/other.html (only `open` listed); package-interface likewise. `gleam publish --dry-run` does not exist in 1.18.1 (`unexpected argument`), so publish itself is NOT CHECKABLE. Suggest wording "hidden from package-interface and generated docs" |
| Elixir `@moduledoc false` caller compiles silently; Erlang export-only (p1 b, c) | REPRODUCED (Elixir 1.14 / OTP25 here) |
| Go `internal/`: parent and descendant build, unrelated fails with `use of internal package ... not allowed`, exit 1 (p3) | REPRODUCED. Extra cases: cousin `shop/billing/x` refused; `shop/pricingv2` (string-prefix sibling) refused; deep descendant `shop/pricing/a/b` allowed |
| Elm `exposed-modules` | NOT CHECKABLE (offline) |
| Prototype table, 4 importers, HEAD control vs patched (p4) | REPRODUCED exactly (Pricing, Sub ok; Reports refused with the quoted sentence; Vians refused with `Rates is called but never imported`; HEAD compiles all four; `Charge :standard 2` = 200) |
| Patch size "2 files, +31 -2" | not recounted by me beyond reading; patch is 2 files and plausible |
| Namespace-form diagnostic is the misleading "never imported" sentence | REPRODUCED (Vians; also deeper form `using Shop` + `Pricing.Internal.Rates.Rate(..)` gives `Pricing.Internal.Rates is called but never imported`) |
| `bs_check.erl:490` add_import/7, `:504` add_module_import/3 at HEAD | REPRODUCED |
| `rebar3 eunit` note / "4 baseline failures" | See below. The brief's Verification section still says "appended below" and has no result: nothing is appended |
| "O(path segments) per using", compile-time cost not measured | NOT CHECKABLE (author says unmeasured; fine) |

## eunit (my own runs, separate scratch dirs, run concurrently)
- Patched: 4 failed / 1299 passed: body_check_tests:every_aoc_program_still_compiles, cli_tests:batch_runs_every_entry_in_one_vm_and_attributes_each, diagnostic_json_tests:a_path_is_utf8_on_the_wire, non_numeric_operand_tests:a_non_ascii_literal_is_advised_as_written. `every_example_still_compiles` passes.
- Unpatched baseline: those same 4 plus diagnostic_term_tests:the_diagnostics_gate_passes_test = 5 failed / 1298 passed. That fifth is a harness artefact, not a patch effect: check-diagnostics.sh needs a built `_build/default/bin/bsc` and I had not run `rebar3 escriptize` in the baseline dir (my patched dir had). So the patch adds NO failure. The 4 common failures reproduce the author's number (environmental: aoc inputs / utf8 locale, not investigated).

## Circularity and blind spots (3+ new importer cases of my own; patched vs HEAD control)
All verified by running both bsc builds.
1. `Shop.PricingV2` importing `Shop.Pricing.Internal.Rates`: patched refuses (segment-wise prefix, correct); HEAD compiles. Handled right.
2. Module `Shop.Pricing.Internal` itself importing Rates: allowed (correct, under Shop.Pricing).
3. Two Internal segments, `Shop.Internal.Pricing.Internal.Rates`: `Shop.Internal.Pricing.A` allowed; `Shop.Internal.Foo` and `Shop.Other` refused. Matches Go's "last internal element" rule. Correct.
4. `Shop.Other2` using `Shop.Internal.Pricing` (a module whose own path has `Internal` at segment 2): allowed from anywhere under Shop. Correct under the rule but shows the rule reserves `Internal` anywhere in a path, not only as a leaf directory; a leading `Internal` segment (index 1) is ignored by the `seq(2..)` search (silently exempt). Edge to note under ticket 65.
5. Qualified call with no using (`Shop.Pricing.Internal.Rates.Rate(x)`): refused by the existing "never imported" rule, patched or not. Not a bypass.
6. Foreign route `using :'Shop.Pricing.Internal.Rates'`: the lexer rejects a quoted atom (`illegal characters "'"`), so it cannot be expressed; NOT CHECKABLE. Foreign `using :mod` is a raw BEAM-module call outside add_import by construction; the brief should state that it is outside this rule (same as Elixir/Erlang row).
7. Transitive: `Shop.Dep` using the illegal importer `Shop.Reports`: error is reported against Reports.bs:3:1 (right file/line), because exports are computed leniently via import_env. Handled right. Note `internal_ok` raises via erlang:error even in `lenient` mode (polys_of/types_of/implements_of), which is why this surfaces; worth a sentence, not wrong.
8. HEAD (control) accepts every case above that the patch refuses, so the refusals are attributable to the patch. The probes are not circular: the control flips the outcome, and the allowed cases (parent, descendant) pass in both.
Prototype handles wrongly: nothing found in refusal logic. Only weakness: the dedicated message for namespace imports is absent (children silently filtered), as the brief already says.

## Corrections needed
1. Verification section: replace "appended below" with the actual result: patched 4 failures = baseline's same 4; no new failure. Also the "rebar3 eunit on this patch: see the appended note" line is dangling.
2. Gleam row: say hidden from package-interface AND generated docs (docs build verified; also for `@internal` type/function); `gleam publish --dry-run` does not exist in 1.18.1 so publish is unchecked. Add `@internal` on a type as measured.
3. Go row could add: cousin and string-prefix sibling are also refused (measured).
4. Add the foreign-`using` caveat and the "Internal reserved at any non-leading depth; leading segment ignored" note.
5. HEAD hash: brief says 0dddf8b; the repo HEAD is a0199d6 (brief-only commit atop 0dddf8b). Harmless.
