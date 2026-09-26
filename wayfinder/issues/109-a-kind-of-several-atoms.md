# 109 — A `Kind` of several atoms: shorthand for a union of tagged members, or refused?

Type: grilling
Status: open — [ENG-492](https://linear.app/davewil/issue/ENG-492). Raised 2026-09-26 out of
[ENG-491](https://linear.app/davewil/issue/ENG-491). Q1 answered the same day; round 2 (Q2) reopened
it, when the build's review found Q1's framing false for `with`
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

## The compiler delta

- `bs_types:map_member/2`, the constructor behind `map_closed/1` and `map_open/1`, expands a `Kind`
  whose type is a finite set of two or more atoms, and nothing else, into the union of one member
  per atom. Every reader then sees the `Split` form, and none has to learn the shorthand.
- A `Kind` with any other part (`:a | binary`, `atom`, `string`) is not a set of tags and is left
  as written. Its openness is read from its parts as before, and a cofinite `atom` stays open.

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
  The key stays ordinary, as [73](issues/73-a-record-name-crosses-using.md) Q1 has it: nothing a
  program may write is taken away. A `Kind` with any non-atom part is not a set of tags and is
  unchanged. Not decided: renaming the key to a reserved `__Kind__`. Unbuilt — ENG-491.
```
