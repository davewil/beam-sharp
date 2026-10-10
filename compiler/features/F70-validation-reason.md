# F70 — `ValidationError` says why: `Reason`, and a key blamed at its own path

**Status**      **in progress** — built 2026-10-09, 30 tests in `validation_reason_tests`;
                closing it is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q16, Q12, Q21
                and Q24, and [ticket 79](../../wayfinder/issues/79-validationerror-as-a-record.md)'s
                reopened point. Decides nothing; see *One point the build could not follow*
**Closes**      [ENG-615](https://linear.app/davewil/issue/ENG-615)
**Unblocks**    [ENG-617](https://linear.app/davewil/issue/ENG-617) (a repeated key) and
                [ENG-618](https://linear.app/davewil/issue/ENG-618) (tag-first unions), which
                report values carrying `Reason`
**Depends on**  F18 (`ValidateAs`), F49 (the record), F58 (string keys), F59 (open field
                sets), F61 (the absent option key), F69 (`FromJson`)

## Why this one now

A failed decode said where and what was expected, and nothing else. Text that was not
JSON, an absent key, a key the type does not name and a wrong value differed only in the
`Expected` string, and the middle two were both reported as the whole type at the
object. A handler that answers them differently compared strings.

## The program

```csharp
module Intake

type W = { "a": int }

public result<W, ValidationError> Read(string body)
Read(body) -> FromJson<W>(body)

public string Explain(ValidationError e)
Explain(ValidationError { Reason: :not_json })      -> "the body is not JSON"
Explain(ValidationError { Reason: :missing })       -> "a field is absent"
Explain(ValidationError { Reason: :unknown_key })   -> "a field is not one of ours"
Explain(ValidationError { Reason: :duplicate_key }) -> "a field is repeated"
Explain(ValidationError { Reason: :mismatch })      -> "a field has the wrong type"
```

```
$ bsc Intake Read '"{\"a\":\"x\"}"'
(:error, {Kind = :'ValidationError', Expected = "int", Path = ["["a"]"], Reason = :mismatch})
$ bsc Intake Read '"{}"'
(:error, {Kind = :'ValidationError', Expected = "int", Path = ["["a"]"], Reason = :missing})
$ bsc Intake Read '"{\"a\":1,\"b\":2}"'
(:error, {Kind = :'ValidationError', Expected = ""a"", Path = ["["b"]"], Reason = :unknown_key})
$ bsc Intake Read '"nope"'
(:error, {Kind = :'ValidationError', Expected = "JSON", Path = [], Reason = :not_json})
```

## The rule

- `ValidationError` is `{ Path: list<string>, Expected: string, Reason: :not_json |
  :missing | :unknown_key | :duplicate_key | :mismatch }`.
- `:mismatch` is every failure the other four do not name, and what every validator
  reported before this feature.
- `:not_json` is `FromJson`'s alone: the text did not parse.
- `:missing`: where the type at a position has exactly one map member, a field set or a
  record, and the value is a map lacking a key that member requires, the error is at that
  key's path, and `Expected` is the key's type. An `option<T>` key is not required (F61).
  With several absent, the first in key order is reported.
- `:unknown_key`: where that one member is exact and the map has a key it does not name,
  the error is at that key's path, and `Expected` is the keys the type names, joined with
  ` | `; a type naming none but its tag is printed whole. With several, the first in the
  term's key order. An absent key is reported before an unknown one, and an unknown one
  before a named key's wrong value. A key the path cannot spell, a tuple or a binary that
  is not text, is not named: the whole type at the map, as `:mismatch`, as F43 does.
- A key whose type is a single atom, a record's `Kind` above all, is asked about before
  any other: absent it is `:missing`, and holding another atom it is `:mismatch`, both at
  that key. Another record is so reported as another record, whatever else it lacks.
- A position whose type has several map members, a `map<K, V>` among them, is reported
  as before: the whole type at the position, as `:mismatch`. [F72](F72-tagged-union.md) changes that for
  a tagged union.
- `:duplicate_key` is in the type and was built by nothing here; [F71](F71-duplicate-key.md)
  builds it.
- `ValidateAs<T>` reports `:mismatch`, `:missing` and `:unknown_key` as `FromJson<T>` does.
- A hand-built `ValidationError` names all three fields.

## One point the build could not follow

Q12 says the first absent key *"in declaration order"*. A field-set type is a set of keys:
`{ "a": int, "b": int }` and `{ "b": int, "a": int }` are one type, share one validator,
and print the same way, so the order the author wrote is not there to read. This build
reports the first absent key in key order, which is the order the type prints in and the
order F43 walks a map's entries in. Reported to David with the build.

## What changed

- `bs_check:stratum_two/0`: the `ValidationError` entry gains `Reason`, a union of the
  five atoms. Construction, projection and the record pattern follow from the entry.
- `bs_emit:error_at/3`: the one place a validator's error is built, taking the reversed
  path, the expected text and the reason. `error_expr/1` is it with `:mismatch` at the
  node. `text_form/1` writes `:not_json`.
- `bs_emit:validator_form/4`: a validator whose type has one field-set member ends in a
  clause for any other map, calling a generated `…@k/2`. That function tests each required
  key with `is_map_key`, then, for an exact member, walks the map in key order for a key
  outside the member's own (`bs@validate@unknown/2`, one per module). What neither
  explains goes to the fill attempts (F61) or, with none, to the node's own mismatch.
- `ToJson`'s strict validators are the same code with every key required, so its crash
  names the absent or undeclared field where it used to name the whole record.

## What the build found

- **A record residual does not say which field's value is uncovered.** `Explain` with
  four of the five clauses is refused as *not exhaustive*, and the clause it asks for is
  `Explain(ValidationError v) -> ...`. It is the same for any record: a
  `record Light { State: :red | :amber | :green }` covered for two states gets
  `Say(Light l) -> ...`. Not this feature's:
  [ENG-439](https://linear.app/davewil/issue/ENG-439) has it.
- **An unknown key is spelled from the value, a known one from the type.** A name key
  is `.Extra` either way. A string key holding `"` or `\` is escaped in a known key's
  segment, as the type prints it, and written raw in an unknown key's, as F43 writes a
  map entry's. No JSON this was run on has such a key.
- **Six existing assertions said the whole type at the object** and now say the key:
  three in `absent_option_tests`, two in `validate_as_tests`, and V4 of
  `check-absent-option.sh`. `check-to-json.sh` P3 forbade the text `Secret` anywhere in a
  crash; the crash now names that field, so P3 forbids the member `"Secret":`, which is
  what its `unguarded` stub prints.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F70.1 | the program above on the four inputs | the four values above |
| F70.2 | `ValidateAs<W>` over `{}` and over `{ "a" = 1, "b" = 2 }` | `:missing` at `["a"]`; `:unknown_key` at `["b"]` |
| F70.3 | `Explain` with five clauses; with the `:duplicate_key` clause removed | compiles and answers each; refused as not exhaustive |
| F70.4 | an absent key in a nested object, and in a list element | the parent's path followed by the key's |
| F70.5 | an open type: an extra key; an absent required key beside an absent option key | accepted; `:missing` at the required key |
| F70.6 | a record: `Total` absent; an extra field | `:missing` at `.Total`, `Expected = "int"`; `:unknown_key` at `.Extra`, `Expected = "Id \| Total"` |
| F70.7 | `{ "a": int, "c": int }` given `a`, `b`; given `a`, `c`, `z` | `:missing` at `["c"]`; `:unknown_key` at `["z"]`, `Expected = "\"a\" \| \"c\""` |
| F70.8 | `W \| :null` given `{}`; a two-member union given a map neither takes | `:missing` at `["a"]`; the whole union at `[]`, `:mismatch` |
| F70.9 | a hand-built error with `Reason`; without it; `e.Reason` | compiles; refused; the atom |
| F70.10 | a value that is not a map at a field-set position | the whole type, `:mismatch` |
| F70.12 | a record with no `Kind`; with another record's; a tuple key; `W \| map<int, int>` | `:missing` at `.Kind`; `:mismatch` at `.Kind`; the whole type, `:mismatch`; the whole union |
| F70.11 | exemplar 25f on `{"answers":{}}` | `(:error, (:malformed, ValidationError { Path = ["[\"model\"]"], Expected = "string", Reason = :missing }))` |

## Done when

The scenarios pass, `check-validation-reason.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-09

Before the build, `validation_reason_tests` failed 20 of its first 23 and `check-validation-reason.sh`
was red on all six cases: R1 to R5 printed `Reason is not declared by ValidationError`,
and R6 printed the whole `ReplyWire` type at `Path = []`. Its `--self-test` sees four
defects (`no_reason`, `blames_object`, `all_mismatch`, `open_reason`) and accepts the
correct outputs. F70.11 is R6: `wayfinder/prototypes/25f_replay.erl` now asserts the
malformed case and prints `malformed: ok`.
