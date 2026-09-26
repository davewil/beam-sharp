# 109 — A `Kind` of several atoms: shorthand for a union of tagged members, or refused?

Type: grilling
Status: resolved 2026-09-26 — [ENG-492](https://linear.app/davewil/issue/ENG-492). Raised and
answered 2026-09-26 out of [ENG-491](https://linear.app/davewil/issue/ENG-491); two rounds, the
second raised when the build's review found Q1's framing false for `with`
Blocked by: —

## Why this is raised

[101](101-what-closes-a-residual.md) decided that a record member closes on its tag. ENG-402 built
that as *a closed map member whose `Kind` is a single atom*. A `Kind` holding two atoms is no
single tag, so the member's `int` field reopens it, and two spellings of the same type now answer
differently. Measured at `2c6783c`:

```csharp
module Joined

type Doc = { Kind: :invoice | :receipt, Id: int }

public atom Which(Doc d)
Which({ Id: 0 }) -> :zero
Which(_)         -> :other
```

compiles.

```csharp
module Split

type Doc = { Kind: :invoice, Id: int } | { Kind: :receipt, Id: int }

public atom Which(Doc d)
Which({ Id: 0 }) -> :zero
Which(_)         -> :other
```

is refused, `Which discards cases the compiler can name`, naming `Which({ Kind: :invoice })` and
`Which({ Kind: :receipt })`. For closed maps the two types have the same inhabitants. Subtraction
already splits `Joined` once a clause narrows `Kind`: `Which({ Kind: :invoice, Id: i })` followed
by `_` is refused naming `{ Kind: :receipt }`. So today whether `_` is legal depends on which
clause came first.

David raised the direction on 2026-09-26: that the tag should only ever be one atom, perhaps under
a reserved spelling such as `__Kind__`, after Elixir's `__struct__`.

## Q1 — Is a `Kind` of several atoms a type a program may write?

There are two answers, and they differ in what a program may write. Under one, `Joined` is refused
at its declaration and `Split` is the only spelling. That is a new rule on the tag key, where
[26](26-data-modelling.md) §1 made the tag *"sugar over a writable field"* and
[73](73-a-record-name-crosses-using.md) Q1 has the compiler refusing the raw key nowhere. Under the
other, a `Kind` of several atoms is read as the union of one tagged member per atom. `Joined` then
*is* `Split`, and every program that compiles today still compiles.

**A1 (David, 2026-09-26):** *"Shorthand for union."*

So `{ Kind: :invoice | :receipt, Id: int }` means `{ Kind: :invoice, Id: int } | { Kind:
:receipt, Id: int }`, everywhere a type is read: openness, subtraction, the residual's printed
heads, and the emitted spec. Each case is still named by one atom, which was the aim of the
reserved-tag direction, and the key stays the ordinary key 73 Q1 made it.

## Round 2, Q2: may `with` move a value from one member of its type to another?

Asked 2026-09-26. Q1's framing said *"every program that compiles today still compiles"*, and that
is false. The cold review of the ENG-491 build (`22f7952`) found this program:

```csharp
module Reissue

type Doc = { Kind: :invoice | :receipt, Id: int }

public Doc Settle(Doc d)
Settle(d) -> d with { Kind = :receipt }
```

It compiles at `2c6783c`, before the build. After it, the program is refused:

```
Reissue/Reissue.bs:6:16: error: Settle assigns Kind a value invoice does not accept
  not covered by the declared type of Kind:
    :receipt
```

[36](36-field-value-obligations.md) checks a `with` against the type the declaration wrote down.
Written joined, that type is `Kind: :invoice | :receipt`, and it accepts `:receipt`. Expanded, `with`
checks each member on its own, and the `invoice` member refuses `:receipt`. The split spelling,
`{ Kind: :invoice, Id: int } | { Kind: :receipt, Id: int }`, was already refused at `2c6783c`. So
Q1's answer made the joined spelling behave as the split one did, and no ticket has decided what
`with` does across the members of a union.

Under one answer, `Settle` compiles in both spellings. The split spelling, refused today, becomes
legal. The compiler delta: `e_with` checks the updated value against the whole declared type,
rather than against each member it started in. Under the other answer, `Settle` is refused in both
spellings, as the build has it. A program that compiled at `2c6783c` stops compiling, and the
message must stop printing the tag `invoice` where a record's name goes.

The question was put to David as a domain-modelling question. Records already refuse the
cross-member `with`: `d with { Kind = :'Morph.Receipt' }` over `Invoice | Receipt` is refused
at `2c6783c` (*"assigns Kind a value Invoice does not accept"*). So a *yes* would reach records
too, and settling an invoice could be written as a field edit instead of as the construction
`Settle(Invoice { Id: id, Amount: a }, at) -> Receipt { Id = id, Amount = a, PaidAt = at }`. A
state that is an attribute of one thing (`record Order { Id: int, Status: :draft | :sent }`,
`o with { Status = :sent }`) compiles under either answer.

**A2 (David, 2026-09-26):** *"no"*: in a language enforcing DDD's ubiquitous language, bounded
contexts and anti-corruption layers, `with` may not move a value from one member of its type to
another. `Kind` says what a value *is*. Changing it is a named function that constructs the other
member, and across bounded contexts that function is the anti-corruption layer. `Settle` is refused
in both spellings. The refusal names a member with no record name by its shape, `{ Kind: :invoice
}`, not by its bare tag.

## The compiler delta

- `bs_types:map_member/2`, the constructor behind `map_closed/1` and `map_open/1`, expands a `Kind`
  whose type is a finite set of two or more atoms, and nothing else, into the union of one member
  per atom. Every reader then sees the `Split` form, and none has to learn the shorthand.
- A `Kind` with any other part (`:a | binary`, `atom`, `string`) is not a set of tags and is left
  as written. Its openness is read from its parts as before, and a cofinite `atom` stays open.
- Round 2 needed no change to what `with` accepts, since it already checks each member on its own.
  It did change what `with`'s diagnostics call a member. `with` still classifies members by their
  single tag, but `bs_check:record_name/1` names a record only when the tag is qualified (as `record`
  mints it) or belongs to a compiler-known record (`ValidationError`). Any other tagged member is
  shown by its shape, e.g. *"updates the member `{ Kind: :invoice }` with the wrong fields"*, and
  never as *"an receipt"*. A record keeps its name beside a hand-written member in the same union.

## Not decided here

- The spelling of the key. Renaming `Kind` to a reserved `__Kind__` would give `Kind` back to
  programs as a field name (a `record` refuses a field named `Kind` today), and it would change the
  wire form: a record encodes as `{"Kind":"Intake.Reading", …}` under
  [77](77-what-goes-on-the-wire.md). Not asked.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [A `Kind` of several atoms: shorthand for a union of tagged members, or refused?](issues/109-a-kind-of-several-atoms.md)
  — **shorthand for the union: `{ Kind: :a | :b, Id: int }` is `{ Kind: :a, Id: int } | { Kind:
  :b, Id: int }`, and every reader of the type sees the expanded form.** Raised and resolved
  2026-09-26 in one round, out of [ENG-491](https://linear.app/davewil/issue/ENG-491). After
  [101](issues/101-what-closes-a-residual.md) was built, the joined spelling stayed open while the
  split spelling of the same type closed, so `_` was legal over one and refused over the other.
  The key stays ordinary, as [73](issues/73-a-record-name-crosses-using.md) Q1 has it. A `Kind`
  with any non-atom part is not a set of tags and is unchanged. **Round 2: `with` may not move a
  value from one member to another**, as records already refused. `Kind` says what a value is,
  changing it is a named function that constructs the other member, and across bounded contexts
  that function is the anti-corruption layer. The one program this stops compiling, `d with
  { Kind = :receipt }` over the joined spelling, is refused exactly as its split spelling already
  was. Not decided: renaming the key to a reserved `__Kind__`. Built — ENG-491.
```
