# 95 — A lowercase atom key: Erlang's own option maps

Type: grilling
Status: open — [ENG-436](https://linear.app/davewil/issue/ENG-436). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

25d connects to PostgreSQL through epgsql, whose `connect/1` takes a map keyed by lowercase atoms,
`#{host => "localhost", port => 5432}`, as most Erlang options do. Ticket 48 recorded that a
brace key is a PascalCase name, and that an atom literal or a lowercase name is refused at the
parser; ticket 78 Q2 added string keys. Nothing decided a lowercase atom key. Measured on
`a0f9cbf`:

```csharp
public map<atom, term> Opts(string h)
Opts(h) -> { host = h, port = 5432 }
```

`error: syntax error before: host`. 25d compiles only because epgsql also accepts a proplist:

```csharp
Config() -> [(:host, "localhost"), (:port, 5499), (:username, "probe"), (:database, "shop")]
```

## Round 1

**Q1. May a brace key be an atom literal, `{ :host = h, :port = 5432 }`, in expression, type and
pattern position?**

Under yes the program compiles as `Opts(h) -> { :host = h, :port = 5432 }`, emits
`#{host => H, port => 5432}`, and `{ :host: string, :port: int }` is its type. Under no, a
proplist is the idiom for an Erlang option map.

Compiler delta: `bs_parser.yrl`'s three brace key positions take an `atom` token beside `uident`
and `string` (F58 made the same change for strings); `bs_types` needs nothing, since a map
member's keys are atoms already; the printers write a lowercase key with its colon.
