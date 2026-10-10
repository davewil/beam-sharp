# F72 — a union tagged by a string-literal key is validated by that key first

**Status**      **in progress** — built 2026-10-10, 20 tests in `tagged_union_tests`;
                closing it is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q19 and Q22.
                Decides nothing; see *What the build found*
**Closes**      [ENG-618](https://linear.app/davewil/issue/ENG-618)
**Depends on**  F18 (`ValidateAs`), F61 (the absent option key), F68 (string-literal
                types), F69 (`FromJson`), F70 (`Reason`, and a key blamed at its own path)

## Why this one now

An LLM reply's answers are a union told apart by `"type"`. When one answer was wrong, the
error was the whole union at the answer: three field sets printed end to end, and nothing
about which key. F70 names a key only where a position has one map member, and a tagged
union has several. The tag says which one was meant.

## The program

```csharp
module Tagged

type AnswerWire = { "type": "choice", "choice": string, .. }
                | { "type": "score", "score": int, .. }
type Reply = { "answers": map<string, AnswerWire> }

public result<AnswerWire, ValidationError> Read(string body)
Read(body) -> FromJson<AnswerWire>(body)

public result<Reply, ValidationError> ReadReply(string body)
ReadReply(body) -> FromJson<Reply>(body)
```

```
$ bsc Tagged Read '"{\"type\":\"tri\",\"choice\":\"x\"}"'
(:error, {Kind = :'ValidationError', Expected = ""choice" | "score"", Path = ["["type"]"], Reason = :mismatch})
$ bsc Tagged Read '"{\"type\":\"score\",\"score\":\"x\"}"'
(:error, {Kind = :'ValidationError', Expected = "int", Path = ["["score"]"], Reason = :mismatch})
$ bsc Tagged Read '"{\"choice\":\"x\"}"'
(:error, {Kind = :'ValidationError', Expected = ""choice" | "score"", Path = ["["type"]"], Reason = :missing})
$ bsc Tagged ReadReply '"{\"answers\":{\"q\":{\"type\":\"tri\"}}}"'
(:error, {Kind = :'ValidationError', Expected = ""choice" | "score"", Path = ["["answers"]", "["q"]", "["type"]"], Reason = :mismatch})
```

Before this feature all four were the whole union, at `[]` for the first three and at
`["answers"]["q"]` for the fourth.

## The rule

- A union's map members have a **tag** when there are two or more of them, none is a
  `map<K, V>`, and one key is in every member, holds nothing but string literals in each,
  and has no literal in two of them. With several such keys, the first in key order is the
  tag.
- A map whose tag is a literal one member names is validated against that member and no
  other. What that member's validator reports is the answer: a wrong value at its own
  path, and by F70 an absent key as `:missing` at that key and, for an exact member, an
  unknown key as `:unknown_key` at that key. The member's absent `option<T>` keys are
  filled as F61 fills them.
- A map whose tag is anything else, a string no member names or a value that is not a
  string, is `:mismatch` at the tag's path, and `Expected` is the tags, printed as the
  union of literals they are.
- A map with no tag is `:missing` at the tag's path, with the same `Expected`.
- The tag's path is the union's own path followed by the tag's segment, wherever the
  union sits.
- A member that is not a map, `AnswerWire | :null`, is accepted as before. A value that
  is neither a map nor such a member is the whole union at its position, as before.
- A union with no tag is reported as before: the whole union at its position.
- `ValidateAs<T>`, `FromJson<T>` and `ToJson<T>`'s guard share one validator, so all
  three read the tag first.
- No value is accepted that was refused before, and none refused that was accepted: a
  member requires its own literal at the tag, so the tag already decided which member a
  map could inhabit.

## What changed

- `bs_emit:map_cases/1` gains a case ahead of the others, `{lit, Key, Tagged}`, returned
  when `literal_tag/1` finds a tag. The cases it had are `shape_cases/1`, unchanged.
- `bs_emit:lit_clauses/3` writes that case: one clause per literal, calling the validator
  of the member the literal names with the map and the path unchanged, then a clause for
  a map whose tag matched none, then one for any other map.
- `bs_emit:map_children/1` registers each tagged member as a child, so each has a
  validator of its own. A member is one field set, so F70's `…@k` function and F61's fill
  attempts are generated for it as for any single field set.
- `bs_emit:validator_form/4` makes no fill attempts at a tagged union: the member does.

## What the build found

- **With two candidate keys, key order chooses.** `{ "kind": "a", "type": "x" } |
  { "kind": "b", "type": "y" }` is told apart by either. The build reads `"kind"`, the
  first in key order, as F70 reports the first absent key in key order. ENG-618 does not
  say.
- **A member's tag may be several literals.** `{ "t": "a" | "b", .. } | { "t": "c", .. }`
  has a tag, and `"a"` and `"b"` both name the first member. The issue's words, *"string
  literals no two members share"*, cover it; its examples have one literal each.
- **Records can be told apart this way too.** Two records that share a field of disjoint
  string literals are dispatched on that field, and the member's validator then asks about
  `Kind` as F70 has it. `FromJson` refuses a record, so this is reachable under
  `ValidateAs` and `ToJson` alone.
- **No existing test or gate assertion changed.** The suite's other 1,397 tests passed
  unmodified.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F72.1 | the program above: an unknown tag; a named tag with a wrong value; no tag | `:mismatch` at `["type"]` expecting `"choice" \| "score"`; `:mismatch` at `["score"]` expecting `int`; `:missing` at `["type"]` |
| F72.2 | a value inhabiting each member, one with an extra key | returned unchanged |
| F72.3 | a named tag with a required key absent; the same with the other member's key present; an exact member with an extra key | `:missing` at the key, both; `:unknown_key` at the key, expecting the member's own keys |
| F72.4 | a tag holding `7` or `null`; a value that is not a map | `:mismatch` at the tag; the whole union at `[]` |
| F72.5 | the union as a map's value; as a list's element | the entry's path then the tag's; the element's path then the tag's |
| F72.6 | `AnswerWire \| :null` given `null`, a member, an unknown tag, `{}` | `:null`; the member; `:mismatch` at the tag; `:missing` at the tag |
| F72.7 | a member with an `option<string>` key, the key absent; a required key absent | the key filled with `:nothing`; `:missing` at the required key |
| F72.8 | `ValidateAs<AnswerWire>` over the same terms | the same values |
| F72.9 | `ToJson` over an exact tagged union: a member; a member short a key | the JSON; a crash naming the key as `:missing` |
| F72.10 | `{ "a": int } \| { "b": int }`; `{ "t": "a", .. } \| { "t": string, .. }` | the whole union at `[]`, as before, both |
| F72.12 | two keys that would both serve; a member named by `"a" \| "b"`; two records sharing a literal field, under `ValidateAs` | the first in key order is the tag; either literal names the member; the field picks the record, which then asks about `Kind` |
| F72.11 | exemplar 25f, served a reply whose `department` answer has `"type":"tri"` | `(:error, (:malformed, ValidationError { Path = ["[\"answers\"]", "[\"department\"]", "[\"type\"]"], Expected = "\"choice\" \| \"noul\" \| \"score\"", Reason = :mismatch }))` |

## Done when

The scenarios pass, `check-tagged-union.sh` is seen red before the build and green after,
and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-10

Before the build, `tagged_union_tests` failed 13 of its first 17 (F72.12's three came
after it); the four that passed are the ones
that assert nothing changed (F72.2, the non-map value of F72.4, and F72.10).
`check-tagged-union.sh` was red on T1, T2, T3, T4 and T7: each printed the whole union,
and T7 the three-member `AnswerWire` at `["answers"]["department"]`. Its `--self-test` sees
seven defects (`whole_union`, `first_member`, `no_missing`, `top_only`, `maps_only`,
`always_tag`, `exemplar_only`), the last six each required to be red on one case alone, and
accepts the correct outputs. F72.11 is T7: `wayfinder/prototypes/25f_replay.erl` serves the
reply and prints `unknown tag: ok`.
