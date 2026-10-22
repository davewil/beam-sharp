# Verification of 64-term-collapse.md

Verifier run 2026-10-22. All probes re-run from empty caches into `/tmp/claude-0/verify64/` (the build scripts honour `BSC_WS`, `BSC_WS_TAGGED`, `BSC_WS_CALLSITE`, so I never touched the author's `/tmp/claude-0/ws64-*`). Repo `git status` stayed `?? artifacts/` only. Raw outputs: `/tmp/claude-0/verify64/o01.txt`, `o02-*.txt` ... `o08-*.txt`.

## Overall verdict

The brief's measurements reproduce. I found no manufactured result in the OTP-25 patches. The patches touch the rebar option, `~kp` and token columns; the checker and emitter are the repo's.

The brief's conclusions are weaker than its prose in four places:
1. The call-site refusal prototype is incomplete, and the recommendation's "~25 lines at one call site" understates that.
2. "2 of 25 break" for Option 1 rests on a half-built Option 1 and a sample that barely uses `option<>`.
3. The P07 "within noise" label is wrong. The difference is stable and favours tagged.
4. The Gleam neighbour evidence is a hand-written function, not Gleam's lookup.

The recommendation (Option 3 plus the refusal) is still supported where it matters. The tagged form is correct on today's compiler and the hole is real. The "why" evidence is partly circular or unsupported, listed below.

## Per-probe verdicts

| Probe | Verdict | Notes |
|---|---|---|
| P01 four signatures | REPRODUCED | Identical output. FindR/FindT are refused, FindF/FindI survive. It can go red: FindR/FindT exit 1. |
| P02 result matrix | REPRODUCED, can fail | 14 rows identical, with both accept and REFUSE outcomes, so the verdict is a real compiler exit status. See "Q3 thinness" below. |
| P03 inferred instantiation | REPRODUCED and independently re-confirmed | See hole tests below. |
| P04 three programs | REPRODUCED, partly cannot-fail by construction | See below. |
| P05 neighbours | REPRODUCED, with one CIRCULAR component | See below. |
| P06 blast radius | REPRODUCED (35 dirs, 25 ok under both, 2 newly refused, 8 failing at baseline, 33 lines, 10 files). The conclusion is overstated. | See below. |
| P07 runtime cost | REPRODUCED (flat_size 0/3/6/9/0/0 exact). The "noise" label is MISMATCH. | See below. |
| P08 stale premises | REPRODUCED, but the (b) grep is weak evidence and the (a) grep is weak. | See below. |

Probe 04's Opt2/Opt3 results are identical across base, tagged and callsite builds. Opt3 uses an explicit tagged alias and Opt2 uses `Map.Has` first, so neither could collapse. They show only that a hand-tagged program works, which is the claim. The real negative control is Opt1 under base, and it is refused, so it can go red. There is no control showing a bare, ambiguous program compiling and giving a wrong answer for the `PresentNothing` input. That control exists only in P03, for generics.

### Independent tests of the headline falsifications

**(a) Generic `Head<T>` over `list<term>` collapses silently with a wrong runtime answer: CONFIRMED.**
- I wrote my own program, `/tmp/claude-0/verify64/t1/X/X.bs`, with a nested generic wrapper, a direct return and an argument position.
- Base compiles with rc=0 and no diagnostic.
- `HasFirst([:nothing])` returns `:false` although the list has an element.
- `ViaArg([:nothing])` returns `:true`, the same defect seen from the other side.
- Under the tagged build the same logic, rewritten with `(:some, x)`, is correct: `T1` gives `true`, `T2` gives `false`. This backs the claim that Option 1 closes the hole without a new check.

**The refusal prototype is incomplete (not reported by the brief).**
- It checks only a top-level `t_union` return.
- In `/tmp/claude-0/verify64/t2/Y/Y.bs`, `list<option<T>> Heads<T>` and `(option<T>, int) Pair<T>` called at `list<term>` compile under the callsite build (rc=0).
- They give wrong answers: `CountAbsent([[:nothing]])` returns 1 (absent) and `PairAbs([:nothing])` returns 0.
- So "close the inference hole in ~25 lines at one call site" is true only for top-level `option<T>`/`result<T,E>` returns. The brief's Limits do mention "records/nested generics not explored", but §7 states the fix as settled.
- The brief says it did not check the prototype against the tree. I did:
  - All 35 example dirs give byte-identical output and exit code under base and callsite builds (0 diffs).
  - `rebar3 eunit` under OTP 25 fails 182 tests with the same failing set under both builds (1316 pass in each), so the prototype causes no regression.
  - That is weak, because the failures are OTP-25 and column artefacts. The tree and tests contain no generic-at-`term` instantiation.
  - One possible false positive: `Raw(xs) -> Head(xs)` returning `term` is also refused. This is arguably right, but the brief never says the refusal fires where nothing is discriminated.

**(b) Option tag change breaks exactly 2 of 25: COUNT REPRODUCED, CONCLUSION MISLEADING.**
- Only Levels and Parcel are newly refused.
- Of the 25 dirs that compile under both builds, only Levels, Parcel and Names mention `option<` as code or comments. Names mentions it only in a comment. The sample says almost nothing about `option<>` migration cost.
- The brief itself says the option-heavy exemplars (25d/e/f) cannot be compiled. §6 also says "seven exemplars that actually use `option<>` heavily (25d/25e/25f)". That is three directories, and seven is the total number of exemplars.
- The Levels failure is manufactured by the half-built prototype. The tagged build leaves `ParseAtom` emitting a bare `:nothing`. If `ParseAtom` also returned tagged, `Parse(s) -> ParseAtom<Level>(s)` would need no change. §6 text "Levels' Parse ... stop compiling and need `(:some, …)`" holds only if ParseAtom stays bare. The brief's Limits admit "not a finished Option 1", but the "2 broken" figure is quoted as the cost in §7.
- The one true break is Parcel (`Weigh(p) -> p.Note`).

**(c) "No PRELUDE.md; ToExistingAtom built tagged": CONFIRMED.**
- `find` shows only `wayfinder/research/prelude-the-word-across-languages.md`, so there is no `PRELUDE.md` in the tree.
- `bs_emit.erl:949-957` emits `{error, Name}` from a caught `badarg`.
- Ticket 97:59 reads "`ToExistingAtom` returns `result<atom, string>`".
- P08's `grep "the failure is"` hits a diagnostic message string. That is a doc string, not a type, so it is weaker evidence than the emitter and ticket 97, which do confirm it.
- The brief says "(ticket 97:59 says the same)" and that is correct.
- Commit `96fc0b2`, which CLAUDE.md names as holding the old tracking layer, is not in this clone. I could not check whether a PRELUDE.md ever existed. I only confirmed it does not now.

**(d) "`as T` unbuilt": CONFIRMED, weak probe.**
- `d as int` gives "syntax error before: as".
- My own grep of `bs_lexer.xrl` and `bs_parser.yrl` for the word `as` finds only comments.
- P08's grep pattern (`'as'\|^as `) is narrow; my broader pattern agrees.
- `ValidateAs` and `ParseAtom` exist, and ticket 08:251 says `as T` yields `T | :nothing`. The brief's reading, that the cost is a decision rather than code, is fair.

### Other probe findings

**P02 / Q3 thinness.**
- The conclusion "collapse is a function of T, never of E" survives my extra 17 rows. I ran string, bool, float, binary, `(int,int)`, `(term,term)`, `(:error,term)`, `tuple`, `list<atom>`, `fn`, `int|:error` and other `T` at `E = term`.
- Rows that hold `(:error, E)` are refused; the rest are accepted.
- The brief's 14 rows cover `T=term` and a few tuple tops, which is enough to state the rule.
- P02 tests only the declared identity function `F(x) -> x`. It never tests inferred `E=term` or `T=term`.
- I wrote a generic `Wrap<T>(T x) -> result<T, term>` and called it at `T = term`. It compiles silently and gives an answer that conflates success with failure: `D((:error,1))` returns `"err"`.
- So "Q3 closed by P02" is true for the declaration rule, but the same inferred-instantiation hole as P03 applies to `result<T, term>`. §7 says closed without that caveat, though P03 does show a `result` variant at `E = atom`.

**P05 Gleam is CIRCULAR.**
- `gl1.gleam` defines its own `find`, so the probe shows that nested `Result` values nest. It does not show what Gleam's stdlib lookup returns.
- The brief admits `gleam_stdlib` is not installed and says "A lookup is `Result(v, Nil)`". That is from knowledge and not labelled as such, unlike Elm.
- The "Pattern across all four" in §4 therefore rests on Erlang and Elixir only (verified) plus two unverified neighbours.

**P05 Erlang/Elixir:** The ambiguity shown (`maps:get/3` and `Map.get/2` return the sentinel for both present and absent) is real and can go red. All Erlang and Elixir citations check:
- `maps.erl` lines 53, 60, 285-291.
- `lists.erl:77`, `proplists.erl:130`.
- Elixir `Map.fetch` at 300, `fetch!` at 318, `get` at 525, `has_key?` at 281.
- Elixir doc strings match.

**P07 "within noise" is MISMATCH.**
- I ran it 4 times (the author's single run plus mine). LoopTagged/LoopBare was 0.94, 0.94, 0.93, 0.92.
- Raw times: bare 175-179 ms, tagged 162-168 ms. The 6-8% advantage for tagged is stable. Spread within a loop is about 1%.
- The brief says "within noise... tagged never slower". The claim "no cost" survives.
- The ratio shows an unexplained effect, probably JIT or inlining. There is no control (bare vs bare, or a shuffled order) to establish a noise floor.
- §7's "at no measurable cost" is fine; the explanation ("because `maps:find` already allocates `{ok,V}`") is unsupported speculation.
- The suggestion that a lookup row could return the `maps:find` tuple as is cannot be right for `(:some, V)`. The emitted code allocates `{some,V}` from `{ok,V}`. It would work only with an `:ok` tag, and the brief acknowledges that as a naming question.
- Heap words (3 per hit) are exact and reproducible. They match `erts_debug:flat_size`.

**P06 baseline.**
- The 8 baseline failures are the 7 exemplars plus Signalbox. Signalbox mentions no `option<>` (0 matches), but I did not determine whether its `ModelKey` failure is real or an OTP-25 artefact (the brief already says it didn't either).
- The brief's claim that the scratch build matches FRONTIER "line for line on all seven" is not a probe output. P06 only prints the baseline first lines.
- I compared them by hand and they match, except that 25g carries an absolute path.

## Citations

| Citation | Result |
|---|---|
| `bs_check.erl:1351-1353` (`stratum_one`) | OK |
| `:1111` (`collapse_decl`), `:1164` (`scan_ty`) | OK |
| `:1015` (`subst_tpl` `t_union`) | OK |
| `:1221` (`failure_channel`) | OK |
| `:3424` (`absorbed/2`) | OK |
| `:3455` (`ParseAtom` type) | OK |
| `:4427-4433` (`checked_call_typed/7`) | OK |
| `bs_check.erl:1708-1747` `standard_table`/`declared_rows` has `Map.Has` and no `Get`/`Find`/`First` | OK. grep of `'Get'`, `'Find'`, `'First'` across `src/*.erl` is empty. |
| `bs_diag.erl:1973` hint | OK |
| `bs_diag.erl:1697` | OK |
| `bs_emit.erl:996` (`ParseAtom` bare `nothing` arm) | OK |
| Ticket 64 quoted text ("Not measured", "PRELUDE.md still records `ToExistingAtom` as owed...", "neither chosen") | OK |
| Ticket 64 Q1 and Q4 narrowing by 68 | OK |
| Ticket 68 Q1 "(a). An absorbed member is an error where it is written" | OK |
| Ticket 15 §1 "Why not simply tag both channels... showcase" (lines 216-222) | OK |
| Ticket 15 "known limit" (line 321-323) | OK |
| Ticket 15 §4 `atom \| (:error, binary)` does not collapse (line 624-630) | OK |
| 96:224 "`Find` → `option<V>` (`maps:find`)" | OK. The row is `Get` (ENG-324) plus `Find`. The brief attributes the "second form returns `option<T>`" to 108 and the 108 header text matches, so OK. |
| 108 header (line 20-21) | OK |
| 08:251 | OK |
| F31 S5, S7, S10 | OK |
| 97:59 | OK |
| 25f `route.bs:19` Lookup | not checked |
| `25g-jev-server/triage_index.bs:38-40` | not checked |

## Unsupported or overstated claims

1. §7: the refusal "is ~25 lines at one call site". Shown only for top-level `option<T>`/`result<T,E>` returns. My nested and tuple tests escape it.
2. §6/§7: Option 1 "breaks two compiling examples (P06)". It counts an artefact of the unfinished `ParseAtom` change, and the examples barely use `option<>`.
3. §7 Q3 "closed by P02". True for declarations; the inferred-instantiation hole applies at `E = term` as well.
4. §4/§7 "Every neighbour that has a `term`-like top tags the lookup". Gleam's stdlib and Elm's are not verified; the Gleam probe is a user-written function.
5. §5/P07 "noise level". It is a consistent ~6% tagged advantage with no noise control.
6. P07 "A lookup row whose OTP target is `maps:find` could return the tuple it was handed". Not tested, and the emitted code does not do so for `:some`.
7. §6 "seven exemplars that actually use `option<>` heavily (25d/25e/25f)": inconsistent count.
8. "Option 2 refusal with no false positives": untested beyond one T=int control. Mine found 0 diffs over the tree, but the tree has no generic `option<T>` call at `term`, so that is no evidence in either direction.

## Verdict

PASS WITH CAVEATS. Every raw output matches. The headline claims (a), (c) and (d) re-confirm independently, and (b) re-confirms as a count but not as a cost estimate. The two caveats a decision-maker would most want fixed are #1 and #2 above.
