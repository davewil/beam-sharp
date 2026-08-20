# 30 — Binaries as a parsing grammar, not as values on a boundary

Type: grilling
Status: claimed

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
