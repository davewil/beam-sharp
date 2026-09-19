# 83 — Is an `int | float` operand at an operator the mixed pair?

Type: grilling
Status: claimed — [ENG-392](https://linear.app/davewil/issue/ENG-392). Raised 2026-09-19 out of
[ENG-387](https://linear.app/davewil/issue/ENG-387), the defect whose question this is
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
compile and answer correctly at the guard today. The author must dispatch the parts first — and
**there is no native spelling for that today**. Measured at `44ca20c`:

| Attempt | Result |
| -- | -- |
| `Post(float a) -> ...` | `syntax error before: a` |
| `Post(a) when Type.IsFloat(a)` | refused: *"a guard … cannot call a function"* |
| `Post(Amount a)` after `type Amount = int \| float` | refused: *"Amount is not a record, so it cannot name a pattern"* |
| `using :erlang { bool is_float(term x) }`, then `when :erlang.is_float(a)` | **compiles, and is correct** |

The one route that works declares a BEAM guard BIF through the FFI. Ticket 69 recorded
*"Discriminable by `is_float/1`, so `int | float` satisfies ticket 09 §4 and a clause head can tell
the two apart"* — true of the algebra, and the surface has no spelling for it. So a **yes** costs a
follow-up ticket for that spelling, and until it lands the only way to write `Ledger` is the FFI
escape hatch.

Under **no**, `Ledger` needs no spelling, and the missing discrimination form stays a matter for
whenever a program wants the two parts handled differently.

<!-- Round 1, asked 2026-09-19. -->

## Decisions entry

<!-- Written on resolution. -->
