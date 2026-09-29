# 114 — Comprehensions revisited: may B# write `[r for Receipt r in cs]`?

Type: grilling
Status: resolved 2026-09-29 — [ENG-570](https://linear.app/davewil/issue/ENG-570). Raised 2026-09-28
by David, reviewing [F64](../../compiler/features/F64-implements.md)'s `for` keyword; answered in
three rounds, seven questions
Blocked by: —

## Why this is raised

David, on learning that [17](17-pipeline-and-comprehension.md) had removed comprehension syntax:
*"not sure why I ruled them out."*

17 decided on 2026-08-13: *"There is no comprehension syntax, because precision is a lowering
decision, and it was measured."* The argument was about the emitted code. Lowering `List.Map` to
an inlined Erlang comprehension keeps Dialyzer's `[integer()] -> [binary()]`, so surface syntax
bought no precision that the lowering could not. That settles precision. It does not weigh a
comprehension as something an author writes, and 17 §2 names what the pipeline cannot say:

> `filter` returns `[pos_integer()]`, narrowed out of the guards, where `List.Filter<T>(list<T>,
> fn(T) -> bool) -> list<T>` can only say `list<T>`. The emitted code knows a fact the language's
> own type system discards.

A generator with a pattern is where a set-theoretic checker keeps that fact, by the same narrowing
a clause head already does on a parameter.

Two things have changed since 17. `for` is a keyword ([F64](../../compiler/features/F64-implements.md),
2026-09-28), used only in `implements P for T` at declaration level, so it is free in expression
position. And `List.Map`, `List.Filter` and `List.Fold` are built.

## The program

A billing module collects the receipts from a batch of charges, each of which either settled or was
declined. Every result below was measured with `bsc` at `6803241`.

```csharp
module Shop.Billing
record Receipt { OrderId: int, Pence: int }
type Charge = Receipt | (:error, string)

public list<Receipt> Settled(list<Charge> cs)
Settled(cs) -> [r for Receipt r in cs]
```

Today this is `syntax error before: for`.

What compiles today is a fold with a `switch` inside it. Over a receipt for order 1, a declined
charge and a receipt for order 3, it returns the receipts for orders `[1, 3]`:

```csharp
Settled(cs) -> cs |> List.Fold([], (acc, c) => c switch {
    Receipt r   => [r, ..acc],
    (:error, _) => acc
}) |> List.Reverse()
```

`List.Filter` cannot write it, because its result is the input's type whatever the predicate says:

```csharp
Settled(cs) -> cs |> List.Filter(c => c switch {
    Receipt r   => true,
    (:error, _) => false
})
```
```
Shop/Billing/Billing.bs:6:1: error: Settled returns a value its signature does not declare
  not covered by the declared return type:
    [(:error, string), ..] | [{ Kind: :'Shop.Billing.Receipt', OrderId: int, Pence: int }, ..]
```

The clause-head recursion, B#'s own idiom, should compile and does not. That is a defect,
[ENG-569](https://linear.app/davewil/issue/ENG-569): a type-prefix pattern in a list element does
not narrow its binder. It is not this ticket's question, and fixing it does not answer this ticket,
because the recursion is still three clauses for what the comprehension says in one line.

## What it compiles to, under yes

The fold's arm `Receipt r` already emits `R = #{'Kind' := 'Shop.Billing.Receipt'}`. A comprehension
puts that pattern in a generator:

```erlang
'Settled'(Cs) -> [R || R = #{'Kind' := 'Shop.Billing.Receipt'} <- Cs].
```

The checker types the result as a list of the generator's element type intersected with the
pattern's type. `Charge` intersected with `Receipt` is `Receipt`, so the result is
`list<Receipt>`.

Erlang has two generators, and on OTP 28.5 they differ on the element the pattern refuses. Over
`[#{kind => receipt}, {error, x}]`, `[R || R = #{kind := receipt} <- L]` returns
`[#{kind => receipt}]`, and `[R || R = #{kind := receipt} <:- L]` crashes with
`{badmatch, {error, x}}`.

## The compiler delta, under yes

- The lexer makes `in` a keyword. Today it is a name.
- The parser gains `[expr for pattern in expr]` inside list brackets, with yecc measured before
  and after.
- The checker binds the pattern against the generator's element type, narrows it, and types the
  body under the bindings. Whether the pattern must also cover the element type turns on a
  question that follows Q1: a generator that skips has no missing case, and one that crashes does.
- The emitter writes an Erlang `lc` form.
- The editor grammars learn the form, the tree-sitter one measured on a scratch file.

## Round 1

**Q1. Does B# get a comprehension back, one that keeps a generator pattern's narrowing, as
`Settled` above does?**

Under **no**, `Settled` stays the fold, and 17 stands. C#'s own answer to `Settled` is
`charges.OfType<Receipt>()`, which could become a `List` row and would narrow by a type. It stops
there, though. A generator's pattern also destructures, which no type filter can do:

```csharp
public list<string> Declines(list<Charge> cs)
Declines(cs) -> [reason for (:error, reason) in cs]
```

`OfType<(:error, string)>` would return the tuples, not the reasons.

**Recommended: yes.** A pattern is B#'s defining construct, and a generator is one more position for
it, narrowed by the same algebra and lowered to the BEAM's own comprehension. The cost is one
keyword, one grammar rule, a binding pass the checker already has for clause heads, and an `lc`
form. Under no, collecting one member of a union, or one field of it, from a list stays a fold with
a `switch` and a `List.Reverse`.

**A1 (David, 2026-09-29):** *"Yes."*

## Round 2

A1 makes `Settled` the program, so the three questions below are what it is made of. None depends
on another. A filter after the generator, several generators, and `map` and `binary` comprehensions
wait for Q3's spelling.

**Q2. A generator skips an element its pattern refuses, and there is no form that crashes on one.
A pattern that no element can match is reported as a vacuous `switch` arm is.**

`Settled` depends on skipping, since a declined charge is not a `Receipt`. OTP 28.5 also has a
strict generator, `<:-`, which crashes with `{badmatch, E}` on an element the pattern refuses
(measured above). In B# the checker already knows whether a pattern covers the generator's element
type. Where it does, the two forms behave alike. Where it does not, a narrower pattern is written to
filter. That leaves the strict form asserting only what the types already prove, except over
`term`, and there `ValidateAs<T>` is the boundary. A pattern outside the element type is dead:

```csharp
record Refund { OrderId: int, Pence: int }
Refunds(cs) -> [r for Refund r in cs]      // Refund is not a Charge: always []
```

A `switch` arm in the same position gets a warning today (measured): *"arm 1 of this switch in Count
matches no value … this arm's pattern is not a member of it"*, and the program compiles and runs.

Recommended: yes to both. The delta is the vacuity check pointed at the generator, reusing
`redundancy/4`'s membership test.

**Q3. It is spelled `[r for Receipt r in cs]`.**

The result comes first, then the pattern and the list, inside the brackets that already build a
list, as `[a, ..b]` does. Two borrowings fail on facts:

- C#'s LINQ, `from Receipt r in cs select r`. In C#, an explicitly typed range variable means
  `cs.Cast<Receipt>()` (ECMA-334's query translation), which throws on the first element that is not
  a `Receipt`. That is the opposite of Q2.
- Elixir's `for r <- cs, do: r`. Here `<-` lexes today as `<` then `-`, so `x <- 1` is `x < -1`.

Measured for the recommended form: adding `'in'` as a terminal and
`expr_low -> '[' expr 'for' pattern 'in' expr ']'` to `bs_parser.yrl` leaves yecc at 6
shift/reduce and 0 reduce/reduce, before and after. `for` is already a keyword (F64). `in` is not,
and no example (73 `.bs` files) and no code block in LANGUAGE.md or TOUR.md uses it as a name.

Recommended: yes.

**Q4. A generator's pattern is anything a clause-head parameter accepts, and narrows as a parameter
does.**

A generator matches the whole element, as a parameter matches the whole argument, so the part
prefix, which is refused nested (`type_prefix_nested`), is legal at a generator's top:

```csharp
public list<float> Fractional(list<int | float> amounts)
Fractional(amounts) -> [f for float f in amounts]

public list<string> Paid(list<Order> os)
Paid(os) -> [o.Customer for Order { Status: :paid } o in os]
```

The delta is checking the generator's pattern as a top, the way a switch subject is checked, so
`child_type/3` sees its children and not the pattern itself.

Recommended: yes.

**A2:** not answered in round 2; carried to round 3.
**A3 (David, 2026-09-29):** *"yes"*: `[r for Receipt r in cs]`.
**A4 (David, 2026-09-29):** *"yes"*: a generator's pattern is anything a clause-head parameter
accepts.

## Round 3

Q2 is carried unchanged. A3's spelling opens the three questions below, and none depends on
another. Measured for all three together: adding `'in'`, and a comprehension whose first generator
may be followed by any mix of `for pattern in expr` and `when guard_expr`, leaves yecc at 6
shift/reduce and 0 reduce/reduce, before and after.

**Q5. A filter follows a generator as `when` and a guard, and takes what a clause guard takes.**

```csharp
public list<Receipt> Large(list<Charge> cs)
Large(cs) -> [r for Receipt r in cs when r.Pence >= 10000]
```

`when` then means one thing everywhere it is written. So a filter cannot call your function, as a
clause guard cannot today (measured): *"Size calls Large in a guard / a guard asks a question about
the values a clause already matched; it cannot call a function. Move the call into the body and
switch on its answer."* Erlang lets a comprehension filter be any boolean expression. B# would be
narrower on purpose, so that a `when` reads the same in a head, an arm and a comprehension. A call
belongs in a `List.Filter` stage.

Recommended: yes.

**Q6. A comprehension may have several generators; a later one sees an earlier one's bindings, and
a `when` may follow any of them.**

```csharp
public list<(int, string)> Skus(list<Order> os)
Skus(os) -> [(o.Id, l.Sku) for Order o in os for Line l in o.Lines when l.Qty > 0]
```

This lowers to one Erlang comprehension with two generators and a filter, the BEAM's own shape:
`[{…} || O = #{…} <- Os, L = #{…} <- maps:get('Lines', O), …]`.

Recommended: yes.

**Q7. A comprehension draws from lists and builds a list. Map and binary comprehensions, and a
generator over an `Enumerable<T>` record, are not this ticket's.**

Each waits on something open. A binary comprehension waits on building a binary,
[ticket 90](90-building-a-binary.md). A generator over a map needs a key-and-value pattern, which
48 Q2 deferred ([ENG-323](https://linear.app/davewil/issue/ENG-323)). A generator over an
implementing record needs `Enumerable<T>` as a parameter type
([ENG-566](https://linear.app/davewil/issue/ENG-566)). All three go to the map's *Not yet
specified*, to be ticketed when a program needs one.

Recommended: yes.

**A2 (David, 2026-09-29):** *"yes"*: a generator skips, and a pattern no element can match is
reported as a vacuous arm is.
**A5 (David, 2026-09-29):** *"yes"*: a filter is `when` and a guard, under guard rules.
**A6 (David, 2026-09-29):** *"yes"*: several generators, and a `when` after any of them.
**A7 (David, 2026-09-29):** *"yes"*: lists in, a list out; map, binary and `Enumerable<T>`
comprehensions go to the fog.

David confirmed the summary on 2026-09-29, with these consequences stated in it: names bound
inside a comprehension are local to it; ticket 17 is overruled on its comprehension sentence
alone; `in` becomes a keyword; the build is a feature of its own.

## Round 4 (asked 2026-09-29, from the ENG-572 build)

ENG-572 built the amendment "a `when` narrows the binders of the generator before it, as an arm's
guard narrows its pattern" by reading the generator as the arm's pattern, its `when`s joined by
`and` as the arm's guard, and the rest of the comprehension as the arm's body. One question
decides whether that reading stands; what a later generator sees follows from it.

**Q8. A generator's `when`s are one guard, checked as written, as an arm's `when … and …` is.**

```csharp
type Sample = (:ok, int) | (:stale, float)

public list<int> Fresh(list<Sample> samples)
Fresh(samples) -> [v for (s, v) in samples when s == :ok when v >= 0]
```

Under **yes**, as built, this is refused, as the arm `(s, v) when s == :ok and v >= 0 =>` is:

```
error: `>=` in Fresh has `int | float` on its left
```

The pattern says it instead: `[v for (:ok, v) in samples when v >= 0]` compiles, and returns `[3]`
from `[(:ok, 3), (:stale, 1.5), (:ok, -1)]`. `when a when b` narrows exactly as
`when (a) and (b)`, so the two spellings never differ.

Under **no**, each `when` is checked, and narrows, after the ones before it, as a `switch` nested
in the arm's body would be, and `Fresh` compiles with `v` an `int` at `v >= 0`. The delta:
`comp_quals/5` checks a `when` in the scope the `when`s before it narrowed rather than the one its
generator bound, and narrows by each `when` alone; F65.26's first case and F65.28's chained forms
flip to compiling.

**Prior art** (measured 2026-09-29, at David's request). Erlang and Elixir both answer yes: the
guard that narrows is the generator pattern's own, as a clause head's is, and neither lets one test
narrow the next. Gleam has no comprehension.

- **Erlang.** The reference manual treats filters as tests in a row: a guard filter that fails is
  `false`, and any other filter raises `{bad_filter, Val}` on a non-boolean. The compiler goes
  further. In OTP 28.5, `v3_core:preprocess_quals/5` takes the run of guard-test filters directly
  after a generator and folds it into that generator's clause guard ("fold them together and join
  to a preceding generators"). `[V || {S, V} <- Xs, S =:= ok, is_integer(V), V >= 0]` compiles to
  one Core Erlang clause, `<[{S,V}|_]> when … S =:= ok … is_integer(V) …`. A B# `when` keeps
  guard rules, so every `when` B# emits is a guard test. `when s == :ok when v >= 0` therefore
  reaches the BEAM as one clause head: the pattern and both tests. *Yes* is the shape the BEAM
  already compiles it to.
- **Elixir** spells the two readings differently, and on 1.20.1 its type checker narrows through
  only one of them. Each row uses `v` as a binary, so a warning means `v` was narrowed to an integer:

  | Elixir 1.20.1 | warning on `v <> "!"` |
  |---|---|
  | `case` clause `{s, v} when s == :ok and is_integer(v) ->` | yes |
  | generator guard `for {s, v} when s == :ok and is_integer(v) <- samples` | yes |
  | two filters `for {s, v} <- samples, s == :ok, is_integer(v)` | none |
  | one filter `for {s, v} <- samples, s == :ok and is_integer(v)` | none |

  Narrowing lives only in the guard written on the pattern, left of `<-`; a filter is a truthy
  test the checker learns nothing from. A B# `when` after a generator corresponds to Elixir's
  generator guard, not to its filters. Nothing in Elixir supports *no*: a test read in light of
  the one before it needs a nested `for` or `case` there.
- **Gleam** has no comprehension. Its tour points to `list.filter_map`, where the function holds a
  `case`. A guard "must evaluate to `True` for the pattern to match" and cannot call functions.
  Gleam has no union of built-in types for a guard to split (an inference, not a documented
  rule). So the Gleam counterpart of `Fresh` is the arm itself, with the variant chosen by its
  pattern.
- **For ENG-575.** Elixir 1.20.1 prints "this guard will never succeed" in the same words for a
  generator guard and a `case` clause, one message at both sites. It catches only kind
  contradictions (`is_integer(v) and is_atom(v)`), not `v > 5 and v < 3`, since its types have no
  integer ranges. `erlc` warns about neither.

Sources: [Erlang expressions](https://www.erlang.org/doc/system/expressions.html),
[Erlang list comprehensions](https://www.erlang.org/doc/system/list_comprehensions.html), OTP 28.5
`lib/compiler/src/v3_core.erl`, [Elixir `for/1`](https://elixir.hexdocs.pm/Kernel.SpecialForms.html),
[Elixir's gradual set-theoretic types](https://elixir.hexdocs.pm/gradual-set-theoretic-types.html),
[Gleam guards](https://tour.gleam.run/flow-control/guards/),
[Gleam's list module](https://tour.gleam.run/standard-library/list-module/).

Recommended: yes. It is the arm's reading, the pattern already has a spelling for it, and a
`when` then reads the same in a head, an arm and a comprehension.

## The compiler delta, as decided

- The lexer makes `in` a keyword.
- The parser takes `'[' expr 'for' pattern 'in' expr quals ']'`, where `quals` is any mix of
  `for pattern in expr` and `when guard_expr`. yecc is 6 shift/reduce and 0 reduce/reduce before
  and after (measured on a scratch copy of `bs_parser.yrl`).
- The checker checks a generator's pattern as a top, as a switch subject is, so the part prefix is
  legal there. It intersects the pattern with the list's element type, types each guard and the
  head expression under the bindings so far, and runs `redundancy/4`'s membership test for the
  vacuous warning. A guard keeps guard rules.
  *Corrected 2026-09-29 by the F65 build: a guard is checked as a clause guard is (guard rules and
  the guard-level operator refusals), not typed further; a clause guard is not typed either.
  The build also found that an Erlang generator binds its pattern fresh, so `== n` lowers to a
  fresh name and an `=:=` filter (F65.18).*
- The emitter writes one Erlang `lc` with `<-` generators, so an element the pattern refuses is
  skipped.
- The tree-sitter grammar and the regex grammars learn the form.
- The tests go through the CLI: `Settled`, `Declines`, `Large`, `Fractional` and `Skus` run; a
  pattern outside the element type warns; a guard calling a private function is refused; a
  generator's binding is unbound after the comprehension. The build is
  [ENG-571](https://linear.app/davewil/issue/ENG-571).

## Not decided here

- Map, binary and `Enumerable<T>` comprehensions (A7), which wait on ENG-323, ticket 90 and
  ENG-566 and are fog on the map.
- Laziness. A comprehension builds a list, and 17 §5 keeps collections strict; `stream<T>` is
  [ENG-283](https://linear.app/davewil/issue/ENG-283).
- A record pattern nested in a list element that does not narrow is a defect,
  [ENG-569](https://linear.app/davewil/issue/ENG-569), and does not block the build: a
  generator's pattern is checked at the top.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Comprehensions revisited](issues/114-comprehensions-revisited.md) — **B# has list
  comprehensions, `[r for Receipt r in cs]`. A generator's pattern is anything a clause-head
  parameter accepts, and narrows the element type; an element it refuses is skipped, never a
  crash; a `when` guard may follow any generator; lists go in and a list comes out.** Raised by
  David on 2026-09-28 while reviewing F64's `for` keyword (*"not sure why I ruled them out"*), and
  resolved on 2026-09-29 in three rounds of seven questions. It overrules
  [17](issues/17-pipeline-and-comprehension.md)'s *"There is no comprehension syntax"* and nothing
  else in 17. That ticket argued about the precision of the emitted code, which inlining keeps under
  either answer. It never weighed the construct as something an author writes, though its own §2
  recorded that `List.Filter` "can only say `list<T>`", and a generator's pattern keeps exactly that
  fact. Measured: yecc stays at 6 shift/reduce before and after; no example or document code block
  uses `in` as a name; OTP 28's strict `<:-` crashes where `<-` skips. B# takes only the skipping
  form, since the checker already proves where a pattern covers, and a pattern no element can match
  gets the vacuous-arm warning. Two borrowings were refused on facts. C#'s LINQ
  `from Receipt r in cs` would be `Cast<T>()`, which throws. Elixir's `<-` already lexes as
  `< -` in B#. A `when` keeps guard rules, so it cannot call a user function. Map, binary and
  `Enumerable<T>` comprehensions are fog. Unbuilt: [ENG-571](https://linear.app/davewil/issue/ENG-571).
  **Amended 2026-09-29 by David, reviewing F65 ([ENG-571](https://linear.app/davewil/issue/ENG-571),
  built at `6ab638b`):** a generator's source must be a list, and a `term` is refused, since
  `ValidateAs<list<T>>` is where an outside value becomes one and a generator skipping malformed
  entries would drop them silently; a comprehension in a guard is refused, as a `switch` is; a
  generator may not rebind an outer name or bind one name twice, as an arm and a lambda may not; a
  map pattern in a generator stays deferred with 48 Q2 ([ENG-323](https://linear.app/davewil/issue/ENG-323));
  and a `when` narrows the binders of the generator before it, as an arm's guard narrows its
  pattern ([ENG-572](https://linear.app/davewil/issue/ENG-572), built into F65 2026-09-29, its
  reading asked as Q8; a warning for a guard that admits nothing is
  [ENG-575](https://linear.app/davewil/issue/ENG-575)).
```

Under **yes**, these follow, each asked after it rather than beside it: whether a generator skips
or crashes on an element its pattern refuses, which Erlang offers both ways; the spelling, where
`for … in` is Python's order and Elixir writes `for r <- cs, do: r`, while LINQ's
`from … select` died in 17 for the unqualified names its translation emits, which a
compiler-known form would not emit; a filter after the generator; several generators; and `map`
and `binary` comprehensions.
