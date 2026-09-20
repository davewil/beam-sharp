# 86 — May a numeric literal take its part from the union beside it?

Type: grilling
Status: open — [ENG-396](https://linear.app/davewil/issue/ENG-396). Raised 2026-09-20 by David out of
[F53](../../compiler/features/F53-numeric-union-dispatch.md)
([ENG-394](https://linear.app/davewil/issue/ENG-394)), on reading what the shipped dispatch costs
in a program that treats the parts the same
Blocked by: —

## Why this is raised

F53 shipped [83](83-a-union-operand-at-an-operator.md)'s refusal and
[84](84-dispatching-the-parts-of-a-numeric-union.md)'s dispatch on 2026-09-19, and the form is
the one David asked for: *"it is expressive and self documenting"*. This ticket is not a doubt
about that. It is the one lever that would change the line count, named so the decision is taken
rather than inherited.

**83 already weighed this spelling and took its loss as a cost.** Its own words:

> `a < 0.0` over an `int | float` subject **stops compiling**. It compiles today, emits no kind
> test, and answers correctly for both parts — and it is refused under this answer, because 80's
> no-flow rule is symmetric and the `int` part of the union is beside a float literal. The form
> that behaves correctly today is the form that goes away, and the two clauses replace it.

So the question here is not whether 83 was answered. It was. What 83 could not weigh is what the
replacement costs in a program, because **the dispatch did not exist yet** — there was nothing to
put on the other side of the scale. Now there is, and it is measurable.

## The program

A basket threshold. The amount is off the wire, so it is both parts ([77](77-what-goes-on-the-wire.md)),
and the business states the threshold once.

```csharp
module Fees

public bool FreeShipping(int | float basket)

FreeShipping(basket) -> basket >= 50
```

Measured at `01990a3`:

```
Fees.bs:5:32: error: `>=` in FreeShipping has `int | float` on its left
  a union whose parts are all numeric is the mixed pair wherever one
  part would be: nothing converts between `int` and `float`, so `>=`
  has no one meaning over both.
  Dispatch the parts in the head, and write the operator in each
  clause, where the part is known:
    FreeShipping(int basket) -> ...
    FreeShipping(float basket) -> ...
```

The rewrite the compiler advises, which compiles and answers correctly:

```csharp
public bool FreeShipping(int | float basket)

FreeShipping(int n)   -> n >= 50
FreeShipping(float f) -> f >= 50.0
```

`FreeShipping(60)` is `:true` and `FreeShipping(49.99)` is `:false`.

**The cost is not the line.** It is that `50` is now written twice, in two spellings, and a
business rule that moves to 75 is two edits with nothing tying them together. The clause set says
"these two cases differ"; the bodies say they do not. That is the shape this ticket exists to put
in front of a decision, and it appears wherever a union-typed value meets a threshold — a fee
band, a retry ceiling, a tolerance, a credit limit.

## Q1 — May a numeric literal take its part from the union beside it?

One question, and it is about a **literal** alone. Scope: one operand is a union whose parts are
all numeric, the other is a numeric literal written in the source.

**If yes**, `basket >= 50` compiles. The literal is read as belonging to whichever part the value
holds at run time, which is what the BEAM's own `>=` already does, and the emitted program is the
comparison with **no kind test conjoined**:

```erlang
'FreeShipping'(Basket) -> Basket >= 50.
```

The compiler delta is two places, and the second is the one that bites:

* `op_result/5` gains a case above `union_result/5`: a numeric union beside a numeric literal is
  not the mixed pair, and a comparison over it answers `bool`.
* [ENG-330](https://linear.app/davewil/issue/ENG-330)'s `kind_tested/2` **must not** conjoin
  `is_integer` at that site. That conjunction is exactly what silently removed the float half of
  a parameter before F53 — `'Post'(A) when is_integer(A) andalso A < 0` — and a yes here creates
  a second site with the same shape. 83's *no* branch carried this same delta and it is the
  reason that branch was not free either.

**If no**, F53's dispatch is the only spelling, the threshold is written once per part, and this
ticket closes having named the cost rather than removed it.

### What the yes costs, and it is not small

[80](80-does-an-int-flow-where-a-float-is-expected.md) decided that nothing flows between the
parts, and stated the rule as *"the emitted program is the written program"*. Under a yes the
written `50` means `50` against an `int` and `50.0` against a `float` — the literal's part is
decided by a value the compiler cannot see. That is a coercion, at one site, with the compiler
choosing. It is the thing 80 refused, admitted through the narrowest door available.

It also reopens a question 80 closed by construction: if `50` may float, an author will reasonably
ask why `Float.FromInt(n)` is still their job everywhere else ([81](81-how-is-an-int-converted-to-a-float.md)).
The answer would have to be "because a literal has no run-time identity and a value does", which
is true and is a rule a person has to hold.

<!-- Round 1, asked 2026-09-20. -->

## Not decided here

- **A non-literal `int` operand beside the union** — `basket >= threshold`, where `threshold` is
  a declared `int`. That is a value, not a literal, so the argument above does not reach it and it
  stays the mixed pair under either answer. Asking it here would make this two questions.
- **What arithmetic answers.** `basket * 100` under a yes needs a result type, and the only honest
  one is the union itself, which then has to satisfy the declared return — 83's *no* branch in
  miniature, and the reason `public int Owed(int | float)` was the program that was wrong under
  every answer. Gated by Q1 and asked after it, never beside it.
- **A union with a non-numeric part**, which [83](83-a-union-operand-at-an-operator.md) scoped out
  and nothing here moves.
