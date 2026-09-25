# F61 — `ValidateAs` reads an absent key at an `option<T>` field as `:nothing`

**Status**      **in progress** — 19 tests in `absent_option_tests`, 1146 in
                the suite; `check-absent-option.sh` seen red on master first
**Implements**  [ticket 26](../../wayfinder/issues/26-data-modelling.md) §4's
                boundary half, extended to wire types by
                [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q8.
                Decides nothing
**Closes**      [ENG-409](https://linear.app/davewil/issue/ENG-409)
**Depends on**  F18 (`ValidateAs`), F33 (field-set types), F58 (string keys),
                F59 (open field sets)

## Why this one now

TypeSafe's evaluate reply has no `id`; OpenRouter's has `"id": "gen-jev-test"`.
A wire type that says the key is optional, `"id": option<string>`, refused the
first reply outright, `Path = []`, because a validator only ever checked a
term and handed it back. 26 §4 decided a record has no absent
fields and that the boundary turns an absent key into `:nothing`; nothing built
the boundary half.

## The program

```csharp
module Reply

type ReplyWire = { "id": option<string>, "model": string, "refusal": string | :null, .. }

public result<ReplyWire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<ReplyWire>(doc)
```

TypeSafe's reply, with no `id`, comes back with `"id" => :nothing`.
OpenRouter's keeps its string. A `null` refusal stays `:null`.

## The rule

- At a record field or a field-set key whose type is an `option<T>`, an absent
  key validates as though it held `:nothing`, and the value returned holds
  `:nothing` there. Every other absent key is refused as before, `Path = []`.
- **Which fields count.** The emitter sees the normalised type, where
  `option<T>` is `T | :nothing`. A field counts when `:nothing` is one of its
  type's finitely many atoms. A field typed `atom`, or `term`, contains
  `:nothing` only by absorption. Ticket 15 makes `option<atom>` that same
  collapse, so no `option` was written there, and an absent key stays refused.
- JSON `null` is not absent: a key holding `:null` at an `option<string>`
  field is refused at that key, as before. `option<string | :null>` accepts both.
- The fill reaches every depth the validator walks: a record's field, a tuple
  component, a list element, a map value, an alternative. A value with nothing
  to fill comes back as it was.
- An exact field set still refuses a key it does not name. An absent key is
  filled first, so an unknown key beside it is still an unknown key.
- `ToJson<T>` converts nothing. Its guard crashes on an absent option key as
  it did before this feature, blamed where the key is missing.
- A value refused after its absent keys were filled is blamed as the filled
  value would be: `{ Model = 1 }` against `{ Id: option<string>, Model: string }`
  is refused at `.Model`, where before it was refused at `[]`.

## What changed

- `bs_emit`: a validator whose type has a member with an `option<T>` field
  ends, before its refusal, in one attempt per such member. Each attempt merges
  `:nothing` under the member's option keys and validates the merged value
  again, if the member's other keys are present, at least one option key was
  absent, and for an exact member the merged value has exactly its keys. The
  attempts nest linearly, so a union of members with optional keys costs one
  attempt each, never one per combination of absent keys.
- `bs_emit`: a validator whose type can reach such a field returns its
  children's values and rebuilds its own from them (map update, tuple, list,
  map entries). A validator whose type cannot reach one returns the term it
  was handed, as before.
- `bs_emit`: `map_cases/1` no longer emits an `{any, []}` clause beside an
  untagged field set with nothing shared. It caught every map and refused it,
  the same refusal as the validator's last clause, and it stood in front of
  the fill attempts.
- `bs_emit`: `ToJson`'s guard calls a strict twin of each validator that
  can fill (`bs@validate@N@s`): the validator as it was emitted before this
  feature, calling strict twins where its children can fill and the shared
  validators where they cannot. A validator that can fill is emitted only
  where a `ValidateAs` reaches it, so a type `ToJson` alone names leaves no
  unused function. Found by the `/code-review`: a first version detected a
  fill after the fact and blamed the root, so `ToJson<list<R>>` lost the
  `["[0]"]` it had before.

Measured against master (`ad451c3`) by comparing the `.abstr` `bsc -o`
writes: the 19 examples that compile singly are identical, and so are
validators over a record union, a domain map, a tuple union and a list of
records. Field-set validators differ only by the deleted `{any, []}` clause,
with no line added. `ToJson` over a record with an `option` field emits
master's forms, function for function, once the `@s` suffix is removed.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F61.1 | `ValidateAs<{ Id: option<string>, Model: string }>` on a map with no `Id`; with `Id = "x"` | `Id = :nothing` filled; returned unchanged |
| F61.2 | the same over `record R { Id: option<string>, Model: string }` | `Id = :nothing` filled, `Kind` kept |
| F61.3 | `Id => :null` at `option<string>`; at `option<string \| :null>`, `null` and absent | refused, `Expected = ":nothing \| string"`, `Path = [".Id"]`; `:null` kept, absent filled |
| F61.4 | an absent key under a record field, a list element, a tuple component, a map value | filled at that depth |
| F61.5 | an absent `atom` field; an absent required key; an exact set with an unknown key beside an absent option | each refused, `Path = []` |
| F61.6 | the program above on TypeSafe's reply and OpenRouter's | `"id" => :nothing`, extras kept; the string kept |
| F61.7 | a union of two exact members, each with an option key, on a value only the second one's fill admits | filled by the second member |
| F61.8 | `ToJson<R>` handed an `R` with no `Id`; `ToJson<list<R>>` with one | crashes `{to_json, ValidationError}`, `Path = []`; `Path = ["[0]"]`, as before |

## Out of scope

- `FromJson<T>` ([ENG-410](https://linear.app/davewil/issue/ENG-410)), which
  gets this conversion by calling `ValidateAs`.
- What `ToJson` writes for `:nothing`: F50.2's `"nothing"`, key present.

## Done when

The scenarios pass, `check-absent-option.sh` is seen red on master and green
after, and `./bin/verify.sh` is green twice from a clean clone.
