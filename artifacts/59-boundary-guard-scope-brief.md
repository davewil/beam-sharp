# Brief: ticket 59 / ENG-241 — the boundary guard applies two rules with different scopes

Status: **OPEN - for human review.** Probes: `artifacts/probes/59/` (one command: `artifacts/probes/59/run.sh`).
Nothing in `compiler/`, the ticket file or Linear was touched. Every "stripped" / "widened" variant below is
the `.abstr` bsc emitted, edited by an escript and recompiled with the same `compile` options bsc uses
(`bsc.erl:843`); it is *not* a compiler change.

## 1. Ticket and gating question

Ticket: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`. The record TAG test goes on private
functions; the int KIND test (F24) is exported-only; so is the FLOAT test and the RANGE test (F37).

**Hypothesis check first.** The asymmetry is real and is larger than the ticket says: *one* guard
(tag) is unconditional, *three* (kind, float, range) are exported-only (`bs_emit.erl:275-293`; the
comment at `bs_emit.erl:330-333` calls the split deliberate). Probe `bsc-compile.out` + `emitted-erlang.out`:

```
'Inner'(O) when map_get('Kind', O) =:= 'Guard.Order' -> map_get('Total', O).   % PRIVATE, tag test present
'IInner'(N) -> N + 1.                                                           % PRIVATE, no kind test
'OuterInt'(N) when is_integer(N) -> 'IInner'(N).                                % exported, kind test
```

**Sub-decisions the ticket implies**
1. Is "site 1 already refused it" (18 §4 / F24 §2) a claim about *types* or about *values*? (gating)
2. Given (1): which scope for the tag test — exported-only, as now, or exported plus something?
3. Given (1): do kind/float/range widen to private functions too?
4. Is "exported" the right discriminator or is it "reachable without passing a guard"? (follows from 1)
5. Cost of widening (ticket's item 3) — measured below; it does not gate anything.

**Gating question, asked alone:** *`Nested(Cart)` where `Cart.Primary` holds a map tagged `Invoice` and
the private callee wants an `Order`: does the call return `99` or raise?* Today it raises (in `Inner`).
Everything else follows from the answer.

## 2. Evidence

| # | claim | probe | result | verdict |
|---|---|---|---|---|
| E1 | private record param gets the tag test; private `int` param gets no kind test | `bsc-compile.out`, `emitted-erlang.out` | `Inner` has `map_get('Kind',O) =:= 'Guard.Order'`; `IInner` has no guard; `OuterInt` has `is_integer` | **ticket confirmed** |
| E2 | exported + whole record passed straight to private: private tag test never fires first | `forge-emitted.out` (`Outer(forged)`) | raises in `Outer`, stack top `'Outer'`; identical with test stripped (`forge-stripped.out`) | **dead weight on this path, as the ticket's "defect" side says** |
| E3 | forged record **one projection deep** (`Cart.Primary`) reaches private `Inner` unchecked by `Nested` | `forge-emitted.out`, `forge-stripped.out` | emitted: `function_clause` in `'Inner'`; stripped: returns **99** (`{value,99}`), also for a map with no `Kind` | **the private tag test fires on a value the exported function did not check. Strongest counterexample to "dead weight"** |
| E4 | same for a record **list element** reaching a private fn by `Inner/1` as a fun value | `forge-*.out` (`Totals`) | emitted: `function_clause` in `Inner`; stripped: `{value,[7,99]}` | second independent path; 46 §4 *decided* collections are not guarded at the export (`46:213-222`), so this one survives any depth work |
| E5 | the int analogue has the hole **today** | `forge-emitted.out` (`NestedInt`) | `Count=1.5` -> `{value,2.5}` out of a `public int` function; `Count=foo` -> `badarith` | outcome 3 of 18, reached because the private int is unguarded. Known as F24 §5 "refined int below the top"; this shows the asymmetry is *why* the record is safe at depth and the int is not |
| E6 | widening int to private closes E5 | `forge-widened.out` | `NestedInt(1.5)` -> `function_clause` in `'IInner'` | works |
| E7 | whole-int path: private int test is dead | `forge-emitted.out` (`OuterInt(1.5)`) | raises in `OuterInt` | F24.6 premise holds *there* |
| E8 | a private **union** record param is checked by its clause heads in both scopes | `forge-emitted.out` (`ViaUnion`) | `function_clause` in `'DocN'`, also with the tag test stripped (the strip only removes guard-form tests) | scope option never touches unions |
| E9 | cost, tag test, private fn | `disasm.out`, `sizes.out` | disasm: `bif map_get` + `is_eq_exact` = 2 instrs; Code chunk 395 -> 383 B when stripped = **12 B**; whole beam 1256 -> 1244 B | matches 26a's +14 B |
| E10 | cost, int test widened onto private | `sizes.out` | Code chunk 395 -> 400 B = **+5 B** (1 instr) | matches 18's +3-5 B |
| E11 | exported and private fns lay out identically (one entry label) | `disasm.out` vs `disasm-exported.out` | same instruction sequence, labels differ only | confirms 18 §1 "exported vs local-only" elision claim at the instruction level; I did not test what *erlc* would do with `+inline` |
| E12 | call time | `bench.out` | 7 runs x 5M calls, ~30 ns/iter incl. remote call + loop; emitted 30.8 [27.6..36.3], stripped 32.2 [28.3..37.9]; int 21.3 [19.9..23.2] vs widened 22.6 [18.1..26.4] | **ranges overlap; no difference measurable** (consistent with 18's +-0.09 ns resolution; mine is far coarser) |
| E13 | **corpus exposure today** | `corpus.out` | 25 compiled modules, 21 private functions, **0** carry a tag test | the asymmetry is latent: no shipped program has a private record parameter. The exemplars `25a-g` do not compile yet (`corpus` skips them) so this undercounts real programs |
| E14 | the narrowing-site precedent | `compiler/features/F24-boundary-kind.md` §6, `test/guard_kind_tests.erl:14` | a private int helper reached an atom through a *checker-sound-looking* comparison; "Privacy is what makes it silent" | the premise "every private call site is checked" has already been wrong once for `int` |

Reading E2 against E3: **both sides of the ticket are right about different value paths.** The test is
dead on whole-parameter pass-through and live on every path where the declared type is trusted below the
exported guard's reach.

## 3. Neighbour survey (all probes executed; sources cited where installed)

| language | behaviour measured | where |
|---|---|---|
| Gleam 1.19.0 | **No check anywhere, public or private.** `outer(forged_int())` with a float from an `@external` returns `2.5`; a non-`Order` term through a `pub opaque` value reaches `private_total` and returns `<<"x">>`. Generated `private_inc(N) -> N + 1.`, `outer(N) -> private_inc(N).` Gleam's boundary is the *`@external` declaration*, trust-based. | `probes/59/gleam/probe.out`, `gleam/emitted.out`. Compiler source **not installed** (only the binary and `.drv` files under `/nix/store/*gleam*`), so behavioural only |
| Elixir 1.18.5 | No automatic guard on `def` or `defp`. A forged `%{__struct__: Other}` passes a bare `defp` (`99`); a hand-written `%__MODULE__{}` pattern or `is_integer` guard on the **`defp`** catches nested forgeries (`FunctionClauseError` in `priv_pat` / `inc`); a bare `defp` lets `1.5` flow (`2.5`). The type checker infers signatures for `def` only (`types.ex:67,73`: `kind in [:def, :defmacro]`, `kind == :def`); `defp` bodies are traversed per use (`types.ex:80`). `inc(:a)` against a guarded `defp` yields **no** warning. | `probes/59/elixir/probe.out`, `warn.out`; `/nix/store/pp8kbll8n2778kdm3b3bihjj3nnrrvh3-elixir-1.18.5/lib/elixir/lib/elixir/lib/module/types.ex` |
| Erlang/Dialyzer (OTP 28.5) | No runtime check either; an unguarded private is the norm. **Dialyzer draws the same line 18 draws, but on "escaping", not "exported":** functions that escape (exported **or referenced as a fun value**) start with `any()` arguments, local ones start from their call sites (`dialyzer_dataflow.erl:2894-2898`, `3118-3121`). A literal wrong-kind call is flagged to private and exported callees alike (`erlang/dialyzer.out`). I read the source line; I did **not** probe an observable difference from escaping. | `/nix/store/qlclzl3234h2jwjpvy2gs72vzq2g6wkw-erlang-28.5.0.7/lib/erlang/lib/dialyzer-5.4.0.1/src/dialyzer_dataflow.erl` |

Takeaway, stated narrowly: none of the three emits a private-function check by default, so none
corroborates the *tag-on-private* behaviour; none contradicts 18 either, because none has a boundary
guard to scope. The one transferable observation is Dialyzer's: a function referenced as a value
(our `Inner/1` in E4) leaves the closed world even though it is not exported.

**Repo lines.** 18 §4 `18-boundary-defence.md:815-818` (function-local; "a value handed to another
function counts as unchecked, and is guarded"); 18 `:613-617` (elision is exported-vs-local, one entry
label); 18 `:190-195` ("restricting omission to non-exported functions is *not* an alternative — a
foreign value entering through an exported function reaches private ones unchallenged"); 46
`:213-222` (fixed number of projections, not through a collection); 46 `:247-250` (measured the
asymmetry); F24 §3 `F24-boundary-kind.md` (inherited on purpose); F37.5 `F37-boundary-range.md:170-178`;
tests that would flip under widening: `boundary_kind_tests.erl:88` and `boundary_range_tests.erl:122`.

**Not a defect in the ticket's text, but worth knowing:** ticket 59 quotes 18 §4 as *the* authority for
exported-only. 18 itself, three screens earlier (`:190-195`, about the failure arm) says the opposite
shape is unsound: values that enter through an exported function reach private ones. §4's function-local
analysis decides *how the exported guard is derived*; it does not state that private functions are exempt.
That exemption is F24's inference (F24 §2, last paragraph), not 18's sentence.

## 4. Options

All three are programs run against the same module (`probes/59/src/Guard/guard.bs`):

```csharp
record Order { Id: int, Total: int }
record Cart  { Primary: Order, Count: int }
int Inner(Order o)          Inner(o)   -> o.Total          // private
int IInner(int n)           IInner(n)  -> n + 1            // private
public int Nested(Cart c)   Nested(c)  -> Inner(c.Primary)
public int NestedInt(Cart c) NestedInt(c) -> IInner(c.Count)
```

### Option 1 — narrow: tag test exported-only (18 §4 read literally)

- Program: `Nested(Cart{Primary = <Invoice-tagged map>, ...})` returns `99` from a `public int`
  function (E3, `forge-stripped.out`). Under the status quo it raises.
- Compiler delta: `boundary_guards/5`, record branch (`bs_emit.erl:276`) gains `Public` in the guard
  like `bs_emit.erl:284` already has; delete the "deliberate" comment (`:333`); any test asserting a private record tag test flips
  (none found by name in `test/records_tests.erl`); no new pass. Smallest change.
- Evidence: -12 B Code per private record parameter (E9); call time unmeasurable (E12).
- **Strongest counterargument:** it re-opens outcome 3 for records. Today the tag test is the *only*
  thing between a forged nested or list-element record and a `public int` answer (E3, E4); 46 §4
  decided collections stay unguarded at the export, so no later depth work removes the E4 path.
  "Too narrow is a silent hole" is the ticket's own words, and E3 shows the hole.

### Option 2 — keep the tag test on private functions, state the rule, widen nothing

- Rule, stated once for all four guards: *a guard is emitted on a function where a value can arrive that
  no earlier guard reached.* Exported entry: always (foreign callers). Private: only the tag test, because
  it is the one guard whose reach below the export (a record field, a collection element, a function
  reference) is not otherwise built; kind/range for those positions are owed by 46 §4 and F24 §5 and
  become exported-side projections when built.
- Program: E3/E4 raise (as today); `NestedInt(Cart{Count=1.5})` still returns `2.5` (E5), now *named* as the
  one owed edge rather than discovered.
- Compiler delta: no emitter change. Edit the `bs_emit.erl:330-333` comment to state the rule; amend
  18 §4's "exported" with "and whatever a value reaches below an exported guard"; F24 §3 and F37.5
  stop calling the asymmetry unowned. Test: add a pinning test for E3 (forged `Primary` -> `function_clause`).
- Evidence: 0 cost change; E13 says no corpus program pays the tag test on a private function now.
- **Strongest counterargument:** it ratifies a rule whose justification is "the exported guard is
  shallow today" — a temporary fact. When 46 §4's record-field projection lands, E3 becomes redundant
  but E4 (collections) still stands, so the private tag test persists as a permanent compensation for a
  *decided* gap, while the equivalent int hole (E5) stays open. Users reading the emitted Erlang see an
  asymmetry whose reason is a footnote.

### Option 3 — widen: every boundary guard on every function, private included

- Program: E5 and E3/E4 all raise (`forge-widened.out` shows the int half).
- Compiler delta: drop `Public` from `guard_one`/`int_guard`/`float_guard` and the range subtraction
  (`bs_emit.erl:284-286`, `int_guard/6`); rewrite F24.6, F37.5 and their tests
  (`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122`) from "private not guarded" to "guarded".
  F24's own `IntOnly` shortcut ("a checked B# call site establishes it", `bs_emit.erl:177-182`) must go.
- Evidence: +5 B per int param, +12 B per record param (E9, E10); call time within noise (E12) — but a
  private helper is exactly where recursion lives, so the test runs per iteration, not per entry.
- **Strongest counterargument:** it contradicts 18 §4 and F24.6/F37.5 as written, converts "guards at the
  boundary" into "guards everywhere" (ticket 18 §1 priced exported-only and measured only that), and on
  whole-parameter pass-through (E2, E7) it is pure waste on every private call. It closes holes the
  decided path (46 §4 projections) was going to close at the *export* for the cost of re-testing at every
  interior step.

## 5. Recommendation

**Option 2.** E3 and E4 are executed counterexamples to the ticket's "dead weight" reading, and the
ticket's own rule is that too-narrow is the silent, costly direction; E2 is why the status quo is not a
bug for whole-parameter paths. Option 3's only extra gain is E5, which F24 §5 already owns and 46 §4 already
decided how to close (at the export, by projection); widening to the interior duplicates that and
breaks two shipped tests and a decided sentence. Option 1 is cheapest and wrong on E3. So: keep the tag
test, write the rule down, add the E3 pinning test, do not widen kind/range. Revisit only if the E4
(collection) path gains its own guard. This is a judgement; the evidence supports it, it does not force it.

## 6. What I could not measure

- **No real B# program in the repo has a private record parameter** (E13); the exemplars 25a-g do not
  compile, so the corpus says nothing about how often E3/E4 shapes occur in practice.
- **Message / ETS / process-boundary paths into a private function** (a private fn used as a `receive`
  handler or spawned): I covered nested field, list element via fun value and union; not mailbox.
- Call-time deltas are below my harness's resolution (spread 5-8 ns on 20-30 ns); 18a's number
  (+-0.09 ns) is cited, not reproduced. No JIT-native code size.
- Compile-time cost of the guard: not measured (trivial AST node).
- Dialyzer: I read where escaping functions seed `any()`; I did not produce a program whose warning
  changes because a private function escapes.
- Gleam compiler source is not installed; its behaviour here is from probes only. Elm was not probed (no
  boundary-scoped analogue to a private/public check; 18 already covered its port boundary).
- The "stripped"/"widened" builds are post-edits of bsc's `.abstr`; they match what Options 1 and 3 would emit
  for these shapes but I did not implement either in the compiler, so interactions with `constrains_kind`,
  `pins_integer` and `strip_rels` are untested.

## 7. Re-run

`artifacts/probes/59/run.sh` regenerates every `.out`. Individually:
`forge.escript Guard.abstr emitted|stripped|widened`, `sizes.escript Guard.abstr`,
`disasm.escript Guard.abstr Inner`, `measure.escript $(find corpus -name '*.abstr')`,
`bench.escript Guard.abstr`, `elixir elixir/probe.exs`, `cd gleam && gleam build`,
`cd erlang && dialyzer --plt erts.plt dprobe.beam`.

Status: **OPEN - for human review.**
