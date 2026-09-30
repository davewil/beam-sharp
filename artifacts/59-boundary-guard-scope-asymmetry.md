# 59 — The boundary guard applies two rules with different scopes

Ticket 59 · [ENG-241](https://linear.app/davewil/issue/ENG-241) · 2026-09-29
Status: decision open — for human review. Nothing here resolves the ticket, writes a Decisions entry or touches Linear.
Probes: `artifacts/probes/59/` (`run.sh` prints PASS/FAIL against expectations written in the script before each command). Compiler tree untouched: every variant is a patch applied to a copy.
Host: OTP 25, x86_64 JIT, 4 shared cores. The tickets cite OTP 28.5 / arm64 (see §7).

## 1. Sub-decisions, gating first

The ticket says `boundary_guards/4` and `/5`; at HEAD (`41b47c2`) it is `/6` (`bs_emit.erl:257`). `Public` is consulted **once**, in `guard_one/8`'s head `none when Public ->` (`:276`), and that one gate covers **three** guards (F24 int kind, F37 range, F51 float), not one. The tag branch (`:268-275`) never reads it. The premise "a private function's every call site is a checked B# call site" is also written into `clause/4` (`:169-175`, `IntOnly`/`strip_rels`), so it lives in two places.

**(a) Is "exported" the right discriminator for both guards?** Gates everything. Probed answer: **no, for the premise the discriminator rests on.** A private function is reachable by a caller nothing checked in two measured ways: as a function value a public function returns (F46 emits `fun 'Free'/1`; P8), and as the consumer of an element taken out of a collection or tuple, which the exported guards do not inspect (46 §4 refuses the collection case as O(n); P2). Sub-decision (a) is really "which unchecked reaches count".
**(b) Tag test on private: keep (defence in depth) or elide (18 §4)?** Depends on (a). Measured cost of keeping: +13.9 B Code per function, and one `map_get` per iteration of a private recursion over a record (~+5.3 to +6.4 ns).
**(c) If private keeps a guard, does the int/range/float family widen?** Follows (b). Measured cost: +22.9 B per function when callers are unproved; erlc erases `is_integer` (not the range bounds) when every caller proves an integer; +1.2 ns per iteration in a 3-int-parameter private self-loop.
**(d) State the scope once, in one function?** Independent of the answer; each option below gets it. Delta: one `owed_at(Guard, Public)` in `bs_emit.erl` consulted by `guard_one/8` and by the `IntOnly` computation at `:174`.

Two authority facts the options must respect. CONTEXT.md:397 defines **Boundary guard** as *"a guard the compiler emits on an exported function's parameter"*, so the shipped tag test on private functions contradicts the glossary today. And 18 §4's function-local rule says *"a value handed to another function counts as unchecked, and is guarded"*, which is the sentence both sides of the ticket quote.

## 2. Probes

Expected-before-run is quoted from `run.sh` (each block starts with an `# expect` comment). **Disclosure:** I ran exploratory versions of P1, P2, P3, P5b and P8 before writing `run.sh` and pre-stated the expectations from reading `guard_one` and F46; they were not derived from a patched-until-green probe, but they were not blind either. The verifier should weight P4, P6, P7, P9 (stated before first run) higher.

| id | claim tested | expected before run | observed | file |
|---|---|---|---|---|
| P1a-d | shipped compiler: which of exported/private carry which guard | tag on exported and private record fn; `is_integer` on exported int fn only | as expected | `out/P1-asymmetry.txt` |
| P1e-g | patches change only what they name | base == shipped; NARROW drops private tag only; WIDE adds private int only | as expected | `out/P1-asymmetry-{narrow,wide}.txt` |
| P2a | exported record param forged, forwarded to private | caught at exported `Direct/1` in all variants | as expected | `out/P2-forgery.txt` |
| P2b-c | forged record inside `list<Order>` / tuple, consumed by a private helper | base and WIDE crash in private `Amount/1`; NARROW returns 5 | as expected | same |
| P2d | same value, no private helper | silent (`ok:5`) in every variant | as expected | same |
| P2f-g | `Buckets([300])`, `Buckets([100.5])` (private `Octet` helper) | silent in base and NARROW; WIDE crashes in `Bucket/1` | as expected | same |
| P5b | exported fn called from its own module pays its guard (18 §1 one entry label) | local `call` targets the label whose block holds `is_integer`; private sibling has none | `callee_entry_label=4 has_is_integer=true calls_callee_entry=true`; `Priv` false | `out/P5b-*.txt` |
| P5c | WIDE, callers prove int | erlc erases private `is_integer`, keeps range bounds | as expected | `out/P5c-loc-wide.asm.txt` |
| P8a-f | private fn handed out as a value, applied from Erlang with a bad arg | silent in base/NARROW; WIDE crash in callee; REFSITE crash in wrapper; lambda-with-helper caught only by WIDE; inline lambda silent everywhere | as expected | `out/P8-function-values.txt` |
| P4a-c | size per private fn | tag 10-18 B, int 3-40 B | 13.88 B, 22.85 B | `out/P4-size.txt` |
| P7a-c | shipped corpus (22 modules) | no private fn carries a tag test; WIDE adds 0 Code bytes | as expected | `out/P7-corpus.txt` |
| P3a-d | hot loop, 1e7 calls | RecP NARROW >=1 ns faster; IntP WIDE >=0.5 ns slower; exported self-loop >=1 ns slower than private | as expected | `out/P3-bench-*.txt` |
| P9a-d | repo eunit against each variant | NARROW/REFSITE add no failures; WIDE adds exactly F24.6 and F37.5 | as expected | `out/P9-*` |
| P6a-e | neighbours | see §3 | as expected | `out/P6-*` |
| P6f | Elm | cannot run | NOT-RUN | `out/P6-elm.txt` |

**Correction (verifier):** the earlier claim of a full `run.sh` with 0 FAIL was unbacked: `out/run-full.txt` is truncated after P4c and `out/P3-bench-*.txt` are stale. The verifier's three complete runs gave 0 / 1 / 0 FAIL on a contended host (the one FAIL was P3d, RecP base 14.47 vs wide 12.28 ns).

## 3. Neighbouring languages

Only files opened locally; no neighbour source is installed except OTP/Elixir compiler internals used through their public APIs.

- **Gleam 1.12.0** (binary only, no stdlib; `gleam build` ran offline with zero dependencies). Emitted `probe59.erl` (`out/P6-gleam-emitted.erl`): `pub_total/1` (:18-19), private `priv_total/1` (:23-24) and `pub_int/1` (:38-39) are bare `erlang:element(3, O)` / `N + 1`, **no guard anywhere**, opaque type included. Forged `{wrong,1,5}` returns 5 through both the exported and the private path; `pub_int(1.5)` returns 2.5 (`out/P6-gleam-forged.txt`). Gleam neither scopes a guard nor emits one. (Matches 18's cited precedent; re-observed, not quoted.)
- **Elixir 1.14.0.** Nothing is emitted for `@spec` (`spec_only`'s head is a bare variable, `out/P6-elixir-forms.txt`). A written `%Ord{}` pattern, `is_struct/2` guard or `is_integer/1` guard is a real test, and **`def` and `defp` with the same written head compile to identical code** (P6c). The check exists because the author wrote it; visibility never changes what is emitted. That is the closest neighbour to "one rule, stated once", and it is a rule about the source, not the compiler.
- **Erlang/OTP 25.** `-spec integer() -> integer()` is not enforced: `e59:pub(1.5)` and, through a private `priv/1`, `e59:use(1.5)` both return 2.5 (`out/P6-erlang.txt`). Dialyzer is a separate static tool; no compiler output of `erlc` contains a test for it (nothing to probe beyond that).
- **Elm 0.19.2.** Not runnable: `package.elm-lang.org/all-packages` unreachable, so no module compiles (`out/P6-elm.txt`). No Elm claim is made.

## 4. Measurements

All from `run.sh`; N stated. Code = `beam_lib` "Code" chunk bytes (uncompressed); stripped/file from `beam_lib:strip/1` and the file.

| quantity | value | source |
|---|---|---|
| tag test, Code B per private fn | K=1: 12, K=10: 12.8, K=100: **13.88** (26a: +14) | P4 |
| tag test, stripped file B / unstripped file B per fn (K=100) | 5.5 / 37.6 (debug_info carries the guard) | P4 |
| int guard (is_integer + both range bounds, callers unproved), Code B per fn | K=1: 20, K=10: 21.5, K=100: **22.85** | P4 |
| int guard, stripped / unstripped file B per fn (K=100) | 7.2 / 94 | P4 |
| corpus (22 modules, 97 fns, 19 private) | private tag tests: **0**; WIDE: +9 int guards in abstract code, **+0 Code bytes** (erlc erased them) | P7 |
| compile time, K=100, min/median of 9 | rec: base 114.9/125.2 ms, NARROW 95.5/101.8; int: base 93.3/111.1, WIDE 156.8/175.8. rec-WIDE emits identical code to base and read 125.5 ms median in the last run, but 156.8 in an earlier one: **noise floor was up to ~30-50 ms on this shared host** | P4 |
| RecP hot loop (private, record param, tag test on the path), ns/call, min of 7 | base 13.6-15.4 (three runs), NARROW 8.3-9.0, WIDE 13.8-15.7 → tag test **~+5.3 to +6.4 ns** | P3 |
| IntP (private, 3 int params, self-recursive), ns/call | base 1.30-1.34, WIDE 2.54-2.65 → **+1.2 ns** even when the exported caller proves x | P3 |
| IntE (same loop, exported), ns/call | 2.65-2.82 vs private 1.31 → exported pays its guard on every self-call | P3 |
| run-to-run spread within one variant (min vs median) | 0.01-0.14 ns | P3 |

Ticket 18's "at or below ±0.09 ns/call" and 26a's "the tag itself costs nothing measurable" **do not reproduce on this host for these loops**: the deltas are 10-60× the spread. The claims were made on arm64/OTP 28.5 for a different loop shape; I cannot say they are wrong there. What reproduces exactly is the byte figure (+14).

Why the loops are the right shape: B# has recursion and no loop statement, so a private self-recursive helper is the loop; under any rule that guards private functions, the guard is re-run on every self-call (P5b: one entry label, so the guard cannot be skipped for internal calls).

## 5. Options

Common source (`artifacts/probes/59/src/Fv/fv.bs`, `src/Fwd/fwd.bs`):

```csharp
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

int Amount(Order o)           // private
Amount(o) -> o.Total
int Shave(int cents)          // private
Shave(c) -> c - 100
int Band(Octet n)             // private
Band(n) when n >= 9 -> 1
Band(n) -> 0

public int SumAll(list<Order> os)
SumAll([])       -> 0
SumAll([o, ..t]) -> Amount(o) + SumAll(t)   // elements: no exported guard (46 §4)
public int Buckets(list<Octet> ns)
Buckets([n, ..t]) -> Band(n) + Buckets(t)   // ([] clause elided)
public fn(int) -> int Rule(atom tier)
Rule(_) -> Shave                            // F46: emitted `fun 'Shave'/1`
```

### Option A — NARROW + REFSITE: exported-only, and guard where a private function is handed out

Program that behaves differently under A: `Rule(:member)(1.5)` from Erlang is refused; `SumAll([forged])` returns silently.

Compiler delta (patches `variants/narrow.patch`, `variants/refsite.patch`, ~30 lines):
- `bs_emit.erl:270` `guard_one/8`, tag branch: `false when not Public -> {Pat, []}`.
- `bs_emit.erl:1063` `expr({e_fname,...})`: for a local target that is private, build synthetic `p_var` patterns, call `boundary_guards/6` with `Public = true` and `Accepts = term`, and emit `fun(X) when Tests -> Priv(X) end` instead of `fun Priv/1`. New Ctx key `privfns` (built in `forms/1`, `:35` neighbourhood).
- `owed_at/2` for (d); update `clause/4`'s `IntOnly` comment; amend CONTEXT.md only if wording changes (it already says exported).

Emitted: `'Shave'(C) -> C - 100.` and `'Amount'(O) -> map_get('Total', O).` (no guards); `'Rule'(_) -> fun(Bs@ref1) when is_integer(Bs@ref1) -> 'Shave'(Bs@ref1) end.`

Evidence: P8a-c refused at the wrapper (crash blamed on `-Rule/1-fun-0-`); P9: no existing test fails; private record loop 5.3-6.4 ns/iter faster and 13.9 B/fn smaller (P3, P4). Cost of the wrapper on a private function passed to `List.Map(xs, Double/1)`: one guard per element, **not measured**. Lambda that calls a private function is still open (P8d), as is the collection-element case (P2b, P2f).
Strongest counterargument: **A converts a defence that works today into a silent hole.** `SumAll([forged])` crashes in `Amount/1` on HEAD and returns `5` under A (P2b, P2c, P8g); the same value is already accepted when there is no helper (P2d), so what disappears is a defence that only existed when the author happened to factor a private function out. That is silent-vs-loud in the ticket's own direction, and only 46 §4's owed projection guard (tuple/record field, not collection) could close it. A also makes the wrapper a new function identity (`fun 'Shave'/1` becomes an anonymous fun).

### Option B — WIDE: every function guards its own parameters

Program that behaves differently under B: `Banding(:x)(300)`, `Rule(:member)(1.5)`, `SumAll([forged])`, `Buckets([300])` and `(c) => Shave(c)` applied to 1.5 all crash inside the private callee.

Compiler delta (`variants/wide.patch`, one line): `none when Public ->` becomes `none ->` at `bs_emit.erl:276` (kind, range and float all move). Then, concrete follow-ons: `owed_at/2` collapses to `true`; `clause/4`'s `IntOnly` comment (`:169`) rewritten (the boundary guard now establishes the kind at both sites); flip two tests, `boundary_kind_tests:a_private_function_is_not_guarded_test` (F24.6) and `boundary_range_tests:a_private_function_carries_no_range_guard_test` (F37.5); amend F24 §3, F37.5, 46 §1, 58's tail, 18 §4/§1 cost paragraph ("interior functions already pay nothing"), and CONTEXT.md:397 (drop "exported"). Emitted: `'Shave'(C) when is_integer(C) -> C - 100.` plus the range bounds on `Band/1`.

Evidence: P2b-c, P2f-g, P8a-d refused; P9: fails exactly F24.6 and F37.5 and nothing else; corpus +0 Code bytes (P7). Costs: +22.9 B per private int function where callers are unproved, +13.9 B per private record function already paid today, +1.2 ns per iteration in private int loops (P3b), +45-56 ms on a K=100 compile (P4, noisy). Only the inline lambda (P8e) stays silent, and it is silent under every option.
Strongest counterargument: **the cost lands on the idiom B# encourages.** A private self-recursive loop over plain `int` params doubles its per-iteration time on a trivial body (1.3 to 2.6 ns) to re-check values the function itself produced, and P5b shows the single entry label means no way to skip it. Every private function with a plain `int` parameter is affected, not only refined ones (`is_int_only` is true for `int`, `bs_emit.erl:~340`). B also rewrites four feature documents and the glossary's definition of the term.

### Option C — status quo, stated once: tag on every function, kind/range/float exported-only

Program that behaves differently from A and B: none new. `Reader(_)(forged)` is refused (tag), `Banding(_)(300)` is not (P8b, P2f).

Compiler delta: `owed_at(tag, _) -> true; owed_at(_, Public) -> Public.` consulted by both branches of `guard_one/8`; a comment at `:316-325` that gives the reason instead of "deliberate"; CONTEXT.md:397 reworded to say identity is tested at every function head and kind at the exported one. No test moves (P9 identical to base).

Evidence: cheapest change; keeps every defence that works today. It is defensible only as *"identity is unforgeable in the term; ordering and kind are the caller's problem"*, which 26 §1 argues for the tag (no body ever checks it) and 58 argues against for the kind (a comparison proves ordering, not kind).
Strongest counterargument: **it has no principle beyond accident.** The nested and function-value paths that reach a private function protect a record and leave the `int` under the same parameter silent (P2b vs P2f, P8b vs P8c), and both are the same 18 §1 outcome 3. It also keeps the +5.3-6.4 ns/iteration tag cost in private record loops, which no test pins.

## 6. Recommendation

**B, one-line patch, if the hot-loop cost is acceptable; otherwise A. Not C, and not A's NARROW half alone.** The order follows the ticket's own rule (too narrow is a silent hole, too wide is measurable and loud), and the two probes that decide it are P8 and P2:

1. The discriminator "exported" is false as a statement about who can reach a function (P8: F46 publishes private functions; P2: collection elements are decided-unguarded at the boundary by 46 §4). B is the only option whose one-sentence rule ("a function guards its own parameters") is true of both paths, and (d) is trivially satisfied.
2. The measured price is real but small in absolute terms and erased in most bytes: 0 Code bytes on the corpus, `is_integer` erased when callers prove it (P5c), +1.2 ns/iteration only in private int self-loops with unprovable arguments, and the tag cost is already paid today.
3. If David judges +1.2 ns (100% on an empty loop) and +5.3-6.4 ns (tag, already shipping) as too much for private recursion, A is the fallback, but only with the follow-up recorded: **A knowingly reopens `SumAll([forged])`**, which needs its own ticket for the projection guard 46 §4 already decided and F24's tail lists as unbuilt.
4. Independent of the pick, open a ticket (not this one) for the inline lambda / arrow-typed value (P8e): no scope rule reaches it, and a function-value boundary was never priced (ticket 75's answer says only that *"the guard, `ValidateAs<T>` and the spec were fixed by 11 and 18"*; I found no sentence there on a private function published as a value).

A refinement B cannot express and that would cut the loop cost: a guarded entry plus an unguarded self-loop body. 18 §1 says one function cannot do it (P5b confirms the label), so it is two emitted functions and a decision of its own. Not built, not measured.

## 7. Not measured / limits

- **OTP 25 / x86_64 JIT / 4 shared cores**, not OTP 28.5 / arm64. Timing deltas and erlc's type-based erasure (P5c, P7b) may differ on 28; the byte figures matched 26a exactly.
- Compile-time is noise-bound (~30-50 ms floor here); no compile-time claim is made beyond "not clearly different".
- Hot loops are synthetic. The corpus has 19 private functions, none with a tag test, so **neither the status quo nor WIDE costs anything measurable on shipped programs**; a program with private recursion over records would.
- Wrapper cost of Option A on `List.Map(xs, Priv/1)`, cold/megamorphic call sites, JIT native size: not measured.
- P9 runs the eunit modules under `erlc`/`eunit` (no rebar3); **Correction (verifier): the 451 baseline failures are NOT mostly environmental.** 393 of them fail only because `bs_test_support:escript()` finds no built escript, so the author's P9 never ran the patched emitter on those tests (about 30% of the suite). With a stand-in `_build/default/bin/bsc` wrapper the verifier got base 58 failures / 1245 passes (the 58 are `maps:iterator/2`, `json:decode/1`, `json:encode/1` missing on OTP 25, plus a few such as `cli_tests:escript_entry_point_exists_test`); NARROW's failing set is identical to base; WIDE fails 60, exactly base plus F24.6 and F37.5. The P9 conclusion holds, over 1303 tests instead of 903. Only the diff against base is claimed. The shell gates (`bin/check-*.sh`, `verify.sh`) were **not run**, so I cannot say which gate scripts pin the scope.
- Elm: not run. Elixir: 1.14 only. Gleam: emitted code read, standard library absent.
- Not probed: OTP behaviour callbacks declared private, `spawn` of a private fun via `Process`/`Task`, function values passed to foreign functions (P8 applies the fun from Erlang, which covers the same reachability).
- The exemplars under `compiler/examples/exemplars` do not compile (README says so), so the corpus is the 22 shipped example modules only.
- No Decisions entry, no Linear write, no edit under `compiler/`, `wayfinder/` or `CONTEXT.md`. The ticket file `wayfinder/issues/59-...md` already exists and was left untouched; this brief is at `artifacts/59-boundary-guard-scope-asymmetry.md` per the spec.

## 8. Reproduce

```
cd /home/user/beam-sharp && bash artifacts/probes/59/run.sh          # ~4 min; --quick = fewer timing runs
# env: SP=<scratchpad holding bsc/ebin>, W=<scratch>, GLEAM=<gleam binary>
# one probe by hand (variants are built by run.sh into $W/ebin-{base,narrow,wide,refsite}):
erl -noshell -pa $W/ebin-wide -eval 'bsc:main(init:get_plain_arguments()),halt().' -extra -o /tmp/o artifacts/probes/59/src/Fwd/fwd.bs
artifacts/probes/59/lib/call.escript /tmp/o Fwd SumAll "[#{'Kind'=>'Other.Thing','Id'=>1,'Total'=>5}]"
artifacts/probes/59/lib/guards.escript /tmp/o/Fwd.beam
```

## Verifier corrections (independent re-run, 2026-09-29/30)

Structural claims REPRODUCED (`boundary_guards/6` at :257, `Public` read only at :276, tag branch never reads it, CONTEXT.md:397-398, F46:90/97). Forgery scenarios REPRODUCED with an independent driver on base (`Reader(_)(forged)` refused; `Banding(_)(300)`, `Banding(1.5)`, `Rule(_)(1.5)`, `Buckets([300])`, `InlineLambda(1.5)` silent; `SumAll([forged])` crashes); WIDE refuses all but `InlineLambda`. Byte figures REPRODUCED exactly in 3 runs (13.88 B, 22.85 B, 22 modules / 97 fns / 19 private / 0 private tag tests, WIDE +9 abstract guards, +0 Code bytes). Gleam (no guards; the emitted .erl also carries `-spec` lines), Elixir (def and defp identical) and Erlang (-spec unenforced) REPRODUCED. Elm NOT-RUN.
**All timings are CONTENDED** (load average 2.8-4.0 from other agents) and are not called reproduced or not:
- Tag delta base-minus-narrow in three verifier runs: +2.9, +7.5, +4.0 ns (brief: +5.3 to +6.4). IntP delta +0.87 to +1.05 ns (brief: +1.2). Real noise floor about 0.3-0.7 ns (identical functions differed by 0.3 ns within one run), not 0.01-0.14.
- Independent loop (N=2e7, 9 runs, min): record param + int 6.9-7.0 ns base vs 0.64-0.79 narrow vs 6.5-8.2 wide; 1 plain int 0.63-0.80 / 0.62-0.81 / 0.78-1.00; 3 plain ints 0.62-0.79 / 0.81-0.84 / 0.96-1.26. A pure-Erlang control (`map_get('Kind',It) =:= K` guard) costs 5.7-5.8 ns against 0.67-0.81 unguarded, so the tag cost is the `map_get` guard on OTP 25, not B#-specific; two `is_integer` guards cost 0.67-0.73 ns.
- IntP is not a 3-plain-int loop: one parameter is a range-refined `Octet`. The plain-int guard costs about +0.15 to +0.6 ns; the brief's +1.2 ns includes the range bounds. 'Every private function with a plain int parameter' overstates the plain-int cost by 2-4x.
- P3d loosening (1 ns -> 15%) and min-of-3 are legitimate noise handling, not a manufactured pass; P3d is only a sanity check and should be INFO.
- Tickets 18 and 26a: mostly apples-to-oranges, not a contradiction. 18a (`wayfinder/prototypes/18a_guard_cost.md` :173-218) times a remote call to a leaf on a 2.2-2.8 ns floor with a tuple discriminator, and its own four-`is_integer` `add/4` shows +0.44 to +0.87 ns, the same order as here; 26a (`26-data-modelling.md:305-313`) compares two already-guarded forms (8.76 vs 8.78), never a tag against no tag. A real OTP 28 / arm64 difference is not ruled out.
Other corrections: WIDE's one-line patch leaves an unused `Public` and an unreachable clause at :281, so the real change also drops them. Ticket 46's O(n) sentences are at 46:119, 221, 290 (only :221 inside §4); 46 says the guard stands for a tuple element and a record field, so the P2c tuple case is owed by 46 §4 and unbuilt (F24:164-165), and only the collection case is decided unguarded; §1(a) lumps them. `run.sh` fails with 'build base failed' if the work path is long; copy from a short path.
Recommendation check: supported on correctness. On cost it is weaker than presented: the dominant measured cost is the tag test (about 3-7 ns per iteration), which B and C keep and A removes; B's own added cost is small (+0.2-0.6 ns plain int, about +0.9-1.2 ns with range bounds). The brief never considers a hybrid, WIDE for kind/range/float and NARROW for the tag (one more line, keeps the loud crash for ints); a reader should treat it as a fourth shape. A's wrapper cost on `List.Map(xs, Priv/1)` remains unmeasured by anyone.
