# 69 — Does the language have `float`?

Type: grilling
Status: resolved 2026-09-15 — [ENG-333](https://linear.app/davewil/issue/ENG-333). Raised
2026-09-07 by David while ENG-330 was in flight; one question, one round
Blocked by: —

## Why this is raised now

Asked by David on 2026-09-07 while [ENG-330](https://linear.app/davewil/issue/ENG-330) was in
flight, and ENG-330 is the reason it is not academic: the fix there had to choose `is_integer`
over `not is_atom` **because a float passes an ordering comparison exactly as an atom does**, and
there is no way to declare that value away.

**Nothing here is decided, and one thing near it is.** [Ticket 38](38-division-and-modulo.md)
resolved division *"phrased over the operand types on purpose, so a later `float / float` stays
open"* — a deferral on the record, with no ticket behind it until this one.

## What is true today, measured 2026-09-07 at `b2a26d9`

Four facts, run rather than inferred:

1. **`float` is not a type.** `type T = int | float` → `error: float is not a builtin type — this
   slice has int, atom, term, bool, binary, string and list<T>`.
2. **A float literal does not lex.** `Half() -> 1.5` → `syntax error before: '.'`. Not a missing
   type with a working literal; the surface has neither.
3. **The algebra has no bucket for one.** `bs_types:ty()` is `atoms, ints, tuples,
   lists, maps, bins`. Six parts, and `term` is their union — so **the top type does not contain
   floats**, in an algebra whose whole method is subtracting from the top.
4. **Floats flow through anyway.** `public atom Kind(term t)` with a catch-all answers `:other`
   for `Kind(1.5)`. The value arrives, is matched, and is returned from — it simply has no name.

## What already leans on a type that does not exist

- [Ticket 20](20-untheorised-term-shapes.md) argues the newtype rule six times over `Meters` and
  `Feet` as `float where value >= 0` — worked examples in a type nobody can write.
- [Ticket 25](25-exemplar-programs.md) records an exemplar's need directly: *"a `timestamptz`'s
  seconds is a **float**"*, routed to *"48, the float row, stdlib"*.
- [Ticket 58](58-refined-int-admits-a-float.md) and F24 exist **because** a float reached an `int`
  parameter. Both halves of that rule — F24's and ENG-330's — are written against a value the
  language cannot name.

## Round 1

Asked 2026-09-07. One question, alone: everything else here — float division, `int | float`,
refinements over a float, the numeric tower in a pattern, what `-spec` publishes — follows from
its answer, and asking any of them first would be asking the gated question before the gate.

### Q1 — Is `float` a type in B#?

**The program that needs the answer.** A mean, over a list of readings:

```csharp
module Stats

public float Mean(list<int> samples)
Mean([]) -> 0.0
Mean(xs) -> List.Sum(xs) / List.Length(xs)
```

It is refused three times over today: `float` is not a builtin type, `0.0` does not lex, and `/`
on two `int`s is `div` (ticket 38), so the third line truncates even if the first two were fixed.

**What you write instead, today, and it compiles:**

```csharp
module Stats

// Hundredths, carried as int, because there is nothing else to carry them in.
public int MeanCentis(list<int> samples)
MeanCentis([]) -> 0
MeanCentis(xs) -> (List.Sum(xs) * 100) / List.Length(xs)
```

**The compiler delta if the answer is yes.** A seventh part in `ty()` and every function that
destructures one (`parts/1`, `pat_parts/1`, `hd_parts/1`, `is_none/1`, `is_open/1`); a float token
in `bs_lexer.xrl`, which must not break `1..5` or the dot that ends a qualified name; `float` in
`builtin/1`; `is_float/1` added to the guard vocabulary, which is what makes a float
**discriminable** and so keeps ticket 09 §4 satisfiable for `int | float`; a second lowering for
`/` (Erlang's `/` for floats, `div` for ints), which is exactly the choice ticket 38 left open;
and a decision on whether `int` is a subtype of `float` — the numeric tower — which the BEAM
answers one way for `==` and another for `=:=`.

**The compiler delta if the answer is no.** A refusal, and a named one: today a float is not
refused, it is *unnameable*, which is the quieter failure. ENG-330 has just closed the one site
where that was silently unsound; nothing announces it anywhere else.

**What makes this a real fork rather than an obvious yes:** B# targets the BEAM, where floats are
a genuine term type, and the language's own tickets already write in them. Against that, the whole
type system is subtraction from a top that does not include them, and adding a seventh part
touches every function that takes a `ty()` apart. (Seven was the count on 2026-09-07; F46 added
`funs` on 2026-09-13, so the part is the eighth.) A "no" is a defensible answer that costs a
sentence; it has simply never been said.

**A1 — yes** (David, 2026-09-15 18:18). Resolved on the one question, one round.

## The answer

`float` is a type in B#: the BEAM's float, an eighth part of `ty()` beside `ints`, so `term` once
again contains everything that can arrive. Three things go with the yes, taken knowingly:

- **The literal is C#'s.** The program David said yes to writes `0.0`; the lexer reads digits, a
  dot, digits and an optional exponent, and `1..5` stays a range.
- **`/` lowers by its operand types.** `div` on two `int`s ([38](38-division-and-modulo.md)), the
  BEAM's `/` on two `float`s — the door 38 §4 held open closes on its own terms. The emitter needs
  the operand types at the site and does not receive them today; that is the feature's work, not a
  decision.
- **Discriminable by `is_float/1`**, so `int | float` satisfies ticket 09 §4 and a clause head can
  tell the two apart.

**What the yes does not settle, and is asked next**: whether an `int` flows where a `float` is
expected — `Mean([]) -> 0` under `public float Mean`, and a caller whose head is `Verdict(0.0)`.
That is [ticket 80](80-does-an-int-flow-where-a-float-is-expected.md),
[ENG-377](https://linear.app/davewil/issue/ENG-377), raised with this answer and blocking the
build. Mixed arithmetic, `int | float` in a head, refinements over a float and what `-spec`
publishes follow it.

**What the yes corrects on the record**:

- [Ticket 77](77-what-goes-on-the-wire.md)'s `float` row read *inherits 69, open*. Measured on
  resolution: `json:encode(1.5)` is `1.5`, `0.0` is `0.0`, `1.0e20` is `1.0e20` (OTP 28.5,
  2026-09-15) — a number. The row is rewritten.
- `LANGUAGE.md` §4's `float` row: **open** → **decided**. `TOUR.md`'s *decided but not built*
  row was already in the right table and is untouched.
- Ticket 20's `Meters` and `Feet` over `float where value >= 0`, ticket 25's `timestamptz`
  seconds and ticket 58 / F24's float reaching an `int` are all now written in a type that exists.
  None is reopened.

### What follows

- Building it is [ENG-378](https://linear.app/davewil/issue/ENG-378), a feature; the compiler
  delta is Round 1's *if the answer is yes* paragraph, with the part count corrected to eight.
  **Built 2026-09-16** as [F51](../../compiler/features/F51-float.md); `Mean([2, 4])` prints
  `3.0`, and the decisions entry's *Unbuilt* is now history.
- [Ticket 80](80-does-an-int-flow-where-a-float-is-expected.md) / ENG-377 blocks ENG-378.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Does the language have `float`?](issues/69-does-the-language-have-float.md) — **yes: `float`
  is a type, the BEAM's float as an eighth part of the lattice beside `int`, written as C# writes
  it.** Raised 2026-09-07 by David while ENG-330 was in flight, resolved 2026-09-15 in one round
  on one question. Measured before asking: `float` was neither a type nor a literal, `term` did
  not contain it, and a float flowed through a catch-all anyway, unnameable. Taken with the yes:
  the literal is C#'s (`0.0`, and `1..5` stays a range); `/` lowers by its operand types, `div`
  on two `int`s and the BEAM's `/` on two `float`s, closing the door 38 §4 held open; `is_float/1`
  makes it discriminable. Not settled by it, asked next: whether an `int` flows where a `float`
  is expected — [80](issues/80-does-an-int-flow-where-a-float-is-expected.md), which blocks the
  build. Ticket 77's `float` row, *inherits 69*, is measured: a number. **Unbuilt** —
  [ENG-378](https://linear.app/davewil/issue/ENG-378).
```
