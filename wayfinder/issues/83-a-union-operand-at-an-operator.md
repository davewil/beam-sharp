# 83 — Is an `int | float` operand at an operator the mixed pair?

Type: grilling
Status: resolved 2026-09-19 — [ENG-392](https://linear.app/davewil/issue/ENG-392). Raised 2026-09-19
out of [ENG-387](https://linear.app/davewil/issue/ENG-387), the defect whose question this is;
one question, one round, answered the same morning
Blocked by: —

## Why this is raised

[Ticket 69](69-does-the-language-have-float.md) gave the language `float` and
[ticket 80](80-does-an-int-flow-where-a-float-is-expected.md) ruled that nothing flows between the
two parts: *"the emitted program is the written program."* Both list `int | float` among the things
that follow, and neither reaches it. Ticket 80's **Not decided here** leaves it out;
[ticket 81](81-how-is-an-int-converted-to-a-float.md) decided the conversion's spelling and not
this.

`op_result/5` (`compiler/src/bs_check.erl:4281`) says what happens meanwhile, and says it on
purpose:

> An operand in neither part — a `term`, a union, an operand already refused and so `none` —
> answers what `op_type/1` always answered, so nothing that compiled yesterday moves.

`part_of(int | float)` is neither `int` nor `float`, so the union falls to that clause and
**answers `int` at every operator**. The refusal that fires for `int` beside `float` never fires,
and the result type is `int` whatever the operands were.

## The program

An amount off the wire. JSON gives a whole number as an `int` and a fractional one as a `float`
([77](77-what-goes-on-the-wire.md)), so the parameter is both parts. This is a ledger posting rule:
a negative amount is money going back to the customer.

```csharp
module Ledger

type Side = :debit | :credit

public Side Post(int | float amount)

Post(amount) -> amount switch {
    a when a < 0 => :credit,
    _            => :debit
}
```

Measured at `44ca20c`. It compiles with no diagnostic, and:

| Call | Answers | |
| -- | -- | -- |
| `Post(-250)` | `:credit` | a £250 refund, posted as a credit |
| `Post(-2.50)` | `:debit` | **a £2.50 refund, posted as a charge** |
| `Post(250)` | `:debit` | |
| `Post(2.50)` | `:debit` | |

The clause-head spelling behaves the same way. What it compiles to says why:

```erlang
'Post'(A) when is_integer(A) andalso A < 0 -> credit;
'Post'(_) -> debit.
```

The `is_integer` is [ENG-330](https://linear.app/davewil/issue/ENG-330)'s, conjoined because a
relational guard credits int-ness the emitter must then establish. Against an `int | float`
subject it silently removes the float half of the parameter from the arm. Ticket 80 said the
emitted program is the written program; the written guard is `a < 0`.

### The same form over a `float` subject is refused

```csharp
public Side Post(float amount)

Post(a) when a < 0 -> :credit
```

> error: `<` in Post has a `float` on its left and an `int` on its right
>   nothing converts between the two: write the conversion, `Float.FromInt(n)`,
>   on the `int` side, or write `0.0` to make the literal a float

So the rule exists and the union is the hole in it.

### The spelling that rule advises already works on the union

Writing the literal as a float is what the refusal above tells the author to do. Over an
`int | float` subject it compiles today, and the two emitted guards stand side by side:

```erlang
%% written `a < 0`   — the int literal
'Post'(A) when is_integer(A) andalso A < 0 -> credit;
'Post'(_) -> debit.

%% written `a < 0.0` — the float literal
'Post'(A) when A < 0.0 -> credit;
'Post'(_) -> debit.
```

No kind test is conjoined for the float literal, and the answers are the ones the program means:
`Post(-250)` and `Post(-2.50)` are both `:credit`. So the form a **yes** would have to refuse is
the form that behaves correctly at the guard right now.

It is not a safe form either, which is why this is one question and not two. The same literal in
the body face still lies:

```csharp
public int Owed(int | float amount)

Owed(a) when a < 0.0 -> a * 100
Owed(_)              -> 0
```

`Owed(-2.50)` returns `-250.0` from a function declared `int`. The guard lets the float in — as it
should — and the body types as `int` anyway.

## The program that is wrong under every answer

The same union operand in a body, under a declared `int` return. No guard is involved:

```csharp
module Pence

public int Owed(int | float amount)

Owed(a) -> a * 100
```

It compiles. `bsc --api` publishes `int Owed(int | float)`. Then `Owed(-2.50)` returns `-250.0`:
a float from a function declared `int`, which is the outcome §10's guarantee exists to rule out
and which F42 closed at every *foreign* declaration on 2026-09-11. This is a native function, so
no boundary guard is in play — the checker typed `a * 100` as `int` because `op_result/5` answered
`int` for the union operand.

Two further measurements pin it to that fallback rather than to a reading of the literal:

- Declaring the return `float` is refused, and the diagnostic names what the checker believes:
  *"not covered by the declared return type: `int`"*.
- `a * 100.0` — a float literal, which guarantees a float result — also compiles against the
  declared `int`. A rule where the literal picks the part would type this `float`.

An `int` subject beside a float literal is refused correctly (`Owed(a) -> a * 100.0` under
`public int Owed(int amount)`), so this is the union escaping the rule, not the rule being absent.

## Q1 — Is an `int | float` operand at an operator the mixed pair?

One question. Scope: a union whose parts are all numeric. A `term` operand, and a union with a
non-numeric part, are not decided here.

**If yes**, `Ledger` above is refused at its guard exactly as the `float` subject is, and `Pence` is
refused at `*`. The compiler delta is one `op_result/5` case: where either operand is a union whose
parts include `float` beside `int`, refuse as `mixed/6` already does.

**If no**, the guard is the BEAM's own comparison over two numbers. `Post(-2.50)` answers
`:credit`, and the delta is in two places: ENG-330's `kind_tested/2` must stop conjoining
`is_integer` where the operand's parts are all numeric, and `op_result/5` must answer the union of
the parts rather than `int`, so that `Pence` is refused for its return type instead.

### What the yes costs, measured

Under **yes**, the refusal cannot advise `0.0` the way the existing one does. Ticket 80's no-flow
rule is symmetric: an `int | float` operand beside a float literal has its `int` part beside a
float, so `a < 0.0` is refused for the same reason — and that is the spelling shown above to
compile and answer correctly at the guard today. The author must dispatch the parts instead.

**That is the BEAM's own idiom, and B# refuses it.** In Elixir the rule is two clauses:

```elixir
def post(x) when is_integer(x), do: :debit
def post(x) when is_float(x), do: :credit
```

The same shape in B#, measured at `44ca20c`:

```csharp
Post(a) when is_integer(a) -> :debit
Post(a) when is_float(a)   -> :credit
```

> error: Post uses is_integer, which nothing binds
> error: Post calls is_integer in a guard
>   a guard asks a question about the values a clause already
>   matched; it cannot call a function. Move the call into the
>   body and switch on its answer.
> error: Post is not exhaustive
>   no clause matches:
>     Post(n) -> ...
>     Post(f) -> ...

The advice is the finding: there is nothing in the body to move it to. `switch` switches on
values, and no expression asks which part a number lies in. The other spellings an author would
reach for:

| Attempt | Result |
| -- | -- |
| `Post(float a) -> ...` | `syntax error before: a` |
| `Post(a) when a is float` — C#'s own type test, and TypeScript's predicate form | `syntax error before: is` |
| `Post(Amount a)` after `type Amount = int \| float` | refused: *"Amount is not a record, so it cannot name a pattern"* |
| `using :erlang { bool is_float(term x) }`, then `when :erlang.is_float(a)` | **compiles, and is correct** |

The one route that works declares a BEAM guard BIF through the FFI.

**This is a ticket of its own, not a cost of the yes.** Under **no**, `Pence` is refused on its
return type, and the honest rewrite is still one clause per part — so any program that treats the
parts differently needs the spelling under either answer. What the answer here changes is only
whether `Ledger`, which treats them the *same*, also needs it.

Three things bear on that ticket and none of them decides it:

- [Ticket 08](08-head-and-guard-syntax.md) listed *"narrow in the head with a type pattern
  instead — simplest semantics, and pushes conditions into patterns where the checker credits
  them"* among four alternatives, all of them about `dynamic`, which
  [ticket 11](11-type-system-shape.md) then removed from the language.
- [Ticket 55](55-destructure-and-bind.md) gave that shape a grammar — `Frame f`, the signature's
  own `type_prim lident` — but decided it for **records**, whose tag is what the pattern matches.
  `int` and `float` mint no tag, so 55's mechanism does not reach them.
- [Ticket 69](69-does-the-language-have-float.md) recorded *"Discriminable by `is_float/1`, so
  `int | float` satisfies ticket 09 §4 and a clause head can tell the two apart"*. That is the
  algebra's discriminability criterion, which the checker uses to judge a union legal; it reads as
  a claim about the surface, and the surface has no such form.

<!-- Round 1, asked 2026-09-19. -->

## The answer

**Yes — it is the mixed pair.** David, 2026-09-19: *"So 83 yes mix pair, with the 84 answer."*

`Ledger`'s guard and `Pence`'s `*` are both refused, and the author splits the parts first with
[84](84-dispatching-the-parts-of-a-numeric-union.md)'s type-prefix pattern.

### What this costs, stated plainly

`a < 0.0` over an `int | float` subject **stops compiling**. It compiles today, emits no kind test,
and answers correctly for both parts — and it is refused under this answer, because 80's no-flow
rule is symmetric and the `int` part of the union is beside a float literal. The form that behaves
correctly today is the form that goes away, and the two clauses replace it.

Nothing shipped pays that cost: no `int | float` operand appears in `LANGUAGE.md`, `TOUR.md` or
`compiler/examples/`, and the one suite case over the union,
`float_tests.erl:int_or_float_is_discriminable_test`, dispatches on **literal heads**
(`Kind(0)`, `Kind(0.0)`), which are patterns and never reach `op_result/5`.

### The refusal and 84's pattern land together

The refusal `mixed/6` prints offers the int literal's float spelling — *"write `0.0`"* — and under
this answer that advice is refused too. The only correct advice is to dispatch the parts, which
does not parse today. **A refusal whose advice does not compile is the defect it exists to
prevent**, so this ships with 84's form and not before it: one feature, the coupling ticket 55
recorded for the type prefix and the binder, in a second costume.

### The emitter is untouched

The ticket's *no* branch had a delta in `kind_tested/2`. The *yes* has none: no relational guard
over a union operand compiles under it, in either literal spelling, so
[ENG-330](https://linear.app/davewil/issue/ENG-330)'s conjunction never meets one.

## Not decided here

- **A numeric union with a non-numeric part.** Q1 was scoped to a union whose parts are all
  numeric, and that is what was answered. `int | float | :none` keeps today's
  `op_type(Op)` fallthrough and today's defect with it — the same hole, one member wider. Seen,
  not missed.
- **`term` at an operator**, which the same fallthrough covers and which nothing here moves.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [Is an `int | float` operand at an operator the mixed pair?](issues/83-a-union-operand-at-an-operator.md)
  — **yes: a union whose parts are all numeric is the mixed pair wherever one part would be, so
  the operand is refused and the author splits the parts first.** Raised and resolved 2026-09-19
  in one round on one question, out of [ENG-387](https://linear.app/davewil/issue/ENG-387), and
  widened past that defect's framing by measurement: `op_result/5` answers what `op_type/1`
  always answered for an operand in neither part, so the union escapes the refusal **and** the
  result type at every operator, bodies included — `public int Owed(int | float amount)` with
  `Owed(a) -> a * 100` compiles, publishes `int Owed(int | float)` through `--api`, and returns
  `-250.0`, which is what §10's guarantee exists to rule out and what F42 closed at every
  *foreign* declaration. The guard face is the same fallthrough: `a < 0` emits
  `is_integer(A) andalso A < 0` and drops the float half, so a ledger rule posts a `-2.50` refund
  as a debit. The delta is one `op_result/5` case, inheriting the operator set of the existing
  `{int, float}` clause rather than naming a new one; the emitter is untouched, because no
  relational guard over a union operand compiles under this answer. **The cost is a form that
  works today**: `a < 0.0` over the union compiles, emits no kind test and answers correctly for
  both parts, and is refused under the symmetry of [80](issues/80-does-an-int-flow-where-a-float-is-expected.md)'s
  no-flow rule. Nothing shipped pays it — no `int | float` operand in `LANGUAGE.md`, `TOUR.md` or
  the corpus, and `float_tests.erl`'s one case dispatches on literal heads, which never reach the
  operator. **It ships with [84](issues/84-dispatching-the-parts-of-a-numeric-union.md)'s
  type-prefix pattern and not before**, because the advice `mixed/6` prints is *"write `0.0`"*,
  which this answer also refuses, and a refusal whose advice does not compile is the defect it
  exists to prevent. Corrections on the record: [69](issues/69-does-the-language-have-float.md)'s
  *"a clause head can tell the two apart"* is the algebra's discriminability criterion and not a
  surface form, and ENG-387's *"with `0.0` as the advice"* is false under this answer. A numeric
  union with a non-numeric part — `int | float | :none` — was scoped out of the question and
  keeps today's behaviour. Unbuilt — F53.
```
