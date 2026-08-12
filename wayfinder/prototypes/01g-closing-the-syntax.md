# PROTOTYPE 01g — closing the three open syntax questions

> **Throwaway.** Ticket [01](../issues/01-sample-code.md), final pass. The atom sigil, the guard
> punctuation, and the nullary/unary clause ambiguity. Two of the three now have arguments rather
> than preferences.

---

## 1. The clause arrow — `->` not `=>`

The `(0) => 0;` problem is worse than "no anchor for the eye". **In C#, `(n) => n * 2` is a
lambda.** A clause head with the name elided is visually identical to a lambda expression, in a
language that also has lambdas.

```csharp
int Fib(Nat);

(0)            => 0;                          // clause? lambda? both parse to a C# reader
(n) when n > 1 => Fib(n - 1) + Fib(n - 2);
```

**Resolution: clauses use `->`, lambdas keep `=>`.** Each is idiomatic in the heritage it comes
from — `->` is Erlang's clause arrow, `=>` is C#'s lambda arrow — and the ambiguity disappears.

```csharp
int Fib(Nat);

(0)            -> 0;
(1)            -> 1;
(n) when n > 1 -> Fib(n - 1) + Fib(n - 2);

list<int> Doubled(list<int>);

(xs) -> xs.Map(x => x * 2);                   // clause arrow and lambda arrow, one line
```

That last line is the argument in miniature: two different arrows doing two different jobs, both
recognisable, neither guessable from the other.

Cost: `->` is not a C# token in this position, so it is one thing to learn. Against that, `=>`
meaning two different things would be a thing to *un*learn, repeatedly.

---

## 2. Guards — `&&` and `||`, and the reason is totality

The objection to C#'s operators was semantic, not cosmetic. Erlang's `,` and `;` carry
**fail-to-false**: a guard test that raises is treated as false rather than propagating. `&&` does
not work that way, so using it would imply behaviour the runtime does not deliver.

**But fail-to-false only matters when a guard test can fail**, and in beam-sharp a guard over
typed values cannot. If the checker knows `xs` is a `list<Line>`, then `xs.Length` cannot raise.
Erlang needs fail-to-false precisely because it has no types to rule the failure out.

```csharp
Outcome Apply(Order, Command);

(a, (:withdraw, amt)) when amt > 0 && amt <= a.Balance  -> ...;
```

So: **`&&` and `||`, with one scoped exception.** A guard mentioning a `dynamic` value *can* fail,
because nothing has been proved about it. Ticket 08 must decide whether that case is forbidden
(guards may not mention `dynamic`), given fail-to-false semantics explicitly, or made an error the
programmer must handle.

This also folds in prototype 01f's finding: the checker credits any condition it can translate
into a type operation, so much of what would have been a guard is a pattern anyway. What is left
in guards is arithmetic and comparison — exactly the part where `&&` and `||` read naturally to
the intended audience.

---

## 3. The atom sigil — three candidates, all with a cost

The 01b analysis offered two. There is a third, and the first two both collide with something
already in the prototypes.

### `:atom` — Elixir's

```csharp
type Status = :draft | :placed | :shipped;

({ Status: :draft } o, (:add_line, l)) -> ...;
```

Every BEAM programmer reads it instantly. Three collisions: C#'s ternary `? :` (so ternary must
go), the attribute-target syntax `[module: GenServer]`, and — visible above — **`Status: :draft`
puts two colons adjacent**, one a field separator and one a sigil, doing unrelated jobs.

### `#atom`

```csharp
type Status = #draft | #placed | #shipped;

({ Status: #draft } o, (#add_line, l)) -> ...;
```

Reads more cleanly in property patterns, and `#` is C#'s preprocessor sigil which this language
does not have. **But it collides with the map literal `#{}` already used in the prototypes**
(`{ Orders: #{} }`), so `#` would be doing two jobs.

### `'atom'` — Erlang's own quoted form

```csharp
type Status = 'draft' | 'placed' | 'shipped';

({ Status: 'draft' } o, ('add_line', l)) -> ...;
```

No collision at all: it is exactly Erlang's quoted-atom syntax, and C#'s only use of `'…'` is the
char literal, which a BEAM language does not need (the BEAM has no char type — `$a` is an
integer). Ternary survives, `#{}` survives, property patterns read cleanly.

**Its cost is the oldest confusion in Erlang**: `'ok'` and `"ok"` look alike and are completely
different things — an atom and a binary. Every Erlang newcomer trips over it, and a C# reader
arrives expecting quotes to mean string.

### Where this lands — REVISED, both of my objections to `:atom` fail

**The ternary cost is not a cost.** No BEAM language has a ternary operator: not Erlang, not
Elixir, not LFE, and [Gleam explicitly replaces it with `case`](https://tour.gleam.run/flow-control/case-expressions/)
— "Gleam doesn't have a traditional ternary operator like `condition ? trueValue : falseValue`".
The objection was imported from C#, not from the platform, and the only people who would miss `?:`
are C# developers losing something the ecosystem they are joining never had.

**And the replacement is better than the thing given up: make `if` an expression.**

```csharp
Outcome RemoveLine(Order, string);

(o, sku) -> if (Found(o, sku)) (:ok, Removed(o, sku))
            else               (:error, (:no_such_line, sku));
```

Rust and Kotlin both do this; Elixir's `if` already returns a value and `if cond, do: a, else: b`
is the compact form Elixir programmers reach for daily. Expression-`if` is strictly more capable
than `?:` — it takes blocks as well as expressions — and it is a *more* familiar keyword to a C#
developer than the symbol they are losing. This also partly answers the intermediate-value
friction from 01b, since a conditional no longer forces a drop into a block body.

**The adjacent-colon objection also fails.** `{ Status: :draft }` is exactly the shape Elixir
writes as `%{status: :draft}` — the most-read syntax in that ecosystem, and nobody minds. That was
an aesthetic objection dressed as a technical one.

So `:atom` costs `[module: GenServer]` sharing a character in a positionally distinct place, and
nothing else. `#atom` still collides with the `#{}` map literal; `'atom'` still inherits Erlang's
oldest confusion. **`:atom` wins on the corrected analysis.**

---

## What ticket 01 can now record

- Variant A, module-as-focus, directory-as-module, source-only — the structural shape.
- `->` for clauses, `=>` for lambdas.
- `&&` and `||` for guards, with `dynamic` scoped to ticket 08.
- The atom sigil, once the map-literal interaction is decided with it.
