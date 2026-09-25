# 90 — Building a binary: `<<t:8, ch:16, size:32, p, 0xCE:8>>` in expression position

Type: grilling
Status: open — [ENG-431](https://linear.app/davewil/issue/ENG-431). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

Three exemplars write a binary out, and none can. F13 built binary **patterns** and said the
building direction had *"no decision behind it yet"*; ticket 30 decided the pattern grammar and
nothing about construction. Measured on `a0f9cbf`:

```csharp
// 25c encode.bs: an AMQP frame
private binary Wrap(int t, int channel, binary payload)
Wrap(t, ch, p) -> <<t:8, ch:16, :erlang.byte_size(p):32, p, 0xCE:8>>

// 25b encode.bs: the header's body is never written, because it would need this
Encode(op, payload) -> Header(op, ByteSize(payload)) |> Binary.Append(payload)

// 25e escape.bs: a byte written back through a foreign call, since `<<c:8>>` does not parse
Walk(<<c:8, rest>>, acc) -> Walk(rest, [:binary.encode_unsigned(c), ..acc])
```

`<<c:8>>` in an expression is `syntax error before: '<<'` today (`T90/t90.bs:4:12`). 25e routes
around it with a foreign call; 25c cannot, and 25b leaves `Header` unwritten: a length-prefixed
frame needs the payload measured before its first byte is written, so there is no accumulation
that avoids building one.

## Round 1

**Q1. Does `<<…>>` in expression position build a binary, with the same segment syntax a pattern
takes?**

```csharp
Wrap(t, ch, p) -> <<t:8, ch:16, :erlang.byte_size(p):32, p, 0xCE:8>>
```

Under yes this compiles, and `Wrap(1, 0, "ab")` is `<<1, 0, 0, 0, 0, 0, 2, 97, 98, 206>>`. The
empty binary is `<<>>` in both positions (25e wrote `<<"">>` because `<<>>` is a syntax error
today in a pattern too).

Compiler delta: `expr -> '<<' bin_elems '>>'` in `bs_parser.yrl`, reusing F13's segment rules
(`:N` size, `:_*N` unit, a bare trailing segment); a `type_of` clause giving `binary`, or `string`
when every segment is a string literal or a `string` (F56's reading, the other way); an
expression clause in `bs_emit` emitting `{bin, …}` as F13 already does for patterns. A size
expression is an `int` expression, checked as an argument is.

What the answer leaves open, for a later round: whether a segment's value is checked against its
width (`<<300:8>>` truncates silently on the BEAM).
