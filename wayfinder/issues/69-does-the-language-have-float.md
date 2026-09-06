# 69 — Does the language have `float`?

Type: grilling
Status: open — raised 2026-09-07, [ENG-333](https://linear.app/davewil/issue/ENG-333)
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
touches every function that takes a `ty()` apart. A "no" is a defensible answer that costs a
sentence; it has simply never been said.
