# PROTOTYPE 01b — Variant A, at length

> **Throwaway. Not a commitment.** The first prototype chose Variant A on the strength of one
> four-clause function while writing everything substantial in Variant B. This is the correction:
> a realistic module set written **entirely in Variant A**, long enough to judge the rhythm
> rather than infer it. Ticket [01](../issues/01-sample-code.md).
>
> Read it for *feel*. Every token is negotiable. The friction list at the end is the honest part —
> it records what writing this actually surfaced, including three things that don't work.

---

## Module 1 — `Orders`, pure domain logic

No processes, no OTP. This is where you find out whether the language is pleasant for ordinary
code, which is most code.

```csharp
module Orders;

type Money = int;                     // minor units, always

type Status = :draft | :placed | :paid | :shipped | :cancelled;

type Line = {
    Sku:  string,
    Qty:  int,
    Unit: Money,
};

type Order = {
    Id:     string,
    Status: Status,
    Lines:  list<Line>,
    Paid:   Money,
};

type Event =
    (:add_line, Line)
  | (:remove_line, string)
  | :place
  | (:pay, Money)
  | (:ship, string)
  | :cancel;

type Rejected =
    (:not_allowed, Status, Event)
  | (:no_such_line, string)
  | (:underpaid, Money)
  | :empty_order;

type Outcome = (:ok, Order) | (:error, Rejected);
```

### The transition table

The reason the language exists, at the size it actually occurs.

```csharp
Outcome Apply(Order o, Event e);

Apply(o, (:add_line, l))     when o.Status == :draft
    => (:ok, o with { Lines = [l, ..o.Lines] });

Apply(o, (:remove_line, sku)) when o.Status == :draft
    => RemoveLine(o, sku);

Apply(o, :place)             when o.Status == :draft, o.Lines != []
    => (:ok, o with { Status = :placed });

Apply(o, :place)             when o.Status == :draft
    => (:error, :empty_order);

Apply(o, (:pay, amt))        when o.Status == :placed, amt >= Total(o)
    => (:ok, o with { Status = :paid, Paid = amt });

Apply(o, (:pay, amt))        when o.Status == :placed
    => (:error, (:underpaid, Total(o) - amt));

Apply(o, (:ship, _))         when o.Status == :paid
    => (:ok, o with { Status = :shipped });

Apply(o, :cancel)            when o.Status != :shipped
    => (:ok, o with { Status = :cancelled });

Apply(o, e)
    => (:error, (:not_allowed, o.Status, e));
```

**This is Variant A at its best.** Nine clauses, aligned guards, and it reads as a specification
of the state machine rather than as code that implements one. The repeated `Apply(o, …)` is not
noise here — it is the left margin of a table, and the eye stops seeing it by the third row.

Note the last clause. It is the total-function catch-all, and whether it should be *required*,
*forbidden*, or *inferred* is ticket 12's question. Here it converts "no clause matched" from a
crash into a value, which is a choice, not an obligation.

But notice what it costs: `Apply(o, e) => (:error, (:not_allowed, o.Status, e))` makes the
function total, so **the compiler can no longer tell you when you have forgotten a case.** The
exhaustiveness guarantee this language is built on is switched off by the catch-all that makes
the function safe. That tension is real and this prototype does not resolve it.

### Recursion and list work

```csharp
Money Total(Order o) => Total(o.Lines, 0);

Money Total(list<Line> lines, Money acc);

Total([], acc)                            => acc;
Total([{ Qty: q, Unit: u }, ..rest], acc) => Total(rest, acc + q * u);
```

`Total/1` and `Total/2` are **different functions** — BEAM identity is name *and* arity, so this
is not overloading, it is two functions that happen to share a name. That falls out naturally and
matches Erlang exactly.

The second clause is the one to look at: `[{ Qty: q, Unit: u }, ..rest]` is a C# list pattern
containing a C# property pattern, in the parameter position. Nothing was invented for it.

```csharp
list<Line> Merge(list<Line> lines);

Merge([])                                       => [];
Merge([l])                                      => [l];
Merge([a, b, ..rest]) when a.Sku == b.Sku       => Merge([a with { Qty = a.Qty + b.Qty }, ..rest]);
Merge([a, ..rest])                              => [a, ..Merge(rest)];
```

Four clauses, no `case`, no scrutinee named, and clause order carrying the logic. This is the
shape that is genuinely tedious to write as a nested `case`.

### Where it stops being pretty

```csharp
Outcome RemoveLine(Order o, string sku);

// ILLEGAL. HasSku is a user function, and BEAM guards permit only guard BIFs.
RemoveLine(o, sku) when HasSku(o.Lines, sku)
    => (:ok, o with { Lines = o.Lines.Reject(l => l.Sku == sku) });

RemoveLine(_, sku)
    => (:error, (:no_such_line, sku));
```

**This does not compile and cannot be made to.** Erlang restricts guards to a closed set of
BIFs — no user function calls, at all, ever. It is the single hardest constraint the platform
imposes on this syntax, because the natural way to write a guarded clause is to ask a question,
and asking a question usually means calling something.

The legal version has to move the test into a body, which costs the clause structure:

```csharp
Outcome RemoveLine(Order o, string sku);

RemoveLine(o, sku)
{
    var kept = o.Lines.Reject(l => l.Sku == sku);

    if (kept.Length == o.Lines.Length)
        return (:error, (:no_such_line, sku));

    return (:ok, o with { Lines = kept });
}
```

Two clauses became one, and the dispatch that was going to be the language's selling point
turned into an `if`. **Every predicate a programmer wants in a guard and cannot have pushes code
out of the clause table and into a body.** How often that happens in real code is the question
this prototype cannot answer alone — but it is the thing most likely to decide whether the
syntax is a joy or a tease.

---

## Module 2 — `OrderServer`, the OTP layer

```csharp
module OrderServer : GenServer;

type Request =
    (:apply, string, Event)
  | (:fetch, string)
  | :stats;

type State = {
    Orders:   map<string, Order>,
    Applied:  int,
    Rejected: int,
};

State Init(:no_args) => { Orders: #{}, Applied: 0, Rejected: 0 };
```

### `handle_call` — the showcase

```csharp
(Reply<Outcome>, State) HandleCall(Request req, From from, State s);

HandleCall((:apply, id, e), _, s)   => ApplyTo(s, id, e);

HandleCall((:fetch, id), _, s)      when s.Orders.HasKey(id)
    => (Reply((:ok, s.Orders[id])), s);

HandleCall((:fetch, id), _, s)
    => (Reply((:error, (:no_such_order, id))), s);

HandleCall(:stats, _, s)
    => (Reply((:ok, (s.Applied, s.Rejected))), s);
```

Delete the `:stats` clause and the compiler says:

```
error: clauses of HandleCall/3 do not cover Request
  missing: :stats
    --> order_server.bs:14:1
```

`s.Orders.HasKey(id)` **is** guard-legal, but only because `is_map_key/2` happens to be a guard
BIF. `HasSku` above was not. **Nothing in the syntax distinguishes them** — both read as a method
call on a value. The language would need a known set of guard-legal names, the way
`purescript-backend-erl` carries a hardcoded 36-name whitelist (ticket 19). A programmer will
have to learn which of its own standard library calls are permitted in a guard, and the syntax
gives no clue.

### `handle_info` — where the mailbox is honest

```csharp
type Known =
    (:DOWN, Ref, :process, Pid, dynamic)
  | (:timeout, Ref, :sweep);

(:noreply, State) HandleInfo(Known | dynamic msg, State s);

HandleInfo((:DOWN, _, :process, pid, reason), s)
    => (:noreply, DropWorker(s, pid, reason));

HandleInfo((:timeout, _, :sweep), s)
    => (:noreply, Sweep(s));

HandleInfo(other, s)
{
    Log.Warn("unexpected message", other);
    return (:noreply, s);
}
```

`Known | dynamic` in the signature is the whole argument in one line: exhaustiveness is proved
over `Known`, and the `dynamic` arm is what the platform forces — visible in the type rather than
hidden in a catch-all. A reader can see exactly which half of this function is guaranteed.

### `handle_cast`, and a two-clause function

```csharp
(:noreply, State) HandleCast(:flush | (:preload, list<Order>), State s);

HandleCast(:flush, s)          => (:noreply, s with { Orders = #{} });
HandleCast((:preload, os), s)  => (:noreply, s with { Orders = IndexById(os) });
```

**Here Variant A is at its worst.** Two clauses, and `HandleCast` is written three times in five
lines — once in the signature, once per clause. At this size the repetition is pure overhead and
the table effect never arrives. Most functions in a real codebase are this size, not nine clauses.

---

## Module 3 — supervision, and interop

```csharp
module OrderSup : Supervisor;

(SupFlags, list<ChildSpec>) Init(:no_args) =>
    ( { Strategy: :one_for_one, Intensity: 3, Period: 60 },
      [ Child(:orders, OrderServer.StartLink, :permanent, :worker) ] );
```

```csharp
[Erlang("erlang", "system_time")]
int SystemTime(:millisecond | :second unit);

[Erlang("lists", "keyfind")]
(string, Order) | :false KeyFind(string key, int n, list<(string, Order)> haystack);
```

The second declaration is worth pausing on. `lists:keyfind/3` returns a tuple **or the atom
`false`** — an untagged union of a tuple and an atom, which is exactly the shape a nominal type
system cannot describe without wrapping, and exactly what structural set-theoretic types are for.
It is also an **unverified claim**: nothing checks that `lists:keyfind/3` actually behaves this
way (ticket 18).

And the chained form, which ticket 05 established is the same static rewrite as `|>`:

```csharp
list<string> ActiveSkus(list<Order> orders) =>
    orders.Filter(o => o.Status == :placed || o.Status == :paid)
          .FlatMap(o => o.Lines)
          .Map(l => l.Sku)
          .Distinct();
```

---

## What writing this actually surfaced

Nine things, ordered by how much they should worry you.

1. **Guards cannot call user functions, and nothing in the syntax shows which calls are legal.**
   `s.Orders.HasKey(id)` works because `is_map_key/2` is a BIF; `HasSku(o.Lines, sku)` does not,
   and they look identical. Every predicate you want and cannot have pushes code out of the
   clause table into an `if`. **This is the biggest threat to the whole design.** → ticket 08.

2. **The catch-all clause switches off the guarantee.** `Apply(o, e) => (:error, …)` makes the
   function total and therefore unfalsifiable — the compiler can never again tell you a case is
   missing. Safety and exhaustiveness pull against each other, in the same function. → ticket 12.

3. **Variant A is excellent at nine clauses and poor at two.** `HandleCast` writes its own name
   three times in five lines. The table effect that justifies the repetition needs a table.
   Whether most functions are big enough is an empirical question about real code.

4. **`==` is ambiguous and the platform cares.** Erlang has `==` (arithmetic: `1 == 1.0` is true)
   and `=:=` (exact). Every `o.Status == :draft` above silently picks one. C# programmers expect
   exact; C#'s `==` on doubles is arithmetic. → ticket 08 or 11.

5. **The ternary is gone, and it shows.** The legal `RemoveLine` wanted `cond ? a : b` and had to
   use `if`/`return` because `:` is the atom sigil. That is the `:atom` decision's real cost, now
   visible in code rather than described. → ticket 10.

6. **Map literals versus record literals are unresolved.** `{ Orders: #{}, Applied: 0 }` uses
   `{ }` for a record and `#{}` for an empty map in the same expression. Records are maps with
   atom keys, so the language needs one story here, not two syntaxes. → fog.

7. **Signature-to-clause distance is unenforced.** Nothing above stops two hundred lines
   appearing between `Outcome Apply(Order o, Event e);` and its first clause. Erlang requires
   clauses to be contiguous; this syntax should probably require the signature to be too. → 08.

8. **Parameter names in the signature are decorative.** `HandleCall(Request req, From from,
   State s)` names three parameters that no clause uses — every clause rebinds them. Either they
   document intent, or they are a lie the reader has to ignore. → ticket 08.

9. **Arity overloading is free and idiomatic.** `Total/1` and `Total/2` sharing a name is not a
   special case; it is what BEAM identity already means. This one is a genuine win.

### What did not appear

No binary patterns anywhere, again, and this module set would use them in reality — order IDs,
serialisation, anything on a wire. Ticket 04 found binaries are *untheorised* in the
set-theoretic literature. **The largest gap in this design is the one it is not yet possible to
prototype.** → ticket 20.
