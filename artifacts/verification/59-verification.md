# Verification of the ticket 59 brief (ENG-241)

Verifier run 2026-10-08/09. Everything rebuilt in `/tmp/verify59/` (own compilers: stock, A, B, C, D, E from `build-bsc.sh` plus the author's patches; probes copied and their hardcoded `/tmp/bsbuild`, `/tmp/bsb_59_*` paths rewritten). No file under `compiler/`, `wayfinder/`, the brief or the probes was edited. No Linear, no commit.
Environment: OTP 25.3, Elixir 1.14.0, 4 vCPU Xeon 2.8 GHz, lexer shim (columns wrong), no rebar3, no Gleam.

## Verdict: PASS WITH CORRECTIONS

Every measured table in the brief reproduces. The empirical core (what is emitted, which forged values get through under A, which are stopped under B/E, the eunit set difference, the byte costs, the corpus elision) is sound and I found no circularity that changes a result. Corrections are needed to one textual claim (ticket 18's "self-contradiction", which the recommendation leans on), to the timing section (W1 miscounted, "kind test below noise" too strong), and to a few scope statements.

## Reproduced

| # | Claim | My result | Match |
|---|---|---|---|
| 1 | Patches A, B, C, D, E are diffs against `compiler/src/bs_emit.erl`, apply cleanly | all 5 applied with `patch -p0`; 15 beams each | yes |
| 1a | A = `{ok,_} when not Public -> {Pat,[]}` (+1 line); B = drop `when Public` and the `none ->` fallback (-3); E = A + `Public = is_public(F) orelse member({Name,Arity}, address-taken)` | read all five; `fnames` is keyed by `e_fname` use sites (`bs_check.erl:126,164`; `bs_emit.erl:1073`), so it is "address-taken" only, and `element(2,F)`/`arity(F)` are the same name/arity pair `name/2` uses (`bs_emit.erl:118,138`). `{q,...}` (4-tuple) values are skipped by the `{N,A}` generator, as the brief admits unchecked | yes |
| 2 | `a.sh`: Handle/Inner tag test; DoubleP kind test, Double none, Band none | `a.mine` byte-identical to `a.out` | yes |
| 3 | `forge.out` (base, A, B, E) | byte-identical | yes |
| 3 | `kinds.out` (base, B, E) | byte-identical | yes |
| 3 | `nest.out` | same results, only `~p` line wrapping differs | yes |
| 4 | `elision.out` | byte-identical (`Inner` abstract=yes beam=no under B; `Cap` beam=yes; `Tot` yes/yes) | yes |
| 5 | Code bytes (`size.out`) | Code column identical in all 11 rows (tag 88 to 100 and 119 to 131 for 1/3/8/16 fields; kind +5; pass-through +0). `.beam` file bytes differ by 4 to 20 (build path in debug info), which is why the brief says to use Code | yes |
| 6 | 26a +14 on OTP 25 (`26a-rerun.out`) | the file is the author's output of the unmodified `26a` prototype; I did not rerun it, but see 12 vs 14 below | n/a |
| 7 | eunit: 34 tests in `records_tests`, `boundary_kind_tests`, `boundary_range_tests` | stock 34/0, A 34/0, B 34/2 failed, E 34/0 | yes |
| 8 | Full suite set difference | see (c) | yes |
| 9 | Corpus: 77/12, B adds 19, 0 survive (47 vs 47) | `corpus.out` identical after I recompiled the 22 modules (Pipeline needs `--src-root .`; the author's invocation is undocumented); `survive` 47 vs 47 | yes |
| 10 | `census.out` | byte-identical | yes |
| 11 | `elixir/neighbour.out` | byte-identical | yes |
| 12 | Benchmark 8 ns tag test | 11 runs, see (e): 8.6 ns | yes (slightly above) |

### (a) Signature and the ticket-18 "contradiction"

- `boundary_guards/6` is correct: `compiler/src/bs_emit.erl:265` `boundary_guards(Patterns, Params, Line, Ctx, Public, Accepts)`. `Public = is_public(F)` is at `:163`. The record branch `{ok, Tag}` is `:277` and never reads `Public`; `none when Public` is `:284`. Ticket 59 says `/5` (`59-...md:11`), ticket 58 `/5` (`58-...md:166`), F24 `/5` (`F24-boundary-kind.md:123`), ticket 46 `/4` (`46-...md:55,128,247,297`). Confirmed. Ticket 59 line 15 itself still says "nothing consults `is_public/1`".
- **"Ticket 18 contradicts itself at :194" is NOT supported.** `18-boundary-defence.md:194` sits in "Constraints from ticket 12" (`:172-200`), and the paragraph is about omitting the compiler's *failure arm* (ticket 12's 40 bytes). Quote, `:191-196`: "If it decides not to, the arm stays everywhere ... Restricting omission to non-exported functions is *not* an alternative — a foreign value entering through an exported function reaches private ones unchallenged. It collapses into the guard question." The sentence is conditional on no exported guard. Its own preceding sentence (`:190-192`) says that *with* exported guards "internal omission becomes sound". That is the same position as §4 (`:817`) and §1 (`:439-441`), not the opposite. It is a useful analogy (an exported guard that does not walk aggregates leaves private functions exposed) but it is not a self-contradiction and not a "resolved text" about guards on private functions. Brief §2.5 and Recommendation point 3 ("already contradicted inside ticket 18 (:194)") must be reworded.
- §4 `:817` ("looks at the exported function's own clause heads and body, and no further") and §1 `:439-441` ("interior functions already pay nothing") are correct as cited.

### (b) The four shapes under A, with controls, and whether each is a real wrong result

Reproduced (mine, `forge.mine`/`nest.mine`):

```
== emitter A
  Handle(forged)  [exported rec param]         {error,function_clause}      <- exported test still stops it
  Unwrap(#{Item=forged}) [nested field]        {ok,100}
  Totals([forged]) [list elem]                 {ok,"d"}
  Sum(#{Orders=[forged]}) [lambda->Inner]      {ok,100}
  Picker(x)(forged) [escaped private fun]      {ok,100}
  Totals([genuine]) [control]                  {ok,"d"}
== emitter base / B / E   (same calls)
  Unwrap / Totals / Sum / Picker (forged)      {error,function_clause}
```

Control with the guard present and the same forged value stopped: base, B and E, where the only difference is the one patched line. To rule out "function_clause from somewhere else", I printed the top stack frame (`/tmp/verify59/origin.erl`): under base and B the four forged calls fail in `'Inner'` (`{fc_in,'Inner',[#{'Id'=>1,'Kind'=>'Ledger.Invoice','Total'=>100}]}`), and `Handle(forged)` fails in `'Handle'`. Kind side under B: `Doubled([1.5])`, `FromField`, `Bands([300])` fail in `'Double'`/`'Band'`, `DoubleP(1.5)` in `'DoubleP'`. So the stop is the claimed guard in each case.

Real wrong results, not a crash elsewhere:
- Floats: `Doubled([1.5])` returns `{ok,[3.0]}` out of `list<int>`, `Bands([foo])` returns `high`, `Bands([-5])` returns `low`. These are genuine kind/range violations.
- Records: the `{ok,100}` for the forged Invoice is a true acceptance of a wrongly tagged record but the number is numerically what an Order would give, since the forged value copies Order's fields. That is the tag test's exact job (nominal identity), but the brief's "silent" is mild for it. I added a sharper case (`/tmp/verify59/extra`): wrong tag and `Total` a binary. Under A, `Totals([wrong-tag, Total=<<"not-an-int">>])` returns `{ok,[<<"not-an-int">>]}` out of `list<int>`; under base/B/E it is `function_clause`.
- The probe set is selection-biased by construction: every shape is "a nested value flows into a private function that takes a record or int". Two things the brief should say:
  1. A wrong-tag record nested in an unwalked field is accepted by **every** variant, including B, if a public function projects it directly with no private record function involved (`Peek(w) -> var i = w.Item; i.Total` returns the binary under stock, A, B and E).
  2. The tag test is shallow even on stock: a right tag with a wrong field type passes (`Totals([right tag, Total=binary])` is `{ok,[<<...>>]}` under all four).
  So "Option 2 closes every path the probes found" is literally true and says less than it sounds. The brief does name S4 (projection guards) as the real closer, which is the honest reading.

### (c) eunit

Compiled all 67 `compiler/test/*.erl` (copy of `compiler/` in `/tmp/verify59/compiler`), ran every `*_tests` module under each emitter with `+S 1`:

```
stock Failed: 462  Passed: 864
A     Failed: 462  Passed: 864
B     Failed: 464  Passed: 862
E     Failed: 462  Passed: 864
```

Set of failing test names (parsed from the verbose logs; one extra failure line has no parsable name and appears identically in all four): A and E vs stock: empty difference both ways. B vs stock: exactly two new failures,

```
boundary_kind_tests: a_private_function_is_not_guarded_test              (boundary_kind_tests.erl:88)
boundary_range_tests: a_private_function_carries_no_range_guard_test     (boundary_range_tests.erl:122)
```

`grep -n private compiler/test/records_tests.erl` returns nothing; `compiler/bin/check-boundary-kind.sh` and `check-boundary-range.sh` contain no "private". Caveat the brief should state: the 462 baseline failures hide any test that dies before its assertion on OTP 25. I checked the baseline-failing tests in the modules that assert on emitted guards (`intervals_tests` 5, `diagnostic_json_tests` 1): they are diagnostic-text tests, not emission pins, so no pin is masked.

### (d) Corpus elision

Independent method (`/tmp/verify59/indep.erl`): take each corpus module's emitted abstract code under base and B, count `is_integer`/`is_float` calls, then `compile:forms` and disassemble with and without optimisation.

```
abstract code:               base 70   B 89   -> added 19
optimised beam (default):    base 47   B 47   -> added 0
no_type_opt + no_ssa_opt:    base 68   B 87   -> added 19
```

So the 19 are really added, `erlc` removes all of them, and with its type optimisation off they all survive: the elision is `erlc`'s. Per module B equals base on the optimised count everywhere. Gaps in the author's script that I closed: (i) `survive.erl` counts only `is_integer`/`is_float`; B also adds range comparisons (Frame: 6 to 8 `>=`/`=<` ops in abstract code); in the optimised Frame beam `is_ge`/`is_lt`/`is_integer` counts are identical between base and B, so those go too. (ii) The `CONTROL (Chain ...)` line in `corpus-survive.out` and the "abstract-code added: 19" text are not produced by `survive.erl` (the latter is a hardcoded string, the former was appended by hand). The control is valid (my `elision.sh` rerun shows `Cap` keeps `is_integer` under B), but it is not machine-linked to the 47/47.

### (e) Cost

Bytes. Tag +12, flat in field count (1/3/8/16 fields all 88 to 100 public, 119 to 131 private): confirmed. Kind +5 confirmed.

12 vs 14: not a real discrepancy. The emitted B# test is two extra instructions, `bif map_get 'Kind'` and `is_eq_exact` (`+12`). 26a reports +14 for an Erlang guard of the same shape on its harness (3 extra instructions counted there). I compiled the identical hand-written source from 26a (`amt(X) when map_get('__type__', X) =:= order -> map_get(total, X).` vs unguarded) in isolation: 73 to 85 bytes, +12. So the +2 comes from 26a's harness (module wrapper or operand encoding), not from a different test. The brief's "emitted +12 against hand-written +14" frames this as two designs; they are the same test. Note both are OTP 25 here; 26a's +14 was OTP 28.5 and the brief says it "reproduced exactly" (it reproduced the harness output, not an independent measurement). The brief's "+12 per record parameter" is per clause: `SpinRec` (2 clauses) carries two `map_get('Kind')` tests in the beam, `GetA` one.

Timing. 11 full runs of the author's `bench.erl` (15 interleaved rounds each, `+S 1`), rebuilt `BenchBase`, `BenchBas2` (byte-identical source), `BenchTagA`, `BenchKndB` from my builds. Load average during runs 1.0 to 3.0 (4 vCPU), lower than the brief's "4 to 8". Per-run minimum ns/iteration, median over 11 runs [range]:

| | base | Bas2 (floor) | A | B |
|---|---|---|---|---|
| W1 | 44.08 [43.3 to 44.7] | 43.91 | 15.29 [15.1 to 15.6] | 45.77 |
| W2 | 4.15 | 4.17 | 4.44 | 3.86 |
| W3 | 12.83 | 12.82 | 13.00 | 13.21 |
| W4 | 4.17 | 4.17 | 4.43 | 3.85 |
| W5 | 23.99 [23.7 to 24.2] | 23.91 | 15.37 [15.3 to 15.6] | 26.55 [26.3 to 27.1] |

Paired within-run differences (11 runs; run-minimum, with run-median in brackets):
- Floor, base minus Bas2: W1 +0.03 [-0.81..0.76], W2 -0.02, W3 +0.01, W4 -0.03, W5 +0.05 [-0.05..0.34] (run-medians swing to about ±1.2 under noise).
- Tag test, base minus A on W5 (one test per iteration): **+8.58 ns** [8.29..8.76]; run-medians +8.90 [8.39..10.35]. The "about 8 ns" claim reproduces (8.6), is about 30 times the min-floor and 8 times the worst median swing, so it is distinguishable from noise. The brief's 8 is a rounding down; "8.6 +/- 0.3" is what the data support.
- Kind test, B minus base: W2 -0.29 (all 11 runs negative), W4 -0.29 [-0.38..-0.24] (all negative), W3 +0.34 [0.27..0.44] (all 11 positive), **W5 +2.65** [2.35..3.00] (all 11 positive).

What follows:
- The brief's "kind-test time is below the noise floor" (Option 2, "Measured") and its W3/W4 "below noise, no claim" are too strong. The author's floor of 0.83 comes from a single noisy run; in 11 paired runs W3 (+0.34 ns/elem, about 2.6 %) and W5 (+2.65 ns/iter, about 11 %) are consistently above the byte-identical control, and W2/W4 are consistently 0.3 ns *faster* under B. Opposite signs of roughly equal size mean a code-layout effect of about 0.3 ns that is not the guard, so sub-ns kind-test costs are unresolvable, but W5 is larger than that effect. B's `SpinOne` keeps three `is_integer` tests in the optimised beam (disassembly), so the brief's "kind test elided when callers proven" does not cover a loop that accumulates a value from an unknown-typed projection (`acc + GetA(h)`). The brief's W5 table row lists B at 24.9 vs 23.8 and its "read" column attributes nothing to it.
- TagA is also +0.3 ns slower than base on W2/W4 (code it does not touch), confirming the layout offset.
- **W1 is explained, not unexplained.** The brief labels it "two tag tests per iteration". The disassembly of `BenchBase:SpinRec/3` shows `map_get('Kind')` + `is_eq_exact` at the head of clause 1 (which then fails `n <= 0`), the same pair again at clause 2, and `GetA` has one more: **three tag tests per iteration**, because each clause repeats the boundary guard and `erlc` does not share it. 29 to 30 ns / 3 = about 10 ns each, close to W5's 8.6 (the rest is the non-tail call and allocation). So the per-call figure is about 8 to 10 ns, and a multi-clause private function pays it once per clause tried.
- Not carried to OTP 28: the brief says so, correctly.

### (f) Gleam and Elm

No Gleam claim is presented as measured: §4.8 and §7 say "UNVERIFIED-NOT-EXECUTED" and cite only `10c_gleam_forge.erl` (tag caught, payload not; matches the header comments at lines 56-60) and `18c_gleam_ffi_trust.gleam`. Elm: `elm-try.out` shows `elm make` failing to fetch packages. But §4.8 attributes to `wayfinder/research/18-elm-port-validation.md` that "the language has no private/public distinction that affects checking". The file says nothing about visibility (grep for private/expose/public finds only a JS "PUBLIC API" comment at `:313,336`). That half-sentence is the author's, not the source's; see Overstatements.

## Mismatches (brief vs my reproduction)

1. W1 workload label "two tag tests per iteration" is wrong; three execute (above).
2. W3/W4 "below noise" and the Option-2 sentence "Kind-test time is below the noise floor": not supported by 11 paired runs for W3 (+0.34) and W5 (+2.65).
3. 4.2/Option-3 numbers are all right, but 4.5 says `Totals`/`Picker` closed and `Unwrap` open under E; in `forge.out` (Ledger) E also closes `Unwrap` and `Sum`, because `Inner` is address-taken elsewhere in that module. That is the S5 action-at-a-distance in miniature and is stronger evidence than the `nest.bs` toy; the brief only used the latter.
4. `.beam` file byte numbers differ from `size.out` by 4 to 20 bytes in my build (debug-info paths); Code bytes match exactly. The brief already says to use Code.

## Circularity flags

- No probe counts a crash as an expected result. `lib.sh probe()` has the vacuity guard, but none of the 59 probe scripts call `probe()`; they call `bsc` directly. They are safe for a different reason: a failed build leaves no `.beam`, and `forge`/`nest`/`kinds` do `{module,M} = code:load_abs(...)`, `a.sh`/`elision.sh`/`size.sh` read the beam, so a missing build crashes loudly rather than printing an "expected" value. `size.sh` pipes compiler output through `grep -v warning`, which would hide a non-warning line only if it contained "warning".
- The author never adjusted expectations in the files I checked: the `.out` files are pure program output.
- The eunit "B breaks two tests" is partly tautological: B reverses a rule those two tests were written to pin. The finding that matters is that A and E break zero, and that is a genuine check.
- Selection bias in the shape list (b above); the brief's own S4 note mitigates it.
- Patch E is a probe and the brief says so ("the patch is a probe, not a design", §7), presents it as Option 3 with its failure shapes and the S5 objection, and does not claim it is sound for `{q,...}` cases. The one fairness point: B is also an unrefined probe (it leaves an unused `Public` parameter, warned) and gets a fuller design write-up than E. Not misleading.
- The recommendation's point 3 relies on the unsupported "18 contradicts itself" reading.

## Citation errors

- `18-boundary-defence.md:194`: line is right, characterisation wrong (above).
- `CONTEXT.md:397` is the bold heading `**Boundary guard**:`; the "on an exported function's parameter" text is `:398`. Off by one.
- `LANGUAGE.md:3638` is the refined-`int` row; the record-tag row is `:3637`. The brief cites 3638 for "exported" generally, so acceptable.
- `beam_ssa_type.erl:708-725` (make_fun / `any` arguments): in this OTP 25.3 install (`compiler-8.2.6.3`) `opt_make_fun` is `:700-719` and `ArgTypes = duplicate(ArgCount, any)` is `:707`. `:119-120` and `:432-441` are exact. `:693-694` is the exported-function comment of the neighbouring clause (about `:683-690`). The brief does not say which OTP source version the line numbers belong to; they are not OTP 28's.
- `dialyzer_dataflow.erl:2890-2894` exact (OTP 25 dialyzer 5.0.5).
- Correct: `bs_emit.erl:159-163, 178-181, 265, 277, 284, 330-333`; `boundary_kind_tests.erl:88`; `boundary_range_tests.erl:122`; `F24:120-123` ("boundary_guards/5"), `F24 §6` at `:173`; `F37.5` at `:168-180`; `F3.9` at `F3-records.md:252`; 26 §1 "every exported function taking a record" at `26-data-modelling.md:197`; `18a_guard_cost.md §4(c)` at `:349`; `examples/Shop/Pricing` `Rule(:staff) -> Free` (Free private, `:20,32`); F46 `fun 'Free'/1` at `F46:90`.

## Overstatements

1. "Ticket 18 contradicts itself" / "both are resolved text": see (a). Withdraw; the sentence supports §4 under exported guards.
2. "F24 §6 is itself a precedent against the 'private is already checked' premise." Two-sided at best: the hole there was an unsound narrowing at the *call site* in B# code, and the fix was to repair the call-site check (so that "every call site is checked" became true), which is the opposite of guarding the callee. The brief's own phrasing "not by guarding the private function" concedes this but still files it under evidence for widening.
3. "Option 2 ... closes every path the probes found" and Recommendation 1: true of the probes, which are by construction paths into a private function with a guard; a direct projection of an unwalked field (`Peek`) is open in every option, as is a right-tag record with a wrong field type.
4. "The 8 ns figure is larger than ticket 26's 'the tag itself costs nothing measurable'" (4.7): 26's sentence compares guarded tuple (7.04) with guarded tagged map (8.78) to choose the erasure; it is not a claim about the guard's absolute cost, and 26a's own table (unguarded map 16.45 vs guarded 22.63) already shows about 6 ns. There is no conflict to resolve.
5. "Kind-test time is below the noise floor" (Option 2 Measured); see Mismatches 2.
6. "26a's +14 reproduced exactly on OTP 25" followed by "+12 emitted against hand-written +14": the same test compiles to +12 in isolation; the +2 is harness.
7. "+12 per record parameter": per clause per parameter.
8. Elm: "the language has no private/public distinction that affects checking" is not in the cited research file and Elm does have `exposing`; either drop it or mark it as the author's recollection. (The brief tags the whole bullet UNVERIFIED, which limits the harm.)
9. Machine note: "load average 4 to 8" is the author's; mine was 1 to 3 and the W5 base/A numbers agree to 0.2 ns (24.0 / 15.4 vs 23.8 / 15.5), so the tag-test figure is robust to load.

## Artefacts

Scratch: `/tmp/verify59/{stock,a,b,c,d,e}/ebin`, `/tmp/verify59/probes/59/*.mine`, `/tmp/verify59/eunit.{stock,a,b,e}.log`, `/tmp/verify59/probes/59/bench/runs/r1..r11.txt`, `/tmp/verify59/agg.py`, `/tmp/verify59/indep.erl`, `/tmp/verify59/extra/`.
