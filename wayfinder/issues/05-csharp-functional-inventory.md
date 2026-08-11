# 05 — C# functional feature inventory: what survives without OOP and the CLR

Type: research
Status: open

## Question

Inventory C#'s functional features and classify each as:

- **(a) portable** to a no-OOP BEAM language essentially as-is,
- **(b) portable only in altered form** — say what alters and why,
- **(c) load-bearing on OOP or the CLR** and therefore droppable.

Cover at least: LINQ (both query-comprehension and method syntax) and its dependence on
`IEnumerable<T>`, extension methods and deferred execution; records and `with` expressions;
pattern matching and `switch` expressions including property, positional, list and
relational patterns; tuples and deconstruction; local functions; lambdas and delegates;
nullable reference types and null-state analysis; `readonly` and `init`; ranges and
indices; `async`/`await` and `Task`; iterators and `yield`; extension methods; generics and
constraints; collection expressions and spreads.

For each, state the BEAM equivalent or the obstacle. Note especially anything that depends
on **mutation**, on **interfaces as dispatch**, or on **lazy evaluation** — the BEAM is
immutable, has no interface dispatch, and is strict.

Also note which features exist principally because C# is object-oriented and would have no
reason to exist here.

Write findings to `wayfinder/research/05-csharp-functional-inventory.md` and link here.

## Notes

AFK. Feeds tickets 08, 14 and the fog around LINQ and pipelines.
