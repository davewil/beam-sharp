# F74 — `FromJson<T>` takes a `binary`

**Status**      **in progress** — built 2026-10-11, 14 tests in `from_json_binary_tests`;
                closing it is David's call
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q13 and Q23.
                Decides nothing; see *What the build found*
**Closes**      [ENG-611](https://linear.app/davewil/issue/ENG-611)
**Depends on**  F9 (`string` and `binary`), F69 (`FromJson`), F70 (`Reason`)

## Why this one now

An HTTP body is a `binary`, and `FromJson` took a `string`. So exemplar 25f validated the
body as a `string` and then decoded it, and the decoder checked the same bytes for UTF-8
a second time. A body that was not UTF-8 came back as `Expected = "string"`, a different
value from every other body that is not JSON.

## The program

```csharp
module Bodies

type ReplyWire = { "model": string, .. }

public result<ReplyWire, ValidationError> Parse(binary body)
Parse(body) -> FromJson<ReplyWire>(body)

public result<ReplyWire, ValidationError> ParseText(string body)
ParseText(body) -> FromJson<ReplyWire>(body)
```

```
$ bsc Bodies Parse '"{\"model\":\"jev\"}"'
{"model" = "jev"}
$ bsc Bodies Parse '<<255>>'
(:error, {Kind = :'ValidationError', Expected = "JSON", Path = [], Reason = :not_json})
$ bsc Bodies Parse '<<"{\"model\":\"",255,"\"}">>'
(:error, {Kind = :'ValidationError', Expected = "JSON", Path = [], Reason = :not_json})
$ bsc Bodies Parse '"{\"model\":7}"'
(:error, {Kind = :'ValidationError', Expected = "string", Path = ["["model"]"], Reason = :mismatch})
$ bsc Bodies ParseText '"{\"model\":\"jev\"}"'
{"model" = "jev"}
```

Before this feature the module did not compile: *"Parse hands FromJson an argument it
does not accept … `binary \ string`"*.

## The rule

- `FromJson<T>(text)` takes a `binary`. A `string` is a `binary`, so every call that
  compiled still does, and returns what it returned.
- Bytes that are not UTF-8 are text that is not JSON: `Path = []`, `Expected = "JSON"`,
  `Reason = :not_json`. That holds for a stray byte before or after the value, and for
  one inside a JSON string in an otherwise well-formed object.
- What is read is typed as before. A `string` position read from a `binary` body is a
  `string`: the decoder has checked it.
- An argument that is not a `binary` is refused as before, `arg_not_accepted`, and the
  refusal prints the part that is not one: `binary | int` prints `int`.
- The target `T` is checked as it was. `FromJson<binary>` is still refused: JSON has no
  bytes, only strings.

## What changed

- `bs_check`'s `type_of` clause for `FromJson` checks the argument against
  `bs_types:binary_top()` where it checked `bs_types:string()`. Nothing else in the
  compiler changed, and no generated code did.

## What the build found

- **Q23's "compiler delta: none" held.** The generated decoder already ran
  `json:decode/3` under a catch that turns any raise into `:not_json`, and OTP's decoder
  raises on a byte that is not UTF-8. A function declared over `string` and called from
  Erlang with `<<255>>` returned this value before the build.
- **`ValidateAs<string>(body) |?> FromJson<T>()` still compiles**, and for bytes that are
  not UTF-8 it still returns the first stage's error, `Expected = "string"` with
  `Reason = :mismatch`. A program that wrote the workaround keeps its old value until
  the stage is deleted.
- **A UTF-8 byte-order mark is refused** as `:not_json`, from a `binary` and from a
  `string`: OTP's decoder does not skip one, and the generated decoder is the one F71
  left. RFC 8259 lets a parser ignore it. Not asked by any ticket, and not changed here.
- **Exemplar 25f's `Parse` is one stage.** The replay gains a ninth case, a reply whose
  `"model"` holds the byte `0xFF`: with the old `Parse` it was `Expected = "string"`,
  `:mismatch`, and it is now `:not_json`.
- **One existing test changed, as ENG-611 said it would.** F69.8's
  `the_text_must_be_a_string_test` asserted that a `binary` argument is refused. It is
  `the_text_must_be_a_binary_test` and hands `FromJson` an `int`. The suite's other
  tests passed unmodified.

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F74.1 | `FromJson<W>(body)` for a `binary` body and a `string` one; six texts each refused for its own reason, through both | the value from both; the same error from both |
| F74.2 | the byte `0xFF` alone, after the value, before it; a key cut off inside a two-byte character; `0xFF` inside a JSON string; a three-byte character short a byte; a whole two-byte character; a byte-order mark before the value | `:not_json` at `[]` expecting `JSON`, each; the two-byte character is read; the mark is `:not_json`, from a `binary` and from a `string` |
| F74.3 | a clause that binds a `string` field read from a `binary` body and builds a string from it | compiles, and returns the string |
| F74.4 | `body \|> FromJson<W>()`; `body \|?> FromJson<W>() \|?> Held()` over a `result<binary, ValidationError>`; `ValidateAs<string>(body) \|?> FromJson<W>()`, the form written before | the value; `:not_json` for `0xFF`; an earlier error passed through; compiles, and `0xFF` is the first stage's `Expected = "string"` |
| F74.5 | an `int` argument; a `term`; an `option<binary>`; `binary \| int` | `arg_not_accepted`, each; the refusal prints `int` |
| F74.6 | `FromJson<binary>` over a `binary` body | `undecodable_member`, `binary`, as before |
| F74.7 | exemplar 25f, `Parse(body) -> FromJson<ReplyWire>(body) switch { … }`, served a reply whose `"model"` holds `0xFF` | `(:error, (:malformed, ValidationError { Path = [], Expected = "JSON", Reason = :not_json }))` |

## Done when

The scenarios pass, `check-from-json-binary.sh` is seen red before the build and green
after, and `./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-10-11

Before the build, `from_json_binary_tests` failed 8 of its first 12 (the byte-order mark
and the two-stage form came from the review, and load the same module): the seven that load the
module, which did not compile, and the refusal's wording, which printed
`int | binary \ string` and not `int`. The four that passed assert a refusal
that stands (`int`, `term`, `option<binary>`, and the `binary` target).
`check-from-json-binary.sh` was red on B1 to B4, whose module did not compile, and on
B6, which the replay did not yet print. With the compiler changed and the exemplar not
yet, B6 was red alone: `not utf-8: WRONG … 'Reason' => mismatch … 'Expected' =>
<<"string">>`. Its `--self-test` sees seven defects (`refused`, `text_refused`,
`crashes`, `as_string`, `call_only`, `anything`, `exemplar_only`), and accepts the
correct outputs. `refused` is red on five cases and `crashes` on B3 and B6, since a
decoder that raises does so in the exemplar too; the other five are each required to be
red on one case alone. F74.7 is B6:
`wayfinder/prototypes/25f_replay.erl` serves the reply and prints `not utf-8: ok`.
