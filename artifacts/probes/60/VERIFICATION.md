# Independent verification of brief 60 and probes/60

Verifier worked only under `.../scratchpad/verify60/` (fresh copy of probes and of `compiler/src`; author's `out/` untouched). Compiler fingerprint in my copy: `bad8cbb2bfcea1c2`, the same as the author's, so both runs saw identical sources. No git, no edits to the author's files, `compiler/` or `wayfinder/`.

## Overall verdict

**The evidence is sound; the brief is mostly supported. REPRODUCED 16 of 17 probes** (p07 is honestly NOT MEASURED). No probe is manufactured, and every mutation I tried that should break a key claim turned the probe RED. Findings to fix before it goes to David:

1. **Wrong number:** "md5 identical across 31 modules" is a miscount. There are 30 beam files and 27 distinct modules. `wc -l` counted a trailing blank line. The equality itself holds.
2. **A logic gap on Option 2 (B) and Option 3 (A):** a module-level rule refuses every `using` of the module, including a call to its other public functions. Only C was tested for this (`OutsiderPub`). The brief's counterargument for B omits it (see section 4 below).
3. **Weak verdict lines:** p08, p10 (and structurally p09) print CONFIRMED when the tool is missing (shell exit 127). The brief's Go/Java/Rust claims are nonetheless backed by real tool output in `out/`.
4. **Mis-cite:** "ticket 18 section 1" for "one entry label".
5. **Omitted reader:** `bs_api.erl:152,158` is a sixth visibility reader that the brief's "five visibility readers" omits.

## 1. Re-run and diff against the author's out/

I ran `run.sh` from the fresh copy. All 17 probes ran, and every VERDICT line is identical. Diffing all `.out` and `.exit` files, with ms values stripped, gives:

- **Non-timing differences:** only absolute paths (`w60run` vs `verify60/w`) and gleam's "Compiled in 1.08s" vs "0.78s".
- **p12 timing:** differs, as expected.

| p12 timing, 15 interleaved runs | base median | A | B | C | base spread |
|---|---|---|---|---|---|
| author | 2211 | -1.4% | +15.1% | +8.2% | 1894-3160 |
| mine | 2053 | +3.5% | -1.3% | +2.6% | 1688-2684 (about 1000 ms) |

The signs of B and C flip between the author's run and mine. That supports the brief's "noise, not cost" reading. It does not support the table's headline +15.1% / +8.2% as a delta. The brief does say so in the paragraph after the table and in section 7, so it is hedged but still printed as a headline.

p12's own verdict is **low power**. The spread is about 57% of the median, so even a 50% regression would print "CONFIRMED no measurable delta". The label should read "not measurable", not "CONFIRMED".

## 2. Per-probe verdicts and circularity

| Probe | Verdict | Reason |
|---|---|---|
| p01 | REPRODUCED | `Outsider` compiles and runs to `6`; the `using`-less call is refused; `private` is refused; the keyword grep hits only comments at 109, 188, 4861. Mutation M8 (below) confirms the control. |
| p02 | REPRODUCED | Not circular. Minor: the brief says ExpT holds `{Name,Arity,Label}`, but the probe prints only name and arity, not labels. The "Label" part is background knowledge, not shown. |
| p03 | REPRODUCED | The control is refused under each patch, and the bypass returns `6`. Mutation M2 turns it RED. |
| p04 | REPRODUCED, weak verdict | The verdict is only `rc==0`. The warning grep runs on the second, cached `gleam build`, so it is vacuous. The first build's raw output does show no warnings, so the claim holds. Docs list `plain` and `total`, not `recompute` or `marked`. |
| p05 | REPRODUCED | `elixirc` exit 0 with a warning for the `defp` call, as claimed. CHANGELOG dropped the "mix new + xref callers" block because it printed nothing. That is no-data, not contrary data, but the replacement (doc text lists no restriction mode) is weaker evidence. |
| p06 | REPRODUCED | The fixture `sneaky` is built to trigger a documented limitation, so the result is somewhat by design. Quote `xref.erl:40-55` is correct, as is `{module_use..}` at 1587. |
| p07 | REPRODUCED (NOT MEASURED) | 403 from the registry, reported honestly as NOT MEASURED. |
| p08 | REPRODUCED, weak verdict | Real error text, `use of internal package ... not allowed`, plus a control that builds. But the verdict is `[ rc -ne 0 ]`. With go hidden from PATH: `go: command not found`, `exit=127`, `VERDICT ... CONFIRMED`. |
| p09 | REPRODUCED, weak verdict | Real `package lib.internal is not visible`, and the friend control compiles. Same non-zero-exit verdict structure as p08. |
| p10 | REPRODUCED, weak verdict | `E0603` shown. With rustc missing, `exit=127` and still CONFIRMED. |
| p11 | REPRODUCED | Expected exit codes match and the messages match the brief's quotes. Caveat: the "must be refused" cases assert only exit 1, not the diagnostic tag. A parse error would also satisfy them. Mutation M1: an unpatched compiler on `shopB`/`shopC` also gives exit 1, from a parse error on `visible_to`/`internal`. The "must compile" cases (exit 0) do constrain it, and the printed messages are the right ones, so I judge the result valid. |
| p12 | REPRODUCED (LOC) / noise (timing) | LOC recomputed from the patches: A +49 -3, B +52 -6, C +65 -19; per-file splits and rule lines 15 and 9 all match. Timing: see section 1. |
| p13 | REPRODUCED | `internal` has 1 `is_integer` test, `private` has 0, and `internal` is exported. Mutation M3 turns it RED. Caveat: the baseline mixes compilers (`public`/`private` from base, `internal` from patch C). The only extra variable is C's design choice to export `internal`, which the claim is about. |
| p14 | REPRODUCED | `--api` omits the private helper and a test module is refused. With the helper made public it is listed (mutation M5 turns the first verdict RED). |
| p15 | REPRODUCED | I recomputed independently by grep: 27 module dirs, 4 B#-native edges, 4 exemplar `using` lines. The "0 refused" figure is tautological (nothing is marked, and the brief says so). "2 of 4" depends on the script's arbitrary treatment of namespace targets. Treating a namespace target as its child modules would also refuse `Shop.Reports -> Shop.Collections`, giving 3 of 4. The brief presents "2 of 4" as a fact. |
| p16 | REPRODUCED | md5 hash `c3989ba0222d901d` is identical across base, A, B and C. The "31" is wrong: 30 beams, 27 distinct modules (`Shop` x2, `Ints` x3). Mutation M4 turns it RED. |
| p17 | REPRODUCED | Two separate beams and the cousin `using` runs. Mutation M7 turns it RED. |

### CHANGELOG edits: all legitimate, none manufactured

- p01 echo, p02 `beam_lib` query shape, p10 PIPESTATUS, p13 5-tuple vs 6-tuple (an empty first REFUTED was a probe bug), p11 yecc-count print: probe bugs, no expectation changed.
- p12 sequential to interleaved: a sound fix for ordering bias, made after seeing an odd first run. The 5% and spread criterion was unchanged. The kept `.firstrun` file is the interleaved one (-0.1/-2.2/-1.1); the sequential run is not preserved, so the "base 2644 vs 2146-2296" figure is uncheckable.
- p12 mechanical verdict line added later: the criterion was already in the header, so it is fine, but low power (section 1).
- The sha256-of-beams removal is correct: the beams embed output paths, and p16 replaces it with `beam_lib:md5`.
- The p05 dropped block is the only edit that removed an unexplained result. It is not contrary evidence, but I note it.
- The claim that `using :'Shop.Internal' {..}` does not parse (lowercase `lident` in `foreign_sig`) is plausible against the grammar, but I did not re-test it.

### Mutation tests

Each premise was broken, with the outcome:

| # | Mutation | Result |
|---|---|---|
| M1 | Unpatched compiler on p11's A fixtures | `Outsider` and `OutsiderNs` exit 0, so p11 would go RED. |
| M2 | p03 with no patch for A | Control not refused, so p03 is REFUTED. |
| M3 | C patch without the export change | `internal` has 0 tests and is not exported, so p13 is REFUTED. |
| M4 | A plus `is_public(_) -> true` | pA hash 429f..., not base; p16 says DIFFERS. |
| M5 | p14 helper made public | First verdict REFUTED. |
| M6 | p15 corpus with `module FibX` in `Fib/` | Reports 1 mismatch and exits 1. |
| M7 | p17 `Helper.bs` declares `module Shop.Orders` | `module_path_mismatch` and REFUTED. |
| M8 | p01 `RecomputeTotal` made `private` | `Outsider` is refused. |
| M9 | Caller moved under `Shop` (A) | Compiles, so A's subtree reading is right. |
| M10 | Delete the `visible_to` line from `shopB` | `Audit` and `Outsider` both exit 0, so p11 would go RED. |

None stayed green when it should have failed. The exception is the tool-missing cases, which stay green and which I flag as weak (p08, p10).

Extra independent checks, which reproduced the brief's claims:
- Under A, nested `Shop.Orders.Internal` is usable from `Shop.Orders` and refused from `Shop.Billing`.
- Under A, `Shop.Reports` using `Shop.Collections.Internal` is refused.

## 3. Citations

All correct unless listed:
- `bs_check.erl` lines 109/188/4861, 299, 364, 375, 478; `bs_emit.erl:141`; `bs_api.erl:280`; `add_module_import/3` at 511-525 (reads exports and the `types` entry).
- `xref.erl:40-55` and 1587; `erl_internal.erl:22-25`; `logger.erl:1573`; `kernel.erl:37`.
- F15.8 and F15.11, 41 §5 (diagram at line 490), 24 §2 and §7, `CONTEXT.md:426`.

Mismatches and omissions:
- **"Ticket 18 section 1" (one entry label) is wrong.** The text is in ticket 18 at line 440 (Answer preamble), line 931 (Evidence table) and line 975. §1 is lines 491-618 and does not contain it. The ticket 60 text itself says §5, which is also wrong (§5 is "No opt-out").
- **"Five visibility readers" is incomplete.** `bs_api.erl:152` and `:158` also match `public` literally. Under C, `bsc --api Shop/Orders` lists only `Fetch`, so an `internal` function is silently omitted from the client API. I ran this on the C binary. That is a C benefit the brief never states, and it bears on the Option 1 counterargument.
- **Section 8 item 1, "REFUTED (stale)", is framed too hard.** The ticket said "measured at 0b761f6", so its claim was true then. "Superseded" would be accurate.

**Go, Java and Rust:** these are installed (`go1.24.7`, `javac 21.0.11`, `rustc 1.97.0`, in `out/`) and were executed. The quoted messages match raw output verbatim, and each has a control that compiles. "Reflection not measured" is stated honestly. None of the Go, Java or Rust claims is unexecuted. The weakness is only the verdict lines.

## 4. Numeric claims

| Claim | Check | Result |
|---|---|---|
| +52 -6 (B) | recomputed from the patch | OK. Likewise A +49 -3 and C +65 -19, with the per-file splits. |
| Net in `bs_check`: A 32, B 26, C 34 | 35-3, 30-4, 51-17 | OK. |
| Rule lines 15 vs 9 | regex over the patch | OK, but apples to oranges: B's 9 excludes its lexer/grammar/`bsc` lines (+8 -2). Totals are A 49 vs B 52. Section 6's "9 rule lines against 15" favours B misleadingly. |
| md5 equal across 31 modules | `md5.txt`: 31 lines, 30 entries, 27 distinct | **WRONG count; equality OK** (same hash for all four variants). |
| 0 of 4 cross-module edges, 27 modules | grep recompute | OK (4 edges and 27 module dirs reproduced). The "0" is by construction. |
| 0 vs 1 `is_integer` | raw disassembly | OK. |
| 6 s/r, 0 r/r yecc | `build.log` echo | OK. |
| `base` spread 1894-3160 | author's raw | OK; mine was 1688-2684. |
| 27x exit 0 under each patch | p12 | OK. |

## 5. Claims weakly supported or unsupported by raw outputs

- **"Twice -> Bump hits the guard too (one label)"** (brief section 4, p13): the output shows only Bump/1's own entry test. It never disassembles `Twice` or shows the call going through that entry. This comes from ticket 18, not from the probe. The brief says "reproduced", but only the guard's presence is reproduced.
- **E11's naive-filter message** was reasoned from code, not built. The brief says so.
- **Option 2 and 3 granularity.** The brief's Option 2 counterargument covers the list-editing speed bump and the keyword. It omits that under B (and A) the whole module is closed, so an outsider cannot call even another public function. I tested this: with `Fetch` added to `shopB`'s `Orders`, `OutsiderFetch` (using `Shop.Orders`, calling `Fetch`) is refused with `Shop.Orders declares visible_to Shop.Billing, Shop.Reports ...`, exit 1. Only A's counterargument mentions "granularity is the whole module". Also, B and A leave `RecomputeTotal` listed in `bsc --api` for allowed callers and do not address the Option 1 test-boundary counterargument; only C does, via `bs_api`'s `public`-only pattern, by accident.
- **Recommendation framing.** The "no corpus demand" and "0 of 4 refused" arguments are tautological for an opt-in rule. The decisive argument for "do nothing" is the CLAUDE.md second-occurrence rule, which is policy, not measurement.
- **Portability.** `lib.sh` defaults to this session's scratchpad path; the probes are not portable beyond this machine without `W60_ENV`/`W60_WORK`.
