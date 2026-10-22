# Verification of 59-boundary-guard-scope.md

Verifier re-ran every probe in a fresh scratch (SCRATCH=/tmp/claude-0/verify59/s, raw output /tmp/claude-0/verify59/out/). Repo `git status`: only `?? artifacts/`.

## Per-probe verdicts

| Probe | Verdict | Notes |
|---|---|---|
| 00 toolchain | REPRODUCED | identical |
| 01 as-built | REPRODUCED | emitted Erlang and battery byte-identical to the brief |
| 02 scope variants | REPRODUCED | whole file identical to author's out/ (diffs of patches included). Patches A/B/C are real one-hunk edits of bs_emit.erl (diff printed in output); B's `{ok,_} when not Public` and C's removal of `when Public` do change emission (A/B/C columns differ), so it can go red/green. Valid-input controls present in all 3 variants. battery.escript prints raw results with no expectations, so there is no hard-coded expected output to echo. |
| 03 bytes | REPRODUCED | Code chunk 418/391/436 identical; file bytes differ by 4 (2500 vs 2496, 2556 vs 2552), immaterial |
| 04 single-caller elision | REPRODUCED | is_integer gone, range tests + tag test kept. Weakness: the causal claim "because single caller proved it" has no in-probe control (same Bump with an unguarded caller). Probe 03's multi-caller Bump keeping 3 tests is the only contrast, and it is a different module. Soft, not circular. |
| 05 runtime | REPRODUCED | tag +8 ns (33.8 vs 24.5), kind +1..2 ns, same as brief. Noise floor ~1 ns (A vs B Bump, identical code, differs 0.5..0.9), so the "+1 to +2 ns" kind cost is barely above noise; the brief says so. |
| 06 Elixir | REPRODUCED | 2.5 / 301 / 303.5 |
| 07 Gleam | REPRODUCED | emitted Erlang and 999 / 2.5 identical |
| 08 Elm | REPRODUCED as "cannot compile" (403) | the brief correctly labels the Elm row unverified |
| 09 tag cost vs fields | REPRODUCED | 179/155 bytes, instrs 8/8 vs 6/6. "12 bytes each" is 24/2, derived not per-function, but equal instruction counts support flatness |
| 10 deep door | REPRODUCED but MIMIC (weak) | mine: 99/7784/100368 us door-check vs 3.2/33.9/95.8 shallow. Ratio at n=4000 is ~1000x here (brief: 300x to 1000x, fine). It is quadratic by construction, because `deep` re-checks the whole tail on each recursive re-entry. It demonstrates arithmetic, not bsc behaviour. The brief labels it hand-written. It also shows check-once is ~1x, so "narrow cannot be sound without restructuring" is the only claim it supports. |
| 11 hot private loop | REPRODUCED emission; **MISMATCH in conclusion** | see below |

### Probe 11 mismatch (conclusion-relevant)
Brief 3.7 / Option 2 rationale: "a plain-int accumulator loop shows no consistent cost (C was not slower in either pass)"; total range "0 to about +25%".
My 6 runs of hot.escript (A vs C), SumTo(1e6) medians us, A / C:
2608/2772, 2535/4493, 2565/2608, 2541/4092, 3039/4126, 2573/2851.
In 3 of 6 runs C was 1.6x A with non-overlapping ranges (C min 3687..4172 vs A max 2616..2631 in two of them). SumMod (refined-int helper) C was slower in all 6 runs by +20..30% (5.0-5.3 ms vs 6.3-7.0 ms). So "plain-int loop shows none" is not supported; it is bimodal (JIT/placement noise or a real +60% on a 1e6-iteration tail loop with `is_integer` on two accumulators). The brief's recommendation point 2 ("cost small and bounded ... int helper at most a couple of ns", "plain-int loop showed none") should be softened: the evidence is a range of 0 to +60% on a call-only hot loop, OTP 25, noisy. It does not flip the recommendation (per-call absolute cost is still ns), but the stated bound is wrong.

## Circularity / cannot-fail hunt
- No probe echoes hard-coded expected output. Probes 01-04, 09, 11 consume the real bs_emit.erl (OTP-25 scratch build). I confirmed the scratch patches are only rebar.config, lexer TokenLoc/adjust_col, as the brief says; bs_emit.erl has no column references (grep: none), supporting "emission unaffected".
- A/B/C patches make the "bad" case reachable rather than unreachable: B introduces the hole, C removes it, A is the repo. Each variant has valid controls that return the same in all three.
- Probe 10 is the only mimic and is disclosed. Probe 08 fails by design and is disclosed.
- Probe 02 is a measurement, not an assertion; it has no pass/fail, but it demonstrably differs across variants, so it can show red.
- Not circular, no cannot-fail probes found. Gaps: no control for 04's causal claim; no probe at all for floats/other ground types though Option 2 is worded "every function with a ground-typed parameter".

## Brief text errors
- "C closes all ten doors" / "all ten of the forged ones raise": the battery has 9 forged calls (Outer, OuterL, SumO x2, InnerAsValue, BumpAsValue x2, Nested, OuterI) and 3 controls. "Ten" is wrong; nine.
- Section 3.2 and the ticket: the ticket text itself already contains the "It is not [a defect]" argument (a forged record reaching a private function through an exported one). The brief frames the falsified premise as the ticket's; accurate for the "defect" side only. Minor.

## Citation check
- bs_emit.erl: 275 guard_one head, 277 `{ok, Tag}`, 284 `none when Public ->`, 288-290 fall-through (confirmed by the C diff), 253-255 for the "tag test emitted only where single closed record" claim is WRONG: that comment is at lines 259-262 (253-255 is the start of the section comment). Minor.
- 46-refined-parameter...md:214-216 and 220-222: text is at 215-216 and 221-222 (off by one). Content matches.
- 18-boundary-defence.md (lives in wayfinder/issues/, not research): 613-617 matches (one entry label, "elided entirely", "shape C wanted anyway"); 557-560 matches (83.3%); 815-846 section 4 matches ("looks at the exported function's own clause heads").
- lists.erl:271-275 in OTP stdlib-4.3.1.3 matches.
- 18-elm-port-validation.md:216-221 and :860 match (toDecoder; "owning the only door").
- Ticket 59 text: /5 in header, /4 in quote, "+14 bytes flat", "+3-5 bytes ... +-0.09 ns" all match. 26 line 381 "+14 bytes, flat in field count" matches. F24.6 and "100.5 >= 9" match F24. Ticket 75 `fun 'Double'/1` matches. 46 "Corrections" section exists and says boundary_guards/4 not scoped.
- Brief's "never silently" quote of 18 is a paraphrase of 18-boundary-defence.md:408 ("but never silently"); ellipsis-joined, acceptable.

## Unsupported / weakly supported claims
1. "plain-int loop showed none" (Option 2 cost, rec. point 2): contradicted by my reruns (above).
2. "erlc elides is_integer because a single caller proved it": no direct control.
3. "Option 2 is every function with a ground-typed parameter": only int/refined-int/record probed.
4. "exported function pays guard on intra-module calls", "element consumed inline in exported body unguarded": inferred, disclosed as not probed.
5. Elm behaviour: unverified, disclosed.
6. Probe 10 "300x" ratio is a property of a hand-written mimic.

## Overall verdict
Core finding is REPRODUCED and robust: under the repo emitter, narrowing the tag test to exported-only turns three realistic doors (list element, nested record field, private fn escaped as value) into silent wrong answers; widening the kind test closes the int equivalents. The comparison is non-circular (real emitter, one-hunk patches, valid controls). Two things need correcting before it goes to David: the hot-loop cost claim in 3.7 / Option 2 (timings do show up to ~1.6x on a 1e6-iteration plain-int loop in half my runs and a consistent +20-30% on the helper loop), and "ten doors" should be nine. Citations are sound apart from two off-by-small line numbers. The recommendation (Option 2) stays supported on correctness grounds; its cost paragraph is overstated as "small and bounded".
