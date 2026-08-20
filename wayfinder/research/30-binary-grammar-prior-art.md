# 30 — What four languages actually prove about binaries as a parsing grammar

Measured 2026-08-20 for [ticket 30](../issues/30-binaries-as-a-parsing-grammar.md), which asks
what a binary type does when the binary is a **grammar consumed left to right** rather than a value
arriving at a boundary.

**Everything here was compiled and run.** No claim below rests on documentation or recollection.
Versions: Erlang/OTP 28 (erts-16.4, jit) · Elixir 1.19.5 · Gleam 1.18.1 · .NET SDK 9.0.306,
C# language version 13.0 (pinned by a `#error version` probe, `CS8304`). C# 14 was **not measured** —
no .NET 10 SDK is installed.

Probe sources were written to a scratch tree that does not survive the session; the verbatim
outputs are reproduced here, which is why this file is long. Where a compiler emits a numbered
diagnostic the number is quoted, so a later reader can re-find the behaviour without the sources.

---

## The one-line answer

**No language in the survey can prove clause coverage over a binary discriminated by a value inside
it, and none can relate two fields of one pattern.** They fail for four different reasons, and the
differences matter more than the agreement.

| | value discrimination inside the binary | relate two fields | coverage over binary patterns | sub-byte fields |
|---|---|---|---|---|
| **Erlang** | no — erased to `nonempty_binary()` | no — `bad binary type` | **no exhaustiveness checking at all** | yes, runtime only |
| **Elixir** | no — machinery exists, does not reach binaries | no — rejected by the typespec grammar | no | yes, runtime only |
| **Gleam** | no | no — dependency erased at the binding | **subsumption yes, coverage no** | yes, and *shape* coverage is sound |
| **C#** | **yes, for byte-or-larger elements** | no — `CS9135` | **yes**, arity × element value-space | **no such concept** |

C# is the outlier and the reason this survey does not read as unanimous. But its list patterns
operate on sequences with a `Length`, so its elements are bytes or larger, and **nobody in the
survey does coverage over a sub-byte field** — which is what both of ticket 25's wire exemplars
actually need. RFC 6455's header is `fin:1, 0:3, op:4, 1:1, len:7`.

---

## 1. Erlang — no exhaustiveness to extend

**Runtime is fully general.** A segment sized by a variable bound earlier in the same pattern
compiles and runs:

```erlang
decode(<<Size:32, Payload:Size/binary, Rest/binary>>) -> {Payload, Rest}.
```
```
input   = <<0,0,0,3,97,98,99,116,97,105,108,45,114,101,115,116>>
decode  = {<<"abc">>,<<"tail-rest">>}
```

Binding is strictly left-to-right — a forward reference is a compile error, not a constraint to
solve:

```
e1b.erl:5:15: variable 'Size' is unbound
%    5| fwd(<<Payload:Size/binary, Size:32>>) -> Payload.
```

**The compiler does no exhaustiveness checking whatever.** Two binary clauses, no catch-all,
`erlc +debug_info +warnings_as_errors` — exit 0, no output. The control matters: the same flags over
two *atom* clauses also exit 0, so this is not a binary-specific omission. Uncovered input is a
runtime error only:

```
tag(<<1,9,9>>) = {one,<<"\t\t">>}
tag(<<3,9,9>>) = RAISED error:function_clause
tag(<<>>)      = RAISED error:function_clause
```

**Dialyzer erases the discriminator.** Forcing it to print its inference for a leading-literal
clause:

```
The success typing is e5b:only_ping
         (nonempty_binary()) -> 'ok'
```

The byte `1` in `only_ping(<<1:8, _/binary>>)` is gone, so feeding a pong to a ping-only function
passes clean: `dialyzer --plt ./survey.plt e5.beam` → `done (passed successfully)`.

**Sizes are spellable and enforced only where statically visible.** Across four call sites against
`-spec header(<<_:32>>) -> ok.`, Dialyzer emitted exactly one warning:

```
e2.erl:8:25: The call e2:header
         (<<1,2,3>>) breaks the contract
          (<<_:32>>) -> 'ok'
```

Silent on both of the load-bearing ones:

```erlang
takes_unknown(B) when is_binary(B) -> header(B).      % binary() into <<_:32>> -- NO WARNING
takes_derived() -> header(binary:copy(<<1,2>>, 2)).   % 32 bits via a call -- NO WARNING
```

This is not a subtype check. Success typing warns only on a provably empty intersection, and
`binary() ∩ <<_:32>> ≠ ∅`, so any value whose size the analyser cannot see flows in unchallenged.

**Relating two fields is refused at every route**, including `when` constraints, which otherwise
work — `-spec decode(...) -> {P, R} when P :: binary(), R :: binary().` compiles, and:

```
e7b.erl:6:42: bad binary type
%    6|     when Size :: non_neg_integer(), P :: <<_:Size>>, R :: binary().
```

What the type language holds, from Dialyzer's own inference on the variable-sized decoder:
`(<<_:32, _:_*8>>) -> {binary(), binary()}` — a lower bound and a stride going in, and the
relationship erased coming out.

---

## 2. Elixir — the machinery exists and does not reach binaries

This is the sharpest result in the survey, because it is a **controlled** one: both halves in one
module, one compile, so "the checker was not looking" is ruled out.

```elixir
def tag(<<1::8, r::binary>>), do: {:one, r}     # binary clauses
def tag(<<2::8, r::binary>>), do: {:two, r}
def call_uncovered, do: tag(<<3::8, 9::8>>)     # matches neither -> SILENT

def atag(:a), do: 1                              # atom clauses
def atag(:b), do: 2
def call_uncovered_atom, do: atag(:c)            # -> WARNS
```

`elixirc -o . x3.ex` reports exactly one warning, on the atom case:

```
warning: incompatible types given to atag/1:
    atag(:c)
given types:
    -:c-
but expected one of:
    #1
    dynamic(:a)
    #2
    dynamic(:b)
```

Atom clauses get a real per-clause domain union. The binary clauses get nothing — not the uncovered
tag byte, not even the empty binary.

**Sizes are not tracked at all.** Positive control first, to prove the checker is on:
`Integer.to_string(:a)` warns `expected one of: integer()`. Then, both calls local, one compile:

```elixir
def header(<<_::32>>), do: :ok
def wrong_type, do: header(:not_a_binary)   # WARNS
def wrong_size, do: header(<<1, 2, 3>>)     # 24 bits vs 32 -- SILENT
```

and the expected type prints as **`binary()`** — atomic, no size. The pattern `<<_::32>>`
contributes nothing. The missed case is a genuine error: it raises `FunctionClauseError` at runtime.

**`@spec` and the new inference are two unrelated systems.** `@spec header(<<_::32>>) :: :ok` with
`header(<<1,2,3>>)` compiles clean under `elixirc`; the same beam under Dialyzer reports
`breaks the contract`. The set-theoretic checker ignores the spec.

**The typespec grammar enumerates itself when rejecting a dependent size:**

```
** (Kernel.TypespecError) x5.ex:3: invalid binary specification, expected <<_::size>>,
<<_::_*unit>>, or <<_::size, _::_*unit>> with size being non-negative integers,
and unit being an integer between 1 and 256
```

Three forms, sizes are integer literals, there is no fourth.

**An inversion worth knowing:** on the same module Dialyzer caught `tag(<<>>)` via
`nonempty_binary()` and the atom union, while `elixirc` caught only the atom case — the newer
checker is *less* precise about binaries than the older one.

---

## 3. Gleam — subsumption without coverage, and sound about the difference

The closest comparator: statically typed, on the BEAM, with exhaustiveness checking built on the
same pattern-match compilation algorithm this effort's own checker rests on.

The probe harness was self-tested before any negative result was trusted — a one-clause match over
a two-variant type produced `error: Inexhaustive patterns` and exit 1, the two-clause version exit
0, and the red re-ran byte-identical. So "Gleam said nothing" below is a measurement, not a cache
artefact.

**Variable-sized segments work, and the dependency is erased.**

```gleam
<<size:int-size(32), payload:bytes-size(size), rest:bytes>>
```

compiles, and parses for real — a length-3 frame slices correctly, a declared length of 9 overruns
to the catch-all. Forcing the bindings into `fn want_int(x: Int)`:

```
error: Type mismatch
10 │       want_int(size) + want_int(payload) + want_int(rest)
   │                                 ^^^^^^^
Expected type:    Int
Found type:    BitArray
```

`size` raises no error and is `Int`; `payload` and `rest` are plain `BitArray`. Gleam checks the
size expression is an `Int` in scope, then types the result as an unadorned `BitArray`. Nothing
records that `payload` is `size` long. Scoping is strictly left-to-right, same as Erlang.

**No size-carrying type.** `BitArray(32)` is a *parse* error — `BitArray` is nullary. A
`bytes-size(4)` binding and the literal `<<1>>` pass through the same `BitArray` parameter, exit 0.

**Subsumption — the redundancy half — works.**

```
warning: Unreachable pattern
7 │     <<1, _rest:bytes>> -> 10
This pattern cannot be reached as a previous pattern matches the same values.
```

and `<<_:bits>>` sits at the top of that lattice, making any following bit-array pattern
unreachable. It reaches string prefixes too: `"GET /" <> rest` after `"GET" <> rest` warns.

**Coverage — the other half — is refused, and refused even where it is finite and tiny.** All of
these fail with `The missing patterns are: _`:

- three literal-tag clauses `<<1,…>>` / `<<2,…>>` / `<<3,…>>`
- `<<>>` plus `<<_first, _rest:bytes>>` — total over byte-aligned input
- `<<0:1,_:bits>>` + `<<1:1,_:bits>>` + `<<>>` — **a 1-bit tag has exactly two values, so this
  covers every bit array**

The only accepted no-catch-all case is `<<_:bits>>` alone. So the rule is not "mandatory catch-all";
it is "one pattern must subsume the whole type."

**And Gleam is sound about shape**, which is the most useful single fact in this file: `<<_:bytes>>`
alone is **rejected**, because a non-byte-aligned bit array escapes it, while `<<_:bits>>` is
accepted. Gleam has exactly the size dimension this effort's type representation lacks, uses it for
the one judgement it can make soundly, and declines the rest.

**String literals in pattern position are allowed** — bare (`"GET" <> rest`) and inside a bit array,
both `<<"GET", _rest:bytes>>` and `<<"GET":utf8, _rest:bytes>>`. Never exhaustive without `_`,
because `String` is open.

---

## 4. C# — the one that does coverage, and the two things it cannot do

C# 13 list patterns. The slice is `..` and binding it is `.. var rest`; the binding carries the
*slice* type, not the element type (`int[]` for an array, `ReadOnlySpan<byte>` for a span).

```csharp
[.. [_, _, 0xFF]]        // a sub-pattern applied to the slice, not just a binding
[_, .. { Length: 3 }]    // constant length constraint on the slice
[_, .. { Length: 3 } r]  // constrained AND bound
[0x02, .., 0xFF]         // slice in the middle
[.. var head, 0xFF]      // slice at the front
```

Exactly one slice per pattern: `CS8980: Slice patterns may only be used once and directly inside a
list pattern.` That restriction is what keeps matching linear and decidable, and it is the same
reason Erlang binary patterns need a size on all but the last segment.

**Coverage is real, and it composes arity with element value-space.** Accepted with zero
diagnostics and no discard arm: `[]` / `[0, ..]` / `[not 0]` / `[not 0, _, ..]` over `byte[]` — a
value split at position 0 intersected with an arity split further along. Also clean: `[]` /
`[true, ..]` / `[false, ..]` over `bool[]`. Dropping an arm warns, **with the counterexample written
in the pattern's own syntax**:

```
warning CS8509: ... For example, the pattern '[false]' is not covered.
warning CS8524: ... For example, the pattern '[(Tag)2]' is not covered.
warning CS8509: ... For example, the pattern '{ Length: 0 }' is not covered.
```

So the decision DAG genuinely partitions arity × value-space rather than testing length alone.
**This is the borrowable mechanism**, and the counterexample-in-surface-syntax is the part worth
taking: it is what ticket 23's residual-as-a-thing-an-agent-writes actually wants.

**Length-as-property and length-as-arity are one fact to the checker.** `{ Length: 4 }` and
`[_, _, _, _]` are proved equivalent in both orders — the second is `CS8510: The pattern is
unreachable`. A new language should decide deliberately whether it wants two spellings for one
thing.

**Two things C# cannot do, and both are decisive here.**

*It cannot relate two parts of one input.* Four spellings, all rejected:

```
error CS9135: A constant value of type 'int' is expected     // [var n, .. { Length: n }]
error CS9135: A constant value of type 'int' is expected     // [var n, n]
error CS1525: Invalid expression term '=='                   // [var n, .. { Length: == n }]
error CS9135: A constant value of type 'int' is expected     // { Length: var len } and [len, ..]
```

Repeating a binding name does **not** mean "equal to the earlier one" — the second `n` parses as a
constant pattern. A `when` guard is the only route, and C# has a dedicated diagnostic saying the
guard is invisible to the checker:

```
warning CS8846: ... it is not exhaustive. For example, the pattern '{ Length: 1 }' is not covered.
However, a pattern with a 'when' clause might successfully match this value.
```

*The sized type and the sequence pattern never meet.* Inline arrays are the one place a length
reaches C#'s type system — `[InlineArray(4)] struct Buf4 { byte _e; }` makes `Buf4` and `Buf8`
distinct types (`CS0029`) and a **constant** out-of-range index a compile error (`CS9166`). A
variable index is not checked, and:

```
error CS1061: 'Buf4' does not contain a definition for 'Length'
error CS8985: List patterns may not be used for a value of type 'Buf4'.
```

The length the exhaustiveness checker uses comes from a runtime `Length` property, never from the
type. `Span<byte>` carries no length in its type at all — a 2-length span assigns to a 6-length one.
`fixed byte Data[4]` gives distinct types with **no** bounds checking whatever (`f.Data[7]`
compiled and ran). Nothing in `System.Buffers` is sized — all 16 public types enumerated.

**Two cautions measured, both worth carrying.** UTF-8 literals are *not* constant patterns —
`s is "GET"u8` is `CS9135`, while the `ReadOnlySpan<char>` equivalent `c2 is "GET"` works. A
byte-oriented language must make byte-string literals patternable, which C# has not. And C#'s
totality is not sound: a switch the compiler accepts as exhaustive throws
`SwitchExpressionException` on null, silently under `Nullable disable`. Exhaustiveness diagnostics
exist only for switch *expressions* — a non-exhaustive switch statement or `is` pattern produces
nothing.

---

## 5. What `bsc` itself does today — measured in the same session

Four surface forms, all failing at the **parser** rather than the checker, so none of this syntax
exists in any form:

```
Greet("hello")          -> syntax error before "hello"
<<fin:1, rsv:3, ...>>   -> syntax error before '<'      (`<<` is not a token; two `'<'` by munch)
type Header = binary<32>-> syntax error before 32       (no type production derives an integer)
```

The binary type is a four-point lattice on `{utf8, other}` with **no size dimension anywhere**, and
ticket 20's size grammar is implemented nowhere. Binaries pass through three one-line ordset calls
inside the generic componentwise operators; nothing compares sizes. Any non-empty binary part is
unconditionally **open**, which is a single line and is what a size partition would have to touch.

### The finding that decides how expensive a value-discriminated answer is

The checker **does** decompose into sub-positions and track field-level coverage — but its
**residual renderer discards every field-level fact**. Measured with records, which give
sub-position destructuring today without needing binary syntax:

```
    one refined int field, 2 of 256 covered
    -> Classify({ Kind: :'Sub1.Hdr' }) -> ...

    two refined int fields
    -> Classify({ Kind: :'Sub2.Hdr' } | { Kind: :'Sub2.Hdr' } | { Kind: :'Sub2.Hdr' }) -> ...

    one ATOM field, :c uncovered           (union machinery certainly works at top level)
    -> Classify({ Kind: :'Sub3.Hdr' }) -> ...

    the same with :c covered
    -> exit 0, green
```

Three consequences, and the second is the one that sizes the work:

- **Soundness holds; precision is lost in the printing.** The engine knows `:c` is missing (red) and
  knows when it is not (green). The diagnostic just will not say so. Two-field decomposition
  produces three disjuncts that all render identically, which is also a legibility defect in its
  own right — three terms a reader cannot tell apart.
- **So a value-discriminated binary answer does not need a new coverage engine**; it needs the
  residual renderer to carry sub-position facts. That is a smaller delta than "new machinery" and a
  larger one than "reuses what exists".
- **Interval patterns do not work in nested position**, which is known and diagnosed:

```
error: a relational pattern goes where a whole argument goes
  `Classify(>= 4 and <= 7)` is the shipped form. Inside a record
  pattern, a tuple or a list it is not built yet — write the
  comparison as a guard there: `when o.Total > 100`.
```

Both of these are **general** gaps rather than binary-specific ones: closing them improves records
and tuples too, and any answer that proves coverage over a field inside a binary needs both.

### And the interval algebra at top level is sound, re-verified today

Re-measured against a compiler four features newer than when it was first recorded:

```
four int singletons, no catch-all  -> Classify(int <= 0 | 4..7 | int >= 9) -> ...
guard bounding the octet 0..255    -> Classify(int <= -1 | int >= 256) -> ...
CONTROL: single-sided guard t >= 0 -> Classify(int <= -1) -> ...
declared `type Octet`, 4 of 256    -> Classify(0 | 4..7 | 9..255) -> ...
```

The control is what makes it evidence: a single-sided guard leaves exactly `int <= -1`, so each
comparison is credited independently. Two figures have **moved since they were first recorded** — a
catch-all over a closed residual is now refused (`discards cases the compiler can name`), where it
was once accepted silently; and a 41-interval residual now truncates to `... (38 more)`.

---

## 6. What this leaves for the decision

**Ruled out by the survey, unanimously and with an explicit diagnostic in three of four
languages:** relating two fields of one pattern. Erlang `bad binary type`, Elixir's grammar
enumerating its three forms, Gleam erasing the dependency at the binding, C# `CS9135` plus `CS8846`
saying the guard route is invisible to the checker. A dependent size is not a road anyone is on.

**Established as borrowable, with a working implementation to point at:** C#'s coverage mechanism —
partition arity × element value-space, and report the counterexample in the pattern's own syntax.

**Established as a warning:** C#'s sized type cannot be pattern-matched (`CS8985`). The one language
that has both a sized sequence type and a sequence pattern keeps them apart. That is evidence
against spending a spelling on a sized binary type before something needs it.

**Left open, and the reason this ticket is not a formality:** nobody does coverage over a
**sub-byte** field. C# has no such concept; the BEAM three have the bits and not the proof. Both of
ticket 25's wire exemplars are bit-packed in their first eight bits. An answer that proves coverage
over a 4-bit opcode is beyond every language measured here — which is either the differentiator or
the overreach, and that is a decision rather than a measurement.

<!-- ticket 30; exemplars 25b (RFC 6455) and 25c (AMQP 0-9-1); F9 shipped the value half; F13 blocked on this -->
