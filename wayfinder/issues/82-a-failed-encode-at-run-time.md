# 82 — What is a failed encode at run time? `ToJson<T>`'s guard has a crash shape no ticket chose

Type: grilling
Status: open — [ENG-382](https://linear.app/davewil/issue/ENG-382). Raised 2026-09-15 by the F50
build ([ENG-375](https://linear.app/davewil/issue/ENG-375)), which had to pick a shape to ship
Blocked by: —

## Why this is raised

[Ticket 18](18-boundary-defence.md) §1(c) makes a guard unconditional where generated code
consumes a value, and [ticket 26](26-data-modelling.md) §4 puts the exact field-set test at an
obligation site, because an encoder would otherwise publish fields no type declares. Both say a
guard is emitted. **Neither says what the failure is.**

F50 had to answer that to ship, and the answer it shipped is the feature's own:

```csharp
module Orders

record Order { Id: int, Total: int }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)
```

```
$ bsc Orders OrderBody "{ Kind = :'Orders.Order', Id = 1, Total = 5, Secret = 7 }"
crashed: to_json {Kind = :'ValidationError', Expected = "{ Kind: :'Orders.Order', Id: int, Total: int }", Path = []}
```

A public record parameter is guarded on its tag alone (F3.9), so the map above reaches the body
with a field the type does not declare. Without a guard at the obligation, `json:encode` publishes
`"Secret":7` — well-formed JSON carrying a field no type declares, which is exactly what 26 §4
named. With the guard, the value never reaches the encoder and the program crashes.

CLAUDE.md: *a feature that needs a decision raises a ticket rather than making one.* This is that
ticket. Until it is answered, the shape below is provisional and
`compiler/features/F50-to-json.md` says so.

## Q1 — What does a failed guard at an obligation site become?

Three answers are live, and the language's own constraints narrow them:

- **A crash carrying the `ValidationError`**, as shipped. The reader gets the path and the type
  expected there, which is the same value `ValidateAs<T>` would have returned.
- **A bare `function_clause`**, the shape a clause head's guard already fails with (F42, ticket 18
  §1). One failure vocabulary for every guard the compiler emits, at the cost of the reason.
- **A value the author can take apart**, which would make `ToJson<T>` return
  `result<string, ValidationError>` rather than `string`. That is a different signature from the
  one [ticket 77](77-what-goes-on-the-wire.md) decided (*"Returns `string`"*), so it reopens 77
  rather than answering this.

There is no `try` in the surface language, so a crash is not recoverable inside B#; 18 §1 rule C
requires only that a wrong term crash rather than pass silently. The question is whether the
reason travels with it.

## Q2 — How deep is the guard, and what does the depth cost?

26 §4 priced **one** `map_size` test on the record `T` names: *"+29 B"*, against the +14 an
ordinary boundary costs. F50 emits the whole `ValidateAs<T>` validator instead — every member, a
closed map's exact field set at every depth, a `string`'s UTF-8 — because `map_size` at the top
leaves an undeclared field *inside* a nested record on the wire, and `json:encode` is what
publishes it. So the narrow test keeps 26 §4's promise only at the top level.

The cost is a second walk of the value beside `json:encode`'s own: O(size), the same order, twice.
That is a wider guard than the ticket priced, and it is the reason Q2 sits beside Q1 rather than
in its own ticket: an answer to Q1 that drops the reason makes the deep walk harder to justify,
and an answer that keeps it makes the walk the thing that produces it.

## What follows the answer

- `bs_emit:json_form/1` is the single site; the crash is one expression in it.
- `compiler/features/F50-to-json.md` records the shape as provisional and links here.
- Two tests pin it today, F50.8's pair in `to_json_tests`, and they are the tests that change.

## Decisions entry

<!-- Written when this ticket resolves. -->
