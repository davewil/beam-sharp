# F2 — Interval refinements, and the interval patterns that must land with them

**Status**      **blocked** — two decisions owed, see [below](#two-decisions-this-feature-needs-before-it-can-be-built)
**Implements**  tickets 20 §5, 12 §2, 04 — decides nothing
**Unblocks**    `bs_emit:int_part/1`'s bounded branches; wire dispatch in 25b and 25c
**Depends on**  F1, and on tickets 42 and 43

**The header said `not started` until 2026-08-15 while the README's table said `blocked`.** Two
files disagreed about whether this feature was takeable, and the table was the one that was right —
a session picked the feature up on the header's word and had to be turned round. The status line of
a feature file is the thing an agent reads first, so it is the thing that must not lie.

## Why this one now

The skeleton's README names it: *"a parameter declared `int` emits `integer()` whatever its clauses
test. The surface owes ticket 20 §5's `type Positive = int where value > 0;`. **That is the next
slice increment.**"* Intervals are already in the algebra and the checker already uses them — this
feature is surface and emission, not new theory, which makes it the cheapest real increment
available.

## The coupling that makes this one feature and not two

**Recorded in 25c and in neither ticket.** Today a parameter declared `int` has an **open**
residual, so a wire-format dispatch gets its catch-all for free. Measured against the skeleton by
[`25c_residual_probe.sh`](../../wayfinder/prototypes/25c_residual_probe.sh):

- four named frame types over a bare `int` → residual `int <= 0 | 4..7 | int >= 9` — **open**;
- the same plus a guard bounding the octet to `0..255` → residual `int <= -1 | int >= 256`,
  **values the wire cannot produce**, still open.

The moment `type Octet = int where value >= 0 && value <= 255;` lands, every wire dispatch acquires
a **closed** residual — 252 unnamed values for an AMQP frame type, ~2³² for a class/method pair —
and ticket 12 §2 makes a catch-all over a closed residual an **error**. So refinements *without*
interval patterns turn working programs into rejected ones.

**Therefore both halves ship together or neither does.** This is the feature-file rule from the
features README, and it is here because it was learned rather than assumed.

## Scenarios

### F2.1 — a refined type is declared and narrows the emitted spec

Input:

```csharp
module Wire

type Octet = int where value >= 0 && value <= 255

Octet Clamp(Octet)

Clamp(n) -> n
```

Expect: compiles, exit `0`, and the emitted `-spec` says `0..255` rather than `integer()`. This is
the scenario that makes `bs_emit:int_part/1`'s bounded branches reachable — currently dead code
that the unit suite cannot cover.

### F2.2 — a refinement closes the residual, and an unnamed case is an error

Input: a function over `Octet` naming four values with a `_` catch-all.

Expect: **error**, exit non-zero, ticket 12 §2's closed-residual rule firing. This is the scenario
that would silently break 25c if F2.3 did not exist — worth running *before* F2.3 to see the
failure it prevents.

### F2.3 — an interval pattern names a span of cases in one clause

Input:

```csharp
FrameType Classify(Octet)

Classify(1)      -> :method
Classify(2)      -> :header
Classify(3)      -> :body
Classify(8)      -> :heartbeat
Classify(4..7)   -> :reserved
Classify(0)      -> :reserved
Classify(9..255) -> :reserved
```

Expect: exhaustive, exit `0`. **The spelling `4..7` is not settled** — ticket 28 §5 measured that
`..` lexes ahead of `.` and imposes the float-literal rule (`1.0` yes, `1.` no), so the token is
available, but whether an interval *pattern* is spelled `4..7`, `n when n in 4..7`, or by naming a
refined type is a **decision, not a feature**. Raise a ticket before writing this scenario's
implementation.

### F2.4 — the residual stays legible at width

25c measured that 40 singleton clauses produce a residual of **41 disjoint intervals on one line** —
exact per ticket 20's algebra, and useless to read or to synthesise a clause head from, which is
what ticket 23 makes it for. Expect a diagnostic that reports the residual's **shape** at some
width rather than enumerating it. **The threshold and the summarised form are undecided** — also a
ticket, not a feature.

### F2.5 — a guard refinement and a type refinement agree

A function whose parameter is `Octet` and whose clause also guards `when n > 128` must not
double-count: the residual after that clause is `0..128`, not `int <= 128`.

## Out of scope

**Opaque (O(n)) refinements.** Ticket 20 §5 as amended by ticket 29 permits users to declare them
but **bars them from clause heads and foreign declarations**, so they need a check site the surface
does not yet have — and ticket 29 left three things owed on exactly that (whether the compiler may
call user code at a boundary, a spelling for the check site, what happens when the predicate
raises). Guard refinements only, here.

Also out: `string`'s UTF-8 refinement, which is the compiler-known opaque one and belongs with
binaries (F6).

## Two decisions this feature needs before it can be built

Both are tickets, not features. **This file should not be implemented until they are answered** —
recorded here so the coupling is not discovered mid-build:

1. **The spelling of an interval pattern** (F2.3) →
   [ticket 42](../../wayfinder/issues/42-interval-pattern-spelling.md) ·
   [ENG-212](https://linear.app/davewil/issue/ENG-212)
2. **The residual's summarised form at width** (F2.4) →
   [ticket 43](../../wayfinder/issues/43-residual-summarised-form.md) ·
   [ENG-213](https://linear.app/davewil/issue/ENG-213)

**Raised 2026-08-15, and they should have been raised when this file was written.** F2.3 already
said *"raise a ticket before writing this scenario's implementation"* and F2.4 said *"also a ticket,
not a feature"* — but neither was raised, so for a day this file recorded two blockers that existed
nowhere a query could find them. The feature itself is now
[ENG-214](https://linear.app/davewil/issue/ENG-214), blocked by both, so the frontier renders in
Linear rather than only in prose here.

## Done when

`bs_emit:int_part/1`'s bounded branches are reachable from a `.bs` file and covered by a boundary
test; a closed residual over a refined integer type is an error; an interval pattern discharges
one; and `25c_residual_probe.sh` reports a **closed** residual that the exemplar can name.
