# 25 — Exemplar programs the design must serve

Type: prototype
Status: open

## Question

Every prototype so far is one shape: a domain aggregate plus a `gen_server`. That is the case the
design was built to flatter, and it proves little. Real BEAM applications do considerably more,
and each shape stresses a different part of this language.

Fix a set of exemplars, then write each one as the tickets it exercises come ready. They are a
**standing resource** — a test suite for the design — not a single session's work.

### The candidate set

| Exemplar | What it stresses | Tickets it decides |
|---|---|---|
| **HTTP API server** | routing as multi-clause dispatch on method and path; request/response shapes; **JSON in and out** | 08, 09, 11, 17 |
| **Database querying** | untyped result sets crossing a boundary; comprehension/pipeline over rows; connection processes | 17, 18, 22 |
| **Event-queue consumer** | the mailbox at scale; deserialising wire format; back-pressure; failure and redelivery | 12, 14, 15, 18 |
| **Async processing** | whether `async`/`await` survives, or `spawn`/`Task`; supervision of work | 14, 15 |
| **Dynamic web page** | building output; templating; string and **binary** construction | 17, 20 |
| **WebSocket handler** | a long-lived process with a message protocol; **binary frames**; connection lifecycle | 14, 20 |

### The signal to notice before writing any of them

**Three of the six hit binaries**, and [ticket 20](20-untheorised-term-shapes.md) records that
binaries are *untheorised* in the set-theoretic literature — no `<<>>` typing anywhere in either
Elixir type-system paper. Web pages, WebSocket frames and queue payloads are all binary work.

So the most ordinary BEAM workloads sit exactly where the theory is missing. That is a much
sharper statement of ticket 20's risk than the ticket currently makes, and it should be weighed
before the type system is settled, not after.

**JSON cuts the other way, and is worth stating too.** A JSON document is structural, open and
recursive — the shape nominal ADTs handle worst and set-theoretic types handle best. An HTTP API
exemplar is therefore the strongest practical case *for* the ticket 09 structural answer, as
opposed to the theoretical ones already recorded there.

### What each exemplar must produce

Not just code that reads well. For each:

1. The beam-sharp source, written honestly — including the parts that are awkward.
2. **A lowering to Erlang that compiles and runs**, following prototypes
   [01_counter_lowering.erl](../prototypes/01_counter_lowering.erl) and
   [01f_orders_lowering.erl](../prototypes/01f_orders_lowering.erl). Both of those found real
   errors in sample code that had only been read, not executed. Unexecuted samples are worth
   much less.
3. A friction list, in the format 01b established.

### The risk this set exists to test

[Ticket 22](22-how-opinionated.md) weighs baking DDD conventions into the language, and the main
argument against is that it narrows the addressable set — a gateway, a parser, a game server all
fight a domain-shaped grammar. **These exemplars are how that risk gets measured rather than
argued.** A language in which the aggregate reads beautifully and the WebSocket handler is
miserable has answered ticket 22 empirically.

## Notes

HITL for the reactions; the lowerings are AFK. Raised 2026-08-12.

Unblocked — any exemplar can be written at any time — but most valuable written *after* the ticket
it exercises has a candidate answer, so it tests something rather than inventing it.

## A question ticket 12 hands to these exemplars — 2026-08-12

Ticket 12 §2 decided a catch-all is legal **only over an open residual**: `_` is permitted where
what remains contains an unbounded top (`term`, `atom`), and is an **error** where the residual is
closed and the compiler knows the case names.

That decision rests on an empirical claim these exemplars can test: **that deliberately closing a
finite residual is rare.** If it turns out common, forcing every case to be named is a real tax and
a marked spelling for a deliberate close is worth inventing; if rare, such a spelling is ceremony.

Ticket 12 accepted the rule as a **tier-3 invention** — neither audience expects `_` to be
conditionally legal — so evidence either way is worth having before the spec is written.

Where it should bite hardest:

- **Database querying** — result-set shapes and column unions, where a `_` over a known set of
  column types is the tempting move.
- **Event-queue consumer** — a large, closed domain event union, handled partially on purpose
  because most events are not this consumer's business.
- **HTTP API server** — routing as multi-clause dispatch over a closed route union.

Record, for each: how many times a closed residual was closed deliberately, and whether naming the
cases instead read better or worse.

## Constraints from ticket 14 — resolved 2026-08-12

**The OTP showcase is now specified enough to write — but prototype 01e is stale in three ways and
must not be copied verbatim.** See the correction header on
[`01e-otp-under-directory-module.md`](../prototypes/01e-otp-under-directory-module.md). In short:
the clause arrow is `->` not `=>` (prototype 01g), there is no `dynamic` (ticket 11), and
`HandleCall`'s argument is `term`, not `Request` (ticket 14 §4 — narrowing the argument is the
unsound direction).

What an exemplar can now assume:

- **`pid` is untyped** (§1). The message type lives on the client API function's signature, so an
  exemplar's client wrappers are where the `Request` union is written and checked.
- **No `async`/`await`, no `Task`** (§2).
- **`[module: GenServer]` names a typed contract and the user narrows it** (§4), so a showcase
  `HandleCall` signature is genuinely narrow — `(:reply, int, Account) HandleCall(term, From,
  Account);` — and per ticket 12 that narrowing *is* the crash policy the exemplar demonstrates.
- **`receive` exists and is a filter** (§5), so an exemplar may show a non-OTP process, and should
  make clear that unmatched messages stay in the mailbox.
- **The prelude's OTP message types are compiler-known** (§6), so `handle_info` clauses in an
  exemplar should *name* `Down` / `Exit` / `Timeout` rather than spell the tuples.

**One question ticket 12 handed here is now sharper.** Ticket 12 asked how often closing a *finite*
residual is genuinely wanted. Ticket 14 §6 supplies a case where the residual is unavoidably open
and a clause silently never fires ([`14g`](../prototypes/14g_handle_info_blind_spot.erl)) — so an
exemplar `handle_info` is exactly the place to judge whether the open residual plus a
compiler-known message type feels sufficient in practice.

## Two jobs from ticket 17 — resolved 2026-08-13

[Ticket 17](17-pipeline-and-comprehension.md) deferred two decisions onto evidence this ticket is
the standing resource for. Both are answerable by writing exemplars, and neither by argument.

**1. Does a long ladder of unrelated conditions actually occur?** 17 §6 made `switch` the only
branching construct — no `if`, no `else`, no `cond` — with a **tuple subject** for compound
conditions. That is clean at two or three conditions:

```csharp
(user.IsAdmin, o.Total > 100) switch {
    (true, true) => :priority,
    (_,    true) => :large,
    _            => :normal
}
```

and clumsy at five, where `(a, b, c, d, e) switch` is hard to read even with `_` absorbing the tail.
17 declined to pay a keyword for `cond` until the shape is shown to exist. **The database and HTTP
exemplars are the likeliest place** — request validation and query-building are where unrelated
boolean ladders usually live. Report whether they produce one, and at what width.

**2. Does the pipe read well where the lowering is least precise?** 17 §3 found that fold's inlined
lowering widens a binary accumulator at the recursive fixpoint (`bitstring()` rather than
`binary()`). Three of this ticket's six exemplars are binary work — dynamic web pages, WebSocket
frames, event-queue payloads — and all three build output by accumulation. **Write those three with
the pipe and the valve, and lower them**, per this ticket's non-negotiable second requirement. If
binary construction reads badly under `|>`, that is a finding 17 could not have reached from a
single measurement.

Note the exemplar table's `Decides` column is now partly historical for 17: the ticket is resolved,
so these exemplars *test* its answers rather than inform them.
