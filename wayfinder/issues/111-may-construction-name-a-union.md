# 111 — May construction name a union?

Type: grilling
Status: resolved 2026-09-28 — [ENG-554](https://linear.app/davewil/issue/ENG-554). Raised and
answered 2026-09-28 in one round, out of [ENG-493](https://linear.app/davewil/issue/ENG-493), which
says it needs a decision rather than a fix
Blocked by: —

## Why this is raised

[26](26-data-modelling.md) §2 settled that **construction names the type**: `Order { Id = "A-1" }`.
Every construction in `compiler/examples` names a `record`. No ticket has said what happens when
the name is a union alias, and today the compiler accepts it without checking anything. Measured at
`e1c5137`:

```csharp
module Billing

record Invoice { Id: string, Amount: int }
record Receipt { Id: string, Amount: int, PaidAt: int }
type Doc = Invoice | Receipt

public Doc Raise(string id, int amount)
Raise(id, amount) -> Doc { Id = id, Amount = amount }
```

```
$ bsc Billing Raise '"A-1"' 50
{Kind = :'Billing.Doc', Amount = 50, Id = "A-1"}
```

The value is neither an `Invoice` nor a `Receipt`. The emitter mints a tag from the alias name.
The clause-return check passes it because construction's type is read as the alias, `Doc`, and
not as what was built. `Doc { Id = 7 }` compiles as well, since no field is checked.

A hand-written union has the same gap:

```csharp
type Event = { Kind: :placed, OrderId: string } | { Kind: :shipped, OrderId: string, Carrier: string }

Placed(id) -> Event { Kind = :placed, Carrier = id }
```

This compiles, erlc warns `key 'Kind' will be overridden`, and it returns
`{Kind = :placed, Carrier = "A-1"}`, which is not an `Event`.

The cause is `bs_check:declared_fields/1`. It reads a field set only from a type with exactly one
map member and returns `unknown` for anything else. `unknown` then skips both the field-set check
and [36](36-field-value-obligations.md)'s field-value check.

Construction over a name with **one** member already works. `type Placed = { Kind: :placed,
OrderId: string }` followed by `Placed { OrderId = id }` returns `{Kind = :placed, OrderId = …}`,
with the tag read from the type, as F49 made construction do.

## Round 1

**Q1. May the name before `{` stand for more than one member?**

Each program below compiles under one answer and is refused under the other.

```csharp
public Doc Raise(string id, int amount)
Raise(id, amount) -> Doc { Id = id, Amount = amount }
```

**Under *no***, this is refused at the construction (the wording is proposed; nothing prints it
yet):

```
Billing/Billing.bs:8:22: error: Raise constructs Doc, which is a union
  Doc is one of:
    Invoice
    Receipt
  Construct the one you mean: Invoice { … } or Receipt { … }.
```

The fix is the program's own intent, and it compiles today:

```csharp
Raise(id, amount) -> Invoice { Id = id, Amount = amount }
```

A hand-written union has no record name to construct by. It uses F57's bare brace, which today is
already checked against the type the site expects (measured). `Placed(id) -> { Kind = :placed,
OrderId = id }` compiles against `Event`. `{ Kind = :placed, OrderId = 7 }` and `{ Kind = :placed,
Carrier = id }` are both refused by the return check.

**Under *yes***, `Doc { Id = id, Amount = amount }` compiles and builds an `Invoice`, because
`Invoice` is the one member whose field set is exactly `{ Id, Amount }`. Records do not write their
tag at construction, so the fields are all there is to choose by. Add `PaidAt = t` and it builds a
`Receipt`. With a third member, `record Credit { Id: string, Amount: int }`, the same line is
refused as ambiguous. That makes the construction's meaning depend on the other members of `Doc`,
and adding a member elsewhere can turn a compiling construction into a refused one.

**The compiler delta under *no*.** It is one refusal:

- In `record_construction/5`, a name whose resolved type has more than one map member is refused
  with a new `construct_union` diagnostic carrying the members.
- `bs_diag` prints the members by record name, and a hand-written member by its shape, as
  [109](109-a-kind-of-several-atoms.md) Q2 prints them (`bs_check:record_name/1`). The diagnostic
  also joins the `--diagnostics json` roster.
- The tests go through the CLI, plus a `diagnoses: construct_union` block in `LANGUAGE.md`, seen
  red first.
- The emitter is untouched, because the refused program never reaches it.

**The compiler delta under *yes*.**

- `declared_fields/1` gains a union case that picks the member whose closed field set equals the
  written keys, and refuses when none or several match.
- `type_of` returns that member, not the alias.
- The emitter must stamp the **chosen** member's tag. Today it resolves the tag from the name alone
  (`bs_emit:record_tag/2`), so it would need the checker's choice passed per expression. That is
  the per-expression type channel [80](80-does-an-int-flow-where-a-float-is-expected.md) records
  the emitter as not having.
- A hand-written member would need a written `Kind` to choose by. That reverses today's refusal of
  `Kind` at a construction (`Placed { Kind = :placed, … }` is refused as *"not declared by
  Placed: Kind"*).

➡️ **Recommended: no.**

- [26](26-data-modelling.md) §2 refused target-typing at construction on read cost. *Yes* is
  target-typing by field set: the reader has to know every member of `Doc` to know what `Doc { … }`
  builds.
- [109](109-a-kind-of-several-atoms.md) Q2 ruled that `Kind` says what a value *is* and that
  changing it is a named function constructing the other member. A construction that doesn't say
  which member it builds sits badly beside that ruling.
- Both repairs compile today.

**A1 (David, 2026-09-28):** *"No."*

The name before `{` stands for exactly one member. `Doc { … }` over a union is refused at the
construction, naming the members. A record member is constructed by its own name
(`Invoice { … }`), and a hand-written member by the bare brace, `{ Kind = :placed, … }`, which is
checked against the type its site expects.

## The compiler delta

- `bs_check:record_construction/5`: a name whose resolved type has more than one map member is
  refused with `construct_union`, carrying the name and its members. The field checks are not
  reached, because there is no single field set to check against.
- `bs_diag`: the message names the members, a record by its name and a hand-written member by its
  shape, as [109](109-a-kind-of-several-atoms.md) Q2 prints them (`bs_check:record_name/1`), and
  gives the repair for each kind. The tag joins the `--diagnostics json` roster.
- Tests go through the CLI and cover a union of records, a hand-written union in both
  [109](109-a-kind-of-several-atoms.md) spellings, and a union mixing the two. Beside them, a green
  control: `Placed { OrderId = id }` over a single tagged member still builds, with its tag read from
  the type. `LANGUAGE.md` gains a `diagnoses: construct_union` block, seen red first.
- `bs_emit` is untouched. The refused program never reaches `expr({e_record, …})`.

**As built (ENG-493, 2026-09-28).** A1 says a name stands for exactly one member, and the build
counts every member: map members, a `map<K, V>` member, and each non-map part. So
`type MaybeDoc = Invoice | :none` and `type N = int | :none` are refused too. That goes past the
delta's *"more than one map member"*, and the review of the build measured the narrower reading
building a wrong value in each of these cases (`option<Invoice>` built
`{Kind = :'Opt.MaybeDoc', …}`). Two members that share a tag would print alike by tag, so they
print in full.

## Not decided here

- [ENG-381](https://linear.app/davewil/issue/ENG-381): construction over an **untagged**
  single-member alias (`type Point = { X: int, Y: int }`, `Point { X = 1, Y = 2 }`) mints
  `Kind = :'M.Point'`, a key the type does not declare. That issue proposes refusing it as
  `not_a_record`. Q1 does not reach it, because `Point` names one member.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [May construction name a union?](issues/111-may-construction-name-a-union.md) — **no: the name
  before `{` stands for exactly one member, so `Doc { … }` over `Invoice | Receipt` is refused,
  naming the members, and the program constructs the one it means.** Raised and resolved 2026-09-28
  in one round, out of [ENG-493](https://linear.app/davewil/issue/ENG-493). Measured before asking:
  `Doc { Id = id, Amount = amount }` compiled, checked no field, and returned a value tagged
  `:'Billing.Doc'`, which is neither member, and the clause-return check passed it because
  construction's type was read as the alias. The hand-written union's `Event { Kind = :placed,
  Carrier = id }` compiled the same way. The *yes* reading would have chosen the member by field
  set, which is the target-typing [26](issues/26-data-modelling.md) §2 refused on read cost. It
  would also have needed a per-expression channel from the checker to the emitter, which
  [80](issues/80-does-an-int-flow-where-a-float-is-expected.md) records the emitter as lacking.
  Both repairs compile today: a record by its name, and a hand-written member by F57's brace,
  already checked against the expected type. This sits beside
  [109](issues/109-a-kind-of-several-atoms.md) Q2, where a construction says which member a value
  is. Not decided here: construction over an untagged single-member alias, which is
  [ENG-381](https://linear.app/davewil/issue/ENG-381). Unbuilt:
  [ENG-493](https://linear.app/davewil/issue/ENG-493).
```
