# 36 — Is the value assigned to a field checked, and is `with` a sixth site?

Type: grilling
Status: **open** — raised 2026-08-14 from building
[F5](../../compiler/features/F5-body-check-site.md)

## Question

F5 built [ticket 33](33-body-check-site.md)'s five obligation sites. Two expressions now type-check
that plainly should not:

```csharp
record Order { Id: int, Total: int }

Order Make(int n)
Make(n) -> Order{ Id = :oops, Total = n }      // compiles

Order Bump(Order o)
Bump(o) -> o with { Total = :oops }            // compiles
```

`Id: int` is a **declared type**, and `:oops` is a synthesised one meeting it. So: **is a field
assignment a check site — at construction, at `with`, or at neither?**

## Why this is a ticket and not more of F5

Because ticket 33 answered a question adjacent to this one and the two answers point different
ways, which is the bar this map sets.

- 33 §1's **principle** is *"a check runs wherever a declared type meets a synthesised one"*, and a
  record field declaration is exactly that.
- 33 §2's **enumeration** gives site 2 the relation *"supplied field set **=** declared field set"*
  — a statement about names — and §4 elaborates only the name delta. It then closes with *"there is
  no sixth site because there is no sixth place a type is written"*.

F5 implemented the enumeration, because a feature implements and does not decide. The principle and
the enumeration disagree here, and picking between them is a decision.

## The two halves are not the same question

**Construction** is arguably *inside* site 2 — `Order{ … }` is one expression meeting one
declaration, and F5 already computes the declared field types to answer the name delta. The
supplied values are sitting right there unchecked.

**`with` is a genuine sixth site by 33's own counting rule.** 33 §1 characterises `e_with` as
synthesising *"the base's type, unchanged — `with` is width-preserving (26 §2)"*, and gives it no
row in the table. Adding one contradicts the sentence that closes §2.

Answering "yes" to construction and "no" to `with` is defensible and reads badly:
`Order{ Total = :oops }` rejected, `o with { Total = :oops }` accepted, for a reason the author
cannot see from the surface. That asymmetry is the actual cost to weigh.

## What is already decided — do not re-raise

| Decided | By |
|---|---|
| A record IS a closed map type; its field set is exact | [26](26-record-and-aggregate-surface.md) §4 |
| `with` is width-preserving and cannot add a field | [26](26-record-and-aggregate-surface.md) §2 |
| Synthesis is total over the twelve forms; obligation is a fixed list | [33](33-body-check-site.md) §1 |
| The analysis is function-local | [18](18-boundary-defence.md) §4 |

## The compiler delta, if the answer is yes

Small, and stated so the ticket is not answered on cost. F5 already resolves the declared field
types (`declared_fields/1` reads the same map) and already synthesises every assigned value —
`type_of/3` walks them today purely to collect diagnostics from nested expressions:

```erlang
%% NEW, in the e_record clause and again in e_with — one containment per field
%% against the type the record declaration wrote down.
{field_value_not_accepted, Record, Field, Residual}
```

The residual is a type, so the existing printer renders it and ticket 23 is satisfied without a
new shape of diagnostic. **Nothing new in `bs_types`.**

## Notes

Blocked by nothing. Worth answering **before angle brackets**, for the same reason 33 was: an
`option<T>` field multiplies the assignments this question is about.

**Do not re-derive whether a record's field set is exact.** 26 §4 settled it and F5 enforces it.
This ticket is about the *values*, not the *names*.

**Linear**: [ENG-203](https://linear.app/davewil/issue/ENG-203). Verified against the workspace
rather than derived: ticket 35 is ENG-202, so the *"from 33 it is ENG-(167+NN)"* offset does still
hold here — but it was checked, because the map's own instruction is to verify the arithmetic and
the rule has already broken once.
