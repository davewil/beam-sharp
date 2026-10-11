# 59 — Boundary guard scope: does a private function get a guard? Decision brief

Ticket [59](../wayfinder/issues/59-boundary-guard-scope-asymmetry.md) · ENG-241 · stays OPEN for David.
Measured at HEAD `a5af573` (2026-10-10), OTP 28 / erts 16.4, x86_64 Xeon 2.8 GHz, 4 shared cores.
Every number below is from `artifacts/probes/59/output.txt` (rerun with `artifacts/probes/59/run.sh`); none is copied from a ticket.

## 1. The ticket's premises, re-checked against today's bsc

**The asymmetry still holds, and it grew.** `bs_emit.erl:275-290` (`guard_one/7`): the record tag test is
unconditional; `none when Public ->` (line 284) gates the int test **and** the `float` test F51 added later.
Nothing since 2026-08-23 changed it, and no ticket or feature settles it (`grep` over `wayfinder/` and
`compiler/features/` finds only 58, F24 and F37 pointing at 59; `F59-open-field-sets` is an unrelated feature).
Emitted today (probe `p1_shape`):

```
'PubRec'(O)  when map_get('Kind', O) =:= 'Guard.Order' -> ...     'PrivRec'(O) when map_get('Kind', O) =:= 'Guard.Order' -> ...
'PubInt'(N)  when is_integer(N) -> N + 1.                          'PrivInt'(N) -> N + 1.
'PubOct'(N)  when is_integer(N) andalso N >= 0 andalso N =< 255    'PrivOct'(N) -> N + 1.
```

Three more facts the ticket does not have:

- **`CONTEXT.md:398` already defines the term the other way**: *"Boundary guard: a guard the compiler emits on an
  exported function's parameter."* The glossary sides with "exported"; only the tag test disagrees with it.
- **No test pins the private tag test.** Deleting it (patch `exported-only`, 2 changed lines) fails no existing test
  (eunit: same single failure as the unpatched copy, `every_aoc_program_still_compiles_test`, which fails only because
  my scratch copy of `compiler/` has no `aoc/`). Adding int guards to privates fails the pins F24.6 / F37.5.
  The corpus (28 example modules) contains **zero** private functions with a record parameter, so on it the choice changes nothing.
- **Ticket claim "18's cost section measured elision *entirely*" is half right.** `18a_guard_cost.md:335-352` showed
  `is_integer` deleted from a local function whose callers prove integers, and kept when they do not. Reproduced: the private
  `Inc(int)` carries no `is_integer` even when I force the emitter to write one (`guard-all`), because `beam_ssa_type`
  sees every caller. **The tag test is never deleted**: `Step(Order)` keeps `map_get 'Kind'` + `is_eq_exact` although its
  only caller tests the same tag one instruction earlier (`output.txt` §3, §4). erlc tracks integer types, not map-key values.

**The ticket's "it is not a defect" argument misreads 18 §4.** The sentence *"a value handed to another function counts as
unchecked, and is guarded"* (`18-boundary-defence.md`, §4 "The analysis is function-local") is about the **exported**
function deciding whether *it* needs a guard on a parameter it forwards (its example: `Describe(int id)` forwards to `Format`,
so `Describe` is guarded). It puts the guard on the caller, not the callee. It is no argument for a private-callee guard.

**Can a forged value reach a private function at all?** Yes, but not the way the ticket imagines (probes `p2_forge`, `p3_leak`):

| route into the private `Cents(Order o)` | reaches it unchecked? |
|---|---|
| exported whole parameter `Order o` | no, the exported head already tested the tag |
| `term` narrowed by naming the record in a head | **refused by the checker**: it types `o` as `{ Kind: :'Forge.Order' }`, "not covered by Cents's declared type" |
| `term` through `ValidateAs<Order>` | no, validator checks every field and refuses an Invoice (returns `-1`) |
| `Order \| Invoice` union, head `Order o` | no, the head matches `#{'Kind' := 'Forge.Order'}` |
| **record field** `Cents(w.Inner)` | **yes**: the boundary tests `Wrapper`'s tag, not `Inner`'s |
| **list element** `[o, ..rest]` → `Cents(o)` | **yes**: 46 §4 decided collections are not guarded |
| **tuple element** (int case) | **yes** |

So the ticket's second claim is real but narrow: three projection routes. And the control that decides which side is right:
**the same forged value passes through with no private function involved** (`DirectField`, `DirectList`: the body projects
`i.Total` itself). The private tag test is not a defence of the route; it is an accident of how the author factored the code.

## 2. The gating question (one, alone)

**When an exported function hands a private function a value it took *out of* its own parameter (a record field, a tuple
element, a list element), does the private function owe that value a test?** The scope of both guards follows from the answer.
It is not "private vs exported": the same projection read inline in the exported body is equally unchecked.

## 3. The same module under three answers

```csharp
module Forge
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }      // identical fields, different tag
record Wrapper { Inner: Order }
record Counter { N: int }

int Cents(Order o)                          // private
Cents(o) -> o.Total * 100
int Bump(int n)                             // private
Bump(n) -> n + 1

public int ViaField(Wrapper w)    ViaField(w) -> Cents(w.Inner)
public int ViaList(list<Order> os)  ViaList([o, ..rest]) -> Cents(o)
public int CountField(Counter c)  CountField(c) -> Bump(c.N)
```
Raw Erlang caller, forged inputs (`output.txt` §2, §3; the Invoice has the same field names as an Order):

| call | today (`base`) | **A** guard all | **B** exported only | **C** exported only + boundary reaches record fields |
|---|---|---|---|---|
| `ViaField(Wrapper{Inner = Invoice})` | `function_clause` | `function_clause` | **`700`** | `function_clause` (at `ViaField`) |
| `DirectField(Wrapper{Inner = Invoice})` (no helper) | **`700`** | **`700`** | **`700`** | `function_clause` |
| `ViaList([Invoice])` | `function_clause` | `function_clause` | **`700`** | **`700`** |
| `CountField(Counter{N = 1.5})` | **`2.5`** | `function_clause` | **`2.5`** | `function_clause` |
| `DirectField(Counter{N = 1.5})` | **`2.5`** | **`2.5`** | **`2.5`** | `function_clause` |
| `BumpPub(1.5)` (exported control) | `function_clause` | same | same | same |

Bold = the silent outcome 3 of ticket 18 (a wrong term returns a value).

### A. Guard every function, private included (tag, `is_integer`, `is_float`, range)
Delta: `bs_emit.erl guard_one/7`, delete the `none when Public` gate and the second `none ->` clause: 8 changed lines
(`patches/guard-all.patch`). Emitted: `'Cents'(O) when map_get('Kind', O) =:= 'Forge.Order'` as today, plus `'Bump'(N) when is_integer(N)`.
- Evidence: closes `ViaField`/`ViaList`/`CountField` rows; leaves both `Direct*` rows open (table). Costs below.
- Breaks two pinned decisions: `boundary_kind_tests:a_private_function_is_not_guarded_test` (F24.6) and the range pin F37.5; both
  rest on 18 §4 and 46 ("dead weight"). CONTEXT.md:398 would need to say "any function".
- **Strongest counterargument for A**: too narrow is a silent hole, too wide is measurable and loud (the ticket's own
  rule), and the loud half here is small: 0 bytes and 0 ns for ints, ~13 bytes and ~3 ns for a tag.

### B. Exported only, for every guard — one rule, stated once
Delta: `guard_one/7`, one clause `{ok, _} when not Public -> {Pat, []}` (`patches/exported-only.patch`, 2 lines).
Emitted: `'Cents'(O) -> map_get('Total', O) * 100.`
- Evidence: matches 18 §4, 46, F24 §2, CONTEXT.md:398 and what hand-written OTP does (`lists.erl:477-481`: exported `seq/2`
  guards `is_integer`, its private `seq_loop/3` guards nothing). Removes the one asymmetry. Fails no existing test.
- **Regression it causes today**: `ViaField(Wrapper{Inner = Invoice})` and `ViaList([Invoice])` go from `function_clause`
  to a silent `700`. It makes the *accidental* coverage disappear without replacing it.
- **Strongest counterargument against B**: it ships a measurable loss of safety to save ~13 bytes, and on a rule ("callers are
  checked") whose premise the field/list/tuple routes falsify. The guarantee in `LANGUAGE.md` (§ "A declared type at an
  entry is checked"): *"never silently"* is then false for those routes, as it already is for `DirectField`.

### C. B, plus the exported boundary reaches one record field down (46 §4, decided, unbuilt)
46 §4 already decided: *"A refined `int` is guarded wherever a fixed number of projections reaches it — a whole parameter, a
tuple element, a record field. It is not guarded through a collection."* C builds that for the tag and kind tests so the
private test can go without a loss. Prototype `patches/field-depth.patch`, ~40 changed lines (`field_tests/4`, `field_test/4`
beside `guard_one/7`): for an exported record parameter, each field typed as a closed record gets its tag tested, each int-only
field gets `is_integer`. Emitted: `'ViaField'(W) when map_get('Kind', W) =:= 'Forge.Wrapper' andalso map_get('Kind', map_get('Inner', W)) =:= 'Forge.Order'`;
`'ViaField'(C) when ... andalso is_integer(map_get('N', C))`.
- Evidence: closes both `Direct*` field rows that A leaves open, at the boundary, with a message at the exported function.
  List/tuple elements stay open (tuple is cheap to add; lists are 46 §4's O(n) refusal).
- **Collides with a pin**: F3.9 *"an exported function taking a record emits the tag test and nothing more"*
  (`compiler/features/F3-records.md:252-258`) — prototype fails `records_tests:an_exported_record_parameter_gets_one_tag_test_test`, plus
  `bindings_tests:a_binding_reads_a_projection_once_test` and `to_json_tests:a_field_of_the_wrong_type_is_not_published_test`
  (the last now fails earlier, at the boundary). 46 (2026-08-23) post-dates F3.9 (2026-08-14); I have not resolved which wins.
- Cost on the corpus (`output.txt` §7): int tests on exported functions 71 → 90 (+19) across the 28 modules; tag tests unchanged.
- **Strongest counterargument against C**: it is the biggest change (a feature, not a one-line fix), it taxes every
  exported record with int fields (+19 tests in a corpus whose records are small), and it answers a different ticket's question (46 §4's depth).

## 4. Cost, measured (probes `p4_cost`, `run.sh` §4)

Bytes (`Many` module, K private record functions + K private int functions; `Code` chunk):

| K / record fields | base | B exported-only | A guard-all |
|---|---|---|---|
| 1 / 3 | 159 | 147 (**−12**) | 159 |
| 10 / 3 | 1119 | 987 (−132 = 13.2 each) | 1119 |
| 10 / 8 | 1119 | 987 (same: **flat in field count**) | 1119 |
| 40 / 3 | 4287 | 3735 (−552 = 13.8 each) | 4287 |

So the private tag test costs **12–14 bytes of Code** (ticket 26a said +14: confirmed). Guarding private ints costs **0 bytes**
(A equals base: erlc deleted every `is_integer` it could prove dead). Stripped `.beam`: ~6 bytes per tag test. The loaded file with
`debug_info` grows ~20 bytes per test, because the abstract-code chunk carries it.

Time (`tbench.erl`: 25 runs × 2M calls, round-robin across variants, 8 private calls per entry; `base1`/`base2` are the *same* beam
loaded under two names = the noise floor; load average ≈ 5-7 on 4 cores during the final run):

| ns per entry (8 calls), min / median | base1 | base2 | B exported-only | A guard-all |
|---|---|---|---|---|
| private record fn | 73.4 / 76.7 | 73.7 / 76.5 | **47.7 / 49.8** | 73.5 / 75.5 |
| same, erlc `{inline,[Step]}` | 27.1 / 28.3 | 26.9 / 27.7 | 27.0 / 27.9 | 26.9 / 28.4 |
| private int fn | 41.2 / 42.8 | 41.0 / 43.2 | 41.1 / 42.2 | 41.0 / 42.2 |
| exported twin (guard present in all four) | 70.2 / 74.2 | 70.5 / 74.1 | 68.6 / 71.4 | 71.2 / 73.5 |

Noise floor within a build: the two identical copies agree within 0.4 ns (min) and 0.2 ns (median) on the private-record row, MAD ≤ 2.3 ns.
**Between builds of identical code it is larger**: the exported twin, whose code is the same in all four, differs by up to 5.3 ns
(65.1 vs 70.4 in its `{inline}` column) from code placement alone; read that as the layout floor.
Resolved difference: **~26 ns per 8 tag tests ≈ 3.2 ns per private record call** (5× the layout floor; it reproduced to 0.3 ns in an earlier identical run). Not resolved: any int
cost (A = base within 0.2 ns). Inlining deletes the guard along with the call (the row equals the no-call `Run8Direct`, 27.0 min).
A first run at load ≈ 17 had MAD ≈ 20 ns on medians and could resolve nothing; I discarded it.
Not re-measured: exported-guard cost (settled by 18 §5), JIT native size, a cold or megamorphic call site.

## 5. How neighbours treat private vs exported (probes `survey/`)

- **Erlang** (`survey/erlang`): a `-spec` is not a run-time check on either: `pub(1.5)=2.5`, `via_priv(1.5)=2.5`. OTP's own code
  checks at the exported entry and trusts the interior (`lists.erl:477-481` above). Census reproduces 18's figures exactly
  (4193 exported functions, 7606 positions, 83.3% bare) and adds: private positions are **89.4% bare** (23805 of 26642).
- **Elixir 1.20.4** (source not installed; binary probed): no automatic guards anywhere. A guard or `%Order{}` head written by the
  author works identically on `def` and `defp` (`run_inc(1.5)` and `struct_via(%{total: 7})` both raise `function_clause`). Its type
  checker infers *through* private functions into the exported signature (`struct_via/1` gets the closed Order struct from the
  `defp`'s pattern), the opposite of 18 §4's function-local rule; `ExCk` lists only exported functions.
- **Gleam 1.19.1**: no guards. `-spec` is emitted for private functions too; `pub_cents({other,1,7})` and `via_priv({other,1,7})`
  both return `700`; `opaque` is a compile-time constructor hiding only (`money_cents({whatever,3})` returns `3`).
- **Elm 0.19.3**: **UNMEASURED here**, `elm make` cannot fetch `package.elm-lang.org`. 18's recorded finding (research file
  `18-elm-port-validation.md`, not re-run) is that Elm checks at the port door and has no private/exported distinction at run time.

None of the four has a rule "private functions are guarded"; one (Elixir) lets the author write it, none automates it.

## 6. Recommendation

**One rule, exported only, for every guard (B), but do not delete the private tag test before the boundary reaches record fields (C's
`field_tests`)**. Reason: the evidence shows the private test is not what the ticket takes it for; it catches the field and list routes
only when the author happened to factor a helper, while `DirectField` is silent under the status quo, so A buys an accident at the
price of contradicting 18 §4, 46, F24 and CONTEXT.md. B's regression is real today, so the order is: raise the 46 §4 depth as its
own feature (it needs a ruling on F3.9's "tag test and nothing more"), then delete the private tag test in the same commit that
makes `ViaField` refuse at the boundary. Collection elements remain a named limit of *"never silently"* under every option; say so
in `LANGUAGE.md` rather than let one private function appear to cover it.

## 7. Unmeasured

Elm (blocked, see §5); JIT code size; cold/megamorphic sites; Apple Silicon numbers; the cost of C on a real record-heavy program
(corpus has no private record function and few record fields); list-element depth (46 §4 refuses it, never prototyped);
whether 46 §4 or F3.9 prevails on the exact-field-set tension; dialyzer behaviour of the extra guards (not run).
`field-depth` also tests every int field of an exported record, wider than 46 §4's *refined*-int wording; I did not narrow it.

## 8. Probes and how to rerun

`bash artifacts/probes/59/run.sh > artifacts/probes/59/output.txt 2>&1` (≈45 min; `TIMING=0` skips §4b, `TESTS=0` skips eunit).
It copies `compiler/` four times into a scratch dir, applies `patches/{exported-only,guard-all,field-depth}.patch`, builds each with
`rebar3 escriptize`, and checks the rebuilt unpatched compiler emits byte-identical `.abstr` to the repo's built `bsc`.

| dir | what | control |
|---|---|---|
| `p1_shape` | which functions carry which guard, 4 compilers | exported `Pub*` beside private `Priv*` |
| `p2_forge`, `drive_forge.erl` | forged Invoice / bare map into field, list, union, term routes | valid inputs; wrong `Wrapper` tag at the exported guard; `Direct*` (no helper) |
| `p3_leak`, `drive_leak.erl` | the same for `float` into `int` (field, tuple, list) | `BumpPub`, `Direct*` |
| `p4_cost`, `survey/*`, `corpus.sh`, `tests.sh` | bytes, timing (+ `{inline}`), OTP/Gleam/Elixir/Elm, corpus counts, eunit + `check-boundary-kind/range.sh` per compiler | `base1` vs `base2`; exported twin |

A probe bug to disclose: my first `Forge` used `w.Inner.Total`, which B# does not parse (chained projection); I rewrote the control
as `DirectField({ Inner: i }) -> i.Total * 100` and reran everything. The first bytes script used `beam_lib:strip/1` on a path, which
rewrites the file in place; I switched it to a binary and reran.
