# 16 — Ad-hoc polymorphism: what replaces interfaces and extension methods?

Type: grilling
Status: open
Blocked by: 09, 11

## Question

Ticket 05 dropped both of C#'s ad-hoc polymorphism mechanisms — **extension members** and
**static abstract interface members** — as load-bearing on OOP and the CLR, and flagged the
consequence explicitly: the language currently has **no ad-hoc polymorphism story at all**.

That is a hole, not a simplification. Without one there is no way to write a function that
works over "anything that can be compared", "anything that can be serialised", or "anything
with a length" — and every BEAM language has had to answer this somehow.

Decide the mechanism. Candidates, each with a real precedent:

- **Type classes** — PureScript/purerl and Haskell. Powerful, principled, needs dictionary
  passing at runtime and interacts non-trivially with set-theoretic subtyping.
- **Protocols** — Elixir's runtime dispatch on term shape. Idiomatic on the BEAM and cheap
  to implement, but dispatch is dynamic, which sits awkwardly against enforced exhaustiveness.
- **Structural dispatch** — since types are (probably) structural after ticket 09, dispatch
  on shape directly, with no nominal declaration at all. Fits the type system, but overloads
  the same mechanism the headline feature already uses.
- **Nothing** — no ad-hoc polymorphism; callers pass functions explicitly. Honest and small.
  Gleam largely takes this line. State the ergonomic cost if chosen.

Whatever is chosen must answer: how does it interact with **multi-clause head dispatch**,
which is already a dispatch mechanism? Two dispatch systems in one language need a clear
story about which fires when.

## Notes

HITL. Surfaced by ticket 05's inventory, which named the gap rather than papering over it.
Blocked by 09 (nominal vs structural changes what dispatch can even key on) and 11 (whether
the type system supports constraints).
