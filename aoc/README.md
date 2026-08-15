# Advent of Code in beam-sharp

**A test of the language against work nobody designed it for.** The exemplars in
`compiler/examples/exemplars/` were written to answer specific ticket questions; AoC was written by
someone else, for other languages, with no interest in what this one finds convenient. That is the
point of it.

Started 2026-08-15 (David: *"I want to see if beam-sharp can solve AoC problems"*).

**→ [The write-up](../reports/2026-08-15-aoc-and-state.md)** — what these puzzles established, the
four-language benchmark, and where the project stands as a result.

| Puzzle | Result |
|---|---|
| [2019 Day 1](2019/day01/day01.bs) — The Tyranny of the Rocket Equation | **solved**, both parts, against the real input |
| [2025 Day 1](2025/day01/day01.bs) — Secret Entrance | **solved**, both parts — 1195 and 6770 |

## 2025 Day 1 — the one that hit both gaps at once

A dial numbered 0..99 starting at 50; `L<n>` and `R<n>` rotations; count the times it lands on 0,
first only at the end of a rotation, then on **every click**.

```
worked example (from the puzzle text) -> 3 and 6
real input, 4,732 rotations           -> 1195 and 6770
```

Both match the answers David supplied. Part two simulates **673,364 individual clicks** one at a
time, which the tail calls handle without complaint — F7.16 pinned that property a few hours
earlier and this is the first thing to lean on it.

**It needed both of the gaps 2019 Day 1 found, simultaneously.**

- **Modulo.** A dial *is* modular arithmetic, so the puzzle is unwritable without it. It comes
  through the FFI, and the wrapper is the one every language needs, because `rem` truncates:
  Erlang's `-18 rem 100` is `-18`, not `82`. → [ticket 38](../wayfinder/issues/38-division-and-modulo.md).
- **Parsing, and this time the shell did more than read.** For 2019 the shell only turned a file
  into a list. Here it also **parses**: `L68` becomes `-68` and `R43` becomes `43` before the
  compiler sees anything. Splitting a letter from a number is a real part of this puzzle, and it was
  solved outside the language because there is no `string`, no `binary`, and nothing to take either
  apart.

**What the language did do**, and did well: the modular wrap, the click-by-click simulation
returning position *and* count as a tuple, both folds, and the direction/size split — and **every
function is exhaustive with no catch-all**, including `Spin`, whose three clauses cover
`left = 0`, `left > 0` and `left < 0` and are proven to by the interval refinement.

**And one gap this puzzle closed rather than merely reported: there was no unary minus.** `-1` did
not lex as anything, so `Sign` had to return `0 - 1` and `Size` had to return `0 - d`. Negative
numbers had always arrived fine *as data* — `bs_run`'s reader handles `-68` — so the gap was only
ever in source.

**Fixed the same night**, because unlike division it needed no decision: a grep for *"unary"* across
`LANGUAGE.md`, every ticket, the fog and every feature file returned **nothing**, and C# and Erlang
both have it, so the two tiers agreed and there was nothing to choose. `Sign` and `Size` above now
read `-1` and `-d`, and both puzzles still give the same answers.

The regression worth knowing about is the one a prefix `-` invites in a grammar that already has an
infix `-`: **`1 - 2 - 3` must stay `-4`** and not re-associate to `2`. yecc reported zero conflicts,
which F6.9 says is not the check, so the test asserts the value.

## 2019 Day 1 — solved, and the false start that came first

**Both answers are correct against the 100-module puzzle input in
[`2019/day01/input.txt`](2019/day01/input.txt):**

```
part one -> 3358992
part two -> 5035632
```

and the seven worked examples in the puzzle text match too — 2, 2, 654, 33583, and 2, 966, 50346.

### The false start, kept because it is the more useful half

This file first claimed *"both parts solved, exact"* **before any input existed**. David had
withheld the input deliberately and caught it: *"you didn't get the input, and you made up the
question."*

Both charges were right. There was no input, and I had not asked for one. And the number reported
as evidence — `Sum([12, 14, 1969, 100756]) = 34241` — was **the sum of the four example masses,
which AoC does not ask for**. The question was invented here, computed here, and presented as
validation.

That is the precise failure this repo keeps catching in its own documents, and it was already
written down two directories away: exemplar 25a *"constructed a shape to answer the question"*
instead of writing the workload honestly, and the map retracted it the same day. The seven numbers
that matched were real; the eighth was mine.

**The lesson is not "check your work" but something narrower:** every one of the seven genuine
checks came from the problem statement, and the one fabricated check came from me. A test you wrote
for yourself proves the code does what you already believed. It is worth knowing which of your
checks an outsider supplied.

**Two things went better than expected, and both are the language's thesis rather than luck.**

The fold is two clauses, one per list shape, and it is **exhaustive with no catch-all** — `[]`
covers the empty list, `[m, ..rest]` covers the non-empty one, and that is the whole of `list<int>`.
Nothing was swept up by a `_`.

Part two's recursion is likewise exhaustive over `int` with no catch-all, because the guard states
the termination boundary as an **interval** rather than testing a computed result:

```csharp
FuelAll(m) when m <= 8 -> 0
FuelAll(m)             -> Fuel(m) + FuelAll(Fuel(m))
```

`div(m, 3) - 2` is at most zero exactly when `m` is at most 8, and the checker credits `m <= 8` as
an interval refinement (tickets 08 and 20), so it can prove the two clauses cover `int`. A guard
that tested the *result* would have credited nothing and forced a catch-all.

## What it needed that the language does not have

**Division.** The operator table is `+ - *` and there is no `/` in the lexer at all, so the most
ordinary arithmetic in the puzzle crosses the FFI:

```csharp
using :erlang {
    int div(int a, int b)
}

Fuel(m) -> :erlang.div(m, 3) - 2
```

That is not a hack — ticket 32 makes a foreign declaration a signature attached to the name Erlang
already has, and `erlang:'div'/2` is an exported BIF (measured: `erlang:'div'(7, 2)` is 3). But it
is a real finding: **an arithmetic puzzle reaches outside the language on line one.**

**It is now [ticket 38](../wayfinder/issues/38-division-and-modulo.md)**, raised from this puzzle.
Division turned out to be absent by *oversight* — zero mentions in `LANGUAGE.md`, the tickets or the
fog — and it hides a real decision: truncation is easy (C#, JavaScript and Erlang's `div`/`rem` all
agree, measured), while **divide by zero is where the sources split** and where beam-sharp could
make `/` the first operator carrying a precondition its checker enforces.

## What actually blocks AoC, and it is not the arithmetic

**The input cannot be read.** A real puzzle input is a file of a hundred numbers, one per line, and
beam-sharp has:

- **no file I/O**, and no way to add it usefully — `:file.read_file/1` returns a binary, and
  `binary` is not a builtin type, so the value that comes back cannot be given a type;
- **no `string` type** (decided, in stratum 2 of the prelude, unbuilt);
- **no string operations** — nothing to split lines or parse an integer.

So the input has to be handed in on the command line as a list literal. **beam-sharp can express
the computation and cannot read the question.** That is the sentence to carry into whatever comes
next, and it is a sharper statement of what `string` and the module system are worth than any
exemplar produced.

## Notes for whoever adds the next one

- `bsc FILE.bs FUNCTION ARG` runs it; a list argument is written `'[12, 14, 1969]'`, a tuple
  `'(1, 2)'`, a record `'{Kind = :"Mod.Name", Field = 1}'`.
- **Nothing gates this directory.** `examples/` must compile and run, `LANGUAGE.md`'s blocks are
  checked bidirectionally, and `aoc/` is checked by nobody — which is exactly how 63 exemplar
  clause heads rotted into a dead dialect. If these are worth keeping, they are worth a gate.
