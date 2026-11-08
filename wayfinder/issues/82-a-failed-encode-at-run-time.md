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

## Round 1 — 2026-11-08

Measured on Erlang/OTP 28 (built from `otp_src_28.5`, the pinned release) with rebar3 3.27.0 and an
unmodified `compiler/` at `8bf1516`. The probes are in
[the research file](../research/82-failed-encode.md). Ticket 74 (resolved 2026-09-19) settled the
*channel* site, not this one: its answer is "crash, and a refused value never enters the channel",
and it names 82 as the sibling it did not decide.

### The program

An order service puts an `Order` on the wire. The record arrives from Erlang or Elixir, so the head
guards its tag only (F3.9) and the body is where an undeclared field can first be seen.

```csharp
module Orders

record Line  { Sku: string, Qty: int }
record Order { Id: int, Total: int, Lines: list<Line> }

public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)
```

Today, an `Order` map carrying an undeclared `Cost` inside a line:

```
crashed: to_json {Kind = :'ValidationError', Expected = "Qty | Sku",
                  Path = [".Lines", "[0]", ".Cost"], Reason = :unknown_key}
```

The reader learns which field, at which path, and why. A wrong tag on the same entry point crashes
bare, and by the head, not the encoder:

```
crashed: error:function_clause
```

`bs_emit:json_form/2` (`compiler/src/bs_emit.erl:1889`) is the one site: the validator runs, and its
`{error, E}` clause is `erlang:error({to_json, E})`.

### The question

**When `ToJson<T>` is handed a value its type does not admit, does the crash carry the
`ValidationError`, or is it a bare `function_clause`?**

Alone. The depth of the guard (Q2 above) follows from it and is not asked here. Returning a
`result` is not on the table: it changes ticket 77's `string` signature, so it would reopen 77.

### Under each answer

**Carry the `ValidationError`.** The program above compiles unchanged and crashes as shown. Nothing
to build; the work that remains is to delete "provisional" from `F50-to-json.md` and link this
entry from it.

**Bare `function_clause`.** The program compiles unchanged and crashes with `error:function_clause`
for the `Cost` input, the same as a wrong tag does. The `Path` and `Reason` are gone from the
reader's view although `ValidateAs<Order>` still computes them. The compiler gains:

- in `bs_emit:json_form/2`, the error clause becomes `erlang:error(function_clause)` and the
  `EV` variable is dropped;
- F50.8's two tests in `to_json_tests` change their expected reason from `{to_json, #{...}}` to
  `function_clause`;
- `F50-to-json.md` loses its "provisional" paragraph and its "crash reason" bullet.

The deep validator walk stays either way (Q2), so the bare form saves no run-time work. It only
removes information.

**Recommended:** carry the `ValidationError`, because the walk already computes the reason and
dropping it makes the one crash that names a field indistinguishable from a wrong tag.

## Decisions entry

<!-- Written when this ticket resolves. -->
