# Ticket 59 / ENG-241 — the boundary guard applies two rules at two scopes

**DRAFT FOR HUMAN REVIEW — ticket remains open.** Nothing here resolves, edits or commits anything.
Probes: `artifacts/probes/59-NN/` (each `run.sh` + captured `out.txt`; re-run with only `env.sh` sourced).
Repo HEAD at measurement: `019533d`. Prototype compilers were built in a scratch copy; `compiler/` is untouched.

## 0. Is the ticket still true? Yes, and it has grown

- Still present (59-01): a private `Inner(Order o)` emits `'Inner'(O) when map_get('Kind', O) =:= 'T.Order'`;
  a private `InnerN(int n)` emits no `is_integer`; the exported twin of each is guarded.
  Source: `bs_emit.erl:278` (tag test, no `Public` test) vs `bs_emit.erl:284` (`none when Public ->`).
- **Stale details.** The ticket says `boundary_guards/5`; it is now `/6` (`bs_emit.erl:265`). It says two guards
  at two scopes; there are three kinds of test: tag (all functions), kind (`is_integer`/`is_float`, exported),
  and range (F37, exported; `boundary_range_tests.erl:122` pins "private carries no range guard").
- **No test or feature pins the private tag test.** F3.9 (`F3-records.md:252`) and `records_tests` pin only the
  *exported* case; the only private-function tests (`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122`)
  are about the int/range tests. Corpus census (59-03): 28 example modules, 100 public + 16 private functions;
  **0 private functions carry a tag test** (10 public do, 41 public carry `is_integer`). The question is
  untested by the corpus as well as by the suite.

## 1. Sub-decisions the ticket bundles

1. **GATING — does the record tag test stay on private functions?** (the ticket's stated question)
2. Whether the int kind/range tests widen to private functions. *Follows from 1*: both rest on one premise
   (the premise "a private function's every call site is a checked call site" is NOT in 18 §4 — it is at 46:166, bs_emit.erl:330, F24:115 and F37:170; 18 §4 itself says a value handed to another function "counts as unchecked", which supports the private tag test), so they stand or fall together.
3. Whether "exported" is the right discriminator at all. *Settled by measurement, below*: it is the BEAM's own.
4. Cost if widened. *Measured, below.*

## 2. The gating question, stated alone

> A forged record reaches an exported function. The exported function's own guard tests only its direct
> parameters. It hands a *field* of that record to a private function declared `Inner(Order o)`.
> **Should `Inner` check that the `Order` it receives is an `Order`?**

The ticket frames it as defect-vs-narrow. The run shows the premise both sides share is partly wrong.

### Finding: 18 §4's premise "site 1 already rejected a wrong tag" is false for nested positions (59-02)

```csharp
record Order { Id: int, Total: int }
record Line  { Item: Order, Qty: int }
int Inner(Order o)             { Inner(o) -> o.Total }      // private
public int ViaOrder(Order o)   { ViaOrder(o) -> Inner(o) }  // own guard fires first; Inner's is dead here
public int ViaLine(Line l)     { ViaLine(l) -> Inner(l.Item) }
public int ViaList(list<Order> os) { ... Inner(o) ... }
public Order ViaItem(Line l)   { ViaItem(l) -> l.Item }     // no private fn at all
```
Forged `Item = {Kind = 'T.Invoice', ..}` (59-02/out.txt):
```
ViaOrder top-level forged      {error,function_clause,raised_in,'T','ViaOrder'}   % exported guard
ViaLine nested forged tag      {error,function_clause,raised_in,'T','Inner'}      % PRIVATE guard is the only defence
ViaList elem forged tag        {error,function_clause,raised_in,'T','Inner'}
ViaItem returns nested forged  #{'Id' => 1,'Kind' => 'T.Invoice','Total' => 7}    % typed Order, nothing checks
ViaLineQty forged payload      5.0                                                % `int` private fn fed 2.5: silent
```
So: a forged record **can** reach a private function through an exported one. The exported guard is shallow
(`map_get('Kind', L) =:= 'T.Line'` only), a checked call site accepts anything *projected out of* an unchecked
aggregate as typed, and the private tag test is then the **only** thing that fires. It is incidental, not
systematic (`ViaItem` shows the hole left open), but it is not dead weight. Likewise the int/range omission on
private functions leaves a real, silent outcome-3 (`ViaLineQty` returns `5.0` from `int`).

## 3. Options (each: B# program, compiler delta, evidence, strongest counterargument)

Prototypes: `59-04/narrow.patch`, `59-04/widen.patch`; both build with `59-04/make_variant.sh`. Same program,
three compilers (59-05/out.txt):

| program result | base (today) | narrow (A) | widen kind/range (C) |
|---|---|---|---|
| `ViaLine`/`ViaList` forged nested tag | crash in `Inner` | **returns `7`** | crash in `Inner` |
| `ViaLineQty` with `Qty = 2.5` | `5.0` | `5.0` | **crash in `Twice`** (`when is_integer(N)`) |

### A. Narrow: tag test on exported functions only (treat as a defect against 18 §4)
Delta: one condition in `guard_one` — `case constrains_kind(Pat) orelse not Public of` (3-line patch, 59-04).
Remove nothing else; the `Public` boolean is already threaded to this function.
Evidence: 40 tag tests removed (20 two-field + 20 twelve-field private record fns) cut the `Code` chunk 6335 -> 5786 bytes
(**13.7 bytes per tag test**, re-confirming the +14 claim; 2 instructions, `bif map_get` + `is_eq_exact`) and
~3.5 ns/call in a 20M-call loop (59-06: min 6.27 -> 9.76 ns, noise floor 0.66 ns, 9 runs). Erlc cannot elide it
even when the caller tested the same map (59-07 `rec_proven`: both tests remain), so 2 dead instructions per
private call are real in the direct case.
Strongest counterargument: it makes `ViaLine`/`ViaList` above silently return `7` for an `Invoice` that is typed
`Order` — outcome 3 — to save 14 bytes and ~3 ns; the ticket's own "too narrow is a silent hole" asymmetry.

### B. Status quo, name it: keep tag-everywhere / kind-exported, amend the text
Delta: none in the compiler. One sentence in 18 §4 / F24 §3 / F37.5: the tag test is unconditional because the
exported guard is shallow; the private test is the nested-position cover; kind/range stay exported-only.
Evidence: 59-01, 59-02. Leaves `ViaLineQty -> 5.0` (kind hole) open and says so.
Strongest counterargument: it records an inconsistency as a principle. The *same* shallow-guard reasoning that
justifies the private tag test justifies a private `is_integer` (the hole in the last row), so B is stable only by
choosing not to apply its own argument.

### C. Widen: kind and range tests also apply to private functions (tag stays)
Delta: `none when Public ->` becomes `none ->`, drop the now-unreachable clause, `Public` param unused (`widen.patch`,
~6 lines). Reverses F24.6 / F37.5 (`boundary_kind_tests.erl:88`, `boundary_range_tests.erl:122` change).
Evidence (59-04, 20 private int + 20 private float fns): where every caller's argument is provable, erlc deletes
the test (fixture figure `4176 -> 4176` is in no out.txt; the verifier's fixture without 12-field records gave 3076 -> 3076, so the direction holds; verification/59.md); same mechanism 18a recorded and 59-07 reproduces:
`loc_int` keeps its test only because `unproven/1` also calls it). On real code the zero-byte claim does NOT hold everywhere: across 28 example modules plus 3 aoc programs, 28 have identical code and three grow — Shop.Pricing +9 B (2 tests, private functions passed as function values), aoc/2025/Day01 +34 B (3 tests), aoc/bench/Day01 +18 B (2 tests): 4.5–11 B per surviving test; no runtime cost shown. Where the argument is a record-field
projection (the exact hole), tests survive (`is_integer` 1 -> 21, `is_float` 1 -> 21): Code chunk 6335 -> 6535 bytes, 40 tests, **5.0 bytes each** (consistent with
the 3-5 claimed). `is_integer` call cost not measurable (-0.05 ns/call, inside 0.66 ns noise, 59-06; caveat:
verified by `erlc +to_asm`: `int_g` and `int_n` compile to identical asm, so erlc erased the test in that arm — it is vacuous, not merely unmeasurable. The tag test is 2–3.5 ns/call (verifier re-run 2.14 vs author 3.49; noise ~0.7)).
Strongest counterargument: it contradicts 18 §4's text and 18 §1's "interior functions already pay nothing — the
shape C wanted", and is still *partial*: it covers only values that flow into a private function, not
`ViaItem`-style pass-through. It adds guards on exactly the unprovable edges, so it is a patch over shallow guards,
not a fix; the fix (check where a value is projected out of an aggregate, or deepen the exported guard) is a
different, bigger ticket.

## 4. Is "exported" the right discriminator? (59-07)
For the BEAM, yes. `ex/1` has one entry label (`{function, ex, 1, 2}` / `{label,2}`); the local call is
`{call,1,{f,2}}`, the remote call `{call_ext,1,{extfunc,entry,ex,1}}`, and `beam_disasm` lists `{ex,1,2}` in the export
table. Local-only functions are the ones erlc may specialise from call sites. So a guarded-public/unguarded-internal
pair cannot be one function — confirmed, not new. What the probe adds: the optimiser's discriminator is
"are all callers provable", which for int/float is usually true and for a map tag is never (a `Kind` atom is not
tracked). That is why the same scope rule costs ~0 for kind and 14 bytes for tag.

## 5. Neighbouring languages
- **Erlang/Dialyzer** (source): only escaping/exported functions are seeded as entry points with unknown arguments;
  private functions get argument types from callers: `dialyzer_dataflow.erl:2894-2897`
  (`ExportedFunctions = [Fun || ..., dialyzer_callgraph:is_escaping(Fun, Callgraph), ...]`), non-exports dropped from
  the PLT at `dialyzer_analysis_callgraph.erl:146-161`. That is 18 §4's premise, and it shares 18 §4's limit: it
  trusts callers' types, it does not defend.
- **Elixir** (59-08, crude one-line grep over stdlib): type-test guards on 672 of 2905 `def` heads (23%) vs 299 of
  3870 `defp` heads (8%); struct matches 118 vs 27. Authors guard private heads about a third as often, but not
  never; mostly dispatch, not defence. Evidence of practice only.
- **Gleam** 1.19 (executed, 59-09): no runtime check on any function, pub or private; forged `{invoice,1,7}` to
  `outer/1` returns `8`; `outer_int(1.5)` returns `2.5`. The compiler writes abstract format (`.abstr`), not `.erl`.
- **Elm**: *could not be executed here* (59-10: `package.elm-lang.org` returns 403 through the proxy). Not re-probed;
  repo's `wayfinder/research/18-elm-port-validation.md` records a 2026-08-13 run (Elm 0.19.1) that ports are decoded
  at the one door. Elm has no public/private argument-check distinction to compare.
- **C#/F#** (knowledge only): no runtime parameter-type checks on private members; null/range checks are by
  convention on public API. Not probed.

## 6. Recommendation

**Keep the tag test on private functions (reject A), and widen kind/range to private (C), provisionally.**
Reasons: (1) 18 §4's reason for exported-only is false at nested positions, measured not argued (59-02);
(2) the cost the ticket worried about is measured and small: 0 bytes where erlc can prove, 4.5–11 bytes per surviving test where
it cannot (three of 31 corpus modules grow), and those are exactly the edges that are unsound; (3) narrowing converts a crash into silent
type confusion for ~14 bytes. If the owner prefers 18 §4 left literal, B is the honest minimum, but then
the text must say the private tag test exists as nested-position cover and that the kind hole is accepted.
The residual shallow-guard problem (`ViaItem`) is unaffected by any option and wants its own ticket.

## 7. Not decided / not measured
- Narrow variant (A) under `rebar3 eunit` in a scratch copy (only `src test examples` copied): (author's partial copy: 1447 passed, 1 failed from missing corpus dirs). Verifier, whole-repo copy: A passes 1448/1448 and the unpatched baseline passes 1448/1448; widen (C) passes 1446 and fails exactly F24.6 and F37.5, the two that change by design. **No test pins the private tag test.**
  Not run: the widen variant (C) suite (it would fail F24.6 / F37.5 by design), `./bin/verify.sh`, any gate.
- Not measured: per-call cost of `is_integer` on an *unprovable* argument (my loop was provable); bytes on
  arm64 or JIT-emitted native code; cold call sites; compile time (escript boot ~0.5 s swamps it: 59-04 shows
  base/narrow/widen medians within noise).
- Not covered: FFI-declared return values (ETS reads) reaching private functions; gen_server callback heads.
- "Flat in field count" was not isolated: 59-04 mixes 2- and 12-field records (13.7 B average).
- Elm not executed; C#/F# knowledge-only; Elixir survey is a line grep, not a parse.
- Nothing here edits ticket 18, but option C amends 18 §4's scope text and conflicts with ticket 46's Decisions entry ("Emitted always, on exported functions only"); A or B would leave both literal. "The shape C wanted" at 18:617 means 18's own rule C, not this brief's option C.
- The corpus has no private function with a closed record parameter, so 59-03's "0 of 16 private functions carry the tag test" is not negative evidence.

## 8. Probe index
| probe | claim checked | result |
|---|---|---|
| 59-01 | asymmetry still exists at HEAD | yes: private tag test present, private/exported int tests absent/present |
| 59-02 | forged record reaches a private fn via an exported one | yes: nested/list forged tag caught only by private `Inner`; `ViaItem` leaks; `ViaLineQty` returns `5.0` |
| 59-03 | corpus exercises private tag test | no: 0 of 16 private functions in 28 modules |
| 59-04 | +14 bytes tag, +3-5 `is_integer`; patches | 13.7 B/tag; 0 B where provable, 5.0 B where not |
| 59-05 | behaviour under narrow vs widen | table in section 3 |
| 59-06 | call-time cost, 9 runs of 20M | tag 2–3.5 ns/call (noise ~0.7); `is_integer` arm erased by erlc (vacuous) |
| 59-07 | one entry label; local-only elision | confirmed; tag test never elided, `is_integer` elided only if all callers provable |
| 59-08 | Elixir def vs defp guarding | 23% vs 8% of heads guarded (crude) |
| 59-09 | Gleam pub/private checks | none; forged values pass |
| 59-10 | Elm port module via `elm make` | could not run (403); not evidence |
