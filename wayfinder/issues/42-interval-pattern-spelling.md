# 42 — How is a span of integers named in a clause head?

Status: resolved 2026-08-15 — a span is a relational pattern; `4..7` refused
Raised by: F2 (`compiler/features/F2-interval-refinements.md`, scenario F2.3)
Blocks: F2
Type: `wayfinder:grilling`

## Question

A clause head can name one integer (`Classify(1) -> :method`). It cannot name a **span**. Once
`type Octet = int where value >= 0 && value <= 255` lands, spans stop being a convenience and
become the only way to write a legal program — so this ticket settles how one is spelled.

## Why this is forced rather than nice to have

Ticket 12 §2 makes a catch-all over a **closed** residual an error. Today a parameter declared
`int` has an **open** residual, so a wire dispatch gets its `_` for free. Measured against the
skeleton by [`25c_residual_probe.sh`](../prototypes/25c_residual_probe.sh):

- four named frame types over a bare `int` → residual `int <= 0 | 4..7 | int >= 9` — **open**;
- the same plus a guard bounding the octet to `0..255` → residual `int <= -1 | int >= 256`,
  values the wire cannot produce, **still open**.

The moment the refinement lands, that residual **closes** — 252 unnamed values for an AMQP frame
type, ~2³² for a class/method pair — and the `_` that used to discharge it becomes an error. So
F2 cannot ship the refinement without shipping a way to name the span, or it turns working
programs into rejected ones. That coupling is recorded in 25c and is why F2 is one feature and
not two.

**This is the residual arriving as a bill.** Ticket 04's finding — the residual *is* the missing
case — is what makes exhaustiveness useful; here it is what makes the language unwritable without
a span pattern. The compiler is about to hand an agent 252 cases and no syntax to answer with.

## What is already established

- **The `..` token is available and costs nothing.** Ticket 28 §5 measured it in
  [`28b_dot_dot_lexing.escript`](../prototypes/28b_dot_dot_lexing.escript): `..` ordered before `.`
  lexes `o.Status..t` cleanly as `o . Status .. t`, and `1..5` lexes as `1 .. 5` rather than
  `1.` `.5`.
- **It places one obligation on a decision not yet made.** That result holds *because* 28b's float
  rule demands digits on both sides (`{D}+\.{D}+`). A float spelled `{D}+\.` — a trailing dot, as
  Pascal allowed — would swallow the first dot and the collision would be real. Erlang's own lexer
  already requires both sides (`1.0` legal, `1.` not), so honouring it costs nothing, but whoever
  settles float literals inherits the obligation.
- **There are no relational patterns.** F7 recorded that `{ Total: > 100 }` is a C# relational
  pattern *"which this grammar does not have"*. So the C# pattern-position answer to this question
  is not currently available, and adopting it is a larger change than adopting a range token.
- **Guards already work.** `Classify(n) when n >= 4 && n <= 7` parses and checks today. The
  question is not whether spans are expressible — they are — but whether they are expressible in
  a form the compiler can read *back* as an interval, and whether ticket 23 §2's synthesised head
  can emit one.

## The three shapes, as code

### A — a range pattern

```csharp
Classify(4..7)   -> :reserved
Classify(9..255) -> :reserved
```

### B — a range test in a guard, with membership

```csharp
Classify(n) when n in 4..7   -> :reserved
Classify(n) when n in 9..255 -> :reserved
```

### C — no new syntax; you name a refined type

```csharp
type Reserved = int where (value >= 4 && value <= 7) || (value >= 9 && value <= 255)

Classify(Reserved r) -> :reserved
```

C is the only one that needs **nothing new** — F2.1 already ships type-position refinements, and
26's tag mint already makes the type nameable. It is here as the null option precisely because a
decision that adds no syntax deserves to lose on its merits rather than by being unstated.

## The false friend, which is the actual difficulty

**`4..7` is a tier-1 borrow whose C# meaning is wrong here.** C#'s `..` builds a `System.Range`
and it is **half-open**: `a[1..4]` yields elements 1, 2 and 3. Elixir's `4..7` is **inclusive** and
yields 4, 5, 6 and 7. The spelling this language would take from C# carries the arithmetic this
language would take from the BEAM, and the two disagree by one at the top end.

A wire dispatch is exactly where that costs something: `9..255` inclusive covers the octet;
`9..255` half-open leaves 255 unnamed, the residual stays closed, and the compiler rejects a
program its author believes is total. The failure is **loud** — that is the one mercy — because
exhaustiveness catches it at the definition rather than at runtime.

This is the shape the map's own amendment already models: `behaviour` beat C#'s `interface` because
the tier-1 borrow carried vocabulary the construct did not belong to. Here the tier-1 borrow carries
**semantics** the construct does not want. The heuristic says survey all three tiers and take the
most accurate word, not take the highest tier that fits.

## What each shape costs the compiler

| | lexer | parser | checker | 23 §2 head synthesis |
|---|---|---|---|---|
| **A** `4..7` | `..` token (28b, done) | new pattern form | `p_range` → interval directly; no guard translation | emits `4..7` — one clause per residual interval |
| **B** `n in 4..7` | `..` token, `in` keyword | new guard operator | must recognise `in` as an interval, not an opaque predicate, or the refinement is lost | emits `n when n in 4..7` |
| **C** named type | nothing | nothing | already works | emits `Reserved r`, but **only if a matching type exists** — otherwise it has no name to offer |

The last column is the one that is easy to miss. Ticket 23 §2 makes the compiler synthesise the
head from the residual, and *"where the residual is not guard-expressible the term says so and
offers nothing"*. Under C the residual is always interval-expressible but rarely **name**-expressible
— the compiler would have to either invent a type name or fall back to a shape C does not otherwise
permit. A spelling that the compiler cannot emit is a spelling that breaks the interlocutor.

## What this ticket owes

1. The spelling, and whether the interval is inclusive at both ends.
2. If `..` is taken: a line for the spec stating the divergence from C#'s half-open range, per
   tier 3's "diverge deliberately, and say so".
3. Confirmation that ticket 23 §2's synthesised head emits the chosen form — since the residual is
   a set of intervals, and this is the syntax it must lower to.
4. Whether the float-literal obligation from 28 §5 is now discharged here or stays owed.

## Answer

**Resolved 2026-08-15. A span is a relational pattern. `..` is not used for it, and keeps the one
meaning it already has.**

```csharp
Classify(1)              -> :method
Classify(2)              -> :header
Classify(3)              -> :body
Classify(8)              -> :heartbeat
Classify(0)              -> :reserved
Classify(>= 4 and <= 7)  -> :reserved
Classify(>= 9)           -> :reserved
```

emitting

```erlang
-spec classify(0..255) -> frame_type().
classify(1) -> method;
classify(2) -> header;
classify(3) -> body;
classify(8) -> heartbeat;
classify(0) -> reserved;
classify(N) when N >= 4, N =< 7 -> reserved;
classify(N) when N >= 9 -> reserved.
```

### The question was built on a false premise, and measuring dissolved it

This ticket asked whether `4..7` should be inclusive or half-open. **Neither: C#'s `..` does not
denote a set of integers at all.** Measured on dotnet 9.0.306
([`42a_csharp_range_probe`](../prototypes/42a_csharp_range_probe/Program.cs)):

```
a[4..7]        = [4, 5, 6]
(4..7).Start   = 4   .End = 7
offset/length  = 4 / 3

foreach (var v in 4..7)
→ error CS1579: 'Range' does not contain a public definition for 'GetEnumerator'
```

A `System.Range` is a **slice specification over indices**. It is not enumerable, and
`GetOffsetAndLength` needs a collection length before it means anything — so it has no existence
independent of a thing to index into. "Does `4..7` include 7" is a question the construct cannot
answer, because it contains no numbers.

**C#'s actual numeric-span construct is the relational pattern**, and it is inclusive at both ends:

```
Classify(7)    = reserved   (relational: 7 IS included)
Classify(255)  = reserved   (relational: 255 IS included)
```

**And in *pattern* position C#'s `..` already means "the rest"** — `[var first, .. var rest]` —
which is exactly what beam-sharp shipped in 28 §5 and runs today in
[`fib.bs`](../../compiler/examples/fib.bs): `Reverse([x, ..rest], acc)`.

So `4..7` was never a tier-1 borrow. It was tier 3 wearing tier 1's clothes: a construct C# does
not have, spelled with a glyph C# uses for two other things, one of which this language has already
taken. Taking it would have put one token on two unrelated jobs in the same position — and made
`[1..3]` ambiguous to a reader even where a parser could cope.

### Why this is the least-surprising answer rather than merely the C# one

David's standing rule is *"match C# if there's a choice"*, for familiarity and least surprise, with
deviation permitted where the BEAM is better served. **Here the rule needed no trade-off, because
the familiar-looking option was the surprising one.**

There are two costs a construct can impose on a reader: *"I must be taught this"*, which is paid
once; and *"I read this fluently and wrongly"*, which is never paid because the reader never stops.
A glyph borrowed **without** its semantics converts the first into the second — it spends the
reader's fluency against them. `4..7` reads on sight and reads wrong, so it fails the map's own test
(*"a construct a C# developer reads on sight, versus one they must be taught"*) in a way that test
cannot see. That is the sharpening this ticket contributes, and it belongs in the heuristic:

> **Borrow the construct, or don't borrow the glyph.** Where C# has the symbol but not the
> construct, taking the symbol buys no familiarity and costs a false friend.

`as` (map Notes) was the first instance of this and was handled ad hoc; `..` is the second. The
condition is not *"C# lacks this construct"* — `|>` and `->` are absent from C# and confuse nobody —
but ***"C# has this glyph, meaning something adjacent"***.

### The combinator is `and` / `or`, not `&&` / `||`

Ticket 08 chose `&&`/`||` for guards over Erlang's `,`/`;`. C# uses the **keywords** `and`/`or`
inside patterns precisely so a pattern combinator cannot be confused with the boolean operator on
expressions, and beam-sharp inherits that distinction along with the construct:

```csharp
Classify(>= 4 and <= 7)          -> :reserved   // pattern position
Classify(n) when n >= 4 && n < 8 -> :reserved   // guard position, same meaning
```

Taken by applying David's rule rather than on independent grounds — and it was in fact the piece
that got overruled, within the hour.

**The split above is provisional.** David, the same session: *"For ticket 8, I think with more info,
and/or would probably sit better"* — i.e. guards should move to `and`/`or` too, leaving one spelling
rather than two. That is a change to a **shipped** surface (`math.bs`, CI-gated `LANGUAGE.md`, and
the refinement predicate F2's own scenarios use), and it amends a closed ticket, so it is
[ticket 44](44-conjunction-spelling.md) rather than a line here.

**What this ticket fixes regardless of 44's outcome** is the *pattern* combinator: `and` / `or`,
because that is the construct C# supplies and 42 is taking the construct whole. If 44 lands, the
distinction disappears and the language has one conjunction; if it does not, the C# split stands as
written above. Neither outcome changes the relational pattern itself.

### What the compiler gains

- **Lexer**: two keyword rules. **Corrected 2026-08-15** — the first draft of this table said
  *"nothing, no new token"*, which was asserted without reading `src/bs_lexer.xrl` and is wrong.
  Measured: `&&` and `||` are lexed as tokens (lines 112–113); **`and` and `or` are not reserved**,
  so today they lex as ordinary lowercase identifiers. Making them keywords is a real lexer change
  and it removes both from the variable namespace — a parameter named `and` becomes illegal. Small,
  but it is a cost, and the table understated it.
- **Parser**: a relational pattern form (`p_rel(Op, Literal)`) and `p_and` / `p_or` combinators.
- **Checker**: each relational lowers to an interval the algebra already has (`>= 4` → `int >= 4`);
  `and` is intersection and `or` is union, both already implemented. No new theory, which was
  F2's claim for itself and survives intact.
- **Emitter**: `when N >= 4, N =< 7`. Identical to what a guard would have produced, so nothing
  downstream changes.

**It pays a debt.** F7 recorded `{ Total: > 100, Status: :open }` as *"a C# relational pattern,
which this grammar does not have"*. This is that construct. Whether it nests inside record patterns
immediately is a scope call for F2 rather than a further decision.

**And it improves ticket 23 §2.** That section measured the skeleton rendering `Classify(int <= -1)`
where the real head was `Classify(n) when n <= -1`. With relational patterns the synthesised head is
`Classify(<= -1)` — no binder, no guard, and shorter than the form 23 anticipated. An interval
residual now lowers to a pattern rather than to a pattern *plus* a guard.

### The float-literal obligation from 28 §5

**Retained, and now unreachable rather than load-bearing.** `..` stays in the grammar for list rest,
but it is always preceded by a comma (`[x, ..rest]`, `[f(h), ..Map(t, f)]`), so no valid program
juxtaposes an integer literal with it and the `1..5` collision cannot arise from source a user would
write. Keep the both-sides-digits float rule anyway: it matches Erlang (`1.0` legal, `1.` not),
costs nothing, and the obligation is cheaper to honour than to re-derive.

### What this unblocks and what it does not

F2 loses one of its two blockers. It remains blocked on
[ticket 43](43-residual-summarised-form.md) ([ENG-213](https://linear.app/davewil/issue/ENG-213)).
