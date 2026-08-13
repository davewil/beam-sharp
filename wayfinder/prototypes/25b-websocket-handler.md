# PROTOTYPE 25b — exemplar: a WebSocket handler

> **Throwaway.** Ticket [25](../issues/25-exemplar-programs.md), exemplar 2 of 6.
> Written against the surface as it stands after tickets 26, 27 and 28 (2026-08-13).
> The lowering is [`25b_websocket_lowering.erl`](25b_websocket_lowering.erl) and it **compiles and
> runs on OTP 28.5**. Everything claimed below was executed.

This is the exemplar [ticket 22](../issues/22-how-opinionated.md) named as the test its deferral
waits on — *"at least one of the non-aggregate shapes (WebSocket handler, protocol parser) needs to
exist"*. It is also two of ticket 25's three binary workloads, and carries ticket 17's job 2 (does
the pipe read well where the lowering is least precise?).

---

## The layout

```
lib/shop/socket/                    ← compiles to ONE beam: Shop.Socket
  index.bs          module attributes and types
  decode.bs         frame decoding
  opcode.bs         the opcode table
  encode.bs         frame encoding
  handle_info.bs    the connection process
```

---

## `index.bs`

```csharp
type Opcode =
    :continuation | :text | :binary | :close | :ping | :pong | :reserved;

record Frame { Fin: bool, Op: Opcode, Payload: binary }

type Decoded = result<(Frame, binary), DecodeError>;

type DecodeError = :incomplete | :unmasked_client_frame | :reserved_bit_set;
```

`Payload` is `binary`, **not `string`** — and that distinction is load-bearing here in a way it is
nowhere else in the map. Ticket 20 §4 made `string` a `binary` refined by valid UTF-8, established
by a generated O(n) entry check. A WebSocket text frame is *specified* to be UTF-8 and is
*received* as bytes from a socket, so it is exactly the case where the refinement must be
established at runtime rather than by construction. A binary frame must not pay that cost. **Two
opcodes, two types, one field** — and the record cannot express it, because ticket 26 §4 forbids
absent fields and this is not optionality, it is a field whose type depends on another field's
value. See friction 1.

---

## `decode.bs` — the head that does not work

The RFC 6455 header is `FIN:1, RSV:3, Opcode:4, Mask:1, Len:7`, then 0/2/8 bytes of extended
length, then a 4-byte mask. Written as beam-sharp would want to write it:

```csharp
Decoded Decode(binary);

(<<fin:1, 0:3, op:4, 1:1, 126:7, len:16, mask:32, payload:len, rest>>)
    -> (Frame { Fin = fin, Op = Opcode(op), Payload = Unmask(payload, mask) }, rest);

(<<fin:1, 0:3, op:4, 1:1, 127:7, len:64, mask:32, payload:len, rest>>)
    -> (Frame { Fin = fin, Op = Opcode(op), Payload = Unmask(payload, mask) }, rest);

(<<fin:1, 0:3, op:4, 1:1, len:7, mask:32, payload:len, rest>>) when len < 126
    -> (Frame { Fin = fin, Op = Opcode(op), Payload = Unmask(payload, mask) }, rest);

(<<_:1, 0:3, _:4, 0:1, _>>)  -> (:error, :unmasked_client_frame);
(_)                          -> (:error, :incomplete);
```

The lowering proves the *dispatch* works — five clauses, five native Erlang clause heads, and the
size-driven binary matching does all of it with one guard. But three things here are outside what
any ticket has settled, and the third is a real gap.

**First, `payload:len` is a size taken from a variable bound earlier in the same pattern.** Erlang
allows it; nothing in the map does. Ticket 20 fixed the binary type grammar as `<<_:M, _:_*N>>`
where `M` and `N` are **literals**. A pattern whose segment size is a *bound variable* is not in
that grammar at all, and it is not exotic — it is how every length-prefixed wire format is parsed.

**Second, the three header shapes are not a discriminable union.** They are selected by the *value*
of the 7-bit length field: 126 and 127 are sentinels meaning "the real length is in the next 2 or 8
bytes". Ticket 09's discriminability rule asks whether a BEAM guard can tell union members apart —
and here the answer is yes, but only because the discriminator is an integer *equality on a field*,
not a shape difference. The types `<<_:16, _:_*8>>` and `<<_:72, _:_*8>>` overlap freely; what
separates them is arithmetic on a value inside them. **Ticket 20's binary algebra does not reach
this**, and length-prefixed framing is the majority of what binaries are used for.

**Third, `Opcode(op)` is a function call in a clause body doing what the head should do** — see
`opcode.bs`.

---

## `opcode.bs` — ticket 12's closed residual, and the tax is real

The opcode is 4 bits: an interval `0..15` under ticket 20, which is **closed and finite**. Five
values are named by the RFC; **eleven are reserved**. Ticket 12 §2 says a catch-all over a closed
residual is an **error**, and the compiler knows every case by name. So this is what the language
requires:

```csharp
Opcode Opcode(int);

(0)  -> :continuation;
(1)  -> :text;
(2)  -> :binary;
(8)  -> :close;
(9)  -> :ping;
(10) -> :pong;
(3)  -> :reserved;
(4)  -> :reserved;
(5)  -> :reserved;
(6)  -> :reserved;
(7)  -> :reserved;
(11) -> :reserved;
(12) -> :reserved;
(13) -> :reserved;
(14) -> :reserved;
(15) -> :reserved;
```

**This is the case ticket 12 asked these exemplars to find.** Eleven clauses that mean one thing.
The residual is closed, so `_ -> :reserved` is an error; the interval `3..7 | 11..15` is a perfectly
good description of the set and there is no way to spell it in a pattern, because ticket 20 put
intervals in the *type* language and clause heads match values.

Two ways out exist and both are worse. Declaring `type Reserved = 3..7 | 11..15;` and matching
`(r: Reserved)` invents pattern syntax nothing has settled. Widening the parameter to `int` makes
the residual open and buys the `_` back — by **throwing away** the fact that an opcode is 4 bits,
which is the one thing the type system knew.

**Count for ticket 12: one deliberate close, and it needed eleven clauses to say one word.**
Naming the cases read *worse*, unambiguously. This is a wire protocol, not a contrived case, and
"most values of this field are reserved" is how every wire protocol on earth is specified.

---

## `encode.bs` — ticket 17's job 2

17 §3 found that fold's inlined lowering widens a binary accumulator to `bitstring()` at the
recursive fixpoint, and asked whether the pipe reads well where the lowering is least precise.

```csharp
binary Encode(Opcode, binary);

(op, payload) -> Header(op, ByteSize(payload))
              |> Binary.Append(payload);

binary Fragments(list<binary>);

(chunks) -> chunks |> List.Fold("", (acc, c) => Binary.Append(acc, c));
```

**The pipe reads fine. The type does not.** `Fragments`' accumulator starts as `""` and each step
appends, and 17 §3's widening means the compiler's emitted spec says `bitstring()` where the author
declared `binary`. Ticket 20 §4 says a non-byte-aligned bitstring is a **compile-time error** — so
the declared type and the inferred type disagree at exactly the point the language promises they
will not.

**Measured, and the runtime behaviour is worse than the type suggests.** A single one-bit chunk in
the list poisons the whole accumulation:

```
fragments concat   -> <<"abcdef">>
fragments w/ 1 bit -> {'EXIT',{badarg, ... error_info =>
                       #{cause => {2,binary,unit,<<1:1>>}, ...}}}
```

Note the `error_info` map — that is [ticket 23](../issues/23-what-the-language-owes-an-agent.md)'s
third diagnostic channel observed live, carrying a **structured cause** naming the argument
position, the segment type and the offending value. 23 said the platform builds this value and
`erlc` destroys it; here the *runtime* publishes it intact.

So ticket 17's job 2 answers: **the pipe is not the problem, the accumulator's type is.** The
readability 17 worried about is fine; the precision loss it measured is real and it collides with
ticket 20 rather than with the surface syntax.

---

## `handle_info.bs` — ticket 14's process model

Ticket 14 §5 makes `receive` a **filter**, and §6 puts OTP's message shapes in the compiler-known
prelude stratum, so a handler *names* `Down` / `Exit` / `Timeout` rather than spelling the tuples.

```csharp
(:noreply, State) HandleInfo(term, State);

((Down, pid, reason), s)   -> (:noreply, DropWorker(s, pid, reason));
((Exit, pid, reason), s)   -> (:noreply, Closing(s, pid, reason));
((:tcp, _, data), s)       -> (:noreply, Feed(s, data));
(Timeout, s)               -> (:noreply, Reap(s));
(other, s)                 -> { Log.Warn("unexpected frame", other);
                                (:noreply, s); }
```

The lowering demonstrates the filter behaviour, and it surfaced something sharper than ticket 14
recorded. An unmatched message was sent **first**, then a real one:

```
conn_loop          -> {timeout,[{text,<<"hi">>}]}
```

The process selectively received the `tcp` message, processed it, recursed, and then **fired its
`after` timeout while its mailbox was still non-empty** — the unmatched message sitting there the
whole time. That is correct BEAM semantics and it is a trap worth naming: *a timeout does not mean
the mailbox is empty*, it means nothing **matching** arrived. Ticket 14 §6 found that a mis-shaped
`handle_info` clause never fires and the catch-all absorbs it silently; this is the same hole one
level up — with a catch-all present the message is absorbed, and **without** one it accumulates
invisibly until the process dies of memory.

---

## What writing this actually surfaced

Five things, ordered by how much they should worry you.

0. **Length-prefixed framing is outside ticket 20's binary grammar, and it is most of what binaries
   are for.** Two distinct gaps, both in `decode.bs`. A segment whose **size is a bound variable**
   (`payload:len`) is not expressible in `<<_:M, _:_*N>>` where `M` and `N` are literals. And the
   three header shapes are discriminated by an integer **value** inside the binary (the 126/127
   sentinels), not by shape, so ticket 09's discriminability rule and ticket 20's exact-union
   algebra both look straight past the thing doing the work. **Ticket 20 answered "what must the
   type system model that set-theoretic theory doesn't cover" for binaries as *values on a
   boundary*; this is binaries as a *parsing grammar*, and it is untouched.** → ticket 20, 09.

1. **A field whose type depends on another field's value has no spelling.** A WebSocket frame's
   payload is `string` (UTF-8, ticket 20's opaque refinement) when the opcode is `:text` and bare
   `binary` when it is `:binary`. Ticket 26 §4 forbids absent fields and directs optionality to
   `option<T>` — but this is not optional, it is *dependent*, and 26 §4's own advice applies
   instead: **two record types wearing one name**. So `TextFrame` and `BinaryFrame` are separate
   records and `Frame` is their union, which is correct and which **doubles the clause count of
   every function that handles a frame**. Worth stating because 26 §4 predicted this remedy would
   be cheap, and in a protocol handler it is not. → ticket 26, 20.

2. **Ticket 12's closed-residual rule costs eleven clauses to say "reserved".** Detailed above with
   the code. The rule is right in principle and this is the case that makes it expensive: a closed
   numeric interval where most values share one meaning. An interval **pattern** would fix it, and
   ticket 20 put intervals in the type language only. → ticket 12, 20.

2b. **The obvious workaround for item 2 is lossy, and exhaustiveness catches it in the wrong
   function.** Collapsing all eleven reserved opcodes to a single `:reserved` atom — which is what
   `opcode.bs` above does, and what anyone would do to stop the tax spreading — **destroys which of
   the eleven it was**. So the inverse is uninhabitable:

   ```csharp
   int OpCode(Opcode);

   (:continuation) -> 0;
   (:text)         -> 1;
   // ... and then :reserved, which has no integer to return
   ```

   `Opcode` has seven members, so exhaustiveness demands a `(:reserved)` clause, and there is no
   honest body for it. The compiler is right and it complains **in `encode.bs`, about a mistake made
   in `opcode.bs`** — one file away from the decision that caused it, which is exactly the
   blast-radius property ticket 13's one-function-per-file was supposed to bound.

   **The evidence is that I made this mistake while writing this exemplar and did not notice.** The
   Erlang lowering returns *distinct* atoms (`reserved_3` … `reserved_f`, all eleven) and its
   `op_code/1` covers only the six real opcodes — a partial function that crashes on the rest. The
   beam-sharp source above returns the *collapsed* `:reserved`. **The two artifacts silently
   disagree**, and the lowering is the one that is right. So item 2's tax is worse than item 2 says:
   round-tripping needs **eleven distinct atoms**, not one, and the cheap-looking escape is a
   correctness bug the type system only reveals downstream. → tickets 12, 20, 04.

3. **Ticket 17 §3's accumulator widening collides with ticket 20 §4.** The declared `binary` and
   the inferred `bitstring()` disagree, and a single non-byte-aligned chunk crashes at runtime with
   a `badarg` whose `error_info` names the offending segment. The pipe itself reads fine — **17's
   job 2 was worried about the wrong half.** → tickets 17, 20.

4. **A process can time out with a non-empty mailbox.** Measured above. `after` fires when nothing
   *matching* arrives, not when nothing arrives, so ticket 14 §6's silent-absorption hole has a
   second form: without a catch-all, unmatched messages accumulate invisibly rather than being
   dropped. Ticket 24 made the client API the test boundary, and this is invisible from there —
   nothing in the client API observes mailbox depth. → tickets 14, 24.

5. **I invented four prelude names and the exemplar should say so.** `Binary.Append`, `List.Fold`,
   `ByteSize` and `Unmask` are written above as though they exist. Ticket 17 §1 fixed that chaining
   uses **qualified** names, and ticket 27 dropped the collection library out of the compiler-known
   stratum — but *which* module a binary-building operation lives in, and whether `Binary` is a
   prelude module at all, is unanswered. The map's stdlib-shape fog patch owns this; it is worth
   recording that a binary-heavy exemplar cannot be written without inventing at least a
   `Binary.Append`, since ticket 17's inlining rule makes prelude membership determine the
   **emitted type**, not merely the spelling. → the stdlib-shape fog patch, ticket 17.

### What ticket 22 can now take from this

22's deferral says the trigger is a walking skeleton *plus* a non-aggregate exemplar, and asks
whether a DDD-shaped grammar narrows the addressable set. **The honest answer from this exemplar is
that the DDD constructs did not get in the way — they simply never appeared.** `record`, the minted
tag, `with`, and projection are absent from every file above except `index.bs`; a protocol handler
is patterns, integers and binaries. Nothing about the aggregate-shaped design made the WebSocket
handler miserable.

**What made it awkward was the type system's treatment of binaries, which is orthogonal to how
opinionated the language is.** That is a genuine and slightly surprising result for 22: the risk it
was deferred over is not the risk this exemplar found. Whether that is enough to fire the trigger
is David's call, and one exemplar is one data point — the protocol-parser shape 22 also names has
not been written.
