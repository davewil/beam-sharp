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

## Q1 — What spells "this clause takes the `float` part"?

Not asked yet: [83](83-a-union-operand-at-an-operator.md) is the round in flight, and this ticket
is independent of its answer rather than gated by it. Under a *no* to 83,
`public int Owed(int | float amount)` is refused on its return type and the honest rewrite is
still one clause per part; under a *yes*, every operator over the union needs the parts split
first. Both need this.

<!-- Raised 2026-09-19, not yet asked. -->

## Decisions entry

<!-- Written on resolution. -->
