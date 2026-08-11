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
