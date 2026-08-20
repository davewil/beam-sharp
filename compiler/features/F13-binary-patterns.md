# F13 — Binary patterns: a width is a refinement

**Status**      **done 2026-08-20**
**Implements**  [ticket 30](../../wayfinder/issues/30-binaries-as-a-parsing-grammar.md), resolved
                2026-08-20 — decides nothing about the language, and the mechanism it does decide is
                listed below
**Unblocks**    [25b](../../wayfinder/prototypes/25b-websocket-handler.md) and
                [25c](../../wayfinder/prototypes/25c-event-queue-consumer.md), the two exemplars
                that parse a wire format; and it is the last row in the table
**Depends on**  F9 (`binary`/`string` as values, the literal, the boundary rule), F2 (relational
                patterns — and the dependency is load-bearing in a way nobody expected: see below),
                F3 (records, whose sub-position machinery this feature deliberately does *not* touch)

## Why this one now

It is the only row left. Every other feature with a file is done, ticket 30 was the decision the
queue starved on for four cycles, and it was resolved on 2026-08-20.

## Measured before this file was written, not assumed

Six probes against the compiler at `297eb2a`. Four of them moved this feature's scope, and two of
those contradict something a ticket in this repo currently asserts.

### 1. The whole downstream half of ticket 30's answer already runs

The answer's worked example was executed rather than read. Declaring the refinement by hand — which
is what a segment's width will infer — gives the diagnostic the ticket predicts, character for
character:

```csharp
type Octet = int where value >= 0 and value <= 255

public atom Classify(Octet t)
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
```
```
error: Classify is not exhaustive
  no clause matches:
    Classify(0 | 4..255) -> ...
```

And the **upward** half — the less obvious one the answer flags — also holds. A bare `int` handed to
an `Octet` parameter is refused with `int <= -1 | int >= 256`, exactly what
[25c](../../wayfinder/prototypes/25c-event-queue-consumer.md)'s probe 2 recorded and called *"values
the wire cannot produce"*.

**So the novel step is one inference and nothing else.** Everything it feeds already works. That is
the whole reason this feature is small.

### 2. 25c's coupling is already satisfied, and it was never re-measured

25c's finding 0 is carried forward by ticket 30's answer, by this file's README and by the map:
**"interval patterns and interval refinements must land together or the increment breaks wire
parsing."** The fear behind it is specific — the moment a field has a width, every wire dispatch
gets a *closed* residual, and 25b priced saying "reserved" over a 4-bit opcode at **eleven clauses**.

The escape hatch it demands landed in **F2 on 2026-08-16**, and it costs one clause:

```csharp
Classify(1) -> :method
Classify(2) -> :header
Classify(3) -> :body
Classify(>= 4) -> :reserved
Classify(0) -> :zero
```

Compiles, runs, `Classify(7)` is `:reserved`. Five clauses for a frame type, not 252 and not eleven.
The coupling was written before relational patterns existed and has been repeated ever since without
anyone running it. **Wire parsing does not get harder. It was already easier.**

### 3. The two rows ticket 30 called "the real cost" are not reached by this feature

Ticket 30's table ends with *nested interval patterns* and *a residual renderer that keeps
sub-position facts*, and names them the expensive half. Neither is in F13, and the reason is the
answer's own rule: **the binary pattern does shape; a function head does value.**

That rule puts every residual this feature can produce at **whole-argument position in a second
head** — where the renderer already prints legibly and where relational patterns already work. The
sub-position discard is reached by destructuring a *record* and leaving a field uncovered; F13 never
destructures anything but a binary, and a binary's residual is unconditionally open, so a `_` is
always required and always legal. There is no residual to render at a sub-position.

They remain real, general defects. They are not this feature's, and they are named in **Out of
scope** rather than dropped.

### 4. `list<list<int>>` parses today — so `>>` may not become a token

Ticket 30's table says *"`<<` is not a token today — maximal munch yields two `'<'`"*, which is
true and is only half the problem. It says nothing about the closing bracket, and the closing
bracket is the one with a live collision:

```csharp
public int Head(list<list<int>> xss)     // parses and runs, at 297eb2a
```

A `>>` rule in the lexer would swallow that, and the failure would be a syntax error in generic code
that has nothing to do with binaries. §1 below says what F13 does instead.

### 5. `0xCE` does not lex

The decided surface in `LANGUAGE.md` writes AMQP's sentinel as `0xCE:8`. The lexer has `{D}+` and no
hex rule, so `0xCE` is the integer `0` followed by the variable `xCE` and the parse dies. **Hex
integer literals are part of this feature**, and they are not in ticket 30's table either.

### 6. Both surfaces die at the parser, as the survey said

`First(<<a:8, rest>>)` is `syntax error before: '<'` and `Greet("hello")` is
`syntax error before: "hello"`. Nothing to unbuild.

## What is being built

```csharp
DecodeFrame(<<t:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Classify(t, ch, payload), rest)
DecodeFrame(_) -> (:error, :incomplete)

private Frame Classify(Octet t, int ch, binary payload)
Classify(1, ch, p) -> ...
```

`t` is an `Octet` because the segment said `8`, and nobody wrote a type. That single inference is
the feature; the exhaustiveness proof over it is machinery F2 and F9 already shipped.

## The six things this feature decides, all mechanism

Ticket 30 settled the behaviour. These are implementation, which a feature may decide.

### 1. `<<` becomes a token; `>>` does not. The pattern closes on two `'>'`

Measured in §4 above: a `>>` token breaks `list<list<int>>`. The grammar therefore matches
`'<<' segments '>' '>'`, and the lexer is left alone at the closing end — it already emits two
separate `'>'` tokens there, and both the generic close and the binary close go on getting them.

The asymmetry is deliberate and it is the cheaper half of the trade. It is safe in the opening
direction because **no existing form puts two `<` adjacent**: a generic's open bracket is always
preceded by a name (`list<`, `Result<`), so `list<list<int>>` lexes `list` `<` `list` `<` `int`
`>` `>` before and after this change. Erlang has the same collision and resolves it the same way
round; C# resolves the generic case in the parser because it has a `>>` *operator* to protect, and
this language has none.

**Yecc conflicts are measured, not inferred** — the count is checked with `yecc:file/2` on the
grammar before and after, and this feature holds the zero that F14 refused to spend.

### 2. An unsized segment is the remainder, and it must come last

`rest` in `<<t:8, ch:16, rest>>` binds everything left over, typed `binary`. This is the spelling
the decided surface already uses, and it diverges from Erlang, where a bare `<<A, B>>` is two
*bytes* and the remainder needs `Rest/binary`.

Taken deliberately: an unsized segment in a language with no default width has no other sensible
reading, and the alternative is a marker glyph that ticket 30 never decided and this feature may not
invent. An unsized segment anywhere but the final position is refused with a message naming the fix
(`give it a width, or move it to the end`) — a known-shape refusal, which is this repo's habit.

### 3. Hex integer literals, everywhere and not only in segments

`0xCE` is `206` in any integer position. Adding it only inside a binary pattern would make the lexer
context-sensitive for one construct's benefit, and would leave the language unable to write the
constant it is matching against anywhere else.

### 4. The width infers `range(0, 2^N - 1)`, not a named type

`bs_types:range/2` already exists and is what the inference produces. **No `Octet` is minted.** A
refinement is a subset of its base, so the inferred `range(0,255)` goes into a parameter declared
`Octet` without either side knowing the other's name, and the diagnostic renders through the
interval printer that produced `0 | 4..255` in §1.

This is what "nothing enters the type lattice" means concretely: `bin_part()` — the four-point set
on `{utf8, other}` — is untouched, and the only new fact lives in the *integer* part, which has had
intervals since ticket 20 §5.

### 5. A literal segment is a match, not a binding, and it may be sub-byte

`0xCE:8` and `126:7` match the value and bind nothing. `126:7` is the case that puts this feature
past every language surveyed, and it needs no special handling: the width still fixes the segment's
size, the literal still has to fit it, and a literal too wide for its width is a compile error
naming both numbers.

### 6. A string literal in pattern position is a byte-string singleton

`Greet("hello")` reuses the `string_lit` token F9 already lexes, in a new pattern production. The
residual of a `string` is unconditionally open — any non-empty binary part is — so a catch-all is
required and legal, and a set of string literals is never exhaustive on its own. Ticket 30 §4 flags
that this follows from *reading* the openness rule and was never behaviourally tested, and it owes a
test in both directions. F13.9 and F13.10 are that test.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F13.1 | `First(<<a:8, rest>>) -> a` | `bsc … First "<<7,8,9>>"` | `7` | 0 |
| F13.2 | `t:8` bound, then handed to an `Octet` parameter with no guard | `bsc …` | compiles — the width is what makes the call legal | 0 |
| F13.3 | tag dispatch in a second head, cases 1–3 of an inferred octet | `bsc` it | `no clause matches: Classify(0 \| 4..255)` | 1 |
| F13.4 | `op:4`, RFC 6455's opcodes, reserved ranges omitted | `bsc` it | `Op(3..7 \| 11..15)` — the sub-byte proof | 1 |
| F13.5 | `payload:size` sized by an earlier binding | `bsc …` | runs; `payload` is `binary` and its length is erased | 0 |
| F13.6 | `0xCE:8` sentinel present, then a frame where it is wrong | `bsc …` | the good frame decodes, the bad one falls to `DecodeFrame(_)` | 0 |
| F13.7 | `0xCE` in ordinary expression position | `bsc … Hex` | `206` | 0 |
| F13.8 | `Greet("hello") -> :hi` / `Greet(s) -> :other` | `bsc …` twice | `:hi` and `:other` | 0 |
| F13.9 | a set of string literals **with** a catch-all | `bsc` it | accepted, and **not** reported as discarding cases — 30 §4's owed test | 0 |
| F13.10 | the same set **without** a catch-all | `bsc` it | not exhaustive | 1 |
| F13.11 | `list<list<int>>` and a binary pattern in one file | `bsc` it; `yecc:file/2` | both parse; **zero** grammar conflicts | 0 |
| F13.12 | an unsized segment in non-final position | `bsc` it | refused, message names the fix | 1 |
| F13.13 | a literal wider than its segment (`300:8`) | `bsc` it | refused, message names both numbers | 1 |
| F13.14 | `examples/` gains a decoder; probe roster rows; `check-tokens.sh` knows `<<` | `rebar3 eunit`, all gates | green | 0 |

## Out of scope

- **Nested interval patterns.** Ticket 30's table lists them and §3 above measures that no F13
  scenario reaches them. They stay a general gap against records and tuples, already diagnosed with
  a message that names the guard workaround.
- **A residual renderer that carries sub-position facts.** Same argument, same evidence: F13 puts
  every residual at whole-argument position by design. It remains a defect against ticket 23 and it
  is somebody's next feature, not this one's.
- **The 41-interval residual.** 25c's finding 1 — a residual that is exact and unreadable — is a
  *legibility* decision belonging to tickets 23, 04 and 20. F13's own residuals are two and three
  intervals wide (`0 | 4..255`, `3..7 | 11..15`) and stay legible. A feature may not decide, and
  this one does not.
- **A sized binary type.** Ticket 30 §3 answered that it does not arise. `binary<32>` and
  `type Header = <<_:32>>` are not coming, and ticket 20 §2's `<<_:M, _:_*N>>` algebra is left where
  it is — published, unimplemented, and now with no consumer.
- **Relating two fields of one pattern.** `payload:size` runs and the dependency is erased. AMQP's
  trailing sentinel stays a runtime check, which 25c calls *"the check that matters most"* — catching
  it statically is the dependent step the whole survey refuses.
- **Binary construction.** This feature is the *consuming* direction, which is ticket 30's stated
  scope. Building a binary from parts has no decision behind it yet.
- **String operations.** `LANGUAGE.md` puts them behind the module system, not here.

## Done when

`DecodeFrame(<<t:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)` parses, runs and erases the size;
`t` reaches an `Octet` parameter with no guard and no declaration; omitting a tag case names the
residual `0 | 4..255` and omitting an opcode range names `3..7 | 11..15`; `Greet("hello")` runs and
its catch-all is neither required-and-missing nor accepted-and-flagged; `list<list<int>>` still
parses and yecc still reports zero conflicts; all fourteen scenarios hold; `LANGUAGE.md`'s two
`not-yet` blocks compile; `examples/` demonstrates a decoder and the probe roster has a row for each
new surface form; and every CI gate is green **twice from a clean checkout**.
