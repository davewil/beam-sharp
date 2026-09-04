# 66 — Can a union name a pattern? `Handle(C c)` where `type C = A | B`

Type: grilling
Status: open — [ENG-309](https://linear.app/davewil/issue/ENG-309)

Raised 2026-09-02 by David, while [ENG-263](https://linear.app/davewil/issue/ENG-263)'s mutation
stage was being built. Every verdict below was measured at `6728799` against a built `bsc`, not
inferred from the grammar.

## Question

**May a named union stand in pattern position, and what happens to a value that cannot be a
member?**

David's framing: *"`Handle(C c)` is whatever the union of A and B are, but pattern matching from
`C` should error if not in the union."*

[Ticket 55](55-destructure-and-bind.md) settled the **record** type prefix —
`Frame { Type: :method } f`, and `Frame f` when only the type matters. It is silent on union
aliases. ticket 28's entry's *"matching a variable inside a union is undecided"* is about generic
type variables and belongs to [ticket 37](37-instantiation-by-matching.md), not here.

## The exemplars

```
record A { Id: int }
record B { Id: int }
record E { Id: int }

type C = A | B
type D = A | B | :none
```

| # | exemplar | today |
| -- | -- | -- |
| 1 | `public int Take(C c)` + `Take(c) -> c.Id` | **compiles** |
| 2 | `Bad() -> Take(5)` — a non-member at a call site | **refused** |
| 3 | `public atom Handle(D d)` + `Handle(C c) -> ...` | **refused** |
| 4 | `Handle(A a)` and `Handle(B b)`, bodies duplicated | compiles |
| 5 | `public atom Bad(C c)` + `Bad(E e) -> :e` | **warning only, `rc=0`** |

Exemplar 2:

```
error: Bad hands Take an argument it does not accept
  argument 1 is not covered by Take's declared type:
    5
```

Exemplar 3:

```
error: C is not a record, so it cannot name a pattern
  only a `record` declaration mints the tag a type prefix matches on.
  to constrain fields without naming a type, write `{ Field: ... }`.
```

Exemplar 5:

```
warning: clause 3 of Bad matches no value of its input
  the declared input is ({ Kind: :'T6.A' } | { Kind: :'T6.B' }), and this clause's pattern is not
  a member of it — so no call can reach this clause.
```

## What the exemplars show

**The plain case is already served, and needs no new syntax.** Exemplars 1 and 2: when the union
*is* the parameter type, the declaration carries the constraint and the head simply binds. A
non-member is refused at the boundary. `shop.bs:28` is this today — `Amount(d) -> d.Total` over
`Doc = Order | Invoice`. So half the raised question is answered by the language as it stands, and
`in C` is spelled by the signature rather than by the pattern.

**The gap is a union inside a wider parameter.** Exemplar 3: where the parameter is wider than the
union being selected, naming `C` is a real discriminator and not a restatement of the signature —
and it is refused. The cost is exemplar 4: the body is duplicated once per member, scaling with the
size of the union. A five-member union means five identical right-hand sides.

**The raised requirement is half-met, and the missing half is a severity.** Exemplar 5: the
compiler already *detects* a clause that no call can reach, and names the reason precisely. But it
warns and exits 0, where the ask is that it error. That is a smaller change than exemplar 3 and
does not depend on it.

Worth noting on the side: exemplar 5's message names the union in **erased notation**
(`{ Kind: :'T6.A' } | { Kind: :'T6.B' }`) rather than as `C`. That is
[ENG-307](https://linear.app/davewil/issue/ENG-307)'s complaint — the surface making an erasure
detail load-bearing — appearing in a diagnostic rather than in source.

## The compiler delta, if it is taken

- The type-prefix production accepts a `record` name only (ticket 55 / F22), and anything else
  raises `not_a_record`, rendered at `bs_diag.erl:952`. Supporting exemplar 3 means resolving the
  name and, for an alias naming a union of records, lowering `C c` to a disjunction over the
  members' minted tags with `c` bound to the whole value.
- Exhaustiveness needs nothing new: it already subtracts unions.
- Exemplar 5 is an independent severity change.

## What must be decided, not assumed

1. **Does the residual print `C c`, or the members spelled out?** The printer has no way to name an
   alias today, and `check-residual-pasteable.sh`'s `RecordUnion` shape pins the current answer, so
   this decision moves a gate.
2. **Only all-record unions, or any named type?** `D = A | B | :none` mixes a record union with an
   atom. Admitting it generalises the question to *any named type in pattern position*, of which
   ticket 55's record prefix is the special case already built — which may be the better framing of
   the whole ticket.
3. **Is exemplar 5 an error or a warning?** Raised as an error. Weigh against ticket 12 §2 and
   whatever else in the compiler warns rather than refuses.
4. **Does it interact with ticket 15 §1's collapse refusal?** A named union is enumerable, so
   probably not — but that has not been measured, and saying so without measuring is the habit this
   project keeps paying for.

## Not in this ticket

The corpus writing the minted tag by hand in pattern position is
[ENG-307](https://linear.app/davewil/issue/ENG-307). That is a cleanup against a decision already
taken; this ticket is a decision not yet taken.
