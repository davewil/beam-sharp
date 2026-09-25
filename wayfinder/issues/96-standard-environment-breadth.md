# 96 — Standard environment breadth: may a qualified operation be OTP's own function?

Type: grilling
Status: open — [ENG-448](https://linear.app/davewil/issue/ENG-448). Raised 2026-09-25 by David
Blocked by: —

## Why this is raised

David, 2026-09-25: *"A number of the exemplars also make heavy use of erlang imports. A fair few
of these should be exposed through the standard environment. … these should be comprehensive of
the full capability of List and Maps. Additionally, Float.FromInt is the only conversion
supported, there should be many others. … Also GenServer, Task, Agent etc and other OTP stuff
should be in there."*

**This moves a recorded boundary, and the move is David's decision, not a question here.** Ticket
00 ruled *"standard library breadth"* out of scope, and `STANDARD-ENVIRONMENT.md` leaned on that to
say `Map.Get` *"never crossed it"*. A comprehensive `List` and `Map` is that breadth; as of today it
is in scope.

What ships today: `List.Sum`, `Length`, `Reverse`, `Map`, `Filter`, `Fold`; `Term.Compare`;
`Float.FromInt`. `Map` is reserved and holds no operation (`Map.Get` is decided and unbuilt,
ENG-324). There is no `String`, `Int`, `Process` or `GenServer` qualifier.

What the exemplars and examples import instead, counted across `wayfinder/prototypes/25*.md` and
`compiler/examples/` on `a0f9cbf`. A write-up and its extracted copy are both counted, so a count is occurrences, not programs:

| Erlang call | Occurrences | Who |
|---|---|---|
| `maps:from_list`, `find`, `put`, `remove`, `to_list` | 38 | 25f, 25g |
| `erlang:integer_to_binary`, `binary_to_integer` | 12 | 25e, Foreign |
| `erlang:byte_size`, `iolist_size`, `iolist_to_binary` | 6 | 25b, 25c, 25e, 25f, Interop, Label |
| `gen_server:call`, `reply` | 6 | 25d, 25g |
| `erlang:self`, `send`, `spawn_monitor`, `whereis` | 7 | 25g, Names |
| `erlang:system_time` | 2 | Interop |
| `json:encode`, `decode` | 4 | 25f (ENG-410 covers decode) |
| `lists:sum`, `ets:lookup`, `file:read_file`, `binary:encode_unsigned` | 5 | Interop, Foreign, 25e |
| `Log.Warn` (written as though it existed) | 4 | 25b, 25c |

## Round 1

**Q1. May an operation under a reserved qualifier lower to the OTP function that already does
it — a remote call into `lists`, `maps`, `string`, `erlang` or `gen_server` — rather than to a
form the compiler generates?**

```csharp
record Order { Id: string, Total: int }

public list<Order> Top(list<Order> os)
Top(os) -> List.Take(List.SortBy(os, o => o.Total), 3)

public list<string> Words(string s)
Words(s) -> String.Split(s, " ")

public term Status(pid p)
Status(p) -> GenServer.Call(p, :status)
```

Today: `Top calls List.SortBy/2, and \`List\` has no operation of that name`; `String is called
but never imported`; `GenServer is called but never imported`.

Under yes, all three compile. `List.SortBy` is emitted as `lists:sort/2` over a key comparison,
`List.Take` as `lists:sublist/2`, `String.Split` as `string:split(S, P, all)`, and `GenServer.Call`
as `gen_server:call/2`. Each operation is one row in a compiler-known signature table: B# name,
arity, B# signature and the OTP function it becomes. F51's `inlined_bif/1` (`Float.FromInt` is
`erlang:float/1`) is the one row that exists today. No B# beam ships, which is ticket 67's rule;
the platform's own modules are already on every node.

Under no, each operation is a local form the compiler writes out, as F32 wrote `List.Sum`,
`Length`, `Reverse`, `Map`, `Filter` and `Fold`, and the roster below costs a hand-written walker
each.

What a yes reverses, stated so it is not reversed by accident: F32 chose a generated local form
because ticket 67 asked for one (*"a remote call to the stdlib is still a remote call"*), and
`check-reserved-qualifiers.sh` P2 reads the import chunk to prove no `lists` call is emitted. Under
yes that probe changes meaning: a call into OTP is allowed, and a call into a B# module stays
refused. Ticket 17 §2's precision argument does not change. It was about a call into a *generic B#
beam* losing the spec. A B# function's `-spec` is written from its B# signature, whichever call its
body makes.

Compiler delta: a signature table in `bs_check`, keyed `{Qualifier, Name, Arity}`, holding the
signature (polymorphic ones typed as F45 types any polymorphic call) and the target MFA. `bs_emit`
emits the remote call through `inlined_bif/1`'s path. `check-reserved-qualifiers.sh` P2 is rewritten
to allow OTP's modules and refuse B# ones. Each new qualifier (`String`, `Int`, `Process`,
`GenServer`, `Supervisor`, `Logger`) is a reserved name, which ticket 65 (ENG-255) governs.

**Q2. Are the operations named as Elixir names them, PascalCased, and not as LINQ does?**

```csharp
public list<string> TopCustomers(list<Order> os)
TopCustomers(os) -> os |> List.SortBy(o => o.Total) |> List.Take(3) |> List.Map(o => o.Customer)
```

Under yes this is the spelling: `SortBy`, `Take`, `FlatMap`, `GroupBy`, `Uniq`, `Any`, `All`,
matching F46's `Map`, `Filter` and `Fold`, which already chose Elixir's words over LINQ's `Select`,
`Where` and `Aggregate`. Under no, the table uses LINQ's (`OrderBy`, `SelectMany`, `Distinct`) and
F46's three are renamed. The borrow heuristic surveys C# first; F46 is where it was met.

**Q3. Does ticket 48 Q8's rule, two operations with the assertive one preferred, reach every
operation that can find nothing: `List.First`, `Last`, `At`, `Max`, `Min`, `Find`, as well as
`Map.Get`?**

```csharp
public Order Latest(list<Order> os)
Latest(os) -> List.MaxBy(os, o => o.PlacedAt)          // an empty list crashes, via `raise`

public option<Order> Newest(list<Order> os)
Newest(os) -> List.TryMaxBy(os, o => o.PlacedAt)       // an empty list is :nothing
```

Under yes every such operation has both forms, one naming convention for the pair (the one ENG-324
owes for `Map.Get`, decided once for all of them), and the assertive form is the plain name. Under
no, each returns `option<T>` only and a caller who knows the list is non-empty matches `:nothing`
anyway. The `Try` prefix above is a placeholder: the spelling is ENG-324's.

**Q4. Is there no `Enum`: an operation over a map lives under `Map` and one over a list under
`List`, and neither takes the other's argument?**

```csharp
public int Stock(map<string, int> counts)
Stock(cs) -> Map.Fold(cs, 0, (k, n, acc) => acc + n)
```

Under yes this is the spelling, and `List.Fold(cs, …)` over a map is refused by the argument check
it already has. Elixir's `Enum` exists because the `Enumerable` protocol dispatches at run time,
and ticket 16 gave B# no protocols. Under no, an `Enum` qualifier takes a `list<T> | map<K, V>` and
dispatches on the argument's shape.

## What a yes makes cheap — the roster, for a later round

This is not a round of questions. It is what the table would hold. It is drawn from the imports
above and from Elixir 1.20's wrappings of the same modules (`Enum`, `List`, `Map`, `String`,
`Process`, `GenServer`, `Supervisor`), and names follow F46 (`Map`, `Filter`, `Fold`), not LINQ's.
Names and failure shapes are decided in the rounds after Q1.

| Qualifier | Operations (target) |
|---|---|
| `List` | `Sort`, `SortBy` (`lists:sort`), `Take`, `Drop` (`lists:sublist`, `nthtail`), `Concat` (`++`), `FlatMap` (`lists:flatmap`), `Zip` (`lists:zip`), `Any`, `All` (`lists:any`, `all`), `Find` → `option<T>`, `Count`, `Contains` (`lists:member`), `Uniq` (`lists:uniq`), `Max`, `Min` → `option<T>`, `Partition` (`lists:partition`), `GroupBy` → `map<K, list<T>>`, `Seq` (`lists:seq`), `Join` over strings, and ticket 94's fallible `TryMap` |
| `Map` | `Get` (ENG-324), `Find` → `option<V>` (`maps:find`), `Put`, `Remove`, `Update` (`maps:put`, `remove`, `update_with`), `Has` (`maps:is_key`), `Keys`, `Values`, `ToList`, `FromList`, `Size`, `Merge`, and `Map`, `Filter`, `Fold` over entries (`maps:map`, `filter`, `fold`) |
| `String` | `Length` (`string:length`, graphemes), `Split`, `Trim`, `ToUpper`, `ToLower`, `Replace`, `StartsWith`, `EndsWith`, `Contains`, `Slice`, `Join` (`string` and `binary` modules) |
| `Binary` | ticket 93 |
| conversions | ticket 97 |
| `Process` | `Self`, `Send`, `Monitor`, `Demonitor`, `Link`, `Register`, `Whereis` → `option<pid>`, `SendAfter`, `Exit`, and `SpawnMonitor` taking an `fn() -> term` (25g's call) |
| `GenServer` | `StartLink`, `Start`, `Call`, `Cast`, `Reply`, `Stop`. A reply crosses as `term` (ticket 18 §2), so a typed reply is `ValidateAs<T>` at the call's site, and the client function's signature carries the type (ticket 14 §1) |
| `Supervisor` | `StartLink`, `StartChild`, `WhichChildren`; the child spec is a record |
| `Logger` | `Info`, `Warning`, `Error` (`logger:info`, …) |
| time | `System.Time(unit)` (`erlang:system_time`) |
| `Task`, `Agent` | ticket 98 |
