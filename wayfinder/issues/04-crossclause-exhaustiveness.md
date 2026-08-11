# 04 — Cross-clause exhaustiveness with set-theoretic types

Type: research
Status: open

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

## Notes

AFK. This is the research risk at the heart of the effort — the part nobody has shipped in
a mainstream BEAM language. Feeds tickets 09, 11 and 12.
