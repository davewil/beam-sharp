# Prior art: decoding wire JSON into typed values on the BEAM

Scope: Erlang, Elixir and Gleam libraries, reviewed for the design of `FromJson<T>(text)`.
Date of review: 2026-10-09.

## How to read this

- **[M]** = measured in this session on this machine. **[D]** = copied from docs or source fetched in this session (URL given). Anything else is marked "(unverified, from memory)".
- Machine: Erlang/OTP 28.5 (erts 16.4), Elixir 1.19.5. `gleam` is **not installed**, so every Gleam statement is [D] (source reading), none is measured.
- Measurement scripts (all in `probes/beam/`):
  - `m.erl` — OTP `json`. Run: `erlc m.erl && erl -noshell -eval 'm:main()' -s init stop`
  - `j.exs` — Jason 1.4.5, Elixir `JSON`, Poison 6.0.0, Ecto 3.13.6. Run: `elixir j.exs`
  - `e.exs` — jsx 3.1.0, thoas 1.2.1, jsone 1.9.0, jiffy 2.0.2, jesse 1.8.2. Run: `elixir e.exs`
  - `v.exs` — peri 0.11.3, zoi 0.18.11, nimble_options 1.1.1, ex_json_schema 0.11.5, json_xema 0.6.5 / xema 0.17.10, norm 0.13.1, drops 0.2.1. Run: `elixir v.exs`
  - All `.exs` scripts use `Mix.install` with `MIX_INSTALL_DIR` pointed into the scratch directory, and `PATH` prefixed with `~/.local/share/mise/installs/elixir/1.19.5-otp-28/bin`.
- Standard probe inputs used for question E in every parser: `hello`, empty, `{"a":` (truncated), `{"a":1} x` (trailing), `{"a":1,"a":2}` (duplicate), `"\xFF"` (invalid UTF-8), `"\ud800"` (lone surrogate escape), a 30-digit integer, `1.0`, `1e2`, `1E400`.

## Popularity (how judged)

hex.pm API, `https://hex.pm/api/packages/<name>`, field `downloads` (all-time / last 90 days "recent"), fetched 2026-10-09:

| Package | All-time | Recent | Note |
|---|---|---|---|
| jason | 212.8M | 9.49M | dominant Elixir parser |
| ecto | 148.6M | 5.28M | de facto validation layer for external params |
| poison | 122.2M | 1.33M | legacy, last release 2024-06 |
| jsx | 74.8M | 1.57M | last release 2021 |
| nimble_options | 71.1M | 5.50M | keyword-option validator, not JSON |
| ex_json_schema | 35.3M | 0.72M | most-used JSON Schema validator |
| open_api_spex | 12.3M | 1.29M | not reviewed (OpenAPI-specific) |
| thoas | 12.1M | 0.95M | |
| jsone | 6.7M | 0.28M | |
| jiffy | 5.7M | 0.22M | |
| norm | 2.7M | 0.07M | fading |
| gleam_stdlib | 2.4M | 0.52M | |
| jesse | 2.1M | 0.08M | |
| xema / json_xema | 1.5M / 1.3M | 0.23M / 0.21M | |
| peri | 0.89M | 0.34M | rising |
| zoi | 0.88M | 0.49M | rising fastest of the schema libraries |
| jsv | 0.82M | 0.48M | not reviewed (noted as rising JSON Schema validator) |
| gleam_json | 0.78M | 0.20M | |
| drops | 0.07M | 0.005M | negligible |

Judgement: the popular answers on the BEAM are **Jason + Ecto changesets** (Elixir), **jsx or OTP `json` + pattern matching** (Erlang), **gleam_json + `gleam/dynamic/decode`** (Gleam). Of the dedicated schema libraries only ex_json_schema has real volume; Zoi and Peri are the ones growing.

---

## 1. Erlang/OTP `json` (OTP 27+, measured on 28.5)

Sources: <https://www.erlang.org/doc/apps/stdlib/json.html>, EEP 68 <https://github.com/erlang/eep/blob/master/eeps/eep-0068.md>.

```erlang
1> json:decode(<<"{\"a\":1,\"b\":null}">>).
#{<<"a">> => 1,<<"b">> => null}
```

- **A. Extra keys.** Not applicable: it is a parser, there is no schema. Everything is preserved in the map. [M]
- **B. Missing field.** Not applicable. The Erlang idiom is a pattern match afterwards (`#{<<"id">> := Id} = Map`), whose failure is a bare `{badmatch, Map}` with no path.
- **C. Errors.** First error only, raised as an exception, three shapes [D]: `error(unexpected_end)`, `error({invalid_byte, Byte})`, `error({unexpected_sequence, Bytes})`. No position in the reason term; a byte offset travels only in the stacktrace's `error_info` (`#{cause => #{position => N}}`) [M]. EEP 68: "The exceptions might be enhanced through the Error Info mechanism with additional meta-data like byte offset" [D].
- **D. null vs absent.** `null` decodes to the atom `null`; an absent key is an absent map key. Distinct. `decode/3` lets `null` map to anything, e.g. `#{null => undefined}` → `#{<<"a">> => undefined}` [M].
- **E. Input** [M unless noted]:
  - Binary only. A charlist or an iolist raises `function_clause`.
  - Invalid UTF-8 `<<"\"", 16#ff, "\"">>` → `{invalid_byte,255}`. Overlong `C0 AF` → `{invalid_byte,192}`. UTF-8-encoded surrogate `ED A0 80` → `{invalid_byte,160}`.
  - Lone surrogate escape `"\ud800"` → `unexpected_end` (it waits for the low half). A valid pair decodes.
  - UTF-8 BOM → `{invalid_byte,239}`.
  - Trailing data `{"a":1} x` → `{invalid_byte,32}`. Note the byte reported is the **first leftover byte (the space), not the `x`**. Trailing whitespace alone is accepted. `decode/3` returns the rest instead: `{#{<<"a">> => 1}, ok, <<" x">>}`.
  - Duplicate keys `{"a":1,"a":2}` → `#{<<"a">> => 1}`. **First wins, silently.** A custom `object_finish` can keep the pair list and so detect duplicates: `{[{<<"a">>,1},{<<"a">>,2}], ok, <<>>}`.
  - Big ints: arbitrary precision, `123456789012345678901234567890` round-trips. `1` → integer, `1.0` → float, `1e2` → `100.0` (float). `1E400` → `{unexpected_sequence,<<"1.0e400">>}`. `-0` → `0`, `-0.0` → `-0.0`. `1.00000000000000000001` → `1.0` (silent precision loss).
  - Empty input, whitespace only, truncated object, truncated string → all `unexpected_end`. `hello` → `{invalid_byte,104}`.
  - Strict: `01`, `[1,]`, `{'a':1}`, `NaN`, raw newline in a string, `"\x"` all rejected with `invalid_byte`.
- **F.** Only one kind of failure exists (not JSON). Shape failures belong to whatever the caller writes.
- **G. Unions.** Not applicable.
- **H.** No type-driven decoding. `decode/3` takes callbacks (`object_push`, `object_finish`, `null`, `integer`, `float`, `string`, …) [D]. Atom keys by hand: `object_push => fun(K, V, Acc) -> [{binary_to_existing_atom(K), V} | Acc] end` → `#{a => 1}` [M]. No record decoding.
- **I.** No atom-exhaustion risk by default (keys stay binaries). EEP 68's rationale is availability, not validation: "being able to use it in situations where leveraging third-party libraries is complex or cumbersome" [D]. Duplicate-key checking is documented for the *encoder* only (`encode_map_checked`, `{duplicate_key, Key}`) [D]; the decoder's first-wins is undocumented, measured.

## 2. jsx

Source: <https://github.com/talentdeficit/jsx/blob/main/README.md>.

```erlang
jsx:decode(<<"{\"library\": \"jsx\", \"awesome\": true}">>, [{return_maps, false}]).
```

- **A.** Not applicable (parser).
- **B.** Not applicable.
- **C.** Every failure is a bare `badarg` — no position, no reason [M: `ArgumentError "argument error"`; D: "raises a `badarg` error exception if input is not valid json"].
- **D.** `null` → atom `null`; absent stays absent.
- **E.** [M] Binary in. **Lenient by default**: invalid UTF-8 and a lone surrogate both decode to U+FFFD, `[1,]` → `[1]`, comments accepted, `{'a':1}` accepted. `[strict]` turns each into `badarg` [D lists `comments, trailing_commas, utf8, single_quotes, escapes, control_codes`]. Trailing data → `badarg`, or `{with_tail, #{<<"a">> => 1}, <<"x">>}` with `return_tail`. Duplicate keys: **last wins** in maps (`#{<<"a">> => 2}`), both kept with `{return_maps,false}` (`[{<<"a">>,1},{<<"a">>,2}]`). Big ints kept exact. `1E400` → `badarg` from `binary_to_float`.
- **F.** Parse errors only.
- **G.** Not applicable.
- **H.** None. `{labels, atom | existing_atom | attempt_atom}` controls keys [D].
- **I.** `{labels, atom}` creates atoms from input (`#{zzq_never_4 => 1}`) [M]. `attempt_atom` gives a **mixed-key map** when only some atoms exist: `#{ok => 2, <<"zzq_never_6">> => 1}` [M]. The README calls its default leniency "pragmatic" [D].

## 3. jiffy

Source: <https://github.com/davisp/jiffy/blob/master/README.md>.

- **A, B, G.** Not applicable (parser).
- **C.** Exceptions carrying a **1-based byte position and a reason atom** [M]: `{1,invalid_json}`, `{6,truncated_json}`, `{9,invalid_trailing_data}`, `{2,invalid_string}`.
- **D.** `null` by default; `use_nil` / `{null_term, T}` remap it [D].
- **E.** [M] Trailing data is its own error (`invalid_trailing_data`), or `{has_trailer, Term, <<"x">>}` with `return_trailer`. Invalid UTF-8 and lone surrogate → `invalid_string`. Duplicates: default EJSON form keeps both (`{[{<<"a">>,1},{<<"a">>,2}]}`); `return_maps` or `dedupe_keys` keep the **last** — the README says this "mirrors the parsing behavior of virtually every other JSON parser" [D]. `1E400` → `{range,<<"1E400">>}`.
- **F.** Parse only.
- **H.** None.
- **I.** A NIF, so a C toolchain is needed. No atom-key option, hence no atom risk.

## 4. thoas and jsone (brief)

Sources: <https://github.com/lpil/thoas/blob/main/README.md>, <https://github.com/sile/jsone/blob/master/README.md>.

- **A, B, G, H.** Not applicable (parsers, no schema).
- **C.** thoas returns `{error, Reason}` with a hex byte string and offset [M]: `{unexpected_byte,<<"0x68">>,0}`, `unexpected_end_of_input`, `{unexpected_sequence,<<"1E400">>,0}`. jsone's "error" is `{badarg, Stacktrace}` exposing internal function names (`jsone_decode:number_integer_part`) [M].
- **D.** Both: atom `null`.
- **E.** [M] thoas: strict; trailing `x` → `{unexpected_byte,<<"0x78">>,8}` (points at the `x`, unlike OTP); duplicates first-wins; README: "Thoas has no support for detecting duplicate object keys" [D]. jsone: **accepts invalid UTF-8 by default** (`{ok,<<255>>,<<>>}`; `reject_invalid_utf8` fixes it), returns trailing data as a remainder `{ok, #{..}, <<" x">>}` rather than failing, duplicates first-wins with `{duplicate_map_keys, last}` available.
- **F.** Parse only.
- **I.** thoas `#{keys => to_existing_atom}` silently leaves an unknown key as a binary (`#{<<"zzq_never_7">> => 1}`) [M]. gleam_json dropped thoas for OTP `json` in v2.0.0 [D, gleam_json changelog].

## 5. Erlang shape validation: pattern matching and jesse

Source: <https://github.com/for-GET/jesse/blob/master/README.md>.

```erlang
jesse:validate_with_schema(Schema, Json, [{allowed_errors, infinity}]).
```

- **A.** JSON Schema default: extras **allowed and preserved** (`{ok, #{..., <<"x">> => 1}}`). With `"additionalProperties": false`: `{data_invalid, Schema, no_extra_properties_allowed, Value, [<<"x">>]}` [M].
- **B.** `{data_invalid, Schema, missing_required_property, <<"r">>, []}` — the field name is in the *value* slot and the path is the **parent's** path, not `[<<"r">>]` [M].
- **C.** **First error by default** (`allowed_errors` defaults to 0); `{allowed_errors, infinity}` collects all [M, D]. Error tuple is `{data_invalid, Schema, ErrorType, Value, Path}`; path is a list of binaries and zero-based integers [D]. Failed `oneOf`: `{not_one_schema_valid, [ErrorsPerBranch]}` — one flat list, one error from each branch [M].
- **D.** `null` is a type (`"type": ["string","null"]`); a null on an integer gives `wrong_type` with value `null`; absent is governed by `required`. Distinct [M].
- **E.** Takes already-decoded terms, not text. `1.0` **passes** `"type":"integer"` [M].
- **F.** Distinct by construction: parsing is a different library.
- **G.** No discriminator support. With `oneOf` and a known tag but a missing field, the error lists the real fault *and* the other branch's "tag not in enum" side by side, with nothing saying which branch was meant [M].
- **H.** Schema is separate JSON data; validation returns the same untyped term (`{ok, Value}`), nothing nominal.
- **I.** Regex is Erlang `re`, not ECMA [D]. `schema_invalid` is a third error class [D].

Pattern matching (the common Erlang answer): extras ignored by map patterns, missing field is `badmatch`/`function_clause` with no path, first failure only. No source beyond language semantics; (unverified, from memory) as a statement of community practice.

## 6. Jason (Elixir)

Sources: <https://github.com/michalmuskala/jason/blob/master/lib/jason.ex>, <https://github.com/michalmuskala/jason/blob/master/README.md>.

```elixir
iex> Jason.decode("invalid")
{:error, %Jason.DecodeError{data: "invalid", position: 0, token: nil}}
```

- **A, B, G.** Not applicable (parser).
- **C.** First error, `%Jason.DecodeError{position, token, data}` with 0-based byte position. Messages [M]: `unexpected byte at position 0: 0x68 ("h")`, `unexpected end of input at position 5`, `unexpected sequence at position 0: "1E400"`.
- **D.** `null` → `nil`. Since `map["k"]` is also `nil` for an absent key, the distinction survives in the data but is lost by the idiomatic accessor.
- **E.** [M] iodata accepted. Invalid UTF-8 → `unexpected byte at position 1: 0xFF`. Lone surrogate → `unexpected byte at position 7: 0x22`. Trailing → `unexpected byte at position 8: 0x78 ("x")` (points at the `x`). Duplicates first-wins; `objects: :ordered_objects` preserves both (`%Jason.OrderedObject{values: [{"a",1},{"a",2}]}`). Big ints exact. `floats: :decimals` → `Decimal.new("1.10")`. BOM rejected.
- **F.** Parse only.
- **H.** README: "no support for decoding into data structures (the `as:` option)" — a deliberate removal relative to Poison [D]. Encoding is a protocol with `@derive`; decoding has no counterpart, so **asymmetric**.
- **I.** `keys: :atoms`: "Since the atoms are not garbage collected, this can pose a DoS attack vector when used on user-controlled data" [D]. `keys: :atoms!` on an unknown key **raises `ArgumentError` out of the non-bang `decode/2`** rather than returning `{:error, _}` [M].

## 7. Elixir built-in `JSON` (1.18+)

Sources: <https://github.com/elixir-lang/elixir/blob/v1.19.5/lib/elixir/lib/json.ex>, <https://github.com/elixir-lang/elixir/blob/v1.18/CHANGELOG.md>.

- **A, B, G.** Not applicable (parser).
- **C.** First error; the OTP reasons with an offset added [D, M]: `{:invalid_byte, 0, 104}`, `{:unexpected_end, 5}`, `{:unexpected_sequence, 0, "1.0e400"}`. `decode!` raises `JSON.DecodeError`, e.g. `invalid byte 104 at position (byte offset) 0`.
- **D.** `null` → `nil` (configurable in `decode/3`) [D].
- **E.** [M] **Binary only**: iodata raises `FunctionClauseError` (Jason accepts it). Trailing data → `{:invalid_byte, 7, 32}` — again the space at offset 7, not the `x` at 8. Duplicates first-wins. Otherwise as OTP.
- **F.** Parse only.
- **H.** `JSON.Encoder` protocol with `@derive`; **no decode-to-struct** [D: the module documents only encoding for structs].
- **I.** No atom-keys option at all (must be hand-built via `decode/3`). Added so tooling need not depend on a library: "official support for JSON encoding and decoding" [D].

## 8. Poison

Sources: <https://github.com/devinus/poison/blob/master/README.md>, <https://github.com/devinus/poison/blob/master/lib/poison/decoder.ex>.

```elixir
Poison.decode!(~s({"name": "Devin Torres", "age": 27}), as: %Person{})
#=> %Person{name: "Devin Torres", age: 27}
```

- **A.** Extras **silently dropped** [M: `{"name":"a","extra":1}` → `%Person{name: "a", age: nil, ...}`]. Not switchable, not capturable.
- **B.** Missing field → the struct's **default (usually `nil`)**, no error [M].
- **C.** **No shape errors at all.** `{"name":42,"age":"old"}` → `{:ok, %Person{name: 42, age: "old"}}` [M]. A JSON array where a struct was asked for raises `BadMapError` from inside the library [M]. Parse errors: `%Poison.ParseError{data, skip, value}`.
- **D.** Not distinguished: `{"name":null}` against `%Person{name: "dflt"}` → `name: nil` (null overrides the default); absent → default [M].
- **E.** [M] **Invalid UTF-8 accepted**: `{:ok, <<255>>}`. Duplicates first-wins. Trailing → ParseError at `skip: 8`.
- **F.** Only parse errors exist.
- **G.** None; `as:` may be a function of the value, so a hand-written dispatch is possible [D, decoder.ex].
- **H.** Decodes into nominal structs, driven by a *value* (`as: %Person{address: %Addr{}}`), not a type; nested shapes must be spelled out in the template. Symmetric in spirit with `@derive Poison.Encoder`.
- **I.** Same atom warning for `keys: :atoms` [D]. This is the cautionary case: "typed decoding" that checks nothing. Jason's README lists dropping `as:` as a difference [D].

## 9. Ecto embedded schemas + changesets

Source: <https://github.com/elixir-ecto/ecto/blob/v3.13.6/lib/ecto/changeset.ex>. Measured on 3.13.6.

```elixir
def changeset(p), do: %Order{} |> cast(p, [:id, :note, :total, :kind])
  |> cast_embed(:lines, required: true) |> validate_required([:id, :kind])
Order.changeset(Jason.decode!(json)) |> apply_action(:insert)
```

- **A.** Extras **silently ignored**: "All parameters that are not explicitly permitted are ignored" [D]; `"bogus": true` → `valid?: true` [M]. Not switchable in `cast`, not captured.
- **B.** Only if `validate_required` names it: `id: {"can't be blank", [validation: :required]}` [M]. Otherwise the field is `nil`. The error is keyed by field atom; no path string.
- **C.** **All errors**, nested per embed. `traverse_errors` gives a tree [M]: `%{id: ["is invalid"], total: ["is invalid"], lines: [%{qty: ["can't be blank"]}, %{sku: ["is invalid"], qty: ["is invalid"]}], kind: ["is invalid"]}`. Type failures say only `"is invalid"` with metadata `[type: :integer, validation: :cast]`; **no "found"**. List positions are implicit in list order, not an index in a path.
- **D.** **Not distinguished**: `{"id": null}` and a missing `id` both give `can't be blank` [M].
- **E.** Takes a decoded map. Params must be a map (`Ecto.CastError "expected params to be a :map, got: `[1]`"` — a raise, not a changeset error) and must not mix atom and string keys [M]. **Coerces**: `"12"` → `12`, `3` → `3.0`, `"2"` → `2`; but `1.5` for an integer → `is invalid` [M].
- **F.** Distinct: Jason's error vs an invalid changeset vs a raised `CastError`. Three channels.
- **G.** Nothing built in for embeds (polymorphic embeds need a third-party library — unverified, from memory). An unknown `Ecto.Enum` string → `"is invalid"` with `[validation: :inclusion, enum: ["card","cash"]]` [M].
- **H.** Schema declares fields and types, but the permitted list and required list are **written again by hand** in `changeset/2`. Decodes into nominal structs. Encoding is unrelated (`@derive Jason.Encoder`).
- **I.** Designed for form input, hence coercion and blank-as-nil. Field names are compile-time atoms, so no atom exhaustion.

## 10. Elixir schema libraries

Sources: Zoi <https://github.com/phcurado/zoi/blob/main/README.md>; Peri <https://github.com/zoedsoupe/peri/blob/main/README.md>; ex_json_schema <https://github.com/jonasschmidt/ex_json_schema/blob/master/README.md>; NimbleOptions <https://github.com/dashbitco/nimble_options/blob/main/lib/nimble_options.ex>. Norm, Drops, JsonXema: measured only, no docs read.

### Zoi (the closest Elixir analogue to the design in hand)

```elixir
zs = Zoi.map(%{"id" => Zoi.integer(), "kind" => Zoi.enum(["card", "cash"])})
Zoi.parse(zs, %{"id" => "a"})
```

- **A.** Extras **stripped** by default (`{:ok, %{"id" => 1, "kind" => "card"}}`). `unrecognized_keys: :error` → `%Zoi.Error{code: :unrecognized_key, message: "unrecognized key: x", path: []}` (key named in the message, path is the parent). `strict: true` is deprecated in favour of it [M].
- **B.** `%Zoi.Error{code: :required, issue: {"is required", [key: "kind"]}, message: "is required", path: ["kind"]}` [M]. Path is a list of keys and integer indexes (`path: [1]` for a list element [D]).
- **C.** **All errors, flat list** [D: "Even when errors are nested, Zoi will return all errors in a flattened list"]. Type error: `"invalid type: expected integer"` — expected, no found. Failed `Zoi.union([integer, string])` on `1.5` reports **only the last alternative**: `"invalid type: expected string"` [M].
- **D.** Distinguished: `Zoi.optional` allows absence but **rejects `null`** (`"invalid type: expected string"` at `["note"]`); `Zoi.nullish` accepts it [M].
- **E.** Decoded terms. No coercion unless `coerce: true` (`"12"` → `12`); `1.0` rejected for integer [M].
- **F.** Separate library from the parser, so distinct.
- **G.** `Zoi.discriminated_union("t", [...])` [M]: unknown tag → `"unknown discriminator 'tri' for field 't'"` (code `:custom`, path `[]`); missing tag → `"is required"` at `["t"]`; known tag, missing field → `"is required"` at `["r"]` with `discriminator: "circle"` in the issue metadata. **This is the best union reporting found in this survey.**
- **H.** Schema written by hand as a value; a typespec is *derived from the schema* (`Zoi.type_spec/1`) [D], the reverse of deriving a decoder from a type. Output is a plain map.
- **I.** An atom-key schema fed string keys fails with `is required` unless `coerce: true` [M] — an easy mistake at the JSON boundary.

### Peri

- **A.** Default "strict" mode **strips** extras and returns atom keys from string-key input (`{:ok, %{id: 1, kind: "card"}}`); `mode: :permissive` preserves them [M].
- **B.** `%Peri.Error{path: [:kind], message: "is required, expected type of {:enum, [\"card\", \"cash\"]}"}` [M].
- **C.** All errors; **nested** (`errors:` inside a parent error) rather than flat; has expected *and* actual: `"expected type of :integer received \"a\" value"`. `oneof` failure: `"expected one of :integer or :string, got: 1.5"` [M].
- **D.** **Not distinguished**: `nil` for a required field → `"is required, …"` [M].
- **E.** Decoded terms. A list where a map is expected reports the *fields* as required instead of a type error [M].
- **F.** Distinct (separate library). **G.** `either`/`oneof` only; no discriminator found in the README. **H.** Schema is plain data; no nominal output. **I.** Not found.

### ex_json_schema

- **A.** Allowed unless `additionalProperties: false` → `{"Schema does not allow additional properties.", "#/x"}` [M].
- **B.** `{"Required property kind was not present.", "#"}` — path is the parent [M].
- **C.** All errors; `{message, json_pointer_path}` tuples, or raw structs with `expected`/`actual` [D]. Failed `oneOf` collapses to `"Expected exactly one of the schemata to match, but none of them did."` unless raw errors are requested, which give per-branch `InvalidAtIndex` lists [M].
- **D.** Distinct (`Expected Integer but got Null`). **E.** `1.0` passes `integer` [M]; atom-key data fails as if empty [M]. **F.** Distinct. **G.** No discriminator; same both-branches noise as jesse. **H.** Schema separate, output untyped. **I.** Not found.

### NimbleOptions, JsonXema, Norm, Drops (brief)

- **NimbleOptions**: keyword lists only — a string-key map raises `FunctionClauseError` [M], so it is not a JSON tool. **A** rejects unknown keys: `"unknown options [:x], valid options are: [:id, :kind, :note]"`. **C** first error only. **B** not reached in the probe (the type error on `:id` was reported first, the missing `:kind` never). D–I: not applicable.
- **JsonXema**: **A** extras allowed. **B/C** `%JsonXema.ValidationError{reason: %{required: ["kind"]}}`, message `Required properties are missing: ["kind"].`; the wrong-typed `id` in the same input was **not** reported [M]. D–I: not examined.
- **Norm**: **A** extras preserved. **B** a plain `schema` treats every key as optional (`{:ok, %{"id" => 1}}`); `selection/2` makes them required → `%{input: ..., path: ["kind"], spec: ":required"}`. **C** all errors [M]. D–I: not examined.
- **Drops**: **A** extras stripped. **B** `text: "key must be present"`, `path: ["kind"]`. **C** all errors [M]. D–I: not examined.

---

## 11. Gleam: `gleam_json` + `gleam/dynamic/decode`

Sources (all read, none executed): decode module <https://github.com/gleam-lang/stdlib/blob/main/src/gleam/dynamic/decode.gleam>; its Erlang FFI <https://github.com/gleam-lang/stdlib/blob/main/src/gleam_stdlib.erl>; gleam_json <https://github.com/gleam-lang/json/blob/main/src/gleam/json.gleam> and <https://github.com/gleam-lang/json/blob/main/src/gleam_json_ffi.erl>; changelogs <https://github.com/gleam-lang/stdlib/blob/main/CHANGELOG.md>, <https://github.com/gleam-lang/json/blob/main/CHANGELOG.md>; old API <https://github.com/gleam-lang/stdlib/blob/v0.40.0/src/gleam/dynamic.gleam>.

```gleam
let decoder = {
  use name <- decode.field("name", decode.string)
  use score <- decode.field("score", decode.int)
  decode.success(Player(name:, score:))
}
json.parse(from: text, using: decoder)
```

- **A. Extra keys.** Ignored: a decoder only indexes the keys it names (`bare_index` → `maps:get`). No strict mode exists in the module. Capturable only by decoding the whole value again as `decode.dict(decode.string, decode.dynamic)`. [D]
- **B. Missing field.** An error. `decode.field` on an absent key yields exactly `DecodeError(expected: "Field", found: "Nothing", path: ["name"])` — the missing key is the **last path segment**, and the fact that it is missing is carried by the magic strings `"Field"`/`"Nothing"` [D, `subfield`]. Path is `List(String)`; list positions are stringified integers (`integer_to_binary(Index)`).
- **C. Errors.** `Result(t, List(DecodeError))` with `DecodeError(expected: String, found: String, path: List(String))`; `found` is the *runtime class name* (`"Int"`, `"String"`), never the value. **All errors across the fields of one record** (each failed field substitutes a placeholder and decoding continues) — but **only the first failing element of a list** (FFI `list/5` stops) and **only the first failing entry of a dict** [D]. `decode.one_of`: "If no decoder succeeds then the errors from the first decoder are used" [D] — the other alternatives' errors are discarded. `decode.collapse_errors(decoder, name)` replaces them with one named error.
- **D. null vs absent vs optional.** Three separate tools [D]:
  - `decode.field(k, d)` — key must be present.
  - `decode.optional_field(k, default, d)` — absent key → `default`; a present `null` is handed to `d` and fails unless `d` accepts it.
  - `decode.optional(d)` — value may be null → `None`. (`is_null` is `undefined | null | nil` on Erlang.)
  - So "absent or null" must be written as `optional_field(k, None, decode.optional(d))`.
- **E. Input.** `json.parse` takes a `String`, `json.parse_bits` a `BitArray`; on Erlang both call OTP `json:decode/1` [D], so the behaviour in section 1 applies (duplicates first-wins, strict UTF-8). Not measured through Gleam. The FFI formats the byte as hex: `{unexpected_byte, hex(Byte)}`, so trailing data would surface as `UnexpectedByte("0x20")` by inference. `decode.int` rejects `1.0` and `decode.float` rejects `1` on Erlang: "This will not coerse int values into float values … One time this may happen is when decoding JSON data" [D]. Open issue asking for `decode.number`: <https://github.com/gleam-lang/stdlib/issues/801>.
- **F.** **One type, distinct variants** [D]:
  ```gleam
  pub type DecodeError {
    UnexpectedEndOfInput
    UnexpectedByte(String)
    UnexpectedSequence(String)
    UnableToDecode(List(decode.DecodeError))
  }
  ```
  Example from the docs: `parse("1", decode.string)` → `Error(UnableToDecode([decode.DecodeError("String", "Int", [])]))`.
- **G. Tagged unions.** Hand-written: decode the tag with `decode.field("type", decode.string)`, then `case` to pick a decoder. The module's own example ends `_ -> trainer_decoder`, i.e. **an unknown tag silently falls into a default member** [D]. The strict form is `_ -> decode.failure(placeholder, expected: "PocketMonsterType")`, giving `DecodeError("PocketMonsterType", "String", [])` — expected is the *type name*, found is `"String"`, so **the offending tag value is not in the error**. A known tag with a missing field gives the ordinary `("Field", "Nothing", [key])`. Open complaint: "the expected way to solve varients is using `one_of` this doesn't give very good errors" — <https://github.com/gleam-lang/stdlib/issues/843>.
- **H.** Written by hand, separately from the type. No derivation in the language; the language server's "generate dynamic decoder" code action emits the source once, after which it drifts independently (Gleam v1.7.0, <https://gleam.run/news/improved-performance-and-publishing/>). Decodes into nominal records. **Not symmetric**: encoding is a separate hand-written `json.object([...])`.
- **I. The redesign.** The old `gleam/dynamic` decoders (`decode1` … `decode9`, `field`, `any`) were deprecated in stdlib v0.53 and removed from gleam_json in v3.0.0; changelog v0.50.0: "This module will replace the dynamic decoding combinators from `dynamic` (`decode3`, etc)" [D]. **No official rationale text was found** (PR <https://github.com/gleam-lang/stdlib/pull/749> has an empty body). The new module credits Toy as its inspiration, and Toy's README states the reasons [D, <https://github.com/Hackder/toy/blob/main/README.md>]: there is no `decode10`, and fields are positional — "if the two fields you swapped are both strings, the compiler will not catch this mistake. **You will end up with bad data in your application**". Other differences visible in source: old list errors had path `["*"]` (no index), old `any` reported `expected: "another type"`, old missing field was `("field", "nothing")`. Two semantic regrets on the way: `dynamic.optional_field` "no longer treats the value as implicitly optional. It only deals with the presence or absence of the key itself" (stdlib changelog); and the interim `decode/zero` `field` first returned a default for a missing key, then was changed to an error (lpil/decode v0.5.0, <https://github.com/lpil/decode/blob/main/CHANGELOG.md>). Cost of the placeholder technique, per Toy: "Every line of the decoder will be executed on every invocation", so `decode.failure` needs a dummy value of the target type.

---

## Summary table

| | Extra keys (default) | Missing required | Errors | null vs absent | Parse vs shape |
|---|---|---|---|---|---|
| OTP `json` | n/a | n/a | first, no path, no position in term | distinct | parse only |
| Jason / Elixir `JSON` | n/a | n/a | first, byte position | distinct in data, both `nil` on access | parse only |
| Poison `as:` | dropped | default/`nil`, no error | none | conflated | parse only |
| Ecto changeset | ignored | error only if `validate_required` | all, tree | **conflated** | three channels |
| Zoi | stripped (can reject) | error, path ends in key | all, flat | distinct | separate libs |
| Peri | stripped (can keep) | error, path ends in key | all, nested | **conflated** | separate libs |
| JSON Schema (jesse, ex_json_schema) | allowed (can reject) | error at **parent** path | jesse first / exjs all | distinct | separate libs |
| Gleam decode | ignored (no strict mode) | `("Field","Nothing",[key])` | all per record, first per list | distinct, three combinators | one type, 4 variants |

## What stands out

1. **Nobody on the BEAM derives the decoder from the type.** Gleam hand-writes it (with an editor code action); Ecto restates the field list; Zoi goes the other way and derives a typespec from the schema. A type-directed `FromJson<T>` has no direct BEAM precedent.
2. **Ignore-or-strip is the universal default for unknown keys**; rejecting is opt-in everywhere it exists (Zoi `unrecognized_keys: :error`, JSON Schema `additionalProperties: false`) and absent in Gleam and Ecto. NimbleOptions is the only reject-by-default, and it is for options, not wire data.
3. **Where a missing field lives in the path splits two ways**: Gleam, Zoi, Peri, Drops put the missing key as the last path segment; JSON Schema validators report it at the parent with the name in the message. `{Path, Expected}` has to pick one.
4. **Gleam encodes "missing" in magic strings** (`expected: "Field", found: "Nothing"`), indistinguishable by type from a wrong-type error.
5. **"All errors" is never truly all.** Gleam collects across record fields but stops at the first bad list element; jesse defaults to first; JsonXema dropped a type error next to a missing field.
6. **Union failures are the weakest spot everywhere**: Gleam `one_of` keeps only the first alternative's errors, Zoi `union` only the last, JSON Schema `oneOf` either collapses to one sentence or dumps every branch. Only Zoi's `discriminated_union` names the unknown tag and reports a known member's missing field at its own path.
7. **null vs absent is conflated by the two most-used Elixir paths** (Ecto, Peri) and by Poison; Gleam and Zoi keep them apart, and Gleam went through a breaking fix to do so.
8. **Duplicate keys are silently resolved, and inconsistently**: first wins in OTP `json`, Elixir `JSON`, Jason, Poison, thoas, jsone; last wins in jsx and jiffy maps. None rejects by default.
9. **OTP `json` reports trailing data as `invalid_byte` of the first leftover byte** (the space in `{"a":1} x`), and a lone `\ud800` as `unexpected_end`. A layer on top inherits both oddities unless it uses `decode/3` and inspects the remainder itself.
10. **Int/float strictness on JSON numbers is a live complaint in Gleam** (`decode.float` rejects `1`), while JSON Schema validators err the other way (`1.0` passes `integer`), and Ecto coerces strings to numbers.
11. **Atom keys remain a footgun**: Jason and Poison document the DoS; Jason's `:atoms!` raises out of the non-raising API; jsx `attempt_atom` produces mixed-key maps.
12. **Parse and shape errors share one type only in Gleam** (`json.DecodeError` with an `UnableToDecode` variant). Everywhere else they are different libraries with different error shapes.
