# 05 — C# functional feature inventory: what survives without OOP and the CLR

Type: research
Status: resolved

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

## Answer

Full inventory: [research/05-csharp-functional-inventory.md](../research/05-csharp-functional-inventory.md)
— five grouped tables over ~45 features, plus a 43-row claim→source table.

**LINQ is three separable things and only one is a language feature.** ECMA-334 §12.22.3.1
says the query translation "is a syntactic mapping that occurs **before any type binding or
overload resolution** has been performed", and `IEnumerable<T>` appears in the query-expression
pattern only in a *note* about what `System.Linq` provides. Query comprehension is therefore
**portable** — it needs a rule for resolving eleven names, nothing more. Deferred execution
belongs to the operator implementations, not the language, and becomes an explicit stream type.
Extension-method invocation is a static rewrite `C.M(expr, args)`, so the fluent chain
**already is a pipeline**: `xs.Where(f)` and `xs |> where(f)` are the same rewrite.

**Portable**: tuples/deconstruction, most patterns, lambdas, local functions, collection
expressions and spread — plus `with`, which becomes *more* central here than in C#.
**Droppable**: `init`/`readonly`/`required` (vacuous under immutability), extension members,
primary constructors, nullable reference types, static abstract interface members, and both
compiled-state-machine features (iterators, `async`/`await`). **Altered with real loss**: type
patterns, `when` guards, `params`/optional parameters (they collide with name+arity identity),
ranges and indices. Two debts flagged not resolved: dropping extension methods *and* static
abstract interface members leaves no ad-hoc polymorphism story; interior/suffix slice patterns
aren't one-pass expressible over cons cells. C# 15 (preview) changes no verdict.

## Notes

AFK. Feeds tickets 08, 14 and the fog around LINQ and pipelines.
