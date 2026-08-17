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

---

## RESULTS — first two exemplars written 2026-08-13

> Decision brief: <https://claude.ai/code/artifact/6d927928-e5fd-4a15-9e1f-5722b092f2db>

**Two of the six exist**, both with a lowering that compiles and runs on OTP 28.5, both with a
friction list. This is the first section on this ticket that records *results* rather than
incoming constraints. **The ticket stays open** — it is a standing resource, and four exemplars
remain.

| Exemplar | Files | Status |
|---|---|---|
| HTTP API server | [`25a-http-api-server.md`](../prototypes/25a-http-api-server.md), [`25a_http_lowering.erl`](../prototypes/25a_http_lowering.erl) | **written, runs** |
| WebSocket handler | [`25b-websocket-handler.md`](../prototypes/25b-websocket-handler.md), [`25b_websocket_lowering.erl`](../prototypes/25b_websocket_lowering.erl) | **written, runs** |
| Event-queue consumer | [`25c-event-queue-consumer.md`](../prototypes/25c-event-queue-consumer.md), [`25c_queue_lowering.erl`](../prototypes/25c_queue_lowering.erl), [`25c_residual_probe.sh`](../prototypes/25c_residual_probe.sh) | **written, runs** (2026-08-13) |
| Database querying | — | not written |
| Async processing | — | not written |
| Dynamic web page | — | not written |

### The three questions this ticket was holding, answered

**1. Ticket 17 job 1 — RETRACTED the same day. 25a's ladder is contrived and is not evidence.**
David: *"In a web server you'd basically have a pipeline and pluggable middleware, e.g. Plug in
Elixir. So something like the switch in that example is unlikely to be written."* Correct, and it
lands on the one failure this ticket exists to prevent: `admit.bs` **constructed a shape to answer
17's question** rather than writing the workload honestly and reporting what it demanded. Plug, Rack
and ASP.NET Core all distribute those five concerns across separate middleware, each halting the
pipeline, so the architecture dissolves the ladder. **The evidence for 17 job 1 now rests on 25c
alone — width four, reads fine, no case for `cond`.** The larger consequence is recorded as 25a's
friction 1: the exemplar has **no middleware layer**, which is where the language's own constructs
would have been exercised, and it raises a question no ticket has asked — **is `|?>` already the
middleware mechanism?** → new ticket. The struck-through original follows.

~~**1. Ticket 17 job 1 — does a long ladder of unrelated conditions occur? YES, at width five.**~~
HTTP request admission (authentication, verification, quota, body size, feature flag) has no
structural relationship between its five conditions, so 17 §6's tuple subject is the only spelling.
It reads worse than an `if` ladder: the test is separated from its consequence by the tuple's
width, the `_` ceremony grows as O(width²), and the subject line runs to 70 characters before the
first arm. One genuine win against that — the final `(true, true, true, true, true)` arm makes the
ladder *exhaustive*, which an `else` fall-through never is. **The shape 17 declined to pay a
keyword for exists in the most ordinary handler in the set.** Whether that buys `cond` is David's
call; the evidence 17 asked for is now on the table. → 17's `cond` fog patch.

**2. Ticket 17 job 2 — does the pipe read well where the lowering is least precise? The pipe is
fine; the accumulator's type is not.** Binary construction under `|>` reads cleanly. What breaks
is 17 §3's fixpoint widening colliding with ticket 20 §4: the author declares `binary`, the
emitted spec says `bitstring()`, and a single non-byte-aligned chunk crashes the fold at runtime
(`badarg`, with an `error_info` cause naming the segment — ticket 23's third channel observed
live). **17's job 2 was worried about the wrong half.**

**3. Ticket 12 — how often is a closed residual closed deliberately? Once in two exemplars, and it
cost eleven clauses to say one word.** A WebSocket opcode is 4 bits — interval `0..15` under
ticket 20, closed and finite. Five values are named by RFC 6455; **eleven are reserved**. Ticket 12
§2 makes `_ -> :reserved` an error over a closed residual, so all eleven must be written out.
Naming the cases read **worse**, unambiguously. The fix is an interval *pattern*, and ticket 20 put
intervals in the type language only. The HTTP exemplar's route table, by contrast, gets its
catch-all legally — but *by accident*: it is legal because `list<string>` is infinite, not because
a 404 is the specified response to an unmatched request.

**And the tax is worse than that, because the obvious escape from it is a correctness bug.**
Collapsing all eleven reserved opcodes to a single `:reserved` atom — the natural move, and the one
the beam-sharp source made — **destroys which of the eleven it was**, so the inverse function is
uninhabitable: exhaustiveness demands a `(:reserved)` clause of `int OpCode(Opcode)` and there is no
honest integer to return. The compiler is right, and it complains **in `encode.bs` about a decision
made in `opcode.bs`** — one file away, which is the blast radius ticket 13's one-function-per-file
was meant to bound. **The evidence is that I made this mistake while writing the exemplar and did
not notice**: the Erlang lowering carries eleven *distinct* reserved atoms while the beam-sharp
source carries one, and the two artifacts silently disagreed until this was checked. So
round-tripping needs eleven distinct atoms, not one — the cheap-looking escape trades a verbosity
tax for a silent loss of information. → tickets 12, 20, 04.

### The finding neither ticket asked for, and it is the sharpest

**The language's own failure values are unserialisable.** `ValidationError` is *"a tuple today"*
(CONTEXT.md) and `result<T, E>`'s failure member is `(:error, E)` — also a tuple. Ticket 16 §4
established that `json:encode/1` refuses tuples at any depth. **Measured**: the 422 response body
carrying a `ValidationError`, and any response embedding a `result`, both return
`{crashed, error, unsupported_type}`. Ticket 16 §4 converts that runtime crash into a compile
error, which is right — but the compile error then lands on the single most common thing an HTTP
handler does, which is putting its own error reason on the wire.

**The fix already exists and nobody had connected it.** CONTEXT.md records `ValidationError` as
*"a tuple today; a record candidate if one is ever introduced"* — and ticket 26 introduced records
the same day. A record erases to a map and `json:encode` takes a map directly. **`ValidationError`
should be respelled as a record.**

`result`'s `(:error, E)` needs a different fix, and "unserialisable" overstates it: ticket 16 §4
admits serialisation **by decree**, so a published mapping saying `(:error, E)` → `{"error": …}`
settles it without disturbing ticket 15's tag. **The sharper statement is that the language's own
types force the mapping to *define* a tuple encoding rather than reject one** — which is the
opposite of the direction 16 §4 was reasoning in when it cited `json:encode`'s refusal of tuples as
the motive for generating an encoder at all. What is open is the mapping's content, not ticket 15's
decision. → tickets 15, 16, 26; recorded on the map's stdlib-shape fog patch, which is where the
serialisation mapping's debts live.

### What the WebSocket exemplar says to ticket 22

**The DDD constructs did not get in the way — they never appeared.** `record`, the minted tag,
`with` and projection are absent from every file of the WebSocket handler except its declarations.
A protocol handler is patterns, integers and binaries. Nothing about the aggregate-shaped design
made it miserable.

**What made it awkward was the type system's treatment of binaries, which is orthogonal to how
opinionated the language is.** That is a real result for 22 and not the one it was deferred over:
the risk it feared is not the risk the exemplar found. One exemplar is one data point, and the
protocol-parser shape 22 also names has not been written.

### Two gaps in ticket 20 that only a protocol handler exposes

Both from `decode.bs`, and neither is covered by ticket 20's resolution:

- **A segment whose size is a bound variable** (`payload:len`) is not expressible in
  `<<_:M, _:_*N>>`, where `M` and `N` are literals. Every length-prefixed wire format needs it.
- **The three RFC 6455 header shapes are discriminated by an integer *value* inside the binary**
  (the 126/127 length sentinels), not by shape. Ticket 09's discriminability rule and ticket 20's
  exact-union algebra both look straight past the field doing the work.

Ticket 20 answered *"what must the type system model"* for binaries as **values on a boundary**.
This is binaries as a **parsing grammar**, and it is untouched. → tickets 20, 09.

### Ticket 26's remedy is more expensive than 26 predicted

A WebSocket frame's payload is `string` (UTF-8, ticket 20's opaque refinement) when the opcode is
`:text` and bare `binary` when it is `:binary` — **a field whose type depends on another field's
value**. That is not optionality, so `option<T>` does not apply; 26 §4's own advice does — *two
record types wearing one name*. Correct, and it **doubles the clause count of every function that
handles a frame**. 26 §4 predicted this remedy would be cheap; in a protocol handler it is not.

### One process-model finding

**A process can time out with a non-empty mailbox.** Measured: an unmatched message was sent first,
a `tcp` message second; the process selectively received the second, recursed, and fired its
`after` timeout with the first still sitting in the mailbox. Correct BEAM semantics, and the same
hole ticket 14 §6 found one level up — *without* a catch-all, unmatched messages accumulate
invisibly rather than being dropped, and ticket 24's client-API test boundary cannot see it.
→ tickets 14, 24.

### Note for whoever writes the next exemplar

**No `|>` and no `|?>` appeared in the HTTP exemplar at all.** Request handling is dispatch and
validation, not transformation. The valve's absence is the more surprising half — `CreateOrder` is
exactly 17 §4's "validate then act" sequence, and it came out cleaner as a two-arm `switch` on the
`ValidateAs<T>` result, because there is only **one** fallible stage. `|?>` looks like it earns its
place at three stages, not one. **The database exemplar is the place to test that**, and it is the
natural next one to write.

---

## RESULTS — third exemplar, the event-queue consumer, 2026-08-13

> Decision brief: <https://claude.ai/code/artifact/21cb916f-5151-4f3b-8956-2b726f2d3a2a>

[`25c-event-queue-consumer.md`](../prototypes/25c-event-queue-consumer.md) — AMQP 0-9-1, with a
lowering that compiles with no warnings and runs on OTP 28, and a residual probe run against the
walking skeleton.

**Written out of the order this ticket recommended, deliberately.** 25a's closing note nominated the
database exemplar next, on the `|?>` question alone. AMQP answers that question *and* is the second
**parser-shaped** exemplar, which is [ticket 30](30-binaries-as-a-parsing-grammar.md)'s stated
condition for being decidable and the non-aggregate shape
[ticket 22](22-how-opinionated.md)'s trigger still wanted. **The database exemplar is still owed**
and is again the natural next one.

### The correction, and it lands on this ticket's own results section

**Ticket 12's closed-residual tax has never been paid by anything that runs, because the surface
cannot state that a wire field has a width.** Result 3 above records the WebSocket opcode as a
closed `0..15` costing eleven clauses. Measured against the skeleton
([`25c_residual_probe.sh`](../prototypes/25c_residual_probe.sh)):

- four named frame types over a bare `int` → residual `int <= 0 | 4..7 | int >= 9` — **open**;
- the same plus a guard bounding the octet to `0..255` → residual `int <= -1 | int >= 256`,
  **values the wire cannot produce**, still open.

A parameter is declared `int`; ticket 20 put intervals in the *type* language, and intervals arise
only from guards, which refine a clause and never a signature. So the eleven-clause finding is a
correct claim about the **design** and not about the language as it stands — and the reversal is
worse than the current state. When ticket 20 §5's `type Octet = int where ...` lands (the skeleton
README names it as the next slice increment), every wire dispatch acquires a **closed** residual:
252 unnamed values for an AMQP frame type, ~2³² for a class/method pair. **Interval patterns and
interval refinements must land in the same increment or wire parsing breaks.** Neither ticket
records that coupling. → tickets 12, 20, 04.

**Separately, the skeleton does not implement ticket 12 §2 at all** — it accepts a catch-all over a
genuinely closed atom residual, exit 0, no diagnostic. A skeleton gap rather than a design change,
and the first known place the skeleton is behind a closed decision.

### The residual does not scale as a diagnostic

40 singleton clauses — one AMQP class — produce a residual of **41 disjoint intervals on one line**.
Exact, per ticket 20's algebra, and useless to read or to synthesise a clause head from, which is
what ticket 23 makes it for. **First case in the map where exactness and legibility pull apart**,
and an argument that the diagnostic should report the residual's *shape* at some width rather than
enumerate it. → tickets 23, 04, 20.

### `|?>` — 25a's question answered, with a narrower scope than it assumed

**Yes at three fallible stages; no for a parser.** The valve short-circuits correctly across the
consumer's four stages that have the shape it wants (measured, all four failure paths). But a
decoder stage has type `A -> result<(B, A), E>` — it threads a value **and a remainder** — and the
valve threads one value. **The shape most reliably producing three fallible stages in a row is the
shape the valve cannot compose.** Nothing here argues against 17 §4's choice; it says the parser
shape needs its own answer and does not have one. → tickets 17, 15.

### Ticket 17 job 1 — the second data point locates the cliff

25a found the ladder at **width 5** and reported it reads worse than an `if` ladder. 25c found it at
**width 4** (ack / requeue / dead-letter from outcome, permanence, redelivered, delivery count) and
it reads fine. **Consistent, and together they put the readability cliff between 4 and 5.** Two
notes for 17's `cond` patch: lifting two of the four conditions into named functions (`Ok`,
`Permanent`) to fit the tuple *improved* it, which a `cond` ladder would have inlined and made
worse; and the width-4 ladder collapses to four rows with a positional wildcard, which ticket 12 §2
does not touch — it is not a catch-all clause. **No case for `cond` from this exemplar.** → 17.

### A new limit on the pipe, stronger than 17 §3's

**A length-prefixed frame cannot be built by left-to-right accumulation.** The header carries the
payload's size, so construction is build-measure-wrap and no ordering of `|>` expresses it. Measured:
building the *payload* by fold and then wrapping is byte-identical to the direct form, so **the pipe
is fine within a length-delimited region and cannot cross one**. 25b's `bitstring()` widening
reproduces on top of this, in a second format and on frame construction rather than payloads.
→ tickets 17, 20.

### Ticket 30's evidence condition is met

Both of 30's gaps reproduce in AMQP independently of RFC 6455, and the evidence is stronger:
the bound-variable segment is **nested two deep** (`payload:size`, then `shortstr`'s `s:len` inside
it), and the value-discriminated union is an **octet** rather than a 4-bit field. New with this
exemplar: AMQP's trailing `0xCE` sentinel means **a pattern performs a consistency check between two
fields the type system cannot relate** — 30's missing "given", in the *validating* direction rather
than the parsing one, and it is the check that catches a lying length field. **30 is HITL and is not
resolved here.** → ticket 30.

### Back-pressure makes ticket 14's mailbox hole deliberate

Measured with prefetch 2 and four deliveries: two processed, two in flight, **two still in the
mailbox**, process reporting itself healthy. 25b found this accumulation as an accident behind a
selective receive; here it is **the intended design**, because declining work on the BEAM means
leaving it in the mailbox. Mailbox depth is the quantity separating a healthy consumer from an
outage, and ticket 24's client-API boundary cannot observe it — nor can `sys:get_state`, since the
depth is not in the state. → tickets 14, 24.

### What ticket 22 can take

**The protocol-parser shape 22's trigger was still missing now exists, and it repeats 25b's answer.**
`record` appears in `index.bs` and nowhere else; the minted tag never matters; `with` never appears.
A queue consumer is patterns, integers and binaries — the DDD constructs did not narrow anything
because they never showed up, and what made it awkward (field widths, residual legibility, the
valve's shape) is orthogonal to how opinionated the language is. **Both non-aggregate shapes 22
named now agree.** Whether that fires the trigger is David's call.

### Note for whoever writes the next exemplar

**The database exemplar is now doubly owed** — it is the one 25a nominated, and it is the remaining
place to test whether an untyped result set crossing a boundary behaves like the queue body did.
Expect `ValidateAs<T>` per row and check whether that is affordable at result-set scale; 25c only
paid it once per message.

### All three exemplars are missing a `module` declaration — found by F15, 2026-08-17

**Not one of the three `index.bs` files declares a module at all**, and until F15 nothing could
notice: `bsc` read one file and defaulted a missing declaration to `'Main'`, and the exemplars do
not parse yet in any case, so they were invisible to the source index.

F15 made the directory the unit of compilation, and a directory holding `.bs` files with no
`module` line anywhere in it is now an error — a module is a name, and these have none. The
generated files are downstream of the write-ups in `wayfinder/prototypes/25*.md`, which are
canonical and which `bin/extract-exemplars.sh --check` gates, so **the declaration belongs in the
write-ups**, not in `compiler/examples/exemplars/`.

Each write-up's `index.bs` section wants a `module` line naming the path it sits at. The three
directory names are dialect-illegal besides — `25a-http-api-server` is not a module path — so
whoever fixes this is also choosing the exemplars' module names, which is a decision this note
deliberately does not make.

**It changes nothing today.** The exemplars are pruned from every gate that compiles, because they
are the compiler's target rather than a passing corpus. This is recorded so it is not rediscovered
as a surprise the day they first parse.
