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

**A1 (David, 2026-09-25):** *"Yes, with a prefix or suffix, but Try is not something I'm happy
with. Any thoughts?"* So: one affix convention for every pair, and not `Try`.

## Round 2

### Q2 — Is it a suffix that names what comes back: `OrNothing` for an `option`, `OrError` for a `result`?

The precedents with 96 Q3's ordering (the plain name crashes) all use a suffix, and the suffix
names the return: C#'s own LINQ has `First()` throwing and `FirstOrDefault()` returning a default
(`SingleOrDefault`, `ElementAtOrDefault`); Kotlin has `first()` throwing and `firstOrNull()`,
`toInt()` and `toIntOrNull()`. B# has no null and no default value: absence is `:nothing`
(`option<T> = T | :nothing`) and a failed conversion is an error carrying the input (97). So the
suffix is the word for what the caller gets instead:

```csharp
public result<Session, atom> Current(map<string, Session> sessions, string token)
Current(ss, t) -> Map.GetOrNothing(ss, t) switch {
    :nothing => (:error, :no_session),
    s        => s
}

public result<int, string> Page(string raw)
Page(r) -> Int.FromStringOrError(r)                  // "2x" is (:error, "2x")

public option<Order> Newest(list<Order> os)
Newest(os) -> List.MaxByOrNothing(os, o => o.PlacedAt)
```

**Under yes**: `Map.GetOrNothing`, `List.FirstOrNothing`, `LastOrNothing`, `AtOrNothing`,
`MaxOrNothing`, `MinOrNothing`, `FindOrNothing`, `Process.WhereisOrNothing`, `System.EnvOrNothing`;
`Int.FromStringOrError`, `Float.FromStringOrError`, `String.FromBinaryOrError`,
`Task.AwaitOrError`. The name tells the reader the return type without looking it up, which a
one-word prefix cannot. The cost is length (`FromStringOrError`), and two words where 96 Q3 said
"one convention". It stays one rule: the suffix names the return. Ticket 94's `List.TryMap` no
longer collides with anything.

**Under no**, the single-word alternative is a prefix used for every pair whatever it returns,
`Maybe` (`Map.MaybeGet`, `Int.MaybeFromString`, `Task.MaybeAwait`): shorter, one word, but it reads
as `option` even where the return is a `result`.

**A2 (David, 2026-09-25):** *"Map.?Get?"*: a counter-proposal, a `?` marker on the call rather
than a word.

## Round 3

### Q3 — Is the second form marked with `?` after the qualifier's dot: `Map.?Get`?

Ticket [50](50-naming-a-foreign-struct.md) decided `?` never enters an identifier (it would swallow
ticket 26 §4's `Notes?:` tripwire). Here it does not: `?` is a marker on the qualified call, and
the name stays `Get`.

Measured at `345bd8d`:

- **Lexer: no change.** `?` is already its own token, lexed so the parser can refuse `Notes?: int`.
  `bs_lexer:string("Map.?Get(m, k)")` gives `Map` `.` `?` `Get` `(` …, and `Notes?: int` still
  lexes as `Notes` `?` `:` `int`.
- **Parser: no new conflicts.** Adding `call -> modpath '.' '?' uident '(' expr_list ')'` and its
  empty-argument twin to a copy of `bs_parser.yrl`: `yecc` reports 5 shift/reduce, 0 reduce/reduce
  before and 5 and 0 after.

```csharp
Current(ss, t) -> Map.?Get(ss, t) switch {
    :nothing => (:error, :no_session),
    s        => s
}

Page(r)    -> Int.?FromString(r)                     // "2x" is (:error, "2x")
Newest(os) -> List.?MaxBy(os, o => o.PlacedAt)
Answer(t)  -> Task.?Await(t, 5000)                   // (:error, :timeout)
```

For it: one character for every pair whatever it returns; and `?` already means "the path that may
not produce a value" in B#, in the valve `|?>` (ticket [31](31-composable-middleware.md)).

What it costs, and what it is not:

- **It is syntax, not a name**, so it exists only where the compiler supplies both forms: the
  standard environment's reserved qualifiers. A user module cannot declare a `?` form, and
  `Orders.?All()` is refused. F62's table keys the second form by the marker, not by a second name.
- **A C# reader knows `a?.b`**, the null-conditional member access, which reads as the same two
  characters reversed. `Map.?Get` is not that, and the spec says so where `?` is introduced.
- **Tooling reads it as punctuation**: search for `?Get` rather than a name, and the tree-sitter
  grammar and LSP completion owe the same production.

Compiler delta under yes: the two productions above, emitting an `e_qcall` with the second-form
flag; F62's rows gain the flag as part of their key; a `?` on a qualifier with no pair row is
refused, naming the operation; tree-sitter gains the production; LANGUAGE.md's standard-environment
section and `STANDARD-ENVIRONMENT.md` introduce the marker.

## Decisions entry

<!-- Written when the ticket resolves. -->
