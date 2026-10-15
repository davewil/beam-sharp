# Verification of brief 60 (which modules may name this one)

Verifier run, 2026-10-15. Reruns were done from a private copy of the probes in a mktemp dir (so no .beam/.abstr or .out in
the shared tree). Saved outputs were compared after normalising /tmp paths. Extra probes and their outputs are in
`artifacts/verify/60/`.

## 1. Probe table

| Probe | Verdict | Notes |
|---|---|---|
| site | REPRODUCED | Only diff is the `HEAD:` sha (8b09c30 vs 523ad14; compiler untouched since 0f4859a). `0b761f6` still absent, arity 3, 512-525. |
| beam | REPRODUCED | Identical. Behaviour chunks IDENTICAL 5/5, control DIFFERENT. |
| proto | REPRODUCED | Identical. All `[head]` rows exit 0; patched refusals exactly where the brief says. |
| timing | REPRODUCED (direction), noisy | See below. |
| check_micro | REPRODUCED (direction) | Mine: nameable 3073/3102 ns, control 1742/1939 ns, diff ~1.2 us (brief 1.9 us). Far under the 10 us threshold. |
| go | REPRODUCED | Identical. |
| gleam | REPRODUCED | Identical except "Compiled in" times. |
| elm | REPRODUCED | Identical. |
| elixir | REPRODUCED | Identical. |
| erlang | REPRODUCED | Identical. |
| unclassified | REPRODUCED | Identical. |

All 11 ran and exited 0.

Timing, n=15 interleaved, load average ~18 (other agents active), wall ms min/median:
- A (5 modules): stock 388/590, stock again 406/606, patched 408/584.
- B (41 modules, 121 edges): stock 497/642, stock again 485/611, patched 511/578.

The stock-vs-stock spread is as large as or larger than the stock-vs-patched gap, and patched is not slower at the median. The
brief's "no detectable compile-time cost" reproduces. These numbers say only "not detectable here"; they do not bound the
cost tightly. The micro-benchmark is the better bound.

## 2. Circularity review

- **proto / patch (option A):** NOT circular. It has a stock control, and I rebuilt stock from the same source myself (E7) so the
  prebuilt `$BSC` is not a confound. Stock and prebuilt agree. The patched refusals come from a real check, not a hard-coded
  string. The "ok" and "namespace_ok" controls are green under both compilers. Caveat: the `namespace_import` variant contains
  both a legitimate and an offending function in one module, so it is red by design; the brief says so.
- **Patch line count: slightly wrong.** The brief says "+32 / -2 lines". `60_proto.sh` counts `grep -c '^+[^+]'`, which skips
  blank added lines. The patch adds 35 lines (32 non-blank, 3 blank) and removes 2. I diffed stock vs patched `compiler/src`
  directly (verify60.out): 2 files, `bs_check.erl` and `bs_diag.erl`. What it changes: `add_import` calls the new
  `may_name/4` before `add_module_import`; the namespace branch filters `Children` by `nameable/2`; there are new
  `may_name`/`nameable`/`internal_scope` functions; and `bs_diag` gets a `module_not_visible` `built/2` and `message/1`
  clause (9 lines). It applies cleanly to current HEAD. Immaterial to the decision.
- **namespace-import hole on stock HEAD:** CONFIRMED. `using Shop` then `Orders.Internal.RecomputeTotal(...)` in an outsider
  exits 0 on stock. A qualified call with no `using` at all is refused by stock (LANGUAGE.md ~line 156), so the hole needs a
  namespace import.
- **timing:** has a HEAD-vs-HEAD control, so not circular. Weak evidence by nature (noise swamps the effect).
- **check_micro:** control is a no-op fun, and the claim is loose (a 10 us bar). Not circular.
- **beam:** not circular. Control `Priv` -> undef and a DIFFERENT-chunks control are present. Gap: the brief says the
  disassembly shows `Twice -> {call_only,1,{'Guard','Pub',1}}`, but `60_beam.out` does not print that line. I disassembled it
  myself: confirmed (verify60_go_gleam_beam.out), and `Pub` has `is_integer` at its entry label. Whole-file cmp excluded
  because stock is not byte-reproducible; the chunk list compared (Code/AtU8/ExpT/LocT/ImpT/StrT/LitT/FunT) is a fair
  "behaviour" set.
- **unclassified:** mild weakness. The classifier grep filters out all of `bs_diag` and some `bs_api` lines, so a classifier
  there would be hidden. My unfiltered `grep -rniE 'boundary manifest|callbacks:' compiler/src` finds nothing, and the
  `unclassified` hits are only the diagnostic fallback tag (bs_diag 703, bsc 897, bs_api 280). The conclusion stands.
- **gleam:** not circular. The author's expectation was refuted by the run. I reran with unfiltered output (below).
- **elm:** see section 3.
- No probe swallows errors so that failure reads as success; `2>&1 | head -1` rows carry the exit code separately.

## 3. Spot-checks

**Citations** (all opened):
- `bs_check.erl` 498 (`add_import/7`), 500 (call), 503-507 (namespace), 512-525 (`add_module_import/3`), 151 (`behaviours =>`),
  `bsc.erl:240` (`behaviours =>`), `bs_parser.yrl:185` (`using_decl`): all correct.
- `bs_diag.erl:703`, `bsc.erl:897`, `bs_api.erl:280` (`unclassified`): correct. `behaviour` counts 7/3/13: correct.
- `LANGUAGE.md ~187` (index.bs holds shared declarations): correct.
- Erlang: `dets_utils.erl:23`, `escript.erl:404`, `erl_lint.erl:1073`: correct.
- Elixir `apply.ex:952-953`: correct. **Off by one:** `module.ex:318` is the "Accepts a string... or `false`" line; the cited
  "invisible to documentation extraction tools" text is at line 319 (and 188). Cosmetic.
- Stale ticket claims: `0b761f6` is not an object in this repo; ticket 60 says `add_module_import/5` at 407-425; HEAD has /3 at
  512-525. Confirmed. Tickets referencing "ticket 60|ENG-242": only 22 and 60. Confirmed. Ticket 24 s2 text ("every function in
  an aggregate is exported today", `unclassified: RecomputeTotal/1`) matches the brief's quote.
- **Wording flaw:** the brief says "Four of the ticket's measured claims are stale or wrong (Findings 1-3, 6)". Finding 2 is
  CONFIRMED and Finding 3 is an omission in the ticket, not a stale claim. Really 1 stale/wrong, 1 partly (6), 1 omission (3).

**Go:** reproduced. My extra run (below) shows the prototype's nesting semantics differ from Go's.

**Gleam 1.19.2:** rerun with unfiltered output, plus `gleam check`, `gleam run`, and a same-package test-style import. A path-dependency
app importing `libpkg/internal/secret`: `gleam build` exit 0, `gleam check` exit 0, `gleam run` exit 0, no warning text. Within
one package (public module, and a `test/` module): exit 0. So Gleam does not refuse at build. CONFIRMED. (Publish-time check
not testable here.)

**Elm:** reproduced. Could the forged registry cause the result? Unlikely. The setup that fails and the setup that succeeds share
the same forged registry, dependency solve, and installed package. The control importing the exposed `Lib` compiles
(dependency artifacts built), and building the package itself with its internal import succeeds. The only variable is the import
target, so "MODULE NOT FOUND for non-exposed module" comes from Elm's interface handling of `exposed-modules`, not from the
registry. The residual risk is that a real registry would add checks not exercised; the brief already states the forgery.

**BEAM disassembly claim:** confirmed (above).

## 4. My own probes (`artifacts/verify/60/`)

Scripts: `verify60.sh` (stock rebuilt from source and patched, same fixtures through both) and `verify60_go_gleam_beam.sh`.

| ID | Case | Stock | Patched | Meaning |
|---|---|---|---|---|
| E1 | `Billing` (top-level) uses `Common.Internal` | 0 | **refused** | A cannot serve two non-nested top-level modules from a helper in a third top-level prefix. As the brief says. |
| E1b | helper hoisted to root-level `Internal.Fmt`, unrelated `Audit` uses it | 0 | **0 (compiles)** | **Hoisting to the root silently gives no protection.** `internal_scope` needs a non-empty prefix. So for modules with no common ancestor there is no A-compatible home. The brief's "hoist to a shared prefix" is not available when the prefix is empty. |
| E1c | shared helper at common ancestor `App.Internal`; `App.Billing`, `App.Inventory` use it; `Outside` | 0/0/0 | 0/0/**refused** | The plausible layout (shared helper under a common app prefix) works. |
| E2 | `Shop.Orders.Tests` (in tree) vs `Tests.Shop.Orders` (parallel tree) naming `Shop.Orders.Internal` | 0/0 | 0 / **refused** | In-tree test modules pass; a parallel `Tests.*` tree is refused. Relevant to the test-targeting consumer, since there is no test convention in the repo. |
| E3 | `A.Internal.Other` names `A.Internal.B.Internal.C` | 0 | 0 | **Differs from Go**, which refuses it (Go uses the parent of the LAST `internal`; run in the second script, exit 1). The prototype splits at the FIRST. The brief's "exactly the rule the prototype implements" is true only for single `Internal` segments. |
| E4 | `Audit` names `Shop.InternalTools.Internal` | 0 | **0 (compiles)** | **Prototype bug.** `string:split(.., ".Internal", leading)` stops at `.InternalTools`, sees `T` not `.`, returns `none`, and never reaches the real `Internal` segment. A module with an earlier segment that merely starts with "Internal" evades the rule. A fix needs a segment-wise scan. A few lines; does not change the decision but the "32 lines, refuses the right callers and no others" claim is slightly too strong. |
| E5 | `--api` lenient on an outsider | n/a | passes | By design (lenient mode skips). Means the LSP/api path will not show the refusal unless wired separately. |
| E6 | B# test module naming `Orders` and calling the `private` `RecomputeTotal` (stock, no new rule) | **refused** | n/a | `error: T calls RecomputeTotal/2, which Orders declares private`. Option C already covers the 24 s2 RecomputeTotal case. Finding 7 CONFIRMED independently. |
| E7 | prebuilt `$BSC` vs stock built from source | same | n/a | No build-version confound. |

## 5. Bottom line

**YES WITH CORRECTIONS.** The recommendation (Option A, B as upgrade, C as null case) still follows from the evidence. Every
probe reproduced, none is circular, the stock/patched comparison is sound, and the main claims (stock accepts outsiders, the
namespace hole exists, BEAM cannot enforce "who", no emitted-code change, Go/Gleam/Elm/Elixir/Erlang behaviour) hold.

Corrections to make in the brief:
1. Patch size is +35/-2, not +32/-2 (32 non-blank + 3 blank added lines).
2. The prototype has a segment-matching bug (E4: `Shop.InternalTools.Internal.X` is unprotected). Say so or fix it before
   citing "32 lines".
3. Nesting differs from Go (E3): the prototype uses the first `Internal`, Go the last. Soften "exactly the rule Go implements".
4. "Hoist to a shared prefix" does not work at the root: a root-level `Internal` module is silently unprotected (E1b). This
   strengthens the brief's own change-my-mind condition (1) and should be stated as a limit of A.
5. Finding 2 is not a "stale or wrong" ticket claim; Finding 3 is an omission. Rewrite the "four of the ticket's claims" sentence.
6. Cite `module.ex:319`, not 318.
7. Option C is stronger than the brief gives it credit for (E6): within one module, `private` already refuses a B# test
   module, and E2 shows A's parallel-test-tree behaviour, which the brief doesn't mention.
8. The Twice `call_only` disassembly in Finding 5 isn't in `60_beam.out`; add it to the probe.
