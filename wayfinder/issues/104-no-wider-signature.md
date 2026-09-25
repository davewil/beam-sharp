# 104 — Does F25 offer a wider signature when the residual has no type spelling?

Type: grilling
Status: resolved 2026-09-25 — [ENG-467](https://linear.app/davewil/issue/ENG-467). Raised and
answered 2026-09-25 out of [ENG-350](https://linear.app/davewil/issue/ENG-350); one question, one
round
Blocked by: —

## Why this is raised

F25 prints the corrected signature a function's clauses actually return. Since
[ENG-346](https://linear.app/davewil/issue/ENG-346) the line is parsed and declaration-checked
before it is printed, and when what the clauses return has no spelling as a type (a non-empty
list, a literal inside a tuple) it is withheld and the residual is shown alone. ENG-350 filed
that as safe but not the best answer, since a wider line that does compile always exists, and
asked whether F25 should offer it.

## The program

Measured at `5947c1e`:

```csharp
module Lst
public list<map<string, int>> Pick(int n)
Pick(1) -> Ints()
Pick(n) -> Bins()
private list<map<string, int>> Ints()
Ints() -> Ints()
private list<map<string, binary>> Bins()
Bins() -> Bins()
```

```
Lst/lst.bs:4:1: error: Pick returns a value its signature does not declare
  not covered by the declared return type:
    [map<string, binary>, ..]
  If `list<map<string, int>>` is what you meant, fix the clause, not the signature.
  no signature is offered: what the clauses return has no spelling as a type yet.
```

## Q1 — Offer the nearest wider line that compiles, or keep withholding it?

The wider line would be `public list<map<string, int>> | list<map<string, binary>> Pick(int n)`:
a non-empty list widened to `list<T>`, a literal in a tuple widened to its base type.

**A1 (David, 2026-09-25):** *"I'm leaning towards keep withholding it."* Recorded as the answer;
reopen ENG-350 to revisit.

What weighs for it: the wider line declares more than the clauses return (it admits an empty
`list<map<string, binary>>` `Pick` never produces), so pasting it loosens the signature silently,
and the consumer this diagnostic is written for is an agent in a loop, which pastes what it is
given. Withholding keeps the only printed signature an exact one.

## The compiler delta

None. F25's withholding and its `no signature is offered` line stay as they are.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Does F25 offer a wider signature when the residual has no type spelling?](issues/104-no-wider-signature.md)
  — **no: where what the clauses return has no spelling as a type, F25 withholds the corrected
  line and shows the residual, as it does today.** Raised and resolved 2026-09-25 in one round on
  one question, out of [ENG-350](https://linear.app/davewil/issue/ENG-350) (David: "leaning
  towards keep withholding it"). The wider line (a non-empty list widened to `list<T>`, a literal
  to its base type) would compile but declare more than the clauses return, and an agent pasting
  it would loosen the signature without being told. No compiler change; ENG-350 closed.
```
