# 47 — Does `using` get an alias, now that unqualified names are legal?

Type: `wayfinder:decision`
Status: open — [ENG-219](https://linear.app/davewil/issue/ENG-219)
Raised by: [ticket 41](41-imports-and-cross-module-scope.md) on resolving it, 2026-08-16
Blocks: nothing — 41 resolved without it

> **The ticket-to-issue arithmetic is dead and this is another data point.** 47 is ENG-219, read
> from Linear rather than computed. 42→212, 43→213, 44→215, 45→216, 46→218, 47→219.

## Question

C# has three import tiers. Ticket 41 §5 settled the first two:

```csharp
using Shop;                  // → Orders.All()   short-qualified   §5
using Shop.Orders;           // → All()          unqualified       §2
using Orders = Shop.Orders;  // → Orders.All()   ALIAS — this ticket
```

**Does the third one exist?**

## Why it is open on new grounds rather than merely un-answered

Ticket 41 parked this deliberately and said why, and the *why* is what makes it a live question
rather than a leftover:

> While the qualified form was on the table an alias was a pure read cost, because the reader had to
> find the alias line; now that unqualified names are legal, an alias is strictly **more** explicit
> than the thing it competes with. That is a different argument from the one that shelved it, so it
> should be re-asked rather than inherited.

The argument that shelved an alias was **read cost** — `List.Fold(…)` sends the reader hunting for
what `List` is bound to. That argument assumed the alternative was a *qualified* name, which carries
its source in the call. §2 changed the alternative: the competing form is now a **bare** `Fold(…)`
brought in unqualified, which carries no source at all.

So the comparison has inverted. Against a bare unqualified name, an alias is the form that says
where the name came from.

## What this ticket owes

1. **Whether the alias exists at all.** It is a tier-1 borrow (C#) and a tier-1 borrow for the
   TypeScript half of the audience too (`import { Fold as ListFold }`), so the design heuristic
   supplies it cheaply — but the heuristic's own amendment says survey all three tiers and take the
   most accurate word, not take the highest tier that fits.
2. **Whether it aliases a module, a function, or both.** C# aliases a type or namespace;
   TypeScript's `as` renames an imported *binding*. §2's import tables are keyed differently for
   each — `{Name, Arity} -> Module` for functions, `Orders -> 'Shop.Orders'` for modules — so this
   decides which table an alias writes into, and whether both.
3. **How it interacts with §2's ambiguity rule.** A name reachable from two sources is an error at
   the call site printing the qualified candidates. An alias is a third source. Does aliasing
   *resolve* an ambiguity (the obvious use — two modules both exporting `Orders`), and if so it is
   not a convenience but the **only** spelling for that program.
4. **Whether the exemplars need it.** They write `List.Fold(…)` and `Orders.All()`. §5's
   short-qualified tier already covers both without an alias, which is why 41 could resolve without
   this. Measure before assuming a need.

## What it does not owe

**Not §2 or §5 reopened.** Unqualified names and the namespace rule are settled. This asks only
whether a *third* spelling joins them.

**Not a renaming rule for anything but imports.** `type X = …` is ticket 09's single naming
construct and is not touched here.
