# Verification of artifacts/59-boundary-guard-scope-asymmetry.md

Independent re-run. Scratch dir: `scratchpad/verify59/` (one subdir per probe; each run passed `WORK=` so
nothing was shared with the author's temp dirs). Nothing under `compiler/`, `wayfinder/`, the brief or
`artifacts/probes/59/` was edited. `git status` shows other agents' unrelated changes under
`artifacts/probes/52|57|62`; none are mine.

## 1. Re-run versus captured .out

| probe | exit | vs captured `.out` |
|---|---|---|
| 59a | 0 | identical. Four PASS. |
| 59b | 0 | identical, all three variants and the Elixir caller. |
| 59c | 0 | Code bytes, instruction counts and Code-md5 identical on every row (181/169/181; 1110/978/1110; 328/316/333; 21/19/21; 125/105/125). **Whole-.beam and stripped sizes differ** (e.g. cur K=1 1680/510 versus captured 1452/439) because they depend on the output path, which `mktemp` changes. The brief cites only Code and instruction counts, so no claim is affected. Within one run the N=5 sizes are still identical. |
| 59d | 0 | First run was under heavy host load (load average 18) and was useless (cur 24 ns, noise 2x). Re-run twice at R=25 on a quiet host: ViaList cur 15.61/15.60, cur2 15.56/15.64, narrow 13.39/13.48, widen 15.28/15.36; ViaInts cur 12.66/12.66, cur2 12.63/12.69, narrow 13.46/13.43, widen 12.38/12.31. Matches the captured numbers to about 0.2 ns. |
| 59e | 0 | identical (7606 control PASS). |
| 59f | 0 | identical. |
| 59g | 1 | identical except the Gleam "Compiled in 1.12s versus 0.52s" line. Exit 1 is the script's last line (`elm make` failing, as the brief says). |
| 59h | 0 | identical: 27 modules, narrow 0, widen 1 (Shop/Pricing 522 to 531), control 0. |
| 59i | 0 | identical (15 private, 0 record, 9 int/float; 93 public, 10, 33). |

## 2. Brief claim to backing probe

| claim | backing | holds? |
|---|---|---|
| private `InnerTotal` has the tag test, `InnerInt` has no `is_integer`, `OuterInt` has it | 59a | yes, and I confirmed the grep can go red: under `narrow` InnerTotal loses the guard, under `widen` InnerInt gains `is_integer(N)` |
| `ViaTotal` carries the tag test itself (premise 3) | 59a.out line `'ViaTotal'(O) when map_get('Kind', O) ...` | yes |
| forged-map table (A/B/C columns, six rows) | 59b | yes, every cell. Extra cells the table omits: under A, `ViaBox(Box{Item=42})` is `badmap` and `Item=#{}` is `badkey`, so A is silent only for a well-formed wrong record |
| `ViaInts([1.5])` returns 2.5 today | 59b cur `{ok,2.5}`, Elixir `2.5` | yes |
| `Hof:Run([1.5])` returns `[2.5]` today | 59b | yes |
| Elixir gives the same terms | 59b, but the Elixir caller ran under `cur` only | yes for cur; narrow/widen not run from Elixir (same terms, immaterial) |
| tag test is 12 bytes of Code (K=1), 13.2 average (K=10), instructions 21 to 19 and 125 to 105 | 59c | yes |
| `is_integer` is +5 where it survives, 0 where the optimiser removes it | 59c Forge 328 to 333; Many cur=widen md5 | yes |
| optimiser removes private `is_integer` only when the caller proves it; never the tag test | 59f | yes |
| tag test about +2.4 ns on about 15.8 ns | 59d | reproduces as 2.2 to 2.3 ns, see caveat C3 |
| noise floor about 1.3 ns | 59d (narrow ViaInts) | **mislabelled**, see C3 |
| `is_integer` cost not resolvable | 59d | yes (widen vs cur within 0.3 ns, below the layout effect) |
| corpus: narrow changes 0 of 27, widen 1 of 27 (+9 bytes), 26 of 27 md5-equal | 59h | yes for `compiler/examples` minus `exemplars/`; see C1 |
| 15 private signatures, none with a record | 59i | yes for the same slice; see C1 |
| cur Code md5 equal to widen on `Many` | 59c | yes |
| Gleam emits no check on either scope; forged `{invoice,1,5}` returns 5 | 59g | yes |
| Erlang spec unenforced, guard enforced at any scope | 59g | yes |
| Elixir `defp` unchecked, `%O{}` pattern raises | 59g | yes |
| stdlib 10.6 vs 16.7 percent, Elixir 7.6 vs 26.4; 7606 control | 59e | numbers yes; interpretation see C4 |
| `lists.erl:477-481` | read the file | seq's `is_integer` guard is at line 478, `seq_loop(N,X,L) when N >= 4` at 481. Range is right, "`:477`" is off by one |
| Elm not probed | 59g | yes, honestly disclosed |
| widen also enables float and range tests on private fns | none (disclosed as read from code) | no probe. Reading the code agrees (see section 4) |
| no existing test pins the private tag test; widen must invert exactly `boundary_kind_tests:88` and `boundary_range_tests:122` | **no probe** | partial, see C2 |
| `bs_emit.erl:265-290`, `330-333` comment, `guard_one/8` | read | yes (265 `boundary_guards`, 275 `guard_one`, 284 `none when Public`, 289 `none ->`, 330-333 the comment) |

## 3. Circularity hunt

**Variant compilers.** `lib.sh` copies the shipped `ebin/*` and then copies `compiler/src/bs_emit.erl` in as source. I diffed the
results against `compiler/src/bs_emit.erl`:

- `cur`: no diff. Its `bs_emit.beam` is the shipped beam (a `cp`, not recompiled).
- `narrow`: exactly one added line, `        {ok, _Tag} when not Public -> {Pat, []};` after line 276.
- `widen`: exactly one changed line (284), `none when Public ->` to `none ->`. The final `none -> {Pat, []}` clause is **left in place, now unreachable**. The brief's "delete the final `none` clause" is therefore not what the variant did. Behaviour is identical, but the real change under the project's `warnings_as_errors` needs the deletion.

So neither variant differs by more than the single described change. Nothing is hardcoded or copied: every `.out` came from a live compile.

**Is `cur` really the current source?** The line `cur == shipped bs_emit.beam` printed by every probe is
**vacuous**: `cur`'s beam is a `cp` of the shipped one, so `cmp` cannot fail. I checked the real question separately by compiling
`compiler/src/bs_emit.erl` with `erlc +debug_info` and compiling Forge/Hof/Scope with it versus the shipped `$BSC`. The `Code`
chunks are byte-equal for all three, so the shipped compiler does reflect current source (the whole `Dbgi` chunk differs, which is
compile-option noise). `narrow` and `widen` are compiled with plain `erlc`, not rebar's options, which does not touch the `.bs` output.

**Controls that can fail** (flip tests I ran):
- 59a: the assertions go red under the wrong variant (above).
- 59b: `narrow` flips the ViaBox/ViaList rows, `widen` flips ViaInts/Hof, `Inline` stays `5` in all three (a control that is allowed to be silent, deliberately), `ViaOrder` stays `function_clause`. Not circular.
- 59c: cur-vs-cur2 is the control; Code md5 differs for narrow only, which is the claim.
- 59f: `InnerInt` under `cur` is false and `Plus1` under `widen` is true, so the check distinguishes. Its tag check (`is_eq_exact`) is a loose pattern, but `InnerInt` is a negative control and `OuterInt` shows it is not matching arithmetic.
- 59h: the cur-vs-cur2 control compares two compiles of the same compiler, which cannot detect a bad variant but does show compile determinism. The narrow=0 result is independently checked by my list below (private record-param functions exist only under `exemplars/`).
- 59i: a regex census, so weaker than 59h, but it agrees with 59h.
- 59g/59e: no variant compilers involved. 59e's "defended" metric is loose, see C4.

**eunit flip I added** (not in the brief). I compiled `compiler/test/*.erl` and ran every `*_tests` module under each variant ebin. 420 of 1312 tests fail
at baseline in this harness (`cur`; diagnostic-text assertions, nothing to do with guards), so this is partial. Within the
tests that can run: `narrow` fails the same 420; `widen` fails the same 420 plus exactly `boundary_kind_tests:a_private_function_is_not_guarded_test` and
`boundary_range_tests:a_private_function_carries_no_range_guard_test`. That supports the brief's "tests to invert" for B and its "no test pins it" for A, but only over the runnable 892.

## 4. Compiler delta, read independently (`bs_emit.erl`)

- `boundary_guards/6` at 265 calls `guard_one/8` at 275 per parameter, passing `Public`.
- Tag clause (276-283) has no `Public` condition: private functions get the tag test unless `constrains_kind(Pat)`.
- Kind branch (284-288) is `none when Public`, calling `float_guard` or `int_guard`; `int_guard` also emits the range arms via `owed_arms`/`range_test`. So B's note that widening moves the float and range tests too is correct by reading.
- Fallback `none -> {Pat, []}` at 289.
- The comment at 330-333 says "that asymmetry is deliberate". Brief correct.
- Option A's one clause goes ahead of the tag clause: accurate, and it is the exact narrow variant.
- Option B: accurate except the "delete the final clause" detail (above).

## 5. Verdicts

| probe | verdict | reason |
|---|---|---|
| 59a | VALID | reproduced; flips red under other variants |
| 59b | VALID | reproduced; flips; Elixir under cur only |
| 59c | VALID-WITH-CAVEAT | Code and instruction numbers reproduce. Whole-.beam bytes are path-dependent (not cited). The `cur == shipped` line is vacuous (C5) |
| 59d | VALID-WITH-CAVEAT | reproduces on a quiet host; unusable under load; "noise" is really code-layout (C3) |
| 59e | VALID-WITH-CAVEAT | reproduces; "defended" is not "type-checked" (C4) |
| 59f | VALID | reproduced |
| 59g | VALID | reproduced; exit 1 is the Elm line |
| 59h | VALID-WITH-CAVEAT | reproduces, but covers only the compilable slice (C1) |
| 59i | VALID-WITH-CAVEAT | same slice limit (C1) |

No probe is CIRCULAR or UNREPRODUCIBLE. Overall: **the brief's measurements and behavioural claims are sound. Its headline corpus argument is the part to correct.**

## 6. Corrections the brief needs

- **C1 (material). "The corpus does not decide this" / "narrowing changes 0 modules" / "none takes a record parameter."** True only for `compiler/examples` outside `exemplars/`. The excluded `compiler/examples/exemplars/` programs (the language's target programs) have 64 private signatures, at least 7 with a record parameter: `25e/rows.bs:15 Row(OrderRow)`, `25d/rows.bs:38 Prepend(OrderRow, ...)`, `25d/summary.bs:14 Tally(..., Totals)`, `:19 Add(Totals, OrderRow)`, plus `Model`/`State` ones in 25b/25f/25g (`Envelope(Model, ...)`, `Call(Model, ...)`, `Crashed/Answered(..., State)`), and 3 with a bare int/float. Narrowing will change those once they compile. The brief does disclose that the exemplars do not compile, but under "Not verified" and not next to the 0-of-27 figure, and the Option A evidence line ("Corpus: 0 modules change") reads as a clean result. State the limit where the number is.
- **C2.** "No existing test I found pins the private tag test" has no probe in the brief. My partial eunit run agrees (see section 3), but 420 tests could not run here; word it as "none among the tests that run".
- **C3.** "Noise floor about 1.3 ns" is mislabelled. `cur` and `cur2` agree to about 0.05 ns; the 0.8 to 1.2 ns spread comes from `narrow` ViaInts, which has identical code for that function but a different surrounding module (code layout or alignment). Say "layout sensitivity of about 1 ns", and note the +2.2 to 2.4 ns tag-test effect is only about twice that. Also say the probe is unusable while the host is loaded (my first run, load 18, gave 24 ns and no signal).
- **C4.** The platform census counts a position "defended" if every clause has any non-variable pattern or the variable appears in any guard (including arithmetic like `N >= 4`). That measures pattern/guard presence, not type checking, so "local-only functions are defended less" is true as counted but partly reflects accumulator helpers. Fine as colour; do not read it as "authors check less".
- **C5.** Drop or reword the `cur == shipped bs_emit.beam` assurance. It cannot fail. I verified the real equivalence myself (Code chunks of Forge, Hof and Scope are byte-equal between source-compiled and shipped).
- **C6.** Option B: the `widen` variant changes one line and leaves the final `none ->` clause unreachable; the brief says it deleted it. Behaviour is the same, but under `warnings_as_errors` the real change must delete it.
- **C7.** Minor. `lists.erl` `seq/2`'s `is_integer` guard is at line 478 (the brief writes 477). The Option A rows that say "a silent `5`" apply only to a well-formed wrong record; `Item=42` and `Item=#{}` still crash (`badmap`, `badkey`) under A.
