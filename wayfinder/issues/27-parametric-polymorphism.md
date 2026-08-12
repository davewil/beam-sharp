# 27 — Parametric polymorphism: does the language have generics at all?

Type: grilling
Status: open
Blocked by: 09

## Question

Split out of [ticket 11](11-type-system-shape.md) on 2026-08-12, which was the keystone and held
at least six decisions. Ticket 11 kept the `dynamic` boundary, the subtyping relation and the
guarantee; this ticket takes the generics half.

Decide:

- **Does the language have parametric polymorphism at all?** Ticket 09 made types structural and
  open, and set-theoretic unions express a great deal without type variables. Ticket 11 removed
  `dynamic` entirely, so the usual "generic or dynamic" pressure valve is gone in both
  directions. Establish whether type variables are needed before deciding how they are spelled.
- **Generic syntax**, if so. C# angle brackets are the obvious tier-1 borrow and TypeScript
  spells them identically, so this is likely cheap — but confirm it against the parser
  consequences (`<` is also a comparison operator, and ticket 08 settled `&&`/`||` guards).
- **Parametric aliases.** This is the concrete debt. Ticket 10 §5 put
  `type option<T> = T | :nothing;` in the prelude, which assumes the single naming construct
  from ticket 09 admits type parameters — that is, that an alias may be a **type-level
  function**. Ticket 09 already writes `list<Json>` and `map<string, Json>`. Decide whether
  parametric aliases exist, and if so whether they may be recursive.
- **Variance**, if type variables exist. Arrow subtyping is already contravariant in the
  argument (verified in ticket 11: `subtype?(fn(int)->int, fn(none)->term) = true` but
  `subtype?(fn(int)->int, fn(term)->term) = false`). Whether variance must ever be *stated* by
  the user is the open part.

## Binding constraints

- **`ParseAtom<T>` and `ValidateAs<T>` are not evidence that generics exist.** Both are
  type-directed **codegen obligations** — ticket 10 established the first, ticket 11 the second.
  `<T>` there is a compile-time argument driving generation, monomorphic at every use site, with
  no type variable surviving into the runtime or the type algebra. If this ticket decides the
  language has no parametric polymorphism, both mechanisms still stand unchanged.
- **Recursive *and* parametric together is the dangerous combination.** Ticket 11's §"Constraints
  from ticket 09" records that Elixir's roadmap calls this the combination that is unfeasible to
  get wrong, and ticket 09 already committed the language to the recursive half (equirecursive,
  contractive, subtyping decided coinductively). So the cost of saying yes here is not the cost
  of generics in isolation.
- **Tallying is the relevant algorithm**, not unification — ticket 04 found no complexity bound
  for it exists in the literature at all.

## Notes

HITL. This ticket is **ticket 16's blocker in place of ticket 11** — ad-hoc polymorphism cannot
be settled without knowing whether type variables exist. It also owns the parametric-alias
question outright, so [ticket 26](26-data-modelling.md) should not decide it.

## Constraints from ticket 13 — resolved 2026-08-12

**Ticket 13 §6 supplies the publication half of the codegen-obligation story.**

`ParseAtom<T>` and `ValidateAs<T>` are monomorphic at every use and are *generated*, not written —
this ticket exists partly to keep them from being mistaken for evidence of generics. Ticket 13 rules
that the compiler emits a `-spec` for every function whose beam-sharp type is known, **widening to
the nearest expressible supertype** where a set-theoretic type has no Erlang spelling (Erlang's spec
grammar has no negation, and expresses intersection only as an overloaded spec).

So what a codegen obligation publishes to the Erlang world is a **widened monomorphic spec**, never
a generic one — which is consistent with, and further evidence for, the position this ticket is
likely to take. Worth confirming rather than assuming when this ticket is resolved.
