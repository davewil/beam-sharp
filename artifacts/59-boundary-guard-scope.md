# Decision brief: ticket 59, the boundary guard's two scopes

Ticket: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md` (ENG-241). Status in repo: open. Nothing here resolves it, edits it, or touches Linear.
Probes: `artifacts/probes/59/` (`run-all.sh` re-runs everything and writes raw output to `out/`). Raw output below is copied from `out/`.

## 1. Ticket summary

`bs_emit:guard_one/7` (called from `boundary_guards/6`; the ticket says `/5`, the comment says `/4`, the code is `/6`) applies two scopes:

- The record TAG test is emitted on every function, private included (nothing consults `Public` on that branch, `compiler/src/bs_emit.erl:275-283`).
- The int/float KIND test is emitted only `none when Public ->` (`bs_emit.erl:284`), citing 18 §4.

The ticket asks one question: is the private tag test a defect against 18 §4, or is 18 §4's "exported" too narrow for what the tag test needs? It also asks whether "exported" is even the right discriminator, and what widening costs.

Both sides turn on one premise, which the ticket states as fact in the "defect" argument: *"A private function's every call site is a checked beam-sharp call site, so site 1 has already rejected a wrong tag and the test is dead weight."* That premise is measurable. It is false (section 3, probes 01 and 02).

## 2. Sub-decisions and gating order

I grepped `wayfinder/issues/*.md` before writing "undecided" for anything below.

| # | Question | Status | Gates |
|---|---|---|---|
| Q1 | Can a wrong-kind or wrong-tag value reach a private function without crossing a checked B# call site? | Factual. Probes say yes, through at least three doors (3.2). | Q2 |
| Q2 | Which scope for the TAG test? | The ticket's question. | Q3 |
| Q3 | Same scope for the KIND test (restated once, for both)? | Follows Q2 (ticket owes "stated once, for both guards"). | Q4 |
| Q4 | Edits to 18 §4 and F24 §3 prose and to 46's correction. | Follows. | none |

Not open, and not for this ticket:

- **Whether the exported door checks container elements.** 46 §4 decided it: *"A refined `int` is guarded wherever a fixed number of projections reaches it ... It is **not** guarded through a collection"* (`46-refined-parameter-at-the-boundary.md:214-216`), with cost as the stated reason (O(n) in a caller-chosen length, `:220-222`). I rely on this below, and I reproduce its cost in probe 10.
- **Whether to emit a guarded-public plus unguarded-internal pair.** 18 §1 killed it: one entry label per function (`18-boundary-defence.md:613-617`).
- **Whole-aggregate or call-graph analysis to decide which private functions need guards.** 18 §4 killed it (blast radius of editing one file; `18-boundary-defence.md:815-846`).

## 3. Probes

Toolchain (probe 00, `out/00-toolchain.txt`):

```
OTP 25 erts 13.2.2.5
Elixir 1.14.0 (compiled with Erlang/OTP 24)
gleam 1.5.0
0.19.3            (elm)
rebar 3.19.0 on Erlang/OTP 25 Erts 13.2.2.5
```

**How `bsc` ran.** `rebar3 escriptize` on the repo fails under OTP 25. I built it in a scratch copy (`probes/59/lib.sh`, repo never modified; `git status` shows only `?? artifacts/`). Patches, all to the scratch copy:

1. `rebar.config`: `xrl_opts` emptied, because OTP 25's leex rejects `error_location`. `warnings_as_errors` dropped, because `bs_run.erl:351` uses `~kp` (an OTP 26+ format) and OTP 25 flags it. Runtime effect of that line: none for these probes.
2. `bs_lexer.xrl`: `TokenLoc` replaced by `{TokenLine,1}`, and a stub `adjust_col/3`. Columns are lost and diagnostics lose column positions. The emitter does not read columns (inferred from reading `bs_emit.erl`'s guard code, not diffed against an OTP 28 build), so I expect the emitted code to be unaffected.

Everything the probes show about *emission* is therefore from the real `bs_emit.erl`. The one thing that differs from the reference is that erlc is OTP 25's, not 28.5's.

### 3.1 Probe 01: what is emitted today, and what each door does with a forged value

Command: `artifacts/probes/59/01-as-built.sh`. Fixture: `probes/59/src/T/t.bs` (records `Order`, `Invoice` with identical fields, `Cust`, `Wrapper`; refined `Octet`; private `Inner`, `Bump`, `Score`).

Emitted Erlang, verbatim (`out/01-as-built.txt`):

```erlang
'Outer'(O) when map_get('Kind', O) =:= 'T.Order' ->  'Inner'(O).
'Inner'(O) when map_get('Kind', O) =:= 'T.Order' ->  map_get('Total', O).      %% private: tag test present
'OuterL'([O | T]) -> 'Inner'(O) + 'OuterL'(T).                                  %% exported: no element check
'Bump'(N) ->  N + 1.                                                            %% private: no kind test
'OuterI'(N) when is_integer(N) andalso N >= 0 andalso N =< 255 -> 'Bump'(N).   %% exported: kind+range
```

Shows: ticket claims 1 and 2 are **true** ("private `Inner(Order o)` receives the tag test", "int KIND test exported only"). The tag test on `Inner` is redundant on the direct `Outer -> Inner` path and is the only check on every other path (next probe).

### 3.2 Probe 02: three scope rules, same battery

Command: `artifacts/probes/59/02-scope-variants.sh`. Three scratch compilers:

- **A**: repo emitter, unmodified (tag everywhere, kind exported-only).
- **B**: `patch-tag-exported-only.sh`. The whole diff is one line, `{ok, _} when not Public -> {Pat, []};` inserted before `bs_emit.erl:277`. This is "one rule, narrow".
- **C**: `patch-int-everywhere.sh`. Diff: delete `when Public` at `bs_emit.erl:284` and delete the `none -> {Pat, []}` fall-through at `:288-290`. This is "one rule, wide".

Raw battery output, with the forged `Invoice` (same field set as `Order`, `Total = 999`):

```
                                                              A (as built)           B (narrow)             C (wide)
Outer(Invoice)             exported, direct                   raised function_clause raised function_clause raised function_clause
OuterL([Order, Invoice])   exported, via list                 raised function_clause returned 1009          raised function_clause
SumO([1, 1.5])             exported, via list                 returned 4.5           returned 4.5           raised function_clause
SumO([300])                exported, via list                 returned 301           returned 301           raised function_clause
(InnerAsValue())(Invoice)  private fn escaped as fun          raised function_clause returned 999           raised function_clause
(BumpAsValue())(1.5)       private fn escaped as fun          returned 2.5           returned 2.5           raised function_clause
(BumpAsValue())(300)       private fn escaped as fun          returned 301           returned 301           raised function_clause
Nested(Wrapper{Cust=Order}) exported, nested record           raised function_clause returned 5             raised function_clause
OuterI(1.5)                exported, direct                   raised function_clause raised function_clause raised function_clause
(controls: OuterL([Order,Order]) = 20, SumO([1,2]) = 5, Nested(valid) = 5 in all three)
```

(Table assembled from `out/02-scope-variants.txt`; the file has the verbatim per-variant output including emitted private heads and the patch diffs.)

What it shows:

- **Ticket's premise ("site 1 has already rejected a wrong tag; dead weight") is false** at three doors: a list element (`OuterL`, 46 §4 decided the exported door does not check collections), a record-typed field (`Nested`: the exported head tests `Wrapper`'s tag, not `Cust`'s), and a private function that leaves the module as a fun (`InnerAsValue`, ticket 75 decided `fun 'Inner'/1` is emitted, probe 01). Under B each returns a wrong answer silently (1009, 999, 5). Under A the private tag test catches all three.
- **A already has the silent hole for ints at the same doors** (4.5, 301 twice). Not new with B; it is what the asymmetry looks like from the int side.
- **C closes all ten doors.** It catches `SumO([1, 1.5])` at the private `Bump`, even though the exported door does not look at elements. That is a benefit of C that none of the ticket's arguments mention. It is partial: an element consumed inline in an exported body, with no typed private function in between, is still unguarded. I did not probe that; it follows from 46 §4 plus the emitted shape of `SumO`.

### 3.3 Probe 03: bytes (`out/03-cost.txt`)

Command: `artifacts/probes/59/03-cost.sh`.

```
--- base ---    beam file bytes: 2496   Code chunk bytes: 418
--- narrow ---  beam file bytes: 2440   Code chunk bytes: 391     (A minus B = 27 Code bytes for 2 private record params: Inner, Score)
--- wide ---    beam file bytes: 2552   Code chunk bytes: 436     (C minus A = 18 Code bytes for 1 private int param: Bump)
```

Per-function disassembly in the same file shows `Inner`, `Score`: `[test]` under A and C, `[]` under B. `Bump`: `[]` under A and B, `[test,test,test]` under C.

### 3.4 Probe 04: ticket 59 quotes 18 §1: "the same code un-exported has the test elided entirely"

Command: `artifacts/probes/59/04-single-caller-elision.sh`. Fixture `src2/T`: `Outer -> Inner` and `OuterI -> Bump`, one call site each, wide build so `Bump` has a guard to elide. Disassembly after erlc (`out/04-single-caller-elision.txt`):

```
Inner:  bif map_get('Kind', x0) ... test is_eq_exact x1 'T.Order' ... bif map_get('Total') ... return     %% tag test kept
Bump:   test is_ge x0 0 ; test is_ge 255 x0 ; gc_bif '+' ...                                              %% is_integer GONE, both range compares KEPT
```

Shows: the claim is **partly true here, on OTP 25**. With a single local caller that already proved the fact, erlc dropped `is_integer` and kept the range comparisons and the whole tag test. With more than one call site (probe 03: `Inner` has two callers, `Outer` and `OuterL`; `Bump` has two, `SumO` and `OuterI`) nothing is elided. I cannot say what OTP 28.5 does; its `beam_ssa_type` is newer.

### 3.5 Probe 05: call time (`out/05-runtime-cost.txt`)

Command: `artifacts/probes/59/05-runtime-cost.sh`. 1000-element list, ns per element (so includes the walk itself), 9 repetitions, two passes:

```
                 Inner(tag)   median (min..max)             Bump(int)   median (min..max)
A  as built      33.3 (32.2..36.8)  /  33.6 (32.4..39.9)    16.0 (15.7..17.3)  /  15.2 (15.1..15.4)
B  narrow        25.3 (24.5..31.9)  /  24.4 (24.2..25.8)    16.6 (16.0..18.6)  /  16.6 (16.3..22.3)
C  wide          32.4 (31.7..33.8)  /  32.8 (32.0..43.9)    17.2 (17.0..17.4)  /  18.1 (17.2..22.1)
```

Shows: the private tag test costs about +8 ns/element here (a `map_get` plus compare on a 3-key map). The private kind+range test costs about +1 to +2 ns/element (is_integer is kept, range compares are kept). The ticket's "below ±0.09 ns/call resolution" was measured on OTP 28.5 arm64 with a different method; **my numbers do not confirm it and do not refute it**. This VM is noisy (max is up to 1.4x min on several rows).

### 3.6 Probe 09: tag cost against field count (`out/09-tag-cost-vs-fields.txt`)

Command: `artifacts/probes/59/09-tag-cost-vs-fields.sh`. Private `P2(R2)` (2 fields) and `P10(R10)` (10 fields):

```
base:   Code chunk bytes 179   P2 instrs=8   P10 instrs=8
narrow: Code chunk bytes 155   P2 instrs=6   P10 instrs=6
```

24 bytes for two tag tests: 12 each, and the instruction counts are equal at 2 and 10 fields. Ticket's "+14 bytes, flat in field count" is **consistent** (12 vs 14, flat); different OTP so not identical.

### 3.7 Probe 11: the strongest cost objection, a hot private loop (`out/11-hot-private-loop.txt`)

Command: `artifacts/probes/59/11-hot-private-loop.sh`. Under C, `Loop(int n, int acc)` gets `is_integer` on both parameters, and `Step(Octet k)`, called per list element, gets `is_integer` plus range.

```
                                   SumTo(1e6) us med (min..max)       SumMod (1000 x 1000 elems) us med (min..max)
A  as built   pass1                3115 (2575..4621)                  5018 (4870..12110)
C  wide       pass1                2708 (2541..7764)                  6424 (6278..8993)
A             pass2                3674 (2801..4160)                  6731 (5318..7798)
C             pass2                3148 (2813..3767)                  6875 (6373..11526)
```

Shows: a plain-int accumulator loop shows no consistent cost (C was not slower in either pass). The per-element refined-int helper is about +1.4 ms per 1M calls in pass 1 and within noise in pass 2. Honest reading: between 0 and about +25% on a loop whose only work is the helper call; I cannot resolve it on this VM.

### 3.8 Probe 10: the price of making "narrow" sound by checking elements at the door (`out/10-deep-door-cost.txt`)

Command: `artifacts/probes/59/10-deep-door-cost.sh`. **Hand-written Erlang mimic**, not `bsc` output (bsc emits no element check; probe 01). `deep/1` checks every element's tag on entry and recurses through the exported name, as an exported-recursive B# function would:

```
n=100    shallow 3.5 us   door-check-per-entry (recursion re-enters) 60.5 us     check-once 3.1 us
n=1000   shallow 21.7 us  door-check-per-entry                      5925.9 us    check-once 32.5 us
n=4000   shallow 293.7 us door-check-per-entry                      98253.3 us   check-once 137.1 us
```

Shows: quadratic, about 300x at n=4000 (the 293.7 us shallow figure is a noisy outlier; the earlier run gave 94.0 us, so the ratio is 300x to 1000x). This is the measured reason behind 46 §4's "not through a collection". It means narrow cannot be made sound at the door without author-visible restructuring.

## 4. Neighbour survey

| Language | What `pub`/exported vs private changes at runtime | Evidence |
|---|---|---|
| Erlang (OTP 25 stdlib) | Convention only: guard at the export, trust in the helper. No language check. | `/usr/lib/erlang/lib/stdlib-4.3.1.3/src/lists.erl:271` `seq(First, Last)` / `:272` `when is_integer(First), is_integer(Last), First-1 =< Last ->` / `:273` `seq_loop(Last-First+1, Last, []).`; the helper at `:275` `seq_loop(N, X, L) when N >= 4 ->` has no type test. 18 §1 census (`18-boundary-defence.md:557-560`): 83.3% of exported parameter positions are bare variables. Erlang makes no type claim, so it cannot break one. |
| Elixir 1.14 | Nothing. `@spec` is Dialyzer-only. Elixir `.ex` sources are not installed here (only `.beam`), so no file:line; behaviour measured. | Probe 06 (`out/06-neighbour-elixir.txt`): `N.outer(1.5)` with `@spec outer(0..255)` returned `2.5`; `outer(300)` returned `301`; `outer_l([1.5,300])` through `defp bump` returned `303.5`. |
| Gleam 1.5.0 | Nothing. Private functions get the same `-spec`; no guard anywhere. Output of `gleam compile-package` via the shipped compiler, dependency-free package. | Probe 07: `inner(O) -> erlang:element(3, O).` with `-spec inner(order()) -> integer().`; forged `n:outer({invoice,2,999})` returned `999`, `n:bump_pub(1.5)` returned `2.5`. Gleam stdlib is not installed; not needed. |
| Elm 0.19.3 | Defends only the one door (ports/flags); internal functions are never guarded, public or not. | Probe 08 could not compile (`package.elm-lang.org` returns 403; `out/08-neighbour-elm.txt`). The Elm claim is from the repo's own research, `wayfinder/research/18-elm-port-validation.md:216-221` (`toDecoder` synthesises a decoder from the declared port type) and `:860` ("Elm's guarantee rests on owning the only door"). **Not independently verified here.** |

What the survey says: no neighbour discriminates by visibility. Erlang by convention, Elm by construction, Gleam and Elixir not at all. beam-sharp is the only one whose guards are compiler-emitted from declared types, so there is no precedent to follow on this exact question. What neighbours do show (Gleam above) is the cost of the A/B choice made visible: `inner(O)` reads element 3 of any tuple.

## 5. Options

Each is a B# program that behaves differently under one answer. Use the fixture in `probes/59/src/T/t.bs`; the relevant lines:

```csharp
public int OuterL(list<Order> os)
OuterL([])       -> 0
OuterL([o, ..t]) -> Inner(o) + OuterL(t)
private int Inner(Order o)
Inner(o) -> o.Total

public int SumO(list<Octet> xs)
SumO([])       -> 0
SumO([x, ..t]) -> Bump(x) + SumO(t)
private int Bump(Octet n)
Bump(n) -> n + 1
```

Called from Erlang with `[Order, Invoice{Total=999}]` and `[1, 1.5]`.

### Option 1: one rule, exported only (the ticket's "it is a defect" reading)

- `OuterL([Order, Invoice])` returns `1009`. `(InnerAsValue())(Invoice)` returns `999`. `Nested(Wrapper{Cust=Order})` returns `5`. `SumO([1, 1.5])` returns `4.5` (as today). (Probe 02, column B.)
- Compiler delta: one line, `{ok, _} when not Public -> {Pat, []};` (probe `patch-tag-exported-only.sh`). Saves 12 bytes of Code and about 8 ns per element per private record parameter (3.3, 3.5, 3.6).
- Docs delta: 46's "Corrections" and F24 §3 become true as written.
- **Strongest counterargument**: it ships the exact failure 18's headline guarantee exists to rule out ("a foreign term that breaks your types will crash ... never silently"), for records, at three doors measured in 3.2. Its stated defence, that private call sites are checked, is false for each of them. It also removes a check that today catches a same-shape wrong record, which the tag test was introduced for (26 §1).

### Option 2: one rule, every function with a ground-typed parameter (visibility is not an input to the guard)

- Same ten calls: all ten of the forged ones raise `function_clause`; the three controls still return 20, 5, 5. (Probe 02, column C.)
- Notably `SumO([1, 1.5])` and `SumO([300])` now raise, caught at the private `Bump`, so the container hole 46 §4 accepted at the door is closed whenever the element reaches any typed function.
- Compiler delta: delete `when Public` and the `none -> {Pat, []}` fall-through (`bs_emit.erl:284, 288-290`), about 4 lines; `is_public`/`Public` stop being threaded to `clause/4` and `guard_one/7`. No new pass, no new table.
- Cost (OTP 25 here): +12 Code bytes per private record parameter, +18 per private refined-int parameter, +0 to +2 ns per call for an int helper, +8 ns per call for a record helper, and a plain-int loop showed none (3.3, 3.5, 3.7). erlc drops `is_integer` but not the range or tag test when a single caller proves it (3.4), so some of the cost is real, not elided.
- Docs delta: 18 §4's "exported function's own clause heads" must be re-read as "the function whose guard is being decided", and 18 §1's *"interior functions already pay nothing — which is the shape C wanted anyway"* (`18-boundary-defence.md:616-617`) is withdrawn. 46 §1 and F24 §2 lose "exported only". F24 scenario F24.6 (`Inner` unguarded) flips.
- **Strongest counterargument**: it contradicts the text of 18 §4 and F24 §2 and spends bytes and nanoseconds on the direct `Outer -> Inner` path where the guard is provably redundant (probe 01 shows both tests back to back). The cheaper way to avoid that, a second unguarded entry per private function, is ruled out by the one-entry-label finding (18 §1), and elision from call-site knowledge is the whole-aggregate analysis that 18 §4 rejected.

### Option 3: keep both rules as built and write the reason down

- Behaviour is column A. `OuterL([Order, Invoice])` raises, `SumO([1, 1.5])` returns `4.5`.
- Compiler delta: none; only comments and the docs named in Q4.
- **Strongest counterargument**: the only reason that could be written is that tag errors matter more than kind errors, but 18's guarantee is stated for both, and the F24 header itself describes the int case as the silent-wrong-answer defect (`100.5 >= 9` is true). In A, `(BumpAsValue())(1.5)` returns `2.5` and `SumO([300])` returns `301` through the very doors where the tag test protects records. The ticket's own phrase applies: one function, two scopes, "nothing saying why". Nothing true says why.

Rejected before they become options:

- **Narrow plus a deep check at the exported door.** Decided against by 46 §4 and priced in probe 10 (quadratic: 98 ms against 0.29 ms at n=4000, hand-written mimic).
- **Guard a private function only when something references it as a value or passes it an unguarded argument.** Needs the callers' files to decide a callee's emitted code; that is the cross-file dependency 18 §4 refused.

## 6. Recommendation

**Option 2: the boundary guard's scope is "every function", for both the tag test and the kind test, and `is_public` leaves `guard_one`.**

Why, in order of weight:

1. The ticket's deciding premise is falsified. Private functions are reachable with unchecked values by three paths I executed, and Option 1 turns each into a silent wrong answer (3.2: 1009, 999, 5).
2. The cost side is small and bounded. About 12 bytes and about 8 ns per private record parameter, and an int helper pays at most a couple of nanoseconds. Too narrow is a silent hole, too wide is measurable and loud. The ticket itself says the asymmetry runs in that direction.
3. It removes the asymmetry the ticket wants stated once, instead of documenting it, and it makes the int guard stop contradicting 18's own guarantee at the same doors (Option 3's problem).
4. As a side effect it closes part of the container hole that 46 §4 accepted, wherever an element flows into a typed function.

What it costs the decision record: 18 §4 and 18 §1's "interior functions pay nothing" need a dated amendment, because they are now wrong, not merely narrow. Q4 is the place for that.

If David weighs the redundant check on the direct `Outer -> Inner` path more heavily than the three doors, the fallback is Option 1 with the container/escape doors named as accepted limits in 18 §4, but I would not recommend it: it needs the sentence "a forged same-shape record can silently produce a wrong answer" written into the spec.

## 7. Limits and what I could not verify

- **OTP 25, not 28.5.** All byte counts, erlc elision (3.4) and timings are OTP 25, on a noisy x86 VM. The ticket's numbers come from OTP 28.5 arm64. Option 2's cost could be lower on 28.5 if its type pass elides more, or the same. Treat my numbers as order-of-magnitude.
- **`bsc` is an OTP-25 build of the repo's code** with the patches in section 3. Column positions are lost. Emitted guards are the real emitter's. I did not run the repo's eunit suite; Option 2 would flip F24.6 and probably some `emitted(...)` assertions in `test/boundary_kind_tests.erl`, which I did not check.
- **Elm** was not run (package server returns 403, probe 08); the Elm statement is from the repo's research file. **Elixir** was measured, not read from source (no `.ex` files installed). **Gleam 1.5.0** is older than the 1.18.1 the tickets cite; I do not know whether later Gleam versions emit any guards.
- **Hand-written, not `bsc` output:** probe 10 only.
- **Not probed:** that an exported function pays its guard on calls from inside its own module (a BEAM fact from 18a, not re-run); behaviour for union-of-records parameters (the tag test is emitted only for a single closed record, `bs_emit.erl:253-255`, so unions have no tag guard anywhere, public or private, and this ticket does not touch that); behaviour of generated gen_server callbacks that are not `public` in B#; an element consumed inline in an exported body (inferred only).
- **Noise:** probe 05 and 11 timings overlap across variants on several rows; I report medians and ranges and make no claim finer than about 1 ns.
- **Ticket accuracy notes:** `boundary_guards` is `/6` now, not `/5` (ticket) or `/4` (46, comment). The claim *"18's own cost section measured that a non-exported function has the test elided entirely"* holds only for `is_integer` with a single caller on OTP 25 (3.4).

## Verification errata (independent verifier, see 59-verification.md)

Probes 00–04, 06–09 reproduced; none circular. Corrections that supersede the text above:
- Probe 11: a plain-int loop under the wide scope was 1.6x slower in 3 of 6 reruns and the refined-int helper loop +20–30% in all 6. "Small and bounded" is too soft; the recommendation rests on correctness, not cost.
- "ten doors" should read nine (9 forged calls, 3 controls).
- Citation: `bs_emit.erl:253-255` is `259-262`; ticket 46 line ranges are off by one; ticket 18 lives in `issues/`, not `research/`.
- Weakly supported: the single-caller elision cause has no control; Option 2's "every ground-typed parameter" was probed for int and record types only; the Elm row is unverified.
