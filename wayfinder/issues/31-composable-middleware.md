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

Measured, not argued, per the 2026-08-18 note on this ticket — and **read 31a, 31b and 31c first**,
which this session did not and nearly paid for. 31a lowered `Plug.Builder`, 31b did ASP.NET Core's
runtime assembly, and [`31c`](../prototypes/31c-middleware-on-the-page.md) wrote both candidate
shapes out as ordinary code. Everything in [`31d`](../prototypes/31d-middleware-measured/) is 31c's
page put through the compiler:

| probe | what it measures |
|---|---|
| [`Middleware`](../prototypes/31d-middleware-measured/Middleware/middleware.bs) | the chain, three paths, and a both-outcomes stage — with the two-member declaration §2 corrects |
| [`ShapeA`](../prototypes/31d-middleware-measured/ShapeA/shapea.bs) | 31c's shape A: a terminal stage that always halts, four paths, **one-clause unwrap** |
| [`Controls`](../prototypes/31d-middleware-measured/Controls/controls.bs) | guards on a bare parameter versus a projection; the absence of a map type |
| [`Collapse`](../prototypes/31d-middleware-measured/Collapse/collapse.bs) | whether ticket 15 §1's rule is checked at a user declaration — it is not |
| [`Optional`](../prototypes/31d-middleware-measured/Optional/optional.bs) | whether `|?>` serves `option<T>` — it does not (→ ticket 49) |

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

### 2. The cost is the atom, and it is NOT a two-clause unwrap

**This section's first answer was wrong, and the correction came from this ticket's own prototype
directory.** It reported that the pipeline's type is `Response | (:error, Response)`, that both
members are a response, and that every consumer therefore writes two clauses with identical bodies.
That is true only of the chain as *this* probe declared it, and the probe declared it badly:
`Dispatch` was given the return type `Response`, so the pipeline really did carry two members.

[`31c`](../prototypes/31c-middleware-on-the-page.md) had already written the better shape and
called it: **the terminal stage never passes through**, so its success member is uninhabited and it
is declared `(:error, Response)`. A 200 OK from the router *is* a halt. Measured in
[`ShapeA`](../prototypes/31d-middleware-measured/ShapeA/shapea.bs), all four paths through that
chain — 200, 401, 429, 404 — return a bare `Response`, and the unwrap is **one clause**:

```csharp
public (:error, Response) Handle(Request req)
Handle(req) -> Auth(req) |?> Quota() |?> Dispatch()

private Response Unwrap((:error, Response) halted)
Unwrap((:error, resp)) -> resp
```

31c's claim that *"`Web.Serve.Unwrap` is one clause and the compiler proves it is enough"* holds
when run. **Neither Plug nor ASP.NET Core can state that**: 31a measured halting as a *field on a
struct* and 31b as *not calling `next`*, so in both a halted value and a live value have the same
type and no signature can say which you have.

**So the real cost is narrower and sharper than "a lie at the call site".** It is that a `200 OK` is
spelled `(:error, Orders.Index(r))`, and a router that cannot fail is declared `(:error, Response)`.
That atom reaches the emitted `-spec`, the crash report, and the reviewer. The union is honest about
the *shape*; the word `error` is wrong about the *meaning*.

For the record, the union really is opaque to projection — measured on the two-member form before it
was superseded:

> `error: Unwrap projects Code from a value that may not carry it` — *this member has no Code:
> `(:error, { Kind: :'Middleware.Response' })` — discriminate on the tag first, in a clause head.*

**Ticket 15 §1's collapse does not fire, and the reason is not the one this answer first gave.**
The chain compiling was claimed as the measurement and is not one: `validate_collapses/2`
(`bs_check.erl:1670`) has exactly **one caller**, the `ValidateAs<T>` instantiation at `:1606`, so a
user `type` declaration never reaches it. The conclusion survives on the algebra — the failure
channel is *tagged*, so `Response | (:error, Response)` is two discriminable members and the
predicate `T | <failure member> ≡ T` would stay quiet anyway — but the evidence claimed did not
exist. The lie is a readability cost at the call site, not a soundness one.

**Chasing that turned up a defect against ticket 15 itself.** 15 §1 decided *"the collapse is
rejected at the declaration"*. It is not: `type Absorbed = atom | :nothing` — 15's own worked
degenerate case, where `:nothing` is absorbed by the atom top — compiles and runs
([`Collapse`](../prototypes/31d-middleware-measured/Collapse/collapse.bs)). The rule is implemented for
`ValidateAs<T>` instantiation only, so **half of 15 §1 is unbuilt**, and the half that is missing is
the one its own text leads with. Logged in Owed; not fixed here, because a decision ticket does not
carry a compiler change.

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

### §2's behaviour contract gains no consumer, which answers the half most at risk of being dropped

The ticket's §2 said a user-declared behaviour contract *"is exactly ticket 21's Roc `requires`
mechanism"* and that middleware **"may be its first real consumer."** It is not, and the reason is
structural rather than a deferral.

Plug needs the contract because a stage is a **module named in a list**: `Plug.Builder` holds
`@plugs` as module names and must know what to call on each, so `init/1` and `call/2` have to be a
declared behaviour. `|?>` composes **functions named at the call site**, so the compiler already
checks each stage's arity and type where it is written, and there is nothing left for a contract to
promise. The contract exists in Plug to recover type information that a list of atoms threw away;
the valve never throws it away.

So [ticket 21](21-escape-hatch-precedents.md)'s `requires` gains no consumer here, and
[ticket 16](16-ad-hoc-polymorphism.md)'s refusal of open extension is **not** challenged by this
workload — the collision §2 anticipated does not occur. That is a second strong result for 17: the
valve dissolves the need for the mechanism rather than needing it.

### 7. The live question this leaves: 31c's shape B, now with two measurements behind it

[`31c`](../prototypes/31c-middleware-on-the-page.md) drafted a remedy for §2's atom and this session
did not invent it — it nearly missed it. Shape B keys the valve on the **declared parameter type**
rather than on the atom:

| | |
|---|---|
| today | `|?>` short-circuits where its left operand is `(:error, _)` |
| shape B | `|?>` short-circuits where its left operand is **not in the stage's declared parameter type**; that member passes through unchanged |

31c argues the compiler gains nothing it lacks — signatures are mandatory (ticket 04) so the
parameter type is known at the call site, and union members are discriminable by one guard in O(1)
(ticket 09), which is the test every clause head already performs. The stage then spells its halt
`(:halt, Response)` and a 200 stops being an error.

**Two things measured here bear on that choice, and both favour looking at it properly.**

- **The valve does not serve the construct it was borrowed from.** Ticket 17 §4 justified `|?>` as
  *"a tier-1 borrow for both halves of the audience simultaneously"* — C#'s `a?.B()` and
  TypeScript's optional chaining. Those short-circuit on **null**, whose analogue here is
  `option<T> = T | :nothing`. Measured
  ([`Optional`](../prototypes/31d-middleware-measured/Optional/optional.bs)), the valve **refuses**
  it: *"this `|?>` in Load is over a value that cannot fail — `:nothing | { Kind: :'Optional.User' }`
  has no `(:error, _)` member, so the valve would never stop. Write `|>` instead."* Under shape B
  that chain works, because `:nothing` is not in `For`'s parameter type. This is a finding against
  17's stated borrow rationale, not a preference.
- **Shape A's cost is smaller than this ticket first reported** (§2), which cuts the other way and
  is why this is a question rather than a conclusion. The one-clause unwrap removes the ergonomic
  argument for shape B; what remains is the atom's honesty and the `option<T>` gap.

**Not decided here.** It is a change to a shipped operator's meaning, it was raised by 31c rather
than by this ticket's question, and 31c names a real cost against it — the reader must know the
stage's declared parameter type to know what short-circuits, where today they need only recognise
`(:error, _)` on the page, and read cost carries full weight under the standing constraint.
→ **[ticket 49](49-what-the-valve-keys-on.md)**.

### What this settles for ticket 17

A strong result. The valve was chosen partly on reversibility and it turns out to be the
composition mechanism for an entire application architecture — the pattern that dominates one of
the six exemplar workloads — with one named gap (§3) and one naming cost (§2).

### Owed

- **25a is now rewritable as a pipeline**, which the Notes above call the largest thing wrong with
  it. §3 is the thing to watch while doing it.
- **Ticket 48** takes the map question, and waits on that rewrite for its evidence.
- **Defect against ticket 15, found by this ticket's own review:** 15 §1's collapse rule is
  implemented at `ValidateAs<T>` instantiation only, so a *user declaration* that collapses is
  accepted. `type Absorbed = atom | :nothing` compiles. Owed a feature or a ticket of its own.
- **Defect, unrelated and logged not fixed:** `compiler/examples/Shop/shop.bs`'s header comment
  documents an invocation that does not work — map keys must be quoted atoms
  (`#{'Kind' => 'Shop.Invoice', …}`), and the unquoted form in the comment is rejected with
  `cannot read … as a value`.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Composable middleware, and what the valve reaches](issues/31-composable-middleware.md) —
  **`|?>` expresses it, and the gap is one stage-shape rather than a mechanism.** The chain
  `Auth(req) |?> Quota() |?> Dispatch()` compiles and runs; a halting stage stops the pipeline and
  its response reaches the caller **unchanged through two intervening stages**, so routing really is
  one stage near the end. Measured rather than argued
  ([`31d-middleware-measured`](prototypes/31d-middleware-measured/Middleware/middleware.bs)), which is what the
  2026-08-18 note on the ticket asked for once F14 made the valve real. **The cost is one word, not a
  shape**: a terminal stage never passes through, so it is declared `(:error, Response)` and the
  pipeline has **one** member — the unwrap is one clause the compiler proves is enough, which
  neither Plug nor ASP.NET Core can state, since in both a halted and a live value have the same
  type. What is wrong is the atom: a `200 OK` is spelled `(:error, _)` and that reaches the `-spec`
  and the crash report. **The two-clause unwrap this entry first reported was an artefact** of a
  probe that declared the router over `Response`; 31c had already written the better shape and this
  session nearly missed it. **Ticket 15 §1's collapse does not fire** — on the algebra, not on the
  measurement first claimed: `validate_collapses/2` has one caller, the `ValidateAs<T>` site, so a
  user declaration never reaches it. Chasing that found **half of 15 §1 unbuilt**:
  `type Absorbed = atom | :nothing`, its own worked degenerate case, compiles.
  **The one thing it cannot say is in-the-chain-and-still-runs** — a stage observing both outcomes is
  piped with `|>` and wraps the chain from outside, where Plug's logging plug sits *mid-list* and
  still sees halted conns. That is also where the ticket's own premise was wrong: `halt/1` sets a
  flag checked *between* stages and `before_send` still fires, where the valve returns and nothing
  downstream runs at all. **The `Plug.Builder` worry restated**: a runtime list of stages has no
  spelling for want of an arrow type, but that is deferred to ticket 37 rather than refused, and
  Builder assembles at compile time too — alignment, not a gap. Two smaller findings owed onward:
  stage-local state is `list<(atom, term)>` because `with` is width-preserving and there is no map
  type (→ ticket 48), and a stage dispatching on a **field projection** needs a catch-all, since
  guards discharge the residual on a bare parameter and **not** on a projection (controlled for).
  **25a is now rewritable as a pipeline**, which its own notes call the largest thing wrong with it.
```
