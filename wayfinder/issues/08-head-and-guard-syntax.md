# 08 — Multi-clause head and guard syntax

Type: grilling
Status: open
Blocked by: 01, 05

## Question

What is the concrete syntax for multiple clauses of one function, and for guards?

Decide:

- **Clause shape.** Does it reuse C#'s overload appearance — repeated
  `T Name(pattern) { ... }` declarations — or a single declaration containing an internal
  clause list, or something else? The overload shape is visually familiar but means one
  name has several declarations whose relationship is implicit; a clause list is explicit
  but less C#-like.
- **Patterns in parameter position.** How are literal, tuple, map, list and constructor
  patterns written where C# expects `Type name`? What happens to type annotations — are
  they per-clause, or declared once for the function?
- **Guards.** What is the keyword (`when`?), and what expressions may appear? The BEAM
  restricts guards to a small set of guard BIFs with no user function calls — so this is
  constrained by the platform, not just taste.
- **Ordering.** BEAM clauses are tried in order. Does the language preserve
  first-match-wins, and how does that interact with the exhaustiveness checker — does it
  also report redundant, shadowed clauses?
- **Arity.** BEAM identifies functions by name *and* arity. Must every clause of a function
  have the same arity? What becomes of C#'s optional parameters and overloads-by-arity?

- **List patterns.** Ticket 05 flagged that C#'s interior and suffix slice patterns
  (`[first, .., last]`) are not one-pass expressible over cons cells. Decide what subset of
  list patterns survives, and whether a non-one-pass pattern is permitted at a cost.

## Binding constraint from ticket 04 — signatures are not optional

**Exhaustiveness is only well-posed against a declared input type.** Redundancy is *relative*
(clause i against clauses before it); exhaustiveness is *absolute* (the union of clauses
against a domain someone hands you). Elixir cannot check exhaustiveness precisely because it
*builds* the function type as an intersection from the clauses themselves — checking the union
of clause domains against a domain defined as that same union is vacuous. CDuce can check it
only because functions carry a mandatory interface, and it checks once **per arrow** of that
interface.

So this language's headline guarantee **requires a signature on every multi-clause function**.
Inference alone does not weaken the guarantee — it makes the question disappear. This ticket
must therefore decide not only the clause syntax but **where the signature lives**: once above
the clause group, repeated per clause, or somewhere else. That is a language-surface decision,
not a type-theory one, which is why it lands here.

Note the knock-on: an interface may have **several arrows**, and the check runs per arrow. A
syntax that admits only one input type per function forecloses overloading across arrows.

## Prior art to consult first (from ticket 03)

- **Gleam prototyped this and dropped it silently.** An abandoned `examples/clauses.glm`,
  described by lpil as "an experiment to see how we could represent multiple function clauses
  without duplicating the name". No reason was recorded for dropping it. Worth finding and
  reading before designing from scratch — the phrasing suggests the sticking point was
  notational (name duplication), which is exactly this ticket's first decision.
- **Do not accept lpil's "no function overloading results in a much simpler language" as
  evidence about this feature.** It answers a question about same-name-different-arity
  overloading. Multi-clause heads are same name, *same arity*, one signature. Two independent
  searches flagged this conflation; expect to meet it again.
- ~~**purerl's successor backend compiles PureScript equations to native Erlang clause heads.**~~
  **Retracted by ticket 19** — it emits exactly one clause, always, with no guard. Read ticket
  19 instead: it is a **counter-example**, not a precedent, and it carries a guard finding that
  bears directly here. `purescript-backend-erl` emits **no guards at all** (`when` appears zero
  times across all 44 golden files). It carries a hardcoded 36-name whitelist — Erlang's guard
  set minus `is_record` — routing guard-legal conditions into an Erlang `if` and demoting
  everything else to `case Cond of true -> …`. That sidesteps the fail-to-false subtleties
  ticket 02 documents, at the cost of never using a guard. Decide deliberately whether to do
  the same.
- **Alpaca shipped a constructor-pattern-in-head parse ambiguity and never fixed it.** A
  concrete, known grammar hazard sitting exactly where this ticket designs. Find what the
  ambiguity was before choosing a clause syntax, not after.

## Notes

HITL. The headline feature's surface. Depends on ticket 01 for something concrete to react
to, and ticket 05 for what C# syntax is available to borrow.
