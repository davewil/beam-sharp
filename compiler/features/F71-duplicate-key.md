# F71 — `FromJson` refuses a repeated key, and text after the value

**Status**      **in progress** — built 2026-10-09, 14 tests in `duplicate_key_tests`;
                closing it is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q15 and Q20.
                Decides nothing; see *What the build found*
**Closes**      [ENG-617](https://linear.app/davewil/issue/ENG-617)
**Depends on**  F69 (`FromJson`), F70 (`Reason`)

## Why this one now

`FromJson<W>` over `{"a":1,"a":"x"}` returned `{ "a" = 1 }`. The second value was dropped
before any validator saw it. Parsers that accept a repeated key disagree about which value
they keep, so a body a proxy approved reading the first value is acted on by a service
reading the last. F70 put `:duplicate_key` in `ValidationError`'s `Reason`; nothing built
it.

## The program

```csharp
module Repeat

type W = { "a": int }

public result<W, ValidationError> Read(string body)
Read(body) -> FromJson<W>(body)

public result<list<W>, ValidationError> ReadAll(string body)
ReadAll(body) -> FromJson<list<W>>(body)
```

```
$ bsc Repeat Read '"{\"a\":1,\"a\":\"x\"}"'
(:error, {Kind = :'ValidationError', Expected = ""a" once", Path = [], Reason = :duplicate_key})
$ bsc Repeat ReadAll '"[{\"a\":1},{\"a\":1,\"a\":2}]"'
(:error, {Kind = :'ValidationError', Expected = ""a" once", Path = [], Reason = :duplicate_key})
$ bsc Repeat Read '"{\"a\":1} x"'
(:error, {Kind = :'ValidationError', Expected = "JSON", Path = [], Reason = :not_json})
$ bsc Repeat Read '"{\"a\":1} "'
{"a" = 1}
```

## The rule

- JSON in which one object names a key twice is refused: `Path = []`, `Expected` the key
  in quotes followed by ` once`, `Reason = :duplicate_key`. There is no form of the call
  that accepts it.
- It is refused whichever value is the wrong one, when the two are equal, and when the
  key is one an open type does not name.
- `Path` is `[]` however deep the object sits: the decoder's callback is handed the key
  and not where its object is.
- The same key in two different objects is not a repeat.
- Two spellings of one key are one key: `"a"` and `"\u0061"` repeat each other.
- The repeat is found during the decode, before `T` is consulted, so it is reported
  ahead of anything a validator would say.
- Text after the value is `:not_json`, as it was under F69. JSON's whitespace after the
  value, a space, tab, line feed or carriage return, is accepted.

## What changed

- `bs_emit:text_form/1` no longer decodes. It calls `bs@validate@decode/1`, emitted once
  into a module that reads text, and hands what that returns to the root validator.
- `bs_emit:decode_forms/0` is that function and its two helpers. It calls `json:decode/3`
  where F69 called `decode/1`, with three callbacks: an object starts as an empty map,
  `bs@validate@push/3` raises on a key the map already holds and adds it otherwise, and
  the finished map is the value. The raise carries the key, under the catch that already
  turned the decoder's errors into `:not_json`.
- `decode/3` returns the text it did not read, where `decode/1` refused it.
  `bs@validate@blank/1` accepts a remainder made of JSON's four whitespace bytes and
  nothing else.

## What the build found

- **`Expected` writes the key as decoded, without escaping.** A key holding `"` or `\`
  is written raw between the quotes, as F70 writes an unknown key's path segment. Q20's
  example has neither character, and no test here asserts one.
- **A repeat is reported ahead of a wrong shape.** `{"b":1,"b":2}` against `{ "a": int }`
  is `:duplicate_key` for `"b"`, not `:missing` for `"a"`, and a repeated key in text read
  as `int` is `:duplicate_key`, not a mismatch. Q15 says always, and the decode runs
  first.
- **The first repeat in the text is the one reported**, since the decode stops there.
- **Large objects decode more slowly.** The review measured a 300,000-key object, 3.2 MB,
  at 862 ms through the generated function against 148 ms through `json:decode/1`. The
  cost is one map insertion per key, which is how the push knows a key has been seen. A
  reply of ordinary size was not measured.
- **Text that ends inside the second value is `:not_json`.** The key is pushed once its
  value has been read, so `{"a":1,"a":` never reaches the push.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F71.1 | `Read` on `{"a":1,"a":"x"}`; on `{"a":"x","a":1}` | `Path = []`, `Expected = "\"a\" once"`, `:duplicate_key`, both |
| F71.2 | the repeat in a nested object; in a list element; one key in two objects | the same value, `Path = []`; the same; accepted |
| F71.3 | `{"a":1,"a":1}`; an open type given `cost` twice; `"a"` then `"\u0061"` | all three refused |
| F71.4 | a `switch` arm on `ValidationError { Reason: :duplicate_key, Expected: e }` | binds `"\"a\" once"` |
| F71.5 | `{"a":1} x`; two values; `12x`; a `0xFF` byte after the value; a form feed after it | `:not_json` |
| F71.6 | whitespace before and after the value; `7` and `7\n` read as `int` | accepted |
| F71.7 | exemplar 25f, served a good reply with `"model"` a second time | `(:error, (:malformed, ValidationError { Path = [], Expected = "\"model\" once", Reason = :duplicate_key }))` |

## Done when

The scenarios pass, `check-duplicate-key.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-09

Before the build, `duplicate_key_tests` failed 9 of 14; the five that passed are F71.5 and
F71.6, which F69's `decode/1` already satisfied and which the move to `decode/3` must not
lose. `check-duplicate-key.sh` was red on D1, D2, D3 and D6: the first three printed the
value with the first `"a"` kept, and D6 printed a whole `Evaluation` for the reply with two
models. Its `--self-test` sees eight defects (`first_wins`, `last_wins`, `no_key`,
`unequal_only`, `prefix`, `strict_end`, `top_only`, `exemplar_only`) and accepts the correct outputs. F71.7 is D6:
`wayfinder/prototypes/25f_replay.erl` serves the reply and prints `repeated: ok`.
