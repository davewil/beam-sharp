# 30 — Binaries as a parsing grammar, not as values on a boundary

Type: grilling
Status: resolved 2026-08-20

Raised 2026-08-13 by [ticket 25](25-exemplar-programs.md)'s WebSocket exemplar
([`25b`](../prototypes/25b-websocket-handler.md)), which is the first prototype in the map to parse
a real wire format.

## Question

[Ticket 20](20-untheorised-term-shapes.md) settled the binary type grammar as `<<_:M, _:_*N>>` with
an exact union algebra, and answered [ticket 18](18-boundary-defence.md)'s boundary question with
*"anything the grammar can spell"* — `byte_size` and `bit_size rem N` being O(1) guard BIFs. That
is binaries as **values arriving at a boundary**, and for that purpose it holds up.

**Parsing a wire format is a different problem, and two things it needs are outside that grammar.**

### 1. A segment whose size is a bound variable

RFC 6455's payload length is read from an earlier field of the same header:

```csharp
(<<fin:1, 0:3, op:4, 1:1, len:16, mask:32, payload:len, rest>>) -> ...;
```

Erlang permits this and the lowering runs. But `M` and `N` in `<<_:M, _:_*N>>` are **literals**, so
a segment sized by a bound variable is not expressible in the type language at all. This is not an
exotic case — it is how essentially every length-prefixed format is parsed, and three of ticket
25's six exemplars parse one.

Open: what is the *type* of `payload` above? It is a `binary` of unknown length at the declaration
and a known length at the match. Does the checker learn anything from `len`'s interval, and if so
is that a dependent type by another name — which the map has nowhere admitted?

### 2. A union discriminated by a value inside the binary, not by its shape

The three RFC 6455 header shapes are selected by the **value** of a 7-bit field: 126 means "the
real length is the next 16 bits", 127 means "the next 64 bits", anything below means "this field
*is* the length". As binary types the three overlap freely — `<<_:16, _:_*8>>` contains
`<<_:72, _:_*8>>` — so:

- **[Ticket 09](09-union-representation.md)'s discriminability rule** asks whether a BEAM guard can
  tell union members apart. Here it can, but only by arithmetic on a field *inside* a member, which
  is not what the rule means by discriminable.
- **Ticket 20's exact union algebra** would absorb the three into one, since one contains another —
  losing precisely the distinction the parser is built on.

Open: does the language model this, or does it declare wire parsing to be ordinary clause dispatch
over a `binary` with no type-level structure — and if the latter, what does
[ticket 04](04-crossclause-exhaustiveness.md)'s residual mean over a binary subject?

## Why this is not ticket 20 reopened

Nothing ticket 20 decided is wrong. 20 asked *what must the type system model that set-theoretic
theory doesn't cover*, and answered it for binaries as values — sizes, alignment, UTF-8, the
boundary check. It never asked what a binary type does when the binary is a **grammar being
consumed left to right**, and its `AMENDED` section (ticket 29) did not either.

The map's recurring line — **guard-decidable in O(1) or not reasoned about** — is what makes this
sharp rather than vague. A variable-size segment is decidable in O(1) *given* the earlier field, and
the map has no vocabulary for "given".

## Why it matters more than it looks

**Ticket 25 records that three of its six exemplars are binary work**, and the WebSocket handler
found both gaps in its first twenty lines. Ticket 22's deferral asks whether the language narrows
the addressable set; 25b's report is that the DDD constructs did **not** get in the way and the
binary treatment did. So this ticket, not ticket 22, is where that friction actually lives.

## Notes

Grilling. Blocked by nothing — but most valuable after a second parser-shaped exemplar exists, so
the evidence is two formats rather than one. Ticket 22 names a **protocol parser** as the other
non-aggregate shape it wants; that exemplar would serve both.

**Do not re-raise what 20 settled**: the `<<_:M, _:_*N>>` grammar, the exact union algebra for
fixed and repeating sizes, the `string`/`binary` split, base64 encoding of bare binaries, or the
O(1) boundary rule. This ticket is about the *consuming* direction only.

## Two more things this ticket owes, added 2026-08-15 by F9

F9 built binaries **as values** — `binary` as the top, `string` as its valid-UTF-8 refinement, the
literal, and 20 §3's boundary rule enforced in both directions — and stopped deliberately at this
ticket's edge. Stopping there surfaced a question neither ticket had written down.

### 3. A surface spelling for a *sized* binary type

F9 ships `binary` and `string` and nothing in between, so this is code that cannot be written:

```csharp
// none of these has a spelling, and none is decided
type Header = <<_:32>>
type Frame  = binary<32>
type Chunk  = binary where bit_size % 8 == 0
```

Ticket 20 §2 published the algebra in **Erlang's own** `<<_:M, _:_*N>>` notation, which is the
notation of the language beam-sharp is *not* — this surface writes `list<T>` where Erlang writes
`[T]`. Borrowing the spelling unexamined would be the first place the language does the opposite of
what it does everywhere else, so F9 flagged it rather than inventing one.

**It belongs to this ticket rather than a new one**, because §1 and §2 already need a spelling for
the *pattern* form, and **a pattern and a type that cannot be written in the same notation is a
worse outcome than either choice**. They are one question wearing two hats.

### 4. §2 at the smallest possible scale — a string literal in pattern position

`Greet("hello") -> :hi` is out of F9 for exactly §2's reason. It needs a **value-level singleton**
in the binary part, and 20's grammar is *sizes, not values*: `<<_:M, _:_*N>>` cannot say "this one".
So it is *a union discriminated by a value inside the binary* with the binary being five bytes long,
and admitting the pattern without deciding it would mean admitting a match the checker cannot prove
exhaustive.

Worth weighing when §2 is answered, because **a language whose strings cannot be matched literally
will be noticed long before anyone parses a WebSocket frame** — this is the small, common, everyday
face of the same gap, and it may be the better one to design against.

### What F9 leaves in place

The binary part of the algebra is a **set** — the two-element powerset of `{utf8, other}` — so a
size partition refines it later without changing its shape. The exactness requirement 20 insisted on
is already honoured and there is no join to undo.

## The premises, measured — 2026-08-20

Working note, not an answer. Full survey with verbatim outputs and diagnostic numbers:
[`research/30-binary-grammar-prior-art.md`](../research/30-binary-grammar-prior-art.md).
At-a-glance version: <https://claude.ai/code/artifact/891272e6-13b0-4c21-bc33-46dce0feb1d8>.

**Two of this ticket's own claims are false, and both are scoping rather than detail.**

- **"Most valuable after a second parser-shaped exemplar exists."** That exemplar exists.
  [25c](../prototypes/25c-event-queue-consumer.md) opens by saying AMQP *"re-exercises ticket 30's
  two gaps in a second wire format, which is 30's own stated condition"*. The Notes below rank this
  ticket last against a condition it already satisfies.
- **"Three of ticket 25's six exemplars."** Six was 25's specification; three were written, and
  those three are exactly the binary ones. The sample is three of three.

**Four of them hold, and one is stronger than stated.** All four surface forms — the binary
pattern, the sized binary type, `binary<32>`, and `Greet("hello")` — fail at the **parser**, so none
of this syntax exists in any form. There is no size dimension anywhere in the type representation,
not merely no *spelling* for one: the binary part is a four-point lattice on `{utf8, other}`, and
ticket 20's exact union algebra was never built. Binaries pass through three one-line ordset calls.

**That retires §2's framing.** §2 is written as a conflict — the exact union algebra *"would absorb
the three into one, losing precisely the distinction the parser is built on"*. There is nothing to
lose: the algebra exists only in prose. The question is the cleaner *"does a size dimension get
added at all"*, asked of a lattice that has never had one, with no join to undo.

**And §2 and §4 are one question.** Every discriminator in both exemplars is a literal integer in a
binary segment — `126:7`, `127:7`, `1:8`, `0xCE:8`, `60:16`. `Greet("hello")` is the same construct
with a string. F9 filed §4 here on exactly that suspicion and was right.

### What the survey says

Nobody proves coverage over a binary discriminated by a value inside it; nobody relates two fields
of one pattern, and three of four refuse it with a dedicated diagnostic. **A dependent size is not a
road anyone is on.** C# is the one language that does coverage properly — partitioning arity against
element value-space and returning the counterexample in the pattern's own syntax, which is the
borrowable mechanism — but it has no sub-byte concept, and both exemplars are bit-packed in their
first eight bits. **Coverage over a 4-bit opcode is beyond every language measured.** That is either
the differentiator or the overreach, and it is a decision rather than a measurement.

### What it would cost, measured rather than estimated

The tempting claim — that a segment `t:8` binds a byte-wide integer and coverage falls out of the
interval algebra already built — is **half true, and the failing half is the expensive one**. The
coverage engine *does* decompose into sub-positions and track field-level coverage: over a record
field, two-of-three atom cases is red and three-of-three is green. But the **residual renderer
discards every field-level fact**, printing only `{ Kind: :'Hdr' }` in both directions. And interval
patterns do not work in nested position — already diagnosed: *"a relational pattern goes where a
whole argument goes … inside a record pattern, a tuple or a list it is not built yet"*.

So the delta is a renderer that carries sub-position facts, plus nested interval patterns. Both are
**general** gaps rather than binary-specific ones, and closing them improves records and tuples too.

**The cost that is not in the compiler at all** is 25c's recorded coupling: today every dispatch
field is `int`, `int` is open, and a catch-all is always legal. The moment a field can be declared
with a width, every wire dispatch acquires a **closed** residual — 252 unnamed values for a frame
type — and 25b measured that tax at eleven clauses to say "reserved" over a 4-bit opcode. Proving
wire parsing makes wire parsing harder to write. That trade is the decision.

---

## Answer — 2026-08-20

**A binary gets no structure in the type language: a segment's *width* becomes an interval
refinement on the value it binds — `t:8` is an `Octet` by inference — and that inference is the whole
of what this ticket adds.**

Resolved 2026-08-20, against a survey of four languages, all compiled and run:
[`research/30-binary-grammar-prior-art.md`](../research/30-binary-grammar-prior-art.md). Nothing
enters the type lattice — the binary part stays the four-point set F9 shipped.

**Three refusals sit around the one inference.** Sizes stay **erased**: `payload:size` runs and
`payload` is typed `binary`, because relating two fields of one pattern is refused by every language
measured, three of them with a dedicated diagnostic — Erlang's `bad binary type`, Elixir's typespec
grammar enumerating its only three forms, and C# `CS9135`. **§3's sized-binary spelling never
arises**, which retires F9's fear of a pattern and a type in disagreeing notations; C# is the
positive evidence, being the one language with both a sized sequence type and a sequence pattern and
unable to use them together (`CS8985`). **String literals in pattern position are admitted** as
byte-string singletons, with a catch-all always required, because a `string`'s residual is always
open.

**The binary pattern does shape; a function head does value.** A `_` over a binary is always legal —
a binary can always be too short — so it also absorbs any wire value left unhandled, and the compiler
is not asked to see through that. Value dispatch belongs in a second head, where the residual is
computed. That deliberately makes an idiom of the shape 25b filed as a smell, and the price is real:
write the tag dispatch inline in the binary patterns and the checking is silently lost with no
diagnostic saying so, which F13 owes in its docs.

**Two things this answer said were corrected by F13 the same day, and the correction is the later
word.** As first written it named two general gaps as the real cost — interval patterns in nested
position, and a residual renderer that keeps sub-position facts — and repeated 25c's coupling that
interval patterns and interval refinements must land in the same increment. **Neither cost row was
built and neither was needed**: this answer's own rule puts every residual F13 can produce at
whole-argument position, where the renderer already prints legibly and relational patterns have
worked since F2, and 25c's coupling had already been satisfied for four days when this answer
repeated it — `Classify(>= 4)` closes a 4-bit opcode in one clause where 25b priced saying
"reserved" at eleven. Both gaps remain real and general, now with nothing waiting on them. The
second correction is §4's owed test, **discharged by F13**: `binary_tests` runs a set of string
literals with a catch-all (accepted) and the same set without one (`inexhaustive`).

**Flagged as a reversal risk, and this is the decision to revisit first.** Nobody proves coverage
over a *sub-byte* field: C# does coverage properly but has no sub-byte concept at all, Erlang does no
exhaustiveness checking whatever, Elixir's set-theoretic machinery provably does not reach binaries,
and Gleam has subsumption over bit arrays and refuses coverage even for a 1-bit tag with both values
named. Both exemplars are bit-packed in their first eight bits, so **for the case that actually
matters the survey is unanimous against this answer**. It is defensible because none of the four
failed by *trying and finding it unsound*, and cheap to reverse, since nothing entered the type
lattice — backing out means dropping an inference, not unwinding an algebra.

**A binary gets no structure in the type language. A segment's *width* becomes an interval
refinement on the value it binds, and that is the whole of what this ticket adds.**

Three refusals and one small inference. Nothing enters the type lattice: the binary part stays the
four-point set F9 shipped. `bs_types.erl` predicted a size partition could refine it later "without
changing its shape" — and it turns out no partition is needed.

## §1 — a segment sized by a bound variable

**`payload:size` is permitted, lowered, and the dependency is erased. `payload` is typed `binary`.**

The type language learns nothing from `size`'s interval, deliberately. The map needs no vocabulary
for *"given"*, and no dependent type is admitted.

This follows the survey rather than deciding against it. Every language measured refuses to relate
two fields of one pattern, three of them with a dedicated diagnostic — Erlang `bad binary type`
(including through `when` constraints, which otherwise work), Elixir's typespec grammar enumerating
its only three forms, C# `CS9135`. Gleam permits the segment and erases the dependency at the
binding, which is exactly the behaviour adopted here.

**What this gives up, named so it is not rediscovered as a defect.** AMQP's trailing `0xCE` sentinel
is the only way a frame whose length field lies can be caught, and it stays a runtime check. 25c
calls it *"the check that matters most"*. Nothing in this answer touches it, and nothing should:
catching it statically is the dependent step the whole survey refuses.

## §2 and §4 — a union discriminated by a value inside the binary

**One question, not two, and F9 was right to file §4 here.** Every discriminator in both exemplars
is a literal in a segment — `126:7`, `127:7`, `1:8`, `0xCE:8`, `60:16`. `Greet("hello")` is the same
construct with a string.

**The answer is that a segment's width refines its binding.** `t:8` yields `t : int where value >= 0
and value <= 255` — an `Octet`, by inference rather than declaration. Everything downstream of that
already exists and is measured: an `Octet` parameter accepts the value with no guard, and its
residual is computed over 256 values.

```csharp
DecodeFrame(<<t:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Classify(t, ch, payload), rest)
DecodeFrame(_) -> (:error, :incomplete)      // legal: a binary is always truncatable

private Frame Classify(Octet t, int ch, binary payload)
Classify(1, ch, p) -> ...
Classify(2, ch, p) -> ...
Classify(3, ch, p) -> ...
// forget AMQP's heartbeat and the compiler says:
//   error: Classify is not exhaustive
//     no clause matches:  Classify(0 | 4..255) -> ...
```

**The width closes the residual in both directions, and the upward half is the less obvious one.**
Without it, `t` is a bare `int`, and a bare `int` is *refused* into an `Octet` parameter — the
compiler demands clauses for `int <= -1 | int >= 256`, values a byte cannot hold. That is precisely
the residual 25c's probe 2 recorded and described as *"values the wire cannot produce"*, and it is
why 25c concluded the gap was **the signature's, not the checker's**. The width is what closes it,
and inferring it from the segment is what stops every wire function having to declare it by hand.

**The binary pattern does shape; a function head does value.** A `_` over a binary is always legal,
because a binary can always be too short — so it also absorbs any wire value left unhandled. The
compiler is not asked to see through that. Value dispatch belongs in a second head, where the
residual is computed.

This makes an idiom of the shape 25b flagged as a *smell* — *"`Opcode(op)` is a function call in a
clause body doing what the head should do."* Reversed deliberately: under this answer the head is
exactly where it should be, because the head is where exhaustiveness lives. **The price is real and
should be written into F13's docs** — write the tag dispatch inline in the binary patterns and the
checking is silently lost, with no diagnostic saying so.

## §3 — a surface spelling for a sized binary type

**It does not arise, and that is the answer rather than a deferral.**

The type language gains nothing, so there is no notation to borrow from Erlang or invent against it,
and F9's actual fear — *a pattern and a type that cannot be written in the same notation* — cannot
occur, because there is no type form to disagree with.

C# supplies the positive evidence. It is the only language measured that has **both** a sized
sequence type and a sequence pattern, and they cannot be used together: inline arrays put a length
in the type (`Buf4` and `Buf8` are distinct by `CS0029`, a constant out-of-range index is a compile
error) and list patterns refuse that type outright — `CS8985: List patterns may not be used for a
value of type 'Buf4'`. The length C#'s exhaustiveness checker uses comes from a runtime `Length`
property, never from the type. The one language that built both keeps them apart.

Ticket 20 §2's `<<_:M, _:_*N>>` is left where it is: a published algebra with no implementation and
now no consumer. Nothing is reopened, and there is no join to undo.

## §4 at the smallest scale — `Greet("hello")`

**Admit it.** A string literal in pattern position is a byte-string singleton, which is the same
construct §2 settles.

A `string`'s residual is **always open** — any non-empty binary part is unconditionally open — so a
catch-all is required and legal, and a set of string literals is never exhaustive on its own. That
matches Gleam exactly, which permits both `"GET" <> rest` and `<<"GET", _rest:bytes>>` and treats
neither as total without `_`.

*Caveat on the evidence:* this follows from reading the openness rule, not from a behavioural test.
No partial string match can be constructed until the pattern exists, so **F13 owes a test that a
catch-all over a set of string literals is accepted and not flagged as discarding cases.**

> **DISCHARGED BY F13, 2026-08-20.** `binary_tests` runs it in both directions — a set of literals
> with a catch-all is accepted, and the same set without one is `inexhaustive`. The reading was
> right, and it needed no new machinery: a string literal's pattern type is `string` held
> **inexactly**, which is the same `false` that makes `[0, ..t]` credit nothing. Gleam's other
> spelling came along for free — `<<"GET", rest>>` is a segment and matches a prefix, which the
> grammar admitted without anyone designing it, so it has a test and an example of its own.

---

## What F13 must build

| | |
|---|---|
| `<<…>>` in pattern position | New. `<<` is not a token today — maximal munch yields two `'<'` |
| A segment's width refines its binding | **The novel step.** `t:8` ⟹ `Octet` |
| `payload:size` — sized by an earlier binding | Runtime only; permitted by all four languages |
| A literal value in a segment — `0xCE:8`, `126:7` | §2's construct |
| String literals in pattern position | §4; needs the pattern production and a catch-all test |
| Interval patterns in **nested** position | Already diagnosed as unbuilt; **general**, not binary-specific |
| A residual renderer that keeps sub-position facts | Currently discards them; **general**, and a defect against ticket 23 |

The last two are the real cost and they are **not** binary work — closing them improves records and
tuples. 25c's coupling applies unchanged: **interval patterns and interval refinements must land in
the same increment**, or wire parsing gets harder than it is today rather than easier.

> **CORRECTED BY F13, 2026-08-20 — the last three rows of that table are wrong, and the cost
> estimate went stale exactly the way this ticket's own premises did.**
>
> **Neither "real cost" row was built and neither was needed.** The argument is this answer's own
> rule read one step further: *the binary pattern does shape; a function head does value* puts
> every residual F13 can produce at **whole-argument position** — where the renderer already prints
> legibly and where relational patterns have worked since F2. The sub-position discard is reached
> by destructuring a *record*; F13 destructures only binaries, and a binary's residual is
> unconditionally open, so a `_` is always required and there is no residual at a sub-position to
> render. Both remain real, general defects, now with nothing waiting on them.
>
> **And 25c's coupling had already been satisfied for four days when this answer repeated it.** It
> was written before there was any way to name a span, and 25b priced saying "reserved" over a
> 4-bit opcode at eleven clauses. Measured: `Classify(>= 4)` closes it in **one**, and a frame type
> takes five clauses rather than 252. Wire parsing does not get harder. **A price goes stale the
> same way a premise does, and only the premise has a habit that catches it.**
>
> **Three things F13 had to build that this table does not name.** `>>` may **not** become a token
> — `list<list<int>>` parses and runs, so the pattern closes on two separate `'>'`. And
> `payload:size` does not lex as three tokens: the atom sigil is `:name` and maximal munch prefers
> it, so it is the variable `payload` followed by the **atom** `:size`, while `payload:8` *is*
> three tokens. Both were fixed in the grammar rather than the lexer, because a lexer made
> context-sensitive to protect one construct puts the collision everywhere else instead. Third:
> **hex integer literals**, since the decided surface writes `0xCE:8` and `0xCE` did not lex.

## ⚠ This answer goes beyond every language surveyed, and that is the risk

**Nobody proves coverage over a sub-byte field.** C# does coverage properly — partitioning arity
against element value-space, and returning counterexamples in the pattern's own syntax — but its
elements are bytes or larger and it has no sub-byte concept at all. The BEAM three have the bits and
not the proof: Erlang does no exhaustiveness checking whatever; Elixir's set-theoretic machinery
exists and demonstrably does not reach binaries; Gleam has subsumption over bit arrays and refuses
coverage, even for a 1-bit tag with both values named.

Both exemplars are bit-packed in their first eight bits. RFC 6455's header is
`fin:1, 0:3, op:4, 1:1, len:7`. **So for the case that actually matters, the survey is unanimous
against this answer.**

Two things make it defensible rather than reckless. None of the four failed because it *tried and
found this unsound* — Erlang has no machinery to apply, Elixir has not extended what it has, Gleam
stopped deliberately at coverage. And the refinement machinery this rests on is built, and its
soundness was re-measured against a compiler four features newer than when it was first recorded:
a single-sided guard leaves exactly `int <= -1`, so each comparison is credited independently.

**If F13 finds this unsound or unaffordable, this is the decision to revisit first**, and the
revisit is cheap — nothing entered the type lattice, so backing out means dropping an inference,
not unwinding an algebra.

Survey with verbatim outputs: [`research/30-binary-grammar-prior-art.md`](../research/30-binary-grammar-prior-art.md).

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- **Binaries as a parsing grammar** — [ticket 30](issues/30-binaries-as-a-parsing-grammar.md),
  resolved 2026-08-20. Raised by the first exemplar to parse a real wire format, and answered
  against a survey of four languages, all compiled and run:
  [`research/30-binary-grammar-prior-art.md`](research/30-binary-grammar-prior-art.md).
  **A binary gets no structure in the type language. A segment's *width* becomes an interval
  refinement on the value it binds** — `t:8` is an `Octet` by inference — and that inference is the
  whole of what the ticket adds. Three refusals sit around it. Sizes stay **erased**: `payload:size`
  runs and `payload` is a `binary`, because relating two fields of one pattern is refused by every
  language measured, three of them with a dedicated diagnostic. **§3's sized-binary spelling never
  arises**, which retires F9's fear of a pattern and a type in disagreeing notations — C# is the
  positive evidence, being the one language with both a sized sequence type and a sequence pattern
  and unable to use them together. **String literals in pattern position are admitted**, with a
  catch-all always required because a `string`'s residual is always open.
  **The binary pattern does shape; a function head does value.** A `_` over a binary is always legal
  (it can always be truncated), so it also absorbs unhandled wire values — the compiler is not asked
  to see through that, which makes an idiom of the shape 25b filed as a smell. Writing the tag
  dispatch inline silently loses the checking, and F13 owes that warning in its docs.
  **The real cost is two general gaps, not binary work**: interval patterns in nested position, and
  a residual renderer that keeps sub-position facts. The coverage engine already decomposes into
  sub-positions and tracks field-level coverage — measured over records, two-of-three atom cases red
  and three-of-three green — but the renderer discards every field fact and prints only the record's
  name. 25c's coupling binds: interval patterns and interval refinements land in the same increment.
  **Flagged as a reversal risk.** Nobody proves coverage over a *sub-byte* field: C# does coverage
  properly but has no sub-byte concept, Erlang has no exhaustiveness checking at all, Elixir's
  machinery provably does not reach binaries, Gleam has subsumption and refuses coverage even for a
  1-bit tag with both values named. Both exemplars are bit-packed in their first eight bits, so for
  the case that matters the survey is unanimous against this answer. Defensible because none of the
  four failed by *trying and finding it unsound* — and cheap to reverse, since nothing entered the
  type lattice.
```
