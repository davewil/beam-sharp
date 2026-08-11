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

## Notes

HITL. The headline feature's surface. Depends on ticket 01 for something concrete to react
to, and ticket 05 for what C# syntax is available to borrow.
