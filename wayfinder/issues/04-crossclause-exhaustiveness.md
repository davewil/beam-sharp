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

**This is not a research risk — it is a solved, shipped mechanism.** Exhaustiveness and
redundancy are the *same* operation: an emptiness test on a difference type, run against two
inputs. Semantic subtyping *defines* `s ≤ t` as `s ∧ ¬t ≃ 0`, so one solver answers both.
A pattern becomes a type via the accepted type `Acc(p)` (literals are singleton type-tests,
tuples are products, records are cofinite label maps, sequences desugar to recursive pair
patterns, `&`/`|` are intersection/union). Exhaustiveness is `t \ (Acc(p₁)|…|Acc(pₙ)) ≃ 0`,
and the residual *is* the missing case — CDuce prints it plus a sampled counter-value.
Clause `i` is redundant iff its slice `(t \ Acc(p₁) \ … \ Acc(pᵢ₋₁)) ∧ Acc(pᵢ)` is empty, so
first-match ordering is just the subtraction. CDuce's overloaded functions type-check the
body **once per arrow** of the declared interface, which is the whole reason overloading
beats a type-case.

Three findings that change the design:

- **Exhaustiveness needs a *declared* input type.** Elixir infers the function type as an
  intersection built from the clauses, making the check vacuous. **The headline feature
  requires signatures on multi-clause functions.** → 09, 11, 12.
- **Elixir v1.20 ships redundancy only, not exhaustiveness** (verified against changelog,
  source and live probes) — the papers show the exhaustiveness warning, the compiler does not
  emit it. No user signatures yet, and signatures are explicitly gated on making recursive
  and parametric types efficient.
- **Redundancy must warn, never error** — attainability is provably non-compositional, since
  a clause dead under one arrow is live under another.

Cost is real but bounded in practice (2–9% of Elixir compile time) with an unbounded tail;
"EXPTIME-complete" is citation drift. Untheorised gaps beam-sharp inherits: binaries,
improper lists, recursive/parametric types, row polymorphism, OTP behaviours.

## Notes

AFK. This is the research risk at the heart of the effort — the part nobody has shipped in
a mainstream BEAM language. Feeds tickets 09, 11 and 12.
