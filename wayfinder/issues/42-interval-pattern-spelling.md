# 42 — How is a span of integers named in a clause head?

Status: claimed 2026-08-15
Raised by: F2 (`compiler/features/F2-interval-refinements.md`, scenario F2.3)
Blocks: F2
Type: `wayfinder:grilling`

## Question

A clause head can name one integer (`Classify(1) -> :method`). It cannot name a **span**. Once
`type Octet = int where value >= 0 && value <= 255` lands, spans stop being a convenience and
become the only way to write a legal program — so this ticket settles how one is spelled.

## Why this is forced rather than nice to have

Ticket 12 §2 makes a catch-all over a **closed** residual an error. Today a parameter declared
`int` has an **open** residual, so a wire dispatch gets its `_` for free. Measured against the
skeleton by [`25c_residual_probe.sh`](../prototypes/25c_residual_probe.sh):

- four named frame types over a bare `int` → residual `int <= 0 | 4..7 | int >= 9` — **open**;
- the same plus a guard bounding the octet to `0..255` → residual `int <= -1 | int >= 256`,
  values the wire cannot produce, **still open**.

The moment the refinement lands, that residual **closes** — 252 unnamed values for an AMQP frame
type, ~2³² for a class/method pair — and the `_` that used to discharge it becomes an error. So
F2 cannot ship the refinement without shipping a way to name the span, or it turns working
programs into rejected ones. That coupling is recorded in 25c and is why F2 is one feature and
not two.

**This is the residual arriving as a bill.** Ticket 04's finding — the residual *is* the missing
case — is what makes exhaustiveness useful; here it is what makes the language unwritable without
a span pattern. The compiler is about to hand an agent 252 cases and no syntax to answer with.

## What is already established

- **The `..` token is available and costs nothing.** Ticket 28 §5 measured it in
  [`28b_dot_dot_lexing.escript`](../prototypes/28b_dot_dot_lexing.escript): `..` ordered before `.`
  lexes `o.Status..t` cleanly as `o . Status .. t`, and `1..5` lexes as `1 .. 5` rather than
  `1.` `.5`.
- **It places one obligation on a decision not yet made.** That result holds *because* 28b's float
  rule demands digits on both sides (`{D}+\.{D}+`). A float spelled `{D}+\.` — a trailing dot, as
  Pascal allowed — would swallow the first dot and the collision would be real. Erlang's own lexer
  already requires both sides (`1.0` legal, `1.` not), so honouring it costs nothing, but whoever
  settles float literals inherits the obligation.
- **There are no relational patterns.** F7 recorded that `{ Total: > 100 }` is a C# relational
  pattern *"which this grammar does not have"*. So the C# pattern-position answer to this question
  is not currently available, and adopting it is a larger change than adopting a range token.
- **Guards already work.** `Classify(n) when n >= 4 && n <= 7` parses and checks today. The
  question is not whether spans are expressible — they are — but whether they are expressible in
  a form the compiler can read *back* as an interval, and whether ticket 23 §2's synthesised head
  can emit one.

## The three shapes, as code

### A — a range pattern

```csharp
Classify(4..7)   -> :reserved
Classify(9..255) -> :reserved
```

### B — a range test in a guard, with membership

```csharp
Classify(n) when n in 4..7   -> :reserved
Classify(n) when n in 9..255 -> :reserved
```

### C — no new syntax; you name a refined type

```csharp
type Reserved = int where (value >= 4 && value <= 7) || (value >= 9 && value <= 255)

Classify(Reserved r) -> :reserved
```

C is the only one that needs **nothing new** — F2.1 already ships type-position refinements, and
26's tag mint already makes the type nameable. It is here as the null option precisely because a
decision that adds no syntax deserves to lose on its merits rather than by being unstated.

## The false friend, which is the actual difficulty

**`4..7` is a tier-1 borrow whose C# meaning is wrong here.** C#'s `..` builds a `System.Range`
and it is **half-open**: `a[1..4]` yields elements 1, 2 and 3. Elixir's `4..7` is **inclusive** and
yields 4, 5, 6 and 7. The spelling this language would take from C# carries the arithmetic this
language would take from the BEAM, and the two disagree by one at the top end.

A wire dispatch is exactly where that costs something: `9..255` inclusive covers the octet;
`9..255` half-open leaves 255 unnamed, the residual stays closed, and the compiler rejects a
program its author believes is total. The failure is **loud** — that is the one mercy — because
exhaustiveness catches it at the definition rather than at runtime.

This is the shape the map's own amendment already models: `behaviour` beat C#'s `interface` because
the tier-1 borrow carried vocabulary the construct did not belong to. Here the tier-1 borrow carries
**semantics** the construct does not want. The heuristic says survey all three tiers and take the
most accurate word, not take the highest tier that fits.

## What each shape costs the compiler

| | lexer | parser | checker | 23 §2 head synthesis |
|---|---|---|---|---|
| **A** `4..7` | `..` token (28b, done) | new pattern form | `p_range` → interval directly; no guard translation | emits `4..7` — one clause per residual interval |
| **B** `n in 4..7` | `..` token, `in` keyword | new guard operator | must recognise `in` as an interval, not an opaque predicate, or the refinement is lost | emits `n when n in 4..7` |
| **C** named type | nothing | nothing | already works | emits `Reserved r`, but **only if a matching type exists** — otherwise it has no name to offer |

The last column is the one that is easy to miss. Ticket 23 §2 makes the compiler synthesise the
head from the residual, and *"where the residual is not guard-expressible the term says so and
offers nothing"*. Under C the residual is always interval-expressible but rarely **name**-expressible
— the compiler would have to either invent a type name or fall back to a shape C does not otherwise
permit. A spelling that the compiler cannot emit is a spelling that breaks the interlocutor.

## What this ticket owes

1. The spelling, and whether the interval is inclusive at both ends.
2. If `..` is taken: a line for the spec stating the divergence from C#'s half-open range, per
   tier 3's "diverge deliberately, and say so".
3. Confirmation that ticket 23 §2's synthesised head emits the chosen form — since the residual is
   a set of intervals, and this is the syntax it must lower to.
4. Whether the float-literal obligation from 28 §5 is now discharged here or stays owed.

## Answer

<!-- recorded on resolution -->
