# Verification of the ticket-59 brief (independent)

Scope: re-run of `artifacts/probes/59/run.sh` (OTP 25, Elixir 1.14.0, Gleam 1.12.0), source/citation audit, circularity hunt, my own falsification probes (scratchpad `v59/`, not in repo). Brief and probes untouched. `bs_emit.erl` and `compiler/features` are identical at HEAD and `8d56f53` (git diff empty), so line citations are against the brief's SHA.

## 1. Probe re-run vs the evidence table

`run.sh`: "ALL PROBES OK", 54 s. Row by row:

| brief row | my result | verdict |
|---|---|---|
| one entry label (E1/E1b) | ok, `call_only,1,{f,2}` | CONFIRMED |
| local guard elided when caller proves (E2, E4-E7) | `is_integer=0` all | CONFIRMED |
| kept when caller untested (E3) | `is_integer=1` | CONFIRMED |
| tag test not elided (T2, T4) | `tagtest=1`; pattern form 4 instrs | CONFIRMED |
| range kept (R1 `cmp=2`, R1b `is_integer=0`, R2 `cmp=2`) | identical | CONFIRMED |
| P3 11 rows | every cell identical to brief's table (binaries print as `<<97,64,120>>`) | CONFIRMED (see 2b for what it means) |
| P4 Elixir | FunctionClauseError both defp cases | CONFIRMED |
| P5 Gleam | 0 `when`, forged vendor returns `<<"v">>`, `add(1.5,2.5)=5.0` | CONFIRMED |
| P6 census | 760/3845 = 19.8%, 768/7729 = 9.9% | CONFIRMED (meaning: 2d) |
| P2 Code bytes | tag +12 B/+2 instr flat at N=1,5,20; pattern +18/+3; exact-set +24/+28/+55; `is_integer` +5/+1; Kind key +2 words flat | CONFIRMED (exact) |
| P2 timing: "tag +1.3..+4.0 ns at N=5, +5.9..+6.4 at N=20" | 4 runs (1 in run.sh + 3 reruns), identical-module noise floor 0.88, 1.44, 2.35, 3.97 ns. N=5 map_get delta: +2.30, +2.97, +1.28, **-0.63**. N=20: +8.09, +1.95, +5.57, +4.98. `is_integer`: -0.84, +2.20, -1.11, +0.15 | see below |

Timing, noise-aware. The brief's own claim that identical-code modules spread 0.25..3.55 ns reproduces (mine 0.88..3.97): the brief is honest that the box is noisy.
- `is_integer` "unresolved, about 0 ns": CONFIRMED (sign flips, spread +-2).
- N=20 tag test costs more than N=5 and is positive in 4/4 runs (median about +5.3): CONFIRMED qualitatively. The brief's ranges are narrower than my spread (1.95..8.09 vs 5.9..6.4): do not quote "+5.9..+6.4".
- N=5 tag test "+1.3..+4.0": DISAGREE on the range. One of four runs gave -0.63, below zero and inside noise; N=5 is not resolved here. The Option B cost line "(+1..6 ns here)" and "the tag test ... growing in time with field count" is supported only for N=20 and only directionally.
- The script's own "above noise floor" labels are unreliable. `noise floor` is the range of just three modules, and it printed "(above noise floor)" for a pattern-form delta of -4.46 ns (a head pattern cannot be 4 ns faster than no test). The brief correctly does not rely on those labels. The side remark that the head-pattern form "may be cheaper in time" is not supported (it ranged -4.46..+4.49): UNVERIFIABLE at this resolution (brief hedged it).
- Brief's quoted 18a "+3..5 B" / 26a "+14 B" vs mine +5 / +12 is flagged as different OTP/arch: fair.

## 2. Circularity hunt

**a) p1_elision, the changed assertion.** The revised assertion is the observed one, and the source comment (p1_elision.sh lines ~118-120) and brief s7 both disclose it. Original expectation (cmp=0) vs revised (cmp=2): the revision is not tuned toward the recommendation. If anything it cuts against B (range tests survive), and the brief says so in s5. Controls: E1/E2/E3 differ only in exported-or-not and whether the caller tests (same body); T1/T2/T3 likewise; R1/R2 differ only in the caller's range test. `asm_count`'s `cmp` counts `is_ge`/`is_lt` only; `X>=0, X=<255` lowers to two such tests, so `cmp=2` is a sound reading. My own addition: `k1.erl`, local `f` (tag) called from a literal-map caller and a pattern-guarded caller keeps `tagtest=1`; local `g` (`is_integer`) with one proving caller and one untested caller keeps `is_integer=1`. This confirms elision is all-or-nothing across callers, which the brief does not say: B's "erlc removes the private `is_integer`" holds only if *every* in-module caller proves it, and not at all for a function whose `fun f/N` escapes (exactly the f2 case). The brief's cost paragraph is therefore somewhat optimistic. CONFIRMED with that caveat.

**b) p3_forge: model vs real emitter.** `forge_a/b.erl` are hand models, admitted. Against `bs_emit.erl`:
- Public tag guard `ship(O) when map_get('Kind',O)==Tag`: matches `tag_test/3` (582-586) and `guard_one` (267-275). The projection `o.Customer` is `map_get('Customer',O)` (`expr({e_proj..})`, 1105-1112). Model matches.
- Sub-term not tested at the export: matches `boundary_guards/6` zipping parameters only (257-262). Real, not model construction.
- `total(list<Order>)`: `record_tag` on a list gives `none` then `int_guard` is a no-op (`is_int_only` false): no guard. Matches model.
- Private `notify`/`price`/`describe` under B carry the tag test: this is **today's** emitter behaviour (268-275 never reads `Public`), so forge_b is faithful to the status quo for tags. Private `dbl` under A: today's behaviour (`none -> {Pat,[]}`, 279-280). Private `dbl` with `is_integer` under B: matches `int_test` (494) as it would run if `Public` were removed. Private `notify` under A: unguarded only after the proposed 1-line change.
- Model is neither more nor less guarded than the real emitter in any row I found. One omission: the real `rule()` for F46 emits `fun 'Notify'/1` the same way as `fun notify/1` (F46 line 90 confirms the shape), so fine.
- 11 rows, 'silent under A' (c2, l2, f1, f2): the silence is produced by (i) the scope rule (private unguarded) and (ii) a real property of the emitter (exported guard does not look at sub-terms/list elements), not by a hand-added hole. c3 is the honest "neither" row. w1 shows a row where the model is guarded under both. So not circular. What the probe proves is only what the BEAM does with the shape: it cannot show bsc emits it. Accurately disclosed.
- Unlisted but noticeable: B's tag column equals the repo's current behaviour, so rows c2/l2/f1 argue against *changing* tags to A. The only newly-closed hole B buys over today's compiler is int/float/range (f2 and its sub-term analogue). The brief states "net new emitted code is the int/float/range tests", but its prose frames all four rows as B's benefit.

**c) p2 deltas.** Control `u` (`f(M) -> map_get(LastField, M)`) vs `g` (same + `when map_get(kind,M)==order`) differs only in the guard. `p` differs in head form on purpose and is labelled. `i`/`ig` differ only in `is_integer`. `exact-set` control grows, proving the probe can see growth (asserted). Term-size controls differ only by the `kind` key. One bias: `Kind`/`kind` sorts after `f1..f20` so the key lookup is worst case, which the brief states.

**d) p6 census.** The count is "function has a type-test BIF call anywhere in some clause's guard". Biases: patterns (`<<_/binary>>`, `[]`, `{ok,_}`) are not counted, and exported APIs in stdlib lean on patterns too; exported functions are API surfaces with multiple clauses (more chances), local helpers are often single-clause accumulators; both are counted per function, not per parameter; stdlib and kernel are two projects' conventions. Both numbers are exact as stated, and 2x is robust to the arithmetic. But "authors guard exported twice as often" is equally explained by "private callers already validated", which is the *very premise* under dispute, so the census cannot arbitrate A vs B. The brief labels it "a convention census only" and uses it only for precedent. Fair: CONFIRMED as stated, weak as evidence.

**e) My falsification attempts.**
1. Caller-side proof that should elide a tag test (literal map arg, pattern-guarded caller): not elided (k1). This agrees with the brief's T2 (the claim survives).
2. A row where B should NOT be silent-proof: forged float in a sub-term `Amount` reaching an *inline* `o.Amount + 1` (k2 `ship2`) returns 2.5 under B; the same value through a private `add(int)` (k2 `ship`) is `function_clause` under B. So B closes only the cases where the sub-term is handed to a private function, which is a consequence of 46 §4 (projection guards owed). The brief concedes c3 (payload) and defers projection guards, but never states that B's coverage of the int channel depends on whether the author factored the arithmetic into a private function. This weakens the "one rule stated once honours never-silently" sentence in s6: B reduces holes, it does not close them.

## 3. Citations

Opened each:
- `bs_emit.erl:267-275` (`guard_one` tag branch, no `Public`): CONFIRMED. `276` `none when Public`: CONFIRMED. `155` Public, `161` clause/4, `187` call, `257/259` boundary_guards, `582-586` tag_test, `494-495` int_test: all CONFIRMED. `170-173` (IntOnly comment) CONFIRMED. `321-325` ("Exported functions only... asymmetry is deliberate") CONFIRMED.
- Brief s2 "`kind_tested/2` at 194 and `strip_rels/2` at 175": those are *call-site* lines; the definitions are at 693 and 616/621. Fine but imprecise. The substantive claim (neither consults `Public`) is CONFIRMED. Nuance missing: both take `IntOnly`/`skips`, computed from the declared type regardless of visibility, so a private `int`-only parameter never receives the narrowing/relational `is_integer` (the "skip"); the test appears on private functions only when the parameter is a union (F24 §6's `T = int | atom`, whose private `Tag` hole is itself documented at F24 lines 187-211 and is more evidence for B that the brief does not cite). So "the narrowing-site `is_integer` is also emitted on private functions" is true but narrower than it reads.
- F24: §2 line 115, §3 lines 118-130, §5 projection unbuilt (lines 164-165) CONFIRMED. F46 "lines 55-57 and 65, 77": actual `Rule(:staff) -> Free` is 56, `private int Free` 65, `Double` 77/78: acceptable. `boundary_kind_tests` F24.6 line 85-97: CONFIRMED (brief says 88). `boundary_range_tests` F37.5 line 120: CONFIRMED. `records_tests` line 122, F3.9 text (F3 line 252-255 "exported record parameter"): CONFIRMED.
- Ticket 59 table, ticket 46 lines 129, 249, 298 (Inner measured), 46 §4 "fixed number of projections", collections refused: CONFIRMED. Ticket 18 §4 sentence "a value handed to another function counts as unchecked, and is guarded": CONFIRMED, and the brief's reading (it puts the guard on the *exported* function, row w1) is right. 26a +14 B: ticket 26 lines 227/302: CONFIRMED. 18 line 613-615 "elision is exported vs local-only": CONFIRMED.
- **Missed/overclaimed:** s5 says "Everything already written (18 §4, 46 §1, 58, F24, F37.5, F3.9) agrees with A". But 18 lines 194-195 say *"Restricting omission to non-exported functions is not an alternative — a foreign value entering through an exported function reaches private ones unchallenged"* (in the failure-arm context, with 12 §6/ticket 21 "no foreign caller exists is unprovable"). That is a decided text arguing B's premise, and line 615 ("interior functions already pay nothing — which is the shape C wanted anyway") argues the other way; the brief cites neither. The "five artefacts agree with A" count, used as B's strongest counterargument, is overstated or at least one-sided. Verdict on that sentence: DISAGREE (incomplete).
- Citation in the brief to "18 'never silently'" and to `research/18-elm-port-validation.md`: file exists (not re-read); UNVERIFIABLE beyond existence.

## 4. Does recommendation B follow?

Mostly. Evidence for B: premise "private values were already examined" is false by P3 (c2, l2, f1, f2; reproduced, model faithful). Evidence against B is fairly present: range tests not elided (R1), tag test not elided (T2), cost is OTP 25 and noisy, B reverses cited text. The counterargument is fairly stated except: (1) it counts five artefacts agreeing with A while omitting 18 lines 194-195 which cut the other way; (2) it does not note that B's tag half is already the status quo, so the dead-weight/cost objection to B concerns only int/float/range, and the real change for hot paths is two comparisons on private refined-int parameters, which the brief does state; (3) "erlc erases the redundant `is_integer`" needs all callers to prove it (k1) and does not apply to escaped `fun f/N`, the one case where B's int test matters; (4) B's int benefit rests on f2 (an F46 escape) and on sub-terms that 46 §4 is already owed to guard, which the brief names in "what would change my mind (2)". The recommendation is defensible; "never silently" is not achieved by B (k2). The timing numbers should be treated as unresolved, which the brief mostly does.

## Verdicts

- bsc tag test has no visibility check (bs_emit 267-276): CONFIRMED
- three scopes / narrowing-site `is_integer` never consults Public: CONFIRMED with nuance (only for non-int-only params; int-only private params are skipped)
- one entry label (E1/E1b): CONFIRMED
- guard elided only when in-module caller's test visible (E2-E7), kept when not (E3): CONFIRMED (and all-callers caveat added)
- tag test not elided in a local function (T2/T4): CONFIRMED (extra falsification agrees)
- range test not elided (R1), assertion changed after seeing it: CONFIRMED, not circular (change disclosed, cuts against B)
- P3 rows c2/l2/f1/f2 silent under A, w1 caught either way: CONFIRMED; not CIRCULAR-SUSPECT (silence comes from the scope rule plus the real parameter-only guard; model matches emitter lines cited); B's tag column = today's behaviour
- w1: CONFIRMED
- tag test +12 B/+2 instr flat; is_integer +5 B: CONFIRMED
- timing "+1.3..+4.0 ns N=5 / +5.9..+6.4 ns N=20": DISAGREE on ranges (my spread -0.63..+2.97 and +1.95..+8.09); direction at N=20 CONFIRMED; N=5 and `is_integer` UNRESOLVED; brief's noise caveat is accurate
- 18a's ±0.09 ns not reproducible: CONFIRMED
- Elixir defp (P4), Gleam (P5): CONFIRMED
- P6 19.8% vs 9.9%: CONFIRMED numerically; weak evidence for the dispute (same count explained by the contested premise)
- citations (bs_emit, F24, F46, F37, F3, tickets 18/26/46/58/59): CONFIRMED, minor imprecision (kind_tested/strip_rels cited at call sites; F46 line range)
- "everything decided agrees with A": DISAGREE (18 lines 194-195 argue otherwise; unmentioned)
- erlc will remove private `is_integer` under B: PARTLY (all-callers condition, not for escaped funs)
- Recommendation B: follows from the evidence with the caveats above; counterargument stated mostly fairly, with the omissions listed in section 4.

Overall: the brief's measurements reproduce and its model is not tuned to its conclusion. Weak spots are timing figures (quote as unresolved), one overclaimed "all five artefacts agree with A", missing 18 lines 194-195, and B being described as closing holes that stay open when a projection is used inline (k2).
