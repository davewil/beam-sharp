# PROTOTYPE 01e — OTP callbacks under directory-as-module

> ⚠️ **STALE IN THREE WAYS — do not copy the code below verbatim.** Later tickets superseded
> parts of it. The *structure* (directory-as-module, `[module: GenServer]`, callbacks in the
> aggregate, the API/declarations split) all stands; the *spelling* does not.
>
> 1. **The clause arrow is `->`, not `=>`.** [Prototype 01g](01g-closing-the-syntax.md) settled
>    this: `=>` stays the lambda arrow, `->` is the clause arrow, because `(0) => 0` is
>    ambiguous with a C# lambda on sight.
> 2. **There is no `dynamic`.** [Ticket 11](../issues/11-type-system-shape.md) removed it
>    entirely — external values arrive as `term` and the clause head is the decoder. So
>    `HandleInfo(Info | dynamic, State)` is now `HandleInfo(term, State)`, and
>    `(:error, dynamic)` is `(:error, term)`.
> 3. **`HandleCall`'s argument is `term`, not `Request`.**
>    [Ticket 14 §4](../issues/14-concurrency-and-otp-model.md) — narrowing a callback's argument
>    is the *unsound* direction, since OTP calls it with whatever a sender chose. Dialyzer permits
>    it silently and you get `function_clause` at runtime
>    ([14e](14e_callback_contract_containment.md)). beam-sharp rejects it by contravariance. The
>    correct signature is ticket 12's: `(:reply, int, Account) HandleCall(term, From, Account);`
>
> Also from ticket 14: the `Info` type declaration below is not how exhaustiveness works — the
> argument is `term`, the residual is open, and the catch-all is mandatory. Prelude types
> (`Down`, `Exit`, `Timeout`) are the sanctioned spelling for system messages, per §6.

> **Throwaway.** Ticket [01](../issues/01-sample-code.md), fifth pass. §5 of
> [01c](01c-module-as-focus.md) found that splitting OTP callbacks into sub-modules puts the
> exports in the wrong place and breaks the behaviour contract. This shows what happens under
> **directory-as-module with source-only sub-modules** — the shape
> [01d](01d-submodule-realisation.md) recommends.

---

## The layout

```
lib/shop/orders/order/server/          ← compiles to ONE beam: Shop.Orders.Order.Server
  server.bs           module attributes and types
  start_link.bs   ⎫
  apply.bs        ⎬   client API
  fetch.bs        ⎪
  stats.bs        ⎭
  init.bs         ⎫
  handle_call.bs  ⎬   gen_server callbacks
  handle_cast.bs  ⎪
  handle_info.bs  ⎭
  apply_to.bs     ⎫
  sweep.bs        ⎬   private helpers
  drop_worker.bs  ⎭
```

**The problem is gone rather than solved.** All twelve files compile into one BEAM module, so
`handle_call/3` is exported from `Shop.Orders.Order.Server` — precisely where
`gen_server:start_link/3` looks. Ticket 06 established that `-behaviour` has no runtime effect and
that only exports matter; here the exports land correctly by construction.

And a side effect worth noticing: Erlang modules conventionally separate client API from callbacks
with a `%% ===== API =====` banner comment. **That split is now structural.**

---

## `server.bs` — the declarations file

```csharp
[module: GenServer]

using Shop.Orders.Order;

type State = {
    Orders:   map<string, Order>,
    Applied:  int,
    Rejected: int,
};

type Request =
    (:apply, string, Event)
  | (:fetch, string)
  | :stats;

type Info =
    (:DOWN, Ref, :process, Pid, dynamic)
  | (:timeout, Ref, :sweep);
```

`[module: GenServer]` is **C#'s own syntax for module-targeted attributes** — the same shape as
`[assembly: …]`. It fits ticket 22's candidate synthesis exactly: a behaviour is a domain-ish
opinion, expressed as an attribute rather than a keyword, and since ticket 06 found `-behaviour`
has no runtime effect, its only job is a compile-time assertion that the required callbacks exist.
Which is what an attribute is for.

---

## The callbacks

### `handle_call.bs`

```csharp
(Reply<Outcome>, State) HandleCall(Request, From, State);

((:apply, id, e), _, s)                        => ApplyTo(s, id, e);
((:fetch, id), _, s) when s.Orders.HasKey(id)  => (Reply((:ok, s.Orders[id])), s);
((:fetch, id), _, s)                           => (Reply((:error, (:no_such_order, id))), s);
(:stats, _, s)                                 => (Reply((:ok, (s.Applied, s.Rejected))), s);
```

Parameter names are **dropped from the signature** — friction #8 from 01b was that
`HandleCall(Request req, From from, State s)` names three parameters no clause ever uses, since
every clause rebinds them. Types alone are honest.

### `handle_info.bs`

```csharp
(:noreply, State) HandleInfo(Info | dynamic, State);

((:DOWN, _, :process, pid, reason), s)  => (:noreply, DropWorker(s, pid, reason));
((:timeout, _, :sweep), s)              => (:noreply, Sweep(s));
(other, s)                              => { Log.Warn("unexpected message", other);
                                             (:noreply, s); }
```

The whole guarantee is legible in one line of signature: exhaustiveness proved over `Info`, and
`dynamic` naming the part the platform forces.

### `handle_cast.bs`

```csharp
(:noreply, State) HandleCast(:flush | (:preload, list<Order>), State);

(:flush, s)          => (:noreply, s with { Orders = #{} });
((:preload, os), s)  => (:noreply, s with { Orders = IndexById(os) });
```

Two clauses, one occurrence of the name. In 01b this same function wrote `HandleCast` three times
in five lines. This is the repetition problem fixed.

### `init.bs`

```csharp
(:ok, State) Init(:no_args);

(:no_args) => (:ok, { Orders: #{}, Applied: 0, Rejected: 0 });
```

---

## The client API

### `start_link.bs`

```csharp
(:ok, Pid) | (:error, dynamic) StartLink();

() => GenServer.StartLink(Self, :no_args, []);
```

### `apply.bs`

```csharp
Outcome Apply(Pid, string, Event);

(server, id, e) => GenServer.Call(server, (:apply, id, e));
```

### `fetch.bs`

```csharp
(:ok, Order) | (:error, (:no_such_order, string)) Fetch(Pid, string);

(server, id) => GenServer.Call(server, (:fetch, id));
```

A one-line function still costs a file and a signature. Whether that is discipline or ceremony is
the open question below.

---

## What this pass settled, and what it exposed

**Settled.**

- **The OTP facade is unnecessary.** No delegation, no generated wrapper module, no second
  structural convention for behaviour modules. The hardest objection to module-as-focus is gone,
  and it is gone *because* of the source-only decision — the two choices are one choice.
- **API and callbacks separate structurally**, replacing a banner comment with a fact.
- **Parameter names leave the signature.** Types only; clauses rebind everything anyway.
- **`[module: GenServer]`** gives behaviours a home using C#'s existing attribute-target syntax,
  and it is the first concrete instance of ticket 22's attributes-not-keywords synthesis.

**Exposed.**

1. ~~**Twelve files for one gen_server.** Four are one-liners.~~ **Largely withdrawn** — the map's
   standing constraint (written by agents, read by humans, scaffolded by tooling) makes this a
   write-cost objection, and write cost is near-free. What survives is the *read* question: twelve
   files is worse for understanding the whole server at once and better for finding one operation.
   And the split actively helps review — an agent's change to one operation is a single small diff
   readable in full context, rather than a hunk inside a long module.
2. **`Self` is undefined.** `StartLink` needs to name its own module, Erlang's `?MODULE`. Under
   directory-as-module there is no obvious spelling. → ticket 08.
3. **`()` for a zero-argument clause.** Same family as the `(0)` ambiguity from 01c: with the name
   elided, a nullary clause head is an empty pair of brackets. → ticket 08.
4. **`Order.Server.Apply` and `Order.Apply` are different functions with the same short name.**
   Legal and unambiguous to the compiler; genuinely confusing to a reader, and the client-API
   layer will collide with the domain layer routinely. Worth a naming convention, or a rule.
5. **Nested directories are unresolved.** Grouping `api/` and `callbacks/` into subdirectories
   would be natural — but under directory-as-module a subdirectory is a *different module*, which
   would reintroduce the facade problem. Either nested directories are forbidden inside a module,
   or there must be a rule distinguishing grouping from nesting. → fog.
6. **`server.bs` inside `server/`** repeats the name. Elixir and Rust both put the parent file
   *beside* the directory (`server.ex` + `server/`). Under directory-as-module that would place a
   module's own declarations outside its directory, which is worse. A fixed name — `_module.bs` —
   is the alternative. → ticket 08.
