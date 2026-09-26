# 101 — What closes a residual: does a record close on its tag, and a tuple?

Type: grilling
Status: resolved 2026-09-25 — [ENG-464](https://linear.app/davewil/issue/ENG-464). Raised and
answered 2026-09-25 out of [ENG-402](https://linear.app/davewil/issue/ENG-402)'s stop line; one
question, one round
Blocked by: —

## Why this is raised

[12](12-totality-vs-let-it-crash.md) §2 refuses `_` over a residual the compiler can name, and
admits it over a residual with an unbounded part, where a foreign sender chooses the inhabitants.
LANGUAGE.md §3 words the admitting half as *"any type with an unbounded part"*, which reads two
ways once the residual is a record. ENG-402 measured which way the checker reads it: `is_open/1`
in `bs_types` looks for an unbounded part anywhere, including inside a record member's fields, so
ticket 12 §2's own worked example compiles. ENG-402 said that if David read §2 the other way it
was a ticket and not a defect, and put the tuple case beside it as the question the fix could not
settle alone.

## The program

Measured at `057fec6`:

```csharp
record OrderPlaced    { Id: int }
record OrderShipped   { Id: int }
record OrderCancelled { Id: int }
type Event = OrderPlaced | OrderShipped | OrderCancelled

public atom Handle(Event e)
Handle(OrderPlaced p)  -> :placed
Handle(OrderShipped s) -> :shipped
Handle(_)              -> :other      // residual: OrderCancelled { Id: int }
```

compiles, and an `OrderCancelled` returns `:other`. With the fields made `{ Id: :x }` it is refused,
`Handle discards cases the compiler can name`, so the only thing admitting the `_` is the `int`
inside the leftover record.

A tuple residual behaves the same way today, for the same reason. A tuple of literals is closed:

```csharp
public atom Pick((:ok, :a) | (:error, atom) | (:retry, :b) r)
Pick((:error, e)) -> :bad
Pick(_)           -> :other
```

is refused naming `Pick((:ok, :a))` and `Pick((:retry, :b))`. A tuple carrying `int` is open, and
`_` over a residual of `(:ok, int)` compiles.

**Not a tuple, though it looks like one: `result<T, E>`.** It is `T | (:error, E)` (STANDARD-
ENVIRONMENT.md, stratum one), so the success value is bare. Over `result<int, atom>`, after a
`(:error, e)` clause the residual is `int`, open under any reading, and `_` is legal whatever this
ticket decides. The question put to David first used `(:ok, int)` as though it were `result`'s
shape; it is not, and this was corrected in the same round.

## Q1 — Does a record member close on its tag, and does a tuple?

A record is closed by its tag: one clause, `Handle(OrderCancelled o)`, covers every
`OrderCancelled` whatever its `Id` holds, so the residual is one case the compiler can name. The
same argument would make `(:ok, int)` closed, since one clause `(:ok, n)` covers it.

**A1 (David, 2026-09-25):** *"records close on tag, tuples are not the same as records."*

So a record member of a residual is closed by its tag regardless of its fields, and `_` over it is
refused naming the record. A tuple is not: a tuple residual with an unbounded part stays open, and
`_` stays legal over it, exactly as today. A tuple of literals is closed, exactly as today.

## The compiler delta

- `bs_types:is_open/1` stops descending into a record member's fields: a map part carrying a
  resolved `Kind` tag counts as closed. Tuple, list and map parts without a tag keep today's
  reading. The refusal it feeds, `discards cases the compiler can name`, and its message already
  exist; the head the message prints is the record's name, which `bs_types:to_pattern/1` already
  renders.
- The same answer at the switch arm (ENG-402's comment of 2026-09-23), since arms reach the same
  predicate through `walk/6`.
- Every new red in the suite and the examples is read as a finding, per ENG-402's own Done line:
  a `_` over records that the corpus leaned on becomes named clauses.

## Not decided here

- Whether a *foreign* record, a `map<atom, term>` from an Elixir struct under ticket 50, closes on
  anything. It has no B# tag, so under this answer it stays open.
- ENG-407's literal-tagged field sets (`{ "type": "ping", .. }`, ticket 78 Q5). A string literal in
  a key position is a tag in the same sense as `Kind`, and whether it closes the same way is that
  feature's question when it is built.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [What closes a residual: does a record close on its tag, and a tuple?](issues/101-what-closes-a-residual.md)
  — **a record member closes on its tag whatever its fields hold, so `_` over a residual of
  records is refused naming them; a tuple does not, so a tuple residual with an unbounded part
  stays open and `_` stays legal over it.** Raised and resolved 2026-09-25 in one round on one
  question, out of [ENG-402](https://linear.app/davewil/issue/ENG-402), which measured ticket
  [12](issues/12-totality-vs-let-it-crash.md) §2's own `Event` example compiling because
  `is_open/1` found the `int` inside the leftover record. Tuple behaviour is unchanged: a tuple
  of literals was already closed, and `(:ok, int)` stays open. `result<T, E>` is not a tagged
  pair here: it is `T | (:error, E)`, so its residual after the error clause is a bare `T` and
  this ticket does not reach it. Not decided: a foreign struct (no B# tag, so open), and ENG-407's
  string-literal tags. Built — ENG-402 (`2c6783c`).
```
