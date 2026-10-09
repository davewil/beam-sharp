# Decision brief: ticket 59 (ENG-241), the boundary guard's two scopes

Prepared 2026-10-08 for a human decision. Nothing here is resolved. No Linear change, no edit to `wayfinder/` or `compiler/`, no commit.

All probes are under `artifacts/probes/59/` (the `*.out` files are the captured output). Run with the scratch OTP 25 build of bsc (`/tmp/bsbuild`, lexer shim, so diagnostic columns are wrong and nothing else is). Compiler variants are patched copies; the diffs are `artifacts/probes/59/patches/*.patch`:

| variant | change | patch |
|---|---|---|
| base | the emitter as pinned in `compiler/src` | |
| A | record tag test on exported functions only | `A-tag-exported-only.patch` (+1 line) |
| B | `is_integer`, range and `is_float` tests on every function | `B-kind-on-private.patch` (-3 lines) |
| E | both guards on `public` or address-taken (`Name/N`) functions | `E-guard-public-or-address-taken.patch` |
| C, D | no tag test anywhere / no kind test anywhere (size measurement only) | `C-*`, `D-*` |

## 1. The question

`bs_emit` applies two boundary guards with different scopes. The record tag test goes on every function, private included. The `int` kind and range tests go on exported functions only (ticket 18 §4, F24, F37).

**Is the tag test on a private function a defect against 18 §4, or is 18 §4's "exported" too narrow for the tag test?**

The answer has to be one rule for both guards, stated once. That includes the sentence in 18 §1 that private functions pay nothing.

## 2. Stale or wrong premises (checked against the current tree)

1. **The signature is `boundary_guards/6`, not `/5`** (`bs_emit.erl:265`; the ticket says /5, ticket 46 says /4). `Public` is now passed in, from `is_public(F)` at `:163`. It is consulted only on the `none when Public` branch (`:284`, the int and float guards). The record branch (`:277`) never reads it. Ticket 46's "nothing consults `is_public/1`" is therefore out of date, but the asymmetry it described is exactly as stated.
2. **The asymmetry is measured on the pinned emitter** (`probes/59/a.out`). `Inner(Order o)` private has `when map_get('Kind', O) =:= 'Ledger.Order'`. `Double(int n)` private has no test; the public `DoubleP` has `is_integer`. A private function whose parameter is a relational pattern (`Band2(<= 64)`) gets no kind test at all.
3. **"The tag test is dead weight because a private function's every call site is a checked beam-sharp call site" (ticket 59, "It is a defect") is false for values nested in an aggregate.** The exported boundary tags only the top-level parameter. `list<Order>` elements and the fields of a record or map are not walked (O(n) refusal in 46 §4, F24 §5, "owed"). A forged record inside such an aggregate reaches a private function whose call site was never a check on a foreign value. See §5.
4. **The elision claim in 18 §1 needs a qualifier.** Ticket 18 says "interior functions already pay nothing". 18a §4(c) already measured the qualifier: a local function's `is_integer` is elided by `erlc` only when every caller has proved the type (`e_lo`). It is paid when a caller passes an unknown type (`e_un`).
   - **Verified here (`probes/59/elision.out`):** the elision belongs to `erlc`, not to the language.
   - **Reproduced by reading:** `beam_ssa_type.erl:119-120` (exported functions start at `any`, local ones at `none`) and `:708-725` (`make_fun` hands the callee `any` arguments, so a captured private function keeps its test).
   - **Not elided:** the tag test. `Tot(Order o)` called from the already-tagged `Handle(Order o)` still carries `map_get`/`is_eq_exact` in the optimised beam.
5. **Ticket 18 (CORRECTED by the verifier: this is a misreading, do not rely on it).** The verifier found the `:194` paragraph is about omitting the failure arm and is conditional on there being no exported guard, so it agrees with §4 rather than contradicting it. The original reading follows, kept for the record: The intake note, "Constraints from ticket 12" (`18-boundary-defence.md:194`), says: *"Restricting omission to non-exported functions is not an alternative — a foreign value entering through an exported function reaches private ones unchallenged."* §4 (`:817`) and §1 (`:439-441`) say the opposite. Both are resolved text.
6. **F24 is itself a precedent against the "private is already checked" premise.** F24 §6 found that a private `Tag(int x)` helper behind a union-narrowing guard returned `:foo` from a `public int` ("Privacy is what makes it silent"). That was fixed at the narrowing site, not by guarding the private function.
7. **"Exported" is stated in three more places.** `CONTEXT.md:398` (heading at :397) ("Boundary guard ... on an exported function's parameter"), `LANGUAGE.md:3638`, and 26 §1 ("every exported function taking a record"). A decision touches all of them.
8. **The private tag test is unpinned, and the private kind test is pinned.** Run (`probes/59/eunit.out`) against `records_tests`, `boundary_kind_tests` and `boundary_range_tests` (34 tests):

   | emitter | result |
   |---|---|
   | base | 34 pass |
   | A (tag removed from private) | 34 pass |
   | B (kind added to private) | 2 fail: `a_private_function_is_not_guarded_test`, `a_private_function_carries_no_range_guard_test` |
   | E | 34 pass |

   `grep private compiler/test/records_tests.erl` returns nothing. The gate scripts `check-boundary-kind.sh` and `check-boundary-range.sh` do not mention private. F24.6 and F37.5 do.

## 3. Sub-decisions, in dependency order

- **S1 (gates everything). What is the discriminator for "this function gets boundary guards"?**
  - (a) syntactic `public` (18 §4 as written)
  - (b) every function (today's tag behaviour)
  - (c) `public` or address-taken
  - Ask this alone first. S2 to S4 follow mechanically.
- **S2. Is the answer one rule for both guards?** Yes by the ticket's own demand, so this collapses into S1. The only live variant is "tag follows S1(b), kind stays S1(a)", which is today's status quo and is what the ticket calls indefensible.
- **S3 (follows S1).** If the answer widens or narrows, the *text* has to change in one place and the others have to follow: 18 §4 sentence, 18 §1 "interior pays nothing", `CONTEXT.md:398` (heading at :397), `LANGUAGE.md:3638`, F24 §2/§3, F37.5, F3.9, the two pinned tests, and the F24.6/F37.5 scenarios. A feature may not decide this; it implements it (`CLAUDE.md`, "tickets decide, features build").
- **S4 (independent, not this ticket's).** Projection guards (46 §4, owed in F24 §5 and F37 "What this does not build") would test a record field or tuple element at the exported boundary. That closes the record-in-record and field-float paths. It cannot close list elements, which 46 §4 excludes as O(n). So S4 shrinks what S1(a) leaves open but does not remove it.
- **S5 (follows S1(c) only).** Whether function-local analysis (18 §4 "the standing constraint") survives: option (c) makes a function's emitted guard depend on a *different* function elsewhere in the module that takes its address.

## 4. Evidence

### 4.1 (a) what is emitted (`probes/59/a.out`)

| function | visibility | tag test | kind test |
|---|---|---|---|
| `Handle(Order o)` | public | yes | |
| `Inner(Order o)` | private | **yes** | |
| `DoubleP(int n)` | public | | yes |
| `Double(int n)` | private | | **no** |
| `Band(Octet n)` | private | | **no** (only the clause's own `N =< 64`) |

### 4.2 (b) can a forged record reach a private function, and is the private test the only thing stopping it?

Source: `probes/59/src/Ledger/ledger.bs`. The forged value is `#{Kind => 'Ledger.Invoice', Id => 1, Total => 100}`. It has every `Order` field but the wrong tag.

The test driver is `forge.erl`, and the results below are from `forge.out`:

| path | base (tag on all) | A (tag on exported only) |
|---|---|---|
| `Handle(forged)`: exported record param passed straight to a private function | `function_clause` | `function_clause` (**exported test already stops it; private test redundant**) |
| `Unwrap(#{Item=forged})`: forged record in a map field, `Inner(w.Item)` | `function_clause` | **`{ok,100}`, silent** |
| `Totals([forged])`: `List.Map(os, Inner/1)` | `function_clause` | **`{ok,"d"}` (that is `[100]`), silent** |
| `Sum(#{Orders=[forged]})`: fold lambda calling `Inner(o)` | `function_clause` | **`{ok,100}`, silent** |
| `Picker(x)(forged)`: exported function returns `Inner/1` as a value | `function_clause` | **`{ok,100}`, silent** |
| genuine records and an Order-tagged map missing `Total` (controls) | correct / `badkey` | correct / `badkey` (outcome 2, the body objects) |

`nest.out` repeats the record-in-record case with a `record Wrapper { Item: Order }`: even a declared record wrapper does not tag-check its `Item` field at the exported boundary. `A` returns `{ok,100}`.

**Answer to (b).** Yes. The private test is the only check in four shapes: a record in an unwalked field, a list element, a lambda called over a collection, and a private function whose address escaped. It is *not* the only check for the shape the ticket describes ("passed through an exported function"): there the exported function's own tag test fires first. The scenario the ticket's "not a defect" paragraph imagines is real only for nested values.

### 4.3 The kind test has the same hole in the same shapes (`probes/59/kinds.out`, `nest.out`)

Emitter `base`:

| call | result |
|---|---|
| `Doubled([1.5])` via `List.Map(xs, Double/1)` | `{ok,[3.0]}` out of a `list<int>` |
| `FromField(Cfg{Level=1.5})` | `{ok,3.0}` |
| `Picker(x)(1.5)` | `{ok,3.0}` |
| `Bands([300])`, `Bands([-5])`, `Bands([foo])` over `list<Octet>` | `{ok,[high]}`, `{ok,[low]}`, `{ok,[high]}` |
| `DoubleP(1.5)` (exported control) | `function_clause` |

Under B every one of these becomes `function_clause`. This is ticket 06's outcome 3 on a path the exported-only rule leaves open. 18's guarantee sentence is "will crash, never silently". The exported-only kind rule does not meet it for aggregates.

### 4.4 (c) a private function reachable by `fun`

- **Corpus precedent:** `examples/Shop/Pricing`, `Rule(:staff) -> Free`. A raw Erlang caller gets `fun 'Free'/1` back and can apply it to anything (F46).
- **Probe:** `Picker(x)(forged)` in the table above.
- **BEAM's view:** `beam_ssa_type.erl:708` gives a captured function `any` argument types, so its guard survives `erlc` (`elision.out`: `Cap`, "captured as fun", `beam_test=yes` under B).

### 4.5 Option E cuts the hole only part of the way (`probes/59/nest.out`)

Emitter E (guard if public or address-taken):

| path | outcome |
|---|---|
| `Totals`, `Picker` (functions that are address-taken) | closed |
| `Unwrap`: direct call with a nested record | **still `{ok,100}`** |
| `FromList`: direct call from a lambda | **still `{ok,100}`** |
| `FromField`: private `Twice` never captured | **still `{ok,3.0}`** |

### 4.6 Size (`size.out`, Code-chunk bytes, same source under different emitters)

| construct | Code bytes | notes |
|---|---|---|
| tag test, 1 / 3 / 8 / 16 fields, public | +12 (88 to 100) | flat; no field-count slope |
| tag test, same, private | +12 (119 to 131) | identical to public |
| kind test, public `int` | +5 | |
| kind test, private `int` called from `List.Map(xs, Get/1)` | +5 | |
| kind test, private `int` reached only from a guarded exported caller | **+0** | `erlc` elided it |

- **26a's +14 reproduced exactly on OTP 25** (`26a-rerun.out`). The emitted B# test is +12 against 26a's hand-written +14; the verifier found the 12-vs-14 gap is a harness artefact (the same hand-written guard compiles to +12), not a discrepancy in the claim.
- **`.beam` file deltas** include debug info and 4-byte padding, so they run +36 to +80 bytes; use the Code column. The ticket's "+3-5 bytes `is_integer`" holds (+5).

**Corpus effect of B** (`corpus.out`, `corpus-survive.out`; the compiling examples, 22 modules; `Signalbox` fails inside OTP 25's `core` pass under base too): 77 public and 12 private functions. B adds 19 `is_integer`/`is_float` tests to the *emitted abstract code* of the corpus (its private functions, reached from 15 local call sites). **0 survive in the optimised beam** (47 vs 47); `erlc` removed all of them. The control, module `Chain` with a captured private function, shows B > base (3 vs 2), so the probe can see a surviving test. No private function in the compiling corpus takes a record: the tag asymmetry currently costs and protects nothing there.

### 4.7 Call time (`bench.final.out`; 15 interleaved rounds each; noise floor = a byte-identical module `BenchBas2`)

OTP 25 JIT, x86-64, shared host (load average 4 to 8). Figures are ns per iteration; the estimate is the minimum, with the median and spread in the file.

| workload | base | A (no private tag test) | B (kind on private) | read |
|---|---|---|---|---|
| W5: one tag test per iteration | 23.8 | **15.5** | 24.9 | tag test costs **about 8 ns/call**, well outside the floor (base vs `BenchBas2`: 0.0) |
| W1: two tag tests per iteration | 47.6 | **15.9** | 50.0 | about 32 ns. **Explained by the verifier:** three tag tests run per iteration, not two (each of the two clause heads repeats the guard, plus `GetA`'s), so ≈3 × 8–10 ns |
| W2: private int loop, caller proven | 4.24 | 4.60 | 4.06 | kind test elided; B vs base -0.19 |
| W3: private fn mapped over a list (unknown callers) | 13.0 | 13.1 | 13.5 | B vs base +0.47; floor 0.83: **below noise, no claim** |
| W4: private loop, unknown-typed seed | 4.18 | 4.51 | 3.93 | B vs base -0.25: **below noise, no claim** |

The 8 ns figure for the tag test is larger than ticket 26's "the tag itself costs nothing measurable". 26a's re-run here (`26a-rerun.out`) shows map_get unguarded 16.45 vs guarded 22.63 ns/call, about 6 ns. 26 measured on arm64 OTP 28.5. On OTP 25 the emitted form is a generic `{bif,map_get,...}` guard instruction (`disasm`, `elision.sh`). **This number must not be carried to OTP 28 without a re-run.** The kind test is a different matter: nothing resolved.

### 4.8 Neighbours

- **Erlang/OTP, compiler.** `beam_ssa_type.erl:119-120, 432-441, 693-694, 708-725`: the compiler's own discriminator is *escaping*, not *exported*. A function whose address is taken is analysed with `any` arguments. B# `public` is a weaker notion than that.
- **Erlang/OTP, Dialyzer.** `dialyzer_dataflow.erl:2890-2894` builds its entry set from `dialyzer_callgraph:is_escaping/2`, the same notion.
- **Erlang authors.** `census.out` (OTP 25 stdlib + kernel, 18b's method split by visibility). Exported: 16.5% of parameter positions are defended by a pattern or a guard mention. Local: 10.7%. About 1 in 10 local positions is still type-guarded in every clause (10.4%). Authors guard private functions less, but not never.
- **Elixir 1.14.0** (`elixir/neighbour.out`, executed): there is no automatic guard, so no scope asymmetry exists to copy.
  - A `%Order{}` pattern on a `defp` head raised `FunctionClauseError` for a forged struct through all of: a nested map field, `&priv/1` mapped over a list, and an escaped `&priv/1`.
  - A `defp` with no pattern returned the forged struct's `total` (`{:ok, 100}`).
  - In Elixir the author-written check on the private head is what stops the forged value. Elixir 1.14 has no type checker, so nothing is inferred.
- **Elm**: not executed. `elm make` needs `package.elm-lang.org`, which is unreachable (`elm/elm-try.out`). The repo's `wayfinder/research/18-elm-port-validation.md` is the only source for 'Elm checks at the port door'. (An earlier draft also said Elm has no private/public distinction; the verifier found that is not in the cited file, so it is withdrawn.) UNVERIFIED-NOT-EXECUTED.
- **Gleam**: not installed, UNVERIFIED-NOT-EXECUTED. From the repo only: `prototypes/10c_gleam_forge.erl` shows a bad tag is caught by the clause head and a bad payload is not; `prototypes/18c_gleam_ffi_trust.gleam` shows `@external` is trusted. No claim is made about Gleam `pub` versus private.

## 5. The options

### Option 1: exported only, one rule (the ticket's "defect" reading; patch A)

B# the author writes (`probes/59/src/Ledger/ledger.bs`):

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
type Batch   = { Orders: list<Order>, Note: atom }
type Wrapped = { Item: Order, Note: atom }

public int Handle(Order o)
Handle(o) -> Inner(o)             // exported tag test fires first: stops a forged Order

private int Inner(Order o)
Inner(o) -> o.Total               // under Option 1: no test

public int Unwrap(Wrapped w)
Unwrap(w) -> Inner(w.Item)        // Invoice-tagged map accepted as an Order: {ok,100}

public list<int> Totals(list<Order> os)
Totals(os) -> List.Map(os, Inner/1)   // same, per element
```

**Compiler delta** (the whole of patch A):

```erlang
{ok, _} when not Public -> {Pat, []};      % first clause of guard_one/7's record branch
```

Plus: `CONTEXT.md:398` (heading at :397) and 26 §1's "every exported function" become true as written; the comment in `bs_emit` is already right.

**Measured:** 34 existing tests still pass. Saves 12 Code bytes and about 8 ns on every call into a private record function (OTP 25). Four silent paths open (4.2), none of them exercised by any test today.

**Strongest counterargument.** The rule it restores is justified by "a private function's every call site is a checked beam-sharp call site". That is true of values a B# caller built and false of the values the guard exists for. The foreign caller's value reaches the private function inside an aggregate the exported boundary never walks, and 4.2 ran it. The rule also makes the language's one-sentence guarantee false for lists and fields: "will crash, never silently". F24 §6 already found privacy to be the thing that made a hole silent once.

### Option 2: every function, one rule (patch B, widening the kind test to match the tag)

```csharp
public list<int> Doubled(list<int> xs)
Doubled(xs) -> List.Map(xs, Double/1)     // Doubled([1.5]) -> {ok,[3.0]} today; function_clause under Option 2

private int Double(int n)
Double(n) -> n * 2                        // gains: when is_integer(N)

public int FromField(Cfg c)
FromField(c) -> Twice(c.Level)            // {ok,3.0} today; function_clause under Option 2
private int Twice(int n)
Twice(n) -> n * 2
```

**Compiler delta** (patch B): delete `when Public` from `guard_one`'s `none` branch and drop the `none -> {Pat, []}` fallback, then remove the `Public` parameter from `clause`/`boundary_guards` (it becomes unused: B leaves it as a warning). Rewrite the `bs_emit.erl` comments that say exported-only (`:159-162`, `:330-333`, and the `IntOnly` note in `clause/4` that ties omission to "a checked B# call site does when it is private"). Fix the two tests that pin the opposite (`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122`), their F24.6/F37.5 scenarios and F24 §2/§3, F37.5. Amend 18 §4's sentence and §1's "pay nothing", `CONTEXT.md:398` (heading at :397), `LANGUAGE.md:3638`. No change to the analysis: still function-local, so a guard moves only when its own function is edited.

**Measured:** every hole in 4.2/4.3 closed (`forge.out`/`kinds.out`/`nest.out`, emitter B). Code +5 per `int` parameter and +12 per record parameter *when not elided*. On the compiling corpus 19 added tests (in the abstract code of its 12 private functions, reached from 15 local call sites) become 0 after `erlc` (`corpus-survive.out`). Kind-test time is below the noise floor (4.7). Not elided: the private tag test; the status quo already pays that.

**Strongest counterargument.** It contradicts text that is currently resolved: 18 §4's "looks at the exported function's own clause heads", 18 §1's "interior functions already pay nothing", and the "no opt-out" §5 now means no way to switch the private tests off either. A private recursive function reached from a caller whose type `erlc` cannot prove (a list element, a field) pays its test on every iteration; I measured the kind test at below-noise (W4) but could only construct one such loop, on OTP 25, and the tag test in the same position costs about 8 ns (W5) and is never elided. And Option 2 spends bytes, and for records cycles, on private functions in programs where no foreign aggregate ever arrives.

### Option 3: guard what escapes (`public` or address-taken; patch E)

The same program as Option 2. `Inner/1` and `Double/1` are address-taken, so they stay guarded; `Twice` is not, so it is not.

**Compiler delta:** one scan of `maps:values(fnames)` per module, plus `orelse` on the visibility flag (patch E, +4 lines). Aligns the definition with BEAM's own (`beam_ssa_type.erl:708`; `dialyzer_callgraph:is_escaping/2`).

**Measured:** closes `Totals`, `Picker` and `Doubled`; **leaves open** `Unwrap` (direct call, nested record), `FromList` (direct call from a lambda) and `FromField` (`probes/59/nest.out`). 34 tests pass.

**Strongest counterargument.** It violates 18 §4's stated reason for being function-local: adding a `Name/N` reference in *another function* in the module changes whether `Name` carries a guard, so an edit to one function silently moves another function's emitted boundary, the "blast radius" 18 §4 rejected whole-aggregate analysis to avoid. It also leaves the nested-field direct-call hole that the exported-only rule leaves.

## 6. Recommendation

**Option 2: one rule, every function.**

1. It is the only option that closes every path *into a private guarded function* that the probes found (verifier: direct projection of a nested wrong-tag record passes under every variant, and a right tag with a wrong field type passes even on stock), without a new analysis, so 18 §4's function-local property survives. Option 3 does not close them, and breaks that property.
2. The recorded cost is small where measured: Code bytes are exact; the kind test is elided by `erlc` when callers are proven (0 of 19 corpus additions survived) and unresolved against noise otherwise; the tag test already costs what it costs today.
3. The text it rewrites (18 §4, 18 §1 "interior pays nothing") was **not** contradicted inside ticket 18 (the earlier claim about `:194` was a misreading, see §2.5), but one of its two premises, "every call site is a checked call site", is the one F24 §6 already had to patch.

What would change my mind: a hot private loop, on OTP 28, that is reached from a caller `erlc` cannot type (a list element or a field) and pays a kind test per iteration at a resolvable cost. W4 is the closest I got and it was below the floor.

Ask S1 on its own, as a program: Option 1 versus Option 2 on `Totals([forged])` and `Doubled([1.5])`. One refuses and one returns `{ok,100}` and `{ok,[3.0]}`.

## 7. Not measured / could not run

- **OTP 28** (the repo's pin) is not installed; everything ran on OTP 25. `beam_ssa_type` elision and the generic `map_get` guard form are OTP-version-specific. The 8 ns tag cost and the elision rows must be re-run on 28.
- **Gleam**: not installed; no Gleam claim made beyond what repo files record. **Elm**: package download blocked.
- **Diagnostic columns** from the scratch build are wrong (lexer shim). Parser, checker and emitter are unchanged, but the shim means compile-time diagnostics were not compared.
- **Machine and timing:** shared host, load average 4 to 8, `+S 1`, x86-64 JIT. Differences below about 1 ns are within the floor. W1 is explained: three tag tests per iteration, not two (verifier). Kind-test timing is not 'below noise' across the board: in 11 paired runs B is +0.34 ns on W3 and +2.65 ns on W5 and consistently −0.3 ns on W2/W4 (probably code layout), so treat kind-test cost as small and unresolved, not zero.
- **Corpus:** 22 modules compile (`Signalbox` fails inside OTP 25's `core` pass under the *base* emitter too). `compiler/examples/exemplars/` does not compile (its README says so), so call-site counts there are a grep heuristic (`exemplar-static.out`: 30 public, 64 private, 10 private functions take a declared record parameter, about 7 textual call sites to the record-taking ones that I could attribute; the regex misses multi-line signatures).
- **Not run:** the full suite or the gates (`./bin/verify.sh`, the two-run rule). Only three test modules, by hand, because `rebar3` does not work here. The two failing tests under B are an expected consequence; nothing was fixed.
- **JIT native code size** of the guards: unmeasured (18a §1b failed the same way).
- **Whether a function-level `Name/N` scan is sound for `fnames`** (option 3): the patch is a probe, not a design. It was not checked against the qualified (`{q,...}`) or imported cases.


## Verifier corrections (2026-10-09)

See `artifacts/verification/59-verification.md`. Applied above: the ticket 18 misreading, W1, kind-test noise, the scope of 'closes every path', the 12/14 byte note, the Elm sentence and the CONTEXT.md line. Not applied: `beam_ssa_type.erl` line numbers are off by about 1 to 8 in this brief; re-open the file before citing a line.
