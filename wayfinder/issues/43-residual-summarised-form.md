# 43 — What does an inexhaustive diagnostic say when the residual is forty-one intervals?

Status: **resolved 2026-08-16** — the prose truncates the exact form at 3 cases; nothing else summarises
Raised by: F2 (`compiler/features/F2-interval-refinements.md`, scenario F2.4)
Blocks: F2 — **unblocked**
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

## Answer — 2026-08-16

**The prose prints the exact residual truncated at three cases and nothing else summarises.**
Everything below is measured by
[`43a_residual_at_width.escript`](../prototypes/43a_residual_at_width.escript), which drives the
real `bsc` for what is printed today and works in `bs_types` directly for the shapes that are
functions of the residual *term*. Three of the four owed items fell to measurement. One is a taste
call, defaulted in §6 with the question left standing.

### 0. Two of this ticket's own premises were wrong, and the corrections do the work

**Hole 1's "a 41-interval residual therefore lowers to 41 heads" is not what the compiler does.**
Measured, it prints **one** head line of **453 characters**:

```
scattered.bs:3: error: Classify is not exhaustive
  no clause matches:
    Classify(int <= 9 | 11..19 | 21..29 | 31..39 | 41..49 | … | int >= 401) -> ...
```

`heads/2` in `compiler/src/bsc.erl` splits on the **tuple part** — one product per *argument
position* — and a union of intervals lives inside a single argument. The 41-head claim is a
statement about [ticket 23](23-what-the-language-owes-an-agent.md) §2's lowering, which is
**unbuilt**. So there is one artefact to render today and two once §2 lands, and §3 gives them one
rule rather than the two Hole 1 asked for.

**Hole 2's complement loses, and not for the reason the ticket gives.** The aside *"for an unbounded
`int` the complement is not finite"* is wrong: the complement of the residual is the **covered**
set, which is finite whenever the clauses cover finitely much — 25c's case exactly. It loses on
size. Rendered against every case the probe reaches, in characters:

| case | exact | complement |
|---|---:|---:|
| 40 contiguous singletons over `int` | 20 | 22 |
| 40 scattered singletons over `int` | 432 | 245 |
| 40 contiguous over `0..255` (closed) | 11 | 25 |
| 40 scattered over `0..255` (closed) | 404 | 237 |

**It is never the smallest form, and it beats `exact` only where `exact` is already 432 characters —
at which point it is still 245.** The structural reason is that *the residual and the covered set
are long together*: a covered set dense enough to state as a short exclusion is one that made the
residual coalesce, and a residual that sprawled did so because the covered set was scattered, which
its own rendering then is. Hole 2's intuition — *"40 named singletons out of a bounded octet is
small to state as an exclusion and large to state as a union"* — is measurably false in the scattered
case that produced this ticket: `every 0..255 except 5 | 10 | … | 200` is 237 characters.

**So the compiler does not compute a complement.** This is owed item 4, answered *no*, on
measurement rather than on the finiteness argument the ticket expected to have.

### 1. The term never summarises — confirmed, and nothing measured argues otherwise

Expected in the reframing and now stated so F2 can be built against it. Ticket 23 §4 freezes
`inexhaustive` with residual and head as a contractual descriptor; §4 also makes payloads **maps**,
so a *summary* key could be added later without breaking a matcher. It is not added now: a consumer
that can see the whole residual has no use for a shorter description of it, and 23 §10's
`bsc --api` is already the full-fidelity channel when the prose has truncated.

### 2. The prose shape is the exact form truncated — not a fifth spelling

The four candidates in Hole 2 are not four formats. Three of them *replace* the residual with a
description of it; one is the existing printer with a stop in it. Measured, in characters:

| shape | 41 intervals | 2 intervals | new machinery |
|---|---:|---:|---|
| exact (today) | 432 | 20 | none |
| **first N, then a count** | **42** | **20 — byte-identical to exact** | one `lists:split/2` |
| bounds and count | 50 | 49 | a cardinality function |
| complement | 245 | 22 | none — `bs_types:subtract/2` is exported |
| cardinality only | 24 | 24 | a cardinality function |

Decided: **`first 3 cases, then `... (K more)``**. Two reasons, both mechanical rather than
aesthetic:

- **It is one format, not two.** At or under the threshold it prints exactly what the compiler
  prints today, character for character, so the *"why did the format change"* confusion Hole 3
  raises cannot arise — there is no second shape to switch into. Every other candidate must switch,
  because none of them can render a two-interval residual without being worse than the enumeration
  (49, 22 and 24 characters against 20, and none of them tells you the answer).
- **Cardinality is unavailable over the case that matters.** Over `int` the residual is unbounded,
  so `bounds and count` reads `41 intervals spanning -inf..+inf, unbounded values` and `cardinality`
  reads `unbounded unnamed values` — twenty-four characters of nothing. A shape that degenerates on
  the **open** residual cannot be the general one, and today *every* residual is open, because
  `int` is the only integer type the surface has until F2 lands.

The marker is ASCII `... (K more)`, not `… (K more)`. A diagnostic goes to stderr through terminals
the compiler does not control and the ellipsis character buys two characters of width, which is not
a trade. (The probe measures the `…` form; add 2.)

### 3. One rule for both artefacts — Hole 1, owed item 2

**The prose prints at most three of whatever it is enumerating, then `... (K more)`.** The unit is
*the repeated thing on the page*, and which thing that is changes exactly once, when 23 §2 lands:

| stage | what the printer enumerates | what "three" counts |
|---|---|---|
| **today**, before 23 §2 | intervals inside one argument of one head line | intervals |
| **after** 23 §2's lowering | one head line per case | heads |

**Naming the stage is not pedantry, and getting it wrong is the trap this ticket walked into once.**
§0 corrects Hole 1's claim that 41 intervals become 41 heads — today they do not, they are one head
— and a rule stated in *heads* would therefore truncate **nothing** today, because one head is under
any threshold of three. The first draft of this answer said "three heads", and F2.4's expected
string, which is the truncated line, contradicted it. The rule has to name the live unit per stage
or it asserts the exact behaviour §0 just measured as false.

**Counting heads is what the rule must become after §2, and that half is load-bearing.** A residual
over a two-argument function is a *product*, so the head count is the product of the parts and is ≥
the interval count. A rule that stayed on intervals after §2 would print an unbounded number of
lines the moment a second argument had a residual too.

**Both stages share the property that makes the shape work**: three items or fewer prints
byte-identically to no rule at all.

### 4. The threshold is 3, the unit is items-per-stage, and it was measured rather than argued

Hole 3 says the units *"disagree: three intervals over `int` render longer than twenty over
`0..255`"*. Measured, they do not:

| case | intervals | chars |
|---|---:|---:|
| 2 over `int` | 2 | 20 |
| 3 over `int` | 3 | 30 |
| 3 over `int`, 19-digit bounds | 3 | 60 |
| 20 over `0..255` | 20 | 100 |
| 41 over `int` | 41 | 432 |

**Interval count and character length order these identically**, including the adversarial row built
on purpose to break it — three intervals whose bounds are the largest literals a real program
plausibly carries. No threshold in either unit sorts any pair differently, so **character length is
not load-bearing**, and the tie goes to the one that is stable and easy to test: a count of items,
per §3's table.

**And there is no threshold in the tunable sense.** This takes Hole 3's *"no threshold at all"*
option — always truncate — and §2 is what makes it free: since the truncated form **is** the exact
form when there are three cases or fewer, "always on" costs a small residual nothing. The cost the
ticket priced for that option ("a two-interval residual gets summarised prose where the enumeration
would have been more useful") does not exist under this shape. No tunable, no flag, no switch.

### 5. What it prints

Today, in place of the 453-character line:

```
scattered.bs:3: error: Classify is not exhaustive
  no clause matches:
    Classify(int <= 9 | 11..19 | 21..29 | ... (38 more)) -> ...
```

After 23 §2's lowering, where the heads are separate lines:

```
    Classify(n) when n <= 9              -> ...
    Classify(n) when n >= 11 and n <= 19 -> ...
    Classify(n) when n >= 21 and n <= 29 -> ...
    ... (38 more)
```

The guard spelling is `and` per [ticket 44](44-conjunction-spelling.md) and the pattern form
`Classify(>= 11 and <= 19)` per [ticket 42](42-interval-pattern-spelling.md) — a head this
diagnostic could equally print, and which of the two it prints is 23 §2's call, not this ticket's.

### 6. The one thing left open, and the default taken

**When the residual is CLOSED, truncating hides work the author cannot skip.** Ticket 12 §2 makes a
catch-all an *error* over a closed residual, so after F2 lands this program has forty-one clauses to
write and no `_` to write instead:

```csharp
type Octet = int where value >= 0 and value <= 255

atom Classify(Octet n)

Classify(5)   -> :known
Classify(10)  -> :known
// … thirty-eight more, none contiguous
```

Over an **open** residual the truncation costs nothing — the author writes one catch-all and the
intervals were informational. Over a **closed** one the enumeration *is* the checklist, and three of
forty-one is a third of a percent of it.

**Default taken: truncate anyway, both cases identically.** The term keeps all forty-one and
`bsc --api` (23 §10) is where a consumer goes for them; a forty-four-line error message is not more
actionable than a five-line one plus a query, and 23 §1 settled that *the term carries what to act
on, so the prose owes only the fact*. Printing in full for closed residuals also reintroduces
exactly the format switch §2 was chosen to avoid, keyed on something the reader cannot see.

**The compiler delta if David wants the other answer** is one line — `heads/2` takes the residual's
openness, which the checker already knows because 12 §2 already tests it, and passes `all` instead
of `3`. It does not change the term, the descriptor or anything F2 builds, so **F2 is unblocked
either way** and this can flip later without a breaking change.

### The compiler delta, in total

- `bsc.erl`'s `heads/2` gains a truncation at three rendered cases plus a `... (K more)` line. No
  new module, no cardinality function, no complement.
- `bs_types` gains **nothing**. Every shape considered here is a function of the residual it already
  produces, and the one that was chosen is the printer it already has.
- The descriptor in 23 §4 gains nothing, so nothing about it is frozen by this ticket.
- F2.4's scenario becomes assertable: the 40-scattered-singleton input, and an exact expected string
  ending `... (38 more)`.

### What this ticket owed, against what it answered

1. **Whether the term ever summarises** — no. §1.
2. **The summarised shape, for the residual and separately for the head** — one shape for both,
   `first 3 then ... (K more)`, because after 23 §2 they are one object. §2, §3.
3. **The threshold and its unit** — three, in heads; measured that the unit does not matter, and
   there is no tunable because the rule degenerates to the exact form at small width. §4.
4. **Whether the complement is computed** — no. It is never the smallest form, and it is large in
   exactly the case that made this ticket. §0.
