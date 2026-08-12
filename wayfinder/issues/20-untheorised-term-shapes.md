# 20 — What must the type system model that set-theoretic theory doesn't yet cover?

Type: grilling
Status: open
Blocked by: 11

## Question

Ticket 04 established that the exhaustiveness mechanism is solved and shipped — but it also
listed what the theory **has not addressed at all**. These are *untheorised*, not merely
unimplemented, and this language inherits every one of them:

- **Binaries and bitstrings.** There is no `<<>>` typing anywhere in either Elixir type-system
  paper. For a BEAM language this is not an edge case: binaries are the string type, the wire
  format, and a first-class pattern-matching construct with size and unit specifiers. A
  multi-clause head matching on binary patterns is *idiomatic Erlang* and the theory is silent.
- **Improper lists.** Zero mentions in the literature.
- **Recursive and parametric types together.** Elixir's own signature milestone is explicitly
  gated on implementing both efficiently — the roadmap language is that failing to would "make
  the type system unfeasible".
- **Row polymorphism** — relevant if maps are to be typed structurally with extensibility.
- **OTP behaviours** — the callback contract as a typed object.

Decide, for each: does this language model it, approximate it, or exclude it — and if
excluded, what does a programmer write instead?

**Binaries deserve the most attention**, because excluding them quietly makes the headline
feature unusable in the domain the BEAM is most used for. Establish what a binary pattern in a
clause head would have to mean type-theoretically before deciding, rather than assuming it
falls out.

[Ticket 25](25-exemplar-programs.md) sharpens this considerably: of six ordinary BEAM workloads,
**three are binary work** — dynamic web pages, WebSocket frames and event-queue payloads. The most
common things people build on this platform sit precisely where the theory is missing. That should
be weighed before the type system is settled, not after.

Also weigh a product risk named by Castagna himself as an open problem: **readable error
messages and type pretty-printing** — and note that under the map's standing constraint (written
by agents, read by humans) this is a *product* problem rather than a cosmetic one, since the
diagnostic is consumed by an agent in a loop. See [ticket 23](23-what-the-language-owes-an-agent.md). For a language whose entire pitch is "the compiler proves
your clauses cover the input", an unreadable proof failure is not a cosmetic defect — it is
the feature failing in the only place a user meets it.

## Added by ticket 09 — resolved 2026-08-12

**The newtype gap.** [Ticket 09](09-union-representation.md) made naming pure aliasing, so
`Meters` and `Feet` over `float` are **one type**, as are `OrderId` and `CustomerId` over
`string`. The compiler will not catch passing one where the other is meant. Ticket 09 named the
cost explicitly rather than hiding it, and left the remedy here.

Two answers, and this ticket should pick one or say both:

- **Tags** — `{ :meters, float }` and `{ :feet, float }` are genuinely distinct *sets*, so the
  distinction is bought with a tuple rather than with type identity. Free, idiomatic Erlang,
  works today, and needs no theory. Cost: it changes the term, so it is visible at the interop
  boundary and in every pattern that touches the value.
- **Refinement types** — a predicate narrowing a type without changing its representation. This
  is the answer that would *also* settle the DDD-invariant question ticket 22 parked here ("only
  aggregate boundary enforcement is checkable and non-vacuous; the rest needs refinement
  types"), and it may supply a dispatch key for [ticket 16](16-ad-hoc-polymorphism.md), which
  lost nominal resolution to the same decision. Three open questions converging on one mechanism
  is worth noticing before deciding it is out of reach.

**Recursive and parametric together is now half-committed.** The bullet above records that
Elixir's roadmap is gated on implementing both efficiently. Ticket 09 has committed this
language to **equirecursive types with coinductive subtyping and a contractiveness rule** — so
the recursive half is decided, and only the interaction with parametricity is still open here.

## Notes

HITL. Surfaced by ticket 04's gap analysis. Blocked by 11, since what the type system *is*
determines what these questions even mean.
