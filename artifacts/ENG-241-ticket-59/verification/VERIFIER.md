# Verifier report, ticket 59 (ENG-241) brief

Independent re-run, OTP 25.3 / Elixir 1.14, same container. Fresh build: repo `compiler/{src,rebar.config,rebar.lock}` copied to
`scratchpad/verify59/A`, the author's lexer shim applied with `patch` (result byte-identical to the author's shimmed `bs_lexer.xrl`;
`rebar.config` = warnings_as_errors replaced by nowarn_export_all and the `xrl_opts` line removed). B and C = A plus the two emitter
patches. Probe copies re-pointed at these builds; author files untouched. Fresh outputs are `*.rerun.out` in this directory.
Note: `p1/p2/p6 .rerun.out` here were already tracked from an earlier pass (the committed p6 was truncated before the counts); I
overwrote them with complete output.

## Build and patch checks

- `A/src/bs_emit.erl` vs `compiler/src/bs_emit.erl`: **identical** (diff empty). Claim holds.
- `diff -u A B`: exactly the brief's change (`none when Public ->` becomes `none ->`, dead `none -> {Pat, []}` clause deleted). Minimal; one real line.
- `diff -u A C`: exactly one added line, `{ok, _} when not Public -> {Pat, []};`. Minimal. Implements Option 1 as described.
- Caveat: the shim gives every token location `{Line,1}`; `Signalbox` fails with that (see c).

## Per-probe table

| Probe | Reproduced? | Verdict |
|---|---|---|
| p1 emitted guards | yes, byte-identical | Non-vacuous (asserts 1 guard-list found per function; true and false expectations both present). Sound. |
| p2 forged values | yes, identical | (a) exported `TotalOf(forged)` and `BigOf(100.5/300)` refused; `SumTotals([forged])` refused; stripped `Total` gives `5`; `SumBig([100.5])`, `SumBig([300])` give `1`. All brief claims (a),(b) stand. The stripped counterfactual is true by construction (remove the only test, forged value passes); it shows consequence, not discovery. Real evidence is the unstripped refusal. |
| p3 bytes / erlc | yes (identical numbers: +12 B, +9 B, erlc keeps tag test, drops local `is_integer`, keeps it for list element) | Sound. Test programs are hand-written Erlang, not bsc output. |
| p4 call time | yes, direction reproduced, **magnitude not** | See (d). |
| p5 Elixir | yes, identical | Sound. |
| p6 corpus | yes, identical (A 48/B 67 source `is_integer`, 44/44 insns, 9599 B; tag 9/9) | Measure is non-vacuous (see c) but corpus biased; Option 1 "removes 0" is **wrong beyond this corpus** (see c). |
| p7 nested survives | yes, identical (B: 2 insns, refuses; A: 1, accepts) | Sound, but it is the one case designed to survive, so it proves existence, not frequency. |
| p8 private as value | yes, identical to EXPECTED | Sound. EXPECTED printed beside outputs is a prediction that matched, not a tautology for A/B; C's `5` is by construction. |

## (a) Exported pass-through already closed: STANDS, with a scope limit

Reproduced for a directly typed exported parameter. It does not cover a value that reaches the private call by a path the exported
head does not test. I added a probe (`extra_nesting_and_fun_escape.out`): the nested claim is not list-specific. A record **field**
reaches a private function untested too: `Use({Kind=Cell, V=300})` and `V=100.5` return `1` under A, refused under B; a forged
`Order` inside a `Wrap` field is refused under A (tag test on private) and returns `5` under C. Ticket 18:194-195 ("a foreign value
entering through an exported function reaches private ones unchallenged") is therefore **true for nested values**, so the brief's
phrasing that the ticket's exported-to-private argument "was already closed" should read "closed for direct parameters only".

## (b) Nested-value claims: STAND (p2, p7, p8, plus field-nesting probe above)

`SumBig([100.5])` and `SumBig([300])` return 1; `SumTotals([forged])` refused only because of the private tag test, 5 with it stripped.

## (c) 19 added guards, 0 surviving: reproduced, but the corpus is biased and the "0" is a property of the corpus

- Non-vacuity: A has 44 `is_integer` insns, B adds 1 in P59 (p7) and in my `x3` probe (`private Big` also handed out as a fun keeps its test; `x2`, no fun, drops it). So the counter detects survivors; the author's earlier-bug fix is real.
- Which 19: `Fib.Series/4` (6), `Foreign.Fallback` (2), `Frame.Classify`/`Name` (2+2), `Pipeline.Twice/Validate/Charge/Confirm` (1+2+1+1), `Shop.Collections.Ints.Length` (2). Arguments are arithmetic results, binary-pattern segments, or values from an already-guarded exported parameter, all provable by erlc. **No corpus case passes an untested element, record field, or fun-escaped function into a private int function.** The "0 surviving" therefore reports that the corpus never exercises the case where the guard does work, which is exactly where Option 2 pays. This is not circular (it could have been nonzero) but it does not support "costs 0 in general".
- Exclusions, and the brief's "I did not investigate why" is answerable:
  - `Signalbox` (62 lines): fails under **A as well** with `erl_anno:anno_info({{14,24},1},location)`, an artifact of the lexer shim's fake columns. Not a language property.
  - `exemplars` is a **namespace, not a module** (`bsc: examples/exemplars is a namespace`); README says none/most do not compile by design. It is 1255 lines of the 2739 total `.bs` lines under `examples/` (46%; with Signalbox 1317, 48%): nearly half the lines were excluded, the largest real programs. 25f and 25g do compile with bsc if staged as the exemplar's `module` line expects (`Support/Triage`, `Jev`, `Triage`); 25e fails the checker (`List.Reverse` argument), same under A/B/C.
- I ran the 6 modules from 25f/25g under A/B/C (`extra_exemplars_and_corpus.out`): **B: +0 source guards, +0 insns** (no private int params). **C: tag tests 17 to 12, Code 22772 to 22694 B (-78 B), `is_eq_exact` insns 143 to 138.** So the brief's "Option 1 removes 0 tests... invisible to the gates" holds only for the 22 small examples; on the larger programs Option 1 removes 5 of 17 tag tests, which the brief's own limits section guessed ("may not hold there") but the Option 1 evidence line states as fact. Option 2's zero-cost claim is not contradicted by exemplars (no data either way).
- Is erlc removing guards "in a form it can always see through"? No: the guard is the same `is_integer` in both cases; erlc keeps it for list elements (p3, p7) and for private functions whose fun escapes (my x3). It sees through only when all call-site argument types are proven. So not an artifact, but the corpus supplies only the provable case.

## (d) Timing: direction reproduced, brief's number is not robust; contradiction with ticket 26 is partly a misreading

Five fresh runs of p4 (x4 cores, load average ~1-3), `p4_call_time.rerun.out`:

| Quantity (ns/call) | per-run values | median of runs |
|---|---|---|
| tag guard minus none, using **min** | 6.7, 5.8, -0.4*, 6.1, 5.6 | 5.8 |
| tag guard minus none, using **median** (author's stat) | 15.8, 16.4, 10.5, 11.3, 18.0 | 15.8 |
| tag identical-copy noise, min | 17.5*, -0.2, -7.5*, 0.8, -0.4 | -0.2 |
| tag identical-copy noise, median | 7.3, -9.6, 4.4, -0.1, -9.8 | -0.1 |
| is_integer guard minus none, min | 0.2, -2.8, 0.7, 1.3, 0.4 | 0.4 |
| is_integer guard minus none, median | -0.1, -2.5, -0.3, 0.2, 4.8 | -0.1 |

(* a run where one copy fell into the slow mode.) The box is bimodal: per-copy medians flip between ~14 and ~25-40 ns with identical code,
so the median-of-51 statistic has a noise floor of 7-10 ns in this rerun, comparable to the author's "+8.8..+11.3, noise <= 3". The author's
runs sat entirely in the slow mode (their medians 25-45, mins 12-19). **Min-based tag cost is about 6 ns (4 of 5 runs), not 9-11.** The
int result (about 0, inside noise) reproduces robustly. Brief should say "about 6-11 ns on a one-lookup body, box bimodal" and not claim a
noise floor of 3 ns.

Contradiction with ticket 26: ticket 26 line 310-313 states 7.04 ns (tuple, guarded) vs 8.78 (tagged map, guarded) and concludes "the tag
itself costs nothing measurable". That compares **two guarded representations**, not tag-test versus no test; the same prototype
(26a) also has `map map_get unguarded` and `map_get guarded` rows. I re-ran 26a (`ticket26_26a_rerun.out`): unguarded map 12.60,
guarded map 16.82 (+4.2 ns, noisy), consistent in sign with p4. So the sentence in 26 is about tagged-vs-tuple, and the brief's
"is not reproduced" framing is an apples-to-oranges comparison. The cost of a tag test versus none is real and about 4-6 ns by min;
26's text, read narrowly, is not wrong. Soften to: "26's 'nothing measurable' compares two guarded forms; the guard-versus-none delta was not
stated in 26's text."

## Citations checked

Correct: `bs_emit.erl:274-290` (guard_one), `:274-276` (record_tag), `:140` is_public; `18-boundary-defence.md:499` (C row), `:446-450` (Elm
1e300), `:~497` (Gleam row A), `:817` (quoted exported-head wording); F24 section 2 "Exported only" (line 115) and F24.6 (line 229);
F3-records.md 252-260, 460; ticket 46 line 129 (`Inner(Order o)` receives tag test); `beam_ssa_type.erl:119-121`, `:432-440`
(OTP 25 compiler-8.2.6.3 source). Not wrong, only incomplete: ticket 18:194-195 is the real source of the exported-to-private argument and is not
cited. Elm and Gleam rows are RECORDED (labelled so). No MEASURED/RECORDED mislabel found: the OTP 28.5 and arm64 figures are all
labelled RECORDED.

## Circularity and weak spots

- p2 (a') and p8 variant C: results follow by construction of the counterfactual; they are illustration, not evidence. The brief uses them as such but lists them under MEASURED.
- p6's `C removes 0` is correct for its 22 modules and misleading as a general statement (exemplars: -5).
- p7: designed to be the survivor case; shows existence only.
- p4: median statistic fragile on this box; use min.
- p3 `int_none` clause bodies differ from `tag_none`; compare within pairs only (the brief does).
- Not tested by anyone: a private function whose argument comes from `receive`, ETS, JSON decode; union-of-records parameters; lambdas.

## Verdict

Stand as written: toolchain/emitter-identity claim, patch minimality, p1, p2 (a)/(b), p3 byte and erlc claims, p5, p7, p8, all citations, and the
recommendation's logical core (nested int is silent under A; Option 2 closes it; erlc removes the provable case).

Must be softened:
1. "Option 1 removes 0 tests / invisible to the gates": true for 22 small modules only; 25f/25g lose 5 of 17 tag tests (-78 B).
2. "0 surviving instructions across the corpus" must be stated as corpus-specific: no corpus case feeds an untested value to a private int function; it does not estimate Option 2's cost on real code.
3. Corpus exclusion explanation: Signalbox = shim artifact; exemplars = namespace, about half the `.bs` lines, partly compilable; rerun with 25f/25g staged.
4. Tag-test timing: "+9-11 ns, noise <= 3" becomes "about 6 ns by min, 10-16 by median, box bimodal with 7-10 ns median noise".
5. "Contradicts ticket 26": 26 compares two guarded forms; reword as above.
6. "Exported pass-through already closed": add "for directly typed parameters; nested list elements and record fields reach private functions untested" (confirmed for fields too).
7. Section 2 claim that 18's sentence is "false for a nested int" should note it is undecided whether 18 §4 intended element coverage (the brief already says so); fine.
