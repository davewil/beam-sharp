# Brief for ticket 59: one scope for the boundary guards

- Ticket: 59 · [ENG-241](https://linear.app/davewil/issue/ENG-241) · **OPEN, undecided.** This brief is a recommendation. Nothing under `wayfinder/` was edited, no status set, no commit made.
- Date: 2026-10-11 · repo rev `019533d` (master) · `compiler/src` was never edited; the experiments use scratch copies.
- Versions: Erlang/OTP 29 (erts 17.1, compiler 10.0.6), Elixir 1.20.4, Gleam 1.19.1. Elm 0.19.0 is installed but was not exercised (see section 3).
- Probes: `artifacts/59-boundary-guard-scope/probes/` (`README.md` has the one command per probe; every `.out` is a captured run).

## 1. The question, and what gates what

**Gating question (ask this alone):** where may a boundary guard be emitted: exported functions only, or every function that declares a parameter it can test?

Everything else follows from the answer:

- The record tag test on a private function is either a defect (answer "exported only") or correct (answer "every function").
- The int, float and range kind tests are then widened, or confirmed as they are.

Today there are *four* tests, not two. `bs_emit:guard_one/7` (`compiler/src/bs_emit.erl:275`) applies them like this:

| test | scope today | where it is pinned |
|---|---|---|
| record tag (`map_get(Kind)`) | every function | no authority, and **no test pins it** |
| int kind (`is_integer`) | exported only (line 284, `none when Public`) | `boundary_kind_tests:a_private_function_is_not_guarded_test` (F24.6) |
| float kind | exported only | same clause |
| int range (`>= 0`, `=< 255`) | exported only | `boundary_range_tests:a_private_function_carries_no_range_guard_test` (F37.5) |

Ticket 59 names two of the four. A decision made for "both guards" has to cover the float and range halves too, because F37 already inherited the asymmetry.

## 2. Claim ledger

| # | claim (source) | probe | result |
|---|---|---|---|
| 1 | A private `Inner(Order o)` gets the tag test; a private `int` helper gets nothing (46, 59) | `probe_a_asymmetry` | **confirmed** |
| 2 | "A forged record can reach a private function by being passed through an exported one" (59, the 'not a defect' argument) | `probe_b_forged` section 0 | **partly refuted** (verifier correction). refused for a `term`, a `map<atom,term>`, or a `{Kind: ...}`-narrowed value; **confirmed** for an exported parameter of union type, e.g. `public int Entry(Order \| :nothing m)` forwarding to private `Inner(Order o)`: the exported `Entry` carries no guard, so a forged top-level record reaches `Inner`, where today only the private tag test stops it (`function_clause`); without it the result is a silent `9`. Same for `option<Order>` and, for the int rule, `int \| :nothing` into a private `Bump(int n)` (1.5 -> 2.5 today; widening catches it). Independently re-run by the orchestrator: today's behaviour confirmed. See `verification.md` |
| 2b | Same claim, other route: values nested inside a typed exported parameter | `probe_b_forged` sections 1-3 | **confirmed, and wider than claimed.** A wrong-Kind record inside a record field or a `list<Order>` reaches the private function |
| 3 | The private tag test is "18 §4 working" (59) | `probe_b_forged` section 3 | **mostly refuted.** The same forged nested value projected inline, with no function call, already returns a wrong answer under today's emitter. The private test catches it only if the value is handed to a function |
| 4 | "A non-exported function has the test elided entirely" (18 §1, cited in 59) | `neighbours/probe_f_erlang_entry`, `probe_c_cost` | **partly.** erlc drops a local guard only when every caller's argument type is provable. One unprovable caller keeps it |
| 5 | One entry label serves local and remote calls (18 §1) | `neighbours/probe_f_erlang_entry` | **confirmed** |
| 6 | Tag test costs +14 bytes, flat in field count (26a) | `probe_c_cost` | **confirmed in kind, 12 here.** 12 Code bytes at 3 fields and at 8 fields (OTP 29) |
| 7 | `is_integer` costs +3-5 bytes, time below resolution (18) | `probe_c_cost` | **partly.** 0 bytes when erlc proves the argument, 5 bytes when it cannot. Time is inside this harness's noise (about ±0.6 ns/call), not at the ticket's ±0.09 |
| 8 | The tag test costs "nothing measurable" in time (26 §1) | `probe_c_cost` | **not comparable.** 26 §1's figure is an exported-projection comparison (7.04 vs 8.78 ns), not a private-call cost. On a 2-function toy the tag test costs roughly 2-5 ns/call (author 2.3-3.8; verifier 2.0-5.4, load-dependent) |
| 9 | Elided-by-narrowing breaks nothing already built (implied) | `probe_i_suite` | **confirmed:** zero tests fail when the private tag test is dropped |

## 3. Neighbours

**Erlang.** The BEAM compiler itself uses *exported vs local* as the discriminator for exactly this question.

- `compiler-10.0.6/src/beam_ssa_type.erl:122-123`: "The argument types of all exported functions start out as 'any', whereas local functions start at 'none'."
- `beam_ssa_type.erl:444-449`: for a local function "we're guaranteed to have visited every call site... the parameter types are at least as narrow as the join of all argument types."
- `beam_ssa_type.erl:451` and `745-746`: "We can't infer the parameter types of exported functions... they can receive anything as part of an external call."

The probe shows both outcomes: `loc_known` (only provable callers) loses its `is_integer`; `loc_unknown` keeps it. It also shows one entry label. The beam's `ExpT` maps `pub/1 -> entry label 2`, and a *local* call to it in the same module is `{call_only,1,{f,2}}`.

**Elixir.** No Elixir source ships in this environment (only `ebin`), so the citation is the probe `neighbours/probe_g_elixir.sh`.

- A guard on a `defp` runs: `pub(1.5)` with an unguarded exported `pub` calling a guarded `defp` raises `FunctionClauseError` in `priv/1`.
- The control (`defp` without the guard) silently returns `2.5`.
- A `defp` head pattern `%{kind: :order}` also rejects a forged `kind: :invoice`.
- Elixir does not drop a user-written guard on `defp` as a rule (erlc can drop one when every caller is provable). Guards are semantics there, not an optimisation.

**Gleam.** Source is not available; the citation is the real compiler (`gleam build --target erlang`, output in `neighbours/probe_h_gleam.out`).

- Gleam 1.19 emits abstract code, not `.erl`, so the probe pretty-prints it.
- `pub fn entry(b: Batch)` compiles to `entry(B) -> inner(element(3, B)).` and `pub fn pub_int(n: Int)` to `pub_int(N) -> priv_int(N).` with **no guards on any function, exported or private**.
- Control: a user `case n { x if x > 0 -> ...}` is counted as one guard.
- Gleam's stance is "total static typing, no runtime checks", the position 18 rejected as claim A. It gives no precedent for scoping a runtime guard.

**Elm.** Elm compiles to JavaScript. It has no BEAM function and no private/exported entry label. Its one defended door is the port decoder, as recorded in `wayfinder/research/18-elm-port-validation.md`. I did not re-run it. It cannot inform the *scope between functions* question.

## 4. Measurements

All from `probe_c_cost.out` (OTP 29, JIT; a public function calling a private one, with the guard under test only in the private function; 15 interleaved runs of 1e7 calls). `timer:tc` resolves 1 µs per run, which is 0.0001 ns/call and so is not the limit. Run-to-run noise is. A base-versus-base control is printed next to each pair.

**Bytes (the Code chunk is exact, since the variants differ only by the guard):**

| private-function guard | Code bytes | stripped `.beam` |
|---|---|---|
| record tag, 3 fields | 12 | 8 |
| record tag, 8 fields | 12 | 9 |
| `is_integer`, erlc can prove the argument | 0 | 0 |
| `is_integer`, erlc cannot prove it (element of a `list<int>`) | 5 | 0 |

The debug_info chunk carries the abstract code, so unstripped file size is misleading. The 3-field `.beam` is 28 bytes smaller without the tag test, but that is mostly debug_info.

**Time (ns per call, median / min over 15 runs):**

| case | today | variant | noise (base re-run) |
|---|---|---|---|
| record, 3 fields | 18.63 / 17.74 | no private tag: 14.81 / 13.64 | 19.20 / 18.12 |
| record, 8 fields | 16.86 / 15.68 | no private tag: 14.61 / 13.28 | 16.82 / 16.12 |
| int, provable | 11.25 / 10.25 | widened: 11.01 / 10.44 | 11.77 / 10.17 |
| int, unprovable, `Sum` of 8 elements | 52.06 / 50.00 | widened: 53.38 / 50.36 | 52.85 / 48.94 |

The tag test is a real `map_get` and costs 2-4 ns per call. The int test is lost in the noise whether or not erlc elides it.

**Corpus (`probe_e_corpus`):** in the 24 modules of `compiler/examples` that compile standalone (the `exemplars` directory does not), 128 functions of which 45 are private, there are **0** private tag tests (the positive control on `src/Scope` sees 1). Widening would add a kind test to **9** private functions (erlc would drop some).

**Tests (`probe_i_suite`):**

- Narrowing (no private tag test): all ten comparable test modules green, nothing fails.
- Widening: exactly two tests fail, F24.6 and F37.5, both of which assert the opposite.
- Five other modules (`validate_as`, `float`, `intervals`, `clause_block`, `body_check`) fail on *base* in this scratch layout because there is no rebar3 escript, so they are excluded.

## 5. The finding the ticket did not expect

The type system **does** reject the route 59 worried about. Handing an unchecked value to a record-typed private function is refused:

```
src/Fwd/fwd.bs:6:13: error: Entry hands Inner an argument it does not accept
  argument 1 is not covered by Inner's declared type:
    term
src/Narrow/narrow.bs:6:19: error: Entry hands Inner an argument it does not accept
  argument 1 is not covered by Inner's declared type:
    { Kind: :'Narrow.Order' }
```

(`Fwd2` with `map<atom, term>` and `Fwd3` with `Order | map<atom, term>` are refused the same way.) Even `Entry(Order o)` over a `term` narrows only to `{Kind: tag}`, not to `Order`.

The forged value that *does* arrive comes from **inside** a typed exported parameter, which is checked one level deep only (18 §2 refuses deeper):

```
// Nest: Entry(Batch b) -> Inner(b.First), Inner private (Order o)
                       today                  no private tag test
wrong Kind, has Total: crashed: function_clause     9           <- silent
wrong Kind, no Total:  crashed: function_clause     crashed: badkey 'Total'

// Lst: Entry(list<Order>) folds private Inner over elements
2nd element wrong Kind, has Total:  function_clause     14      <- silent
// Direct: same forged nested value, NO private function, projected inline
today: 9   (silent)
```

The same hole exists for ints, with no record involved:

```
ScopeI.Sum(list<int>) -> private Bump(int n):   Sum [1, 1.5]
today: 4.5      widened: function_clause
ScopeJ.Sum (no helper, inline h + 1):           Sum [1, 1.5]
today: 4.5      widened: 4.5
```

So the private tag test is not "18 §4 working". It is an **accident of call shape**: it fires only when a nested value happens to be handed to a function, and it is silent when the same value is read inline. This holds identically for the `int` rule. 18's one-sentence guarantee ("a foreign term that breaks your types will crash, never silently") is **already false for the contents of an exported parameter** under both scopes, and a function published `list<int> -> int` returns `4.5` today. That is a separate decision, and it is not this ticket's to make. It is worth its own ticket (see section 7).

## 6. Options, as programs and compiler deltas

### Option 1. Exported only, for every guard (18 §4 as written)

```csharp
record Order { Id: int, Total: int }
record Batch { Name: int, First: Order }

public int Entry(Batch b)      // tag test on Batch only
Entry(b) -> Inner(b.First)

int Inner(Order o)             // no tag test; was one `map_get`, 12 bytes, ~3 ns
Inner(o) -> o.Total
```

- **Compiles under this answer, and also under today's.** Neither answer changes what bsc accepts.
- **Delta:** one line in `guard_one`. The probe patch is `case constrains_kind(Pat) orelse not Public of` (`probes/variants.patch`). The `Public` flag is already threaded through. The comment at `bs_emit.erl:330-333` ("that asymmetry is deliberate") is rewritten, F3.9 and F37.5 lose their "asymmetry" paragraphs, and one test is added: a private record function carries no `map_get`.
- **Evidence:** 12 bytes and 2.3-3.8 ns per private record call saved; no corpus module changes (0 private tag tests); zero existing tests fail. Forged nested record: `9` instead of `function_clause`, equal to what inline projection already gives.
- **Strongest counterargument:** it turns a crash into a silent wrong answer for the `Batch.First` / `list<Order>` cases that today crash. The ticket's own principle ("too narrow is a silent hole") applies, and probe 2's `14` is the number to quote.

### Option 2. Every function, for every guard (widen)

```csharp
public int Sum(list<int> xs)
Sum([])          -> 0
Sum([h, ..rest]) -> Bump(h) + Sum(rest)

int Bump(int n)                // gains is_integer (and float/range for those types)
Bump(n) -> n + 1               // Sum [1, 1.5]: 4.5 today, function_clause widened
```

- **Delta:** delete `when Public` at `bs_emit.erl:284`; drop the `Public` parameter from `function/2`, `clause/4`, `boundary_guards/6`, `guard_one/7`. Rewrite F24.6 and F37.5 (they assert the opposite), the F24 and F37 prose, 18 §4's "exported" and §1's "interior functions already pay nothing". One scratch-compiler line does the guard half (`probes/variants.patch`).
- **Evidence:** 0 bytes where erlc proves the argument, 5 where it cannot; time inside noise; 9 private functions in the corpus gain a test. It does **not** close the hole: `ScopeJ.Sum` with no helper still returns `4.5` under widening.
- **Strongest counterargument:** it reverses three decided pieces (18 §4, F24 §3, F37.5) and two pinned tests for a defence that fails when the author inlines the helper. It also puts the record tag, which erlc cannot elide, on every private record call: 12 bytes and ~3 ns each.

### Option 3. Keep the split, and write down why

- **Program:** unchanged.
- **Delta:** none in code; an 18 §4 amendment saying "the record tag is scoped to every function; kind and range to exported".
- **Evidence:** this is today's behaviour and breaks nothing.
- **Strongest counterargument:** there is no principled sentence for it. The nested-forgery hole is identical for `Order` (probe `Nest`/`Lst`) and for `int` (probe `ScopeI`), so "tag differs from kind" cannot be argued from provenance. The only honest difference is that erlc can elide the kind test and cannot elide the tag, which is a cost argument and not a safety one. I would not write that sentence.

## 7. Recommendation

**Gating question, asked alone: may a private function's only defence against a forged value be a guard on the exported function above it?** Today that is false for union-typed exported parameters (they carry no guard), so the answer decides whether Option 1 is safe to take on its own.

**Recommend Option 3 for now (keep the split, write down why), and raise one ticket that makes Option 1 safe.** This replaces the author's first recommendation (Option 1 alone), which the independent verifier showed rests on a false sentence:

- "a private function inherits its callers' proofs" does not hold for an exported parameter of union type containing a record or an `int` (probes U1, U5, U6 in `verification.md`). Dropping the private tag test alone turns `function_clause` into a silent wrong answer (`9`) on a top-level argument of a common shape (`option<Order>`).
- Option 1 is still what 18 §4 says and what erlc's own discriminator does (`beam_ssa_type.erl:122-123, 444-451`), so it becomes right once exported union parameters are guarded. A top-level union membership test is O(1) and fits 18 §2.
- So: the new ticket is "exported parameters of union type, and the contents of exported container parameters, are unchecked" (covers `Order | :nothing`, `int | :nothing`, `list<int>` returning `4.5`). After it lands, take Option 1.
- Option 2 (guard everything everywhere) is the cheap stopgap if David wants "never silently" binding now. It reverses 18 §4, F24 §3 and F37.5.

**What would change this:** if a decision already says exported union parameters are deliberately unguarded (not found in a grep of 18 and 26; not examined in depth), Option 1 stands as the author first wrote it.

## 8. Limitations

- The ticket's ±0.09 ns/call resolution and +14-byte figures are from OTP 28.5 on arm64; this run is OTP 29 on this VM. Byte deltas are exact (Code chunk); time deltas are medians of 15 interleaved runs with a noise floor of about ±0.6 ns. A 2-4 ns tag effect is above it, an int effect is not.
- Timing used 2-function toys. Cost on a cold or megamorphic call site is not measured.
- Source for Elixir and Gleam was not available; those citations are probes only. Elm was not re-probed.
- `probe_i_suite` could not run the full suite (no rebar3 escript; five modules fail on base). Only ten base-green modules were compared.
- `Public` widening in the scratch compiler also widens float and range because they share `guard_one`; that is the real change Option 2 means.
- The generated `out*/`, `corpus_*/` and `ctl_*/` directories under `probes/` are run output; the permission check denied me deleting them. They can be removed by hand.


## Verification note

Independently verified: `verification.md` (VERIFIED WITH CORRECTIONS). Corrections applied above: ledger rows 2, 8, the Elixir sentence, `guard_one/7`, and the recommendation. Remaining unreconciled: the `beam_ssa_type.erl` 451 / 745-746 quote joins two comments (read the source, not the quote); the probe `out*/corpus_*/ctl_*` directories are generated and git-ignored only for .beam.
