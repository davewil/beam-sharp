# 80 — Does an `int` flow where a `float` is expected?

Type: grilling
Status: open — [ENG-377](https://linear.app/davewil/issue/ENG-377). Raised 2026-09-15 on resolving
[ticket 69](69-does-the-language-have-float.md), whose Round 1 named this as the first question
gated behind its answer
Blocked by: —

## Why this is raised now

Ticket 69 answered **yes**: `float` is a type, an eighth part of `ty()` beside `ints`. Its round
listed what follows — float division, `int | float`, refinements over a float, the numeric tower
in a pattern, what `-spec` publishes — and asked none of them, because one gates the rest. This is
that one. The feature that builds `float` ([ENG-378](https://linear.app/davewil/issue/ENG-378))
can add the part, the literal and the guard without it; it cannot decide what `Mean([]) -> 0`
means under `public float Mean`, and a feature that needs a decision raises a ticket rather than
making one.

## What is already decided, and is not reopened here

- `/` on two `int`s is `div` ([38](38-division-and-modulo.md)), *phrased over the operand types
  on purpose*, so `/` on two `float`s is the BEAM's `/`. Both readings below keep that; they
  differ only on a `float` beside an `int`.
- A clause head matches the way the BEAM matches: `1 == 1.0` is `true` and `1 =:= 1.0` is
  `false` (OTP 28.5, measured 2026-09-15), and a literal in a head is the second. That fact is
  what the program turns on.
- `float(3)` is `3.0` on the platform, and `using :erlang { float float(int x) }` declares it
  today's way — LANGUAGE.md §10 already spells that declaration (with `int` as its return, on
  purpose, as the demonstration of a false one). No standard-environment entry is asked for here;
  *nothing unqualified is a function* ([67](67-stdlib-shape-as-a-principle.md)) would make a bare
  `Float(...)` a second decision.

## The program

```csharp
module Stats

using :erlang {
    float float(int x)
}

public float Mean(list<int> samples)

Mean([]) -> 0
Mean(xs) -> :erlang.float(List.Sum(xs)) / :erlang.float(List.Length(xs))

public atom Verdict(float mean)

Verdict(0.0) -> :empty
Verdict(_)   -> :some
```

`Mean`'s first clause returns `0`, an `int`, from a function declared `float`. `Verdict`'s first
head is the float literal `0.0`. If `0` is allowed to reach `Verdict` as the value `0`, the head
does not match — `0 =:= 0.0` is `false` — and `Verdict(Mean([]))` is `:some`, silently, from a
program every line of which reads as if it says `:empty`. So an `int` may flow into a `float`
position only if the emitted code converts it there, or not at all.

## Round 1 (2026-09-15)

**Q1. Which of these two transcripts is the language's?**

**The BEAM's reading — two parts, and nothing flows between them.** `0` against a declared
`float` is what the checker already refuses, with the diagnostic it already has:

```
$ bsc Stats.bs Mean '[]'
Stats/Stats.bs:9:1: error: Mean returns a value its signature does not declare
  not covered by the declared return type:
    0
  If `float` is what you meant, fix the clause, not the signature.
```

The author writes `Mean([]) -> 0.0`, and then:

```
$ bsc Stats.bs Mean '[]'
0.0
$ bsc Stats.bs Mean '[2, 4]'
3.0
```

and `Verdict(Mean([]))` is `:empty`. `:erlang.float(List.Sum(xs)) / List.Length(xs)`, one
conversion dropped, is refused at the operator: `/` on a `float` and an `int`, naming
`:erlang.float`. From outside, `bsc Stats.bs Verdict 0` reaches a `float` parameter with an
`int`, which F24's boundary clause sends the way it sends an atom.

The compiler delta is the feature's and nothing more: `floats` is an eighth part, disjoint from
`ints` as every part is from every other; `is_subtype(int, float)` is false because the sets are;
`return_not_declared` fires as it does today; the operator table refuses the mixed pair; a float
literal in a head lowers to the literal.

**C#'s reading — an `int` converts implicitly where a `float` is expected.** `int` to `double`
is C#'s implicit numeric conversion, so the clause compiles as written:

```
$ bsc Stats.bs Mean '[]'
0.0
$ bsc Stats.bs Mean '[2, 4]'
3.0
```

and `Verdict(Mean([]))` is `:empty` — because the emitted first clause is `float(0)`, not `0`.
`:erlang.float(List.Sum(xs)) / List.Length(xs)` is accepted and lowers to the BEAM's `/`, which
promotes on its own.

The compiler delta is a conversion emitted at **every** site where the checker's inferred type
for an expression is not within `float` and the expected type is: a return position, an argument
to a `float` parameter, a `float` field of a record, a `float` in a tuple. Miss one and the
reading is the silent `:some` above — the F24.9 failure with the kinds swapped. The emitter does
not receive an inferred type per expression today (it resolves *declared* types through
`bs_check:resolve/2`, and asks `clause_accepts/2` for a clause's argument types; nothing hands it
what an arbitrary expression was inferred to be), so the channel is new. C# stops the conversion
at scalars — a `List<int>` is not a `List<double>` — and the line B# draws would be round 2's
question. The boundary clause on a `float` parameter tests `is_number` and converts.

**One question.** The refusal and `0.0` written by the author, or `0.0` printed from `0` with the
conversion written by the compiler at every site it can find.

Under the first, ENG-378 builds with no further question, and a mixed pair at an operator is
refused naming `:erlang.float`. Under the second, round 2 asks where the sites stop, and ENG-378
grows the expected-type channel from checker to emitter before its `/` can lower.

**Prior art, surveyed 2026-09-15** — [research 80](../research/80-int-to-float-prior-art.md),
asked by David while this round was open. **Every language that types the BEAM takes the first
reading, and the two that take the second run on a VM with a conversion instruction.** Gleam
refuses `[] -> 0` under `-> Float` at the type and has no shared operator (`+.` beside `+`);
Elixir 1.20's checker infers `m([])` as `integer()` from its first clause and refuses it against a
`float` guard two calls away; Erlang keeps the values apart under `=:=` and Dialyzer passes the
`0` out of a `float()` spec silently, because success typing does not ask. C# converts (§10.2.3)
and the value that arrives is a `Double`. F# 6 added `int32 → double` at known-type sites only,
operators left strict, warning off by default — a narrower version of C#'s rule, adopted after
fifteen years without it, and the shape round 2 would reach under the second reading. **Found on
the way, and not asked here**: on OTP 27+ a `0.0` head matches `+0.0` alone; `erlc` warns, Elixir
warns, Gleam lowers its `0.0` pattern to `+0.0` without a word, C# matches `-0.0` too. B#'s
`Verdict(0.0)` owes a lowering; recorded on ENG-378.

## Not decided here

- Where an `int`-to-`float` conversion lives in the standard environment. `:erlang.float` through
  a `using` declaration works under either reading; a compiler-known spelling is a 67-shaped
  question nobody has asked.
- The literal's grammar beyond C#'s digits, dot, digits and optional exponent — the feature's,
  with `1..5` a range.
- A refinement over a float (`float where value >= 0`, [20](20-untheorised-term-shapes.md)'s
  `Meters` and `Feet`), and a float in a relational guard. Both are the BEAM's guards already;
  they follow the feature.
- What `-spec` publishes: `float()`.
