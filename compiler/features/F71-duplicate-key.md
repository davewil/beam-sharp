# F71 — `FromJson` refuses a repeated key, and text after the value

**Status**      **in progress** — built 2026-10-09, 18 tests in `duplicate_key_tests`;
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
- `Path` is `[]` however deep the object sits: the decoder's callback is handed an
  object's pairs and not where the object is.
- The same key in two different objects is not a repeat.
- Two spellings of one key are one key: `"a"` and `"\u0061"` repeat each other.
- The repeat is found during the decode, before `T` is consulted, so it is reported
  ahead of anything a validator would say.
- Text after the value is `:not_json`, as it was under F69. JSON's whitespace after the
  value, a space, tab, line feed or carriage return, is accepted.

## What changed

- `bs_emit:text_form/1` no longer decodes. It calls `bs@validate@decode/1`, emitted once
  into a module that reads text, and hands what that returns to the root validator.
- `bs_emit:decode_forms/0` is that function and its three helpers. It calls `json:decode/3`
  where F69 called `decode/1`, with one callback, `object_finish`. The decoder collects an
  object's pairs as `decode/1` does. `bs@validate@finish/2` builds the map when the object
  closes, and a map smaller than its pairs held a repeat. Only then does
  `bs@validate@recur/2` walk the pairs in the text's order for the first key to arrive a
  second time, and the raise carries it, under the catch that already turned the decoder's
  errors into `:not_json`.
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
- **An object is checked when it closes** (David, 2026-10-10, point 3 below). Text that
  repeats a key and never closes the object, `{"a":1,"a":"x",`, is `:not_json`. With
  repeats in two objects, the one reported is in the object that closes first:
  `{"x":1,"x":2,"in":{"a":1,"a":2}}` names `"a"`. Within one object it is the first key to
  arrive a second time.
- **The check costs nothing measurable.** The first build looked each key up in a map as
  it arrived, and the review measured that at several times `decode/1` on one very wide
  object. The table under point 3 has the figures for both forms; they were taken on the
  same logic written by hand in Erlang, not on the generated function.

## Four points put to David — 2026-10-10

Each with what the first build did, what the other answer would do, and a recommendation.
**Answered 2026-10-10 (David): all four as recommended.** Points 1, 2 and 4 stand as
built; point 3 was changed the same day.

1. **A repeated key holding `"` is written raw.** `{"a\"b":1,"a\"b":2}` reports
   `Expected = ""a"b" once"`; escaped as the type prints it would be `""a\"b" once"`. In
   the same module a named key's path segment is escaped and an unknown key's is raw. The
   other answer is one generated escape function, called here, where F70 names an unknown
   key and where F43 names a map entry. Recommended: keep raw; changing all three places
   is its own issue.
2. **A repeat is reported before a wrong shape.** `{"b":1,"b":2}` against `{ "a": int }`
   is `:duplicate_key` for `"b"`. Reporting `:missing` for `"a"` first would mean keeping
   one of the two values, validating a map known to be wrong, and reporting the repeat
   only if that passed. Recommended: keep.
3. **The check cost time on every decode, and need not.** Measured in microseconds per
   decode, for `json:decode/1` (F69), this build, and a form that lets the decoder collect
   an object's pairs and compares their count with the finished map's size when the object
   closes:

   | Body | F69 | the first build | checked at the end |
   |---|---|---|---|
   | 25f's reply, 442 bytes | 13.2 | 16.6 | 13.4 |
   | 20,000 rows of 4 keys, 1.1 MB | 44,226 | 46,668 | 44,003 |
   | one object of 300,000 keys, 4.6 MB | 108,935 | 295,579 | 107,058 |

   Two things differ for a program. Text that repeats a key and never closes the object,
   `{"a":1,"a":"x",`, is `:not_json` where the first build said `:duplicate_key`. (Put to
   David as `{"a":1,"a":2`, which the first build already called `:not_json`: the decoder
   registers a pair only at the next `,` or `}`. The review caught it.) With two repeats
   in one body, the one reported is the one whose object closes first. Recommended:
   change to the check at the end.
4. **The decode is one generated function per module**, where ENG-617 says `text_form`
   calls the decoder *"under the catch that is already there"*. No program can tell the
   two apart. Recommended: keep.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F71.1 | `Read` on `{"a":1,"a":"x"}`; on `{"a":"x","a":1}` | `Path = []`, `Expected = "\"a\" once"`, `:duplicate_key`, both |
| F71.2 | the repeat in a nested object; in a list element; one key in two objects | the same value, `Path = []`; the same; accepted |
| F71.3 | `{"a":1,"a":1}`; an open type given `cost` twice; `"a"` then `"\u0061"` | all three refused |
| F71.4 | a `switch` arm on `ValidationError { Reason: :duplicate_key, Expected: e }` | binds `"\"a\" once"` |
| F71.5 | `{"a":1} x`; two values; `12x`; a `0xFF` byte after the value; a form feed after it | `:not_json` |
| F71.6 | whitespace before and after the value; `7` and `7\n` read as `int` | accepted |
| F71.8 | `{"a":1,"a":"x",`; repeats in an outer and an inner object; two repeats in one object; a repeat then text after the value | `:not_json`; the inner object's key; the first to recur; `:duplicate_key` |
| F71.7 | exemplar 25f, served a good reply with `"model"` a second time | `(:error, (:malformed, ValidationError { Path = [], Expected = "\"model\" once", Reason = :duplicate_key }))` |

## Done when

The scenarios pass, `check-duplicate-key.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-09

Before the build, `duplicate_key_tests` failed 9 of 14; the five that passed are F71.5 and
F71.6, which F69's `decode/1` already satisfied and which the move to `decode/3` must not
lose. `check-duplicate-key.sh` was red on D1, D2, D3 and D6: the first three printed the
value with the first `"a"` kept, and D6 printed a whole `Evaluation` for the reply with two
models. Its `--self-test` sees nine defects (`first_wins`, `last_wins`, `no_key`,
`unequal_only`, `prefix`, `strict_end`, `top_only`, `exemplar_only`, `on_arrival`) and accepts the correct outputs. F71.7 is D6:
`wayfinder/prototypes/25f_replay.erl` serves the reply and prints `repeated: ok`.

For the change to the check at the close, on 2026-10-10: F71.8's four tests were added
first, and two of them failed on the first build, the unclosed object and the inner
object's key. The gate's D7 came after the change, at the review's prompting, and was
then seen red against the first build's emitter.
