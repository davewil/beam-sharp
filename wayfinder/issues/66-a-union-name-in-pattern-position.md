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

## What F53 changed, 2026-09-19

**Item 2 above is now the live framing, and half of it is answered.** F53
([ENG-394](https://linear.app/davewil/issue/ENG-394)) shipped
[ticket 84](84-dispatching-the-parts-of-a-numeric-union.md)'s type prefix over a **part** —
`Post(float a)` — so "any named type in pattern position" is no longer the generalisation of one
special case but of two: ticket 55's record, and now the part. The rule the part carries is that
one BEAM test must decide the type named, which is why `list<int>` is refused and `atom` is not.

It does **not** answer this ticket. The part prefix is lowercase-only, so no `uident` reaches it
and every exemplar above behaves exactly as it did at `6728799` — with one textual exception:
**exemplar 3's diagnostic gained a line**, naming the spelling that now exists, so the quoted
output above is the pre-F53 wording. Today:

```
error: C is not a record, so it cannot name a pattern
  only a `record` declaration mints the tag a type prefix matches on.
  a part is named by the part: `Post(int n)` beside `Post(float f)`,
  one clause each.
  to constrain fields without naming a type, write `{ Field: ... }`.
```

The same generalisation is asked from the other side by
[ticket 85](85-which-names-may-wear-the-type-prefix.md)
([ENG-395](https://linear.app/davewil/issue/ENG-395)), which covers an alias to a part union and
a refinement and explicitly does not re-ask the record union here. If either is answered as a
rule about names, the other is inside it and the two resolve together.

## Round 1 — 2026-11-14

Measured on Erlang/OTP 28.5 (erts 16.4, built from `otp_src_28.5`, the pinned release) with rebar3
3.27.0, against an unmodified `compiler/` at `f8fa100`. The probes are
[`66a`](../prototypes/66a_union_name_in_pattern.sh) and
[`66b`](../prototypes/66b_yes_target.erl); their full output is in
[the research file](../research/66-a-union-name-in-pattern-position.md).

**Every exemplar above still behaves as recorded at `6728799`.** No later ticket settles this one.
[111](111-may-construction-name-a-union.md) refused a union name before `{` in **construction**,
because there the name would have to *choose* a member. A pattern chooses nothing: it tests which
member arrived. So 111's reason does not reach this question, and its entry does not claim to.

### The program

```csharp
module Ledger

record CardPaid { Id: int, Amount: int }
record BankPaid { Id: int, Amount: int }
record Refunded { Id: int, Amount: int }

type Payment = CardPaid | BankPaid
type Event   = CardPaid | BankPaid | Refunded

public int Delta(Event e)

Delta(Payment p)  -> p.Amount
Delta(Refunded r) -> 0 - r.Amount
```

Today this is refused, `rc=1`:

```
l.bs:13:7: error: Payment is not a record, so it cannot name a pattern
  only a `record` declaration mints the tag a type prefix matches on.
  a part is named by the part itself, lowercase — one clause taking
  `int` beside one taking `float`.
  to constrain fields without naming a type, write `{ Field: ... }`.
```

What the program has to say instead, one clause per member with the body repeated, compiles
today and emits:

```erlang
'Delta'(P = #{'Kind' := 'Ledger.CardPaid'}) -> map_get('Amount', P);
'Delta'(P = #{'Kind' := 'Ledger.BankPaid'}) -> map_get('Amount', P);
'Delta'(R = #{'Kind' := 'Ledger.Refunded'}) -> 0 - map_get('Amount', R).
```

**Q1. Does `Delta(Payment p)` compile, with `p` typed `Payment` and the clause matching
exactly the members of `Payment`?**

This is the gating question. Three of this ticket's four open items follow from it and are not
asked here: how the residual prints (item 1), whether a union that mixes records with an atom
also qualifies (item 2), and the collapse interaction (item 4). Item 3, whether exemplar 5's
unreachable clause is an error, is independent and is left for its own round.

### What each answer does

**Yes.** The program above compiles. `p.Amount` checks as it already does when `Payment` is the
declared input (exemplar 1, `rc=0`, emits one `map_get`). `Delta` emits one clause for the
union, a map match that binds the tag and a guard that names the members:

```erlang
'Delta'(P = #{'Kind' := K}) when K =:= 'Ledger.CardPaid'; K =:= 'Ledger.BankPaid' ->
    map_get('Amount', P);
'Delta'(R = #{'Kind' := 'Ledger.Refunded'}) ->
    0 - map_get('Amount', R).
```

`66b` is that module written by hand. It compiles under `+warnings_as_errors` on 28.5, returns
5, 7 and -4 for the three members, and raises `function_clause` for a fourth record. Drop the
`Refunded` clause and the exhaustiveness error is unchanged: `Delta(Refunded r) -> ...`.

The compiler gains:

- `bs_check:record_union_of/3`, beside `record_of/3` (`bs_check.erl:1860`). It resolves an
  alias whose every member is a closed map with a singleton `Kind`, and returns the members'
  tags. `record_pattern_type/3` (`bs_check.erl:4977`) calls it when `record_of/3` would raise
  `not_a_record`, and types the pattern as the union of the members' open maps, so
  exhaustiveness subtracts it with no new code.
- In `bs_emit:desugar/2` (`bs_emit.erl:539`), a `p_rec` over such an alias becomes
  `p_alias(V, p_map[{'Kind', p_var(K)}])` and hands up a guard `K =:= T1 orelse …`. The guard
  goes through the channel `guard_one/7` (`bs_emit.erl:274`) already uses for `tag_test`, and
  it is joined with `andalso` to any `when` the clause writes.
- A field-constrained form, `Payment { Amount: 0 } p`, is refused until it is asked:
  `pattern_field_unknown` already has the field list to say so.
- The grammar takes no change. `Payment p` already parses, and the refusal is the checker's.
- A gated `LANGUAGE.md` block holding the program above.

**No.** The program stays refused, and the per-member spelling stays the idiom. The compiler
gains one diagnostic. When the alias resolves to a union of records, `not_a_record` is
replaced by a new tag, `union_in_pattern`, rendered in `bs_diag.erl` beside `not_a_record`
(`bs_diag.erl:562`, `:1896`). It names the members and prints the clauses to paste:

```
error: Payment is a union, and a pattern names one record
  write one clause per member:
    Delta(CardPaid p) -> ...
    Delta(BankPaid p) -> ...
```

`check-residual-pasteable.sh` would replay those lines, since it already replays every printed
head.

### Recommended answer

Yes. The checker already types and subtracts the union, and the emitter already has a guard
channel to test it in one clause. Refusing it costs every program one repeated body per member,
and that cost grows with the union.
