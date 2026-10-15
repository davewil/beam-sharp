# Verification of artifacts/59-boundary-guard-scope-asymmetry.md

Verifier run 2026-10-15, compiler tree == 019533d (stock `$BSC` and my rebuilt HEAD copy produce a byte-identical
Code chunk for `59_reach/G`, hash FD8BFE7F). Machine was loaded (load average 8-11 on 4 cores, other agents running), so
timings are noisier than the author's. All my output is in `artifacts/verify/59/` (`run/*.out` are my reruns).

## Bottom line: YES WITH CORRECTIONS

The recommendation (B) is still supported. Every behavioural claim reproduced. One measurement is vacuous (is_integer
call time), one cited grep is wrong, and the central claim needs a narrower statement. None of these reverses the
recommendation. Corrections are listed at the end.

## 1. Probe table (rerun from clean shell, exact listed commands, diff vs saved .out)

| probe | verdict | notes |
|---|---|---|
| 59_reach.sh | REPRODUCED | byte-identical to saved .out (exit 1 is the final `diff` finding differences, as designed) |
| 59_checker_refuses.sh | REPRODUCED | identical; three bad programs refused, both CONTROLs exit=0 |
| 59_entry_label.sh | REPRODUCED | identical |
| 59_split_entry.sh | REPRODUCED | identical (89 -> 102 B) |
| 59_elision.sh | REPRODUCED | identical |
| 59_size.sh | REPRODUCED | identical; 220/16 = 13.75, 13.5 vs 13.5, 31/8 = 3.88 (deterministic, no n) |
| 59_corpus.sh | REPRODUCED | identical (23 beams, 5 rows, 12 private fns) |
| 59_gleam.sh | REPRODUCED | only diff is "Compiled in 1.90s" vs "0.43s" |
| 59_elixir.sh | REPRODUCED | identical |
| 59_erlang_survey.sh | REPRODUCED | identical |
| 59_time.sh | REPRODUCED (direction) | n=15, mine vs saved, ns/iter min/median: record HEAD 6.98/8.29 (saved 6.47/8.18), EXP 1.90/2.46 (2.01/2.51), ALL 6.00/7.60, NOTAG 2.23/3.20. Tag test +5.1 min / +5.8 median (brief +4.5/+5.7). Int loop HEAD 1.01/1.33, ALL 1.01/1.29 (but see circularity C1) |
| 59_time_erlang.sh | REPRODUCED (direction) | record unguarded 2.26/2.87, tag-guarded 5.92/7.61 (+3.7 min, +4.7 median; brief +3.9/+4.8); int 0.94/1.21 vs 1.01/1.30 |

My own n=9 rerun (`probes/time2.out`, 1e7 iters, round robin), record loop min/median: HEAD 6.36/7.58, ALL 6.64/8.26,
EXP 2.02/2.40. The tag test costs about 4-5 ns and is about 3x the bare loop. The claim holds.

Byte costs are deterministic (one build, no variance), so there is no min/median to report. I got the same numbers on
two builds (the author's saved run and mine): 13.75 B per private tag test, 13.5 B at both 3 and 8 fields, 3.88 B per
`is_integer`.

## 2. Circularity review

**C1. FLAG, vacuous: the int call-time claim ("`is_integer` +0.03 ns, inside noise", F8 and the Measurements table).**
In `59_time` the ALL variant's `LoopI/2` has its `is_integer` test elided by erlc, because the only entry is
`RunI(int n) -> LoopI(n, 0)` and the recursion passes `n - 1` and `acc + n`. Disassembly of `LoopI/2` under HEAD and ALL
is identical (`probes` helper `59_disasm.escript`, both show only `is_eq_exact`, `gc_bif`, `call_only`; Code-chunk hashes
equal). So the probe compares two identical functions. The brief labels the row "ALL (is_integer on n, acc)", which is
not what was timed. The Erlang control (`li_g` in `59_time_erlang.erl`) is the same: `erlc -S` shows `li_g/2` with no
`is_integer` left. Both controls agree because both are empty.
I replaced it with a case where the test survives (`probes/T2/T/t.bs`: private `LoopI` also entered from
`RunU(list<int>)`, so erlc cannot prove it; ALL's disassembly shows `{test,is_integer,{f,3},[{x,0}]}` at label 5).
`probes/time2.out`, n=9: HEAD min 1.189 / median 1.375, ALL min 1.172 / median 1.592, spread up to 2.2-3.0. The surviving
test is still inside noise. The conclusion (a surviving `is_integer` costs about 0 ns) holds. The evidence for it
in the brief does not.

**C2. Not circular: `59_reach`, EXP/ALL patches.** Each patched build has an unmodified control: the stock `$BSC` and
the HEAD copy. Both gave the same Code hash and the same forged-call rows as the saved HEAD column. The forge
script (`59_forge.escript`) runs real calls and prints whatever they return. Nothing is hard-coded. The EXP/ALL rows
differ from HEAD only on the rows the patch should move.
**C3. Not circular: `59_checker_refuses`, `59_elision`, `59_entry_label`, `59_split_entry`.** Controls differ from the
tests (CONTROL programs compile; the proven/unproven callee pair differs). `59_split_entry` is a hand-written Erlang
demo of what a compiler *could* emit, labelled as such.
**C4. Mild: `59_erlang_survey`, `59_gleam`, `59_elixir`.** The programs are author-written, so they show what those
languages do for those shapes, not what idiom is common. The text frames them that way. `.out` is live output, not
literals. The "83.3%" census figure is quoted from ticket 18 (line 410, 560), present.
**C5. `59_corpus`** counts a delta from `59_guards.escript` output with awk filters, and errors in compiling are
printed as "did not compile standalone" (none occurred), so errors are not swallowed. But it excludes the 46 `.bs`
files under `examples/exemplars/` (design prose, do not compile), so "zero private record functions in the corpus"
means "in the 22 compiling example directories". I checked those by grep (15 `private` functions, none take a record
type).

### Patches (applied to fresh copies of stock `compiler/`, `patch -p1`, diffs in `patches_diff.txt`)

| patch | changed lines | exactly what changed | stock differs? |
|---|---|---|---|
| `59_uniform_exported_only.patch` (EXP) | 1 | adds `{ok, _} when not Public -> {Pat, []};` before the tag clause in `guard_one/7` | yes: ViaNested/ViaList/ViaTuple Invoice-tagged rows go from `function_clause` to `ok 5` |
| `59_uniform_all_functions.patch` (ALL) | 7 (4 removed, 3 added) | `none when Public ->` becomes `none ->`; removes the now-dead `none -> {Pat, []}` clause; adds `_ = Public,` to satisfy warnings_as_errors | yes: ViaIntList/ViaOctList forged rows become `function_clause`; Code hash differs (FD1F6804 vs stock FD8BFE7F) |
| `59_no_tag_test.patch` (NOTAG) | 3 | computes `tag_test(...)` and discards it, returns `{Pat1, []}` (measurement tool only) | yes: Code hash EDBB69BE |

The brief calls ALL "one line"; its semantics are one line but the diff is 7.

### Attempt to REFUTE the central claim (own programs, `probes/R/R/r.bs`, forge `probes/forge_r.escript`)
The checker does not guard `list<Order>` elements at the door (`ViaList` tag_guard=n in saved output) and does not refuse
the shape (it compiles). Forged Invoice interior, HEAD vs EXP:

| shape (interior reaches private `Priv(Order)`) | HEAD | EXP (private test removed) |
|---|---|---|
| `ViaPat(Wrapper { Inner: Order o }) -> Priv(o)` | function_clause (head tests inner Kind) | function_clause |
| `ViaSwitch`: `w.Inner switch { Order o => Priv(o) }` | case_clause | case_clause |
| `ViaPat2`: `Wrapper { Inner: o }` binder, no type prefix | function_clause | **ok 5** |
| `ViaLet`: `var i = w.Inner` then `Priv(i)` | function_clause | **ok 5** |
| `ViaChain`: `Priv2(w) -> Priv(w.Inner)` via a second private fn | function_clause | **ok 5** |

So the claim is NOT refuted, but it needs narrowing: the hole exists where the interior value is projected or bound
*untyped*. When the author writes a typed pattern or a switch on the projection, the arm itself emits the tag test and
the private test is redundant. The brief's probes covered only the untyped shapes and says "any value taken out of an
aggregate"; that overreaches. Also no refutation of the payload claim (F5): `Order` tag with `Total=<<"x">>` returned
`ok <<"x">>` in every variant.

## 3. Citations

| citation | result |
|---|---|
| `bs_emit:guard_one/7`, `boundary_guards/6`, ticket says /5, 46 says /4 | CORRECT (bs_emit.erl:265, 275; ticket 59 line 11; ticket 46 lines 55,128,247) |
| bs_emit comment "that asymmetry is deliberate" | CORRECT (bs_emit.erl:333) |
| `grep -l 'ticket 59\|ENG-241'` hits only 46, 58, F24, F37 | **WRONG on 46**: it hits 58, F24, F37 (and 59 itself). Ticket 46 predates 59 and never mentions it. It does contain the `boundary_guards/4` text the brief means |
| ticket 18 "guarded-public/unguarded-internal pair is impossible" is PARTLY wrong | **OVERSTATED**. 18 line 615-618 (s1) says *"cannot be done with one function"*, which is right. Only the summary sentences (18 line 440, 976 "a pair is impossible") drop the qualifier. The stub+twin demo is valid (89 -> 102 B), but the brief should say 18's summaries overstate its own s1, not that 18 is wrong |
| 18 s4 quote "looks at the exported function's own clause heads and body, and no further" / "a value handed to another function counts as unchecked, and is guarded" | CORRECT (18 lines 815-818) |
| 13.5 / 13.75 B, 3.88 B | CORRECT (reproduced) |
| 4 ns | CORRECT in magnitude (my reruns +3.7 to +5.8 ns depending on statistic and load) |
| 26a "+14 B flat", "2.17 vs 7.04 ns" | +14 B CORRECT (26 line 227, 302). The 2.17 vs 7.04 pair is **tuple unguarded vs tuple guarded** (26 line 310), not the map tag test; the brief borrows it as "26a's own tuple numbers", which it does say, but it does not support a map-tag claim. The +4 ns rests on 59's own loops, which did reproduce |
| lists.erl:477-479 `seq` guard, 481-487 `seq_loop` | CORRECT in substance; real extent is 477-479 and 481-486 (OTP 28.5.0.7 stdlib-7.3.0.3), a line off |
| kernel.ex:5448-5450 `@enforce_keys` quote; kernel/utils.ex:143-200 | CORRECT (text at 5448-5450, 143 and 198-200 land on the enforce_keys code) |
| Elm 18-elm-port-validation.md:190-335 | CORRECT range (decoder section 190, "send is the decode" at 330-336) |
| 18's census 83.3% | CORRECT (18 line 410, 560) |
| F24 s3, F37.5 "inherited on purpose" | CORRECT (F24 line 117-125, F37 line 168-177) |

## 4. Independent tests of the two claims B leans on

**T1. B changes no emitted code for the shipped corpus.** Compiled all 22 example directories (23 beams) under HEAD,
EXP and ALL; compared `Code`, `LocT`, `ExpT`, `AtU8` chunk MD5s (`probes/chunkhash.escript`). Result: **23 of 23
identical across all three**. The whole-file MD5 differs for every beam, including `Math` which has no private function
(the file differs from compiler-path metadata in CInf/Dbgi), so file-level hashes are not a usable test. Caveat: the
abstract-code chunk does change under ALL (9 private tests added, author's figure), so "no emitted byte" is true of the
runnable Code chunk, not of the debug chunk. Confirmed.

**T2. B gives no false refusals on legitimate programs.** `probes/L/L/l.bs` has: a recursive private accumulator
(`SumTo(int n, int acc)`, n up to 200000), a private refined `Octet` param (`Bump`, boundary values 0, 254, 255) called
direct and from a `list<Octet>` walk, private `float` params (`Half`, recursive `Geo(int, float)`), an int-to-float
conversion (`Float.FromInt`) feeding a private float function, a JSON-decoded float field (`FromJson`, input `1` and
`0.5`) feeding a private `float` function, a private function passed as a value (`List.Map(xs, Twice)`), and a private
function with an `int | float` parameter. ALL really adds guards: `SumTo`, `Bump`, `Half`, `Geo`, `Twice` carry
`is_integer`/`is_float` in the abstract code (`59_guards`). 19 calls, HEAD vs ALL output **identical**
(`probes/l_head.txt`, `l_all.txt`), and the three forged-at-the-door calls still raise `function_clause` in both.
No false refusal found. I did not exhaust the language (ticket 80 says nothing flows between int and float, which is
what makes this safe; if that rule ever relaxes, a private float guard would refuse a widened int).

## Corrections needed in the brief (none reverses B)

1. **Replace the `is_integer` call-time evidence** (F8, Measurements): the 59_time int loop and the Erlang control both
   have the test elided, so they compare identical code. Use a loop whose entry cannot be proven (my `T2`), or drop the
   claim. Also fix the row label "ALL (is_integer on n, acc)".
2. **Narrow F2's scope**: the hole is "an interior value projected or bound untyped" (field access, `var i = w.Inner`,
   an untyped binder in a record pattern, a list element or tuple component). A typed record pattern or a switch with a
   type-prefixed arm on the projection already emits the tag test (my ViaPat, ViaSwitch rows).
3. **Fix the grep claim**: it hits 58, F24, F37 (plus 59), not 46.
4. **Soften "18's corollary is partly wrong"** to: 18 s1 correctly says "one function"; the summaries in 18 (lines 440,
   976) drop that qualifier.
5. State that the ALL patch is a 7-line diff (the one-line semantic change plus the dead clause and `_ = Public`).
6. State that the corpus claim covers the 22 compiling example directories and the Code chunk; the exemplars (46 files)
   do not compile and were not measured.
7. Minor: the 26a "2.17 vs 7.04" pair is a tuple-shape guard, not the map tag; lists.erl and kernel.ex ranges are a
   line off.
