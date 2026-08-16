# 46 — Does a refined parameter get a boundary guard?

Status: open — [ENG-218](https://linear.app/davewil/issue/ENG-218)
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
