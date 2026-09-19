# 84 — How does a clause head dispatch the parts of a numeric union?

Type: grilling
Status: open — [ENG-393](https://linear.app/davewil/issue/ENG-393). Raised 2026-09-19 by David
while [83](83-a-union-operand-at-an-operator.md) was in its first round
Blocked by: —

## The invariant this starts from

David, 2026-09-19:

> we have this invariant — `public Side Post(int | float amount)` must be declarable. If the
> current clause heads can't express that then a mechanism is needed.

The declaration is legal today, and [ticket 69](69-does-the-language-have-float.md) says why it
should be: `int | float` satisfies [ticket 09](09-union-representation.md) §4 because `is_float/1`
separates the two parts. What 69 recorded next — *"and a clause head can tell the two apart"* — is
the algebra's discriminability criterion, which the checker uses to judge the union legal. The
surface has no form for it, so the type can be declared, passed and returned, and a clause head
cannot pick a part.

That is the same shape [LANGUAGE.md](../../LANGUAGE.md) names for `map<K, V>`: *"`Slot` can be
declared, passed and returned and never matched on"*, and calls **temporary by construction**.

## What is refused today

Measured at `44ca20c`. The BEAM's own idiom first — this is how the rule is written in Elixir:

```elixir
def post(x) when is_integer(x), do: :debit
def post(x) when is_float(x), do: :credit
```

```csharp
public Side Post(int | float amount)

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

The advice cannot be followed: `switch` switches on values, and no expression in the language asks
which part a number lies in. The residual is the two clauses the author just wrote.

| Attempt | Result |
| -- | -- |
| `Post(a) when is_integer(a)` — the BEAM idiom | three errors, above |
| `Post(a) when a is float` — C#'s type test, and TypeScript's predicate form | `syntax error before: is` |
| `Post(float a)` — the signature's own shape in pattern position | `syntax error before: a` |
| `Post(Amount a)` after `type Amount = int \| float` | *"Amount is not a record, so it cannot name a pattern"* |
| `using :erlang { bool is_float(term x) }`, then `when :erlang.is_float(a)` | **compiles, and is correct** |

So the language's escape hatch works and the language does not.

## What bears on the answer

- [Ticket 08](08-head-and-guard-syntax.md) listed *"narrow in the head with a type pattern instead
  — simplest semantics, and pushes conditions into patterns where the checker credits them"* as one
  of four alternatives. All four were about `dynamic`, which [ticket 11](11-type-system-shape.md)
  removed from the language, so none of them is a decision. The instinct is on the record; the rule
  is not.
- [Ticket 55](55-destructure-and-bind.md) decided that **a record pattern may name its type** —
  `Frame f`, C#'s bare trailing designation, *"which is also the shape a signature already has
  (`param -> type_prim lident`, so `Order o`)"*. It was decided for records, and the compiler says
  why it stops there: *"only a `record` declaration mints the tag a type prefix matches on."* A
  record pattern matches a tag; `int` and `float` mint none, so 55's mechanism does not reach them
  and this is not 55 unbuilt.
- **55's grammar measurement does not transfer.** [`55f`](../prototypes/55f_yecc_conflicts.sh)
  measured three variants at zero yecc conflicts, but every one of them begins with a `uident` —
  `Frame { … } f`. `float a` begins with a **type primitive**, a different token class, and `is`
  is a third shape again. The conflict count for whichever spelling wins is the feature's work to
  measure, not this ticket's to assume: yecc resolves a shift/reduce conflict silently, so a quiet
  build proves nothing.
- **Guards cannot call functions, and that is deliberate** — *"a guard asks a question about the
  values a clause already matched"*. A spelling that looks like `is_float(a)` therefore has to be
  a form the grammar knows, not a call the checker whitelists, or it reopens that rule.

## The shape already exists, and stops at records

David, 2026-09-19, on reading the three candidates: *"I would have thought `Post(float a)` — the
signature's own shape in the pattern position — would be the most obvious answer."* The evidence
is stronger than obviousness. LANGUAGE.md, on records: *"the tag is in the term, so a union of
records is dispatched by an ordinary clause head and checked exhaustive"*. Measured side by side
at `d0e9d7b`:

```csharp
type Shape = Circle | Rect

public float Area(Shape s)

Area(Circle c) -> 3.14159 * c.Radius * c.Radius
Area(Rect r)   -> r.W * r.H
```

Compiles, proves exhaustive with **no catch-all**, and runs: `Area` of a `Circle` at radius `2.0`
is `12.56636`, of a `Rect` at `3.0 × 4.0` is `12.0`.

```csharp
public Side Post(int | float amount)

Post(int a)   -> :debit
Post(float a) -> :credit
```

> error: syntax error before: a

The same shape over a union whose members are parts rather than records. So the surface the
invariant asks for is already in the language, already credited by the exhaustiveness checker, and
stops exactly where the member has no minted tag.

### Why this beats both guard spellings, on the language's own terms

A pattern is credited for exhaustiveness; a guard is not. LANGUAGE.md states it for this very
part: *"A float guard compares as the BEAM compares and credits nothing to exhaustiveness … so a
dispatch over `float` closes with a catch-all."* So even a B# that let a guard call `is_float`
would leave `Post` unable to close its clause set without a catch-all, and the catch-all is what
hides the next missing part. The type-prefix pattern closes it, which is what
[ticket 08](08-head-and-guard-syntax.md) meant by *"pushes conditions into patterns where the
checker credits them"*.

That makes this a question about **extending a decided form to a second kind of member**, rather
than about choosing among three unrelated spellings.

## Q1 — What spells "this clause takes the `float` part"?

Not asked yet: [83](83-a-union-operand-at-an-operator.md) is the round in flight, and this ticket
is independent of its answer rather than gated by it. Under a *no* to 83,
`public int Owed(int | float amount)` is refused on its return type and the honest rewrite is
still one clause per part; under a *yes*, every operator over the union needs the parts split
first. Both need this.

If the answer is the type prefix, three things follow and none is settled by picking it:

1. **How far does the form reach?** The natural rule is that `T x` is a pattern wherever the
   [09](09-union-representation.md) §4 criterion says the member is separable — which is machinery
   the checker already computes to judge a union legal. That rule refuses `list<int> a` for the
   reason `Slot` is refused, and refusing it in the *same words* is the point.
2. **The grammar must be measured, not assumed.** `type_prim lident` in pattern position is a
   different token class from the `uident` every [`55f`](../prototypes/55f_yecc_conflicts.sh)
   variant measured, so 55's three zeros say nothing here. yecc resolves a shift/reduce conflict
   silently, so a quiet build is not the measurement.
3. **A pattern form owes the switch arm too.** A head-only answer leaves `x switch { int a => … }`
   a syntax error, and an arm is classified in a different function from a clause head — the trap
   F51 hit, where a refusal wired at the clause site missed the arm and a dead arm shipped as a
   warning.

<!-- Raised 2026-09-19, not yet asked. -->

## Decisions entry

<!-- Written on resolution. -->
