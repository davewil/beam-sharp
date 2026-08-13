# 31 — Composable middleware: is `|?>` already the mechanism?

Type: grilling
Status: open

Raised 2026-08-13 by David's criticism of [ticket 25](25-exemplar-programs.md)'s HTTP exemplar:
*"in a web server you'd basically have a pipeline and pluggable middleware e.g. Plug in Elixir."*

## Question

**A web application on this platform is a pipeline of composable middleware.** Plug is the
reference implementation and Rack and ASP.NET Core are the same idea: each stage receives the
request, may modify it, and may **halt** the pipeline by producing a response. Routing is one
stage near the end, not the whole program.

[Ticket 17](17-pipeline-and-comprehension.md) §4 gave the language `|?>`, a valve that
short-circuits when its left operand is `(:error, _)` and runs no further stage. **That is
structurally what `Plug.Conn.halt/1` does.** So:

**Does `|?>` already express composable middleware, or is a construct missing?**

If it does, a beam-sharp web stack is

```csharp
req |?> Auth.Check() |?> Quota.Check() |?> Router.Dispatch()
```

and needs nothing new — a strong result for 17, and the answer to a pattern the map has never
tested. If it does not, the gap is load-bearing, because this is how every serious web framework
on the BEAM is built.

## Two things to check before claiming it does

**1. The halt channel carries a success, not a failure.** Plug's halted `conn` is a `conn` with a
response already written — a 401 is a perfectly good HTTP response, not an error. So the beam-sharp
shape is `result<Request, Response>` where the *failure* member is an ordinary 200-class value.
[Ticket 15](15-error-model.md) admits that — `result<T, E>`'s `E` is any type — but 15 chose the
tagged shape for *failure carrying a reason*, and never anticipated `E` being the thing you
actually wanted to return. Check whether `(:error, Response)` reads as a lie at the call site, and
whether 15 §1's collapse rule bites when `Request` and `Response` are both records.

**2. Plug composes its stages at compile time, through a behaviour.** `Plug.Builder` accumulates a
`@plugs` list and generates the pipeline function; the stage set is fixed at compile time and each
stage is a module implementing a two-callback contract. That is [ticket 14](14-concurrency-and-otp-model.md)'s
territory — `[module: GenServer]` names a contract the compiler knows — and it collides with
[ticket 16](16-ad-hoc-polymorphism.md)'s refusal of open extension, which died on ticket 13's
aggregate granularity and hot loading. **A user-declared behaviour contract is exactly ticket 21's
Roc `requires` mechanism**, which 14 left as purely additive; this may be its first real consumer.

## Why this is in scope

The destination is a language specification, and *"tooling and ecosystem"* is out of scope — so
**building a Plug equivalent is not this ticket**. What is in scope is whether the *language
surface* expresses a pattern that dominates one of the six exemplar workloads. Ticket 17 chose
`|?>` over alternatives partly on reversibility; if the valve turns out to be the composition
mechanism for an entire application architecture, that is a fact about the construct, not about a
library.

The 2026-08-13 scope clarification applies: *"is this the multi-year track, or one capability the
language owes its author"*.

## Notes

Blocked by nothing. **Most valuable resolved before the HTTP exemplar is rewritten** — 25a is
currently a router with no pipeline, which is the largest thing wrong with it, and rewriting it
without answering this would just produce a second guess.

**Do not re-raise** ticket 17's choice of `|?>` over `Result.Then`, or its refusal of an implicit
propagation rule. This ticket asks what the valve *reaches*, not whether it was the right spelling.

**And do not re-derive the macro question.** `Plug.Builder` is a macro, and if §2 concludes that
middleware composition needs compile-time assembly then this ticket is asking for something Elixir
does with one — which the map rules **out of scope**. The answer is already written on the map's
macros entry: the line is **who may generate**, not whether generation happens, since six codegen
obligations already do. Compile-time assembly the *compiler* owns is a codegen obligation and is
available; a *user-extensible* generation mechanism is a redrawing of the destination, not an
increment. Read that entry before proposing anything shaped like a DSL.
