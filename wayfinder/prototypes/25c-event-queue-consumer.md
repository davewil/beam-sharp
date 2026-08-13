# PROTOTYPE 25c — exemplar: an event-queue consumer (AMQP 0-9-1)

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 3 of 6.
> Written against the surface as it stands after tickets 26, 27 and 28 (2026-08-13).
> The lowering is [`25c_queue_lowering.erl`](25c_queue_lowering.erl) and it **compiles with no
> warnings and runs on OTP 28**. The residual measurements are
> [`25c_residual_probe.sh`](25c_residual_probe.sh), run against the walking skeleton in
> [`compiler/`](../../compiler/README.md). Everything claimed below was executed.

Written as the **second parser-shaped exemplar**, which is what [ticket 30](../issues/30-binaries-as-a-parsing-grammar.md)
says it wants before it is resolved and what [ticket 22](../issues/22-how-opinionated.md) names as
its missing non-aggregate shape. It also carries the question [`25a`](25a-http-api-server.md) left
for whoever wrote next: **does `|?>` earn its place at three fallible stages?**

**Why AMQP and not the database exemplar.** 25a's closing note nominated the database exemplar as
the natural next one, on the strength of the `|?>` question alone. AMQP answers that question *and*
re-exercises ticket 30's two gaps in a second wire format, which is 30's own stated condition for
being decidable. A format that exercised neither gap would have given the map one format twice.
→ recorded so the next session does not silently revert it; the database exemplar is still owed.

---

## The layout

```
lib/shop/queue/                    ← compiles to ONE beam: Shop.Queue
  index.bs          module attributes and types
  frame.bs          AMQP frame decoding
  method.bs         class/method dispatch
  consume.bs        the three-stage pipeline
  disposition.bs    ack / requeue / dead-letter
  encode.bs         frame construction
  handle_info.bs    the consumer process
```

AMQP 0-9-1's frame is `type:8, channel:16, size:32, payload[size], 0xCE`. A `basic.deliver` arrives
as three frames — method, content header, body — and the body is a payload some other system chose.

---

## `index.bs`

```csharp
[module: GenServer]

type FrameType = :method | :header | :body | :heartbeat;

record Frame { Type: FrameType, Channel: int, Payload: binary }

record Delivery {
    ConsumerTag: binary,
    DeliveryTag: int,
    Redelivered: bool,
    Exchange:    binary,
    RoutingKey:  binary
}

record OrderPlaced { Id: string, Qty: int }

type FrameError   = :incomplete | (:bad_frame_end, int) | (:unknown_frame_type, int);
type MethodError  = (:unhandled_method, int, int) | :malformed_method;
type ConsumeError = FrameError | MethodError | ValidationError;

type Disposition = :ack | :requeue | :dead_letter;
```

`ConsumeError` being a bare union of three unrelated error types is ticket 09's structural openness
paying for itself — no wrapper constructor, no `ConsumeError.FromFrame(...)`, and the three stages'
errors unify because a union is a set. Worth noting because it is the *first* thing in this
exemplar and the last thing that gave any trouble.

---

## `frame.bs` — ticket 30's two gaps, in a second format

```csharp
result<(Frame, binary), FrameError> DecodeFrame(binary);

(<<1:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Frame { Type = :method,    Channel = ch, Payload = payload }, rest);
(<<2:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Frame { Type = :header,    Channel = ch, Payload = payload }, rest);
(<<3:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Frame { Type = :body,      Channel = ch, Payload = payload }, rest);
(<<8:8, ch:16, 0:32, 0xCE:8, rest>>)
    -> (Frame { Type = :heartbeat, Channel = ch, Payload = "" }, rest);

(<<t:8, _:16, size:32, _:size, bad:8, _>>) when bad != 0xCE -> (:error, (:bad_frame_end, t, bad));
(<<t:8, _>>) when t != 1 && t != 2 && t != 3 && t != 8      -> (:error, (:unknown_frame_type, t));
(_)                                                          -> (:error, :incomplete);
```

**Both of ticket 30's gaps are here, and the first one appears twice.** `payload:size` is a segment
sized by a variable bound earlier in the same pattern — `M` and `N` in ticket 20's `<<_:M, _:_*N>>`
are literals, so this shape is not in the type language at all. It then recurs *nested*, because
AMQP's `shortstr` is a length octet followed by that many bytes:

```csharp
(binary, binary) ShortStr(binary);

(<<len:8, s:len, rest>>) -> (s, rest);
```

`ShortStr` is four tokens of pattern and the entire content of the gap. A `basic.deliver`'s
arguments contain three of them, inside a payload that was itself sized by a bound variable — so
the exemplar has **bound-variable sizing nested two deep** before it has done anything useful.

The second gap is the dispatch itself: the four clause heads are told apart by the **value** of the
type octet, not by any shape difference. As binary types `<<_:8, _:_*8>>` describes all four.

### One thing 25b did not see: the trailing sentinel is what makes a lie detectable

AMQP puts `0xCE` *after* the variable-length payload. That is not decoration — it is the only
reason a frame whose length field lies can be caught at all:

```
bad frame end    -> {error,{bad_frame_end,1,255}}
```

The clause matched `size:32`, consumed that many bytes, and found the wrong octet where the
sentinel should be. **A pattern performed a consistency check between two fields that the type
system has no way to relate**, which is ticket 30's "the map has no vocabulary for *given*" showing
up in the *validating* direction rather than the parsing one. Ticket 18's boundary rule is
"anything one BEAM guard decides in O(1)"; this is decided by the match itself, in O(size), and it
is the check that matters most.

---

## `method.bs` — and the measurement that changes 25b's headline

```csharp
result<Delivery, MethodError> DecodeMethod(binary);

(<<60:16, 60:16, args>>) -> DecodeDeliver(args);
(<<60:16, 80:16, _>>)    -> (:error, :unexpected_ack);
(<<c:16, m:16, _>>)      -> (:error, (:unhandled_method, c, m));
(_)                      -> (:error, :malformed_method);
```

[`25b`](25b-websocket-handler.md) reported that ticket 12's closed-residual rule cost **eleven
clauses to say "reserved"** over a 4-bit opcode, and called that expensive. AMQP escalates the same
shape: the frame type is **8 bits** (252 unnamed values) and the method selector is a **16-bit class
paired with a 16-bit method** (AMQP 0-9-1 defines about 40 of 2³² pairs). If 25b's reasoning holds,
this file is unwritable.

**It is writable, and the reason is a hole in the language rather than a mercy.** Measured with the
walking skeleton ([`25c_residual_probe.sh`](25c_residual_probe.sh)):

```
1. four named types over a bare `int`
   Classify(int <= 0 | 4..7 | int >= 9) -> ...

2. the same, plus a guard bounding the octet to 0..255
   Classify(int <= -1 | int >= 256) -> ...

2b. CONTROL — the same with a single-sided guard (`t >= 0` alone)
   Classify(int <= -1) -> ...
```

**Probe 2b matters more than it looks.** The residual in probe 2 is what you would see if the
checker credited both bounds *or* if it credited only one and the other came free; 2b settles it —
a single-sided guard leaves exactly `int <= -1` and nothing else, so each comparison is credited
independently and the interval reasoning is sound. **The gap is therefore the signature's, not the
checker's**, which is the stronger and less escapable form of the finding.

**The surface cannot state that a field is eight bits wide.** A parameter is declared `int`; ticket
20 put intervals in the *type* language, and the skeleton's own README records that intervals arise
only from guards, so a guard refines a clause and never the signature. Probe 2 bounds the octet
exactly and the residual that survives is `int <= -1 | int >= 256` — **values the wire cannot
produce**, still open, so a catch-all is legal and required.

Three consequences, and the middle one is the point:

- **Ticket 12's closed-residual rule does not currently bite on any wire protocol.** Every dispatch
  field is an integer, every integer parameter is `int`, and `int` is open. 25b's eleven clauses
  were written because 25b *reasoned* the 4-bit opcode gave a closed residual. The language as it
  stands does not agree.
- **When ticket 20 §5's refinement lands, that reverses — and it reverses worst exactly here.**
  `type Octet = int where value >= 0 && value <= 255;` is named in the skeleton README as the next
  slice increment. The moment a parameter can be declared with a width, every wire dispatch acquires
  a **closed** residual: 252 unnamed values for a frame type, ~2³² for a class/method pair. The
  feature the map already owes would convert this file from writable to unwritable, unless interval
  *patterns* land in the same increment. **That is a coupling neither ticket records.**
- So 25b's finding should be read as **contingent, not current**: the tax is real in the design and
  has never been paid by anything that runs.

**And the skeleton does not implement the rule at all.** Probe 3 offers a catch-all over a genuinely
closed residual (`:method | :header | :heartbeat`, every case an atom the compiler knows) and the
compiler **accepts it** — exit 0, no diagnostic. Ticket 12 §2 says that is an error. Recorded as a
skeleton gap rather than a design change, and it is the first place the skeleton is known to be
behind a closed decision.

### The residual is a diagnostic, and it does not scale

Ticket [23](../issues/23-what-the-language-owes-an-agent.md) makes the residual the thing the
compiler hands an agent to write. Probe 4 asks what that looks like at a protocol's clause count —
40 singleton clauses, which is one AMQP class:

```
Dispatch(int <= 9 | 11..19 | 21..29 | 31..39 | 41..49 | 51..59 | 61..69 | 71..79 | 81..89
       | 91..99 | 101..109 | ... | 391..399 | int >= 401) -> ...
```

**41 disjoint intervals, on one line.** The residual is *exact* — ticket 20's interval algebra doing
precisely what it promised — and as a thing to read or to synthesise a clause head from, it is
useless. 23 §12 moved hole enumeration onto the diagnostic channel and argued the term is the
diagnostic and the prose a pure function of it; that holds, but **the term itself is now the
problem**, and it is the first case in the map where exactness and legibility pull apart. It is also
where a diagnostic *should* say "you have not handled 41 ranges" rather than list them. → tickets
23, 04, 20.

*(Timing from the same probe is not a checker measurement — 5 runs took 547 ms wall, dominated by
escript start. The real number is already in the map's fog: 59 µs at 40 clauses.)*

---

## `consume.bs` — 25a's question, answered, and not the way it was asked

25a left this: *"`|?>` looks like it earns its place at three stages, not one. The database exemplar
is the place to test that."* A queue consumer has four fallible stages — decode the frame, decode
the method, find the body, validate the payload — so it is a stronger test than the two-stage case
25a could reach.

Written the way ticket 17 §4 wants it:

```csharp
result<Delivery, ConsumeError> Consume(binary);

(raw) -> raw |?> DecodeFrame()
             |?> DecodeMethod()
             |?> ValidateAs<OrderPlaced>();
```

**This does not work, and the reason is structural rather than cosmetic.** `DecodeFrame` returns
`(Frame, binary)` — a value *and the rest of the input*. The next stage needs the frame; the stage
after that needs the rest. **A pipeline threads one value; a parser threads a value and a
position.** So the valve composes stages 2→4 and cannot compose stage 1 into them:

```csharp
result<Delivery, ConsumeError> Consume(binary);

(raw) -> switch (DecodeFrame(raw)) {
    (:error, e)                     => (:error, e),
    (Frame { Type = :method } f, rest) =>
        f.Payload |?> DecodeMethod()
                  |?> WithBody(rest),
    (f, _)                          => (:error, (:want_method, f.Type))
};
```

Measured, the valve short-circuits correctly at every stage it does cover:

```
all good         -> {ok,#{... order => #{id => <<"A-1">>,qty => 3}}}
stage 1 (frame)  -> {error,{stage1,{unknown_frame_type,9}}}
stage 2 (method) -> {error,{stage2,{unhandled_method,60,21}}}
stage 4 (payload)-> {error,{stage4,{qty_not_positive,0}}}
stage 4 (nonint) -> {error,{stage4,{not_an_integer,qty}}}
```

**So the answer to 25a is: yes at three stages, and no for a parser.** The valve earns its keep the
moment there are three fallible stages in a row — that half of 25a's guess is confirmed. But the
shape that *produces* three fallible stages most reliably is a decoder, and a decoder is exactly the
shape whose stages do not have the type `A -> result<B, E>`; they have
`A -> result<(B, A), E>`. Ticket 17 §4 chose `|?>` over `Result.Then` partly because the combinator
forces a function-as-value spelling — but a state-threading combinator is what a parser actually
wants, and the valve cannot be it. Nothing here argues for changing 17's decision; it argues that
**the parser shape needs its own answer and does not have one**. → ticket 17, 15.

`ValidateAs<OrderPlaced>` at the end is ticket 18 doing its job: the body is bytes some publisher
chose, ticket 21 says a foreign sender cannot be ruled out, so every field is checked rather than
pattern-bound. The two `stage 4` lines above are that check firing on a payload that is
well-formed and wrong.

---

## `disposition.bs` — ticket 17 job 1: the ladder does occur

Ticket 17 §6 made `switch` the only branching construct, with a **tuple subject** for compound
conditions, and declined to pay a keyword for `cond` until the shape was shown to exist. It named
the database and HTTP exemplars as the likeliest place. **It occurs here, at width 4**, and it is
not contrived — every queue consumer on earth decides ack/requeue/dead-letter from the same inputs:

```csharp
Disposition Decide(result<Delivery, ConsumeError> outcome, bool redelivered, int deliveries);

(o, r, n) -> (Ok(o), Permanent(o), r, n >= 5) switch {
    (true,  _,     _,     _)     => :ack,
    (false, true,  _,     _)     => :dead_letter,
    (false, false, _,     true)  => :dead_letter,
    (false, false, false, false) => :requeue,
    (false, false, true,  false) => :requeue
};
```

Measured:

```
ok r=false n=1     -> ack
error r=false n=1  -> dead_letter
error r=true n=2   -> requeue
error r=true n=7   -> dead_letter
```

**The report for 17 §6 is that width 4 is readable and the honest reason is `_`.** Three of the five
rows are mostly wildcards; the tuple subject is doing real work and the ladder is legible. Two
observations against paying for `cond` anyway:

- The two `:requeue` rows differ only in a position that does not matter, and collapse to
  `(false, false, _, false) => :requeue`. That is a positional wildcard inside a pattern, not a
  catch-all clause, so ticket 12 §2 has nothing to say about it — the ladder is four rows and reads
  better as four. They are written split above only to keep the truth table explicit.
- Two of the four conditions had to be **lifted into named functions** (`Ok`, `Permanent`) to fit
  the tuple, and that improved it. A `cond` ladder would have inlined those as expressions and read
  worse.

So: **the shape 17 §6 was watching for exists, at width 4, and `switch` handled it.** No case for
`cond` from this exemplar. → ticket 17.

---

## `encode.bs` — ticket 17 job 2, and a new limit on the pipe

```csharp
binary EncodeAck(int deliveryTag, bool multiple);

(tag, multiple) -> {
    payload: binary = <<60:16, 80:16, tag:64, 0:7, Bit(multiple):1>>;
    Wrap(1, 1, payload);
};

binary Wrap(int type, int channel, binary payload);

(t, ch, p) -> <<t:8, ch:16, ByteSize(p):32, p, 0xCE:8>>;
```

*(`Wrap` and not `Frame`: the record is already called `Frame`, and ticket 23 §10 makes colliding
short names a defect rather than a style question.)*

**A length-prefixed frame cannot be built by left-to-right accumulation, and this is a stronger
statement than 17 §3's precision loss.** The header contains the payload's size, so the payload must
exist and be measured before the first byte of the frame can be written. It is three steps —
build the inside, measure it, wrap it — and no ordering of `|>` produces it. Measured: building the
*payload* by `List.Fold` and then wrapping gives a byte-identical result (`identical piped -> true`),
so the pipe is fine **within** a length-delimited region and cannot cross one.

25b's accumulator finding reproduces exactly, including the diagnostic:

```
one-bit chunk -> {'EXIT',{badarg, ... error_info =>
                  #{cause => {4,binary,unit,<<1:1>>}, ...}}}
```

Ticket 17 §3's widening to `bitstring()` at the fold's fixpoint collides with ticket 20 §4's rule
that a non-byte-aligned bitstring is a compile-time error — second sighting, second format, and
here it lands on frame construction rather than on message payloads. → tickets 17, 20.

---

## `handle_info.bs` — ticket 14, and back-pressure makes the mailbox hole deliberate

```csharp
(:noreply, State) HandleInfo(term, State);

((:deliver, raw), s) when s.InFlight >= s.Prefetch -> (:noreply, Defer(s, raw));
((:deliver, raw), s)                               -> (:noreply, Handle(s, raw));
((:settle, n), s)                                  -> (:noreply, Settle(s, n));
(Timeout, s)                                       -> (:noreply, Reap(s));
(other, s)                                         -> { Log.Warn("unexpected", other);
                                                        (:noreply, s); };
```

Measured with prefetch 2 and four deliveries:

```
dispositions     -> [ack,ack]
in flight        -> 2 (prefetch 2)
mailbox at exit  -> 2
```

**Two messages were processed, two are still in the mailbox, and the process reported itself
healthy.** 25b found the same accumulation as an *accident* — an unmatched message sitting behind a
selective receive. Here it is **the intended design**: prefetch back-pressure means declining to
take work, and on the BEAM declining to take work means leaving it in the mailbox.

That matters for ticket [24](../issues/24-testing-story.md) more than for 14. 24 made the client API
the test boundary and 25b already noted mailbox depth is invisible from there. This is the case
where that invisibility is not a bug to be caught but **a load-bearing quantity a correct program
must expose** — a consumer at its prefetch ceiling with a growing mailbox is the normal healthy
state right up until it is the outage. Nothing in the language or in 24's boundary offers a way to
observe it, and `sys:get_state` (which 24 measured as buying no determinism) would not show it
either, because the depth is in the mailbox and not in the state. → tickets 14, 24.

---

## What writing this actually surfaced

Six things, ordered by how much they should worry you.

0. **The surface cannot state that a wire field has a width, so ticket 12's closed-residual rule
   does not currently bite — and ticket 20 §5's owed refinement would make it bite hardest exactly
   here.** Measured in [`25c_residual_probe.sh`](25c_residual_probe.sh) probes 1 and 2: an octet
   bounded by a guard leaves the residual `int <= -1 | int >= 256`, values the wire cannot produce.
   25b's eleven-clause tax is therefore **contingent on a feature that does not exist yet**, and
   when it lands a frame type needs 252 named cases and a class/method pair ~2³². **Interval
   patterns and interval refinements must land together or the increment breaks wire parsing.**
   → tickets 12, 20, 04.

1. **The exhaustiveness residual does not scale as a diagnostic.** 40 singleton clauses produce a
   residual of **41 disjoint intervals** (probe 4). It is exactly correct and completely unreadable,
   and ticket 23 makes it the thing the compiler hands an agent to write. First case in the map
   where exactness and legibility pull apart. → tickets 23, 04, 20.

2. **`|?>` earns its place at three stages and cannot serve a parser.** 25a's guess is confirmed and
   its scope is narrower than it looks: decoder stages have type `A -> result<(B, A), E>`, threading
   a value *and* a remainder, and the valve threads one value. The shape most likely to produce
   three fallible stages is the shape the valve cannot compose. → tickets 17, 15.

3. **A length-prefixed frame cannot be built left-to-right.** The header holds the payload's size, so
   construction is build-measure-wrap and no pipe expresses it. The pipe is fine *within* a
   length-delimited region (measured byte-identical) and cannot cross one. 25b's `bitstring()`
   widening reproduces on top of this. → tickets 17, 20.

4. **Ticket 30's gaps reproduce in a second format, and one appears nested two deep.** `payload:size`
   and then `shortstr`'s `s:len` inside it. Also new: AMQP's trailing `0xCE` sentinel means **a
   pattern performs a consistency check between two fields the type system cannot relate** — 30's
   missing "given" in the validating direction. → ticket 30.

5. **Back-pressure makes ticket 14's mailbox hole deliberate rather than accidental**, and ticket
   24's client-API boundary cannot see the one quantity that distinguishes a healthy consumer from
   a failing one. → tickets 14, 24.

6. **The skeleton accepts a catch-all over a closed residual** (probe 3), which ticket 12 §2 makes an
   error. A skeleton gap, not a design change — but the first known place the skeleton is behind a
   closed decision. → the skeleton, ticket 12.

### What ticket 30 can now take from this

30's Notes say it is *"most valuable after a second parser-shaped exemplar exists, so the evidence
is two formats rather than one"*. **That condition is now met.** Both gaps reproduce in AMQP,
independently of RFC 6455, and the evidence is stronger than 25b's in three ways: the
bound-variable segment is **nested two deep**, the value-discriminated union is an **octet with 252
unnamed values** rather than a 4-bit field with 11, and the trailing sentinel shows the same missing
"given" in the *validating* direction. Probes 1 and 2 add what 30 did not have: a measurement of
what the type language can and cannot say about a field's width.

**30 is HITL and is not resolved here** — this is evidence for it, not a verdict.

### What ticket 22 can now take from this

22's trigger wants the **protocol parser** shape, which 25b did not write. This is it, and it
**repeats 25b's answer rather than complicating it**: `record` appears in `index.bs` and nowhere
else, the minted tag never matters, `with` never appears, and projection appears twice. A queue
consumer is patterns, integers and binaries. The DDD constructs did not narrow anything because
they never showed up.

**What made it awkward was, again, entirely orthogonal to how opinionated the language is** — field
widths, the residual's legibility, and the valve's shape. Two exemplars of the two non-aggregate
shapes 22 named now agree. Whether that fires the trigger is David's call; what the exemplars can
say, they have now said twice.
