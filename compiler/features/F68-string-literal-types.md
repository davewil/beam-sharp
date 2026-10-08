# F68 — a string literal is a type: `{ "type": "ping", .. }`

**Status**      **in progress** — built 2026-10-08, 14 tests in
                `string_literal_type_tests`; closing is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md)
                Q5. Decides nothing; raises
                [ticket 117](../../wayfinder/issues/117-a-literal-tagged-field-set-and-the-catch-all.md)
**Closes**      [ENG-407](https://linear.app/davewil/issue/ENG-407)
**Unblocks**    exemplar 25f's answers, which are tagged by `"type"`; see *Left*
**Depends on**  F58 (string keys), F59 (open field sets), F13 (string literals
                in pattern position)

## Why this one now

Ticket 78 made wire types open, so they can carry each other's keys and the
presence of a key no longer says which member arrived. A streaming API's
`message_stop` and `ping` events are both only `{"type": …}`. The value at the
key is what tells them apart, and before this no type could say it.

## The program

```csharp
module Stream

type Start = { "type": "content_block_start", "index": int, .. }
type Stop  = { "type": "message_stop", .. }
type Ping  = { "type": "ping", .. }

type Event = Start | Stop | Ping

public atom Kind(Event e)
Kind({ "type": "content_block_start" }) -> :start
Kind({ "type": "message_stop" })        -> :stop
Kind({ "type": "ping" })                -> :ping

public result<Event, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<Event>(doc)

public Ping Beat()
Beat() -> { "type" = "ping" }
```

`Kind` has no `_`. It runs as `examples/Stream`.

## The rule

- A string literal in type position is the one string it spells. A union of
  them, `"low" | "high"`, is a type on its own.
- A string-literal pattern takes exactly its own string. Over a set of literals
  the clauses can close it; over `string` the residual is every other string,
  which is open, so a catch-all is still required and legal (ticket 30).
- A string-literal expression has its own string as its type, so
  `{ "type" = "ping" }` is a `{ "type": "ping" }`, and `{ "type" = "pong" }`
  is refused where that is expected.
- `ValidateAs` compares the value with the literal. `ToJson` writes it
  unchanged.
- A foreign function may be declared to return literals: equality is a guard.
- A guard's `x == "low"` and `x != "low"` narrow `x` as the literal pattern
  does, as they do for an atom.

A literal now behaves as an atom or a float literal already did, including
where that refuses a program that compiled before: a name bound to
`n switch { 0 => "a", _ => "b" }` is `"a" | "b"`, so a `_` over what is left
of it is refused as it is for `:a | :b`. Ticket 117 Q2 asks whether that stands.

## What changed

- `bs_parser.yrl`: `type_prim -> string_lit`. yecc conflicts unchanged: 6
  shift/reduce.
- `bs_types`: the binary part's strings are a finite or cofinite set of
  literals, as the atom part is, and reuse its set operations. `utf8` is the
  cofinite set that excludes nothing and keeps its atom, so every existing
  reader of `string` and `binary` matches as before. `str_lit/1` builds one;
  `is_open/1` treats only a finite set as closed; `separable/2` tells two
  members apart by a literal; the printers spell a literal quoted and
  `string \ ("a" | "b")` for the rest.
- `bs_types:m_hd/2` and `m_pat/1`: a key that holds exactly one literal prints
  it, in a residual head and in a "not covered" refusal, `{ "type": "ping" }`.
  Both printed `{ "type": _ }`, which names no member. `key_str/1` writes the
  lexer's whole set of escapes, so a literal with a newline prints as source.
- `bs_check`: `resolve/3` reads `t_str`; `pattern_type/3` and `type_of/3` give
  a literal its singleton, where both said `string`; the foreign-return check
  does not count a set of literals as an undecidable `string`;
  `comparison/1` reads `==` and `!=` against a string literal in a guard.
- `bs_check:correction_of/4`: the signature offered for a mismatched return
  says `string` where a clause returned a literal (`bs_types:widen_strs/1`),
  so F25's advice reads as it did.
- `bs_emit`: the validator has one clause per literal; the foreign-return guard
  compares with `=:=`. Specs still say `binary()`.
- tree-sitter: `string` is a `type_prim`.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F68.1 | `Kind` above, three members, no `_` | compiles; each event answers its tag |
| F68.2 | `Kind` over `Stop \| Ping` with the `ping` clause missing, at `bsc` | residual `Kind({ "type": "ping" }) -> ...`, and not the covered member |
| F68.3 | `type Level = "low" \| "high"`, both clauses; then one | runs; `inexhaustive` |
| F68.4 | the same two clauses over `string`; then with `_` | `inexhaustive`; runs |
| F68.5 | `{ "type" = "ping", "seq" = n }` as `Ping`; `{ "type" = "pong" }` as `{ "type": "ping" }` | the map; `return_not_declared` |
| F68.5b | the refused brace, at `bsc` | the message shows `{ "type": "pong" }` |
| F68.6 | `ValidateAs<Event>` on each member and on an unknown tag; `ValidateAs<{ "type": "ping" }>` on `"pong"` and on `7` | unchanged; `ValidationError`; `Path = ["[\"type\"]"]`, `Expected = "\"ping\""` |
| F68.7 | `ToJson<Event>` | the literal, unchanged |
| F68.8 | `l switch { "low" => 1, "high" => 2 }` over `Level`; then one arm | runs; `switch_inexhaustive` |
| F68.9 | `ValidateAs<Event>` where the members are open and differ only in the literal | told apart; an unknown tag and a member missing its key are refused |
| F68.10 | a foreign function declared to return `Level` | `"low"` passes; `"mid"` crashes `case_clause` |
| F68.11 | `Rank(l) when l == "low"` and `when l == "high"` over `Level` | exhaustive; runs |
| F68.12 | a missing literal holding `"` and a newline, at `bsc` | the head prints `"a\"q\n"`, escaped as source |
| F68.13 | a clause returns `"none"` where `int` is declared, at `bsc` | the offered signature is `public int \| string Pick(bool b)` |

## Out of scope

- Whether a `_` over leftover literal-tagged members is refused, as it is over
  leftover records: [ticket 117](../../wayfinder/issues/117-a-literal-tagged-field-set-and-the-catch-all.md)
  Q1. Measured today: it compiles where a leftover member is open (`..`) or
  holds a field with an unbounded type, and is refused where every field of
  every leftover member is a literal, and over a bare union of literals. That
  is the algebra's existing rule for a tuple, not a choice made here.
- Projection by a string key: deferred by ticket 78 Q6.
- A literal-tagged member with more than one literal left at its key prints
  the key's value as `_` in a residual, as any other value does.

## Left

25f's `decode.bs` is not rewritten. Its answers can now be typed as
`{ "type": "choice", .. } | { "type": "score", .. } | { "type": "noul", .. }`
and validated in one step; the write-up it is extracted from still spells the
`:maps.find` ladder.

## Done when

The scenarios pass, the LANGUAGE.md blocks compile, the tree-sitter grammar
parses a string literal in type position, and `./bin/verify.sh` is green twice
from a clean clone.
