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

*Rewritten 2026-09-25 before it was asked. Ticket 96 Q3 (resolved) made every operation that can
fail a pair, so the draft's single `result` shape no longer stood alone. The draft asked one
question; it is two, and they are independent.*

**Q1. Is every conversion spelled `Target.FromSource`, as ticket 81 spelled `Float.FromInt`?**

```csharp
Money(cents) -> ["£", String.FromInt(cents / 100), ".", Pence(cents % 100)]
Quantity(f)  -> Int.FromString(f)
Label(a)     -> String.FromAtom(a)
```

Under yes, the set is `String.FromInt`, `String.FromFloat`, `String.FromAtom`, `Int.FromString`,
`Float.FromString` and `Float.FromInt` (shipped). The conversion lives under the type it produces,
so `String`'s rows are where a reader looks for "a string from X". Under no, C#'s instance spelling
does not port (`n.ToString()` is the dot-as-call ticket 91 Q3 refused), so the alternative is
`Int.ToString(n)` and `Int.Parse(s)`, under the source type.

**Q2. Does ticket 96 Q3's pair reach a conversion that can fail, with the second form returning
`result<Target, string>` whose failure is the input, not `option<Target>`?**

```csharp
Quantity(f) -> Int.FromString(f)            // "1x" crashes, naming the text
Safe(f)     -> Int.TryFromString(f)          // "1x" is (:error, "1x")
```

Under yes, the plain form crashes, and the other returns the text it could not read, as
`ToExistingAtom` returns `result<atom, string>`. A parse's failure has a reason worth carrying,
where a lookup's absence (`Map.Find`) has none. `Try` is ENG-324's placeholder. Under no, the second
form is `option<int>`, and the failed input is the caller's to keep.

Compiler delta, either way: rows in ENG-452's table. The failing forms share F54's lowering, the
platform's `binary_to_integer/1` or `binary_to_float/1` with `badarg` caught.

**Held for round 2, since it depends on Q1's spelling:** `Int.FromFloat` has to choose a rounding,
not a failure. The choice is one operation, or `Float.Truncate`, `Round`, `Floor` and `Ceiling`,
each `float -> int`, as Erlang and Elixir spell them.

**Round 1 answered 2026-09-25 (David): Q1 yes, Q2 yes.**

- **Q1.** Every conversion is `Target.FromSource`, living under the type it produces:
  `String.FromInt`, `String.FromFloat`, `String.FromAtom`, `Int.FromString`, `Float.FromString`, and
  `Float.FromInt`, which already ships.
- **Q2.** A conversion that can fail is ticket 96 Q3's pair. The plain form crashes, naming the input.
  The other returns `result<Target, string>`, whose failure is the text it could not read, as
  `ToExistingAtom` does. Its prefix is ENG-324's.

## Round 2

**Q3. Is there no bare `Int.FromFloat`, but four conversions that name their rounding:
`Int.Truncate`, `Int.Round`, `Int.Floor` and `Int.Ceiling`, each `float -> int`?**

```csharp
Pence(amount) -> Int.Round(amount * 100.0)        // erlang:round/1: half away from zero
Pages(n, per) -> Int.Ceiling(n / per)             // erlang:ceil/1
```

Under yes, `Int.FromFloat` is refused and each rounding is spelled where it is used, under the
type it produces (Q1). `Round` is the platform's, half away from zero: `Int.Round(2.5)` is `3`,
where C#'s `Math.Round` gives `2`, rounding half to even. Under no, `Int.FromFloat` exists, and one
rounding, truncation (C#'s cast), is chosen for it.

**Q4. Is `String.FromBinary` the pair for text arriving as bytes, beside `ValidateAs<string>`?**

```csharp
Page(b) -> String.FromBinary(:erlang.iolist_to_binary(b))   // invalid UTF-8 crashes
Body(b) -> String.TryFromBinary(b)                           // (:error, <<255>>)
```

Measured on `a0f9cbf`: `ValidateAs<string>` already takes a `binary` to a `string`. `<<104,105>>` is
`"hi"`, and `<<255>>` is `ValidationError`, `Expected = "string"`. So the UTF-8 entry check that
LANGUAGE.md's status table and TOUR.md list as *not started* is built, and those rows are wrong.
Under yes, `String.FromBinary` is Q1's spelling of the same check, as a Q2 pair whose failure is the
binary. `ValidateAs<string>` stays for a `term`. Under no, `ValidateAs<string>` is the one spelling,
and a binary-to-string conversion reads as a validation.
