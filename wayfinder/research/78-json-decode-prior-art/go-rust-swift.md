# Prior art for `FromJson<T>(text)`: Go, Rust, Swift

Researched 2026-10-09. Read "measured" as: run in this session. Read a URL as: fetched in this session. Anything else is marked **(unverified, from memory)**.

## Method and what could be measured

- `which go cargo rustc swift` found only `/usr/bin/cargo` and `/usr/bin/rustc`. **Go and Swift are not installed, so nothing about them is measured.** Their error text below is copied from source files fetched from GitHub, and where a message is assembled from several source lines I say so.
- Rust: `cargo 1.98.1`, `rustc 1.98.1`. Crates fetched fine: `serde 1.0.229`, `serde_json 1.0.151`, `serde_path_to_error 0.1.20`. Probe: `probes/rust/src/main.rs`; full output in `probes/rust/out.txt` (`cargo run -q`, exit 0). Every Rust line tagged **[M]** is from that output.
- Source files read (all under `a scratch directory, not kept`), abbreviated below:
  - **[go-v1]** <https://raw.githubusercontent.com/golang/go/go1.25.0/src/encoding/json/decode.go>, `scanner.go`, `stream.go` in the same directory
  - **[go-diff]** <https://raw.githubusercontent.com/golang/go/go1.25.0/src/encoding/json/v2_diff_test.go> (the Go team's own "list of semantic differences between v1 and v2", each with a rationale)
  - **[go-migrate]** <https://raw.githubusercontent.com/golang/go/master/src/encoding/json/v2_options.go> ("Migrating to v2" doc comment)
  - **[go-v2doc]** <https://raw.githubusercontent.com/golang/go/go1.27.0/src/encoding/json/v2/doc.go>; **[go-v2err]** `errors.go` beside it
  - **[serde-de]** <https://raw.githubusercontent.com/serde-rs/serde/v1.0.229/serde_core/src/de/mod.rs>; **[sj-err]** <https://raw.githubusercontent.com/serde-rs/json/v1.0.151/src/error.rs>
  - **[sw-dec]** <https://raw.githubusercontent.com/swiftlang/swift-foundation/main/Sources/FoundationEssentials/JSON/JSONDecoder.swift>; **[sw-scan]** `JSONScanner.swift` beside it
  - **[sw-std]** <https://raw.githubusercontent.com/swiftlang/swift/main/stdlib/public/core/Codable.swift>; **[sw-derive]** <https://raw.githubusercontent.com/swiftlang/swift/main/lib/Sema/DerivedConformance/DerivedConformanceCodable.cpp>

---

## 1. Go `encoding/json` v1 (not measured)

```go
type User struct { Name string `json:"name"`; Age *int `json:"age"` }
var u User
err := json.Unmarshal(data, &u)
```

- **A. Unknown keys.** Ignored by default: "By default, object keys which don't have a corresponding struct field are ignored" (<https://pkg.go.dev/encoding/json>). Switchable only on a `Decoder`, not on `Unmarshal`: `DisallowUnknownFields` "causes the Decoder to return an error when the destination is a struct and the input contains object keys which do not match any non-ignored, exported fields" [go-v1 stream.go]. The error is an untyped `fmt.Errorf("json: unknown field %q", key)` [go-v1 decode.go:740], so a caller can only string-match it. No way to capture extras short of decoding twice into a `map[string]any` **(unverified, from memory)**.
- **B. Missing field.** No error; the field keeps its zero value **(unverified, from memory — the Unmarshal doc never states it, which is itself telling)**. There is no "required". The workaround is a pointer field checked for `nil` afterwards, which the `validator` maintainer also recommends (see §3).
- **C. Errors.** One error is returned, but decoding *continues* past type mismatches: "Unmarshal skips that field and completes the unmarshaling as best it can. If no more serious errors are encountered, Unmarshal returns an UnmarshalTypeError describing the earliest such error" (<https://pkg.go.dev/encoding/json>). So a failed decode leaves a half-filled value behind. Structure [go-v1 decode.go:127]:
  ```go
  type UnmarshalTypeError struct {
      Value  string       // description of JSON value - "bool", "array", "number -5"
      Type   reflect.Type // type of Go value it could not be assigned to
      Offset int64        // error occurred after reading Offset bytes
      Struct string       // name of the struct type containing the field
      Field  string       // the full path from root node to the field, include embedded struct
  }
  ```
  Text is built as `"json: cannot unmarshal " + e.Value + " into Go struct field " + e.Struct + "." + e.Field + " of type " + e.Type.String()` [go-v1 decode.go:137]. `Field` is a dotted Go-field path; array indexes are not in it **(unverified, from memory)**. No unions, so no alternative reporting.
- **D. null vs absent.** Conflated for most types: "unmarshaling a JSON null into any other Go type has no effect on the value and produces no error"; into "an interface, map, pointer, or slice" it sets nil (<https://pkg.go.dev/encoding/json>). A `*T` field is nil for both absent and `null`.
- **E. Input.** `[]byte` (or `io.Reader` via `Decoder`). Invalid UTF-8 is silently repaired: "invalid UTF-8 or invalid UTF-16 surrogate pairs are not treated as an error. Instead, they are replaced by the Unicode replacement character U+FFFD" (same page). Trailing data: `Unmarshal` rejects it (scanner string `"after top-level value"`, composed as `"invalid character " + quoteChar(c) + " " + context` [go-v1 scanner.go:333,595]); **`Decoder.Decode` does not** — `json.NewDecoder(r).Decode(&m)` on `{} bad data` returns no error (<https://github.com/golang/go/issues/36225>, "the Decoder.Decode API lends itself to misuse"). Duplicate keys: "later duplicates will replace or be merged into prior values" [go-v1 decode.go:52]. Keys match "ignoring case… an exact case match is preferred" [go-v1 decode.go:46]. Numbers: into `any` they become `float64`; `Decoder.UseNumber` yields `json.Number` instead; concrete integer types keep precision, and an out-of-range number is an `UnmarshalTypeError` with `Value: "number " + s` [go-v1 decode.go:1005].
- **F. Not-JSON vs wrong shape.** Distinct Go types: `*SyntaxError{msg, Offset}` (`"unexpected end of JSON input"`, `"invalid character 'x' looking for beginning of value"` [go-v1 scanner.go:173,251]) vs `*UnmarshalTypeError`. But unknown-field and several other errors are bare `fmt.Errorf`, so the taxonomy leaks; the v2 discussion lists "Inconsistent error values. Syntactic, semantic, and I/O errors cannot be reliably distinguished" as a v1 flaw (<https://github.com/golang/go/discussions/63397>).
- **G. Tagged unions.** Not applicable: Go has no sum types; users hand-write `UnmarshalJSON` that peeks at a discriminator via `json.RawMessage` **(unverified, from memory)**.
- **H. Derivation and symmetry.** Reflection over the struct plus `json:"…"` tags; the same tags drive both directions. Asymmetries: case-insensitive on decode but exact on encode; `omitempty` exists only for encode, nothing mirrors it as "required" on decode; nil slice encodes as `null` [go-migrate].
- **I. Complaints.** See §2 — the v2 change list *is* the list of regrets.

## 2. Go `encoding/json/v2` (`go-json-experiment/json`) — the regrets (not measured)

Status: experiment in Go 1.25 behind `GOEXPERIMENT=jsonv2` (<https://go.dev/blog/jsonv2-exp>). Proposal <https://github.com/golang/go/issues/71497> is closed, `Proposal-Accepted`, milestone Go1.27. The Go 1.27 release notes list "New encoding/json/v2 and encoding/json/jsontext packages" and say v1 "is now backed by the v2 implementation… the exact text of error messages may differ" (<https://raw.githubusercontent.com/golang/website/master/_content/doc/go1.27.md>). Current release per <https://go.dev/dl/?mode=json> is go1.27.2. Oddity I could not resolve: `v2/doc.go` at tag `go1.27.0` still opens with `//go:build goexperiment.jsonv2`.

Every decode-relevant behaviour v2 changed, with the stated reason:

| v1 | v2 | Stated reason | Source |
|---|---|---|---|
| Case-insensitive key match | Case-sensitive; opt in per field with `case:ignore`, or `MatchCaseInsensitiveNames` | "a surprising default and incurs significant performance cost"; the blog: "a surprising default, a potential security vulnerability, and a performance limitation". It "provides another vector through which duplicate names can occur" | [go-diff], blog, [go-v2doc] |
| Duplicate names allowed (last wins / merged) | Error (`jsontext.ErrDuplicateName`); `AllowDuplicateNames` to opt out | "a JSON value without a universally agreed upon meaning… has been exploited before (as in CVE-2017-12635)"; "difficult for a security tool to validate the semantic meaning"; RFC 7493 rejects them | blog, [go-diff] |
| Invalid UTF-8 replaced with U+FFFD | Error (`ErrInvalidUTF8 = "invalid UTF-8"`); `AllowInvalidUTF8` | "causes data corruption that can be difficult to detect until it is too late", and Hyrum's law then blocks tightening | [go-diff] |
| `Decoder.Decode` accepts trailing junk | `UnmarshalRead` "consumes the entire input until `io.EOF` and reports an error if any invalid tokens appear after the end of the JSON value" | #36225 | #71497 |
| Options only on `Decoder` | Variadic `Options` on every entry point, so `RejectUnknownMembers` works with `Unmarshal` | options could not be plumbed through | discussion 63397 |
| `null` into non-empty value "inconsistently either zero out the value or do nothing" | "consistently and always zero out" | consistency | [go-migrate] |
| Merge rules grew "organically" | Objects merge, everything else replaces (RFC 7396) | "inconsistent and difficult to explain" | [go-diff] |
| Go array accepts JSON array of any length | Length must match | "silent data loss when excess JSON array elements are discarded" | [go-diff] |
| `omitempty` defined on Go zero-ness | Defined on JSON emptiness; new `omitzero` for Go zero-ness ("no effect when unmarshaling") | define JSON behaviour in JSON terms | [go-migrate], #71497 |
| nil slice/map → `null` | → `[]` / `{}` | "avoid leaking such details to the JSON representation" | [go-diff] |
| `,string` on strings/bools, non-recursive, accepts quoted `"null"` | numbers only, recursive, no quoted null | 64-bit ints need quoting for other parsers; the rest was "surprising and inconsistent" | [go-diff] |
| Malformed tags / unserialisable structs silently accepted | Runtime error | "a common pitfall for new users" | [go-diff] |
| Errors hard to classify | `jsontext.SyntacticError` vs `json.SemanticError` vs wrapped I/O errors | see §1 F | discussion 63397 |

Also changed but encode-side only: map order non-deterministic, no HTML escaping, `[N]byte` as base64, `time.Duration` has no default form [go-migrate].

**Unchanged on purpose:** unknown members are still ignored by default ("both v1 and v2 ignore unknown names and their corresponding values" [go-v2doc]), and there is still **no notion of a required field** — #71497 "makes no statement about required fields" (my fetch found none). The v2 docs concede "care should still be taken with large integers or unknown members" [go-v2doc].

- **A.** Ignored; `RejectUnknownMembers` rejects with `ErrUnknownName = "unknown object member name"`, rendered `… : unknown object member name "zzz" within "/parent"` (assembled from [go-v2err] `Error()`). Capture: the 1.25 experiment had an `unknown` tag option [go1.25 doc.go:124]; the accepted proposal **removed it** — "semantically too similar to the existing `inline` tag option" (#71497) — and the shipped form is `embed` on a `map[~string]T` or `jsontext.Value` field, an "embedded fallback" [go-v2doc:109].
- **B.** Still zero value, no error (not stated anywhere I fetched; inferred from merge semantics).
- **C.** `SemanticError{ByteOffset, JSONPointer, JSONKind, JSONValue, GoType, Err}`; the pointer is RFC 6901, "to identify exactly where an error occurred" (#71497). Text is assembled as `json: cannot unmarshal JSON string into Go int within "/addrs/0/zip"`, and the verb is **deliberately randomised** per process between "cannot" and "unable to" to stop callers matching on it [go1.25 v2/errors.go:285–400]. Whether v2 still continues after the first mismatch: not found.
- **D.** null always zeroes; absent leaves the value alone. Still not distinguishable on a plain field.
- **E.** As the table. Numbers into `any` are still `float64` [go-v2doc].
- **F.** Distinct types, by design.
- **G.** Not applicable (no sum types; not found in the proposal).
- **H.** Same reflection-plus-tags model.
- **I.** The security framing cites Bishop Fox, which recommends parsers "Generate fatal parse errors on duplicate keys" and "Produce errors when handling integers or floating-point numbers that cannot be represented faithfully" (<https://bishopfox.com/blog/json-interoperability-vulnerabilities>). The original case complaint is <https://github.com/golang/go/issues/14750> (2016): "it is trivial to create valid JSON values that will be interpreted differently by different implementations"; rsc answered it was "too late to change the defaults". It took nine years and a v2.

## 3. Go validation layer and alternative decoders (not measured)

**`go-playground/validator`** — runs *after* decode on the filled struct.
```go
type Req struct { Active bool `json:"active" validate:"required"` }
```
- **B.** `required` "validates that the value is not the data types default zero value" (<https://pkg.go.dev/github.com/go-playground/validator/v10>). So `{"active": false}` fails exactly like `{}`. Issue <https://github.com/go-playground/validator/issues/142>: "I just want to validate that the property **exists**"; the maintainer's answer is `*bool`, "one way to give this third state". This is the cost of §1 B: presence is lost before validation starts.
- **C.** Returns **all** failures: `type ValidationErrors []FieldError`; each has `Namespace()`, `Field()`, `Tag()`, `Param()`, `Value()`, `Kind()`, `Type()`. Text: `"Key: '%s' Error:Field validation for '%s' failed on the '%s' tag"`, commented "not intended to be a production error message" (<https://raw.githubusercontent.com/go-playground/validator/master/errors.go>).
- A, D–I: not applicable (not a decoder).

**`tidwall/gjson`** — path queries, no typed decode. It "expects that the json is well-formed. Bad json will not panic, but it may return back unexpected results"; validate first with `gjson.Valid` (<https://github.com/tidwall/gjson>). Missing path → `Exists()` false. A–I otherwise not applicable.

**`goccy/go-json`** — "Drop-in replacement of `encoding/json`", including case folding "as with `encoding/json`" (<https://github.com/goccy/go-json>). No decode-semantic differences found.

**`json-iterator/go`** — `Config` has `CaseSensitive`, `DisallowUnknownFields`, `UseNumber`; `ConfigCompatibleWithStandardLibrary` "tries to be 100% compatible" while `ConfigDefault` sets only `EscapeHTML` (<https://pkg.go.dev/github.com/json-iterator/go>). So the same call can differ in strictness by which preset is imported. Field semantics undocumented on that page.

---

## 4. Rust `serde` + `serde_json` (measured)

```rust
#[derive(Deserialize)] struct Addr { city: String, zip: u32 }
#[derive(Deserialize)] struct User { name: String, age: u8, nick: Option<String>, addrs: Vec<Addr> }
let u: User = serde_json::from_str(text)?;
```

- **A. Unknown keys.** Ignored by default. **[M]** `{"a":1,"zzz":2}` → OK. With `#[serde(deny_unknown_fields)]`: **[M]** ``unknown field `zzz`, expected `a` at line 1 column 12``. Capture with `#[serde(flatten)] rest: BTreeMap<String, Value>`: **[M]** `rest: {"y": Array [Number(1)], "zzz": Number(2)}`. The two do not compose: "`flatten` is not supported in combination with structs that use `deny_unknown_fields`" (<https://serde.rs/attr-flatten.html>); open bug <https://github.com/serde-rs/serde/issues/1600> shows valid input being rejected.
- **B. Missing field.** Error unless `Option` or `#[serde(default)]`. **[M]** ``missing field `age` at line 1 column 23`` (column is the closing brace, not a path). Nested, **[M]** ``missing field `zip` at line 1 column 62`` — no indication *which* array element. Format string in [serde-de:290].
- **C. Errors.** First error only. **[M]** `{"name":5,"age":"old",…}` reports only ``invalid type: integer `5`, expected a string at line 1 column 9``. Shape is prose: `invalid type: {unexpected}, expected {expected}` or `invalid value: …` [serde-de:214,232], plus line/column; **no path**. Out of range: **[M]** ``invalid value: integer `300`, expected u8``. `serde_path_to_error` exists to add the path — "Find out the path at which a deserialization error occurred… exposes the chain of field names leading to the error" (<https://docs.rs/serde_path_to_error/latest/serde_path_to_error/>). **[M]** `addrs[0].zip: invalid type: string "q", expected u32 at line 1 column 50`. For a *missing* field its path stops at the parent: **[M]** ``addrs[1]: missing field `zip` ``.
  A surprise: **[M]** decoding `[1,2]` as `User` gives ``invalid type: integer `1`, expected a string at line 1 column 2`` — derived structs also accept a positional JSON array.
- **D. null vs absent.** Conflated for `Option<T>`: **[M]** `"nick":null` and no `nick` both give `None`. `null` for a non-option: **[M]** `invalid type: null, expected a string`. Plain `Option<Option<i32>>` does not help: **[M]** `{}` → `None`, `{"a":null}` → `None`, `{"a":1}` → `Some(Some(1))`. Distinguishing needs `serde_with::rust::double_option` plus `default` and `skip_serializing_if`, giving `None` = missing, `Some(None)` = null (<https://docs.rs/serde_with/latest/serde_with/rust/double_option/index.html>).
- **E. Input.** `from_str(&str)`, `from_slice(&[u8])`, `from_reader`; `from_reader` is "usually slower than reading a file completely into memory" (<https://docs.rs/serde_json/latest/serde_json/fn.from_reader.html>). Invalid UTF-8 via `from_slice`: **[M]** `invalid unicode code point at line 1 column 5`, category `Syntax`. Trailing data is always an error, all three entry points: **[M]** `trailing characters at line 1 column 9`. Duplicate keys depend on the target: struct → **[M]** ``duplicate field `a` at line 1 column 10``; `BTreeMap`, `Value` and a flattened map → **[M]** last wins silently. The maintainer declined to change the map case: "I think I'd prefer to stick with the current behavior" (<https://github.com/serde-rs/json/issues/762>). Keys are case-sensitive: **[M]** `{"A":1}` → ``missing field `a` ``. Numbers: **[M]** `18446744073709551615` → u64 OK; one more gives the confusing ``invalid type: floating point `1.8446744073709552e+19`, expected u64``; `1.0` into `u8` and `1e2` into `i32` are both rejected; `1` into `f64` is accepted; a 30-digit integer into `Value` silently becomes `1.2345678901234568e+29`. Feature `arbitrary_precision` keeps digits ("allows JSON numbers of arbitrary size/precision to be read into a Number… without loss of precision", <https://raw.githubusercontent.com/serde-rs/json/v1.0.151/Cargo.toml>) but is known to break under enum buffering (<https://github.com/serde-rs/serde/issues/1183>, open).
- **F. Not-JSON vs wrong shape.** One type, `serde_json::Error`, with `classify()` → `Category::{Io, Syntax, Data, Eof}` (<https://docs.rs/serde_json/latest/serde_json/error/enum.Category.html>). **[M]** `hello` → `expected value at line 1 column 1`, Syntax; `{"a":` → `EOF while parsing a value`, **Eof** (truncation is its own category); `{"a":"s"}` → Data. The classification leaks: **[M]** an externally tagged enum given two keys reports `expected value at line 1 column 17` as **Syntax** though the text is valid JSON.
- **G. Tagged unions.** Four representations (<https://serde.rs/enum-representations.html>).
  - External `{"Circle":{"r":1}}`: unknown → **[M]** ``unknown variant `Triangle`, expected one of `Circle`, `Square`, `Unit` ``; missing field → **[M]** ``missing field `r` at line 1 column 12``.
  - Internal `#[serde(tag="type")]`: unknown tag → **[M]** ``unknown variant `Triangle`, expected `Circle` or `Square` at line 1 column 18``; missing tag → **[M]** ``missing field `type` at line 1 column 7``; non-string tag → **[M]** ``invalid type: integer `1`, expected variant identifier``. Missing field inside a known member → **[M]** ``missing field `r` `` **with line 0, column 0** — the position is lost because the object is buffered and replayed (#1183). Nested in an array it regains the *enclosing* position: **[M]** ``missing field `r` at line 2 column 19``.
  - Adjacent `tag="t", content="c"`: **[M]** ``missing field `c` `` when content is absent.
  - Untagged: "the first one that deserializes successfully is the one returned" (enum-representations page). No match → **[M]** `data did not match any variant of untagged enum Unt`, line 0 column 0, with every per-variant reason discarded. Both match → **[M]** first declared wins, silently. The docs admit "`untagged` does not produce an informative error" (<https://serde.rs/container-attrs.html>); the tracking issue was closed as "more complicated than it's worth" (<https://github.com/serde-rs/serde/issues/773>).
- **H. Derivation and symmetry.** `#[derive(Serialize, Deserialize)]` at compile time from the type; attributes are shared. Asymmetries: untagged enums serialise unambiguously but deserialise by first-match; decode accepts arrays for structs **[M]**; `Option` encodes `None` as `null` but decodes absent too.
- **I. Complaints.** No path in errors (hence a third-party crate); untagged errors; `flatten`/internally-tagged buffering losing positions and format features (#1183, open since 2018); silent last-wins duplicates in maps (#762).

**`garde` / `validator` crates.** Post-decode validators. `garde` reports path-prefixed lines such as `username: length is lower than 3`, and `required` is "only available for `Option` fields" (<https://docs.rs/garde/latest/garde/>). `validator`'s `required` "Validates whether the given Option is Some" (<https://docs.rs/validator/latest/validator/>). Unlike Go, "required" here cannot be confused with a zero value, because the decoder already refused the missing non-`Option` field. A–I otherwise not applicable.

---

## 5. Swift `Codable` / `JSONDecoder` (not measured)

```swift
struct User: Codable { let name: String; let age: Int; let nick: String? }
let u = try JSONDecoder().decode(User.self, from: data)
```

- **A. Unknown keys.** Ignored, because the synthesised `init(from:)` asks only for its own `CodingKeys` **(unverified, from memory; no switch and no capture facility found in [sw-dec])**.
- **B. Missing field.** Error `DecodingError.keyNotFound(CodingKey, Context)` — "a keyed decoding container was asked for an entry for the given key, but did not contain one" [sw-std]. Text: `"No value associated with key \(key) (\"\(key.stringValue)\")."` [sw-dec:1565]. Path is `Context.codingPath: [any CodingKey]`, an array of keys (string or int index), not a string.
- **C. Errors.** Four cases, each carrying `Context{codingPath, debugDescription, underlyingError}` [sw-std]: `typeMismatch(Any.Type, …)` with `"Expected to decode \(type) but found \(value.debugDataTypeDescription) instead."` [sw-dec:1199]; `valueNotFound(Any.Type, …)` with `"Cannot get value of type \(expectedType) -- found null value instead"` [sw-dec:718]; `keyNotFound`; `dataCorrupted`. First error only — decoding is `throws`; no accumulation mechanism found.
- **D. null vs absent.** Conflated for optionals. Synthesis uses `decodeIfPresent` for `Optional` properties [sw-derive:1374], which returns "`nil` if the `Decoder` does not have an entry associated with the given key, or if the value is a null value" [sw-std]. SE-0166 notes the states "can be distinguished with a `contains(_:)` call", i.e. only by hand (<https://raw.githubusercontent.com/swiftlang/swift-evolution/main/proposals/0166-swift-archival-serialization.md>). For a non-optional, the two *are* distinct errors: `keyNotFound` vs `valueNotFound`.
- **E. Input.** `Data` only: `open func decode<T: Decodable>(_ type: T.Type, from data: Data)` [sw-dec:392]. Bad encoding: `"Unable to convert data to a string using the detected encoding. The data may be corrupt."` [sw-scan]. Trailing data: `unexpectedCharacter(context: "after top-level value", …)` rendering `"Unexpected character 'x' after top-level value around line L, column C."` [sw-scan:253,1177]. Duplicate keys: **first wins** silently (`result[key]._setIfNil(to: value)` [sw-dec:1316]) — the opposite of Go v1 and serde maps. A source comment says "the foundation json implementation does support trailing commas" [sw-scan:332]. Large numbers: `"Number \(parsed) is not representable in Swift."` [sw-scan:1228]; exact text for an integer overflowing `Int8` not found.
- **F. Not-JSON vs wrong shape.** Same enum, different case: bad JSON is `dataCorrupted` with `"The given data was not valid JSON."` and the scanner error as `underlyingError` [sw-dec:463]. But `dataCorrupted` is also used for shape-level failures (bad date, bad Base64, [sw-dec:792,837]), and the NSError bridge gives `typeMismatch` and `dataCorrupted` the same code 4864 [sw-std], so the case alone does not separate the two.
- **G. Tagged unions.** SE-0295 (Swift 5.5): `enum Command { case load(key: String) }` ⇄ `{"load": {"key": "MyKey"}}`; unlabelled values are keyed `_0`, `_1` (<https://github.com/swiftlang/swift-evolution/blob/main/proposals/0295-codable-synthesis-for-enums-with-associated-values.md>). Externally tagged only; no built-in discriminator-field form. The member is the single top-level key; otherwise `typeMismatch` with `"Invalid number of keys found, expected one."` [sw-derive:1677]. An unknown case name presumably lands on the same message, since it is not a `CodingKey` and so is not counted — **inferred, not verified**. A missing field inside a known member is an ordinary `keyNotFound` with the case key in `codingPath`.
- **H. Derivation and symmetry.** Compiler-synthesised from the declaration; `Codable` = `Encodable & Decodable`, same `CodingKeys` both ways. Asymmetry: `encodeIfPresent` omits `nil` while decode accepts both absent and `null`.
- **I. Complaints.** Not researched beyond the above; none verified.

---

## What stands out

1. **Go's whole v2 is a strictness correction.** Case-insensitive keys, last-wins duplicates, repaired UTF-8 and unrejected trailing data were each defended as documented behaviour for years, then reversed on security grounds. None could be fixed in place ("too late to change the defaults").
2. **Go still has no required fields, in v1 or v2.** Presence is erased by the decoder, so the validation layer's `required` means "not zero" and rejects `false` and `0`. Decode-and-validate in one pass against the declared type avoids this entirely.
3. **All three ignore unknown keys by default**, and Go v2 kept that deliberately. Rejection is opt-in everywhere; capture exists in serde (`flatten`) and Go v2 (`embed`), not Swift.
4. **Nobody accumulates errors in the decoder.** Go v1 keeps going but reports only the earliest; serde and Swift stop. Only the post-decode validators return lists.
5. **Path is the field everyone had to retrofit.** serde needs a separate crate, and even then a missing field's path stops at the parent. Go v2 added an RFC 6901 pointer. Swift had `codingPath` from day one and it is the best-regarded part of its errors.
6. **Untagged unions produce the worst error measured**: no variant reasons, no position, and silent first-match when two fit. Tagged forms give `unknown variant X, expected A or B`, which is a good model for an unknown discriminator.
7. **Buffering a union member loses the position** (serde internally tagged: line 0, column 0). Worth designing around if the discriminator may appear after the member's fields.
8. **null and absent are conflated for optionals in all three**; each needs a special type or manual code to separate them.
9. **Duplicate keys: three libraries, three answers** — last wins (Go v1, serde maps), first wins (Swift), error (serde structs, Go v2). This is precisely the parser-differential hazard Bishop Fox describes.
10. **Syntax-vs-shape separation exists everywhere but leaks everywhere**: Go v1's untyped `fmt.Errorf`, serde's two-key enum filed under `Syntax`, Swift's `dataCorrupted` covering both. serde's separate `Eof` category for truncated input is a small idea worth noting.
11. **Go v2 randomises its error wording** so nobody can depend on the text; the structured fields are the contract.
