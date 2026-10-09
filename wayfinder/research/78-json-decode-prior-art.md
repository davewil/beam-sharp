# JSON decoding into typed values: prior art

Research for [ticket 78](../issues/78-the-decode-direction.md), asked for by David on 2026-10-09
after F69 built `FromJson<T>` and round 7 put four questions to him. Decoding JSON off the wire is
a very common thing for a program to do, so the questions were held until this was in.

This file is evidence, not a decision. It changes no ticket's answer.

## What was surveyed, and how far to trust it

Five surveys, one file each, in [`78-json-decode-prior-art/`](78-json-decode-prior-art/). Each
answers the same nine questions per library and carries its own source list. A claim there is
either measured in the session, copied from a page or source file fetched in the session, or
marked *unverified, from memory*.

| Survey | Libraries | Measured or read |
|---|---|---|
| [`beam.md`](78-json-decode-prior-art/beam.md) | OTP `json`, jsx, jiffy, thoas, jsone, jesse, Jason, Elixir `JSON`, Poison, Ecto changesets, Zoi, Peri, ex_json_schema, NimbleOptions, JsonXema, Norm, Drops, Gleam `decode` and `gleam_json` | **Measured** on OTP 28.5 and Elixir 1.19.5. Gleam is not installed: read from source |
| [`ts-python.md`](78-json-decode-prior-art/ts-python.md) | `JSON.parse`, Zod 3 and 4, Valibot, io-ts, Effect Schema 3 and 4, ArkType, Ajv and TypeBox, Standard Schema, Pydantic 2, msgspec, cattrs, `json.loads` | **Measured**, every library |
| [`go-rust-swift.md`](78-json-decode-prior-art/go-rust-swift.md) | Go `encoding/json` v1 and v2, go-playground/validator, serde and serde_json, Swift `Codable` | Rust **measured**. Go and Swift are not installed: read from source |
| [`dotnet-jvm.md`](78-json-decode-prior-art/dotnet-jvm.md) | System.Text.Json, Newtonsoft.Json, Thoth.Json, FSharp.SystemTextJson, Jackson 2 and 3, Gson, kotlinx.serialization | **Nothing measured**: the machine has a .NET runtime and no SDK. Read from docs and source |
| [`ml-standards.md`](78-json-decode-prior-art/ml-standards.md) | Elm, aeson, yojson with both OCaml derivers, sury, circe; RFC 8259, 7493, 6901, 9535, 9457, 9413; Bishop Fox, OWASP, Fowler, Protobuf, GitHub's API rules | Nothing measured. Read from source and the RFC texts |

The probe scripts and their raw output are in
[`78-json-decode-prior-art/probes/`](78-json-decode-prior-art/probes/), including one for B# itself.

Each survey ends with its own list of what it could not verify. Three gaps matter most:

- **C# is the language B# borrows its syntax from, and it is the one survey with no measurement.**
  Its error text is copied from resource strings with the placeholders left in.
- **Go v2's release status is unresolved.** The Go 1.27 release notes list `encoding/json/v2` as
  shipped; the source file at the `go1.27.0` tag still carries the experiment build tag.
- **Gleam's reason for replacing its first decoder API was not found** in any official text. The
  reasons quoted come from the README of the library the new API credits.

## Where `FromJson<T>` stands today

Measured at `cdbe91b` with [`probes/bsharp/run.sh`](78-json-decode-prior-art/probes/bsharp/run.sh).

```csharp
type W = { "a": int }
type F = { "a": float }
type A = { "type": "choice", "choice": string, .. }
       | { "type": "score", "score": int, .. }
type L = { "xs": list<W> }
```

| Input | Target | Result |
|---|---|---|
| `{"a":1,"a":2}` | `W` | `{"a" = 1}` |
| `{"a":1,"a":"x"}` | `W` | `{"a" = 1}` |
| `{"a":"x","a":1}` | `W` | error, `Path = ["[\"a\"]"]`, `Expected = "int"` |
| `{"a":1} x` | `W` | error, `Path = []`, `Expected = "JSON"` |
| `{"a":1.0}`, `{"a":1e2}` | `W` | error at `["a"]`, `Expected = "int"` |
| a 30-digit integer | `W` | read exactly |
| `{"a":1,"b":2}` | `W` | error, `Path = []`, `Expected = "{ \"a\": int }"` |
| `{}` | `W` | error, `Path = []`, `Expected = "{ \"a\": int }"` |
| `{"a":null}` | `W` | error at `["a"]`, `Expected = "int"` |
| `{"a":1}` | `F` | error at `["a"]`, `Expected = "float"` |
| `{"type":"choice"}` | `A` | error, `Path = []`, `Expected` is the whole union |
| `{"type":"tri","choice":"x"}` | `A` | the same error |
| `{"type":"score","score":"x"}` | `A` | the same error |
| `{"xs":[{"a":1},{"a":"x"},{"a":"y"}]}` | `L` | one error, at `["xs"][1]["a"]` |

## Findings, by question

### 1. Unknown keys

Three defaults exist, and the survey found all three.

- **Drop them.** Zod, Valibot, Effect Schema, Pydantic, msgspec, cattrs, Ecto, Zoi, Peri, Poison,
  sury. The key is accepted and is not in the result.
- **Ignore or keep them.** System.Text.Json, Newtonsoft, Thoth, Go v1 and v2, serde, Elm, aeson,
  circe, Gleam ignore them; ArkType, io-ts and raw JSON Schema keep them in the value.
- **Reject them.** kotlinx.serialization, both OCaml derivers, Jackson 2, and ProtoJSON's
  specification.

Rejecting by default is the minority, and it has moved one way. Jackson 2 rejected, Spring switched
that off in every mapper it builds, and Jackson 3 changed the default to ignore. Go's v2 reversed
four lenient v1 defaults and kept this one on purpose. msgspec gives the reason outright: schema
evolution. GitHub's API rules list "adding a response field" as a non-breaking change, so a client
that rejects unknown keys breaks on a routine deploy of the service it calls.

The security sources do not argue the other way. Bishop Fox's interoperability paper is about
duplicate keys, number precision and lenient syntax. OWASP's mass-assignment harm comes from
*binding* unknown input to a program's fields, which a decoder working from a declared type does
not do. RFC 9413 condemns tolerating malformed input and, in the same section, endorses a
specified rule for ignoring unknown elements. RFC 7493 says unrecognised members "MUST be ignored".

Three details bear on B#'s `..`:

- **Strict is always per type where it exists** (`z.strictObject`, `deny_unknown_fields`,
  `[@@yojson.allow_extra_fields]`), which is what an exact type beside an open one is.
- **A decoder more lenient than its encoder is ordinary.** aeson, serde and Swift all read what
  they would not write.
- **Several libraries give the extras a type.** Zod has `.catchall(schema)`, Valibot
  `objectWithRest`, Pydantic an annotated `__pydantic_extra__`, serde a flattened map. Effect
  Schema 4 removed its untyped "preserve" option so that extras must be "represented in the
  schema's type".

No library surveyed refuses to *read* into a type that tolerates extra keys.

### 2. A missing required field

The libraries split on where the error points, and the split follows the kind of library.

- **At the missing key.** Zod, Valibot, ArkType, Effect Schema, Pydantic, cattrs, Gleam, Zoi,
  Peri, Drops, circe. These return errors as values.
- **At the enclosing object, with the key named in the message.** System.Text.Json,
  kotlinx.serialization, Thoth, serde (even with its path add-on), aeson, Elm, Ajv, jesse,
  ex_json_schema, msgspec, ppx_yojson_conv. JSON:API's rule that a pointer "MUST point to a value
  in the request document that exists" lands here too.

Swift keeps the two apart structurally: `keyNotFound(key, context)`, where the context's path is
the object's.

A second split matters more for `{ Path, Expected }`. Some libraries make "missing" its own kind:
ArkType (`was missing`), Effect (`Missing`), Pydantic (`type: missing`), Ajv (`required`), msgspec,
circe (`MissingField`), Zoi (`:required`), Swift. Others report it as a wrong value: Zod and
Valibot say "received undefined", io-ts "Invalid value undefined", and Gleam uses the strings
`expected: "Field", found: "Nothing"`. In the second group a caller cannot tell an absent key from
a present one holding the wrong thing.

System.Text.Json, kotlinx.serialization and ppx_yojson_conv name every missing field of the object
in one error.

### 3. One error or all of them

- **First error only:** every serialiser that throws (System.Text.Json, Newtonsoft, Jackson, Gson,
  kotlinx, serde, Swift, aeson, Elm outside `oneOf`), and by default Effect Schema, Ajv, msgspec
  and jesse.
- **All errors:** Zod, Valibot, ArkType, io-ts, Pydantic, Ecto, Zoi, Peri, cattrs. circe offers it
  as a second entry point. Gleam collects across one record's fields and stops at the first bad
  list element.

The HTTP conventions for reporting a bad request body all carry a list: RFC 9457's example,
JSON:API's `errors`, FastAPI's `detail`. aeson's maintainers declined to add accumulation, one
reason being that untrusted input should fail fast.

Ticket 15 modelled `ValidationError` on Gleam's decoder error. Gleam's decoders return a list of
them.

### 4. A union that fails

This is the weakest area in every ecosystem, and the clearest finding of the survey.

A union the library cannot discriminate gives its worst error:

| Library | The error for a tagged member with one key missing |
|---|---|
| serde, untagged | `data did not match any variant of untagged enum Unt`, no position |
| Zod `z.union` | `Invalid input` at `[]`, with three nested issue lists |
| Valibot `union` | `Invalid type: Expected Object but received Object` |
| Ajv `anyOf` | seven flat errors across all branches |
| Pydantic, smart mode | six errors, each path prefixed with a member's class name |
| Gleam `one_of` | the first alternative's errors only |
| aeson `<\|>`, Zoi `union` | the last alternative's error only |

A union the library dispatches on a tag gives a good one:

| Library | Known tag, key missing | Unknown tag |
|---|---|---|
| ArkType | `url must be a string (was missing)` | `type must be "tool", "text" or "image" (was "video")` |
| Effect Schema 3 | `["url"]` is missing | `["type"]` expected `"text" \| "image" \| "tool"`, actual `"video"` |
| Zod `discriminatedUnion` | one issue at `["url"]` | at `["type"]`, expected `'text' \| 'image' \| 'tool'` |
| Valibot `variant` | one issue at `["url"]` | at `["type"]`, expected the three literals |
| Zoi `discriminated_union` | `is required` at `["r"]` | `unknown discriminator 'tri' for field 't'` |
| serde, internally tagged | ``missing field `r` `` | ``unknown variant `Triangle`, expected `Circle` or `Square` `` |
| aeson `TaggedObject` | `key "x" not found` | `expected tag field to be one of [...]`, at the tag key |
| Jackson | the ordinary error | `Could not resolve type id`, listing the known ids |

**ArkType, Effect Schema 3 and io-ts find the tag themselves**, from literal-typed fields in a
plain union, with no separate constructor; all three measured. cattrs documents the same and was
not measured. ArkType's 2.0 announcement puts it as "all unions are optimally discriminated". That
is the nearest prior art to B#, which has string-literal types (F68) and already decides whether
two members can be told apart (ticket 70).

`FromJson` today behaves like the first table. The last three rows of the B# measurements return
the same error: the whole union, at the top.

Two traps other libraries fell into:

- **A default member.** Gleam's own documented example ends `_ -> trainer_decoder`, so an unknown
  tag decodes as one of the known members. System.Text.Json does the same for a missing tag on a
  concrete base type.
- **The tag must come first.** System.Text.Json required it until .NET 9, because it reads as a
  stream. `FromJson` decodes to a map before it validates, so it cannot have this fault.

### 5. `null`, an absent key, and optional

The designs that held up keep "the key may be absent" apart from "the value may be null": Effect
Schema, ArkType, msgspec's `UNSET`, kotlinx.serialization, Gleam, Zoi, Zod. The ones that fused
them had to break compatibility to undo it (Pydantic 2, where `Optional[X]` stopped implying a
default; Gleam's `optional_field`), or still conflate them (Go, serde's `Option`, Swift, aeson's
and circe's derived decoders, Ecto, Peri).

Ticket 78 Q8 already put B# in the first group: an absent key at an `option<T>` field is
`:nothing`, and `null` stays `:null`.

### 6. What goes in: text or bytes

The parsers take bytes. OTP `json` takes a binary and nothing else. Go takes `[]byte`, Swift takes
`Data` only, aeson's main entry point takes a `ByteString`, serde has `from_slice` beside
`from_str`, System.Text.Json reads UTF-8 spans, Pydantic and msgspec take `str | bytes`. Gleam has
a separate `parse_bits`.

Invalid UTF-8 is where they differ:

- **Go v1 silently replaced it** with U+FFFD. v2 reverses that, calling it "data corruption that
  can be difficult to detect until it is too late". jsx, jsone and Poison accept it by default.
- **msgspec and Python's `json` raise a different exception class** for it, outside the decode
  error.
- **Pydantic reports it as its JSON error**, `json_invalid`. serde files it under `Syntax`.
- **OTP `json` rejects it** as `{invalid_byte, 255}`, measured.

### 7. Duplicate keys

`FromJson` accepts `{"a":1,"a":"x"}` against `{ "a": int }`. It inherits this from OTP's
`json:decode/1`, which keeps the first value and never shows the second to the validator.

The silent parsers disagree with each other, which is the fault:

- **First wins:** OTP `json`, Elixir `JSON`, Jason, Poison, thoas, jsone, aeson, Swift.
- **Last wins:** `JSON.parse`, Python's `json`, Pydantic, msgspec, Go v1, serde's maps, jsx, jiffy
  maps, System.Text.Json, Newtonsoft.
- **An error:** Go v2, serde for a struct, ppx_yojson_conv. System.Text.Json since .NET 10 and
  Jackson as options.

Bishop Fox's attack needs exactly this: one service validates the first value and another acts on
the last. Its first recommendation to parser authors is "Generate fatal parse errors on duplicate
keys". RFC 7493 says objects "MUST NOT have members with duplicate names". Go's v2 announcement
cites CVE-2017-12635 as an exploit of it. .NET 10's notes call last-wins a source of "security
vulnerabilities".

OTP's `json:decode/3` takes callbacks, and an `object_finish` callback sees every pair, so a
duplicate can be detected without a second parser. Measured in `beam.md`.

### 8. Numbers

JSON has one number type. Whether `1` is an integer and `1.0` a float is the decoder's choice.

- **`FromJson` refuses `1` at a `float` field** and `1.0` at an `int` field. 25f's wire types
  write `int | float` at each number that may arrive either way.
- **Gleam has the same behaviour and an open issue against it** (stdlib 801), because JavaScript
  writes the float `1.0` as `1`.
- **serde accepts `1` for a float and refuses `1.0` for an integer.** Pydantic in strict mode and
  msgspec refuse `1.0` for an integer too.
- **The JavaScript-backed validators cannot tell them apart at all**, and round integers above
  2^53 before the validator runs. JSON Schema validators accept `1.0` as an integer.

Large integers are exact in `FromJson`, as in Python and aeson. aeson took a denial-of-service
advisory in 2026 for parsing numbers with huge exponents. OTP refuses `1E400`.

### 9. "Not JSON" and "wrong shape"

`FromJson` returns one type for both, and the only thing that separates them is the string
`Expected = "JSON"`.

- **Distinct by type or code:** circe (`ParsingFailure`, `DecodingFailure`), Newtonsoft, Jackson,
  Gson, Go, serde (`Category::Syntax | Data | Eof`), Gleam (four variants, one of them
  `UnableToDecode`), Pydantic (`json_invalid`).
- **Distinguishable only by message text:** System.Text.Json, Elm, aeson, Thoth.

OTP's error terms carry no position; the byte offset is only in the stack trace. Two of its
reasons mislead: `{"a":1} x` raises `{invalid_byte, 32}`, the space and not the `x`, and a lone
`"\ud800"` raises `unexpected_end`.

### 10. The error's shape

Ticket 79 decided `ValidationError` is `{ Path: list<string>, Expected: string }`, and left
"`found`" open.

- **Path.** A list of segments with keys and indexes kept apart is what Swift, Zod, Valibot,
  Pydantic, Zoi and Standard Schema use, and it converts to JSON Pointer (RFC 6901, what HTTP error
  conventions use) or to `$.a[0]`. B#'s segments are already rendered: `"[\"model\"]"`, `"[1]"`.
  Gleam stringifies indexes the same way.
- **Paths that are not data paths.** io-ts puts union member indexes in the path, and Pydantic
  puts member class names or tag values there.
- **Expected.** A field of its own in Gleam, circe, Zod, Valibot, ArkType, Go and Swift; prose
  inside the message in the rest. Standard Schema, the interface the Zod, Valibot and ArkType authors agreed on, kept only
  `{ message, path }`.
- **Found.** ArkType (`was missing`), Peri, Zod and Valibot report it. Gleam reports the runtime
  class name and never the value. Pydantic echoes the input value.
- **Wording.** Go v2 randomises one word of its error text per process so that callers cannot
  match on it.

### 11. Where the decoder comes from

Derived from the type declaration: serde, System.Text.Json, kotlinx.serialization, Swift, aeson's
generics, both OCaml derivers, circe, Pydantic, msgspec. Written by hand: Elm, Gleam, Thoth. Elm's
author calls derived decoders "a siren design"; Elm still derives one at flags and ports, and its
guide says many users avoid that to get an error they can handle.

**Nothing on the BEAM derives a decoder from a type.** Gleam writes it by hand, Ecto restates the
field list in the changeset, and Zoi derives a typespec from the schema, the other way round.
Poison's `as:` looks like it and checks nothing: `{"name":42}` decodes into a struct whose `name`
is `42`.

Naming a type in the payload is the recurring security fault: Newtonsoft's `TypeNameHandling`, and
Jackson's default typing, whose block list reached about ninety classes before version 2.10
replaced it with an allow list. Every later design resolves a tag against a closed, declared set.
A B# record's `Kind` is a type name in the payload, resolved against the one `T` the call names.
That bears on ticket 78 Q4 when it reopens.

### 12. The defaults that were regretted

- **Go v2** reverses case-insensitive key matching, last-wins duplicates, repaired UTF-8 and
  trailing data accepted by `Decoder.Decode`. The 2016 request to fix the first was answered "too
  late to change the defaults"; it took a second package.
- **System.Text.Json** added required members (.NET 7), unknown-member rejection (.NET 8),
  null enforcement and required constructor parameters (.NET 9) and duplicate rejection (.NET 10),
  each opt-in "to avoid breaking existing applications", then bundled them as
  `JsonSerializerOptions.Strict`.
- **Jackson 3** changed three decode defaults at once: unknown properties, `null` into a
  primitive, trailing tokens.
- **Go has no required fields**, in v1 or v2. A missing field is a zero value, so the validation
  library's `required` means "not zero" and rejects `false` and `0`.
- **Pydantic 2** broke compatibility to stop coercing, after "people have long complained".

The pattern: leniency about malformed or ambiguous input was regretted and could not be withdrawn.
Leniency about unknown keys was not regretted.

## What this says to ticket 78's round 7

- **Q11, an open type as a `FromJson` target.** Supported without exception. Every surveyed library
  can read into a type that tolerates extra keys, and a decoder more lenient than its encoder is
  normal. The typed-rest form (finding 1) is a possible later spelling for `..` and is not needed
  to answer Q11.
- **Q12, blaming an absent required key at its own path.** Precedent exists both ways (finding 2).
  The libraries that return errors as values, which is what B# does, put it at the key. But with
  only `Path` and `Expected`, an absent `"model"` and a `"model"` holding `7` would then produce
  the same value, which is the fault Zod and Gleam have. Q12 should not be answered apart from
  whether the error says *missing*.
- **Q13, `FromJson` taking a `binary`.** Supported (finding 6). The question waiting behind it,
  what bytes that are not UTF-8 report, has an answer in Pydantic and serde: the same error as any
  other text that is not JSON.
- **Q14** is not touched by this.

## What it raises that round 7 did not ask

Each is a finding above with a measurement behind it. None is decided, and none has been put to
David as a question yet.

1. **Duplicate keys are accepted silently** (finding 7). The one behaviour here that the security
   sources call a vulnerability.
2. **A failed tagged union is blamed at the top with the whole union** (finding 4). The type system
   already knows the tag.
3. **A `float` field refuses `1`** (finding 8), which is how JavaScript writes `1.0`.
4. **The error cannot say what kind of failure it is** (findings 2, 9, 10): not JSON, a missing
   key, an unknown key or a wrong value. Ticket 79 left `found` open; this is the same gap.
5. **One error, or a list** (finding 3). Ticket 15 decided one. `result<T, ValidationError>` is in
   every signature that calls `FromJson`, so this is cheapest to revisit before programs depend on
   it.
6. **An exact type reports an unknown key at the object, without naming it.** `{"a":1,"b":2}`
   against `{ "a": int }` returns the whole type at `[]`. Zod, Pydantic, ArkType, kotlinx and
   System.Text.Json all name the key.
