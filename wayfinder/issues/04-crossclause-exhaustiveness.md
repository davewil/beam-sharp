# 04 — Cross-clause exhaustiveness with set-theoretic types

Type: research
Status: resolved

## Question

How is exhaustiveness across multiple pattern-matching function clauses actually computed
under set-theoretic types / semantic subtyping?

Cover:

- **CDuce** and its overloaded function types with pattern-matched arguments — the founding
  use case for this shape.
- **Castagna's semantic subtyping** work: how a pattern becomes a type, how clause domains
  union, how the checker decides the union covers the declared input type.
- The [Elixir type system design paper](https://www.irif.fr/_media/users/gduboc/elixir-types.pdf)
  and Elixir's **shipped** v1.20 implementation — what it does and does not check today,
  and how `dynamic()` interacts with exhaustiveness.
- **Decidability and performance**: set-theoretic subtyping is expensive; Elixir's roadmap
  explicitly gates further work on type-checker performance. What are the known cost
  characteristics and the mitigations?
- **Known open problems** — where the theory is incomplete or the algorithms are still
  research rather than engineering.
- How clause **ordering** is handled: Erlang clauses are tried in order, so later clauses
  may be shadowed. Does the theory detect redundant clauses as well as missing ones?

Write findings to `wayfinder/research/04-crossclause-exhaustiveness.md` and link here.

## Answer

Findings: [research/04-crossclause-exhaustiveness.md](../research/04-crossclause-exhaustiveness.md).

**Not a research risk — a solved, shipped mechanism.** A pattern becomes a type via its
accepted type `Acc(p)`; exhaustiveness is `t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0`; clause `i` is
redundant iff `(t \ Acc(p₁) \ … \ Acc(pᵢ₋₁)) ∧ Acc(pᵢ)` is empty. Both are the *same*
emptiness query, because semantic subtyping defines `s ≤ t` as `s ∧ ¬t ≃ 0`. Ordering is just
the subtraction, so first-match-wins is handled natively. The residual *is* the missing case:
CDuce has printed it, plus a sampled counter-value, since 2003.

Three findings that change the design:

1. **Exhaustiveness needs a *declared* input type.** Elixir builds the function type as an
   intersection *from* the clauses, making the check vacuous — so the headline feature
   requires signatures on multi-clause functions. → 09, 11, 12.
2. **Elixir v1.20 ships redundancy only, not exhaustiveness** (changelog, source comment and
   live probes agree; the papers show a warning the compiler does not emit).
3. **Redundancy must warn, never error** — attainability is provably non-compositional, since
   a clause dead under one arrow of an overloaded type is live under another.

Cost is 2–9% of Elixir compile time with an unbounded tail; "EXPTIME-complete" is citation
drift. Gaps inherited: binaries, improper lists, recursive/parametric types, row
polymorphism, OTP behaviours.

## Notes

AFK. This is the research risk at the heart of the effort — the part nobody has shipped in
a mainstream BEAM language. Feeds tickets 09, 11 and 12.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Cross-clause exhaustiveness](issues/04-crossclause-exhaustiveness.md) — **the mechanism is
  not a research risk; it has been solved and shipped since 2003.** But exhaustiveness is only
  well-posed against a **declared** input type: redundancy is relative, exhaustiveness is
  absolute. CDuce checks it because functions carry a mandatory interface; Elixir cannot,
  because it *builds* the function type from the clauses, making the check vacuous.
  **Therefore multi-clause functions in this language must carry signatures — inference alone
  doesn't weaken the guarantee, it makes the question disappear.** That is a binding constraint
  on tickets 08 and 11. Also: Elixir v1.20 ships **redundancy only, not exhaustiveness**.
```
