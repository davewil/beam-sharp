# F59 — a trailing `..` makes a field-set type open

**Status**      **in progress** — 9 tests in `open_field_set_tests`, 1095 in
                the suite; `check-language.sh` gained a must-compile block in
                §10, seen red first; tree-sitter takes the marker
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md)
                Q3. Decides nothing
**Closes**      [ENG-406](https://linear.app/davewil/issue/ENG-406)
**Fixes**       an F58 gap found while building this: a declaration path
                through a string key printed Erlang's `W.<<"a">>`
**Depends on**  F33 (field-set types), F58 (string keys)

## Why this one now

OpenRouter's evaluate reply carries `id`, `provider` and `usage.cost`, which
TypeSafe's does not, and an exact field set refuses the first. Every JSON API
grows keys a client does not read.

## The program

```csharp
module Reply

type UsageWire = { "input_tokens": int, "output_tokens": int, .. }
type ReplyWire = { "model": string, "usage": UsageWire, .. }

public result<ReplyWire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<ReplyWire>(doc)

public int Tokens(ReplyWire r)
Tokens({ "usage": { "input_tokens": i, "output_tokens": o } }) -> i + o
```

ReqLLM's OpenRouter fixture validates, extra keys at both levels, and comes
back unchanged; `Tokens` gives 120.

## The rule

- `{ …, .. }` is an open member: the named keys are required with their types,
  others are admitted. Without `..` a field set stays exact.
- `ValidateAs` checks the named keys and returns the value unchanged, extra
  keys included. It converts nothing.
- An exact field set is a subtype of the open one with the same keys; the
  reverse is refused (`arg_not_accepted`). The brace expression builds an exact
  set, so it goes where an open type is expected.
- `ToJson` over a type holding an open member is refused, `unencodable_member`
  with kind `open_map`, naming the path: it would publish keys no type
  declares (26 §4, 18 §1(c)).
- A record is always exact: `record R { X: int, .. }` does not parse.

## What changed

- `bs_parser.yrl`: `type_prim -> '{' open_field_decls '}'`, a right-recursive
  list ending in `, ..`. A first version reduced `field_decls` before `, ..`
  and added a shift/reduce conflict on `,` that shifted past the marker; the
  shipped rule shares the `field_decl ','` prefix, and the conflict set is the
  same as before (5 shift/reduce, same resolved set by symbol).
- `bs_check`: `{t_map_open, Fields}` beside `{t_map, Fields}` in `resolve`
  (to `bs_types:map_open/1`), `qualify_refs`, `vars_in`, `scan_ty`, `subst`,
  `written` and `type_source`; `unencodable/3` refuses an open member.
- `bs_diag`: the `open_map` member text and repair.
- Nothing in `bs_types` or `bs_emit`: open members existed for patterns, the
  printer already wrote `..`, the generated validator already skipped the size
  test for an open member, and the spec already added `any() => any()`.
- The F58 gap: `root/1` and `seg/2` now spell a string key `["a"]`, and
  `field_written/1` prints it quoted.

`vars_in/2`'s field-set clause matches `{_, T}`, a 2-tuple, where fields are
`{field, N, T}`, so it has never found a type variable inside a field set. It
is left as it was and recorded here rather than changed under this feature.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F59.1 | `ValidateAs<ReplyWire>` on OpenRouter's reply; `Tokens` | returned unchanged; `120` |
| F59.2 | a named key missing; a named key with the wrong type | `Path = []`; `Path = ["[\"model\"]"]`, `Expected = "string"` |
| F59.3 | an exact field set handed an extra key | refused, `Path = []` |
| F59.4 | `ToJson` over a type holding an open member | `unencodable_member`, `open_map`, path `["inner"]` |
| F59.5 | exact where open is expected; open where exact is expected | accepted; `arg_not_accepted` |
| F59.6 | a brace expression where an open type is expected | runs |
| F59.7 | `record R { X: int, .. }` | parse error |
| F59.8 | `bsc --api` on an open parameter | prints `{ "model": string, .. }` |
| F59.9 | an absorbed member under a string key | path `W["a"]` |

## Out of scope

- A field set with no named keys, `{ .. }`: `map<term, term>` already says it.
- String-literal types for the `"type"` discriminator: ENG-407.

## Done when

The scenarios pass, the LANGUAGE.md block compiles, the tree-sitter grammar
parses the marker, and `./bin/verify.sh` is green twice from a clean clone.
