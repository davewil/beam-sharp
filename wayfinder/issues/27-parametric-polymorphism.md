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

## Constraints from ticket 14 — resolved 2026-08-12

**A motivating case has been removed.** Ticket 03 recommended `Pid[τ]` — a process identifier
parameterised by the message type it accepts — and it was one of the clearest demands in the map
for a genuine type parameter. Ticket 14 §1 **declines it**, on three grounds:

1. It is not expressible. Ticket 09 makes types sets of values with no nominality, so
   `pid<Order.Msg>` and `pid<Payment.Msg>` denote the same set and are therefore the same type.
   Gleam can carry the phantom parameter only because its type system is nominal — `subject(τ)`
   lowers to `{subject, Pid, Ref}` with τ erased.
2. It is not needed. The message type belongs on the client API function's signature, which is
   where it was going to be written anyway.
3. It would not buy soundness, since ticket 21 rules out ruling out foreign senders.

So this ticket decides generics on the remaining evidence — `option<T>`, `ParseAtom<T>`,
`ValidateAs<T>` — which ticket 11 already flagged as **type-directed codegen rather than
generics**. With `Pid[τ]` gone, there may be no surviving case that demands parametric
polymorphism proper, which materially changes this ticket's default answer.

**A phantom-parameter carve-out was considered and rejected** in §1, so if this ticket revisits
phantom types it is reopening 14's first decision, not deciding fresh ground. The recorded
alternative there is a *tagged handle* `(:order_msg, pid)` — an atom singleton per ticket 10
making the two handles genuinely different sets — which is the non-generic way to get the same
distinction and remains available.

## Input from David — 2026-08-12

> "Generics in Elixir are modelled via protocols and behaviours. I don't think generics are
> particularly required on BEAM, think `Enum`, `Stream` etc."

**Half of this is already banked, and the other half is contradicted by `Enum`'s own spec.**
Both measured locally (Elixir 1.19.5, Gleam 1.18.1, OTP 28).

**Ad-hoc polymorphism — agreed, and ticket 09 settled the mechanism.** `Enumerable` is a genuine
protocol with four callbacks (`count/1`, `member?/2`, `reduce/3`, `slice/1`), dispatching on
`__struct__` — an atom *in the data*, which is precisely ticket 09's remedy and ticket 16's
resolution key. No type parameters are involved anywhere in it.

**Parametric polymorphism — `Enum` is evidence the other way.** Its real spec, read from the beam:

```
Enum.map/2 :: map(t(), (element() -> any())) :: list()
              element() :: any()
              t()       :: Enumerable.t()
```

Elixir does not *avoid* the type parameter; it **discards the information**. `map` cannot relate
the output list's element type to the input's, so it says `list()` and stops. That is free in a
dynamically typed language because there was no static element type to lose. Gleam — the
statically typed BEAM neighbour — keeps it, and the parameter survives into the emitted Erlang:

```gleam
pub fn map(list: List(a), with fun: fn(a) -> b) -> List(b)
```
```erlang
-spec map(list(ACJ), fun((ACJ) -> ACL)) -> list(ACL).
```

So the split is **static versus dynamic, not BEAM versus not**, and beam-sharp is on Gleam's side
of it.

**Why the cost lands harder here than elsewhere.** Without type variables, `Map` is
`(list<term>, term -> term) -> list<term>` — and ticket 11 makes a `term` the thing you must
narrow with a clause head before use. Mapping over a list of orders would return something the
caller has to re-validate. The tax falls on the commonest operation in the language, not on an
exotic corner.

**The real argument in the neighbourhood, which this ticket should weigh.** Polymorphic
set-theoretic types are exactly where **tallying** is required, and ticket 04 found tallying has
**no complexity bound in the literature**. So parametric polymorphism may be the feature that makes
checker cost unpredictable — a cost argument, not a platform one.

**And the middle path**, already gestured at by ticket 11 when it called `ParseAtom<T>` and
`ValidateAs<T>` "type-directed codegen, not generics": **monomorphise per call site**. That
preserves element types without asking the checker to solve for a variable. Note the prelude's
`option<T>` (ticket 10) is already parametric *syntax* — whether it denotes real polymorphism or
expansion is exactly what this ticket decides.

**Do not re-derive**: ticket 14 already removed `Pid[τ]`, the map's clearest demand for a genuine
type parameter. Collections are now the strongest surviving case, so this ticket largely turns on
what the type of `Map` is.
