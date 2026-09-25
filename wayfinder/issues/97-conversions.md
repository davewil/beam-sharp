# 97 — Conversions: one spelling for every `X` to `Y`, and what a failed one returns

Type: grilling
Status: open — [ENG-449](https://linear.app/davewil/issue/ENG-449). Raised 2026-09-25 by David
Blocked by: —

## Why this is raised

David, 2026-09-25: *"Float.FromInt is the only conversion supported, there should be many
others."* Ticket 81 chose `Float.FromInt` by C#'s `Target.FromSource` convention (`TimeSpan.FromSeconds`)
and named its reverse, `Int.FromFloat`, without deciding it (*"truncate or round is asked"*).
`ToExistingAtom` (ticket 67) is the one partial conversion shipped, and it returns
`result<atom, string>`, the failure carrying the input.

What the exemplars convert by hand today, measured on `a0f9cbf`:

```csharp
// 25e: money as text. `integer_to_binary` appears 10 times across the corpus
using :erlang { binary integer_to_binary(int n) }
Money(cents) -> ["£", :erlang.integer_to_binary(cents / 100), ".", Pence(cents % 100)]

// Foreign: text to int, through the foreign failure channel
using :erlang { result<int, foreign_error> binary_to_integer(binary b) }
```

The first returns `binary` where the value is a `string`, so it cannot flow where a `string` is
expected without `ValidateAs<string>`. The second, handed `"1x"`, returns `(:error, (:error, :badarg))`, which names
nothing about the text.

## Round 1

**Q1. Does every conversion follow `Target.FromSource`, a total one returning `Target` and a partial
one returning `result<Target, string>` whose failure is the input it could not read, as
`ToExistingAtom` does?**

```csharp
Money(cents) -> ["£", String.FromInt(cents / 100), ".", Pence(cents % 100)]

public result<int, string> Quantity(string field)
Quantity(f) -> Int.FromString(f)
```

Under yes: `String.FromInt` is `integer_to_binary/1`, typed `string` because its output is ASCII
digits. `Int.FromString("12")` is `12`, and `Int.FromString("1x")` is `(:error, "1x")`, lowered to
`binary_to_integer/1` with `badarg` caught, as F54 catches it. The same rule covers
`Float.FromString`, `String.FromFloat` (`float_to_binary(F, [short])`), `String.FromAtom`
(`atom_to_binary`, total) and `Atom.FromString` (`ParseAtom<T>` and `ToExistingAtom` already own
that direction). Under no, each conversion's failure shape is decided on its own.

Compiler delta: rows in ticket 96's signature table, if 96 answers yes, or generated forms if it
answers no. The partial ones share F54's `try`/`catch error:badarg` lowering.

What stays for round 2: `Int.FromFloat` is not a conversion that can fail but one that must choose
a rounding. Whether it is one operation or `Float.Truncate`, `Round`, `Floor` and `Ceiling`, each
`float -> int`, as Elixir and Erlang spell them, is asked after Q1.
