# Independent verification: artifacts/59-boundary-guard-scope/brief.md

Verifier re-ran `probes/run.sh` from scratch on a copy under the scratchpad. The author's `.out` files were not overwritten.
No git, no Linear, no bsc. Every emitted-Erlang block and every number in the brief is a hand-written analogue, not a bsc measurement.

## Overall verdict

**Do not send as-is. Send after six corrections (list at the end).** The direction of the argument survives every re-check.
Three things are wrong outright: the corpus counts, the noise-floor sentence, and `guard_one/8`. Several claims are worded
more strongly than the evidence allows.

## Verdict table

| # | Item | Verdict | Note |
|---|---|---|---|
| 1a | p01, p04, p06, p07, versions `.out` reproduce | CONFIRMED | Byte-identical diffs. Bytes, asm and outcomes are deterministic. |
| 1b | p05 `.out` reproduces | CONFIRMED | Only the PLT path and the timing lines differ. |
| 1c | p03 loop tag cost, "+7.6 to +8.1 ns on a ~12 ns loop" | CONFIRMED-WITH-CAVEAT | Sign and size hold. Range is too tight (see timing section). |
| 1d | "noise floor <0.1 ns" | REFUTED | Twin medians on the loop reach +0.13 to +0.22 ns. |
| 1e | single-call tag "+1.5 to +3.1, cleared floor in 3 of 4 runs" | CONFIRMED-WITH-CAVEAT | Cleared in 6 of 6 of my runs. The 1.6 ns twin-noise event is NOT-REPRODUCIBLE. |
| 1f | single-call `is_integer` "-0.3 to +0.12" | CONFIRMED-WITH-CAVEAT | The upper end is understated. Medians I saw: -0.03, +0.14, +0.24, +0.39, +0.90, +0.15. |
| 1g | private int loop, caller proves: "+0.01 to +0.07" | CONFIRMED-WITH-CAVEAT | The sign flips run to run (-0.10 to +0.13). "No measurable cost" holds. |
| 2 | Analogue guard form matches `bs_emit` | CONFIRMED-WITH-CAVEAT | See fidelity section. Two harmless deviations, one important scope caveat. |
| 2b | Emitted-Erlang blocks vs source | CONFIRMED-WITH-CAVEAT | Guard shapes correct. Tag atom and field-key spelling were not checked against bsc. |
| 3a | p04 paths (nested, escape, many) genuinely reached by code | CONFIRMED-WITH-CAVEAT | The paths are real. The forged input is the premise, not a finding. |
| 3b | p04 `top` "identical on/off" | CONFIRMED-WITH-CAVEAT | True, but by construction: the exported guard is the same test. It is a tautology that the probe confirms. |
| 3c | Predictions "written before results", "four disclosed wrong predictions" | NOT-REPRODUCIBLE | See predictions section. No git allowed, and the disclosure is not in the brief or the headers. |
| 3d | p01 "elision" checks inspect real assembly | CONFIRMED-WITH-CAVEAT | Real `.S` output. The tag-row KEPT flag is vacuous (see below), but bytes and asm independently support it. |
| 3e | Dialyzer "nothing reported" genuinely observed | CONFIRMED-WITH-CAVEAT | The `binary_to_term` case is genuine. The "nested field" and "escaped fun" silences are vacuous. |
| 3f | Dialyzer local-vs-exported-vs-escaped (D4) | CONFIRMED | Real dialyzer 5.0.5. Only `local_two` (line 8) is flagged. |
| 3g | Elixir probe | CONFIRMED | Real compile, real `beam_lib` forms, real disassembly, real runs. |
| 3h | Elixir "no def/defp scope rule" | CONFIRMED-WITH-CAVEAT | Shows only that the author wrote the pattern in both heads. It is an absence-of-rule inference. |
| 3i | p08 counts "30/188 private, 32/161 public with record param" | REFUTED | The regex misclassifies 12 public functions as private. Corrected: 21/176 private, 41/173 public. |
| 4a | SOURCE cites 251, 261-277, 263, 270, 316-319, 322-340, 488, 576-580, 1036-1040, 1306, 32-35, 149-181 | CONFIRMED | Opened and matched. |
| 4b | `guard_one/8` (used repeatedly) | REFUTED | `guard_one` has 7 parameters. The brief flags naming drift elsewhere and introduces its own. |
| 4c | "F24/59 say `/5`" | REFUTED | F24 never names `boundary_guards/N`. Tickets 58, 59 and 68 say `/5`, 46 says `/4`, 105 already says `/6`. |
| 4d | F24.6, F37.5 tests pin private = unguarded | CONFIRMED | `boundary_kind_tests.erl:88-98`, `boundary_range_tests.erl:122-131`. |
| 4e | "no test pins the private tag test" | CONFIRMED-WITH-CAVEAT | Only `records_tests.erl:123` (exported `Pay`) and a `bindings_tests.erl:46` count. Not run, as the brief says. |
| 4f | Finding 3: "18 sec 4's premise ... stopped holding when F46 landed" | CONFIRMED-WITH-CAVEAT | Real problem, wrong attribution (see label section). |
| 4g | F46 cites `:93-98`, `:65-77` | CONFIRMED-WITH-CAVEAT | Actual lines are 90-97 and about 59-66. Content correct. |
| 4h | Finding 4: "elided entirely" holds for `is_integer` only | CONFIRMED | Bytes and asm agree. |
| 4i | "+12 B here vs recorded +14 B" | CONFIRMED | p01 A gives +12. Ticket 26:302 records +14 on OTP 28.5 arm64. |
| 4j | 26:309-312 "tag costs nothing measurable" compares 7.04 with 8.78 | CONFIRMED | The brief reads it fairly. |
| 4k | Gleam / Elm / bsc overclaims | CONFIRMED | None found. Gleam not probed, Elm stated as no claim. |
| 4l | Option 2 table "BEAM takes kind back when the caller proved it: yes, entirely" | CONFIRMED-WITH-CAVEAT | Verified only for a sole, proven, direct caller (see scope caveat). |

## 1. Timing re-run

Six full runs on this machine: run.sh once, then five more of `p03_time:go()`. The four runs the author stored are not
comparable to mine, because only one run's output is kept.

- **Private record loop, read-only.** Medians +7.74, +7.77, +7.77, +7.96, +7.90, +8.37. Mins +7.3 to +7.5. The sign and the
  ~60-65% size hold, since 7.9/12.0 is about 66%. The brief's "+7.6 to +8.1" is a subset of what I saw. Use "+7.3 to +8.4".
- **Rebuilt-record loop.** Medians +7.1 to +8.6. The brief's "+7.6 to +9.2" is comparable.
- **Noise floor.** The brief says "<0.1 ns". Twin `r_priv` medians I saw were +0.215, +0.07 (author), +0.13, +0.15, +0.12,
  +0.01, +0.05. That is up to about 0.2 ns. Mins of the twins reach -0.23 to +0.18. Still 35 times below the effect, but the
  sentence is false as written.
- **Single-call tag.** I saw +2.26, +2.05, +2.68, +1.81, +2.08, +2.00. Twin medians ranged -0.36 to +0.60 (one `s_int` twin
  +0.72). It cleared the twin in 6 of 6 of my runs. The author's "one of four runs did not clear, twin noise 1.6 ns" is
  NOT-REPRODUCIBLE here, since no stored output shows the 1.6 ns event.
- **Single-call `is_integer`.** Medians -0.03 to +0.90, with twin `s_int` medians up to 0.72. It is indistinguishable from noise,
  which agrees with ticket 18. But "-0.3 to +0.12" understates the spread, and the Option 2 table's "+0.0 to +0.16" carries the same
  problem for the single call.
- **Exported int loop.** +0.64 to +0.88, matching the brief's +0.5 to +0.85.
- **Private int loop, caller proves.** -0.10 to +0.13. Zero, as the brief says.
- **Private int loop, caller unknown.** +0.03 to +0.16, matching the brief's +0.1 to +0.16.

## 2. Analogue fidelity (bs_emit.erl vs p01/p03/p04)

Confirmed against the source:

- **Tag test.** `tag_test` builds `{e_op,'==', e_foreign_call erlang:map_get('Kind', Var), atom Tag}`, and `erl_op('==')` gives
  `=:=`. The result is `erlang:map_get('Kind', V) =:= Tag`, with `map_get` on the left. The analogue has the same form and argument order.
- **Kind test and range.** `int_test` builds `erlang:is_integer(V)`. It leads the range comparisons, which are
  `{'>=',Lo}` then `{'<=',Hi}` folded with `and`, and `erl_op('and')` gives `andalso`. The analogue is
  `is_integer andalso >=0 andalso =<255`. This is the same after Erlang's right-associative parse.
- **Guard shape.** `guard/2` yields one guard sequence `[[Expr]]`, one per clause. The analogue matches.
- **Public/private.** Private is default and is left out of `-export`. Locals are `local` in the beam, as in the analogue.
- **Literal pinning.** The i_priv loop's clause 1 with literal `0` omitting the `N` test follows `pins_integer`. Correct.
- **Body projection.** `e_proj` lowers to `erlang:map_get(Field, V)`, the same call as the analogue's body.

Deviations that do not change results:

- **Head form.** `ensure_var` may wrap an unnamed parameter as a `p_alias` (`bs@N = _`). The analogue uses a named variable. Same semantics.
- **List guard.** In p04 `many/1` the analogue writes `when erlang:is_list(L)`. bs_emit emits no guard for `list<Order>`
  (`record_tag` and `kind_only` both return `none`). This makes the analogue stricter than bsc at that spot, but it does not
  touch the private-function outcome.
- **Compile path.** The analogue compiles Erlang source. bsc uses `from_abstr, debug_info` (`bsc.erl:843`). No codegen
  difference is expected, but it is unproven. The brief discloses this.

Fidelity caveat, an important one for Option 2 and Option 3:

- **Elision needs sole, proven, direct callers.** I compiled three analogues and counted `is_integer` in the private
  `p`'s asm:
  - t3, sole proven caller: the test is gone (0).
  - t2, an extra unproven exported caller `d(X) -> p(X)`: the test stays (1).
  - t1, proven caller plus `esc() -> fun p/1`: the test stays (1).
- p01 B tests only the first situation, with a single caller. Real private helpers usually have several callers.
- The exact F46 escape case that motivates Option 3 is the case where BEAM does **not** take the kind guard back.
  The Option 2 table row "+0 B / yes, entirely" is best case only. On an address-taken private function the `is_integer` costs its
  +5 B and there is no elision.
- This does not overturn (d), because kind is still cheap. But the phrase "entirely" needs a condition: "when every caller is
  proven and none takes the address".

## 3. Circularity checks

**p04 hole matrix.** The nested field (`p(map_get(order,W))`), the returned `fun p/1`, and `lists:map(fun p/1, L)` are
real code paths, and each was run (outputs in `p04_hole.out`). They were not asserted. Cells come from `try`/`catch` over real
calls.

The residual circularity is the forged input itself. Nothing in the probe shows a B# program can receive such a nested or
list-element value past the exported head. That rests on 18's eight-channel argument (RECORDED) and on 46 §4. The `top` row is
tautological: the exported guard is the same test as the private one, so the private one is dead. The probe confirms an
identity, which is fine but is not evidence about bsc.

**46 §4 mischaracterised for `many`.** The brief (line 88, and the Option 3 counterargument) says list elements are owned by
"the guard below the top of a parameter work already owed by 46 §4 / F24 §5". 46 §4 actually says a refined int is guarded
through a fixed number of projections (parameter, tuple element, record field) and "**is not guarded through a collection**"
(O(n), refused). So the list-element forgery through a direct call, such as `Totals([h,..t]) -> Bill(h)`, is a decided
non-defence, not owed work. The `many` path in p04 uses `lists:map(fun p/1, ...)`, which is an escape site, so Option 3's wrapper
does close that one. The brief should say which list paths 46 §4 leaves open by design.

**Predictions.** File mtimes (p01.erl 23:22, p03.erl 23:13, p04.erl 23:22 vs `.out` 23:25) are consistent with "headers first",
but git is barred, so "as first written" is NOT-REPRODUCIBLE. The headers I read hold at least three predictions the results
contradict:

- p01 P5: the range comparisons are gone when the caller ran the same test. Wrong: they stay (+13 B, asm `is_ge` x2).
- p03 T1: the single tag delta is 0 to 1 ns. Measured +1.8 to +2.7.
- p03 T5: a "small positive" delta per record-loop turn. Measured +7.3 to +8.4, about 65% of the loop.

Neither header text nor brief flags these as misses. The only "disclosed" items I found are p04's added `wrap` column (declared in
its header with its own prediction H6) and p05's NOTE about the unused-export and d3 redraft. I cannot find "four disclosed wrong
predictions" in the brief or the headers. If the author told the caller that, the disclosure lives outside these files and
should be moved into the brief.

**p01 "elision" checks.** They run `erlc -S` and search the extracted `p` function in the `.S` text, so they inspect real
assembly. They are not a string that would appear regardless, with one exception:

- **Vacuous tag flag.** For the tag rows, `Look` is `"map_get"`, and `p`'s own body is `erlang:map_get(total, O)`, so
  "test in asm: KEPT" is true regardless of the guard. The rows "tag / caller unknown", "built the literal" and "nested field"
  therefore prove nothing on their own. They are supported independently by the +12 B delta (a real byte measure). The "SAME tag
  test" row is supported by the printed asm (`bif map_get 'Kind'` then `is_eq_exact 'Order'`).
- **Range row label.** The `range ... / caller ran SAME range test` row says "ELIDED". The row counts only `is_integer`,
  and the asm below it shows `is_ge` twice still present. The brief reads this correctly (finding 4).

**Dialyzer.** The output is genuine (dialyzer 5.0.5, minimal PLT, real warnings). Genuine findings:

- **Forged literal into private spec'd `p/1`:** "breaks the contract".
- **Forged literal into exported `e/1` from `d2`:** reported only when d1 and d2 are analysed together.
- **`binary_to_term` value:** silent.
- **D4:** only `local_two` (`d3.erl:8`) gets "Guard test is_integer can never succeed"; `exported_two` and `escaped_two` do not.

Vacuous silences: the brief (table row 74) says "nested field, or escaped fun: silent". d1 has `w/1` and `esc/0`, but **no
caller passes a forged value through either**. Silence there only means the specs are self-consistent. That part is not
evidence of Dialyzer blindness. Only the `binary_to_term` silence is exercised. Reword to "not exercised".

**Elixir.** Real: `elixirc`, `beam_lib` abstract forms with `#{'__struct__' := 'Elixir.Order'}` in both `e/1` and `p/1`, `beam_disasm`
counts (q/1: 0 `is_integer`, r/1: 1), and live runs including a forged bare map passing. Note "Elixir 1.14.0 compiled with OTP 24
running on 25", which the brief omits. The inference "Elixir has no def/defp scoping rule" rests on the author writing both
patterns. It shows the compiler treats them alike, but not that no such rule exists. It is labelled MEASURED (pattern in both
heads), which is fair.

**p08 corpus.** Rerun in the repo root: the output is identical to the checked-in one (349 signatures, 160 files). That
run is faulty. The signature regex's return type must start `[A-Za-z_]`, so a public function whose return type starts with `:`
or `(` (for example `public :ok | :error Pick(int n)`, `public (:ok, int) Init(int seed)`) fails to match with `public` as the
visibility group. The regex then backtracks and reads the word `public` as the start of the return type, so the function is
counted as private. I counted 12 such lines. With `pub` read from the line start:

| | brief (public / private) | corrected |
|---|---|---|
| all | 161 / 188 | 173 / 176 |
| record param | 32 / 30 | **41 / 21** |
| int param | 36 / 71 | 38 / 69 |
| float param | 2 / 0 | 2 / 0 |

- The brief's "about 30 corpus functions" that Option 1 would touch becomes about 21.
- The qualitative conclusion (private record helpers are a minority) is stronger, not weaker.
- The 160 files include `wayfinder/prototypes`, which the brief discloses.
- The record-name set is global across files, so a same-named non-record type counts. That is a further, small, unquantified inflation.
- The independent regex I wrote independently confirmed the total (349/350) and found the mismatch.

## 4. Label discipline

- **SOURCE cites.** All bs_emit line references match: 32-35, 149-150, 155, 181, 251, 261-277, 263, 270, 276-277, 316-319 (asymmetry
  sentence at 319), 322-340, 488-489, 576-580, 1036-1040, 1306. `Public` is threaded 149, 155, 181, 251, 253, 261, 270.
  The `fnames` table holds `{Name, Arity}` (line 1037), as claimed for Option 3.
- **`guard_one/8` is wrong.** The head at line 261 has 7 parameters, so it is `guard_one/7`. The brief uses `/8` in the question,
  the Option 1 and Option 2 deltas, and Option 3, while claiming to fix arity drift.
- **Finding 3 attribution.** The sentence "a private function's every call site is a checked B# call site" is in F24:115
  (with F37:171-172 and 46 §1 at about line 162), each citing "18 §4". 18 §4 itself is the function-local section
  (lines 815-846) and contains no such sentence. 18 lines 191-195 also say a foreign value "entering through an exported function
  reaches private ones unchallenged", resolved by emitting guards at exported functions. So the accurate wording is "the premise
  F24, F37 and 46 §1 draw from 18 §4". The F46 half is confirmed: F46 lines 90-91, 96-97 show `fun 'Free'/1` and
  `fun 'Double'/1`, and the lowering is at `bs_emit.erl:1036-1040`. The brief's "F46:93-98, 65-77" are off by about 3 lines.
- **F46 timing.** F24 (2026-08-23) and F37 precede F46 (dated 2026-09-12 in its own text). The chronology claim is supported.
- **Naming drift.** 46 says `/4` (lines 55, 128, 247, 297). 58 (166), 59 (11) and 68 (258) say `/5`. **105 (lines 60, 93) already says
  `/6`.** F24 does not name the function. The brief says "F24/59 say `/5`". Fix to "58/59/68".
- **"18's cost section ... elided entirely" (18:611-616).** The section measured `is_integer` elision. The ticket extended it to
  the tag test. The brief's finding 4 is right and the wording is fair.
- **RECORDED 26:302 (+14 B)** and 26:309-312 confirmed. The brief's reading of 7.04 vs 8.78 is fair, and it is not a guarded-vs-unguarded
  measurement.
- **Label use.** MEASURED-analogue is used on all p01/p03/p04 rows, which is correct. Dialyzer rows are plain MEASURED, and the
  modules are Erlang analogues of bs_emit shapes, which the p05 header says. Acceptable, but the line "Dialyzer draws the same line" in
  Option 3 is an analogy for a B# design rather than evidence.
- **Not a bsc measurement.** No block is presented as bsc output. The Option 3 wrapper block is a proposal and is labelled hand-derived.
- **CLAUDE.md fit.** The repo rule says to ask the gating question alone, not a matrix of coupled ones. The brief carries four
  sub-decisions (a-d) and a cost matrix. Each option does have B# code plus a compiler delta, so the banned "labelled trade-offs"
  form is partly avoided. But (c) and (d) follow from (a) and (b) and could be left until David has answered the scope question.
  This is a judgement, not an error.

## Corrections needed before it goes to a human

1. Replace the corpus table with the corrected counts (private record 21, public record 41) and fix "about 30 corpus functions".
   Fix the p08 regex to read visibility from the line start, and regenerate `p08_corpus_count.out`.
2. Replace "noise floor <0.1 ns" with "twin medians up to about 0.2 ns on loops, up to about 0.7 ns on single calls". Widen the
   loop range to +7.3 to +8.4. Either drop the "three of four runs / 1.6 ns twin noise" sentence or keep the raw output that shows it.
3. Change `guard_one/8` to `guard_one/7` everywhere. Change "F24/59 say `/5`" to "58/59/68, with 105 already at `/6`".
4. Reword finding 3: the "every call site is checked" premise is the F24/F37/46 §1 gloss of 18 §4, not a sentence in 18 §4.
   Also state that 18:191-195 already noted the exported-to-private path.
5. Add the condition to every "BEAM takes the kind test back" statement: sole proven direct callers only. I measured
   the test kept once a second unproven caller exists or `fun p/1` is taken (both compile to `is_integer` retained).
   The F46 escape case is such a case.
6. Fix the two vacuous evidence statements: Dialyzer nested/escape "silent" was not exercised; the p01 tag KEPT flag matches the body's own
   `map_get`. Also correct the 46 §4 description: list elements are refused by design, not owed. Move the miss list (P5, T1, T5) into the
   brief if the brief keeps a "predictions disclosed" claim.
