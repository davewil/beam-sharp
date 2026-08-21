# 31 — Composable middleware: is `|?>` already the mechanism?

Type: grilling
Status: resolved 2026-08-21 — [ENG-197](https://linear.app/davewil/issue/ENG-197)

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

**THE VALVE NOW RUNS — 2026-08-18, F14.** This ticket's premise changed while it sat open: `|?>` was
a decision with no implementation, so the question could only be argued. It is built, and
`compiler/examples/Pipeline/pipeline.bs` is a chain that short-circuits and returns its error
unchanged. **So answer this one by measuring**, which is the habit 43, 41 and 28 set — write the
middleware chain the question asks about and see what it cannot say:

```sh
cd compiler && ./_build/default/bin/bsc --src-root examples examples/Pipeline Place -1
```

Two properties F14 established are worth knowing before writing that chain, because both bear on
§2. A stage is declared over the **narrowed** type — `Charge(int v)`, not `Charge(Res v)` — so a
middleware stage's signature names what reaches it rather than the whole union. And a stage may not
inspect the failure through `|?>` at all: the escape hatch is the operator's **absence**, so a stage
that wants to see the error is piped with `|>` and matches it itself. Whether that is enough for
`halt/1` is exactly what this ticket has to decide.

**Do not re-raise** ticket 17's choice of `|?>` over `Result.Then`, or its refusal of an implicit
propagation rule. This ticket asks what the valve *reaches*, not whether it was the right spelling.

**And do not re-derive the macro question.** `Plug.Builder` is a macro, and if §2 concludes that
middleware composition needs compile-time assembly then this ticket is asking for something Elixir
does with one — which the map rules **out of scope**. The answer is already written on the map's
macros entry: the line is **who may generate**, not whether generation happens, since six codegen
obligations already do. Compile-time assembly the *compiler* owns is a codegen obligation and is
available; a *user-extensible* generation mechanism is a redrawing of the destination, not an
increment. Read that entry before proposing anything shaped like a DSL.

---

## Answer — resolved 2026-08-21

**Yes. `|?>` expresses composable middleware and no construct is missing.** The chain in the
question compiles and runs as written, halt propagates unchanged from any stage, and each stage is
declared over the narrowed type. What it costs is a **naming** problem, not a mechanism one, and
that cost is named in §2 below.

Measured, not argued, per the 2026-08-18 note on this ticket. The chain is
[`prototypes/31a-middleware/Middleware`](../prototypes/31a-middleware/Middleware/middleware.bs) and
the premises behind the findings are
[`Controls`](../prototypes/31a-middleware/Controls/controls.bs), because a contrast asserted from a
neighbouring example is not a measurement of this one.

### 1. The chain runs, and halt propagates unchanged

`Handle(req) -> Auth(req) |?> Quota() |?> Dispatch()`, three paths:

| input | result | stages skipped |
|---|---|---|
| authorised, under quota | `{Kind = :'Middleware.Response', Body = :home, Code = 200}` | none |
| `User = :anonymous` | `(:error, {… Body = :unauthorized, Code = 401})` | two |
| `Tag = 500` | `(:error, {… Body = :too_many, Code = 429})` | one |

So routing really is one stage near the end, a halting stage really does stop the pipeline, and the
halted response reaches the caller **unchanged through two intervening stages**. That is the
ticket's central claim and it holds.

### 2. The cost: the pipeline's type is `Response | (:error, Response)`

Both members are an HTTP response — one wrapped, one not. This is §1's *"reads as a lie"* made
concrete, and it is **forced**, not a style choice: projecting straight through the union is
refused.

> `error: Unwrap projects Code from a value that may not carry it` — *this member has no Code:
> `(:error, { Kind: :'Middleware.Response' })` — discriminate on the tag first, in a clause head.*

So every consumer of a middleware pipeline writes two clauses with **identical bodies**:

```csharp
private int Unwrap(Res r)
Unwrap((:error, resp)) -> resp.Code
Unwrap(resp)           -> resp.Code
```

**Ticket 15 §1's collapse does not fire**, which was predicted here and is now measured: the
failure channel is *tagged*, so `Response | (:error, Response)` is two discriminable members and
the absorption predicate `T | <failure member> ≡ T` stays quiet. The lie is a readability cost at
the call site, not a soundness one.

### 3. What it cannot say: in-the-chain-and-still-runs

A stage that must observe **both** outcomes — Plug's logging plug, `register_before_send` — is
piped with `|>` and matches both shapes itself. That works (`Logged(req) -> Handle(req) |> Stamp()`
returns the halted 401 and the plain 200 alike), but note *where it sits*: **outside** the valve
chain, wrapping it.

The honest statement is narrower than "cannot express": beam-sharp expresses **after-the-chain**,
not **in-the-chain-and-still-runs**. Plug's logging plug can appear mid-list and still see halted
conns, because halt stops only *subsequent* plugs and `before_send` fires at send time. `|?>` has
no equivalent, because skipping the stage is the whole point of the operator.

### 4. Stage-local state is a declared list, not an open map

Plug's `conn.assigns` is an open key/value channel any stage writes into without coordinating.
beam-sharp has no such thing: `with` is **width-preserving** so a record cannot grow, and there is
no map type at all —

> `error: no type named map takes a type argument` — *the prelude has `list<T>`, `option<T>` and
> `result<T, E>`.*

`Assigns: list<(atom, term)>` **does** compile and is the substitute: declared centrally once,
after which a stage prepends its own key without the record growing and without any other stage
knowing. That is what keeps this an ergonomic cost rather than a missing construct — the values are
`term` so a reader narrows at each use, and lookup is a list walk. → **[ticket 48](48-a-map-type-in-the-prelude.md)**.

### 5. A stage dispatching on a conn field needs a catch-all

Guards discharge the residual on a **bare parameter** (`Bare(n) when n > 100` / `when n <= 100`
compiles) and **not** on a **field projection** — `Quota(r) when r.Tag > 100` / `when r.Tag <= 100`
reports `Quota is not exhaustive`. Middleware is squarely in the failing case, because a stage
dispatches on a field of the conn. Today a stage writes a catch-all; the form that would fix it is
a relational pattern in nested position, which F13 already lists as owed.

### 6. Two of the ticket's own premises were wrong

- **"That is structurally what `Plug.Conn.halt/1` does."** Not quite. `halt/1` sets a flag that
  `Plug.Builder` checks *between* stages; the conn keeps flowing and `before_send` callbacks still
  fire. `|?>` returns and nothing downstream runs at all. §3 is the consequence of that difference,
  and it is the only thing in this ticket the valve genuinely cannot reach.
- **The `Plug.Builder` worry, restated correctly.** A pipeline assembled from a *runtime list* of
  stages has no spelling, because there is no arrow in the type algebra — but that is
  **deferred to [ticket 37](37-instantiation-by-matching.md), not refused**, and `Plug.Builder`
  assembles at compile time too, so for the pattern the ticket actually asks about this is
  *alignment* rather than a gap. Only `Plug.run/3`'s runtime list is out of reach.

### What this settles for ticket 17

A strong result. The valve was chosen partly on reversibility and it turns out to be the
composition mechanism for an entire application architecture — the pattern that dominates one of
the six exemplar workloads — with one named gap (§3) and one naming cost (§2).

### Owed

- **25a is now rewritable as a pipeline**, which the Notes above call the largest thing wrong with
  it. §3 is the thing to watch while doing it.
- **Ticket 48** takes the map question, and waits on that rewrite for its evidence.
- **Defect, unrelated and logged not fixed:** `compiler/examples/Shop/shop.bs`'s header comment
  documents an invocation that does not work — map keys must be quoted atoms
  (`#{'Kind' => 'Shop.Invoice', …}`), and the unquoted form in the comment is rejected with
  `cannot read … as a value`.
