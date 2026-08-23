# 46 — Does a refined parameter get a boundary guard?

Status: resolved 2026-08-23 — [ENG-218](https://linear.app/davewil/issue/ENG-218)
Raised by: F2 (`compiler/features/F2-interval-refinements.md`, Done when), 2026-08-16
Blocks: nothing — F2 shipped without it
Type: `wayfinder:decision`

> **The ticket-to-issue arithmetic no longer holds and this is another data point.**
> `CLAUDE.md` says ticket NN maps to ENG-(166+NN), which would make this ENG-212 — and ENG-212 is
> ticket 42. The drift started at 42 and every ticket since has needed its issue number recorded
> rather than computed. 42 is ENG-212, 43 is ENG-213, 44 is ENG-215, 45 is ENG-216, 46 is ENG-218.

## Question

`type Octet = int where value >= 0 and value <= 255` now narrows a parameter, and the emitted
`-spec` says `0..255`. **Nothing enforces it at the exported boundary.** Measured on `wire.bs` at
the `ibs` prompt:

```
bs> Classify(300)
:reserved
```

`300` is not an `Octet`. It matches the `>= 9` clause, because that clause lowers to
`when Bs@r1 >= 9` and there is no upper test anywhere in the emitted module.

**Should `bsc` emit `is_integer(N) andalso N >= 0 andalso N =< 255` in the head of an exported
function whose parameter is a refined integer?**

## Why this is a decision and not a defect

**Inside beam-sharp nothing is wrong.** Site 1 checks every call argument, so a beam-sharp caller
passing an `int` where an `Octet` is declared is already rejected — `intervals_tests` asserts it.
What is unchecked is a caller the compiler has never seen, which is ticket 21's foreign sender.

**Ticket 18 already measured this exact shape and called the check optional.** Its finding is
*"forging the tag is caught. Forging the payload is not"*, observed in Gleam
([`10c_gleam_forge.erl`](../prototypes/10c_gleam_forge.erl)): a bad tag crashes, a bad payload is
returned as-is. A refined integer is a payload. And 18 states the boundary emission is a decision
rather than a default:

> What remains genuinely optional is emitting it at the **exported boundary**, which is this
> ticket's decision and unchanged.

So a feature may not take it. That is the features README's own rule — *a feature that needs a
decision raises a ticket rather than making one* — and it is why F2 shipped with this named.

## What is already established, so this does not get re-derived

- **The check is cheap and is inside the admissible vocabulary.** Ticket 18 fixes that vocabulary as
  the BEAM guard set, and ticket 20 §5 puts guard-decidable refinements in the O(1) tier precisely
  because *"reasoned about"* means a single guard decides them. A range test is two comparisons.
  This is the opposite end of the scale from `string`, whose `valid_utf8` reads every byte and is
  barred from a foreign declaration for that reason (F9.11, shipped).
- **The machinery exists.** `bs_emit:boundary_guards/4` already does this for records — ticket 26
  §1's tier one, an unconditional tag test on an exported record parameter, measured in 26a at
  **+14 bytes, flat in field count**. A refined integer would take the same path with a different
  test, and `ensure_var/3` already handles a parameter with no name to read from.
- **Two narrowings are in that code today and are limits rather than principles**: only where the
  declared type is a *single closed record*, and not where the clause's own pattern already
  constrains `Kind`. The second generalises directly and is the interesting half here — a clause
  written `Classify(>= 4 and <= 7)` already tests both bounds, so a boundary guard on it is dead
  weight, while `Classify(>= 9)` tests one bound and needs the other.
- **18 §1's own test for where the free check belongs** is *"only where the function's own body
  would not object"*. `Classify(300)` returns `:reserved` and objects to nothing, so by 18's stated
  test this case wants the check.

## What this ticket owes

1. **Whether it is emitted at all**, and if so whether on every exported function or only where
   something consumes the guarantee (18's two-tier split for records).
2. **Whether a clause that already tests the bound gets a second test.** Cheap to answer and it is
   the difference between +2 comparisons per exported clause and +2 per *unconstrained* one.
3. **What happens on failure.** A tag test that fails today produces `function_clause`, which
   ticket 12 retains and ticket 13 found `erlc` inserts anyway. Is a refinement violation the same
   crash, or does it deserve to be distinguishable? A `function_clause` on `Classify/1` does not
   say *"300 is not an Octet"*, and the residual machinery could.
4. **Whether the same answer covers a refined `int` inside a tuple or a record field**, or only a
   whole parameter. This is the same nesting boundary F2 drew for relational patterns, arriving
   from the emitter's side rather than the checker's.

## What it does not owe

**Not the O(n) tier.** `binary where valid_utf8` is 20 §5's second tier, is already barred from a
foreign declaration by F9.11, and its entry check is a separate unbuilt thing. This ticket is about
the tier a guard decides.

**Not `is_integer/1` in general.** Whether an exported function type-tests its arguments at all is
18's standing question about every parameter, and it is deliberately not reopened here. This asks
only about the *refinement* — the part of the type the author wrote down explicitly and that the
compiler is now publishing in a `-spec`.

---

# Resolved — 2026-08-23

**Yes. An exported function whose parameter is a refined integer gets a boundary guard, and the
guard is the part of the refinement the clause does not already prove.**

```csharp
Classify(1)             -> :method       // nothing added — the literal proves 1 ∈ 0..255
Classify(>= 4 and <= 7) -> :reserved     // nothing added — the pattern proves 4..7 ⊆ 0..255
Classify(>= 9)          -> :reserved     // one comparison added
```

```erlang
'Classify'(1)      -> method;
'Classify'(Bs@r1) when Bs@r1 >= 4 andalso Bs@r1 =< 7   -> reserved;
'Classify'(Bs@r1) when Bs@r1 >= 9 andalso Bs@r1 =< 255 -> reserved.
%%                                        ^^^^^^^^^^^^ this, and only this
```

The compiler delta is one function in `bs_emit`, beside `constrains_kind/1`: given the declared
type `D` and the type `P` the clause head accepts, emit comparisons for `P \ D`. Everything it
needs exists — `bs_types:subtract/2`, and `bs_check:rel_type/2` which already turns a relational
pattern into an interval.

## 1. Emitted always, on exported functions only, and there is no second tier

**Always**, by ticket 18 §1's rule C, case (b): *the body is total over the wrong term, so a guard
is emitted*. `Classify(300)` returns `:reserved` and objects to nothing — 18's outcome 3, the only
outcome that makes the type system a lie. This is not a new argument; it is 18's, applied to a
shape 18 did not have when it resolved.

**Exported only.** 18 §4 is explicit that C *"looks at the exported function's own clause heads and
body, and no further"*. A private function's every call site is a checked beam-sharp call site, so
site 1 already rejects the out-of-domain argument and the guard would be dead weight.

**No second tier.** The record guard has two (tag always; exact-field-set only where generated code
consumes the record) because a record's shape has two parts that can be forged separately. A
refinement has one part. The range test *is* the whole check, so the question 46 inherited from
26 §1's split does not arise here — recorded so it is visibly closed rather than skipped.

## 2. A clause that already proves the bound gets nothing — and this is subtraction, not a flag

This is the interesting half, and the answer is better than the yes/no the ticket asked for.
`constrains_kind/1` is a **boolean** because a tag either is or is not constrained. A bound is not
like that: `Classify(>= 9)` proves *half* of `Octet` and owes the other half. So the emitter
subtracts rather than tests a flag, and emits comparisons for whatever is left.

Measured against `examples/Wire/wire.bs` using the compiler's own algebra
(`bs_types:subtract(Accepts, range(0, 255))`):

| Clause | accepts | escapes `Octet` | emitted |
|---|---|---|---|
| `Classify(1)` … `Classify(0)` (5 clauses) | `1`, `2`, `3`, `8`, `0` | — | nothing |
| `Classify(>= 4 and <= 7)` | `4..7` | — | nothing |
| `Classify(>= 9)` | `int >= 9` | `int >= 256` | `=< 255` |
| `Band(n) when n > 128` | `int >= 129` | `int >= 256` | `=< 255` |
| `Band(n) when n > 64` | `int >= 65` | `int >= 256` | `=< 255` |
| `Band(n) when n <= 64` | `int <= 64` | `int <= -1` | `>= 0` |
| `Sizing(n)` | `int` | `int <= -1 \| int >= 256` | `>= 0`, `=< 255` |

**Six of eleven clauses need nothing; the remaining five carry six comparisons between them,
against twenty-two for a naive two-per-clause emission.** So the ticket's *"a range test is two
comparisons"* is the worst case, not the cost.

`Band(n) when n <= 64` is the row worth reading twice. It emits `>= 0`, the *lower* bound — and it
is what catches `Band(-5)`, which returns `:low` today. The ticket framed this question entirely
around values above the domain; half the escapes are below it.

## 3. `function_clause`, and inspectability is ticket 23's

Same failure as the record tag test, and for the same reason: two boundary guards in one clause
head that failed differently would be two error channels where the author wrote one declaration.
Ticket 12 retains `function_clause` and ticket 13 found `erlc` inserts it anyway.

A `function_clause` on `Classify/1` does not say *"300 is not an `Octet`"*, which is a real cost —
but it is already an open question with an owner. 18 §7 hands ticket 23 *"whether the emitted
boundary should be **inspectable**, since under §1 and §4 it is invisible in the surface language"*.
This ticket adds a second instance to that question rather than inventing an error channel beside it.

## 4. A fixed number of projections, not a depth limit

**A refined `int` is guarded wherever a fixed number of projections reaches it** — a whole
parameter, a tuple element, a record field. It is **not** guarded through a collection.

The criterion is cost, not nesting. A tuple element is bound by the clause pattern itself and a
record field is one `map_get` — the same projection the tag test already emits at that depth, which
is why 26 §7 puts *"presence and value tests per 18 §1 unchanged"* inside 18's existing scope. But a
`list<Octet>` parameter is O(n) in a length **the foreign caller chooses**, which is ticket 11's
refusal at a third site and 20 §5's second tier. Whole-parameter-only would have been the smaller
answer and needs no defending; it is refused because it would leave a record field undefended that
the tag test already stands next to.

## What this hands back to ticket 18

**A relational pattern is a shape where *"mentioned in a guard"* is not *"the body objects"*.**
18's census counts a parameter defended if every clause *"constrains it structurally or mentions it
in a guard"*. `Classify(>= 9)` mentions `Bs@r1` in a guard and admits `300` anyway. The heuristic
and rule C diverge exactly on F2's construct, so the census understates by however many relational
patterns a program contains — a correction to 18's measurement, not to its rule.

## Corrections to this ticket's own premises

- **18 did not call the exported check optional; its intake did.** The quoted sentence is at
  `18-boundary-defence.md:107`, inside *"The mechanism already exists — from ticket 09, resolved
  2026-08-12"*, which is material 18 gathered. 18 resolved **2026-08-13**, and its answer is §0–§8:
  §1 is rule C, §5 is titled *"No opt-out"*, and §8's *"Not decided here"* does not list this. The
  ticket already cited §1 against itself — *"by 18's stated test this case wants the check"* — so it
  held both sides honestly. This only settles which of the two citations governs.
- **The vocabulary premise holds, but not on the cited authority.** 18:99–102's enumeration
  (`is_integer`, `is_binary`, `is_atom`, `is_tuple`, `binary_to_existing_atom`) is ticket 09's
  *union-discriminability* set and contains no comparison at all. The citation that works is
  **20 §5**, which puts a guard-decidable refinement in the O(1) tier and says it is *"legal in a
  clause head, legal at an FFI declaration"* — the boundary, named.
- **`boundary_guards/4` is not scoped to exported functions,** though its comment says
  *"unconditional on an exported record parameter"*. Nothing consults `is_public/1`; measured, a
  private `Inner(Order o)` receives the tag test. That is the record guard's business against
  18 §4, not this ticket's, and it is why §1 above states the scope rather than inheriting it.

## Consequences

- **A new defect, decided and unbuilt** — see [ticket 58](58-refined-int-admits-a-float.md).
  `Classify(100.5)` returns `:reserved`. The refinement guard narrows *within* `int` and its
  soundness rests on 18 §1(b)'s type test, which is decided and not emitted. Comparison operators
  are not type tests: `100.5 >= 0 andalso 100.5 =< 255` is `true`. 46's *"not `is_integer/1` in
  general"* is correctly scoped — 18 already answered that — so this is raised beside 46 rather than
  inside it.
- **Ticket 23** gains a second instance of the inspectability question it inherited from 18 §7.
- **F2** may now close its *Done when* clause; the decision it raised this ticket for exists.
