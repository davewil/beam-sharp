# F58 — a field-set key may be a string literal: `{ "input_tokens": int }`

**Status**      **in progress** — 12 tests in `string_key_tests`, 1086 in the
                suite; `check-language.sh` gained a must-compile block in §10,
                seen red first; the tree-sitter grammar takes a string key in
                all three field positions
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md)
                Q2, and the string-key half of Q7. Decides nothing
**Closes**      [ENG-405](https://linear.app/davewil/issue/ENG-405), and the
                half of [ENG-408](https://linear.app/davewil/issue/ENG-408) F57
                left: `{ "model" = m.Id }`
**Unblocks**    exemplar 25f's wire types, in part; see *Left*
**Depends on**  F33 (field-set types), F57 (the brace expression)

## Why this one now

Ticket 78 decided that a field's wire name lives in a structural type whose
keys are the wire's strings. Every JSON API an LLM client reads writes
lowercase snake_case keys, and before this no B# construct could name one.

## The program

```csharp
module Usage

type UsageWire = { "input_tokens": int, "output_tokens": int }

record Usage { InputTokens: int, OutputTokens: int }

public result<UsageWire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<UsageWire>(doc)

public Usage Tokens(UsageWire u)
Tokens({ "input_tokens": i, "output_tokens": o }) -> Usage { InputTokens = i, OutputTokens = o }

public UsageWire Echo(int i, int o)
Echo(i, o) -> { "input_tokens" = i, "output_tokens" = o }
```

`json:decode(<<"{\"input_tokens\":100,\"output_tokens\":20}">>)` validates as
it stands and comes back unchanged.

## The rule

- A string key is a binary, in the term and in the type. A name key stays an
  atom, so `{ "Status": int }` and `{ Status: int }` are different types.
- It is written the same way in a field-set type, a pattern, the brace
  expression and `with`.
- A record's fields stay names. `record R { "x": int }` is refused at the
  parse, naming the field set as where a string key belongs; `R { "X" = n }`
  is `field_set_mismatch`.
- Any string is a key, including `"content-type"` and `""`.

## What changed

- `bs_parser.yrl`: a `string_lit` key in `field_decl`, `pat_field` and
  `assign_field`; `record_fields/3` refuses one in a record. yecc conflicts
  unchanged: 5 shift/reduce, and the resolved set is the same by symbol.
- `bs_emit`: `key_lit/2` writes a key as an atom or a binary literal in
  patterns, constructions, guards and the generated validator; `field_seg/1`
  names a string key in a `ValidationError` path as F43 names a map entry,
  `["input_tokens"]`.
- `bs_types:key_str/1` prints a string key quoted, in types, residuals and
  `--api`; `bs_diag` and `ToJson`'s refusal path use it too.
- Specs: Erlang's type language has no singleton binary, so a member's string
  keys widen to one `binary() => any()` entry beside its exact name keys.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F58.1 | `Tokens` above on a decoded map | the `Usage` record |
| F58.2 | `ValidateAs<UsageWire>` on `json:decode` output | returned unchanged |
| F58.3 | a wrong value at `"input_tokens"` | `Path = ["[\"input_tokens\"]"]`, `Expected = "int"` |
| F58.4 | `ToJson<UsageWire>` | the lowercase keys, no `Kind` |
| F58.5 | `{ "input_tokens" = i, … }` | the map |
| F58.6 | the brace against `{ "model": string }`: right, wrong value, wrong key, repeated key | ok; `return_not_declared` ×2; `duplicate_field` |
| F58.7 | `{ "Status" = n }` where `{ Status: int }` is expected | `arg_not_accepted` |
| F58.8 | a missing case over `{ "ok": bool }` | residual `({ "ok": _ })`; `--api` prints `{ "ok": :false \| :true }` |
| F58.9 | `record R { "x": int }` | parse error naming the field set |
| F58.10 | `R { "X" = n }` | `field_set_mismatch` |
| F58.11 | keys `"content-type"` and `""` | run |

F58.8's residual prints the field's value as `_`. That is the head printer's
existing behaviour for name keys too (`Go({ Ok: _ })`), measured beside it.

## Out of scope

- A dictionary pattern, `{ "answers": a }` over `map<string, term>`: still
  refused, since `map<K, V>` has no pattern form (ticket 48). The key set has
  to be written in a field-set type.
- Keys a wire type does not name: ENG-406, the open `..`.
- A string literal as a value type, `"type": "ping"`: ENG-407.
- Projection by a string key: deferred by ticket 78 Q6.

## Left

25f's `decode.bs` is not rewritten. OpenRouter's reply has keys a closed field
set refuses, and its answers are tagged by `"type"`, so it waits on ENG-406 and
ENG-407.

## Done when

The scenarios pass, the LANGUAGE.md block compiles, the tree-sitter grammar
parses a string key in a type, a pattern and a brace, and `./bin/verify.sh` is
green twice from a clean clone.
