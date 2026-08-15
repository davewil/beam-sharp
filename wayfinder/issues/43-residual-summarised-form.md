# 43 — What does an inexhaustive diagnostic say when the residual is forty-one intervals?

Status: open
Raised by: F2 (`compiler/features/F2-interval-refinements.md`, scenario F2.4)
Blocks: F2
Type: `wayfinder:grilling`

## Question

Ticket 25c measured it: **40 singleton clauses produce a residual of 41 disjoint intervals on one
line.** That output is exact per ticket 20's algebra and useless to read. Ticket 23 makes the
residual the thing an agent acts on, so "just truncate it" is not available — truncating the
payload truncates the work.

This ticket settles what the compiler emits at width.

## The reframing that has to happen first

F2.4 states this as one question — *"the threshold and the summarised form are undecided"* — and
ticket 23 says it is two, because **the residual has two consumers with opposite needs**:

- **The term.** Ticket 23 §4 freezes `inexhaustive` (with residual and head) as a contractual
  descriptor, payloads as maps, because an agent dispatches on it. Its consumer needs it
  **complete**: 41 intervals means 41 clauses to write, and a term that summarises has thrown away
  the work it exists to hand over.
- **The prose.** Ticket 23 §1 settled that *"the term carries what to act on, so the prose owes
  only the fact"* — and cut the skeleton's explanatory line on David's *"Yuck. Is that line even
  required"*. Its consumer is a human reviewing, who needs the **shape**, not the enumeration.

So the likely answer is that only the prose summarises and the term never does — in which case
most of this ticket dissolves and F2 is unblocked cheaply. **It is a ticket rather than a feature
because that "likely" has three real holes in it**, below, and because 23 §4's descriptor is
frozen: changing what `inexhaustive` carries later is a breaking change to a contract the spec
publishes.

## Hole 1 — the head is 41 clauses, not 41 intervals

Ticket 23 §2 makes the compiler synthesise **the clause head** from the residual, and freezes it
into the same descriptor. A 41-interval residual therefore lowers to 41 heads:

```csharp
Classify(n) when n <= -1  -> ...
Classify(41..99)          -> ...
Classify(101..199)        -> ...
%% … thirty-eight more
```

That is correct and it is what the agent must write, so the term keeps all of it. But it means the
**prose** cannot summarise the residual alone — the head is the larger artefact and it needs a
rendering rule too. F2.4 asked about one and there are two.

## Hole 2 — the shape of a summary is not obvious for a union of intervals

A residual is a union of disjoint intervals. What is the *shape* of forty-one of them? Candidates
that are all defensible and mutually exclusive:

- the **bounds and the count** — `41 intervals spanning -∞..∞, 252 values`;
- the **first few plus a remainder** — `int <= -1 | 41..99 | 101..199 | … (38 more)`;
- the **complement**, which for a dense case is far smaller — `every int except 1..40`;
- the **cardinality only**, deferring shape entirely — `252 unnamed values`.

The complement is worth noting because 25c's own case is exactly the one where it wins: 40 named
singletons out of a bounded octet is *small to state as an exclusion and large to state as a
union*. Whether the compiler should compute it is a real question, since for an unbounded `int`
the complement is not finite.

## Hole 3 — what the threshold is measured in

"At some width" needs a unit. Interval count, rendered character length, or terminal columns are
three different rules, and they disagree: three intervals over `int` render longer than twenty
over `0..255`. A rule stated in intervals is stable and easy to test; a rule stated in characters
matches what actually hurts to read.

There is also a case for **no threshold at all** — always summarise the prose, always keep the term
complete — which removes a tunable and a class of "why did it switch format" confusion. The cost is
that a two-interval residual gets summarised prose where the enumeration would have been perfectly
readable and more useful.

## What is not in question

- The term stays exact and complete. Ticket 23 §4's contract and the agent-in-a-loop constraint
  both require it, and nothing measured here argues against it.
- The prose stays terse. 23 §1 settled that, and a diagnostic that narrates its own theory is a
  design document leaking into a compiler.
- `bsc --api` is where a consumer goes for the full term when the prose has summarised — already
  decided in 23 §10, still unbuilt. This ticket must not accidentally re-decide it.

## What this ticket owes

1. Whether the term ever summarises (expected: no) — stated, so F2 can be built against it.
2. The summarised **shape** for the residual, and separately for the synthesised head.
3. The threshold, its unit, or the decision that there isn't one.
4. Whether the complement is computed when it is finite and smaller.

## Answer

<!-- recorded on resolution -->
