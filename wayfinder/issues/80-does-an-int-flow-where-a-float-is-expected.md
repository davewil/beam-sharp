# 80 — Does an `int` flow where a `float` is expected?

Type: grilling
Status: resolved 2026-09-15 — [ENG-377](https://linear.app/davewil/issue/ENG-377). Raised 2026-09-15 on resolving
[ticket 69](69-does-the-language-have-float.md), whose Round 1 named this as the first question
gated behind its answer; one question, one round, answered the same evening
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

**A1 — the BEAM's reading** (David, 2026-09-15 19:31, after the survey and a recommendation asked
for and given: *"the least surprise to a C# developer but also considering B# is a BEAM
language"*). Resolved on the one question, one round.

## The answer

`int` and `float` are two parts of the lattice and nothing flows between them. `0` against a
declared `float` is refused by `return_not_declared`, whose advice names `0.0`; a `float` beside
an `int` at an operator is refused, naming the conversion; a `float` parameter reached by an
`int` from outside goes the way F24 sends an atom. The emitted program is the written program:
no conversion is written by the compiler at a site the author cannot see.

Why this and not C#'s conversion, recorded because the recommendation was asked for:

- **B# had already made the call for `==`.** `==` means `=:=` ([16](16-ad-hoc-polymorphism.md) §5), so
  `0 == 0.0` is false in B# today and true in C#. Converting at a call site while refusing to
  compare would be the one place an `int` both is and is not a `float`.
- **A coercion is not inclusion.** Every other type claim in B# is set inclusion over BEAM terms,
  and [09](09-union-representation.md) §5 refused nominal identity for that reason. The emitter has
  no per-expression type channel; every missed site is the silent `:some` in the program above.
- **C# gets the conversion cheaply and B# would not.** The CLR has `conv.r8` and a static type on
  every expression; F# needed an RFC, an off-by-default warning and a rule that stops at
  operators to add a narrower version (research 80).
- **Every BEAM-typed language answers this way.** Gleam and Elixir's type system both refuse; a
  B# function specced `float()` that always returns a float is Dialyzer-clean and Gleam-callable.

**What it costs, and where that goes.** A C# developer types `Mean([]) -> 0` once, and the
refusal's advice says `0.0`. The lasting cost is the conversion's spelling — today
`:erlang.float(n)` through a `using` declaration — and that is [ticket 81](81-how-is-an-int-converted-to-a-float.md),
[ENG-380](https://linear.app/davewil/issue/ENG-380), raised with this answer at David's request.
The conversion is needed at all because of [38](38-division-and-modulo.md), not this ticket:
`/` on two `int`s is `div`, so a mean over a `list<int>` converts an operand exactly as C# does.

### What follows

- [ENG-378](https://linear.app/davewil/issue/ENG-378), the feature, is unblocked. Its delta is
  ticket 69's *if the answer is yes* paragraph; nothing in it changes under this answer, and the
  operator table's mixed-pair refusal is the one addition.
- The float zero in a head (`0.0` matches `+0.0` alone on OTP 27+; research 80) is owed on
  ENG-378 as a lowering, and becomes a ticket only if it is not one.
- `LANGUAGE.md` §4's `float` row says the flow is refused; `CONTEXT.md`'s entry says it.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Does an `int` flow where a `float` is expected?](issues/80-does-an-int-flow-where-a-float-is-expected.md)
  — **no: the BEAM's reading. `int` and `float` are two parts and nothing flows between them; the
  emitted program is the written program.** Raised and resolved 2026-09-15 in one round on one
  question, the first gated behind 69's yes. `0` against a declared `float` is refused by
  `return_not_declared` with `0.0` as its advice; a `float` beside an `int` at an operator is
  refused naming the conversion. Chosen over C#'s implicit conversion because `==` already means
  `=:=` (16), so `0 == 0.0` is false and a converting call site would contradict it; because a
  coercion is not set inclusion and the emitter has no per-expression type channel to write one
  safely; and because every language that types the BEAM refuses (Gleam, Elixir 1.20) while the
  two that convert run on a VM with a conversion instruction (research 80, measured). The cost is
  the conversion's spelling, [81](issues/81-how-is-an-int-converted-to-a-float.md); the need for
  one at all is 38's operand-typed `/`. Unblocks [ENG-378](https://linear.app/davewil/issue/ENG-378).
```

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
