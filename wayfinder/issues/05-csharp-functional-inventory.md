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

## Correction from ticket 16 — 2026-08-12

**The "two debts" above is one debt.** This ticket recorded that *"dropping extension methods
**and** static abstract interface members leaves no ad-hoc polymorphism story."* Raised by David
while resolving [ticket 16](16-ad-hoc-polymorphism.md): extension methods extend *class types* in
C#, and that has no meaning in a functional language.

C# needs them because a type's methods are sealed inside its declaration — you cannot add to
`string`. beam-sharp has no methods on types at all; every operation is already a free function
taking the value, so "extend a type you do not own" is the default, not a feature.

The two genuine halves split, and **neither is ad-hoc polymorphism**:

- **Call syntax** (`xs.Where(f)`) — this ticket already found it is a static rewrite
  `C.M(expr, args)` and *is* the pipeline → [ticket 17](17-pipeline-and-comprehension.md), which
  has owned it all along.
- **Overloading** (same name, different types, resolved by static type) →
  [ticket 08](08-head-and-guard-syntax.md), already settled: one arrow per arity, union
  parameters, no overload signatures.

**Static abstract interface members were the whole of the real hole**, and ticket 16 §1 fills it:
a **codegen obligation is a static abstract interface member with the compiler writing the
implementation**. `ValidateAs<T>` is `T.TryParse` where no type had to declare it.

One leftover that is *not* polymorphism: C# lets you put a function in another namespace so it
appears on that type without an import. That is name resolution → the map's **imports and
cross-module scope** fog.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [C# functional feature inventory](issues/05-csharp-functional-inventory.md) — LINQ query
  comprehension is portable (ECMA-334 makes it a pure syntactic rewrite, bound before type
  binding, with no `IEnumerable<T>` dependency); extension-method chaining *is* already a
  pipeline rewrite; `with` becomes more central than in C#. Dropped: `init`/`readonly`,
  nullable reference types, iterators and `async`/`await`. Two debts left open — no ad-hoc
  polymorphism story, and slice patterns over cons cells.
```
