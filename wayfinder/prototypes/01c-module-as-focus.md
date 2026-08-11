# PROTOTYPE 01c — module-as-focus, one function per sub-module

> **Throwaway. Not a commitment.** Third pass at ticket [01](../issues/01-sample-code.md). The
> same domain as 01b, restructured on the decision that a module *is* a function, with a type
> module owning the aggregate and one sub-module per operation.
>
> Design intent, in David's words: *"one struct per module, operations on that struct define the
> contract"* — Elixir's shape — *"and functions per module exist in their own sub-module so as
> to deal with DDD concerns."*

---

## The shape

```
Shop.Orders/
  Order.bs                 -- type module: the aggregate, its commands, events, errors
  Order.Apply.bs           -- one operation, one module
  Order.Total.bs
  Order.Merge.bs
  Order.RemoveLine.bs
  Order.Server.bs          -- the OTP facade (see §5 — this is the hard part)
  Order.Server.HandleCall.bs
  Order.Server.HandleInfo.bs
```

Two module kinds, distinguished by whether the header carries an arrow:

- **A type module** declares types and nothing else. It is the aggregate's contract.
- **A function module** declares one function via its header, and its body is clauses.

---

## 1. The type module — the aggregate's contract

```csharp
module Shop.Orders.Order;

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

Nothing but types. In DDD terms this file *is* the aggregate boundary: the state, the commands it
accepts, and the ways it can refuse them. A reader who wants to know what an `Order` is opens one
file and finds no logic to wade through.

---

## 2. One operation, one module

```csharp
module Shop.Orders.Order.Apply : Outcome(Order, Event);

({ Status: :draft } o, (:add_line, l))           => (:ok, o with { Lines = [l, ..o.Lines] });
({ Status: :draft } o, (:remove_line, sku))      => RemoveLine(o, sku);
({ Status: :draft, Lines: [_, .._] } o, :place)  => (:ok, o with { Status = :placed });
({ Status: :draft }, :place)                     => (:error, :empty_order);
({ Status: :placed } o, (:pay, amt)) when amt >= Total(o)
                                                 => (:ok, o with { Status = :paid, Paid = amt });
({ Status: :placed } o, (:pay, amt))             => (:error, (:underpaid, Total(o) - amt));
({ Status: :paid } o, (:ship, _))                => (:ok, o with { Status = :shipped });
({ Status: not :shipped } o, :cancel)            => (:ok, o with { Status = :cancelled });
(o, e)                                           => (:error, (:not_allowed, o.Status, e));
```

**The header reads as a type, not a declaration.** `Outcome(Order, Event)` says *this module is a
function from `(Order, Event)` to `Outcome`* — the name is the module's last segment, so it is
never written twice.

The left margin is now entirely patterns. Nine lines, and the state machine is legible as one.

---

## 3. Arities, and the per-arrow check falling out naturally

```csharp
module Shop.Orders.Order.Total : Money(Order)
                               | Money(list<Line>, Money);

(o)                                   => Total(o.Lines, 0);

([], acc)                             => acc;
([{ Qty: q, Unit: u }, ..rest], acc)  => Total(rest, acc + q * u);
```

Two arrows in the header, separated by `|`. Clauses attach to arrows by arity, and the checker
runs the clause set **once per arrow** — which is exactly ticket 04's finding about CDuce's
mandatory interface, arriving as a syntactic consequence rather than a bolt-on.

`Total(…)` in the body is a call, and the name is in scope unqualified inside its own module. So
the name appears where a name belongs — at call sites — and nowhere else. This is the answer to
the objection that the recursive call reintroduces the name: **defining and calling are different
acts and it is right that only one of them names the thing.**

Note the second arrow's arguments are a private concern. Whether the module exports both arities
or only `Money(Order)` is an export question, not a structure question. → ticket 08.

---

## 4. Recursion under this scheme

```csharp
module Shop.Math.Fib : int(Nat);

(0)            => 0;
(1)            => 1;
(n) when n > 1 => Fib(n - 1) + Fib(n - 2);
```

Three lines and one occurrence of the name, at the only place it means anything.

**But `(0) => 0;` is the one objection that survives intact.** With no name, a single-argument
clause head is visually a parenthesised expression — `(0)`, `(n)` — and the eye has nothing to
anchor on. It is worst exactly where the code is shortest. Candidate answers: require a leading
marker per clause (`| (0) => 0;`), require the parameter list even at arity one and accept it,
or permit an optional name. None is obviously right. → ticket 08.

```csharp
module Shop.Orders.Order.Merge : list<Line>(list<Line>);

([])                                  => [];
([l])                                 => [l];
([a, b, ..rest]) when a.Sku === b.Sku => Merge([a with { Qty = a.Qty + b.Qty }, ..rest]);
([a, ..rest])                         => [a, ..Merge(rest)];
```

At arity one with list patterns it reads well, because the brackets give the eye an anchor the
bare `(0)` does not.

---

## 5. The hard part: OTP behaviours break this

`gen_server:start_link(Mod, …)` calls **`Mod:handle_call/3`**. If `HandleCall` is its own module,
then `Order.Server` does not export `handle_call/3`, and OTP cannot find it. Ticket 06 established
that `-behaviour` has no runtime effect and **only exports matter** — which is precisely why this
breaks: the exports are now in the wrong modules.

The structure and the platform's callback contract are in direct conflict, and something has to
give.

### Candidate: the parent module is a generated facade

```csharp
module Shop.Orders.Order.Server : GenServer
{
    HandleCall  from .HandleCall;
    HandleCast  from .HandleCast;
    HandleInfo  from .HandleInfo;
    Init        from .Init;
}
```

The parent declares which sub-modules supply which callbacks, and the compiler emits a real BEAM
module exporting `handle_call/3` and friends, each delegating to its sub-module.

This generalises beyond OTP, and that is its appeal: **the same facade gives Erlang callers a
normal module.** `Order` can export `apply/2`, `total/1`, `merge/1` by aggregating its
sub-modules, so an Erlang caller writes `'Shop.Orders.Order':apply(O, E)` and never sees the
sub-module structure. Ticket 06 wanted exactly this and had no mechanism for it.

Costs, honestly:

- **Two modules per function** — the sub-module and its slot in the facade.
- **A delegation hop per call**, unless the compiler emits the real code in the facade and leaves
  the sub-modules as compile-time-only organisation. That second option is probably right, and it
  means sub-modules are a *source* concept rather than a BEAM concept.
- If sub-modules are compile-time only, **per-function hot code loading is lost** — the thing
  §01b listed as this structure's novel upside. You cannot have both per-function hot swap and a
  single facade module; they are the same choice seen from two ends. → ticket 13, ticket 14.

### The alternative: OTP modules are exempt

Callback modules are written the old way, one module with several functions. Honest and simple,
but it means the codebase has two structural conventions and the boundary between them is
"whatever OTP happens to require".

---

## 6. Module count — correcting an earlier alarm

01b called module explosion "an operational question... thousands of them". That was overstated.
Elixir and Phoenix codebases routinely run to hundreds or low thousands of modules and nobody
treats it as remarkable. A BEAM module is an atom, a code-server entry and a purge unit, and the
runtime is built for many of them.

The real costs are narrower and worth naming precisely:

- **Cross-module calls are not inlined.** Erlang does not inline across module boundaries, so
  `Total(o)` called from `Apply` is a remote call where in 01b it was local. For a hot inner loop
  this matters; for a command handler it does not. Recursion stays intra-module, which is where it
  matters most.
- **Compile-time dependency graph gets wider**, which affects incremental rebuild granularity —
  in this scheme's favour, since changing one operation recompiles one small module.

---

## 7. What is now settled, and what this pass opened

**Settled by this structure:** the two-clause repetition problem (gone), the helper-placement
problem (gone — helpers are sub-modules or local functions), the signature-clause drift problem
(gone — a file boundary), and the recursive-name objection (dissolved — defining and calling are
different acts).

**Opened, and needing decisions:**

1. **The OTP facade.** Sub-modules as BEAM modules with delegation, or as a source-only concept
   compiled into one module? This is also the per-function-hot-swap question, and the two answers
   are mutually exclusive. → tickets 13, 14.
2. **`(0)` at arity one.** No anchor for the eye. → ticket 08.
3. **Export surface.** Which arrows a module exports, and how the facade decides what an Erlang
   caller sees. → tickets 08, 06.
4. **Where invariants live.** DDD's aggregate invariants are not commands and not types. A
   `Order.Invariants` module? Refinement in the type module? Nothing here answers it.
5. **Naming collisions with the type.** `Order` is both a type and a module namespace containing
   `Order.Apply`. C# lives with exactly this (namespace and class), but it should be deliberate.
