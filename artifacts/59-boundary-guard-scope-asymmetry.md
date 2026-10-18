# Decision brief: ticket 59 (ENG-241), the boundary guard now applies two rules with different scopes

Ticket: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`. **Left open for David.** This brief decides nothing.
Probes: `artifacts/probes/59/` (`./run.sh`; `FULL=1` adds the eunit run). Every number below came out of a probe in that
directory on this run.

**Environment, said once.** OTP 25.3 / Elixir 1.14.0 / Gleam 1.12.0 / x86_64 Linux, BeamAsm JIT. The tickets' numbers are
OTP 28.5 arm64, so compare ratios and shapes, not nanoseconds. `bsc` was built from a copy of `compiler/src` with a lexer shim
(OTP 25's leex has no `TokenLoc`), so diagnostic columns are wrong; nothing measured here reads a column. `compiler/` and
`wayfinder/` are untouched. The five compiler variants are built from `patches/*.patch` on a copy.

| variant | tag test (record) | kind test (int / float / range) |
|---|---|---|
| v0 | every function (today) | exported only (today) |
| v1 | exported only | exported only |
| v2 | every function | every function |
| v4 | exported or *escaping* | exported or *escaping* |

*Escaping* means the function's name is taken as a value somewhere in the module (`Inner/1`, F46 / ticket 75).

## 1. What the question is made of

1. **Which functions does each guard belong on?** (the ticket's "stated once, for both guards")
2. **Is "exported" the right discriminator,** or is a private function sometimes reachable by a caller no B# call site checked?
3. **What does each answer cost?** In bytes, in time, and in what it breaks.

Sub-decision 2 gates the other two, so it is answered first.

## 2. Sub-decision 2, run: can an unchecked value reach a private function?

The ticket's "it is a defect" side says a private function's every call site is a checked B# call site. The "it is not" side says a forged
record can reach a private function through an exported one. Nine attempts, on v0 (`02_escape.sh`, `02b_foreign_callback.sh`,
`03_reach.sh`). A "reaches" claim below is a run that printed the result, not an argument.

| attempt | result on v0 | verdict |
|---|---|---|
| B. `Outer(term t) -> Inner(t)` where `Inner(Order o)` | refused at compile time: "Outer hands Inner an argument it does not accept" | **does not reach.** The checker stops it |
| C. a foreign return declared `Order`, passed on | refused at compile time ("Erlang cannot produce its `Kind`") | **does not reach** |
| D. a structural lookalike `{Id, Total}` offered as `Order` | refused at compile time | **does not reach** |
| E. `term` narrowed through `ValidateAs<Order>` then passed | forged map and wrong `Kind` both give `-1` (the `:error` arm) | **does not reach**; the validator is the gate |
| 02. the private function's name leaves the module as a fun (`TotalOf() -> Inner/1`) and Erlang calls it with a wrong-tag map | `{error,function_clause}`: **the private tag test is what stopped it** | **reaches**, and today only the private tag test defends it |
| 02. same shape, `Twice(int n)`, called with `1.5` / `foo` | `3.0` / `badarith`. **No kind test on a private function, so a float passes an `int` parameter** | **reaches**; this is a hole in v0 today, in the kind test |
| 02. `Narrow(Octet n)` called with `1000` | returns `1`. A refined parameter's range is not enforced | **reaches**, same cause |
| 02b. `:lists.map(Twice/1, xs)` where the foreign declaration says `list<term>` | `Run([1,2.5])` gives `[2,5.0]`; `Run([1,foo])` crashes inside `Twice` | **reaches** |
| 03A. exported `SumTotals(list<Order> os)` forwards each element to private `Inner(Order o)`; one element is a forged map | `{error,function_clause}` from the private tag test | **reaches**, caught only by accident (see below) |

So both sides of the ticket are partly right, and they are right about different paths:

* **Plain B# calls cannot forge** (B, C, D, E). 18 §4's premise holds for calls the checker sees.
* **A function name taken as a value is a second entrance.** F46 lets a private function leave the module as a fun, and whoever holds the
  fun calls it with anything. The ticket does not mention F46. This path is open for the kind test today (`Twice(1.5)`) and is closed
  for the tag test only because of the very guard under discussion.
* **A collection's elements are never guarded at an exported entrance.** `SumInts([1,2.5])` returns `5.5` on every variant. That is
  ticket 46's decision, not an accident: guards stand "wherever a fixed number of projections reaches the value … and never
  through a collection" (`46-refined-parameter-at-the-boundary.md:118-119`, again at `:221`, `:290`). The private tag test happens to
  catch a forged element in 03A only because that element is then passed to a function with a record parameter. A body that read the
  element's field directly would not be caught.

**Is "exported" the right discriminator?** Not exactly. Erlang's own optimiser draws the line at *exported or the name taken as a fun*:
`beam_ssa_type.erl:119-121` (exported functions' argument types start as `any`, local ones as `none`), `:432-440` (a local function's
parameter types are the join of its call sites; an exported one's are `any`), and `:703-707` (`make_fun` passes `any` for a callee's
arguments). `survey/erlang_elision.sh` ran it: an `is_integer` guard on a local function whose every call site passes an integer is
**elided**; on one whose name escapes, one called with an unknown term, and an exported one, it is **kept**.

This also corrects ticket 18 §1's wording ("exported vs local-only"): the BEAM discriminator is exported-or-escaping.

## 3. The B# code, and what each option compiles to

```csharp
module Shop.Orders

record Order { Id: int, Total: int }

public int Outer(Order o)           // exported: both guards, in every option
Outer(o) -> Inner(o)

private int Inner(Order o)          // v0: tag test.  v1: none.  v2: tag test.  v4: none (name never escapes)
Inner(o) -> o.Total

public int Plain(int n)
Plain(n) -> Twice(n)

private int Twice(int n)            // v0: none.  v2: is_integer (erlc then elides it: callers known)
Twice(n) -> n + n

public fn(Order) -> int TotalOf()
TotalOf() -> Inner/1                // the name leaves as a fun. v4: Inner gets the tag test back
```

v0 emits (`01_repro.sh`, from the `.abstr` bsc writes):

```erlang
'Outer'(O) when map_get('Kind', O) =:= 'Rep.Order' -> 'Inner'(O).
'Inner'(O) when map_get('Kind', O) =:= 'Rep.Order' -> map_get('Total', O).    %% the private tag test
'Plain'(N) when is_integer(N) -> 'Twice'(N).
'Twice'(N) -> N + N.                                                          %% no kind test
```

## 4. The options

### Option A: guards belong on exported functions only (v1)

One rule for both guards, and it is 18 §4's literal text. The tag test moves from "every function" to "exported only"; the kind test
is already there.

*Compiler delta:* **one line**, `patches/tag_exported_only.patch`: `case constrains_kind(Pat) orelse not Public of` in
`bs_emit:guard_one/8`.

*Measured:*
* A loop through a private two-clause record function (`05_bytes_and_time.sh`, 30M iterations, min of 9): **36.71 → 13.09 ns/iter**
  (-64%). The same program's `.beam` Code chunk: **329 → 285 bytes** (-44).
* The tag test is repeated in every clause of a multi-clause function. Hand-written Erlang with no bsc in the loop
  (`07_handwritten_loop.sh`): plain 13.61, one tag test 19.58 (+6.0 ns), the per-clause shape bsc emits 35.44 (+21.8 ns).
  So the cost scales with clause count, which no earlier ticket measured. (The ticket-39 brief's "~5 ns" is the one-clause case.)
* One guard in bytes (`06_single_guard_bytes.sh`, hand-written, OTP 25): tag test **+12 B**, `is_integer` +5, `is_float` +3,
  range `0..255` +16. Ticket 26a said +14 and 18a +3-5; these agree within the OTP difference.
* The repo's own eunit suite (1448 tests): **v1 fails exactly the same 183 tests as v0**, i.e. no test pins the private tag test
  (`eunit_results.txt`). The 183 fail on unmodified v0 too and I did not triage them one by one; I attribute them to OTP 25 and
  the lexer shim, and only the difference from v0 is a finding.
* The 22 example modules in `compiler/examples`: Code total is **identical** (9599 B) under v0 and v1 (`09_corpus_size.sh`),
  so the examples contain no private record parameter to speak of.

*What it opens.* The escaped-fun tag case: `TotalOf()` called by Erlang with a wrong-tag map returns `7` instead of
`function_clause` (04). That hole is already open for the kind test on v0, so A makes the two guards **consistently** open at the one
entrance F46 added, rather than closing either. It also drops the incidental catch of a forged list element (03A gives `1007` instead
of `function_clause`), which ticket 46 already accepts for every other collection.

**Strongest counterargument.** It turns a defended hole into an undefended one. Today a record forged through an escaped fun is
refused; under A it computes with an attacker's `Total`. The ticket's "too narrow is a silent hole, too wide is measurable and loud"
applies directly, and the escaped-fun path was not in front of anyone when 18 §4 was written.

### Option B: guards belong on every function (v2)

The other direction, also one rule. The kind test widens to private functions.

*Compiler delta:* **deletes** the `none ->` fallback in `guard_one` (`patches/kind_all.patch`, -2 / +4 lines).

*Measured:*
* Closes the kind holes: `Twice(1.5)`, `Twice(foo)`, `Narrow(1000)` and `SumInts([1,2.5])` all give `function_clause` (04).
* **Costs nothing in bytes where the guard is redundant.** Under v2 the examples' `.abstr` files hold 92 `is_integer` tests instead of
  73, and the `.beam` Code total is **unchanged at 9599 B**, because erlc proves them away where every call site passes an integer
  (`09`; the mechanism is `beam_ssa_type.erl:432-440`, run in `survey/erlang_elision.sh`). `RunInt` time: 5.77 (v0) vs 5.59 (v2) ns/iter,
  inside run-to-run noise (v1 5.80, v4 6.21).
* **Does not touch the record cost:** `RunRec` stays at **36.60 ns/iter**, Code chunk 339 B. erlc cannot elide a `map_get('Kind', O) =:= Tag`
  test the way it elides `is_integer`, because it does not track map-key values.
* Breaks tests: **v2 fails two more than v0**, `boundary_kind_tests: a_private_function_is_not_guarded_test` and
  `boundary_range_tests: a_private_function_carries_no_range_guard_test`. Those tests pin F24's and ticket 58's *opposite* decision, so
  they would need rewriting along with 18 §4.

**Strongest counterargument.** It buys safety on the paths where the guard is needed by paying the 64% record cost on every path where it
is not, and the ticket's own text (18 §4, and 18's cost section calling private elision "the shape C wanted anyway") says the author
wanted the private function unguarded. It also defends only the entrances that already exist; a forged list element still gets in.

### Option C: guards belong where an unchecked caller can reach the entry: exported or escaping (v4)

One rule for both guards, and the same line Erlang's optimiser draws (section 2).

*Compiler delta:* **9 added lines, 1 file**, `patches/reachable.patch`: an `escapes/2` that looks the function up in the `fnames` map
the checker already records, and `Public = is_public(F) orelse escapes(F, Ctx)`.

*Measured:*
* Same speed and size as A: `RunRec` **13.70 ns/iter**, Code chunk **285 B**, `RunInt` 6.21 (noise).
* Closes every escaped-fun case: `TotalOf` with a wrong tag gives `function_clause`; `Twice(1.5)`, `Twice(foo)`, `Narrow(1000)` all give
  `function_clause`; `:lists.map(Twice/1, [1,2.5])` now crashes with a `function_clause` instead of returning `[2,5.0]` (04; v2 does the same).
* Leaves the collection-element entrance as it is under A (`SumTotals([Good, Forged])` gives `1007`, `SumInts([1,2.5])` gives `5.5`).

**Strongest counterargument, measured.** A function's emitted guard now depends on code that is not on that function.
`10_cross_file_escape.sh` compiles one module twice: `Inner(Order o)` in `total.bs`, with and without a sibling file `leak.bs` that
returns `Inner/1`:

```
v4 X  Inner guard: 'Inner'(O) -> map_get('Total', O).
v4 Y  Inner guard: 'Inner'(O) when map_get('Kind', O) =:= 'Xm.Order' -> map_get('Total', O).
```

Adding `leak.bs` alone changes `total.bs`'s emitted boundary, with no diff in `total.bs`. That is word for word the failure 18 §4 rejected for
whole-aggregate analysis ("an edit to `format.bs` alone silently changes the emitted boundary of `describe.bs`") and the standing
one-function-per-file / `write_scope` constraint it cites. v0 and v1 print the same guard in X and Y (v2 was not run in this probe).

### Not prototyped: a fourth shape

Put the guard at the escape site instead of on the callee: emit `Inner/1` as a guarded lambda around `Inner`. A callee's emission then never depends on a sibling file, and the guard sits at the entrance F46 created, which is what 18 §4 means by "a value handed to another function counts
as unchecked, and is guarded". I did **not** build or run it, so it carries no evidence here. `bs_emit.erl:1081-1090` is where `e_fname` is lowered; the delta would be a wrapper there, with the parameter types looked up from the callee's signature.
If David likes the direction it is a ticket of its own.

## 5. Neighbouring languages

* **Erlang** (`survey/erlang_elision.sh`, `beam_ssa_type.erl` cited above): the compiler's own rule is exported-or-escaping.
  Local guards are removed when call sites prove them. It cannot prove a map-key tag.
* **Gleam 1.12.0** (`survey/gleam.sh`, source `compiler-core/src/erlang.rs` fetched from the v1.12.0 tag): a `pub` function is not
  guarded at all. An Erlang caller got `gp:double(1.5)` -> `3.0` and `gp:pub_total({not_order,1,2})` -> `2`. `grep -c 'is_integer\|is_float'`
  over `erlang.rs` gives 0. Gleam *does* export a private function when a public constant refers to it
  (`erlang.rs:170-175`, `:312-320`, `:3162-3175`), which is its version of the escaping case, handled by changing visibility rather than adding a check.
* **Elixir 1.14** (`survey/elixir_defp.exs`, run through `beam_disasm`): a struct-tag test appears **only** where the programmer wrote a
  `%S{}` pattern, in a `defp` head (`priv_pat`, 14 instructions, test present). `@spec` on `def` or `defp` and `@doc false` change nothing
  emitted. Elixir's `.ex` sources are not installed here, so no file:line is cited for it.
* **Elm:** not executed (the package registry is unreachable from this host, so no `elm make` was possible). Nothing is claimed about it.

Reading across: no neighbour guards a private entry, Gleam guards no entry, and the one that handles escape does it by exporting.
None of them is evidence for or against the choice.

## 6. Recommendation

**Revised after independent verification. The worker's first draft recommended Option A; the verifier showed that draft rested on an incomplete reachability list.**

The verifier ran two routes the first draft did not list, and neither needs a function used as a value:

* **Nested record field.** Exported `Outer(Cart c)` does `Inner(c.Primary)`; Erlang passes a `Cart` whose `Primary` carries a bogus `Kind`. The exported guard tests only the `Cart` tag. Unmodified compiler: `function_clause` from `Inner`. Variants v1 and v4 (tag test removed from private functions): the call returns `1000`.
* **Tuple element.** Exported `Outer((Order,int) p)` passes `o` to `Inner`. Unmodified: `function_clause`. v1 and v4: returns `1001`.

So today the private tag test is the **only** thing that stops a forged record that arrives as a field or tuple element of a checked exported parameter. A and C both remove it. This is ticket 59's own "it is not" side, demonstrated: a forged record reaches a private function "by being passed through an exported one".

What that makes of the choice: the first question is no longer "exported or all" but **"are record tags inside a record field or tuple element checked at the boundary?"** Today they are not, and ticket 46's "fixed number of projections" argument is about refined `int`, not about record tags, so it does not settle it.

* If **no** (nested tags stay unchecked at the boundary), then the private tag test is load-bearing and **Option B stands as the safe answer**: one scope for both guards, every function guarded, the measured cost (a two-clause private record loop 36.7 ns vs 13.1 ns/iter, three tag tests per iteration; about 7 ns per test in hand-written Erlang) accepted.
* If **yes** (the exported guard grows to check nested record tags, which costs more bytes at every exported boundary), then A or C is safe, and A is the simpler. That is a larger decision than this ticket and belongs to 46's territory.

My recommendation is therefore **Option B now, and raise the nested-tag question as its own ticket**; I do not recommend A until that is answered. The escaped-fun entrance (`Inner/1` as a value) is a second, smaller hole, already open for the kind test; B closes it for the tag test and leaves the kind test as is.

C's blast radius (adding a sibling file that returns `Inner/1` changes `Inner`'s emitted guard in another file) is real for diff visibility, but the verifier notes it is sound, not unsound: the sibling creates a new entrance and the guard appears. "Word for word 18 §4's rejected failure" in the first draft was overstated; what carries over is the no-diff-in-the-changed-file concern.

**What would change this:** a decision that nested record tags are checked at the boundary (then A); a measurement that private-function record calls are rare in real programs (then B's cost is academic either way); David deciding a guard's emission may depend on sibling files (then C, but it still does not close the nested route).

## 7. Unmeasured, or measured weakly (do not cite as fact)

* OTP 26-28 and ARM. The 64% and 21.8 ns are one x86/OTP 25 machine; the *ratio* is the claim.
* Real programs: the examples contain no private record function worth timing, so "how often does this matter" is unmeasured.
* The 183 baseline eunit failures were not triaged individually.
* The fourth shape and Elm.
* Probe 04's per-variant timings are min of 9 runs of 30M iterations; run-to-run spread on `RunInt` was about +-8% (5.59 to 6.21 ns across variants that emit identical code for it), so only differences far outside that, like the record rows, are claimed.
* Nested-record and tuple-element reachability (section 6) was found by the verifier, not by the worker; its probe is `mine/forge.sh` in the verifier's scratch copy, and the committed probes do not include it. Re-running it from the brief's description is the way to check it.
* The 36.7 ns headline is three tag tests per iteration (two clauses plus a `Get`), not two.
* Off-by-one anchors: `beam_ssa_type.erl:118-120` (not 119-121), ticket 46:117-119 (not 118-119). Ticket 46's lines 221 and 290 are continuation lines of a passage about refined `int`.
* Ticket 18:613's "exported vs local-only" is imprecise rather than wrong: the BEAM rule measured is exported-or-escaping.
* Harness quirks: `lib.sh` defaults `BSC` to the scratchpad bsc, so probes 01, 02, 02b and 03 need `BSC=<var/v0/bsc>` to test the rebuilt v0; `build_variants.sh` and `08_eunit.sh` find the repo root three directories up from the script.

## Independent verification (separate agent, rebuilt v0 to v4 from the patches)

Verdict: **sound with caveats.** All measurements reproduced (record loop 36.3-38.5 vs 13.0-13.6 ns/iter over five runs, Code chunk 329 to 285 bytes, per-guard bytes, eunit failing sets identical by name for v0, v1 and v4, v2 adds exactly the two tests pinning F24's decision). Timing loops are answer-equal and not hoisted. The headline safety claim was incomplete; section 6 is revised accordingly.
