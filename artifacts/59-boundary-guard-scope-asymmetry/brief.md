# Decision brief: ticket 59 (ENG-241), the boundary guard's two scopes

Prepared 2026-10-04 against `master` @ `98d9835`. Nothing under `wayfinder/` or `compiler/` was edited; every
compiler change below was made on a **copy** (`/tmp/p59/...`) and is saved as a patch beside the probes.
All probes live in `artifacts/59-boundary-guard-scope-asymmetry/probes/` as `NN_name.sh` with its captured
`NN_name.out`; `10_build_variants.sh` rebuilds the four compiler variants from the real tree plus the patches.

**Variants used throughout** (all built from the real `compiler/src`, differing only in `bs_emit.erl`):

| name | what it is | patch |
|---|---|---|
| `base` | the compiler as it is: tag test on every record parameter, int kind/range/float tests on exported only | none |
| `narrow` | tag test exported-only too (the "it is a defect" reading) | `narrow.patch`, 1 line |
| `wide` | int kind, range and float tests on private functions too, tag test unchanged (the "unconditional" reading) | `wide.patch`, 8 lines |
| `proj` | `narrow` + ticket 46 §4's "fixed number of projections" at the exported entry (option C below) | `proj.patch`, 36 lines |

---

## 0. The one-paragraph answer

The ticket frames this as defect (18 §4 says exported-only) versus working-as-designed (a forged value reaches a private
function through an exported one). Measured, **neither framing is quite right**, and the second half of the argument
is partly misread:

* **A forged value does reach private functions through exported ones**, but not by being *passed on*: `Direct(Order o) -> Inner(o)`
  dies at `Direct`'s own guard. It gets in **through a projection or a collection**: a field of a record that passed its tag
  test, or an element of a list. The tag test checks `Kind` and nothing else (26 §1, by design), so the record's own fields,
  and everything in a `list<Order>`, arrive unchecked. In the probe, `narrow` returns `7` for a tag-less map and `14` for a
  list holding one; `base` has no such hole for records and **does** have it for ints (`Field(cart(1.5))` returns `3.0`,
  `FieldBig(cart(:foo))` returns `:big`), because the int test is exported-only. (Probes 02, 05.)
* **18 §4's sentence is not what protects the private tag test**, because the emitter does not do 18 §4's analysis at all.
  Guards come from the declared parameter type alone; the body and the callees are never read, and an unused `int`
  parameter is guarded too (probe 14). The sentence "a value handed to another function counts as unchecked, and is guarded"
  describes why the *exported caller* gets a guard, not why the *private callee* does. The sentence in 18 that actually says
  what the ticket's "not a defect" side needs is at `18-boundary-defence.md:194-196`: *"a foreign value entering through an
  exported function reaches private ones unchallenged."* Written about arm elision, but the same fact.
* **"Exported" is the wrong discriminator for correctness and a half-right one for cost.** The BEAM optimiser already
  discriminates on exported-vs-local *and* on call-site type flow: a guard on a private function is removed where every caller
  proves it (probe 03: 0 bytes) and costs +5 bytes where one caller does not (probe 03, `IntU`). The tag test is never
  removed, because the optimiser does not track map values (probe 01, 03).
* **The measured cost of widening is small in bytes and visible, not free, in a tight loop** (corpus +9 bytes of 8309; about
  0.3 ns per surviving `is_integer` and about 1.4 ns per tag test per iteration of a 13 ns loop, on a noisy shared machine).

**Recommendation: widen the int/float/range tests to private functions (`wide`)**, so one rule holds for every guard:
*a guard is emitted for every parameter whose declared type it decides, in every function; the Erlang compiler removes the
ones the call sites prove.* Detail, and the strongest counterargument, in §3.

Not the same as closing the hole: **no scope choice closes the projection hole in an exported body that has no private callee**
(`Compare(Cart c)` with a forged int field, probe 02 path 3c). That is ticket 46 §4's owed "fixed number of projections", still unbuilt (F24 §5).

---

## 1. Sub-decisions

Each is answered with the probe that answers it. Nothing here was assumed from the ticket text.

**1. Scope of the record tag test: exported-only or all?**
Today: all. Reproduced (probe 01): private `Inner(Order o)` emits `when map_get('Kind', O) =:= 'Priv.Order'`.
`bs_emit:boundary_guards` is now arity 6 (the ticket says /4 and /5); `guard_one/8` consults `Public` only on the int branch.
No test pins the private tag test: `narrow` passes the entire eunit suite with no new failure (probe 15). It is
unpinned behaviour, which says nothing for or against it.

**2. Scope of the int kind test (and its two siblings): exported-only or all?**
Today: exported-only. Reproduced (probe 01): private `Scale(Octet n)` and `Plain(int n)` carry neither `is_integer` nor the
range comparisons. Two further guards share the rule and the ticket does not name them: the F37 **range** test and the
`float_guard` (`is_float`) test. All three are inside the same `none when Public` branch, so the decision is really about
three guards, not two.

**3. Is "exported" the right discriminator?**
For *correctness*, no: the property that matters is "can a value of this declared type have arrived unchecked", which is
a provenance question. 18 §4 forbids answering provenance questions across functions (the blast-radius argument), so the
only function-local sound answer is "by declared type, always". For *cost*, the BEAM already has a discriminator and it is not
"exported": it is "exported, or any call site cannot prove it" (probe 07, `beam_ssa_type.erl`). 18's own cost note says the
same (*"elision is exported-vs-local"*) but understates it: elision on a local function is **conditional on the callers**, not
automatic (probe 03: `IntP`/`Oct` 0 bytes, `IntU` +5, `Big2` +10).

**4. Can a forged value reach a private function via an exported one, i.e. is 18 §4's "handed on counts as unchecked" doing work?**
The first half, yes (probe 02, seven paths). The second half, no: the sentence is about the exported function's own guard,
and the emitter does not implement the analysis the sentence describes (probe 14). The static premise the ticket leans on
(*"every private call site is a checked B# call site"*) **holds**: bsc refuses a wrong-kind, out-of-range or wrong-record
argument at a private call (probe 06, 6 of 6 refused). It is a statement about *static* types of arguments, and a forged
value has a different runtime type from its static one, which is exactly what a projected field or list element is.

**5. Cost if the answer widens.** Bytes: 0 where callers prove, +5 per unproven int parameter, +10 with two, the tag test
+12 to +14 and flat in field count (probes 03, 04). Corpus (27 example modules plus the 3 AoC programs): +9 bytes of 8309
(0.11%), 13 functions gain guard text, 6 of 7 changed modules gain 0 bytes (probe 13). Time: measured, §3.

---

## 2. What the probes show, in one table

All rows are real bsc output. "caught at X" is where `function_clause` is raised; "silent" means a wrong answer is returned.
The forged inputs are hand-built Erlang maps (probe 02's driver), i.e. a caller that skips every bsc check. Source: probe 05
(`05_scope_variants_runtime.out`), driver `forge_drive.erl`, fixture `fixtures.sh`.

| forgery | `base` (today) | `narrow` | `wide` | `proj` |
|---|---|---|---|---|
| exported param is a forged record (`Direct`) | entry | entry | entry | entry |
| record nested in a record param (`Nested`, wrong or missing `Kind`) | `Inner` | **silent `7`** | `Inner` | entry |
| int field into private `Scale(int)` (`Field(1.5)`) | **silent `3.0`** | silent `3.0` | `Scale` | entry |
| int field into a private comparer (`FieldBig(:foo)`) | **silent `:big`** | silent `:big` | `Big` | entry |
| Octet field into private `ScaleO(Octet)`, value `300` | **silent `600`** | silent | `ScaleO` | **silent `600`** (no range half prototyped) |
| Octet field, value `1.5` | silent `3.0` | silent | `ScaleO` | entry |
| `list<Order>` element, via a private recursive worker | `Inner` | **silent `14`** | `Inner` | **silent `14`** |
| same, private function passed as a value (`List.Map(os, Inner)`) | `Inner` | **silent `[7,7]`** | `Inner` | **silent `[7,7]`** |
| forged int field read in an exported body, no private callee (`Compare`) | silent `:small` | silent | silent | entry |
| private function called directly from Erlang | `undef` | `undef` | `undef` | `undef` |

Three things to read off it:

1. `base` is already unsound on private int paths (rows 3 to 6). That is not an effect of any proposed change; it is the
   current asymmetry's cost, and it is the "silent hole" the ticket says is the worse direction to err in.
2. `narrow` buys a **second** silent hole in exactly the place the tag test closes today (rows 2, 7, 8).
3. Only `wide` closes rows 2 to 8 except `Compare`; only `proj` closes `Compare` and moves the check to the door; and
   **neither closes everything**. The lists are the reason `proj` alone is insufficient: 46 §4 refuses a guard through
   a collection (O(n) in a length the caller chooses), so the private function is the only place that can check an element.

**Error shape** (probe 02 tail, probe 05): a guard on the private callee raises `error:function_clause` in `Forge:Inner/1`
with the forged map as the argument, and **no frame for the exported entry** (it tail-called). The blame lands on the
function that detected the lie, not the one that let it in. 18's guarantee is already worded for that
(*"not always where it entered, but never silently"*); it is an inspectability cost (ticket 23's), not a soundness one.

---

## 3. Options

Three, each a program plus the compiler delta. The program is the same for all three (it is the gating question, asked alone):

```csharp
module Forge
record Order { Id: int, Total: int }
record Cart  { Item: Order, Qty: int, Items: list<Order> }

int Inner(Order o)            // private
Inner(o) -> o.Total
int Scale(int n)              // private
Scale(n) -> n * 2

public int Nested(Cart c)  Nested(c)  -> Inner(c.Item)
public int Field(Cart c)   Field(c)   -> Scale(c.Qty)
```

Called from Erlang with `Item = #{'Id'=>1,'Total'=>7}` (no `Kind`) and `Qty = 1.5`:

```
              Nested(forged Item)               Field(Qty = 1.5)
 A  wide      crash in Inner/1 (function_clause)   crash in Scale/1 (function_clause)
 B  narrow    returns 7                            returns 3.0
 -  base      crash in Inner/1                     returns 3.0     <- today: the two rules disagree
```

The decision David has to make is the one this table asks: **"must `Field(Qty = 1.5)` crash, and must `Nested` crash?"**
Everything below follows from the answer.

### Option A. Every guard on every function (recommended)

*The rule, stated once for all guards:* **a guard follows the declared parameter type, in every function; the BEAM
compiler drops the ones the call sites already prove.**

Compiler delta (prototype `wide.patch`, built and run):

* `bs_emit.erl`: delete the `Public` plumbing: `function/2` (`Public = is_public(F)`), `clause/4`, `boundary_guards/6`,
  `guard_one/8`; collapse `none when Public` / `none ->` into one clause. Prototype is +1/-3 lines of logic (the 8-line diff
  includes a `_Public` rename to keep `warnings_as_errors` quiet); a real change removes the parameter in four signatures.
* Comments: the *"The kind guard"* header (`Exported functions only ... that asymmetry is deliberate`), `int_guard`, the range
  guard's header.
* Tests: exactly **two** existing tests fail on `wide` and both pin the old rule: `boundary_kind_tests:a_private_function_is_not_guarded_test`
  (F24.6) and `boundary_range_tests:a_private_function_carries_no_range_guard_test` (F37.5); everything else passes
  (1302 pass, same 5 environment failures as the unmodified copy; probe 15). Both must be inverted, and a new test added
  for the forged-projection program above.
* Docs: F24 §2/§3 and F37.5 (both say *exported only*), a one-paragraph amendment to 18 §4, F24.6 in the scenario table.

Evidence:

* Closes every private-callee row of §2's table (probe 05). Rule shrinks from "two scopes" to none.
* Bytes: 0 where callers prove it, +5 per unproven int parameter (probe 03, `IntU`; `Big2` +10 for two), tag test unchanged.
  Corpus: **+9 bytes of 8309 (0.11%)**; 13 functions in 7 modules gain guard text, 12 of them cost 0 bytes because the
  optimiser removes them (probe 13). Includes `Fib.Series/4`, the private accumulator worker, which gains three `is_integer` in
  source and 0 bytes in code.
* Time (probe 12, 41 and 61 rounds, interleaved, a byte-identical control `HotX` as the noise floor): in a loop
  `Loop(o, n, acc) -> Loop(o, n - 1, Step(o, acc))` whose accumulator the optimiser cannot prove an integer, `wide` adds
  **+0.47 ns/iteration (run 1) and +0.70 (run 2)** over a 13.3 ns baseline, for two surviving `is_integer(Acc)`; noise floor
  was -0.07 and -0.01. About 0.25 to 0.35 ns per guard, 3 to 5% for two.
  The guard on `n` is removed by the optimiser (`n - 1` of a proven integer is an integer).

**Strongest counterargument.** *It taxes the idiom B# teaches for avoiding the guard.* 18 §1 found one entry label serves
exported and local calls, so an exported recursive function pays its guards on every self-call, and the language's answer is
the public wrapper over a private worker (`Fib`/`Series`). Under A that worker pays per iteration for any accumulator the
optimiser cannot prove (`acc + x` is a `number`, not an `integer`). Measured: an exported `Loop` costs +0.9 to +1.1 ns/iteration over the
private one today (probe 12, `HotE`). Under A the private one costs most of that too. The tax is real and small; the only
way to avoid it is to stop guarding, which is option B or C's silent hole. A further caveat: **A does not make the claim
"never silently" true**, because the projection hole in an exported body (`Compare`, row 9) is untouched; A just removes the
asymmetry that made the private half *more* holey than the exported half.

### Option B. Exported-only for both (the "defect" reading)

*The rule:* **guards stand at the door only; a private function trusts its checked callers.**

Compiler delta (prototype `narrow.patch`): one line, `{ok, _} when not Public -> {Pat, []}` in `guard_one/8`. Plus doc
changes making 18 §4 the stated rule for all three guards, and a new test that pins it (none exists today).

Evidence:

* Saves 12 bytes of code per private record parameter, flat in field count (probe 03, `Rec3`/`Rec8` both -12) and about
  **1.4 ns per tag test**: 2.75 ns of a 13.3 ns iteration for the two private record parameters of the probe loop
  (probe 12, `narrow` vs `base`, noise floor 0.01 to 0.07). Corpus: **zero** change, there is no private record parameter in
  the 27 example modules or the AoC programs (probe 13), which is itself a finding: the private tag test has never been exercised by the corpus.
* Breaks no test (probe 15: same 5 environment failures as base, nothing new).
* Matches 18 §4 and F24 §2 literally, and the static premise holds (probe 06).

**Strongest counterargument.** *It converts a hole that is closed today into one that is open, in the only place the
language's own guarantee is stated.* `narrow` returns `7` for a record with no tag and `14` for a list containing one
(§2 table, rows 2, 7, 8): the ticket-06 "outcome 3" that 18 says is *"the only outcome that makes the type system a lie"*.
The static premise is true and beside the point: the forged value never was an argument at a checked call site, it was a
field or an element. B also leaves rows 3 to 6 as they are.

### Option C. Check at the door, deeper (46 §4's projections), private guards gone

*The rule:* **the exported entry guards a fixed number of projections (record-typed and int-typed fields of a record parameter, one
level); no private function guards anything.**

Compiler delta (prototype `proj.patch` on top of `narrow.patch`): `proj_tests/4` and `proj_one/4` in `bs_emit.erl`, ~35 lines,
walking the resolved closed-record field map, emitting `map_get('Kind', map_get(F, V)) =:= Tag` for record-typed fields and
`is_integer(map_get(F, V))` for int-typed ones. **Not prototyped:** the range half for refined fields (hence `Oct = 300` is
still silent in the table), tuple elements, `option`/`result` payloads. A real build also needs a
`bs_check`/F24-style statement of which projections are "fixed number" (46 §4 says whole parameter, tuple element, record field).

Evidence:

* Closes rows 2 to 4 and 6 and **row 9** (`Compare`, which no scope choice reaches); leaves the list rows 7 and 8 silent. 46 §4
  excludes collections by decision (O(n)), so C alone cannot reach "never silently".
* Bytes are **not flat**: at the exported entry +21 B for a 3-int-field record, +79 B for 7 int fields (probe 03,
  `Rec3`/`Rec8`, `proj` rows), roughly 11 B per field, and the cost is paid on every call of the exported function,
  including in-module calls (one entry label, 18 §1). Private functions pay 0.
* Eunit on `proj`: see §6 (probe 15).

**Strongest counterargument.** *It does not stand alone and it is the largest build.* Lists are the one collection every
realistic program carries (`Lines: list<Line>` is in LANGUAGE.md's `Order`), and the private function is the only place that can
guard an element at O(1) per call. So C ends up as C plus A's private guard for collection elements, which is A with more compiler
work. It also moves cost *onto the door*, which every in-module call of an exported function now pays per field.

### Recommendation

**Option A.** Reasons, in order of weight:

1. It is the only option that makes *one sentence* true for the whole function: the rule is "by declared type, every function"
   and the emitter needs no notion of visibility, which is also what the emitter already does for *what to guard* (probe 14: no
   body or callee analysis exists). B and C keep a notion of visibility the compiler cannot justify function-locally.
2. The ticket's own asymmetry argument (*"too narrow is a silent hole, too wide is measurable and loud"*) is borne out by both
   numbers: the narrow side opens silent wrong answers (§2), the wide side costs 9 bytes on the corpus and about 0.3 ns per
   surviving guard.
3. The BEAM optimiser already implements "pay only where unproven" for ints; A hands it the decision instead of re-deriving
   it with `Public`.

**What A does not settle and David should not read into it:** (i) the tag test is never elided by the optimiser, so on private
record parameters A keeps paying +12 B and about 1.4 ns each time, whether or not the caller proved the tag (probes 01, 03, 12);
(ii) A leaves `Compare` open, that is 46 §4's unbuilt projection guard, which is independent of this ticket and A does not conflict with it
(`proj` composes with `wide`); (iii) the guard-on-private error blames the private function (§2, error shape).

**Confidence: moderate-high on the correctness call, moderate on the cost call.** The cost call rests on a loop on a machine
shared with other sessions (load average 5 to 15 on 4 vCPU), spread 3 to 8 ns per round, so the *ordering* and the order of
magnitude are solid and the absolute nanoseconds are not. If David judges 0.3 ns per surviving guard in a tight private worker too
dear, the principled alternative is C, and it needs 46 §4 built first plus an answer for lists.

---

## 4. Survey, from sources opened

None of the neighbours discriminates guard emission by visibility, so **the existing exported-only int rule has no precedent
to defend it, and neither would a private-everywhere rule; B# is inventing in either direction.** That is a statement about
absence of precedent, not about which is right.

**Gleam** (1.12.0, tickets measured 1.18.1; probe 08). Built a project with a public record, an `opaque` type, private
helpers, and `pub fn` entries. The generated `gp.erl` contains **zero** guards: `inner(O) -> erlang:element(3, O).`,
`scale(N) -> N * 2.`, `add(A, B) -> A + B.`, and `unwrap(T) -> erlang:element(2, T).` for the opaque type. `pub` and private are
generated identically except for the `-export`. Forged calls from Erlang: `field({cart,_,1.5})` returns `3.0`,
`is_big({cart,_,foo})` returns `true`, `add(1.5,2.5)` returns `4.0`, a forged record dies in `erlang:element/2`. Gleam
`opaque` is compile-time only (`-opaque token()` is a Dialyzer attribute).

**Elixir** (1.14.0 on OTP 25, the installed Elixir cannot boot on OTP 28; tickets used 1.19.5, which adds a gradual type system
this one lacks; probe 09). `def` and `defp` compile to the same code apart from the export (`exports` list: `defp` names
absent, nothing else differs). A struct pattern `%Order{} = o` in a head is *user-written* and lowers to
`#{'__struct__' := 'Elixir.Order'} = O`, identical in `def pub_pat` and `defp priv_pat`; a `defp` with a pattern is the only check on a
nested value (`nested(%{item: %{total: 1}})` dies in `priv_pat` with `FunctionClauseError`), and a bare-parameter `defp`
checks nothing (`via_bare` returns `1`). `is_struct(o, Order)` in a guard expands to `is_map` + `is_map_key` + `map_get('__struct__') == 'Elixir.Order'`.
`@enforce_keys` is a **construction-time** check on the `%Order{}` literal only: `struct(Order, id: 1)` and
`%{__struct__: Order, total: 9}` both pass `pub_pat`. This is the same tag-versus-payload asymmetry 18 §6 recorded: a pattern
is not a check of the fields. Lesson for this ticket: in Elixir the *author* writes the private check where a nested value needs
one; B# would be the first to emit it automatically, which is A's case.

**Erlang/OTP 28** (probe 07; `/opt/otp28/lib/erlang/lib/compiler-9.0/src/beam_ssa_type.erl`). The module's own header, lines 122-125:
*"The argument types of all exported functions start out as 'any', whereas local functions start at 'none'. Every time a function call widens the argument types,
we analyze the callee again."* `opt_continue` lines 428-433: for a local function *"we're guaranteed to have visited every call site"*,
so the parameter types are the join of the callers'; exported functions get `any`. `sig_make_fun`/`opt_make_fun`
(lines 354-361, 736-756): a local function captured as a `fun` gets `any` for every argument, because *"someone could steal it through tracing and
call it"*. Probe 07 confirms the three cases on real code: a guard on a local function is gone when all callers prove it
(`l1`, 0 `is_integer` left), kept when one caller does not (`l2`), kept when the function is captured (`l3`), kept on an exported one (`ex`).
Consequence for this ticket: the VM already treats "local" as "type-flow-closed" and makes the redundant guard free, which is the
BEAM-level form of the ticket's premise ("every call site is checked"); it also means "private function passed as a value" (probe 02 path 4c) is a
channel the optimiser itself does not trust.

**Elm** (**not reproduced**, probe 11). Elm 0.19.2 is installed but `package.elm-lang.org` is blocked by the sandbox proxy (403), so
no project depending on `elm/core` can be built and no generated JS could be inspected. The claims about Elm are
**cited from `wayfinder/research/18-elm-port-validation.md`** (built there against 0.19.1): Elm validates only at ports
(a decoder synthesised from the declared port type), no other function gets a runtime type guard, and Elm's opaque types are a
compile-time export restriction. I did not re-verify that nothing is emitted for opaque types in the JS.

---

## 5. Claims not reproduced / caveats

* **26a's "+14 bytes, flat in field count": reproduced** (probe 04: tagged map +14 at 3 and 8 fields, per-field slope +0.0). My
  in-situ measurement of *removing* the private tag test from a whole module is **-12 B**, flat (3 and 8 fields). The 2-byte
  difference is unexplained (probably label/jump-table layout around a function with a failure arm); I did not chase it.
* **18's "+3 to 5 bytes per `is_integer`": reproduced** (probe 04: `id/1` +3, `add/2` +5, two guards +10, four +22). In situ: +5 per
  unproven private int parameter.
* **18's "call time below ±0.09 ns/call resolution": not reproduced for this loop shape.** Two surviving `is_integer` on the loop accumulator cost +0.47
  and +0.70 ns/iteration against a measured noise floor of -0.07 and -0.01 ns (identical-code control). 18 measured an isolated call on
  arm64 Darwin; this is a recursive loop on x86 under a shared CPU, spread 3 to 8 ns per round. This is a different measurement,
  not a refutation. **Per-guard cost, not per-loop**: I did not separate the two guards.
* **18's "a non-exported function has the test elided entirely": true only conditionally.** Reproduced for int parameters whose
  callers prove integer (probe 03 `IntP`, `Oct`: 0 bytes) and **not** when one caller does not (`IntU`, +5) and **never for the tag
  test** (maps are not tracked by `beam_ssa_type`). Ticket 18 (and so the ticket text) states it unconditionally.
* **File sizes are not used.** `.beam` file bytes vary run to run (embedded temp path) and include the `debug_info` chunk, which keeps
  guards the optimiser later removes. Probe 03 reports them but every conclusion uses the `Code` chunk.
* **Machine noise.** Other sessions share this 4-vCPU box (load average 5 to 15 during probe 12). Rotated interleaving and a
  same-code control bound the damage; absolute ns are not comparable to the tickets' Apple Silicon numbers.
* **The 5 eunit failures** (`every_aoc_program_still_compiles`, `batch_runs_every_entry`, `a_path_is_utf8_on_the_wire`,
  `the_diagnostics_gate_passes`, `a_non_ascii_literal_is_advised`) occur on the **unmodified copy** and are identical in every
  variant. They look like artefacts of running from a copy outside the repo layout (AoC path, gate scripts, locale); I did not
  investigate and did not run the suite in the real tree (that would write `_build/` there). `eunit_base.log` was taken while two other
  suites shared the CPU; narrow/wide were re-run alone after their first runs hit eunit timeouts.
* **`wide` also enables the float test on private functions** (the third guard, `float_guard/3`, not named in the ticket), and the range
  test. `narrow` does not touch them (they are already exported-only).
* **`proj` is a prototype of an owed feature, not a spec of it:** one level, no range half, no tuples, no `option`/`result`
  payloads, no collections. Its table row for `Octet = 300` is silent for that reason.
* **The corpus is thin for this question.** 27 example modules + 3 AoC programs; none has a private record parameter, so
  `narrow` changes nothing there. The three `exemplars/` programs do not compile on any variant (7 of 7 directories fail, base included), so they are excluded.
* **18a's own script** prints a stack trace in its violation section on this box; its size tables, which are what probe 04 uses,
  print first and are intact.
* **Not measured:** JIT native code size, arm64, cold or megamorphic call sites, OTP callbacks' `State` (F24 §4 already guards it
  and an OTP callback is exported by rule), the mailbox/ETS channels (they arrive as `term` and are already defended by ticket 11/18 §0).
* **Ticket text corrections:** `boundary_guards` is arity 6 now, and its comment already says the tag asymmetry is *"deliberate"*
  (the older *"unconditional on an exported record parameter"* wording quoted by 46 is gone).
* **Greps done (CLAUDE.md rule):** `grep -ln 'ENG-241\|ticket 59' wayfinder/issues/*.md` returns only 58 and 59 itself. No other ticket
  decides this. The only other sentence on point is `18-boundary-defence.md:194-196`.

---

## 6. Eunit on the prototypes (probe 15)

| variant | result | new failures vs the unmodified copy |
|---|---|---|
| `base` | 1304 pass, 5 fail | (reference) |
| `narrow` | 1304 pass, 5 fail | **none** |
| `wide` | 1302 pass, 7 fail | `boundary_kind_tests:a_private_function_is_not_guarded_test`, `boundary_range_tests:a_private_function_carries_no_range_guard_test` |
| `proj` | PROJ_EUNIT_RESULT | PROJ_EUNIT_DELTA |

---

## 7. Probe index

| # | files | answers |
|---|---|---|
| 01 | `01_asymmetry_repro.sh/.out` | (a) private `Inner(Order)` has the tag test; private refined-int/`int` parameters have no kind or range test; exported controls have all |
| 02 | `02_forgery_paths.sh/.out`, `fixtures.sh`, `forge_drive.erl` | (b) nine forgery paths from a hand-built Erlang caller against `base`: where each crashes, error shape, full stacktrace |
| 03 | `03_code_size.sh/.out` | (c) Code-chunk bytes per guard per variant: tag flat in fields, int +5 unproven / 0 proven, range 0 behind a guarded caller, `proj` O(fields) |
| 04 | `04_rerun_26a_18a.sh/.out` | (c) the tickets' own 26a / 18a prototypes re-run unmodified on OTP 28 |
| 05 | `05_scope_variants_runtime.sh/.out` | (b)(e) the same forgeries against `base` / `narrow` / `wide` / `proj` |
| 06 | `06_checked_call_sites.sh/.out` | the static premise (private call sites are checked): 6 of 6 wrong arguments refused, plus the field-of-declared-type route |
| 07 | `07_erlang_local_call_types.sh/.out` | Erlang: a guard on a local function is elided only when callers prove it; captured funs and exported functions keep it |
| 08 | `08_gleam_boundary.sh/.out` | Gleam 1.12.0: generated `.erl` has no guards, `pub`, private or `opaque`; forged calls from Erlang |
| 09 | `09_elixir_boundary.sh/.out` | Elixir 1.14.0: `def`/`defp` compile identically; struct patterns, `is_struct`, `@enforce_keys` |
| 10 | `10_build_variants.sh/.out`, `narrow.patch`, `wide.patch`, `proj.patch` | (e) builds the four variants from a copy of `compiler/` |
| 11 | `11_elm_attempt.sh/.out` | Elm: blocked by the proxy; claims cited, not reproduced |
| 12 | `12_hot_loop.sh/.out`, `12_hot_loop.run2.out` | (d) ns per iteration in a hot private loop, 41 and 61 interleaved rounds, noise-floor control, spread |
| 13 | `13_corpus_sweep.sh/.out` | (c)(e) what each variant does to the real corpus: functions changed, guard text, bytes |
| 14 | `14_function_local_analysis.sh/.out` | 18 §4's analysis is not implemented: guards come from the declared type only (an unused param is guarded) |
| 15 | `15_eunit_variants.sh/.out`, `logs/eunit_*.log` | (e) the compiler's own eunit suite on each variant |

Circularity note: no probe was edited to produce an expected result. The two probes that changed did so for correctness of
the harness, and the earlier versions' findings are unchanged: `02`'s driver was extended with paths 3c/3d/4b/4c/error-shape after the first
run (the first nine lines of output are identical); `03`'s delta formatting was fixed (`~+w` is not an Erlang format) after its first run printed garbled
labels over correct byte counts; `13` gained the AoC programs and a de-duplication, and its first run (27 modules, +9 B) agrees with the final one (28 modules, +9 B).
`12` is deliberately two runs with different N and rounds, both kept.
