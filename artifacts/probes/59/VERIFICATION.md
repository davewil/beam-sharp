# Independent verification of the ticket-59 brief

Verifier work area: `/tmp/claude-0/-home-user-beam-sharp/c0642514-f9d1-5f22-91e2-015f96c1f119/scratchpad/verify59/`
(fresh copy of `probes/59`, symlinked `compiler/` and `aoc/` read-only, `W59_WORK` pointed at a separate build dir; four
bscs rebuilt from the repo source + the author's patches; own builds under `mine/`). Nothing under `compiler/`, `wayfinder/`,
or the author's `out/` was touched; no git.

Host: 4 vCPU, loadavg 1.4 to 5 during my runs. Timeouts: every eunit run had an explicit `timeout` (500 s to 1500 s); none hit it.

## Verdict

**The brief's evidence reproduces. No result in it was found to be manufactured.** Every probe re-ran with 0 failed
assertions, and raw outputs are byte-identical to the author's except path strings, whole-`.beam` file sizes (+200 B
everywhere: longer source path embedded) and timings. Mutation tests went RED where they should. What I found wrong is
framing, denominators and a few places where the brief claims less or more than the data say. All are listed below.

## 1. Re-run of `run.sh` (SKIP_TESTS=1 for p11; p11 done separately in section 3)

`TOTAL failed assertions: 0`. Diff of `out/` (author) vs mine:

| item | difference |
|---|---|
| `build.txt`, `p10/*/files.txt` | absolute path prefix only |
| `p05/files.txt`, `p05/scope.txt` (file= column), `p06/sizes.txt` (file=) | whole-file bytes +200 (+64..+72 for variant files); **Code bytes identical** (the numbers the brief uses) |
| `p05.txt` (author's) | **stale**: lacks the `src/Scope` block (CHANGELOG #11 added it later). Author's `p05/scope.txt` has it. The brief cites `out/p05/scope.txt`, which is right. Mine regenerates both |
| `p08.txt` | `Compiled in 0.74s` vs `0.62s` |
| `p06/bench.txt` | timings (below) |
| `out/p12.txt` | exists in mine, absent in author's (author's p12 dir is identical); `out/p10_run.txt`, `out/run_all.txt` exist only in the author's |
| p02, p03, p07, p09, p10 (census, deltas, totals), p10b, p12 | **identical** |

### Per-probe verdict

| probe | verdict | reason |
|---|---|---|
| p01 | REPRODUCED | emitted `InnerRec` has `map_get('Kind',O) =:= 'Scope.Order'`, `InnerInt` has none, `OuterInt` has `is_integer`. Not circular: the line-284/277 expectations grep `sed -n 275,293p` of the live source, not an echo |
| p02 | REPRODUCED (mutation-checked) | the whole E2 table matches `out/p02/*/run.txt` cell for cell; see section 2 |
| p03 | REPRODUCED | `ex_f` keeps `is_integer`, `lo_f` elided, `un_f` kept, `tag_f` keeps `map_get`+`is_eq_exact`; `call_only` target label 2 = `ex_f` entry label 2; b emits `is_integer` on `InnerInt` and the beam drops it (164 B) |
| p05 | REPRODUCED | tag 12/12/12; int 5, float 3, Octet 12; Scope 164/152/164/152. The awk-column fix (CHANGELOG #2) is a real off-by-one: fields are `case base a b c | tag kind` = $1..$8, so $7/$8 are right |
| p06 | REPRODUCED for the tag test; int/float/range unresolved, as claimed | see section 4 |
| p07 | REPRODUCED | `defp priv_rec` keeps the struct tag test; capture-free `only_proven` loses `is_integer`. The "non-vacuity" pattern `gc_bif,.\*.` is odd-looking but matches `{gc_bif,'*',..}`, so it is a real check |
| p08 | REPRODUCED | Gleam emits nothing at either scope; forged `{wrong,9,9}` -> `{ok,11}` via private; wrong-prediction history is honest |
| p09 | REPRODUCED (cannot run) | `HTTP PROBLEM`, exit 0. Elm claim is not first-hand, as the brief says |
| p10 | REPRODUCED, **with a denominator caveat** | see section 5 |
| p10b | REPRODUCED independently | see section 6 |
| p11 | REPRODUCED on my own builds | see section 3 |
| p12 | REPRODUCED | `Bump(:foo)` -> 0, `Bump(5)` -> 5 on base and b. Note it asserts only the *fixed* state (brief admits this) |

## 2. Mutation tests and my own forged calls (own module, own Erlang driver, my own A and B builds)

I did not use the author's patches for these. I edited `bs_emit.erl` copies by hand: `mine/A` (record branch gets
`{ok,_} when not Public -> {Pat,[]}`), `mine/B` (`none when Public` -> `none`, drop the dead clause), `mine/N` (tag test
removed everywhere). Module `Mine` has `Whole(Order)->Inner(o)`, `Sum(list<Order>)`, `Pair((Order,int))`, private `Inner(Order)`.
Driver: `mine/forge.escript` calls the exported functions with hand-built maps.

| # | claim | result | RED when premise broken? |
|---|---|---|---|
| (a) | forged `Invoice` in a list reaches private `Inner` silently under A, raises under B | base `function_clause` in `Inner`; **A `{ok,14}`**; **B `function_clause` in `Inner`** | M1: same list with a *valid* Kind and a different Total returns `104` under all three (no false alarm). N (tag test removed everywhere): `list_forged => {ok,14}` as expected |
| (b) | forged whole parameter raises in the exported function, not the private one | base, A and B all `function_clause` in `Whole` | **N build: `whole_forged => {ok,9}`** -> the raise really is the exported tag test, so the brief's refutation of the ticket sentence stands |
| (c) | tag test is 12 B, flat in field count | my own modules: F1 / F4 (int, string, int, atom) / F12 all `152 -> 140` (base -> A), 12 B each; plain `erlc` on a hand-written `p(O) when map_get('Kind',O)=:='g1.R'` vs without: 98 vs 86, 12 B | A on a 1-field and a 12-field record are equal -> a field-dependent cost would have shown. **Ticket's +14 is not reproduced by Code bytes**; whole `.beam` delta is ~64..72 B, so neither is 14 |
| (d) | exactly two existing tests go red under B, none under A | my A: 13 guard modules 211/211 pass, **full suite 1312/1312 pass**. My B: 13 modules 209/211, **full suite 1310/1312, the two failures are `boundary_kind_tests:a_private_function_is_not_guarded_test` (:88) and `boundary_range_tests:a_private_function_carries_no_range_guard_test` (:122)** and nothing else. Author's `c` build, 6 modules: the same two red | stronger than the brief: it only claimed 13 modules for a/b/c; the full suite is in fact green under A and exactly-two-red under B |
| (e) | corpus +9 B in 8004, 7 of 24 private functions | reproduced (8004 -> 8013; Foreign 1, Pipeline 3, Ints 1, Pricing 2 = 7). My census mutation: a private record function flips `priv_tag` 1 -> 0 under A and `priv_int` 0 -> 1 / +5 B under B, so the census is sensitive to the thing it counts | **denominator is wrong, see section 5** |
| extra | option C soundness | cycle `F<->G` with an unproven list-element entry: C keeps the tag on `F` and `G`, forged element still `function_clause` in `F`. Conservative, not unsound, on this case | |

## 3. Existing tests (p11)

Author's p11 was not re-run under `run.sh` (SKIP_TESTS=1); I ran the same module list under my own A and B (section 2 (d)), plus the
full suite, plus 6 modules under the author's `c`. The brief's E5 is correct, and its caveat "a/b/c full runs were cancelled" is
now closed for A and B (I got them to finish on a quieter host). Circularity in p11: CHANGELOG #12 admits the assertions were
written after the outcome had been seen. They only guard against drift; my independent runs are the evidence.

## 4. Timing claims

My three rounds (min ns/element; loadavg 4.5 -> 3.9):

| | Base | Base2 | A | B | C |
|---|---|---|---|---|---|
| Totals r1/r2/r3 | 13.39 / 13.27 / 13.31 | 13.43 / 13.36 / 13.46 | 7.92 / 8.22 / 7.99 | 12.34 / 12.36 / 12.29 | 12.27 / 12.41 / 12.42 |
| Weights r1/r2/r3 | 6.25 / 6.23 / 6.21 | 6.22 / 6.25 / 6.21 | 5.44 / 5.37 / 5.49 | 6.79 / 6.81 / 6.81 | 6.79 / 6.81 / 6.95 |

- Tag test: A minus Base = -5.47 / -5.05 / -5.32 ns. **Same conclusion as the brief (+5.3).** Noise floor Base vs Base2: 0.04 / 0.09 / 0.15
  (the author's 0.12 is the same order). Ratio about 35-100x the floor.
- Is the benchmark measuring something else? I disassembled the three beams and diffed them. **Base vs A differ in exactly one place:
  the `map_get 'Kind'` + `is_eq_exact` pair in `Amount`** (the later `map_get 'Total'` loses its `{tr,{x,0},{t_map,any,any}}` type
  annotation, which if anything makes A slower, so +5.3 is a lower bound on the test). The driver loop is the same code for every
  variant. So the tag-test number is attributable.
- **Base vs B differs in more than `Weight`'s guard.** B also puts `is_integer(Acc)` into `FoldWeights` and `FoldTotals` (per
  iteration), and the guard changes the type on the accumulator `+` (`t_number` -> `t_integer`) and the register shuffle
  (`allocate 2,2` -> `allocate 2,4`). That is the likely reason B's *Totals* loop is 1 ns faster than base. The brief's Weights row is
  headed "private `Weight(Octet)` per element", but the +0.5..+0.6 ns it measures is B's whole delta for that loop (kind + range on
  `Weight`, plus acc guards), not the cost of one private `Octet` guard. The brief does say B's Totals result is unexplained and does
  not claim a benefit; it should also say the Weights delta is the sum of several guards.
- "Unresolved for int/float/range": **supported, but conservatively.** B-Base on Weights is +0.54 / +0.58 / +0.60 in all three rounds,
  against a Base-Base2 floor of 0.03; it only becomes "unresolved" because the author invokes a 0.9 ns cross-module layout effect
  taken from `A`, which is *faster* than Base with byte-identical `Weight` code. I would call the sign of B-Base probably positive
  (about 0.5 ns/element for the full B guard set in this loop) rather than "no difference"; the brief's wording is still defensible.
- p06 wording "20 000 calls x 1000 elements = 2e7 visits per rep, 9 reps" matches the script. Ticket 59's "±0.09 ns/call" resolution
  claim is a different harness; not testable here, so the brief's "not reproducible with this method" is fair.

## 5. Corpus claim: `7 of 24 private functions` is mis-denominated

`census.escript` counts every non-exported function in the emitted forms except `bs@type_atoms`. Listing them
(`verify59/privs_base.txt`) shows **8 of the 24 are compiler-generated**: `Intake:bs@validate@1/2`, `@1@e/3`, `@2/2`..`@5/2`, `@1@r/1`
and `Shop.Pricing:bs@List@flip/1`. User-declared private functions: **16**
(matches my regex count of `private` signatures, 15, plus `Aliasing.Score`, which has no `private` keyword; the language default is
private, LANGUAGE.md:53). So it is **7 of 16 user-written private functions** (44%), not 7 of 24 (29%). The +9 B / 8004 and the "7
functions in 4 modules" are correct; "24" is not what a reader assumes. "No private function in the corpus has a record parameter":
true (checked: `Build((int,atom))`, `Prepend<T,E>`, `Describe(Res)`, `Score(:ok|:error)`, none a single closed record).

## 6. Exemplar regex estimate (64 private, 8 record, 4 int)

Independently recomputed with my own parser (`private` lines, top-level comma split, record names per directory):
**64 / 8 / 4, identical**. No bare (visibility-less, hence private-by-default) signatures exist in the exemplars, so there is no
undercount from the missing-keyword case. Two wording points: "8 have a **single**-record parameter" is loose (several of the 8 take
two or more record params, e.g. `Call(Model m, Send send, string token, Json state, list<(string, Question)> qs)`); and one of the
4 ints is `Opcode Opcode(int)` with an unnamed parameter. The regex is not the compiler (the brief says so).
`25e/rows.bs` quote is accurate (`Rows([o, ..rest], acc) -> Rows(rest, [Row(o), ..acc])`, private `Row(OrderRow o)`).

## 7. Citations

| cite | status |
|---|---|
| `bs_emit.erl:163` Public, `:275-291` guard_one, `:277` record branch, `:284` `none when Public`, `:289` fall-through, `:265` boundary_guards/6, `:296` float_guard, `:330-333` comment, `:159-164` | all correct |
| `beam_types.hrl:113-116` | correct |
| `beam_ssa_type.erl:122-123` | correct (text is at 122-123); `:428-433` lands on 429-432 (comment) and `:434-438` on 435-436: off by one to three lines, content right |
| `sys_core_fold.erl` "grep finds nothing for `exported`" | I got no hits either |
| `LANGUAGE.md:3576-3577` | correct |
| `boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122` | correct (function heads) |
| `46-refined-parameter-at-the-boundary.md:213-222` (§4), 18:194-196 | correct (`## 4.` at 213; 194-195 for the quoted sentence) |
| ticket 46 quoted comment "gone from source" | confirmed: only tickets 46 and 59 contain it |
| `compiler/features/F24` section numbers (§2, §6, F24.6), F37.5 | not rechecked line by line |
| "`boundary_guards/5` in the ticket vs `/6`" | ticket 59 line 21 says `/4`, not `/5` (the `/5` appears nowhere I looked): trivial wording slip in the brief's §7 |

## 8. Claims that are unsupported, mis-stated or incomplete

1. **"A forged value is one projection down" is wider than the brief says.** The brief ties the hole to collections
   (46 §4 "never through a collection"). I forged a **tuple element** (`Pair((Order,int))`) and a **record field**
   (`Wrap { Inner: Order }`, `Go(w) -> Pick(w.Inner)`): the exported function does not test the nested tag; base raises in
   `Pick`, A returns `{ok,10}` / `{ok,9}`, B raises in `Pick`. 46 §4 says tuple elements and record fields are *within* the
   guarded depth for the refined int, so that hole is not "by decision". This strengthens the recommendation but the brief's
   explanation of why the private test is the only defence only covers collections.
2. **Brief §4 Weights row** is a sum of guards, not `Weight`'s alone (section 4 above).
3. **"7 of 24 private functions"** (section 5): 16 user-written, 8 compiler-generated.
4. **E5 "a green (nothing pins the private tag test)"** was claimed on 13 modules only; true for the full suite (my run), so the
   claim stands, but the brief's text had no evidence beyond 211 tests.
5. **C: "red on the same two as B"** rests on the author's p11 run only; I confirmed it on 6 modules (66 tests), not the full suite.
6. **Option C's elision soundness** is exercised only by the author's programs; the one adversarial cycle I tried was safe.
   The ~230-line patch was not audited line by line.
7. **`out/p05.txt` is stale** relative to the script (missing the Scope rows); the numbers are in `out/p05/scope.txt`.
8. **`+14 B` refutation**: Code-chunk bytes give 12 under three independent harnesses (author's, mine, raw `erlc`). If 26a counted a
   different quantity (e.g. an extra `{line}` or a label) the brief cannot say which; it already lists this under "could not verify".
9. Neighbour surveys: Elm unverifiable (acknowledged); Elixir/Gleam are generated-code behaviour (acknowledged).

## 9. CHANGELOG judgement

| # | judgement |
|---|---|
| 1 C11/C12 added after first p02 run | legitimate (new route, not a change to an old assertion); outcomes match my own independent forge of the same shape |
| 2 awk columns | legitimate script bug (checked) |
| 3 label-equality assertion | legitimate strengthening |
| 4 `only_proven` | legitimate, and the non-vacuity guard is sound |
| 5 p08 wrong prediction | legitimate and honest; replacement claims are weaker and match the output |
| 6 / 8 dedupe by module | legitimate; the first dedupe edit did not apply and the log says so. My re-run shows 27 distinct modules for 27 dirs |
| 7 copy `aoc/` | legitimate (environment artefact) |
| 9 / 10 p11 cut to 13 modules | a scope reduction, disclosed. Not manufactured; my full-suite runs agree with the 13-module result |
| 11 Scope rows, 3 bench rounds | legitimate; earlier single runs (+5.1, +5.0, +7.1) cannot be checked, my three rounds agree with the kept ones |
| 12 assertions added after the p11 outcome | the assertions are post-hoc by admission; no weakening, and the outcome is independently reproduced |

No edit was found that changes an expectation to fit an output. The patches are small and structural: A is two lines, B is a net
deletion; neither special-cases the probe programs. Baselines differ from variants only by the patch (same source, same OTP).
No `|| true` is load-bearing: the only one (p07, a slice loop) is followed by re-derived slices that are asserted. No error is swallowed
(`p02` exits on a compile failure). Greps run on tool output or live source, not on the author's `echo`.
Circular-by-construction items I looked for and did not find: the only expectations written after seeing data are CHANGELOG #3, #5,
#11-#12, all logged.
