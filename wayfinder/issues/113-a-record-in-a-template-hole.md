# 113 — May a record print itself in a template hole?

Type: grilling
Status: claimed — [ENG-563](https://linear.app/davewil/issue/ENG-563). Raised 2026-09-28 by David,
straight after [112](112-an-arithmetic-operand-with-no-numeric-part.md) resolved
Blocked by: —

## Why this is raised

David, on reading 112's resolution: *"That's where protocols for records might be useful? Build a
representation for use in template strings?"*

[112](112-an-arithmetic-operand-with-no-numeric-part.md) Q3 gave a hole a fixed table: `string`,
`int`, `float` and an atom type, each printed by a total BIF chosen from the hole's static type. A
record is refused, because it has no single obvious printing.
[99](99-protocols-revisited.md) Q5 kept the compiler to `Enumerable` only: *"`String.Chars`,
`Inspect` and `Collectable` wait for a program that wants them, each as its own question."* A
template hole is that program, and this is that question.

What makes it different from Elixir is 99 Q4: *"An implementation lives in the type's own module
and nowhere else."* A hole's type is static, so for a record type the compiler knows which module
would hold the implementation, and whether that module exports it. Elixir's `String.Chars` finds out
at run time, raising `Protocol.UndefinedError`, with a compile-time warning since 1.19 only when
protocols are consolidated ([research 112](../research/112-template-strings.md), Elixir §2). B# can
refuse at compile time instead.

## Round 1

**Q1. May a record fill a template hole when its own module implements a compiler-known protocol
that prints it?**

A value object from a billing module. The protocol's name, `Printable`, is proposed here and asked
as Q2:

```csharp
module Billing

record Money { Pence: int }
record Order { Id: int, Customer: string, Total: Money }

implements Printable for Money {
    string ToString(Money m) -> $"£{m.Pence / 100}.{Pad(m.Pence % 100)}"
}

private string Pad(int p)
Pad(p) when p < 10 -> $"0{p}"
Pad(p)             -> $"{p}"

public string Line(Order o)
Line(o) -> $"Order {o.Id} for {o.Customer}: {o.Total}"
// "Order 42 for Ada: £12.50"
```

Under **yes**, this compiles. The `{o.Total}` hole has type `Money`, and `Money`'s module
implements `Printable`, so the hole lowers to a direct call:
`('Billing':'bs@Printable@ToString'(maps:get('Total', O)))/binary`. With one record type the call
needs no dispatch. A union of records, say `Money | Refund`, is accepted when every member's module
implements it, and lowers to a call whose module is read from the tag, as 99 Q1 lowers
`Enum.Sum`. The implementation returns `string`, so the template stays a `string` with no run-time
check. A record whose module does not implement `Printable` is refused at compile time, naming the
record and the declaration it lacks:

```
Billing/Billing.bs:17:43: error: Line puts a Money in a template hole, and Money cannot print
  a hole takes string, int, float, an atom, or a record whose module implements Printable:
    implements Printable for Money { string ToString(Money m) -> ... }
```

(That wording is proposed; nothing prints it yet.) A hand-written tagged member, `{ Kind: :placed,
… }`, has no module, so it is still refused. It joins by being wrapped in a record, as 99 Q4
says of a tuple or a foreign struct. 112 Q3's table reads as `Printable`'s built-in
implementations for the four parts.

Under **no**, a record is still refused in a hole, as 112 Q3 has it, and the line is written with
an ordinary function the author names:

```csharp
public string Line(Order o)
Line(o) -> $"Order {o.Id} for {o.Customer}: {MoneyText(o.Total)}"
```

That compiles as soon as ENG-562 lands, with no protocol machinery. The cost is that every hole
holding a `Money` names the function, and nothing ties a type to its printing.

**The compiler delta under *yes*.**

- It rides on the `implements` machinery ENG-458 builds for `Enumerable`: the declaration, allowed
  only in the type's own module, and the `bs@`-prefixed export (ticket 87's precedent).
- A second compiler-known protocol in stratum two: `Printable { string ToString(Self s) }`. This
  amends 99 Q5's *"`Enumerable` only"*.
- `type_of(e_interp)`, from ENG-562, accepts a hole whose record members' modules all export the
  implementation, and extends `interp_hole` to name the missing `implements`.
- The emitter makes a direct remote call for one record type, and reads the module from the tag for
  a union.
- Tests through the CLI: `Line` above, a union of two printable records, a record with no
  implementation (refused), and a hand-written member (refused).

So the build waits on ENG-562 (templates) and ENG-458 (`implements`).

➡️ **Recommended: yes.** It is the program 99 Q5 waited for. 99 Q4 makes it checkable, so B# gets
C#'s `ToString` convenience without Elixir's run-time failure. It also keeps a value's printing in the value's
own module, beside its declaration, which is where DDD keeps it.

**A1 (David, 2026-09-28):** *"Yes."* A record fills a template hole when its own module implements
the compiler-known printing protocol. A union is accepted when every member does. Anything else is
refused at compile time, naming the missing `implements`. 99 Q5's *"`Enumerable` only"* is
amended: the compiler ships two protocols.

## Round 2

Asked 2026-09-28. Round 1 held back a second question, whether the operation can be called
directly, outside a template. That is already decided. 99's decisions entry calls a protocol's
operation `Shape.Area(c)`, never `c.Area()`, so this one is called `Name.ToString(m)` whatever the
name. That leaves only the name.

**Q2. Is the protocol `Formattable`, with one operation, `ToString`?**

```csharp
implements Formattable for Money {
    string ToString(Money m) -> $"£{m.Pence / 100}.{Pad(m.Pence % 100)}"
}

// in a template, the hole calls it:     $"Total: {o.Total}"
// anywhere else, called as 99 spells it: Formattable.ToString(o.Total)
```

The name follows the route `Enumerable` took: .NET's `IEnumerable` without the `I`. In C#,
`IFormattable` is the interface an interpolated hole consults. It carries `ToString(format,
provider)`, the path a `{o.Total:F2}` format specifier takes ([research 112](../research/112-template-strings.md),
C# §2). If format specifiers are ever decided (fog since 112), the name already fits them.
`ToString` is C#'s own operation name.

Under **no**, the protocol takes another name. The ones on record:

- `Printable`, this ticket's placeholder;
- `String.Chars`, Elixir's, which puts a protocol under `String`, a qualifier [96](96-standard-environment-breadth.md) reserved;
- `Display`, Rust's;
- `Show`, Haskell's.

The compiler delta is the same under both answers. Only the protocol's name changes.

One thing to check against: [97](97-conversions.md) spells a conversion `Target.FromSource`
(`String.FromInt`). This operation is not one of 97's rows, a conversion between two named types.
It is a protocol's operation, called by the protocol's name (99), as `Shape.Area` is. So
`Formattable.ToString(m)` sits beside `String.FromInt(n)` without contradicting it.

➡️ **Recommended: yes.** It is C#'s name, derived the way `Enumerable` was, and it leaves format
specifiers somewhere to go.

## Not decided here

- `Inspect`, a debugging representation of any value, which 99 Q5 also held back.
- Format specifiers inside a hole (`{o.Total:F2}`), which are fog on the map since 112.
