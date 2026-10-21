# 118 — The `List` and `Map` rows a build could not take on ticket 96's words alone

Type: grilling
Status: open — [ENG-878](https://linear.app/davewil/issue/ENG-878). Raised 2026-10-21 by the F75 build
([ENG-454](https://linear.app/davewil/issue/ENG-454)); one round, five questions
Blocked by: —

## Why this is raised

[96](96-standard-environment-breadth.md) decided that a standard operation is the OTP function
that already does it (Q1), named as Elixir names it (Q2), with every operation that can find
nothing coming as a pair (Q3). F75 built seventeen rows on those words, collection first so a
pipe feeds it (David, 2026-10-21: *"should definitely be pipe friendly order"*). Five places are
where the three rules disagree with each other or say nothing, and a build that picked would be
making the decision. Each question is independent of the others.

Measured on F75's build (`bddd505`, with its review fixes), OTP 28.

## Round 1

**Q1. Does `List.Zip` stop at the shorter list, as Elixir's does?**

```csharp
public list<(int, atom)> Pairs(int n)
Pairs(n) -> List.Zip([n, 2], [:a])
```

Today `List.Zip` is `lists:zip/2`, and this call **crashes** with `function_clause`. Elixir's
`Enum.zip/2` and `List.zip/1` stop as soon as either list ends, giving `[(n, :a)]`. Both answers
are OTP's own function, so Q1 of 96 holds either way: under yes the row's target is
`lists:zip/3` with `trim` as a third argument (OTP 26 and later), and under no it stays
`lists:zip/2`.

Compiler delta under yes: the row's argument order gains a constant, `[1, 2, {atom, trim}]`, so
`bs_emit:otp_args/3` can append an argument a row fixes. Nothing in the checker changes.

**Q2. Is `List.Flatten` one level?**

```csharp
public list<int> All(list<list<int>> groups)
All(gs) -> List.Flatten(gs)
```

Elixir's `List.flatten/1` is `lists:flatten/1`, which flattens at every depth. No B# signature
says that: written `list<T> Flatten<T>(list<list<T>> xs)`, a `list<list<list<int>>>` would be
promised `list<list<int>>` and handed `list<int>`, a type the checker trusts and the value does
not have. One level is `lists:append/1` (Elixir's `Enum.concat/1`), whose signature is exactly
that line.

Under yes: `List.Flatten` is one level, a declared row over `lists:append/1`, and the program
above compiles. Under no (every depth, as Elixir): the signature needs a type operation the
algebra does not have, *the innermost element of a nested list*, written as a new kind of
signature entry and computed by a new `bs_types` function; until then `List.Flatten` is refused.

**Q3. Does `List.Insert` take Elixir's `insert_at` index rules?**

```csharp
public list<int> Pushed(list<int> xs, int n)
Pushed(xs, n) -> List.Insert(xs, -1, n)
```

No OTP function inserts at an index, so 96 Q1 does not reach it: this is the second `generated`
row after `Term.Compare`, a local function written into the module that uses it. Elixir's
`List.insert_at/3` appends when the index is past the end and counts a negative index from the
end (`-1` appends), so the program gives `xs ++ [n]`. The alternative is OTP's own style,
`lists:split/2` and an append, which crashes on an index past the end or below zero.

Compiler delta either way: one `generated` row and its `bs_emit:reserved_form/1` clause. Under
yes the clause handles the two Elixir cases; under no it is `lists:split/2` and nothing else.

**Q4. Is `Map.Update` Elixir's `update/4`, total with a default, and its crash-on-missing form
one of 96 Q3's pairs?**

```csharp
public map<string, int> Counted(map<string, int> m, string word)
Counted(m, w) -> Map.Update(m, w, 1, n => n + 1)
```

Elixir has two: `Map.update/4`, which inserts the default when the key is missing, and
`Map.update!/3`, which raises. OTP has both, as `maps:update_with/4` and `maps:update_with/3`.
The `/3` form is an operation that can find nothing, so 96 Q3 makes it a pair, whose second
form ticket 108 spells with a `?`.

Under yes: `Map.Update/4` is a declared row over `maps:update_with/4` today, and
`Map.Update/3` waits with the other pairs on [ENG-324](https://linear.app/davewil/issue/ENG-324).
Under no, the issue says which one `Map.Update` is.

**Q5. Is a sought value of a type the collection cannot hold refused?**

```csharp
public bool Has(list<int> xs)
Has(xs) -> List.Contains(xs, "x")
```

Today this **compiles** and returns `:false` for every list: F75 types the value looked for as
`term` in `List.Contains`, `List.Delete`, `Map.Remove`, `Map.Has`, `Map.Take` and `Map.Drop`,
because a value of another type is never found, so it can neither fail nor widen the result.
C# refuses the equivalent (`List<int>.Contains("x")` does not type-check); Elixir accepts it.

Under yes: each of the six refuses an argument whose type has no overlap with the element (or
key) type, naming both. Compiler delta: a new diagnostic, an overlap check
(`bs_types:intersect/2` is `none`) in the six rows. The signature text cannot say it, so it is
the first per-row check outside a declared signature. Under no: nothing changes.
