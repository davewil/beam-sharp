# Advent of Code in beam-sharp

**A test of the language against work nobody designed it for.** The exemplars in
`compiler/examples/exemplars/` were written to answer specific ticket questions; AoC was written by
someone else, for other languages, with no interest in what this one finds convenient. That is the
point of it.

Started 2026-08-15 (David: *"I want to see if beam-sharp can solve AoC problems"*).

| Puzzle | Result |
|---|---|
| [2019 Day 1](2019/day01/day01.bs) — The Tyranny of the Rocket Equation | **both parts solved**, exact |

## 2019 Day 1 — what it took

```
Fuel(12)     = 2        FuelAll(14)     = 2
Fuel(14)     = 2        FuelAll(1969)   = 966
Fuel(1969)   = 654      FuelAll(100756) = 50346
Fuel(100756) = 33583
Sum([12, 14, 1969, 100756]) = 34241
```

Every number matches the puzzle text.

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
