# Ticket 59 — one function, two guard scopes: decision brief

**Ticket:** [59](../wayfinder/issues/59-boundary-guard-scope-asymmetry.md) · [ENG-241](https://linear.app/davewil/issue/ENG-241)
**Prepared:** 2026-10-23, autonomously, for David's review
**Status: DECISION OPEN — nothing resolved, no ticket file, feature file, glossary or Linear state was touched.**

Toolchain: Erlang/OTP 28.5 (erts 16.4, built from source, the version `.tool-versions` pins), Elixir 1.19.5,
Gleam 1.18.1, rebar3 3.27.0, `bsc` built from HEAD of this repo, x86_64 Linux, 4 cores. Every number below
comes from a script in [`artifacts/probes/59/`](probes/59/); captured output is
[`probes/59/output.txt`](probes/59/output.txt), the product of one end-to-end `run-all.sh` run (the earlier per-piece captures were deleted; an earlier run with a bug in the per-pair delta column was discarded and re-run after the fix). Anything that needed a compiler change ran against a
**scratch copy** carrying a labelled patch ([`prototype-delta.patch`](probes/59/prototype-delta.patch),
[`prototype-delta-widen.patch`](probes/59/prototype-delta-widen.patch)); `compiler/src` was never edited.

---

## The answer first

The ticket asks whether the private tag test is a defect against 18 §4. **Measured: it is neither dead weight nor
a guarantee.** It is the only thing that catches a forged record that arrives *inside a container* of an
exported parameter, and it does so only if the author happened to put the element in a function parameter.
The premise both rules lean on — "a private function's every call site is a checked call site, so site 1
already rejected the wrong value" — is false for nested positions, for the int kind test as much as for the tag.

My recommendation is **Option A: one rule, scoped by the type, not by visibility** — widen F24's kind and range
test to private functions and keep the tag test. It costs 0 bytes of emitted code where the BEAM can already see
the caller's guard and 5–18 bytes where it cannot. It is not the whole answer (depth is a separate hole, below), and
it **reverses a decision David wrote on purpose**: F24 §2 scoped the kind test to exported functions, citing 18 §4 as authority. Option B also contradicts something David wrote (18 §4's *"a value handed to another function counts as unchecked, and is guarded"*, which the ticket's own "It is not" paragraph reads as the private tag test working). Every option contradicts one written sentence; they differ in which.

---

## The gating question, alone

**Is a boundary guard scoped by who may call the function, or by what the parameter's type can be forged into?**

Everything else (which test, which cost, which documents change) follows from this one. Here is the program,
[`probes/59/src/Nested/Nested.bs`](probes/59/src/Nested/Nested.bs), and what it does under each answer when a
BEAM caller hands it an order whose second line is forged
(`#{'Kind' => 'Evil.Line', 'Qty' => 2, 'Price' => 3}`):

```csharp
module Nested

record Line  { Qty: int, Price: int }
record Order { Id: int, Lines: list<Line> }

public int Total(Order o)                 // tag test on `o` — shallow: reads o.Kind only
Total(o) -> SumLines(o.Lines)

private int SumLines(list<Line> ls)
SumLines([])       -> 0
SumLines([l, ..t]) -> LineTotal(l) + SumLines(t)

private int LineTotal(Line l)             // HEAD emits a tag test here. Visibility-scoped does not.
LineTotal(l) -> l.Qty * l.Price           // a body that only projects fields cannot object
```

| call from Erlang | **scoped by type** (HEAD, and Option A) | **scoped by visibility** (Option B) |
|---|---|---|
| `Total(<forged OUTER tag>)` | `function_clause` in `Total` | `function_clause` in `Total` |
| `Total(<line tagged 'Evil.Line'>)` | **`function_clause` in `LineTotal`** | **`{ok, 12}`** |
| `Total(<an Order-tagged map where a Line is due>)` | **`function_clause` in `LineTotal`** | **`{ok, 6}`** |

(probe 59-B, rows R2–R4.) The HEAD column is the compiler as shipped; the right column is HEAD with one
`when not Public` clause added to `bs_emit:guard_one/7`.

If your answer is **"by visibility"**, 18 §4 and F24 stand as written, the private tag test is removed, and the
two rows above go silent. If it is **"by type"**, the int/float kind and range test follows the tag test onto
private functions and the sentence in 18 §4 / F24 §2 is the thing that changes.

## Sub-decisions, in dependency order

| # | Sub-decision | Status |
|---|---|---|
| 1 | **Scope rule: visibility or type?** (the question above) | **gating** |
| 2 | If *type*: does F24's kind+range test move to private functions too? | follows 1 — there is no coherent "by type" with an exempt `int` |
| 3 | Depth: is an exported guard promised to cover values *reachable* from its parameters, or the parameter alone? | **independent, and the larger hole — see "What this does not fix". Not decided here; proposed as its own ticket** |
| 4 | Which documents say the old rule | follows 1 (listed under each option) |

The ticket's second question — "is *exported* even the right discriminator?" — is sub-decision 1 restated: 18 §1's
cost note says the BEAM's own discriminator is exported-versus-local, which prices the guard but does not argue for
the *scope* of a language guarantee. I found nothing in the BEAM that makes visibility the right axis for a
safety rule; I did find it is the right axis for **cost** (below).

---

## What was measured

### The premise "site 1 already rejected it" is false for nested positions

A checked B# call site proves the *argument's static type*. A forged element inside `list<Line>` is statically a
`Line`, and the exported guard on `Order` reads one key. Three results (probe 59-B):

1. **Tag, HEAD:** R3 and R4 above — `LineTotal`'s own tag test is what stops them.
2. **Tag, factoring:** inline `LineTotal` into the list walk and the same forged input is accepted:
   `TotalInline(<order with forged line>) -> {ok, 12}` on **all three builds** (R5). The element is bound by a list
   pattern, not a parameter, so no boundary guard exists to fire. The private tag test is protection *by accident
   of function factoring*.
3. **Int kind, HEAD (today):** `Bands(list<Octet>)` hands each element to a private `Inner(Octet n)`. The exported
   scalar twin `Band(200.5)` is refused (`function_clause`), but through the list:

   | call | HEAD | widen (Option A) |
   |---|---|---|
   | `Bands([200.5])` | `{ok,[high]}` | `function_clause` in `Inner` |
   | `Bands([foo])` | `{ok,[high]}` (an atom compares greater than any number) | `function_clause` |
   | `Bands([-3.5])` | `{ok,[low]}` | `function_clause` |
   | `Bands([1000])` | `{ok,[high]}` — outside `0..255` | `function_clause` |

   That is ticket 18's outcome 3 (a silent wrong answer) in the exact shape F24 was written to close, reached
   through a list rather than a scalar. F24 §2's "so site 1 has already rejected the out-of-domain argument" holds
   for a scalar argument and not for a list element.

### What each guard costs (probe 59-C, 59-F, 59-G)

| | tag test on a private fn (HEAD vs Option B) | int kind/range test on a private fn (Option A vs HEAD) |
|---|---|---|
| **Code chunk** | **+12 bytes**, identical at 1, 4, 16, 32 fields (125 vs 113 in all four) | `PlainInt` 106→106, `RangeInt` 119→119, `HotLoop` 139→139: **0 bytes** where the exported caller's guard is visible. `ListInt` 135→140 (**+5**), `ListRange` 135→153 (**+18**) where the argument comes out of a list |
| **Stripped .beam** | +8 to +13 bytes across four independent builds (the last run: +9 to +11 across 1/4/16/32 fields; the verifier's rebuild: up to +13) | +0 to +20 bytes (last run: 0 for `PlainInt`/`RangeInt`, +4 `ListInt`, +20 `ListRange`) |
| **Call time** | **≈ 1.3–1.6 ns/call**: 6 pairs with the run order alternated in `run-all.sh`'s run give 0.5, 1.7, 1.5, 2.1, 0.9, 1.8 (mean 1.42, positive 6/6); my earlier head-first run gave a 1.6 mean and the verifier's independent alternated rerun ≈ 1.3. On a ≈ 33 ns loop | **no resolvable difference, but a small lean is not excluded**: per-pair deltas for `PlainInt` span −0.6 to +0.6 (mean −0.05) and for `ListInt` −0.9 to +1.1 (mean −0.07) in this run, while the verifier's rerun saw `PlainInt` widen slower than head by ≈ 0.3 ns on average. Read it as "within ±1 ns per pair; up to ≈ 0.3 ns on average not excluded". `HotLoop` (1M iterations/call) medians interleave |
| **Compile time** | not resolved (medians 7.4–7.9 ms across the three builds, maxima 10.9–16.6 ms; ranges overlap) | not resolved |
| **Corpus (23 `.beam` files from the 22 example dirs that compile)** | 0 of 23 change — **this is no evidence about B's blast radius**: no shipped example has a private function with a record parameter, so the test could not have fired | 5 of 23 change at the abstract-code level (`Fib`, `Foreign`, `Frame`, `Pipeline`, `Shop.Collections.Ints`); in all five the **Code chunk is byte-identical** (same md5; the verifier also compared LitT, AtU8, ImpT, ExpT, LocT and Line — only debug info differs) |
| **Test suite (1498 eunit tests; `run-eunit.sh`, with `aoc/` beside the copy and the escript built)** | **0 fail** (1498/1498 pass) | **2 fail** (1496 pass), exactly the two that pin the old rule: `boundary_kind_tests:a_private_function_is_not_guarded_test`, `boundary_range_tests:a_private_function_carries_no_range_guard_test` |

Two findings behind those numbers worth stating plainly:

- **The BEAM compiler erases the widened int guard whenever it can prove it.** `HotLoop`'s abstract code carries
  `is_integer(N) andalso is_integer(Acc)` on every iteration under widening, and the `.beam` Code chunk is
  the same size as HEAD's (139 = 139; sizes compared, not contents) and its 1M-iteration time is indistinguishable. `HotLoop` is the **best** case for this erasure (the exported caller's guard is visible), so it shows the floor of the cost, not the ceiling; the ceiling is `ListInt`/`ListRange`, and a harder case (argument from `receive`) is unprobed. The cost of the widened guard
  lands only where the compiler *cannot* see the caller's guard — which is where the guard is buying something.
  The record tag test is not erased this way (`map_get(Kind) =:= Tag` is not a type fact the pass derives), so it
  keeps its +12.
- **No test pins the private tag test.** Removing it (Option B) turns zero tests red. The suite would not notice
  the narrowing; R3/R4 above are the only thing that does.

### Neighbours (probe 59-D; sources cited `path:line` at the clone's HEAD)

| | what a forged value in a nested position does | where |
|---|---|---|
| **Gleam** 1.18.1 | **In the probe, nothing is checked at any function, exported or private.** Records are tagged tuples read by `element/2`: forged `{evil,2,3}` returns `6`; `{order,9,9}` where a `line` is due returns `81`; a forged *outer* `{evil,1,[...]}` is also accepted. The compiler publishes a `-spec` and exports by publicity but emits no guard | `compiler-core/src/erlang.rs:718` (`function_spec_attribute`), `:3685-3703` (`function_export`: a non-importable function is simply not exported), the behavioural probe and one emitted dump (a single 3-function program, not a codegen audit); I did not find a codegen citation for "emits no guard" and the claim rests on that probe |
| **Elixir** 1.19.5 | Checks exist only where the author wrote a struct pattern. `defp line_total(%Line{...})` raises `FunctionClauseError` on the forged element; the same body reading `l.qty * l.price` returns `6`. `@enforce_keys` is documented as *"a simple compile-time guarantee … not enforced on updates and it does not provide any sort of value-validation"* | `lib/elixir/lib/kernel.ex:5590-5592`; `defp` at `:5408` |
| **Elm** 0.19 | Checks **depth, not scope**: an incoming port's declared type is turned into a full JSON decoder (`toDecoder`, recursive over lists, records, tuples) and run on every value; Elm code is unreachable unless it succeeded. No per-function guards exist because there is one door | `compiler/src/Optimize/Port.hs:177-224` (`toDecoder`), `:249` (`decodeList`), `:313` (`decodeRecord`) in the elm/compiler clone at `$REF/elmc`, `1c278bf` — **read, not run**; `src/Elm/Kernel/Platform.js:457-461` (elm/core `65cea00`) |

No neighbour scopes a guard by visibility. Gleam checks nothing; Elixir checks what the author writes; Elm checks
everything at one door. B#'s closest precedent for its own behaviour is Elixir's: the tag test is B#'s automatic
struct pattern, and an automatic pattern that skips `defp` would be the odd one out. (C# was not surveyed — no local
source.)

---

## Options

### Option A — scope by type: one rule, every function (recommended)

```csharp
private atom Inner(Octet n)       // HEAD: no guard.   Option A: is_integer(n) and the range bounds
Inner(>= 128) -> :high
Inner(<= 127) -> :low
// Bands([200.5]) : HEAD {ok,[high]}   Option A  function_clause in Inner
```

**Compiler delta** (prototype: 5 lines, [`prototype-delta-widen.patch`](probes/59/prototype-delta-widen.patch)):
in `bs_emit:guard_one/7` (`compiler/src/bs_emit.erl:275-293`) delete the `none when Public` guard and the
`none -> {Pat, []}` fall-through; the `Public` argument is then dead, so also drop it from `boundary_guards/6`
(`:265`), `clause/4` and `function/2` (`:163-169`, where it is computed from `is_public/1`).

**Documents and tests that say the old rule:** `bs_emit.erl:330-336` (the comment block), `F24-boundary-kind.md`
§2 line 115 and §3 lines 120-128 and scenario F24.6 line 229, `LANGUAGE.md:3774` ("exported **refined `int`**") and
`:3773`, ticket 18 §4 (`18-boundary-defence.md:817-818`, *"It looks at the exported function's own clause heads and
body, and no further"*) and ticket 18 §1's cost section, where both lines 441 and 615 are the **§1** "interior
functions already pay nothing / the same code un-exported has the test elided entirely" passage (they are not §4),
and the two eunit tests named above, which flip.

**Evidence:** I3–I6 close (above); corpus: 5 beams change with a byte-identical Code chunk; cost table column 2.
**Gets rid of** the two-rule function the ticket complains about. `LANGUAGE.md:3773` ("the boundary tag guard on an
exported record parameter") stays true under A, as it is on HEAD — it is merely silent about private functions;
`:3774` ("exported **refined `int`**") is the line that goes stale.

**Strongest counterargument:** it reverses a decision made on purpose, with a measured justification. 18 §1 priced
"the same code un-exported has the test elided entirely" and called it *"the shape C wanted anyway"*, and F24 §2
scoped the new test exported-only by 18 §4 explicitly. The private guard is also **defence in depth that still has
the factoring hole** (R5): inline `Inner` into `Bands` and the forged element is accepted again. A uniform rule that
protects "wherever the author happened to write a function" is a weaker sentence than it looks, and a reader may
trust it more than it deserves.

### Option B — scope by visibility: the ticket's "defect" reading

```csharp
private int LineTotal(Line l)     // HEAD: tag test.   Option B: none
LineTotal(l) -> l.Qty * l.Price
// Total(<forged line>) : HEAD function_clause in LineTotal   Option B  {ok, 12}
```

**Compiler delta** ([`prototype-delta.patch`](probes/59/prototype-delta.patch), 2 lines): add
`{ok, _Tag} when not Public -> {Pat, []};` before the `{ok, Tag}` arm at `bs_emit.erl:277`. The `Public` plumbing
stays. No eunit test changes (0 of 1498 fail). `LANGUAGE.md:3773` and F3.9 ("an exported function taking a record")
are about exported functions and are **true on HEAD today**; they are silent about private ones, so B does not
make them truer — it only removes a behaviour they never mentioned.

**Evidence:** saves 12 bytes of Code and ≈ 1.3–1.6 ns per private-record-parameter call; consistent with the ticket's "defect" argument and with
F24 §2's exported-only scope. **It does not "match 18 §4 as written":** 18 §4 says the analysis *"looks at the exported
function's own clause heads and body, and no further"* (`18-boundary-defence.md:817-818`) **and** *"A value handed to
another function counts as unchecked, and is guarded"* (`:818`). The ticket's "It is not" paragraph reads the private
tag test as exactly that second sentence working — the callee guards because the caller's analysis stopped at its own
boundary. B satisfies the first sentence and contradicts the second; A and today's HEAD honour the second and
contradict F24 §2's reading of the first. David wrote both; the choice is which to keep.

**Strongest counterargument:** R3, R4 — a forged element that is rejected today is silently summed. The suite does
not notice (nothing pins it), and the ticket's own rule — "too narrow is a silent hole, too wide is measurable and
loud" — points the other way. After B the language's claim is "a wrong *top-level* argument will crash", which is
a smaller sentence than 18's C ("a wrong term from outside will crash — not always at the call site, but never
silently").

### Option C — leave both rules, write down why they differ

No code. Add to F24 §3 and `bs_emit.erl:330`: the tag test is unconditional because no body ever checks identity
(26 §1); the kind test is exported-only because arithmetic *often* objects.

**Strongest counterargument:** the second half is not supportable. Probe 59-B I3 shows the private `Inner`'s body
(`>= 128` comparison on a float or an atom) does **not** object, so the "body would object" justification that 18 §1
gives for the kind test does not distinguish it from the tag test. I could not find a principled difference; the only
measured difference is cost, and cost (table above) is 0 bytes for ints where the compiler can see the guard. Option C
keeps I3–I6 open and keeps the "two rules" the ticket was filed over.

---

## Recommendation

**Option A.** One rule — "a parameter whose declared type the compiler can test is tested, wherever the function
lives" — with no exemption to explain. Reasons, in order:

1. It is the only option under which the nested forgeries I3–I6 and R3–R4 all crash. B leaves R3/R4 open; C leaves I3–I6 open.
2. The price is measured and small: 0 bytes where the BEAM can see the guard, +5 to +18 bytes where it cannot, no
   resolvable call-time change (a lean of up to ≈ 0.3 ns on average is not excluded), and the record-tag +12 B/≈ 1.3–1.6 ns is already being paid.
3. It follows the ticket's own asymmetry rule, and it is **still function-local** — it does not touch 18 §4's
   stability argument (a guard moves only when you edit the function it sits on).

**What would change this to B:** if you want the guarantee to be explicitly *"the parameter you were handed, nothing
else"*, a smaller promise that 18 §4 reads as, and you accept that R3/R4 go silent. Then Option B's two-line patch is
the whole job and the private tag test goes with it. It is a coherent position; it is not the one 18 §1 states.

## What this does not fix, and a ticket worth raising

All three options leave **depth** untouched: the exported guard on `Bands(list<Octet>)` or `Total(Order)` never walks
the container, so inlining the private helper (R5) accepts forged elements under every option, including today's.

I grepped `wayfinder/issues/*.md` for `depth`, `deep`, `nested`, `container`, `shallow`, `every element` and
`one level deep` before writing this. What exists, all in ticket 18 unless noted:

- **§2 (`:619-634`)**: a *foreign* declaration may promise only what one O(1) guard decides; `list<Order>` is a compile
  error there and crosses as `list<term>` plus `ValidateAs<T>`.
- **`:709` and `:812`**: the option "declare anything, check one level deep" was considered and **rejected** twice
  (for the FFI, and for callbacks), because it "claims a defence one level deep".
- **§1(c) (`:392`, `:884`)**: compiler-generated code that operates on a declared element type (an inlined prelude
  operation, 16 §4's encoder) is guarded unconditionally; a user-written function gets "the ordinary analysis".
- **`LANGUAGE.md` §10**: deep validation is the explicit `ValidateAs<T>`.

So depth was decided for foreign declarations, callbacks and generated code. I found **no ticket that says what an
exported B# signature with a container parameter (`list<Line>`) promises** — which is the case the probes exercise.
If that is right it is a gap worth its own ticket, and it needs David's answer before any cost work; a single-ticket
suggestion, not a finding that 18 is wrong. The exported-container cost (what a walk would add) is **not measured**.

**Adjacent, already decided (F3.9, for completeness):** a *union* record parameter gets no tag test at all, so an
exported `Amount(Doc d)` accepts `#{'Id' => 1, 'Total' => 4}` with no `Kind` key and returns `4` (probe 59-E), while
`Squared(Order o)` refuses it. F3.9 records that as intended ("a disjunction over tags is a different shape").

---

## Evidence ledger

| id | script | claim it tests | control | result | does **not** show |
|---|---|---|---|---|---|
| 59-B | `run-behaviour.sh` (R1–R5, I1–I6) | forged values reach private fns through a nested position | R1 well-formed → `{ok,6}`; R2 forged outer tag → refused on all builds; I1, I2 scalar exported → refused | R3, R4: refused on HEAD/widen, **accepted on narrow**. R5: accepted on all. I3–I6: accepted on HEAD/narrow, **refused on widen** | that any real caller sends such values; only that the language admits them |
| 59-C | `run-cost.sh` §A, §B, §C | byte, compile-time and call-time cost | `PlainInt`/`RangeInt` with a visible guarded caller; Rec1/4/16/32 field-count sweep | tag +12 B flat; int 0 B visible / +5, +18 B not; tag ≈ +1.3–1.6 ns (6/6 alternated pairs positive); int ns unresolved with a lean of up to ≈ 0.3 ns not excluded; compile time unresolved | JIT native-code size; any arch but x86_64; megamorphic or cold call sites. The microbench loop is ≈ 34 ns/call (an `M:F(A)` remote call), so a single pair's delta under ≈ 1 ns is noise (the tag effect is read from the sign over 6 pairs and three runs, not from one pair) |
| 59-F | `run-loop.sh` | widened int guard in a hot private loop — the **best** case for BEAM erasure (the exported caller's guard is visible), not the worst | HEAD, same program | guards present in abstract code, Code chunk 139 = 139, time indistinguishable | a loop the BEAM cannot prove (e.g. argument from `receive`) |
| 59-G | `run-corpus.sh` | blast radius over shipped examples | `exemplars` dir skipped (does not compile as a module under any build) | narrow 0 of 23 beams change (vacuous: no private record-parameter function in the corpus); widen 5 of 23, Code chunk md5-identical | anything about B's blast radius; the `exemplars` dir |
| 59-H | `run-eunit.sh` | which tests pin the behaviour | HEAD: all 1498 pass, with the repo's `aoc/` beside the scratch copy and the escript built first (the first, unscripted attempt lacked both and showed two environment failures that were not the patches') | narrow: 1498/1498 pass; widen: 1496 pass, exactly the 2 named above fail | the `check-*.sh` gates and `bin/verify.sh` (**not run under either patch or on HEAD**), the clean-checkout double run |
| 59-D | `neighbours/run-neighbours.sh` | the same forgery against Gleam and Elixir | well-formed order → 6 on both; Elixir struct-pattern private fn as the control that a check *can* fire | Gleam accepts every forgery; Elixir refuses only where a struct pattern was written | Elm and C# runtime behaviour (Elm: source read only — no Elm program was compiled, the package server is unreachable) |
| 59-E | `run-union.sh` | F3.9's union-parameter omission | `Squared(Order o)` refuses the same forged map | union param accepts it | whether F3.9's decision should stand |

## Not measured / caveats

- OTP 28.5 on x86_64 Linux. 18a and 26a measured arm64 Darwin; my tag figure (+12 B) differs from their +14 B by two
  bytes, which I attribute to the platform and the module shape, not to a change in the compiler.
- The prototype patches are mine and untested beyond the suite runs above; "narrow" and "widen" are the smallest
  edits that realise each option, not designed implementations.
- The `check-*.sh` gates and `bin/verify.sh` were **not run**, under either patch or on HEAD. Only `rebar3 eunit` was.
- Elm was surveyed from source only (read, not run). C# was not surveyed.
- **Unprobed:** (1) the cost of an exported `list<Line>` parameter being walked (the depth option); (2) a hot private loop
  whose argument the BEAM type pass cannot prove, e.g. one fed from `receive` — `HotLoop` is the erasure best case and
  `ListInt`/`ListRange` are only a one-element list; (3) JIT native-code size; (4) the 18a/26a "+14 bytes" (their
  harness was not re-run; my +12 B is a different measurement of a different module shape); (5) compile time beyond
  the one `Rec32` module; (6) whether any real foreign caller ever forges these values.
- The verifier subagent's re-run is recorded separately by the coordinator; this brief is the researcher's account.
