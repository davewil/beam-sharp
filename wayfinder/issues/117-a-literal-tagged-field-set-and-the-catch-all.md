# 117 — Does a field set tagged by a string literal close on that tag?

Type: grilling
Status: claimed — [ENG-595](https://linear.app/davewil/issue/ENG-595). Raised 2026-10-08 by the F68
build ([ENG-407](https://linear.app/davewil/issue/ENG-407)), which makes a string literal a type
Blocked by: —

## Why this is raised

Two decided rules meet at a case neither names.

- [78](78-the-decode-direction.md) Q5: a string literal is a type, and *"a union of literal-tagged
  wire types can be covered without `_`"*. F68 builds that, and it holds (measured below).
- [101](101-what-closes-a-residual.md): *"a record member closes on its tag whatever its fields
  hold, so `_` over a residual of records is refused naming them; a tuple does not"*. Its own
  entry lists *"ENG-407's string-literal tags"* as not decided, and its text says whether a
  string literal in a key position *"closes the same way is that feature's question when it is
  built"*.

78 Q5 settles the program with every member named. It does not settle the program with a `_`.

## Round 1

One question.

A streaming client's events are told apart by `"type"` and by nothing else:

```csharp
module Stream

type Start = { "type": "content_block_start", "index": int, .. }
type Stop  = { "type": "message_stop", .. }
type Ping  = { "type": "ping", .. }
type Event = Start | Stop | Ping

public atom Kind(Event e)
Kind({ "type": "content_block_start" }) -> :start
Kind(_)                                 -> :other
```

**Q1. Is this program refused?**

Today, with F68's type and pattern built and nothing else changed, it **compiles** (measured
2026-10-08): the leftover members are open field sets, and an open member is an open residual.

The same program written with records is refused today, under ticket 101:

```csharp
record Start { Index: int }
record Stop { At: int }
record Ping { At: int }
type Event = Start | Stop | Ping

public atom Kind(Event e)
Kind(Start s) -> :start
Kind(_)       -> :other
```

```
Rc/rc.bs:10:1: error: Kind discards cases the compiler can name
  every value left here comes from a type you declared, so `_`
  hides a case rather than admitting an unknown one:
    Kind(Ping p) -> ...
    Kind(Stop s) -> ...
```

Under **yes, refused**, `Stream` gets that same refusal, naming
`Kind({ "type": "message_stop" })` and `Kind({ "type": "ping" })`, and the author writes the two
clauses. A new event the sender adds later is not in `Event`, so `ValidateAs<Event>` refuses it at
the boundary and it never reaches `Kind`. The delta: `bs_types:m_open/1` treats a field-set
member, open or closed, as closed when one of its keys holds a finite set of string literals, as it
treats a record member on `Kind`. One clause, and the `catch_all_over_closed` message is reused.

Under **no, legal**, nothing changes: a literal-tagged field set behaves as a tuple does under
101, where `(:ok, int)` stays open and `_` stays legal over it. The author may name every member
and drop the `_`, or keep it.
