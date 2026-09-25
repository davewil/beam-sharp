# 93 — `Binary.Append` and `Binary.Size`: ticket 67's next reserved qualifier

Type: grilling
Status: open — [ENG-434](https://linear.app/davewil/issue/ENG-434). Raised 2026-09-25 by the exemplar review (ENG-191)
Blocked by: —

## Why this is raised

25b writes `Binary.Append` and `ByteSize`; 25c writes `ByteSize`. Ticket 67 reserved qualifiers
for the standard operations and said `Binary.Append` *"is not decided here"*; F32 built `List` and
`Term` only. Measured on `a0f9cbf`:

```csharp
// 25b encode.bs
Encode(op, payload) -> Header(op, ByteSize(payload)) |> Binary.Append(payload)
Fragments(chunks)   -> chunks |> List.Fold("", (acc, c) => Binary.Append(acc, c))
```

`error: Binary is called but never imported`, with the advice `add \`using Binary\``, which names
no module. The exemplars route around it with `using :erlang { int byte_size(binary b) }` and
`iolist_to_binary`.

## Round 1

**Q1. Is `Binary` a reserved qualifier, with `Append` and `Size`?**

```csharp
Encode(op, payload) -> Header(op, Binary.Size(payload)) |> Binary.Append(payload)
```

Under yes this compiles; `Binary.Append(binary, binary) -> binary`, and `string` when both are
`string` (the F56 reading); `Binary.Size(binary) -> int`, the byte count, inlined as
`erlang:byte_size/1`. Under no, the foreign declaration is the idiom and the advice stops naming
`using Binary`.

Compiler delta: `Binary` joins `bs_check:reserved_qualifiers()`; two entries in F32's signature
table; `Size` goes through `inlined_bif/1`, `Append` through a two-segment binary construction
(which does not need ticket 90: the emitter writes `{bin, …}` directly).
