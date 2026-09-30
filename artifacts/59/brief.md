# Brief: ticket 59, the boundary guard applies two rules with different scopes

Ticket `wayfinder/issues/59-boundary-guard-scope-asymmetry.md` · ENG-241 · prepared 2026-09-30 at `0dddf8b`.
Nothing here resolves the ticket. The decision is David's.

## Finding that changes the question

**The ticket's premise for the exported-only rule is false since F46.** Ticket 59 (and 18 §4, 46 §1,
F24 §2, F37 §1) say a private function's every call site is a checked B# call site. A private function
named in value position leaves the module as a `fun`, and `examples/Shop/Pricing` already does it
(`Rule(:staff) -> Free`). An Erlang caller can apply that fun to anything, and the int guard is absent
there (P3). So "exported" is no longer the boundary. The ticket asked whether the tag test is too wide.
Measured, the int, float and range guards are too narrow. The tag test is, today, the only guard on
that path.

## Question

`bs_emit:guard_one/7` emits the record tag test on every function and the `int`/`float`/range tests on
exported functions only. Which scope is right, stated once? Is "exported" the right discriminator? What
does widening cost?

## Sub-decisions

1. **Gating: may a private function that has left the module as a value go unguarded?** Asked alone,
   as a program. Everything below follows from the answer.

   ```csharp
   public fn(int) -> int Rule(atom tier)
   Rule(:staff) -> Keep                 // a private function, as a value
   private int Keep(int n)
   Keep(n) -> n
   ```
   From Erlang, `(M:'Rule'(staff))(foo)` returns `foo` from a function declared `int`. Should it crash?
   (Today: no, P3.)
2. **Follows: where does the record tag test live?** Only after 1 is answered. The tag test on a private
   function is a fourth guard on the same path and stops being special once the scope is one rule.
3. **Follows: does a nested value (one tuple deep) count?** It is 46 §4, already decided and unbuilt. It
   is not this ticket's, but it is why the private tag test looks useful today (P2).

## Evidence

| # | Claim | Probe | Result | Status |
|---|---|---|---|---|
| 1 | A private record parameter gets the tag test; a private `int` or `float` gets nothing | P1 | `private InRec/1 guard: map_get('Kind', O) =:= 'P1.Order'`; `InInt/1`, `InFloat/1` have none | VERIFIED |
| 2 | The spec says "exported" for the tag guard; the compiler does not | `LANGUAGE.md:3455` vs P1 | spec says "on an exported record parameter" | VERIFIED (divergence) |
| 3 | No test asserts the private tag test | grep `compiler/test`; P9 | variant A removes it and no runnable test changes | VERIFIED, with the P9 caveat |
| 4 | A forged record passed through an exported whole parameter is caught at the exported head | P2 `WholeRec` | `function_clause` under base and every variant | VERIFIED |
| 5 | A forged record one tuple deep reaches a private function, which only the private tag test refuses | P2 | base: `ViaRec` gives `function_clause`; A: gives `order`; the direct use `DirectRec` gives `9` under every build | VERIFIED |
| 6 | The same shape with an `int` is silent | P2 `ViaInt({1.5,1})` | `{ok,1.5}` from `public int`; `{ok,foo}` for `foo` | VERIFIED |
| 7 | A private function escapes as a value and is callable unguarded | P3 | `Rule(staff)(foo)` gives `foo`; `fun_info` says `{type,local}` | VERIFIED |
| 8 | "A value handed to another function is guarded" (18 §4) puts a guard on the callee | P1, P2 | the guard is on the exported caller (`OutRec`, `Use/3`); §4 says nothing about the callee | REFUTED as the ticket reads it |
| 9 | 18 §1: a guarded-public/unguarded-internal pair is impossible (one entry label) | P3 variant C | true for a call. For an escape a wrapper fun carries the guard and the direct call stays bare | PARTLY REFUTED |
| 10 | Widening costs +3-5 bytes per `is_integer` | P4 | corpus `Code` chunk: 8443 to 8452 bytes (+9) under B, 8486 (+43) under C | VERIFIED (OTP 25) |
| 11 | erlc removes a redundant private guard | P5, P5b | guard kept only when the argument type is unknown or the name escapes; corpus: 13 guards added in the abstract code, 2 survive in bytecode | VERIFIED (OTP 25) |
| 12 | The 2 survivors are exactly the escaping functions | P5c | `Shop.Pricing:Free/1` and `:Double/1`, both `escapes-as-fun=true` | VERIFIED |
| 13 | Widening is measurable in run time | P6, P8 | not resolved above noise (table below) | UNVERIFIED either way |
| 14 | Widening breaks existing tests | P9 | exactly two: F24.6 and F37.5 | VERIFIED (runnable subset) |
| 15 | A private tag test is dead weight because site 1 already refused a wrong tag | P2, P3 | false wherever the value came from an unguarded projection or an escape | REFUTED today |

Caveat on 3, 14: P9 ran 1303 tests, 451 of which fail on base here for toolchain reasons (see the
toolchain section). The claim is "no runnable test changes", not "the suite is green".

## Survey

Source files for Elixir, Gleam and Elm are **not installed** (Elixir has `ebin/` only; Gleam is a binary;
Elm is a binary and is not BEAM), so no file:line is cited for them. The compiler source for OTP is also
not installed, so nothing is cited from `beam_ssa_type`. Behaviour was probed instead.

- **Gleam 1.12.0** (P7a): a `pub` and a private function are emitted alike, both with a `-spec` and no
  guard. A private function returned as a value is `fun keep/1`, applied unguarded:
  `rule()(1.5) = 1.5`. The same escape B# has, with no defence on either side.
- **Elixir 1.14** (P7b): `def` and `defp` differ only in the export list. `&keep/1` returned from a `def`
  is `{:type, :local}` and `Probe59.rule().(1.5)` returns `1.5`. A hand-written guard on the `def` raises
  `FunctionClauseError`; there is nothing on the `defp`. Guards are the author's, so there is no
  compiler scope rule to compare.
- **Erlang/OTP 25** (P5): `erlc` treats a local function differently from an exported one. It drops the
  guard when every call site proves the type and keeps it when an argument is unknown or the name
  escapes. The BEAM applies the exported/escaping distinction itself.
- **Elm**: defends one door (ports), per ticket 18. Not re-probed; the Elm binary is compile-only.

Precedent: no neighbour puts a scope rule on guards. Only Erlang's optimiser distinguishes
private-and-visible from reachable, and the line it draws is "can a caller I cannot see exist".

## Measurements

Corpus: `compiler/examples`, 26 module directories compiled (Signalbox excluded by an OTP 25 toolchain
failure, not by the change). 102 public and 26 private functions.

| build | private tag | private int guards in abstract code | `Code` bytes | survivors in bytecode (local) |
|---|---|---|---|---|
| base | 0 | 0 | 8443 | 1 (`Intake:bs@validate@5/2`, generated) |
| A narrow tag | 0 | 0 | 8443 | 1 |
| B widen kind | 0 | 13 | 8452 (+9) | 3 (adds `Free/1`, `Double/1`) |
| C escape wrapper | 0 | 0 (2 wrappers) | 8486 (+43) | 1 (in the wrapper) |

**No private function in the corpus has a record parameter** (0 of 26). The private tag test currently
protects nothing shipped.

Run time, 1,000,000 elements, 40 reps, three alternating rounds, OTP 25 JIT (medians in microseconds):

| probe | base | B | C |
|---|---|---|---|
| P6 private `Step` in a list loop | 9018 / 9154 / 8584 | 9185 / 8493 / 9106 | not run |
| P8 `List.Map(xs, Double/1)` | 53182 / 39820 / 40240 | 40844 / 57447 / 55982 | 39044 / 39043 / 54394 |

Spread within one build is as large as the gap between builds. **No difference is resolved**, consistent
with 18's "below ±0.09 ns/call". Not measured: OTP 28.5, arm64, cold or megamorphic sites.

## Toolchain caveats

`rebar3` and OTP 28.5 are absent (OTP 25 here). The compiler was built with `erlc` from
`compiler/src`; OTP 25 `leex` has no `TokenLoc`, so a copy of the lexer gives every token `{Line,1}`
(columns are wrong, nothing in these probes reads them). `--diagnostics json` needs OTP 27's `json` and
was not exercised. The pinned build has not been run by me. Emission probes (P1-P3) read abstract code
the emitter produced, which does not depend on the OTP version.

## Options

### Option 1. Exported means exported (variant A)

```csharp
record Order { Id: int, Total: int }
private atom InRec(Order o)
InRec(o) -> :order
public atom ViaRec((Order, int) t)
ViaRec((o, _)) -> InRec(o)
```
Compiles to: `InRec/1` with no guard. Every scope-limited guard (tag, int, float, range) is exported-only.

Compiler delta: in `guard_one/7` (`bs_emit.erl:267`) the record branch gains `when Public`, plus one
fall-through clause returning `{Pat, []}`. A three-line insertion (`variants/variant_A.patch`). Two tests to add
(mirror F24.6, F37.5 for the tag), the `bs_emit.erl:325` comment reworded, F24 §3 and F37 §1 closed
with one sentence. No spec edit: `LANGUAGE.md:3455` already says exported.

Evidence: P2 under A: `ViaRec({Invoice, 1})` returns `order`; P3 under A: `Reader(total)` applied to
an Invoice returns `9`. Corpus and P9 unchanged.

**Strongest counterargument.** It widens a measured silent hole in the direction the ticket says is the
costly one. The private tag test is the only thing that refuses a forged record on the escape path
(P3 `Reader`) and past an unguarded projection (P2), and P3 shows the matching int hole is already open.
Choosing A declares both a named limit, while the author's `fn(int) -> int` return type is a claim the
compiler published and does not check. Also, the exported-only premise is false for escapes.

### Option 2. Guard every function (variant B: kind, float, range on private too)

```csharp
private int Step(int acc, int x)
Step(acc, x) -> acc + x
```
Compiles to `'Step'(Acc, X) when is_integer(Acc), is_integer(X)` in the abstract code; erlc drops the test
wherever it can prove the type (P5b: 11 of 13 corpus guards).

Compiler delta: delete `when Public` at `bs_emit.erl:276` and the dead fall-through clause
(`variant_B.patch`, 18 lines). `IntOnly` at `:174` stays correct. Two tests flip (F24.6, F37.5).
Amend ticket 18 §1's cost paragraph ("interior functions already pay nothing") and §4's scope
sentence. The spec needs a line: `LANGUAGE.md:3456` says "exported refined int".

Evidence: P2 under B closes `ViaRec` and `ViaInt` (both `function_clause`); P3 under B closes the
escape. Corpus +9 bytes; bytecode survivors are exactly the escaping functions (P5c). Run time
unresolved (P6/P8).

**Strongest counterargument.** It makes the guard free only through erlc's optimiser (P5 shows the
retained guards are the ones it cannot prove), so the price is an optimiser property, measured on OTP
25 and not 28.5. It also over-covers: `DirectRec` (P2) is still silent, so the private guard is an
incidental partial cover of the projection hole, not a rule, and it contradicts what 18 called "the
shape C wanted anyway". It guards 26 private functions to protect the 2 that escape.

### Option 3. Guard what a caller outside can reach: exported heads and escaping funs (variant C)

```csharp
public fn(int) -> int Rule(atom tier)
Rule(:staff) -> Keep
private int Keep(int n)
Keep(n) -> n
```
Compiles to a head that stays bare for direct calls, and to a wrapper where the name becomes a value:
`Rule(staff) -> fun(Bs@1) when is_integer(Bs@1) -> 'Keep'(Bs@1) end`. The tag test leaves private
heads and moves into the wrapper together with the int, float and range tests.

Compiler delta: a `privfns` table in the `forms/1` context (`bs_emit.erl:37-56`) and an
`escape_wrapper/6` called from `expr({e_fname...})` at `:1063`, reusing `guard_one/7` with
`Public = true` and `term` as the accepted type. About 30 lines (`variant_C.patch`). The same two
test additions as Option 1. Amend 18 §1's "impossible with one function" paragraph (Evidence 9).
F46 gains a scenario.

Evidence: P3 under C: `Rule(staff)(foo)` and `(1.5)` give `function_clause`; `Reader` with an
Invoice or `5` gives `function_clause`. P2 under C: `ViaRec` and `ViaInt` are silent (see below).
Corpus +43 bytes (2 wrappers). Nothing in P9 changes. The blast radius is one site: an edit that adds
`Double/1` to another function changes that function's emission and not `Double`'s, which is what 18
§4 was protecting.

**Strongest counterargument.** It adds a third placement rule (exported head, escape wrapper) to a
design whose point was one rule, and it does not close P2: a record or int one tuple deep, passed to a
private function called directly, goes silent when the private tag test is removed, until 46 §4's
projection guards exist. A wrapper also puts `-rule/1-fun-0-/1` in the stack trace where `Keep/1`
was; fun identity and ordering are not checked (UNVERIFIED).

## Recommendation

**Option 3, with one sequencing choice for David.**

- Answer the gating question yes: a private function published as a value is inside the boundary. P3
  measures it, F46 created it, and the guard machinery already exists.
- State the rule once: a guard is emitted at every entry a caller outside the checked code can reach,
  which is an exported function's head and the fun minted from a private name. Private heads are never
  guarded. That is 18 §4's function-local analysis unchanged, because each emission depends only on the
  site being emitted.
- Removing the private tag test opens P2's record case. Two orderings, pick one: remove it with
  Option 3 and accept the hole as owed to 46 §4; or keep it until the projection guards land and then
  delete it. The recommendation is to keep it until then, because today it is the only defence on the
  projection path and it costs 0 of 26 corpus functions. The asymmetry stays until that date, but as a
  labelled transitional over-approximation, not a scope rule. Raise a ticket for 46 §4 (grep found no
  issue tracking it).
- Reject Option 1 as stated: it makes the hole wider and the spec would then say "exported" about a set
  that is no longer exported.
- Reject Option 2 as the rule: its cost is carried by erlc, and it guards 26 functions to reach 2.
  It remains the simplest fallback if David prefers one sentence with no escape analysis.

The spec and the oracle disagree today (Evidence 2). Whichever option wins, `LANGUAGE.md:3455-3456`
needs a sentence, since the handoff treats the compiler as the judge and P2/P3 show the disagreement
is observable.

## Open risks

- Every cost number is OTP 25. The JIT in 28.5 may keep or remove different guards (P5 depends on
  erlc's type propagation for local functions).
- Run time was not resolved. A claim of "free" should wait for an OTP 28.5 run with P6 and P8.
- Variant C was built and run but not reviewed against `bs_emit`'s other users of `e_fname`
  (`List.Map` inlining, behaviour callbacks); only the corpus and the runnable suite were exercised.
- An arrow *parameter* (`fn(int) -> int` accepted by an exported function) is a second way a fun enters,
  but it is a foreign caller's fun, not a private function, and is out of scope here.
- F42's foreign-return guard and the OTP callback heads (`init`, `handle_call`) are exported and
  unaffected; not re-measured.
- Signalbox did not compile under this toolchain, so its private functions are not in the counts.

## Reproduce

Clean shell, from `/home/user/beam-sharp/artifacts/59/probes` (about 5 minutes; outputs are overwritten):

```
./run_all.sh            # builds 4 compilers into /tmp/bs59-build, runs everything below
```
Individually (each takes an `ebin` dir as `$1`, default `/tmp/bs59-build/ebin-base`):

```
source env.sh; build_compiler /tmp/bs59-build/ebin-base
for v in A B C; do build_compiler /tmp/bs59-build/ebin-$v $PWD/variants/bs_emit.$v.erl; done
./p1_private_guards.sh   [ebin]     # P1 -> p1_private_guards.out, .variant_{A,B,C}.out
./p2_forged_projection.sh [ebin]    # P2
./p3_fn_value_escape.sh  [ebin]     # P3
./p4_corpus_measure.sh <ebin> <label>   # P4 -> counts and Code bytes
./p5_erlc_local_types.sh            # P5 (erlc -S on p5_erlc_local_types.erl)
./disasm_count.escript /tmp/bs59-build/corpus-B      # P5b
./disasm_which.escript /tmp/bs59-build/corpus-B      # P5c
./p6_loop_bench.sh ; ./p8_escape_bench.sh            # P6, P8 (noisy)
./p7_survey_gleam.sh ; elixir p7_survey_elixir.exs   # P7
./p9_suite_delta.sh                 # P9, about 2 minutes
```
Probe history: `superseded/` holds P2 v1. Its private helper used `InRec(Order o)`, whose record
pattern tests `Kind` in the head (F22), so it could not separate the pattern from the emitter's guard.
Changed after seeing output, for that reason only; both kept. An earlier `InRec(_)` was refused by the
compiler and never ran.
