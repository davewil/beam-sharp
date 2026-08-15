# 45 — Which token marks a match against a value already bound?

Status: open
Raised by: F8 (`compiler/features/F8-bind-and-match.md`, *The token*)
Blocks: F8
Type: `wayfinder:grilling`

## Question

F8 makes `var` bind and bare `=` match. A pattern that must match **the value a name already
holds** — Elixir's pin — needs a spelling, and F8 says outright that it *"must not decide"* it:
a spelling every future `.bs` file carries is a decision, not a feature.

## What is already decided, and by whom

**Mark the *match*, with one token, and not `^`** (David, 2026-08-15, recorded in F8).

- **Mark the match, not the bind**, on frequency: you only need to mark one of the two cases, and
  you mark the rare one. Binding is overwhelmingly the common case — every clause head, every
  `switch` arm — so Elixir's choice to mark the match is right, and marking the bind would be the
  expensive inverse.
- **Not `^`**, because since C# 8 it is the index-from-end operator (`arr[^1]`). A tier-2 spelling
  on top of a live tier-1 meaning is worse than a tie.
- **C# offers nothing to borrow**, so this is tier 3 — invent and say so. C# patterns cannot match a
  runtime value at all; they push you to `when v == expected`.

**So this ticket decides one thing only: which token.** The shape of the answer is settled; leaving
it in a feature file rather than on the map is what this ticket corrects.

## The candidates, as F8 tabled them

| Candidate | Reads as | Collides with |
|---|---|---|
| `==acc` | "equal to acc" | nothing in pattern position; reuses `==`, which 16 already fixed as `=:=` |
| `^acc` | Elixir's pin | **C# 8 index-from-end** — refused |
| `$acc` | a substitution | C# interpolated strings, which `string` will want |
| `&acc` | a capture | C#'s bitwise-and, and Elixir's capture operator |
| `~acc` | a sigil | Elixir sigils; free in C# but for bitwise-complement |
| `same acc` | plain English | nothing — but a keyword for a one-character job |

F8's recommendation is **`==acc`**: the only candidate borrowing a spelling the language already
has, with the meaning it already has, needing no new lexer token.

## The argument that did not exist when F8 was drafted

**[Ticket 42](42-interval-pattern-spelling.md) changed the pattern position under this ticket's
feet, and it argues for `==acc` far more strongly than F8 could have.**

Before 42, a pattern was a literal, a constructor, a binder or a wildcard, and `==acc` would have
been the *only* operator-shaped thing in it — a lone oddity. After 42, the parameter position
admits relational patterns:

```csharp
Classify(>= 4 and <= 7)  -> :reserved
Classify(<= -1)          -> :negative
```

so `== acc` is no longer an oddity but the **equality member of a family that now exists**:

```csharp
Reverse([== acc, ..rest], out) -> ...
```

A reader who has met `>= 4` in a head reads `== acc` correctly on sight, with no new concept. This
is exactly the map's *reads on sight versus must be taught* test passing, where before 42 it was
merely a plausible spelling.

**Note what C# does and does not supply here**, because 42's new rule makes the distinction load
bearing. C#'s relational patterns are `<`, `>`, `<=`, `>=` — **`==` is not among them**, because in
C# a constant pattern is written bare (`case 4:`) and there is no need. So `== acc` is not a borrow;
it is beam-sharp extending its own relational family to cover a case C# cannot express at all
(matching against a runtime value). That is tier 3, and by 42's rule it is the *safe* kind: the glyph
`==` carries into pattern position exactly the meaning it has everywhere else in this language, so
there is no false friend. It reads as what it does.

## What this ticket owes

1. The token.
2. If `==acc`: whether the space is significant (`==acc` or `== acc`, or both), since 42's
   relational patterns will have settled the same question for `>= 4`.
3. Confirmation that the grammar admits it wherever a pattern goes — clause head, `switch` arm,
   list element, record field — or a statement of where it does not.

## Answer

<!-- recorded on resolution -->
