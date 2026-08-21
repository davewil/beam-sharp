# 48 — A map type in the prelude: opaque, matchable, or not at all?

Type: grilling
Status: open — [ENG-230](https://linear.app/davewil/issue/ENG-230)

> **The ticket-to-issue arithmetic is dead, and this is a third data point.** 48 is ENG-230,
> not the ENG-214 that `CLAUDE.md`'s `166+NN` rule predicts. Read the number, never compute it —
> tickets 46 and 47 recorded the same thing.

Raised 2026-08-21 by David while [ticket 31](31-composable-middleware.md) was resolving:
*"probably want to add map to prelude"*.

## Question

There is no map type. The prelude has `list<T>`, `option<T>` and `result<T, E>`, and
`Assigns: map<atom, term>` is refused at the declaration:

> `error: no type named map takes a type argument` — *the prelude has `list<T>`, `option<T>` and
> `result<T, E>`; your own take one with `type map<T> = ...`.*

Ticket 31 §4 found this while writing Plug's `conn.assigns` — an open key/value channel every
middleware stage writes into without coordinating with the others. **It is not blocking**:
`list<(atom, term)>` compiles and carries the same state, declared centrally once, after which a
stage prepends its own key without the record growing. The cost is that values are `term` and
lookup is a list walk.

So the question is not whether the gap exists. It is:

**Should `map<K, V>` be in the prelude, and if so does it have a pattern form?**

## What is already measured, and what it removes from the question

[`prototypes/31b_elixir_maps_vs_structs.exs`](../prototypes/31b_elixir_maps_vs_structs.exs) —
Elixir 1.19.5, `Module.Types.Descr`, the instrument tickets 10 and 15 used.

| measured | result |
|---|---|
| Is a map *pattern* open or closed? | **open** — `closed %{a: int}` is a subtype of `open %{a: int}`, not the reverse |
| Two structs, identical fields, disjoint? | **yes**, on the `__struct__` tag alone |
| Does an open map pattern match a struct? | **yes** — `%Order{}` is a subtype of `open %{a: int}` |
| Does closing the map exclude the struct? | **yes** |
| Can a map type declare the tag key **absent**? | **yes** — `open %{a: int, __struct__: not_set}` is disjoint from `%Order{}` *and* still admits plain `%{a: 1}` |

**This kills the objection that looked fatal.** A record erases to a map carrying a minted `Kind`
(ticket 26), so the worry was that a map pattern would silently also match records and dissolve the
tag that gives aggregates their identity. The last row shows the opposite: the tag is exactly what
keeps them apart. `map<K, V>` would be internally *"open map, `Kind` absent"* — disjoint from every
record by construction, needing no new discriminability rule. Row 2 also confirms ticket 26's own
argument against a shipping implementation that made the same call for the same reason.

**What survives.** A map's key domain is unbounded, so a pattern over it never closes a residual,
so a catch-all is always legal there (ticket 12's rule). Exhaustiveness over a map is **vacuous**.
Elixir pays nothing for that because it never promised exhaustiveness; beam-sharp would be adding
its first type over which the headline guarantee says nothing.

## The three candidates

1. **Opaque, Gleam-shaped.** `map<K, V>` with `Get`/`Put`/`Delete`/`Keys` as compiler-known
   functions and **no pattern form**. Records stay the only brace-pattern surface; the pattern
   grammar, the residual algebra and the catch-all rule are all untouched. Gleam's `Dict` is this,
   deliberately.
2. **Matchable, Erlang-shaped.** A pattern form in clause heads. Now known to be *possible* — the
   `Kind`-absent construction keeps it off records — at the price that matching a map proves
   nothing.
3. **Not at all.** `list<(atom, term)>` already carries the case that raised it.

## The bar this has to clear, and why it is not resolvable yet

**The destination is a clean-room spec.** Every construct is a section an agent fleet implements
from prose without David in the room, and a matchable map is the paragraph most likely to be got
wrong — it is the one place the language's headline promise goes quiet, and the reader has to be
told why without concluding the promise is soft everywhere.

So the test is the one that cut function values: [ticket 27](27-generics-and-parametricity.md) §(c)
was cut on three measurements and one of them was flatly **"no exemplar declares one"**
(→ [ticket 37](37-instantiation-by-matching.md)). Same test here.

**Blocked by evidence that does not exist yet.** The exemplar most likely to want a map is
**25a, the HTTP API server**, which is currently a router with no pipeline — and rewriting it as a
pipeline is precisely what ticket 31 just unblocked. Resolve this **after** that rewrite, and let
it answer from real code rather than from familiarity. Maps are extremely familiar from Elixir,
which is exactly why they would otherwise slip in without paying the toll.

## Not yet surveyed

The borrow heuristic wants all four sources and only one has been measured.

- **Gleam** — `Dict` is opaque and deliberately not matchable. *Why* is the most valuable
  unread thing here, because it is candidate 1 with the reasoning already done.
- **Erlang / Elixir** — matchable, and the `%{k := v}` / `%{k => v}` distinction between "must be
  present" and "may be" is a form beam-sharp has no equivalent of.
- **C#** — `Dictionary<K,V>` and the frozen collections; no pattern form worth borrowing, but the
  *naming* question (`map` versus `dict`) is a tier-1 borrow decision.

## Notes

Do not re-derive the record/map collision — it is measured above and it is not a problem. And do
not treat "Elixir has maps" as an argument; ticket 31 §6 is a worked example of a premise that
read as obvious and was wrong on inspection.
