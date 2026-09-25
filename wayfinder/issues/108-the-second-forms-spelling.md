# 108 — How is the non-crashing form of a pair spelled? (`Map.Get` and every 96 Q3 pair)

Type: grilling
Status: claimed 2026-09-25 — [ENG-471](https://linear.app/davewil/issue/ENG-471). Raised 2026-09-25
out of [ENG-324](https://linear.app/davewil/issue/ENG-324); round 1 below
Blocked by: —

## Why this is raised

[48](48-a-map-type-in-the-prelude.md) Q8 decided two operations for `Map.Get`, assertive preferred.
[96](96-standard-environment-breadth.md) Q3 widened that to every operation that can find nothing
(`First`, `Last`, `At`, `Max`, `Min`, `Find`, `Map.Get`), made the **crashing form the plain
name**, and left *"one naming convention for the pair … decided once for all of them"* to
ENG-324. Tickets 96, [97](97-conversions.md) and [98](98-task-and-agent.md) wrote the other form
with `Try` as a placeholder (`List.TryMaxBy`, `Int.TryFromString`, `String.TryFromBinary`,
`Task.TryAwait`). The row tickets ENG-453, 454, 456, 457, 462 and 463 each stop at their pair rows
until this is named.

Both of ENG-324's original blockers are gone: `raise` is built (F34), and 96 Q3 put the crash on
the plain name, so no `!` is needed. The return types are already decided per family: a lookup's
second form returns `option<T>` (`T | :nothing`), a conversion's returns `result<T, string>`
carrying the input (97), and `Await`'s returns its own error pair (98). Only the spelling is open.

## Q1 — Is the non-crashing form spelled with C#'s `Try` prefix?

The borrow heuristic surveys C# first, and `Try` is C#'s own name for the non-throwing variant
(`int.TryParse`, `Dictionary.TryGetValue`, `TryAdd`), always beside a plain name that throws,
which is the ordering 96 Q3 already chose. Elixir's pair cannot be borrowed: it marks the
*crashing* form (`fetch!`), and B# has no `!` (ticket 63) and put the crash on the plain name.

A web handler under yes (unbuilt surface, spelled as it would be):

```csharp
public result<Session, atom> Current(map<string, Session> sessions, string token)
Current(ss, t) -> Map.TryGet(ss, t) switch {
    :nothing => (:error, :no_session),
    s        => s
}

public Session Known(map<string, Session> sessions, string token)
Known(ss, t) -> Map.Get(ss, t)                       // a missing token crashes, via `raise`

public result<int, string> Page(string raw)
Page(r) -> Int.TryFromString(r)                      // "2x" is (:error, "2x")
```

**Under yes**, the placeholders in 96, 97 and 98 become the names: `Map.TryGet`, `List.TryFirst`,
`TryLast`, `TryAt`, `TryMax`, `TryMin`, `TryFind`, `Int.TryFromString`, `Float.TryFromString`,
`String.TryFromBinary`, `Process.TryWhereis`, `System.TryEnv`, `Task.TryAwait`. Compiler delta:
none beyond the rows the row tickets already owe; each pair is two rows on F62's table, and ENG-324
builds `Map.Get` and `Map.TryGet` first.

One collision to know about: ticket [94](94-a-fallible-map-over-a-list.md) (open) proposes
`List.TryMap`, a map whose **function** may fail, returning `result<list<U>, E>`. Under this
convention `TryX` reads as "the form of `X` that does not crash", and `List.Map` never crashes, so
`TryMap` has no plain partner and means something else. That is ticket 94's to rename, or to keep
knowingly, once this answer exists.

**Under no**, round 2 asks for the spelling itself.

## Decisions entry

<!-- Written when the ticket resolves. -->
