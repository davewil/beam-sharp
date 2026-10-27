# Ticket 59 (ENG-241) — decision brief: one scope for the two boundary guards

**Status: the decision stays OPEN.** Nothing here resolves the ticket. Ticket file:
`wayfinder/issues/59-boundary-guard-scope-asymmetry.md`. Probes: `artifacts/ENG-241-ticket-59/probes/`.

**Toolchain, read first.** Every number is **OTP 25.3 / Elixir 1.14 on x86-64, one shared container**,
not the pinned OTP 28.5. The real `bsc` does not build here (`bs_lexer.xrl` needs OTP 27's leex). I
built it from the repo's source in a scratch dir with a lexer shim (`patches/OTP25_lexer_shim.diff`:
token columns are fake, nothing else changed) and `warnings_as_errors` relaxed. **`bs_emit.erl` is
byte-identical to the repo's** (diffed). Gleam: unavailable (binary download denied). Elm: installed
but cannot compile (`package.elm-lang.org` refused, 403), so Elm is RECORDED only.

## 1. The question, as B# code

```csharp
module P59
record Order { Id: int, Total: int }
type Octet = int where value >= 0 and value <= 255

public int SumTotals(list<Order> os)          // exported
SumTotals([]) -> 0
SumTotals([o, ..rest]) -> Total(o) + SumTotals(rest)

int Total(Order o)                            // private
Total(o) -> o.Total

public int SumBig(list<Octet> xs)
SumBig([]) -> 0
SumBig([x, ..rest]) -> Big(x) + SumBig(rest)

int Big(Octet n)                              // private
Big(>= 9) -> 1
Big(>= 0 and <= 8) -> 0
```

Full file: `probes/bs/P59/p59.bs`. The shipped emitter (`bs_emit.erl:274-290`) gives `Total` a tag test
and `Big` **no** kind test (**MEASURED**, p1: `Total(O) when map_get('Kind',O) =:= 'P59.Order'`;
`Big` has no `is_integer`).

## 2. What the measurements change about the ticket's framing

The ticket weighs "private tag test is dead weight" against "a forged record reaches a private
function through an exported one". **Both sides assume the path is exported → private. Measured, that
path is already closed, and the real paths are two others.**

1. **Exported pass-through is already guarded.** `TotalOf(Order o) -> Total(o)` carries the tag test
   on the exported function, and `BigOf(Octet n) -> Big(n)` carries `is_integer`. A forged value
   passed straight on is refused at the door (p2: `TotalOf(forged)` → `function_clause`;
   `BigOf(100.5)` → `function_clause`). That is 18 §4 working as written. The private tag test adds
   nothing on this path.
2. **Values nested in a container reach the private function untested.** The exported guard looks at
   the list, never its elements (p1: `SumTotals`/`SumBig` carry no element test). So:
   - `SumTotals([forged-record])` → `function_clause`, **only because** the private `Total` tests
     the tag. Strip that one guard from bsc's own `.abstr` and the same call returns **`5`** (p2a').
   - `SumBig([100.5])` and `SumBig([300])` → **`1`**, silently, with no refusal, although neither
     is an `Octet` (p2b). There is no private kind test.
3. **A private function handed out as a value is callable with anything.** `TotalFn() -> Total` and
   `BigFn() -> Big` return the private functions as funs (F46 spelling). A foreign caller applying
   them: tag test refuses a forged map; `Big(100.5)` and `Big(300)` answer `1` (p8, variant A).

**Consequence for the guarantee.** 18 §1 states claim C as *"A wrong term from outside will crash —
not always at the call site, but never silently"* (`18-boundary-defence.md:499`). As shipped, that
sentence is **true for a nested record and false for a nested `int`/refinement**. The asymmetry the
ticket asks about is real, but its effect is not "who pays for a redundant test": it is whether the
sentence holds. Whether 18 meant the sentence to cover nested elements is not stated there. This is
observed behaviour, not intent.

## 3. Sub-decisions

Gating question, asked alone: **is "exported" the right discriminator?** Measured answer: it is a
proxy, and it misses nested elements and function values. Everything below follows from it.

- **G.** Scope rule, stated once for both guards. Options below.
- **S1.** Private record tag test: keep or elide.
- **S2.** Private `int`/`float` kind test (and the range half): stay exported-only, or follow S1.
- **S3.** Does scope depend on value provenance? Not needed: `erlc` already does that step (§4 below).

## 4. Evidence about cost

| Claim | Result | Source |
|---|---|---|
| Tag test, Code bytes | **+12 B** (86 → 98) on OTP 25; recorded +14 on 28.5 arm64 | p3 MEASURED |
| `is_integer`, Code bytes | **+9 B for two clauses** (≈4.5 each); recorded +3–5 each | p3 MEASURED |
| `is_integer` call time | Δ ≈ 0 ns (−0.65…−0.05; identical-copy noise |Δ| ≤ 0.4) | p4, 3 runs × 51 reps MEASURED |
| Tag test call time | **+8.8…+11.3 ns/call** on a one-lookup body; noise floor ≤ 3 ns | p4 MEASURED |
| `erlc` drops a redundant `is_integer` in a local callee | **yes**, even without `+inline` (callee has 0 tests, caller 1) | p3 MEASURED |
| `erlc` drops that `is_integer` when the argument is an untested list element | **no**, it stays | p3 MEASURED |
| `erlc` drops a redundant tag test | **no** (`g` keeps 1 test with and without `+inline`) | p3 MEASURED |
| Why `erlc` can | exported params start at `any`, local ones at the join of call-site types | `beam_ssa_type.erl:119-121`, `:432-440` (OTP 25 compiler-8.2.6.3 source) |

Reading: **a kind test on a private function is free exactly where it is redundant and present
exactly where it works.** A tag test is paid in full either way. The `erlc` finding is the
provenance analysis S3 asked for, supplied for free. It is OTP 25's; see limits.

The 26a/18a record that "the tag itself costs nothing measurable" (7.04 vs 8.78 ns, arm64, OTP 28)
is **not reproduced** here as 'nothing': about 6 ns by min and 10-16 ns by median on a trivial body (verifier, 5 reruns; the box is bimodal, median noise 7-10 ns). Ticket 26's 7.04 vs 8.78 compares two guarded forms, so it is not strictly contradicted; the guard-versus-none delta was never stated there (verifier's rerun of 26a: +4 ns). A real body amortises it; still, a flat
"nothing" is not what this box saw.

## 5. Options

### Option 1 — Elide the private tag test. One rule: *guards live on exported functions only.*

```csharp
// as P59 above. After the change:
SumTotals([{ Kind: :'Other.Thing', Id: 1, Total: 5 }])   // returns 5, not function_clause
```

Compiler delta: `guard_one/8` — `{ok, Tag}` gains `when Public`, with `{ok, _} -> {Pat, []}`
(`patches/C_tag_test_exported_only.diff`, 1 clause). Update F3.9's text (F3-records.md:252-260 says
"exported" only; line 460 notes it is narrower than that) and add a scenario that a private record
parameter is unguarded.

Evidence: saves 12 B and roughly 6-16 ns per private call on a trivial body (p3, p4, verifier). Corpus: **removes 0 tests in 22 small modules**
(tag tests 9 → 9, p6); **but staging 25f/25g removes 5 of 17 tag tests (-78 B)** (verifier): no example has a private record parameter, so this option
is invisible to the gates as they stand. Nested forged record → `5` silently (p2a', p8 variant C).

Strongest counterargument: **it makes the never-silently sentence false for records as well**, so
the guarantee would then hold for neither nested record nor nested int, and the only thing bought is
12 bytes nobody has measured as a problem.

### Option 2 — Widen the kind test to private functions. One rule: *every function tests what its declared parameter type promises, unless its own head already does.*

```csharp
Big(>= 9) -> 1                    // private; now emits is_integer(N) first
SumBig([100.5])                   // function_clause, was 1
```

Compiler delta: `guard_one/8` — drop `when Public` on the `none` branch, which also deletes the
now-unreachable `none -> {Pat, []}` clause (`patches/B_kind_test_on_private.diff`, 1 line plus the
dead clause). The float branch moves with it (same `case`). Rewrite F24 §2 "Exported only" and
scenario F24.6 (`Inner` unguarded) to the opposite, and F24 §3 (the asymmetry) disappears.

Evidence (p6, 22 modules compared): **+19 source `is_integer` guards (48 → 67), +0 surviving test
instructions in the compiled `.beam` (44 → 44), +0 Code bytes (9599 → 9599)**; `erlc` removes every
redundant one. In P59 the private `Big` keeps its test (nested, untested) and refuses `100.5` and
`300` (p7, p8 variant B). Tag behaviour unchanged.

Strongest counterargument: **the cost argument rests on `erlc`'s analysis**, measured on OTP 25 and
not re-run on the pinned 28.5. If a future compiler stopped doing it, the cost returns, but it is
+3–5 B and ≈0 ns per call (p3, p4), so the downside is small and bounded. Second: this contradicts
the letter of 18 §4 ("exported function's own clause heads") and F24 §2's cited authority, so a doc
rewrite and a ticket-18 entry amendment are owed. Third: it does not make nested checking complete:
an element only gets tested if some function with a typed parameter receives it.

### Option 3 — Keep the shipped asymmetry, and write it down as the rule: *tag everywhere, kind exported-only.*

Compiler delta: none to the emitter; a paragraph in 18 §4 and F24 §3 naming the rule.

Evidence: unchanged behaviour (p1). The corpus is unaffected.

Strongest counterargument: **no principled reading gives these two guards different scopes.**
The argument for the private tag (26 §1: "no body ever checks which record a map claims to be")
applies word for word to a kind: `100.5 >= 9` is true, so no body objects either (F24's own premise).
Option 3 states the asymmetry and leaves the nested-`int` silent wrong answer (p2b, p8 variant A)
in the language.

## 6. Recommendation

**Option 2.** It is the only option under which the sentence in 18 §1 is true for the cases
measured, it costs 0 surviving instructions across the 22-module corpus (corpus-specific: every one of the 19 added guards receives an argument erlc can already prove an integer, so this does not estimate Option 2's cost on code that passes an untested value into a private int function), and it states one rule
instead of two. It does not rest on the ticket's "exported pass-through" argument, which p2 shows
was already closed for directly typed parameters (nested list elements and record fields still reach private functions untested). Option 1 is the right call only if the guarantee is deliberately limited to
"direct calls", which is a statement 18 would have to make explicitly.

The decision stays open for human review.

## 7. Survey

- **Elixir** (MEASURED, p5, Elixir 1.14.0): no `def`/`defp` distinction for a struct head. Compiled
  heads are `#{'__struct__' := 'Elixir.P5.Foo'} = _f@1` (`pub`) and
  `#{'__struct__' := 'Elixir.P5.Foo', v := _v@1}` (`priv`); a forged map is refused by both
  (`FunctionClauseError`). An `@spec`'d `integer` param gets no guard: `big(100.5)` → `1`. No
  Elixir `.ex` sources are installed (only `ebin`), so there is no file:line to cite for Elixir.
- **Erlang compiler** (source read): `beam_ssa_type.erl:119-121`, `:432-440` as in §4.
- **Gleam**: not runnable here. RECORDED, not re-executed: 18 treats Gleam as trusting FFI types
  (`18-boundary-defence.md`, "Gleam's position", row A, line ~497).
- **Elm**: RECORDED, not re-executed (`18-boundary-defence.md:446-450`): ports are Elm's one
  untrusted door and the checking happens there; `1e300` through an `Int` port leaks. Elm cannot
  compile here (package host 403).

## 8. Not verified / limits

- **OTP 25.3, x86-64, shared container.** The pinned toolchain is OTP 28.5. The `erlc` redundancy
  elimination (Option 2's cost story) and every byte/time figure are OTP 25. Re-run p3, p4, p6 on
  28.5 before relying on the "0 surviving instructions" claim.
- **Shimmed `bsc`.** Lexer columns are fake and `rebar.config` is relaxed; the emitter is the repo's.
  Not confirmed: full gate parity. Variants B and C are one-line scratch patches
  (`probes/patches/`), not repo changes. No tracked file outside `artifacts/` was edited.
- **Corpus**: 22 example directories compared; `Signalbox` and `exemplars` do not compile under all
  three variants on this build and I did not investigate why. `exemplars` holds the larger programs,
  so the "0 private record parameters in the corpus" result may not hold there.
- **p4 noise**: the shared box moved identical code by up to ±3 ns between copies; the is_integer
  result (≈0) is inside that, the tag result (+9–11 ns) is outside it in 3 of 3 runs. The body is
  one `map_get`, so the figure is a relative cost and an upper bound for real bodies.
- **RECORDED, not re-executed:** 18a's +3–5 B / ±0.09 ns on OTP 28.5 arm64; 26a's +14 B tagged map
  and 7.04/8.78 ns; 18b's 83.3% census; the 18 §4 and F24 §2–§3 wording; ticket 46's measurement
  that a private `Inner(Order o)` receives the tag test (p1 reproduces this on the shimmed build).
- **Not tested:** unions of records in a private parameter (the tag test is only emitted for a
  single closed record, `bs_emit.erl:274-276`), a refined `float`, binary/tuple parameters, closures
  created by lambda rather than by naming a private function.
- **Circularity audit.** Variants B and C were checked against a module whose answer was not tuned:
  p1's checker was first wrong (it matched a 6-tuple against 5-tuple clauses, so two "ok" lines were
  vacuous); fixed by matching the right shape and adding a "found N guard lists" non-vacuity assertion
  before trusting any "false". The FAIL lines on variants B and C in the manual sanity run were the
  intended differences, not probe failures.

## 9. Probe index

| Probe | What it shows | Result |
|---|---|---|
| `p1_emitted_guards.sh` (+`guard_shape.escript`) | tag on private `Total`, no kind on private `Big`, no element test on list params | all CHECKs ok |
| `p2_forged_values.sh` (+`strip_guard.escript`) | forged element refused only via private tag test; nested `int` silently accepted; exported refuses direct | as hypothesised |
| `p3_bytes_and_erlc.escript` | +12 B / +9 B; `erlc` drops redundant `is_integer`, not the tag test | as stated in §4 |
| `p4_call_time.escript` | call time with identical-copy noise control | tag +9–11 ns, int ≈0 |
| `p5_elixir_defp.exs` | Elixir `def`/`defp` struct heads, spec'd int | all CHECKs ok |
| `p6_corpus_variants.sh` (+`count_guards`, `count_beam_tests`) | corpus: A / B / C source guards vs surviving instructions | B +19 source, +0 surviving; C −0 |
| `p7_nested_survives.sh` | under B the nested guard survives and refuses | ok |
| `p8_private_as_value.sh` | private function handed out as a fun, three variants | matches EXPECTED line |


## Verification status
Independently re-run: `verification/VERIFIER.md`. p1, p2, p3, p5-p8 reproduce; fresh bsc copies with the shim and both patches built; `bs_emit.erl` identical to the repo. Standing: the exported function's own guard closes the direct forged-record path; nested `SumBig([100.5])`/`SumBig([300])` return 1 silently (also for record fields); `SumTotals([forged])` returns 5 once the private tag test is stripped. Softened above. Remaining weak spots:
- The stripped counterfactual (p2 a') and variant C's `5` in p8 are true by construction; p7 is a designed survivor case (existence, not frequency); p4's median statistic is fragile on this bimodal box.
- Signalbox fails under the unpatched build too (shim's fake token columns); `exemplars` is a namespace holding ~46% of `.bs` lines, so the 22-module corpus is not representative.
- The verifier overwrote the tracked `verification/p6_corpus_variants.rerun.out` with the complete (previously truncated) output.
The recommendation (Option 2) is now weaker than the brief reads: it rests on 'one rule, nested-element coverage' as a design argument, and its zero-cost evidence is corpus-specific. Option 1's saving is also not zero on the exemplars.
