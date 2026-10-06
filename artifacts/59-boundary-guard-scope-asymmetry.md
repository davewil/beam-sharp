# Decision brief — ticket 59 (ENG-241): the boundary guard's two scopes

Status: **brief, not a resolution.** Nothing in `compiler/`, `wayfinder/` or `docs/` was edited and Linear
was not touched. Every probe is in `artifacts/probes/59/` (`run.sh` re-executes all of it from scratch,
raw outputs in `out/`, edits-after-output logged in `CHANGELOG.md`). Probe ids below are `p01`..`p12`.

## 1. Sub-decisions

The ticket reads as one question. It is five, and one of them gates the rest (project rule: ask the gating
one alone).

| # | question | note |
|---|---|---|
| **G** | **Does a private function's parameter get a boundary test when the value it receives may not have been tested by any B# call site?** | Gating. The ticket's "defect" side assumes the answer is "never happens". p02 shows it does (list element, library walker). S1, S2, S3 and S4 follow from G. |
| S1 | Scope of the record **tag** test (`bs_emit.erl:277`, no `Public` condition) | answered by G |
| S2 | Scope of the **int kind** test — and, at the same site, the **range** test (F37) and the **float kind** test (F51, `float_guard/3`, `bs_emit.erl:296`). The ticket's table names one of three exported-only tests | answered by G |
| S3 | Is "exported" the right discriminator? | G restated: BEAM's own discriminator is *call-site proof* for `is_integer`, not visibility (p03, §3) |
| S4 | One rule for both guards? | yes under any answer to G that is not today's; today's two-rule state is the thing the ticket objects to |
| S5 | What does a forged record through an exported function into a private one do **today**? | measured, §2 E2 |

## 2. Executed facts

All against the repo's built `bsc` (or copies of its source: `base` = unmodified, `a`/`b`/`c` = the three
options, `patches/option_{a,b,c}.patch`). OTP 28 (erts 16.4), Elixir 1.19.5, gleam 1.18.1.

**E1 — reproduction (p01).** The ticket's measurement reproduces.

```
emitted Erlang  'InnerRec'(O) when map_get('Kind', O) =:= 'Scope.Order' -> map_get('Total', O).   % private
                'InnerInt'(N) when N >= 0 -> N; ...                                              % private: no is_integer
                'OuterInt'(N) when is_integer(N) -> 'InnerInt'(N).                               % exported
beam_disasm     InnerRec/1: {bif,map_get,{f,5},[{atom,'Kind'},..]}, {test,is_eq_exact,{f,5},[..,{atom,'Scope.Order'}]}
```

Source read (`compiler/src/bs_emit.erl`): `Public = is_public(F)` at **:163**; `guard_one/7` at **:275-291**;
the record branch `{ok, Tag} ->` at **:277** has no `Public`; the int/float branch is `none when Public ->` at
**:284**; the fall-through `none -> {Pat, []}` at **:289**. Corrections to the ticket's wording: the function is
`boundary_guards/6` (:265) delegating to `guard_one/7`; the comment ticket 46 quoted (*"unconditional on an
exported record parameter"*) is **gone** from source (grep: only tickets 46 and 59 contain it); the comment now at
**:330-333** says *"The record tag guard above is emitted on private functions too; that asymmetry is deliberate."*

**E2 — a forged value through an exported function (p02, `src/Deep/deep.bs`, driven from Erlang with forged terms).**
`raising fn` is the first `Deep` frame of the stack trace.

| case | base (today) | a: tag exported-only | b: guards on every fn | c: b + elide proven tags |
|---|---|---|---|---|
| `Top(forged Invoice-as-Order)` — whole parameter | `function_clause` in **Top** | same | same | same |
| `SumTotals([Order, forged Invoice])` — list element, then private `Amount(Order o)` | `function_clause` in **Amount** | **`{ok,14}` silent** | `function_clause` in Amount | same as b |
| `SumTotals([Order, #{}])` | `function_clause` in Amount | `{badkey,'Total'}` (body objects) | `function_clause` | `function_clause` |
| `SumWeights([1, 100.5])` — float element, private `Weight(Octet)` | **`{ok,3}` silent** | `{ok,3}` silent | `function_clause` in Weight | same as b |
| `SumWeights([1, 300])` / `[1, foo]` | `{ok,3}` / `{ok,3}` silent | silent | `function_clause` in Weight | same as b |
| `Doubled([1, 1.5])` — private `Twice/1` handed to `List.Map` | **`{ok,[2,3.0]}` silent** | silent | `function_clause` in Twice | same as b |
| `WeightPub(100.5)` — exported control | `function_clause` | same | same | same |

- **Refined from the ticket:** the ticket's argument that *"a forged record can reach a private function by
  being passed through an exported one"* is **false for a whole parameter** — the exported tag test raises in `Top`
  and `Amount` never runs. It is true one projection down. Ticket 46 §4 (`46-refined-parameter-at-the-boundary.md:213-222`)
  decided a guard is **"never through a collection"** (O(n) in a length the foreign caller chooses), so a collection
  element is unwalked at the boundary by decision, and the only test that ever sees it is the consuming function's own.
- Today the two guards are therefore *not* equally good at that: the record is defended (by the private tag test) and
  the int/float/range is **silent** (C7-C9, C12). The expensive test is the one that protects.
- `p12`: the ENG-330 hole (F24 §6, private `Tag(int x)` fed by a narrowing guard, atom crossing `public int`) is closed
  today: `Bump(:foo)` → `0` on base and on b. F24 §6 itself says *"Privacy is what makes it silent"*: the premise that a
  private function's call sites are all checked has already been wrong once, in the checker.

**E3 — ticket 18's "a non-exported function has the test elided entirely" (p03, `erlc -S`).** **Reproduced only
narrowly; REFUTED as a general statement.**

```
ex_f   (exported, called locally from a guarded caller)   {test,is_integer,{f,1},[{x,0}]}      kept
lo_f   (private, only caller proved is_integer)           {'%',{var_info,{x,0},[{type,{t_integer,any}}]}}   elided
un_f   (private, caller passes an unknown term)           {test,is_integer,..}                  kept
tag_f  (private, only caller just ran the identical tag test)  {bif,map_get,..} {test,is_eq_exact,..}  KEPT
```

and through bsc: option b emits `is_integer` on private `InnerInt` in the Erlang forms (p03) and the beam has it
**gone** (identical code to base, 164 B both); `InnerRec`'s tag test stays. 18a's own case (c) already says an
unknown-typed caller keeps the test; the ticket's paraphrase dropped that. The tag test is **never** elided: `erlc` keeps
no map-element types (`beam_types.hrl:113-116`, *"we don't track specific elements"*).

**E4 — one entry label (p03).** Reproduced: `ex_caller`'s `{call_only,1,{f,2}}` targets label 2, the label whose first
instruction is `ex_f`'s `is_integer` (`out/p03/labels.txt`: `call_only target label=2  ex_f entry label=2`). An exported
function pays its guard on in-module calls, as 18 §1 says.

**E5 — existing tests (p11; 13 modules that exercise the guards, 211 tests).** base green; **a green** (nothing pins the
private tag test); **b and c red on exactly two**: `boundary_kind_tests:a_private_function_is_not_guarded_test`
(`compiler/test/boundary_kind_tests.erl:88`, F24.6) and `boundary_range_tests:a_private_function_carries_no_range_guard_test`
(`boundary_range_tests.erl:122`, F37.5). Full suite: base only, 1312 passed (`out/p11_base_full.log`); a/b/c full runs were
cancelled by per-test timeouts on the loaded host, so they are not claimed.

**E6 — corpus (p10, `compiler/examples`, 27 module dirs, deduped by module).** 95 exported, 24 private functions.
**No private function in the corpus has a record parameter**, so option a changes 0 functions (0 B) and c == b.
Option b adds 9 `is_integer` conjuncts to **7 private functions in 4 modules** (Foreign, Pipeline, Shop.Collections.Ints,
Shop.Pricing); after `erlc`, total `Code` bytes 8004 → 8013 (**+9 B, +0.11%**). The exemplars do not compile
(`no module line` / syntax; `out/p10/exemplars.txt`), so this is a source-level regex count (p10b, a heuristic, not the
compiler): of **64 private functions in `compiler/examples/exemplars`, 8 have a single-record parameter and 4 an `int`**.
The exemplar shape is exactly E2: `25e-dynamic-web-page/rows.bs` — `Rows([o, ..rest], acc) -> Rows(rest, [Row(o), ..acc])`
into `private Iodata Row(OrderRow o)`.

**E7 — the spec already says "exported".** `LANGUAGE.md:3576` (*"the boundary tag guard on an exported record parameter —
shipped"*) and `:3577` (the `int` guard, exported). bsc emits the tag test on private functions too, so spec and oracle
disagree today on observable behaviour (E2 row 2): a clean-room implementer following the spec gets `{ok,14}` where the
oracle gives `function_clause`. That is a part-3 (handoff) cost of leaving it undecided.

## 3. Neighbour survey

| system | scope rule | evidence |
|---|---|---|
| **Erlang/OTP `erlc`** | no visibility rule in the front end; `beam_ssa_type` drops a type test when **every call site** proves it, and only for non-exported functions | `compiler-9.0.6/src/beam_ssa_type.erl:122-123` (exported args start `any`, local `none`); `:428-433` (*"a local function ... we're guaranteed to have visited every call site"*); `:434-438` (*"can't infer the parameter types of exported functions"*). `sys_core_fold.erl`: grep for `exported` finds nothing (not a source reading beyond that). `beam_types.hrl:113-116`: `#t_map{super_key, super_value}` only. |
| **Elixir** | none; the author writes the guard/struct pattern, `def` and `defp` identical | p07: `defp priv_rec(%Order{})` keeps `is_eq_exact 'Elixir.Scope.Order'` exactly as `def`; `defp priv_int` keeps `is_integer` because `run/1` also captures `&priv_int/1`; capture-free `defp only_proven` (sole caller proves integer) loses it (erlc, not Elixir). Elixir sources are not installed: behaviour only. |
| **Gleam** | none at either scope; trusts types | p08: generated `pub_amount(O) -> erlang:element(3, O).` and private `priv_amount` identical; `pub_double(1.5)` → `{ok,3.0}`; forged `{wrong,9,9}` through private `priv_amount` → `{ok,11}`; non-record dies only in the body's `erlang:element/2` (`badarg`). No Gleam compiler source installed. |
| **Elm** | not testable here | p09: `elm make` needs `package.elm-lang.org`, proxy returns 403. 18's Elm claim (decoder at the port, the one door) is **not re-verified**. |

None of the three makes visibility a *guard* rule. The one mechanism that distinguishes interior functions is
`erlc`'s call-site proof, which is the answer to S3: the BEAM's discriminator is **"is every call site proven"**, and
`exported` is just the case where that is unknowable.

## 4. Measurements

**Bytes of `Code` per guard (p05; one tiny module per case; private function reached through a list element so the
caller proves nothing; `Code`-chunk delta).**

| test | delta | note |
|---|---|---|
| record tag, 1 / 3 / 8 fields | **+12 / +12 / +12 B** | flat reproduced; **ticket says +14**: not reproduced, 12 here (26a's harness not re-run) |
| `is_integer` (plain `int`) | **+5 B** | ticket +3-5: reproduced at the top of the range |
| `is_float` | **+3 B** | |
| `Octet` (`is_integer` + 2 range comparisons) | **+12 B** | range half is not in the ticket's cost figure |
| private function whose every caller proves `int` (p01/p03) | **0 B** | `erlc` drops it |

**Call time (p06; same B# source under 5 builds, interleaved, 9 reps after 1 warm-up, 20 000 calls x 1000 elements =
2e7 element visits per rep, estimator = min, 3 rounds kept in `out/p06/bench.txt`; tail-recursive walk calling the
private function once per element).** Host: 4 vCPU Xeon 2.8 GHz, **shared with other sessions' jobs** (loadavg 3-4 at the
last three rounds, 16-26 during two earlier runs whose results agreed but were not kept). Noise floor = `Base` vs `Base2`
(identical code); a second floor for the Weights loop is `A`, whose `Weight` code is byte-identical to base's but which sits
**0.9 ns lower**, so a layout effect of that size exists between *different* modules.

| loop (min ns/element, rounds 1/2/3) | Base | Base2 (floor) | A (no private tag) | B (private int+range) | C | verdict |
|---|---|---|---|---|---|---|
| private `Amount(Order)` per element | 13.59 / 13.42 / 13.35 | 13.48 / 13.54 / 13.52 (<= 0.12) | **8.20 / 8.24 / 8.10** | 12.28 / 12.39 / 12.55 | 12.29 / 12.31 / 12.31 | **tag test = +5.4 / +5.2 / +5.3 ns per element**, >40x the floor. B is *faster* than base by 0.8-1.3 ns: resolved against 0.12 but the cause is not isolated, so not claimed as a benefit |
| private `Weight(Octet)` per element | 6.27 / 6.25 / 6.27 | 6.28 / 6.25 / 6.35 | 5.35 / 5.37 / 5.42 | 6.82 / 6.79 / 6.80 | 6.93 / 6.78 / 6.83 | B - base = +0.5, **below** the 0.9 layout floor: **not reported as a difference** |

So: the tag test is resolvable (~5.3 ns per consumed element in a tight loop; a worst case, a record walk is not the hot
path of most programs). The ticket's *"call time below its ±0.09 ns/call resolution"* is **not reproducible with this
method on this host** (floor 0.1-0.9 ns; that figure was for exported `is_integer` through a `call_ext` harness). int, float
and range at a private function are **unresolved** here, not shown free.

**What each option does to the corpus:** a: 0 functions; b: 7 private functions gain a test, +9 B in 8004; c: same as b.

## 5. Options

The question each answers is **G**. One program, compiled under each (`src/Deep/deep.bs`, shortened):

```csharp
module Orders

record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

public int SumTotals(list<Order> os)               // 46 §4: a collection is never walked at the boundary
SumTotals(os) -> FoldTotals(os, 0)

private int FoldTotals(list<Order> os, int acc)
FoldTotals([], acc)           -> acc
FoldTotals([o, ..rest], acc)  -> FoldTotals(rest, acc + Amount(o))

private int Amount(Order o)
Amount(o) -> o.Total

public list<int> Doubled(list<int> xs)
Doubled(xs) -> List.Map(xs, Twice/1)

private int Twice(int n)
Twice(n) -> n * 2
```

called from Erlang (a mailbox, an ETS read, a decoded term, any untyped caller):

```
SumTotals([#{Kind => 'Orders.Order',...,Total => 5}, #{Kind => 'Orders.Invoice',...,Total => 9}])
Doubled([1, 1.5])
```

### Option A — exported only, for both (18 §4 to the letter)

| call | result |
|---|---|
| `SumTotals([Order 5, Invoice 9])` | **`14`** — an Invoice summed as an Order, no error |
| `Doubled([1, 1.5])` | **`[2, 3.0]`** — a float returned from `list<int>` (unchanged from today) |

**Compiler delta.** `{ok, Tag} when Public ->` at `bs_emit.erl:277` and `none -> {Pat, []}` generalised to `_`
(`patches/option_a.patch`, 2 lines). Removes the tag test from every private record parameter: **-12 B each, flat in
field count; ~-5.3 ns per element visit in the tight loop (13.6 → 8.2)**. Existing tests: none red (E5). `LANGUAGE.md:3576`
already says "exported", so no spec change. Corpus effect: 0 functions.

**Strongest counterargument.** It turns ticket 46 §4's decision (a collection is never walked) into an **unguarded hole for
records too**, and it is the exact guarantee 18's decisions entry states — *"a foreign term that breaks your types will
crash — not always where it entered, but never silently"* — that is lost: `SumTotals` returns `14` for a map wearing the
wrong aggregate identity, which is the thing ticket 26 minted tags to prevent. The private guard is the only test that
ever sees a collection element; removing it also removes the one defence the int/float/range paths never had.

### Option B — every function, both guards (delete the `Public` condition)

| call | result |
|---|---|
| `SumTotals([Order 5, Invoice 9])` | `function_clause` in `Amount/1` (as today) |
| `Doubled([1, 1.5])` | `function_clause` in `Twice/1` (**new**; today silent) |

**Compiler delta.** `bs_emit.erl:284` `none when Public ->` becomes `none ->` and the dead fall-through clause at :289 goes
(`patches/option_b.patch`: 3 insertions, 5 deletions, **net deletion**); then the `Public` boolean threaded through
`function/2` (:159-164), `clause/4` (:169), `boundary_guards/6` (:265) and `guard_one/7` is unused and can be removed, and the
comments at :159-162 and :330-333 rewritten. Reverse the two tests that assert exported-only
(`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122`); amend F24 §2 *"Exported only"* and F24.6, F37.5,
`LANGUAGE.md:3577`, and 18 §4's *"the exported function's own clause heads"* to *"the function's own"* (the analysis stays
function-local: each function's guard depends on its own head only).

**Measured.** +5 B per `int` param, +3 B `float`, +12 B `Octet` (kind + range) **only where `erlc` cannot prove the caller**;
0 B where it can (`InnerInt`: 164 B before and after). Tag test: unchanged from today (+12 B, ~5 ns/element) because it
already is on. Corpus: +9 B in 8004 over 27 modules, 7 of 24 private functions touched. Time for int/range: not resolved
(+0.5 vs a 0.9 ns/element layout floor). B's accumulator guard `is_integer(Acc)` survived `erlc` in `FoldTotals` (the callee's result type
is unknown) and still showed no cost in the loop (12.3 vs 13.6 ns/element).

**Strongest counterargument.** It **double-tests** a value the exported function already tested (`Top` → `Amount`: the tag is
checked twice, +12 B and ~5 ns on that hop) and `erlc` cannot remove the second one because it keeps no map-element types;
it reverses the explicit text of F24 §2/F37.5 and two tests; and it makes every private recursion accumulator pay
`is_integer` per iteration where the compiler cannot see the callee's return type.

### Option C — guard a private function only where a caller has not already tested (discriminator = proof, not visibility)

Same table as B (the guard stays wherever a collection or a higher-order walker supplies the value). Differs from B only
where every caller is a B# call passing an already-tested top-level parameter: there, the private tag test is dropped
(`Scope.InnerRec`: module Code 164 → 152 B, p05 rows `out/p05/scope.txt`; p02 column c unchanged).

**Compiler delta.** Option B plus a post-pass over the emitted forms, `elide_proven_tags/1` (`patches/option_c.patch`, **~230
lines of diff, prototype**): for each private function, find every reference in the module; drop the tag-test conjunct at
position *i* iff every reference is a direct call whose *i*-th argument is a top-level head variable already tag-tested
(fixpoint over private callers) or a `Kind`-carrying map literal; any capture, atom mention, projection-below-top argument, or
variable shadowed in a `fun`/comprehension keeps it. Integer kind needs nothing: `erlc` does it (E3).

**Measured.** Corpus effect over B: **0** (the examples contain no private record parameter). Probe effect: -12 B on
`Scope.InnerRec` (p05); kept on `Deep.Amount` (list element) and `Deep.Twice`/`Weight`. Existing tests: red on the same two as B.

**Strongest counterargument.** It buys 12 B and ~5 ns on a shape the corpus does not contain, with a whole-module pass whose
output depends on **other functions' bodies** — an edit to a caller silently changes a callee's emitted boundary, which is
the blast-radius argument 18 §4 used to reject whole-aggregate analysis (here within one module directory). It is also the
largest new code (a call-graph walk with shadowing rules) in a compiler where, by the project rule, a gate must guard it.

## 6. Recommendation

**Option B.** Answer G "yes": a private function's parameter is tested like an exported one's, for the tag, the int kind, the
range and the float kind alike, and the discriminator is not visibility.

Why, from the evidence only:
1. The premise that makes the private test "dead weight" (*every private call site is a checked B# call site*) is false at two
   shapes the exemplars actually use — a list element and a function handed to `List.Map` (E2, `25e/rows.bs`) — and 46 §4
   decided collections are not walked at the boundary, so nothing else ever tests those elements.
2. Today's rule protects records and not ints in exactly those shapes; A makes records as silent as ints, B makes ints as
   defended as records. 18's own guarantee ("never silently") and 18:194-196 (*"a foreign value entering through an exported
   function reaches private ones unchallenged"*) point the same way.
3. The cost is bounded where it can be measured: 0 B where `erlc` proves the caller, +3/+5/+12 B where it cannot, +9 B across
   the whole 27-module corpus; the one resolvable time cost is the tag test, which B does not add (it is on today).
4. It is the smallest change (a net deletion that also removes the `Public` parameter), keeps 18 §4's function-local analysis
   intact, and makes `LANGUAGE.md:3576-3577` and the oracle agree after a wording change to "every function".

Hold C back unless a measured hot path shows the double tag test mattering; A only if the human decides the collection hole
is acceptable and records it, since E2 shows what that costs.

## 7. What I could not verify

- **Elm** (needs network). 18's Elm-decoder claim is untested here.
- **Elixir and Gleam compiler sources** are not installed; both surveys are generated-code behaviour, not source lines.
- **Call time** was measured on a shared host; absolute ns are indicative only, int/float/range cost at a
  private function is **unresolved**, and 18a's ±0.09 ns `call_ext` method was not re-run. JIT native size and arm64 (18a's
  arch) not measured; this is x86_64.
- **+14 B** (26a) not reproduced: measured +12 B with a different harness; 26a's harness not re-run.
- **Full test suite** passed only for base (1312). a/b/c were run on 13 guard-relevant modules (211 tests); the full runs
  were cancelled by timeouts under load.
- **Exemplars** do not compile; their counts are a regex over source, not compiler output.
- **Option C** is a prototype exercised by p02/p03/p05/p10/p11 only; its shadowing rules are untested beyond the probe programs.
- Not probed: private functions reached by OTP callbacks (40 §3 / `private_callback` refuses a private callback), `spawn`ed
  private function values, and hot code upgrade — I have no evidence on whether any of them supplies an unchecked value.
- F24 §6's pre-ENG-330 behaviour is cited from the text, not reproduced (p12 shows only the fixed state).
- The `compiler/features/F24` scenario table's "F24.6" and the ticket's `boundary_guards/5` vs the code's `/6`: wording drift,
  no behavioural consequence.

### Ticket facts refuted or not reproduced

1. *"A forged record can reach a private function by being passed through an exported one"* — **false for a whole
   parameter** (caught in `Top`); true only one projection down (E2).
2. *"18 measured that a non-exported function has the test elided entirely"* — **reproduced only for `is_integer` with proven
   callers; refuted as general** (kept with an unproven caller; the record tag test is never elided) (E3).
3. *"+14 bytes, flat"* — flat reproduced, **12 B not 14**.
4. *"call time below ±0.09 ns/call"* — **could not reproduce** the resolution; floor here 0.1-0.9 ns; tag test resolved at ~+5.3 ns/element.
5. *"the ticket's table: one exported-only int test"* — **incomplete**: float kind (F51) and range (F37) share the scope.
6. *Ticket 46's quoted comment* — **no longer in the source**.
7. *"a private function's every call site is a checked B# call site"* — **contradicted** by E2 (list element, `List.Map`).

## Verification errata (independent verifier, `probes/59/VERIFICATION.md`)

The verifier re-ran from a fresh copy (0 failed assertions) and re-tested the key claims on its own B# module, Erlang driver and hand-edited A/B/"no tag test" builds: forged `Invoice` in a list is silent `{ok,14}` under A and `function_clause` under B; a forged whole parameter raises in the *exported* function's tag test (with the tag test removed everywhere it becomes `{ok,9}`), so the ticket's claim is refuted; the tag test is 12 B and flat for 1/4/12 fields (the ticket's 14 B is not reproduced); A passes 1312/1312, B fails exactly `boundary_kind_tests:88` and `boundary_range_tests:122`; corpus 8004→8013 B reproduces. No circular probe. Corrections:

1. **Wrong denominator:** "7 of 24 private functions" counts 8 compiler-generated functions (`bs@validate@*`, `bs@List@flip`); it is **7 of 16 user-written** ones.
2. **The hole is wider than stated.** A tuple element and a nested record field also reach a private function with the wrong tag (silent under A, caught under B). Ticket 46 §4's cost argument excluded collection walking, not tuple elements or record fields, so this hole is not "by decision". It strengthens Option B.
3. The B-vs-base `+0.54…+0.60 ns` on `Weights` is B's whole guard set (including `is_integer(Acc)` in `FoldWeights`), not `Weight(Octet)` alone; int/float/range remain unresolved. The tag test's ≈5.3 ns/element reproduces (noise floor 0.04–0.15 ns).
4. "Single-record parameter" is loose: several of the 8 exemplar functions take two or more records (census 64 / 8 / 4 recomputed identically).
5. `out/p05.txt` is stale (no Scope rows); the numbers are in `out/p05/scope.txt`. p09 (Elm) cannot run; p06 reproduces for the tag test only.
6. Citations: `beam_ssa_type.erl` :428-433 / :434-438 are off by 1–3 lines (content right). Option C's patch was not audited line by line (one adversarial cycle case was safe).
