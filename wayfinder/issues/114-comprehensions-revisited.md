# 114 — Comprehensions revisited: may B# write `[r for Receipt r in cs]`?

Type: grilling
Status: claimed — [ENG-570](https://linear.app/davewil/issue/ENG-570). Raised 2026-09-28 by David,
reviewing [F64](../../compiler/features/F64-implements.md)'s `for` keyword
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

Under **yes**, these follow, each asked after it rather than beside it: whether a generator skips
or crashes on an element its pattern refuses, which Erlang offers both ways; the spelling, where
`for … in` is Python's order and Elixir writes `for r <- cs, do: r`, while LINQ's
`from … select` died in 17 for the unqualified names its translation emits, which a
compiler-known form would not emit; a filter after the generator; several generators; and `map`
and `binary` comprehensions.
