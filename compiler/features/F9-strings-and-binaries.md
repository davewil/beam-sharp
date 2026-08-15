# F9 — `string` and `binary` as values

**Status**      **done 2026-08-15**
**Implements**  [ticket 20](../../wayfinder/issues/20-untheorised-term-shapes.md) §2, §3, §4, §5,
                [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §2 — decides nothing
**Unblocks**    the `string` **fields** in all three exemplars, `list<string>`, and every
                `LANGUAGE.md` block that says `Id: string`. **Not I/O** — see below, the claim is
                narrower than the AoC report's phrasing invites
**Depends on**  F1, F3, F5, F6

## Why this one now

The [AoC report](../../reports/2026-08-15-aoc-and-state.md) §5 named it, and the reason it gave is
the ordering rule with a second corpus behind it: `string` is the only item on the critical path
for *both* the exemplars and a real program written by someone with no stake in the language. Two
puzzles were solved outside the language because

> **beam-sharp can express the computation and cannot read the question.**

It is also, unusually, a feature with nothing to design. Ticket 20 §4 published the mapping and
§5 published the tier; `LANGUAGE.md` §4 has carried both rows as **decided** since the reference
was written. This file implements them and re-opens neither.

## What `string` is, and why it is not a second type

`string` is `binary` refined by valid UTF-8 (20 §4). Not a parallel type, not a wrapper — a
**subset**, so `string <: binary` holds and nothing converts between them.

That single sentence settles most of this feature's scope, because ticket 20 §5 puts the
refinement in the **opaque** tier: `valid_utf8` reads the content, so it is O(n), and O(n) is not a
guard, not a clause head, and not a foreign declaration. What survives that restriction is exactly
what F9 builds:

| | Where the UTF-8 property comes from |
|---|---|
| a literal | **compile time, zero runtime cost** — 20 §4, *"a literal is a `string` by construction"*. The compiler sees the bytes |
| an interior value | statically, from the signature that declared it. Nothing is re-checked |
| a binary from outside | **the generated O(n) entry check** — the sixth codegen obligation, and **out of scope here** |

So F9 gives the language strings it can *have* without giving it strings it can *acquire*. That is
a real boundary and it is where the honest version of the AoC claim sits.

## What this does not unblock, stated before the scenarios rather than after

**AoC still cannot read its input**, and F9 does not change that. Reading a file needs the FFI to
return a `binary` and then the entry check to make it a `string`; splitting lines and parsing
integers needs the collection library, which is blocked on the module system — the map's most
load-bearing fog patch. F9 removes one of three blockers. The report's *"unblocks I/O for AoC"* is
the sentence to not repeat.

What it does unblock is the other half of that line and it is not small: `list<string>` and
`Id: string` fail today on the identical `unknown_builtin` error, and every record in `LANGUAGE.md`
§6 and in all three exemplars has a `string` field.

## Scenarios

### The literal

**F9.1 — a string literal is an expression of type `string`.**

```csharp
string Greet()
Greet() -> "hello"
```

`bsc greet.bs Greet` → `<<"hello">>`, exit 0.

**F9.2 — the literal's UTF-8 is checked at compile time, and the source file is where it is
checked.** A `.bs` file is read as bytes; a literal containing a byte sequence that is not valid
UTF-8 is a compile-time error at the literal's line, not a runtime one and not a silent U+FFFD.

Exit 1. The message names the offset. **This is the divergence 29 §4 told 20 to state**: C# and
TypeScript both substitute U+FFFD here, so beam-sharp is deliberately stricter than both audiences
in the one place where being lenient would manufacture the invalid string the entry check exists to
prevent.

**F9.3 — a non-ASCII literal round-trips.** `"héllo"` is 6 bytes, not 5. Exit 0. The scenario
exists because getting this wrong is invisible in ASCII tests and every string in the exemplars is
ASCII.

> **This one caught a defect, and it was not in the lexer.** See the build notes: the emitted binary
> was 5 bytes. No `/utf8` specifier is emitted — the lexer already holds UTF-8 *bytes*, so the
> emitter writes them raw and adding a specifier would double-encode.

### The types

**F9.4 — `string` and `binary` are builtin type names.**

```csharp
string Echo(string s)
Echo(s) -> s
```

Compiles. Today: `string is not a builtin type`.

**F9.5 — `string <: binary`, so a `string` satisfies a declared `binary`.**

```csharp
binary Bytes()
Bytes() -> "hello"
```

Compiles, exit 0.

**F9.6 — and the converse is rejected, which is the entry check's absence made observable.**

```csharp
binary Raw(binary b)
Raw(b) -> b

string Text(binary b)
Text(b) -> Raw(b)
```

Exit 1 at `Text`'s clause return: a `binary` is not a `string`. **The error must not suggest a
cast**, because there isn't one — the fix is the entry check, and F9 does not have it. This is F5's
clause-return site doing exactly what it was built for, on a type that did not exist when it was
built.

**F9.7 — `string | binary` absorbs to `binary` rather than erroring.** 20 §2's absorption rule,
which is about containment: `<<_:32>> | <<_:32,_:_*8>>` absorbs, and so does this. It is worth a
scenario only because the neighbouring rule looks like it should fire and does not — 09 §4 errors
on **indiscriminable** members, not on nested ones, and `string` is nested.

**F9.8 — `list<string>` and a `string` record field both resolve.**

```csharp
record Order { Id: string, Total: int }

list<string> Ids()
Ids() -> ["A-1", "B-2"]
```

Compiles, exit 0. This is the row the exemplars are waiting on.

**F9.9 — the residual is exact over a union containing `string`.**

```csharp
type Payload = string | :nothing

atom Kind(Payload p)
Kind(:nothing) -> :empty
```

Exit 1, and the residual names `string` as the missing clause — not `term`, not `binary`. The
scenario exists because a new algebra component that silently reports empty is the failure mode
this compiler has hit twice (F5's `Certain`, F6's hang), and both times a passing test was no
evidence.

### The boundary

**F9.10 — `binary` is admissible as a foreign return type.** 20 §3 measured it: `<<_:M, _:_*N>>`
reduces to `byte_size` and `bit_size rem N`, both O(1) guard BIFs at 8 B and 8 MiB alike.

```csharp
using :erlang {
    binary term_to_binary(term t)
    int byte_size(binary b)
}
```

Compiles. `examples/interop.bs` currently writes `int byte_size(term bin)` — typing a binary as
`term` because the language had no word for it — and this scenario is that line getting its type.

**F9.11 — `string` is *not* admissible as a foreign return type, and errors at the declaration.**

```csharp
using :file {
    string read_file(term path)
}
```

Exit 1 at the `using` line. Ticket 18 §2: a foreign return type may mention only what a guard
decides in O(1), and `valid_utf8` is not. The message says what to write instead — `binary` — and
that this is the entry check's job.

**This is the placement rule executing on the one member of the opaque tier**, and it is derived,
not decided here. 20 §5's bar reads *"barred from clause heads and foreign declarations"*; the
amended resolution attached it to *user-declared* opaque refinements, and the reason it gave —
unbounded cost at a boundary with nothing to discharge it against, the caller never inside the
verified subset — applies to `string` identically. A compiler-known predicate is cheaper than an
arbitrary one and it is still O(n) over a length a foreign sender chooses, which is ticket 11's
sentence verbatim.

## Out of scope

**Binary patterns — `<<fin:1, op:4, payload:len>>`.** [Ticket 30](../../wayfinder/issues/30-binaries-as-a-parsing-grammar.md)
is **open**, and both of its questions are unanswered: a segment sized by a bound variable is not
expressible in `<<_:M, _:_*N>>` at all, and a union discriminated by a *value* inside the binary has
no story. F9 deliberately stops at binaries as values, which is the half 20 §3 says *"holds up"*.

**A surface spelling for a sized binary type.** F9 ships `binary` (the top) and `string`, and
nothing in between. This is code you cannot write:

```csharp
// none of these has a spelling, and none is decided
type Header = <<_:32>>
type Frame  = binary<32>
type Chunk  = binary where bit_size % 8 == 0
```

The compiler delta is small and the *decision* is not: 20 §2 published the algebra in Erlang's own
`<<_:M, _:_*N>>` notation, which is the notation of the language beam-sharp is not — this surface
writes `list<T>` where Erlang writes `[T]`, so borrowing the spelling unexamined would be the first
place it does the opposite. **Owed, and ticket 30 is the closest owner** — it already needs a
spelling for the pattern form, and a pattern and a type that cannot be written in the same notation
is a worse outcome than either choice. Flagged rather than invented; F9 needs none of it, because
the exemplars' `string` fields and `list<string>` are all top-and-refinement.

**A string literal in pattern position** — `Greet("hello") -> :hi`. This needs a value-level
singleton in the binary part, and 20's grammar is sizes, not values: `<<_:M, _:_*N>>` cannot say
*"this one"*. It is ticket 30 §2's question — *a union discriminated by a value inside the binary*
— arriving at the smallest possible scale, and it is out for the same reason the big version is.
Without it there is nothing to compute a residual against, so admitting the pattern would mean
admitting a match the checker cannot prove exhaustive, which is the one thing this compiler does
not do.

**The UTF-8 entry check.** The sixth codegen obligation. It belongs with `ValidateAs<T>` — the
exemplars table lists that as its own capability blocking 25a and 25c — and `ValidateAs<string>` is
already the shape ticket 11 published for *"validate a foreign term against `T`, return
`result<T, ValidationError>`"*. F9 does not pick that spelling; it stops one step short of needing
to.

**String operations.** Concatenation, splitting, length, `to_int`. All collection-library, all
blocked on the module system. `byte_size` via the FFI is what F9 leaves you with, and F9.10 makes
that honest rather than accidental.

**Bitstrings.** A non-byte-aligned value has no encoding and reaching the encoder with one is a
compile-time error (20 §4) — but there is no encoder yet and no way to build a bitstring without
binary construction, so the shape is unreachable. Named so that whoever builds construction knows
the rule is already decided.

## The algebra, and the one point in it that cannot be printed

The binary part is a **two-element powerset** — is the UTF-8 half present, is the non-UTF-8 half —
which is the smallest encoding that is *exact*, and exactness is 20's headline property:

| set | surface |
|---|---|
| `{}` | empty |
| `{utf8}` | `string` |
| `{utf8, other}` | `binary` |
| `{other}` | **no spelling** |

The fourth row is the honest cost of `binary \ string`. Collapsing it to `binary` would widen —
precisely the `erl_types` failure 20 spent the ticket on — and collapsing it to `none` would report
a residual empty when it is not. So it is representable and has no *surface* spelling; `to_string/1`
prints it as the difference, `binary \ string`.

> **CORRECTED at build time. This paragraph said the fourth point was "currently unreachable" and
> it is not.** F9.6 reaches it on the first try: `string Text(binary b)` reports
>
> ```
> not covered by the declared return type:
>   binary \ string
> ```
>
> The reasoning behind the wrong claim was that reaching it needs a *pattern* discriminating the
> two, which F9 has not got. That is true of a **clause residual** and irrelevant to the **clause
> return**, which is F5's site 4: containment is checked in both directions, and only the pattern
> direction is limited to what can be written. So the print is load-bearing rather than defensive,
> and it reads correctly in the one message that produces it — which is luck, and is the sort of
> thing to check rather than assume next time a part gains a point nobody can spell.

**Union is set union, intersection is set intersection, subtraction is set difference.** No
widening anywhere, which is the property that makes the rest of the checker's subtraction sound.

## Traps carried in from earlier features

**`is_none/1` matches the `ty()` map literally in its head** (`bs_types.erl:142`). Erlang map
patterns are partial, so a sixth component added to `none/0` and forgotten there makes a
binary-only type report empty — and **every containment over it then passes vacuously**. The
compiler goes quieter, not red. This is F5's `Certain`/`Possible` trap in a third costume and it is
confirmed the same way: by mutating the source, not by the suite being green.

**`term/0` must contain binaries**, or `term` stops being the top type and every residual against
it is wrong. Its existing comment explains a deliberately-absent tuple part; the binary part is not
one of those and must be full.

**Run the corpus gate before writing a single rejection test.** F5's rule, and F9 edits
`bs_types` and `builtin/1` — the shared funnel the checker and the emitter both go through.

**`check-language.sh` is expected to go red, and that is the gate working.** Blocks tagged
`csharp not-yet` that use `string` will start compiling, and the bidirectional check fails a
`not-yet` block that compiles. Promote exactly those; §6's `Area(Circle c)` block stays `not-yet`
because it uses `3.14159` and `float` is **open**, which is a different reason and must not be
over-promoted.

**One `ibs` probe on a string literal.** Three features running have each found a hole at the REPL
prompt and none has closed the gap; `bs_repl` still appears zero times in the suite. One probe, fix
or note, no expansion.

## Done when

- All eleven scenarios assert, including F9.2's rejection and F9.11's declaration error.
- The corpus gate is green and `examples/` gains a file exercising the literal and the type, with
  its row in `every_shipped_surface_form_has_an_example_test` — the test fails **by name**, so this
  is a deliverable and not a nicety.
- `check-language.sh` is green with the blocks that now compile promoted out of `not-yet`.
- Mutating `is_none/1` to drop the binary arm turns the suite **red**, measured rather than assumed.
- `examples/interop.bs` says `binary` where it said `term`.

## What building it found

**The `.abstr` file is a serialisation boundary and nobody knew.** `bs_emit:to_abstr/1` writes forms
with `io_lib:format("~p")`, which prints a list of printable bytes as a quoted string and emits
those **bytes**; `erlc` has read Erlang source as **UTF-8** since OTP 17. The two ends disagreed, so
`"héllo"` round-tripped as **five bytes instead of six** — the `c3 a9` pair read back as the single
codepoint 233.

It **compiled, ran, and returned a perfectly good binary that was the wrong one.** No error, no
warning, correct-looking output; only a byte count showed it. That is the third time this compiler
has produced a defect whose signature is silence, after F5's vacuous containment and F6's hang.

Two fixes were measured before choosing, in a throwaway module rather than argued: without a coding
comment the binary is **5 bytes**, with `%% coding: latin-1` it is **6**. The alternative — emitting
one `bin_element` per byte so no character list is ever printed — fixes strings and **leaves the
identical trap set for the next non-ASCII thing to reach a form**, an atom with an accented name
being the obvious one. The one-line fix is at the boundary; the verbose one is at a caller. This is
not a strings bug that F9 happened to hit, it is an **emitter** bug that only a string was ever
going to reach.

**A leex regex escapes differently than a PCRE one, and the failure points somewhere else.**
`"(\\\\.|[^"\\\\])*"` matches *two* literal backslashes, so no escape ever lexed — and the symptom
was `illegal characters` reported on the closing **quote**, several characters past the real fault.
One backslash is the rule: `"(\\.|[^"\\])*"`.

**F9's hole at the prompt, which is the fourth feature in a row to find one.** `"zz"` typed as an
argument was read by Erlang's own term reader as a **char list**, so it came back `[122, 122]`. That
breaks the REPL's own stated contract — `bs_run.erl`'s comment says *"the REPL must accept back what
it just printed"*, and `format_value/1` prints a binary as `"zz"`. A string changed type on a round
trip: the prompt could not show you what it had just shown you. Fixed in `parse_compound/2`, reading
through `erl_scan` so escapes mean the same at the prompt as in a file, then re-encoding to UTF-8
because `erl_scan` yields codepoints and a beam-sharp string is bytes.

**And a correction to the standing claim about REPL coverage.** The features README says *"`bs_repl`
appears zero times in the suite"*. Literally true and misleading: `repl_tests.erl` holds **17
tests**. They go through the CLI and `bs_run` rather than naming the module, which is the suite's own
boundary doctrine working as intended. The gap is narrower than "no tests at all" — what the REPL
lacks is coverage of *values*, which is exactly where F9's hole was.

**The corpus gate earned its place again, in the negative.** It was run before a single rejection
test, per F5's rule. It stayed green through the algebra change — and unlike F6, that is not because
this feature adds no rejection path. It adds three. It passed because a new component starts empty
in `none/0` and full in `term/0`, so no existing program's type changed at all.

**The mutation was measured, not assumed.** Dropping `bins := []` from `is_none/1`'s head turns
**8 tests red**. The partial-map-pattern hazard turned up in **three** places, not the one that was
predicted: `is_none/1`, `bs_types:m_pat/1` and `bs_emit:record_tag/2`. The latter two would have
mis-printed and mis-tagged a record whose `Kind` field type carried a string, which no scenario in
this file would have caught.

## What this feature is out of order about

Nothing — but **F8 sits ahead of it and is still blocked**, and its own argument was that it
rewrites every `.bs` file in the repo and every later feature adds more of them. F9 adds one
example and touches `interop.bs`, so F8's rewrite cost goes up by that much. Stated rather than
stepped over, the way F4's out-of-order build was: F8 is blocked on a token only David can choose
and F9 is blocked on nothing, so waiting would buy one file's worth of rewrite at the price of the
item both corpora are on the critical path for.
