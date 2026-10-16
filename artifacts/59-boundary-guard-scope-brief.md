# Decision brief — ticket 59: the boundary guard applies two rules with different scopes

**Linear**: [ENG-241](https://linear.app/davewil/issue/ENG-241) · **Ticket file**: `wayfinder/issues/59-boundary-guard-scope-asymmetry.md`
**State**: OPEN. This brief resolves nothing.
**Prepared**: 2026-10-16 by a scheduled run. **Independent verification**: `artifacts/verification/59-verifier.md`.

## The question, as a program

```csharp
module G59
record Order { Id: int, Total: int }
type Byte = int where value >= 0 and value <= 255

public int SumAll(list<Order> os)          // the boundary tests nothing about the elements
SumAll([o, ..t]) -> Inner(o) + SumAll(t)
int Inner(Order o)                         // PRIVATE: gets the record tag test today
Inner(o) -> o.Total

public int SumB(list<Byte> bs)
SumB([b, ..t]) -> Priv(b) + SumB(t)
int Priv(Byte n)                           // PRIVATE: gets no kind/range test today
Priv(n) -> n + 1
```

Emitted today (`probes/59/show.sh out/G59.abstr`):

```erlang
'Inner'(O) when map_get('Kind', O) =:= 'G59.Order' -> map_get('Total', O).   % private, tag test
'Priv'(N) -> N + 1.                                                          % private, nothing
```

The ticket asks whether the private tag test is a defect against 18 §4, or 18 §4's "exported" is too narrow.

## Sub-decisions

1. Scope of the **record tag test**: exported only, or every function?
2. Scope of the **int kind/range test** (F24, F37): exported only, or every function?
3. Is "exported" the right discriminator, or is it "the value might have come from outside"? (Ticket's §2.)
4. Is a stated cost bound enough to settle a widening? (Ticket's §3.)

## Findings (all measured; `probes/59/behave.sh`, `cost.sh`)

**Forged values do reach private functions, through containers the boundary does not walk.** `guard_one` tests only a
top-level parameter that is a *single closed record* or an *int*; `list<Order>` and `list<Byte>` elements are never tested at the boundary.

| call | unpatched | C (tag test exported-only) | D (int/float guards on private too) |
|---|---|---|---|
| `SumAll([forged-tag map])` | `function_clause` | **`99` (silent)** | `function_clause` |
| `SumAll([map with no Kind])` | `function_clause` | **`5` (silent)** | `function_clause` |
| `SumB([300])` (outside `Byte`) | **`301` (silent)** | **`301`** | `function_clause` |
| `SumB([2.5])` | **`3.5` (silent)** | **`3.5`** | `function_clause` |
| `SumC([300])` (nested element used directly, no private call) | **`301`** | **`301`** | **`301`** |

Three consequences:

- The ticket's claim that for a private function "site 1 has already rejected a wrong tag and the test is dead weight" is
  **false for container elements**: removing the private tag test (C) turns `function_clause` into a silent wrong answer (`99`).
  The ticket's *"it is not a defect"* argument is right, and measured.
- The int test has the **mirror hole today**: `SumB([300])` returns `301` and `SumB([2.5])` returns `3.5` in the shipped compiler.
  Ticket 18 §1 states guarantee C as *"a wrong term from outside will crash — not always at the call site, but never silently"*;
  the shipped compiler already breaks it for ints through a list.
- Widening to private (D) closes `SumB` but not `SumC`. **The private-function scope is a patch over the real gap: a container
  parameter's elements are unguarded at the boundary.** Which scope is chosen changes which symptom shows, not whether the hole exists.

Cost (`cost_result.txt`, `cost_result_run2.txt`; two private functions per loop, 20M iterations, min of 9, OTP 28.0, x86-64 JIT):

| variant | `Code` chunk | record loop (2 tag tests/iter) | int loop |
|---|---|---|---|
| unpatched (two builds = noise floor) | 360 / 360 B | 11.20 / 11.25 / 11.00 / 11.12 ns | 8.88 / 8.77 / 8.85 / 8.82 ns |
| C: tag test exported-only | 324 B (−36) | 8.98 / 9.07 ns (≈ −2.1) | 8.83 / 8.87 |
| D: int/float guards on private too | 370 B (+10, +2.8%) | 12.16 / 12.29 ns (≈ +1.1; D also guards the loop's two plain `int` params) | 8.95 / 9.07 (≈ +0.1–0.2, at the noise floor) |

The ticket's own bound (+14 bytes tag, +3–5 bytes `is_integer`) is consistent with these.

## Survey

- **Gleam** emits no run-time guard on a public function either way. Its emitted Erlang for `pub fn shop_new(a: Int)` is
  `-spec shop_new(integer()) -> integer(). shop_new(A) -> 'Shop':'New'(A).` (`probes/62/p2_gleam_emitted.erl.txt:14-16`,
  from `gleam build` 1.12.0): Gleam's position is ticket 18's option A, "types are documentation at the Erlang boundary".
- **Erlang/Elixir**: `-spec`/`@spec` are never enforced at run time; a guard is written by hand. (Language fact, no probe needed.)
- **B# ticket 18 §1** (`wayfinder/issues/18-boundary-defence.md:491-518`) chose guarantee C deliberately *against* Gleam's position; this brief only measures C's coverage.

## Options

### Option 1 — scope both to exported (narrow the tag test; patch C)

`guard_one`: `constrains_kind(Pat) orelse not Public` skips the tag test on private functions (2 lines,
`artifacts/patches/59-C-private-tag-test-removed.diff`). One sentence in 18 §4 would then hold for both guards.
Evidence: −36 bytes, ≈ −2.1 ns per iteration of a loop making two tag tests; opens `SumAll([forged]) → 99`.

*Strongest counterargument*: the measured silent `99`/`5`. It trades a proven guard for ≈ 1 ns per private call, which the ticket's own
asymmetry rule ("too narrow is a silent hole, too wide is measurable and loud") says to avoid.

### Option 2 — keep the asymmetry and write the reason down

No code. State once: *the tag test is unconditional because a record can arrive nested in a container the boundary does not walk;
the kind/range test is exported-only because it is cheap to lose and 18 §4 says so.* Measured cost of the status quo: nothing new.

*Strongest counterargument*: it documents `SumB([300]) → 301`. The shipped int guard is exactly as leaky as the tag guard would be
without the private test, so the written reason would be "we guard the leaky route for records and not for ints", which is a
cost-driven line, not a principled one.

### Option 3 — scope both to every function (widen the int/float guards; patch D)

`guard_one` stops consulting `Public` for ints/floats. Patch `artifacts/patches/59-D-private-int-guard-added.diff` (net −2 lines).
Evidence: closes `SumB`, +10 bytes on a two-private-function module, ≈ +1.1 ns on a loop whose two `int` params gained
`is_integer`, ≈ +0.1 ns on the int loop (at the noise floor; do not quote as a cost).

*Strongest counterargument*: ticket 18 §1 priced "interior functions pay nothing" as *"the shape C wanted anyway"*, and D makes
every private `int` parameter in a hot loop pay (≈ +10% in the record-loop measurement above where it added two tests);
and `SumC` shows it still does not deliver "never silently", so it spends the cost on a partial fix.

## Recommendation

**Option 2 now, plus a new ticket on the cause: elements of a container parameter are unguarded at the boundary.**
Measured, the tag test earns its place on private functions (C produces silent wrong answers), so the ticket's "defect" reading
is refuted. Widening the int guard (Option 3) is the tempting symmetry but `SumC` shows it fixes one route of a gap that stays open.
The decision that actually settles "never silently" is whether the boundary walks container elements (ticket 18 §2 already does this
for foreign returns); scope questions follow from it. If David wants one scope sentence now: *the tag test is unconditional; the kind
test is exported-only; both leave container elements to the callee.*

## Caveats

- Cost numbers are **one machine, OTP 28.0, x86-64 JIT**; 18a measured OTP 28.5/arm64. Differences of ≈ 1 ns are within the unexplained
  build-to-build variation I saw (D's record loop is slower for a reason I attribute to its extra `is_integer` on `int n`/`acc`, which
  is consistent but not independently confirmed).
- `SumAll`/`SumB` use list elements. A forged record in a *record field* and in a *tuple member* were not measured by me; the
  verifier was asked to try them (see its report).

## Verifier (independent re-run; full report `verification/59-verifier.md`)

**CIRCULAR: no.** Bytes (−36 / +10) and the behaviour table reproduce exactly; four shuffled `cost.sh` runs with a same-source control build (C vs C2: 0.03 ns apart) give
record loop C ≈ −2.0 ns, D ≈ +1.1 ns (well above noise) and D int loop ≈ +0.14 ns (**at the noise floor, not a measured cost**). Qualifications the verifier added:

- The record-loop deltas aggregate **several** tests per iteration (both `LoopRec` clauses and `InnerRec`), not one test each.
- Forging a value needs foreign (Erlang) code; B#'s own type checker cannot produce it. That is the boundary threat model, not a B# author bug.
- Its own new probes: a forged `Order` nested in a **record field** and as a member of an **`(:ok, Order)` tuple**, each reaching a private function, give `function_clause` unpatched,
  **`99` under C**, `function_clause` under D; a `Byte` record field holding `300` then `2.5` gives `301` then `3.5` unpatched and under C, `function_clause` under D.
  So the private tag test is the only defence for nested records too. A record built locally and passed to a private function behaves identically in every variant (the private tag test is pure overhead there).
- It agrees that `SumC` means widening private int guards patches a symptom: the root gap is unguarded container and record-field contents at the boundary.
