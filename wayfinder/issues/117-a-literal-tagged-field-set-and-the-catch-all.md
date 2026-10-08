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

Two questions, independent of each other.

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
It also compiles where a leftover member is closed and holds an unbounded field
(`{ "type": "ping", "seq": int }`). It is **refused** today where every field of every leftover
member is a literal (`{ "type": "ping" } | { "type": "stop" }`), and over a bare union of
literals (`"low" | "high"`), because such a residual has nothing unbounded in it. That is the rule
a tuple follows under 101: a tuple of literals is closed and `(:ok, int)` is open.

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

**Q2. Is this program refused?** Independent of Q1.

```csharp
module Use

public int Use(int n)
Use(n) ->
    var x = n switch { 0 => "a", _ => "b" }
    x switch { "a" => 1, _ => 2 }
```

Before F68 it compiled: a string literal expression was a `string`. With F68 a literal expression
has its own string as its type, which is what lets `{ "type" = "ping" }` build a `Ping`, so `x` is
`"a" | "b"` and the `_` is refused (measured):

```
Use/use.bs:5:28: error: Use discards cases the compiler can name
  every value left here comes from a type you declared, so `_`
  hides a case rather than admitting an unknown one:
    "b"
```

The same program with `:a` and `:b`, or with `1.5` and `2.5`, is refused in the same words today
(measured). F68 changes neither.

Under **yes, refused**, nothing changes: a string literal behaves as an atom and a float literal
do. The message's "a type you declared" is as loose here as it is for the atom.

Under **no, it compiles**, a literal expression is a `string` unless the place it lands expects a
literal. The delta: `bs_check:type_of/3` gives `e_str` the type `string` again, and the three
sites that compare a value with an expected type (a return, an argument, a brace field) accept a
string literal where the expected type holds that literal. The checker has no expected type at
`var x = …`, so `var p = { "type" = "ping" }` would be a `{ "type": string }` and could not be
passed as a `Ping` without writing the brace at the call.
