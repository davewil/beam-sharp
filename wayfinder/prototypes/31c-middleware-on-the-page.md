# 31c — Middleware on the page

Two shapes, written out as ordinary code. [`31a`](31a_plug_builder_lowering.md) established that
Plug's macro lowers to exactly the chain beam-sharp writes by hand, so **the pipeline itself needs
no new construct** and is the same in both shapes below. What differs is one thing: what the
halting member is called, and what the valve keys on.

Same workload throughout — authenticate, check a quota, route — with the halt cases written
honestly, including the awkward one (a 200 OK produced by the router is *also* a halt).

---

## Shape A — the valve exactly as it stands

`|?>` short-circuits on `(:error, _)`. Nothing changes anywhere.

```csharp
module Web.Auth

result<Request, Response> Check(Request r)

Check(r) when Headers.Has(r, "authorization") -> r
Check(r)                                      -> (:error, Response.Unauthorized())
```

```csharp
module Web.Quota

result<Request, Response> Check(Request r, int limit)

Check(r, limit) when r.Hits <= limit -> r
Check(r, limit)                      -> (:error, Response.TooManyRequests())
```

```csharp
module Web.Router

// The terminal stage never passes through — its success member is uninhabited.
(:error, Response) Dispatch(Request r)

Dispatch(r) when r.Path == "/orders" -> (:error, Orders.Index(r))
Dispatch(r)                          -> (:error, Response.NotFound())
```

```csharp
module Web.App

(:error, Response) Handle(Request req)

Handle(req) -> req |?> Web.Auth.Check()
                   |?> Web.Quota.Check(100)
                   |?> Web.Router.Dispatch()
```

```csharp
module Web.Serve

Response Serve(Request req)

Serve(req) -> Unwrap(Web.App.Handle(req))

Response Unwrap((:error, Response) halted)

Unwrap((:error, resp)) -> resp
```

**What it costs.** A `200 OK` from the router is spelled `(:error, Orders.Index(r))`. The router's
declared return type — a function that cannot fail — is `(:error, Response)`. That atom reaches the
emitted `-spec`, the crash report, and the reviewer.

---

## Shape B — the valve keys on the type, not the atom

One line in `index.bs`, an ordinary stratum-1 alias a user could have written:

```csharp
type stage<T, H> = T | (:halt, H)
```

```csharp
module Web.Auth

stage<Request, Response> Check(Request r)

Check(r) when Headers.Has(r, "authorization") -> r
Check(r)                                      -> (:halt, Response.Unauthorized())
```

```csharp
module Web.Router

(:halt, Response) Dispatch(Request r)

Dispatch(r) when r.Path == "/orders" -> (:halt, Orders.Index(r))
Dispatch(r)                          -> (:halt, Response.NotFound())
```

`Web.App.Handle` and the pipeline are **character-identical to shape A**.

### The compiler delta, in one rule

| | |
|---|---|
| today | `|?>` short-circuits where its left operand is `(:error, _)` |
| shape B | `|?>` short-circuits where its left operand is **not in the stage's declared parameter type**; that member passes through unchanged |

**What the compiler must gain: nothing it does not already have.** Signatures are mandatory
([04](../issues/04-crossclause-exhaustiveness.md)), so the stage's parameter type is known at the
call site. Union members are discriminable by one BEAM guard in O(1)
([09](../issues/09-union-representation.md)), so *"is this value in that member"* is the test the
language already requires at every clause head. The emitted code does not change — still a `case`
per stage ([18](../issues/18-boundary-defence.md) §3), matching the other member. No new operator,
no codegen obligation.

### What it buys beyond middleware

**`|?>` starts working on `option<T>`.** Ticket 17 §4 justified the valve as *"a tier-1 borrow for
both halves of the audience simultaneously"* — C#'s `a?.B()` and TypeScript's optional chaining. But
those short-circuit on **null**, and null's beam-sharp analogue is
[15](../issues/15-error-model.md)'s `option<T> = T | :nothing`, not `(:error, E)`. **As specified,
the operator does not serve the construct it was borrowed from:**

```csharp
option<User>    Fetch(UserId id)
option<Account> For(User u)

// today: illegal — the left operand is `:nothing`, not `(:error, _)`
// shape B: works — `:nothing` is not in `For`'s parameter type, so it passes through
Load(id) -> Users.Fetch(id) |?> Accounts.For()
```

That example is [`LANGUAGE.md` §5's own illustration of the valve](../../LANGUAGE.md), and whether it
type-checks today depends on a return type the reference does not state.

### What it costs

The reader must know the stage's declared parameter type to know what short-circuits, where today
they need only recognise `(:error, _)` on the page. That is a read cost, and read cost carries full
weight under the standing constraint.

---

## What both shapes get that neither neighbour has

Measured in [`31a`](31a_plug_builder_lowering.md) and [`31b`](31b_aspnet_runtime_assembly.md):
halting is a **field on a struct** in Plug and **not calling `next`** in ASP.NET Core. In both, a
halted value and a live value have the same type.

Here it is a member of a union, so `Web.Router.Dispatch`'s signature *states* that it always halts,
and `Web.App.Handle`'s return type says the pipeline always produces a response — checked by
exhaustiveness at the definition. **`Web.Serve.Unwrap` is one clause and the compiler proves it is
enough.** Neither Plug nor ASP.NET Core can express that.

Against it, one named limit, also measured: Plug hoists `init/1` to compile time — `31a` found
`13 * 7` baked into the emitted module as the literal `91` — where `x |> F(a)` → `F(x, a)` passes
`a` on every request.
