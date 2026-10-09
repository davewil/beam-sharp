# Prior art: decoding wire JSON into typed values — TypeScript/JavaScript and Python

Researched 2026-10-09 for `FromJson<T>(text)`. Read-only review; nothing in the repo was touched.

## How to read this

- **[M:x]** means *measured in this session*. Scripts and raw output are in
  `probes/ts/`
  (`m_zod.mjs` → `out_zod.txt`, `m_valibot.mjs`, `m_arktype.mjs`, `m_ajv.mjs`, `m_iots.cjs`, `m_effect4.cjs`, `m_js.mjs`, `m_py.py` → `out_py.txt`, `e3/m_effect3.cjs`, `e3/m_zod3.cjs`). Error text quoted under an [M] tag is copied from that output, not from memory.
- A URL means the page was fetched in this session. Doc files fetched raw from GitHub are in `a scratch directory, not kept`.
- **(unverified, from memory)** means exactly that.
- Toolchain: node v24.19.0, npm 11.17.0, Python 3.14.7 (no pip; packages installed with `uv pip install --target`).

Versions measured: zod 4.6.5 (and 3.25.76), valibot 1.5.0, arktype 2.2.8, ajv 8.20.0, @sinclair/typebox 0.34.52, effect 4.0.2 (and 3.22.2), io-ts 2.2.22 / fp-ts 2.16.11, pydantic 2.14.0 (pydantic-core 2.50.0), msgspec 0.22.0, cattrs 26.2.1 / attrs 26.1.0.

The three shared inputs: (1) `{model:"m", n:1, extra:true}` against `{model: string, n: number}`; (2) `{n:1}` (missing `model`); (3) a 3-member union tagged by `type` ∈ `"text" | "image" | "tool"`, given (3a) `{type:"image"}` (valid tag, `url` missing) and (3b) `{type:"video", url:"x"}` (unknown tag).

## Popularity (npm weekly downloads, 2026-10-01 to 2026-10-07)

Measured with `curl https://api.npmjs.org/downloads/point/last-week/<pkg>`.

| Package | Weekly downloads | Note |
|---|---|---|
| ajv | 391,107,391 | mostly transitive (build tooling) |
| zod | 324,327,409 | the default application-level choice |
| @sinclair/typebox | 117,006,673 | largely transitive |
| effect | 42,468,174 | Schema is one module of it |
| joi | 25,496,083 | (not reviewed) |
| valibot | 21,377,231 | |
| yup | 12,086,604 | (not reviewed) |
| superstruct | 6,433,683 | (not reviewed) |
| io-ts | 3,009,118 | legacy |
| arktype | 2,126,160 | |
| @effect/schema | 1,321,899 | old standalone package |

Zod is roughly 15× Valibot and 150× ArkType. Ajv's and TypeBox's numbers overstate deliberate choice.

## Measured results at a glance

| Library | (1) extra key, default | (2) missing `model` | (3a) valid tag, key missing | (3b) unknown tag |
|---|---|---|---|---|
| Zod 4 `z.object` / `z.union` | stripped | path `["model"]`, "Invalid input: expected string, received undefined" | one `invalid_union` at path `[]`, message "Invalid input", 3 nested issue lists | same shape, "Invalid input" |
| Zod 4 `z.discriminatedUnion` | — | — | single issue, path `["url"]` | path `["type"]`, "Invalid discriminator value. Expected 'text' \| 'image' \| 'tool'" |
| Valibot `object` / `union` | stripped | path `["model"]`, "Invalid key: Expected "model" but received undefined" | one `union` issue, no path, "Invalid type: Expected Object but received Object", 6 sub-issues | same |
| Valibot `variant` | — | — | path `["url"]` | path `["type"]`, "Invalid type: Expected ("text" \| "image" \| "tool") but received "video"" |
| ArkType (plain `.or`) | **kept** | "model must be a string (was missing)" | "url must be a string (was missing)" | "type must be "tool", "text" or "image" (was "video")" |
| Ajv / TypeBox `anyOf` | **kept** | instancePath `""`, "must have required property 'model'" | 7 flat errors across all branches (`allErrors`) | 7 flat errors |
| Ajv `discriminator` | — | — | 1 error, `#/oneOf/1/required` | "value of tag "type" must be in oneOf" |
| io-ts `t.type` / `t.union` | **kept** | "Invalid value undefined supplied to : Req/model: string" | 1 error (auto-tagged) `(A \| B \| C)/1: B/url: string` | whole value against `(A \| B \| C)` |
| Effect Schema 3 | stripped | `["model"]` "is missing" | `["url"]` "is missing" (auto-tagged) | `["type"]` "Expected "text" \| "image" \| "tool", actual "video"" |
| Pydantic v2 smart union | ignored | loc `('model',)` "Field required" | 6 errors, loc prefixed by member class name | 6 errors |
| Pydantic v2 discriminated | — | — | loc `('image','url')` "Field required" | `union_tag_invalid`, loc `()` |
| msgspec | skipped | "Object missing required field `model`" | "Object missing required field `url`" | "Invalid value 'video' - at `$.type`" |

---

## 1. JavaScript baseline: `JSON.parse` and TypeScript's `any`

- **A. Extra keys.** Not applicable: no schema. Every key becomes an own property.
- **B. Missing field.** Not applicable. A missing key reads as `undefined` later, at the use site, which is the whole reason a validator layer exists.
- **C. Errors.** One `SyntaxError`, thrown, first error only. [M:js] `JSON.parse('{} x')` → `SyntaxError: Unexpected non-whitespace character after JSON at position 3 (line 1 column 4)`; `JSON.parse('')` → `SyntaxError: Unexpected end of JSON input`. MDN: "SyntaxError: Thrown if the string to parse is not valid JSON." <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/parse>
- **D. null vs absent.** Distinguished by the parser (`null` vs no property), but JS then blurs it: an absent key and a key holding `undefined` both read as `undefined`. JSON itself has no `undefined`. Every TS validator's optional/nullable/nullish split descends from this.
- **E. Input.** Typed `parse(text: string, reviver?): any` (TypeScript 5.9.2 `lib.es5.d.ts`, <https://unpkg.com/typescript@5.9.2/lib/lib.es5.d.ts>). At runtime the argument is stringified first: [M:js] `JSON.parse(123)` → `123`, `JSON.parse(null)` → `null`, `JSON.parse(Buffer.from('{"a":1}'))` → `{"a":1}`, `JSON.parse(undefined)` → `SyntaxError: "undefined" is not valid JSON`. No bytes API, so UTF-8 validity is someone else's job: [M:js] `new TextDecoder()` silently substitutes U+FFFD, only `{fatal: true}` throws `TypeError`. A lone surrogate escape `"\ud800"` parses fine. Trailing data is rejected. **Duplicate keys: last wins, silently** ([M:js] `{"a":1,"a":2}` → `{"a":2}`); RFC 8259 only says "The names within an object SHOULD be unique" (<https://www.rfc-editor.org/rfc/rfc8259.txt>). **Numbers are doubles**: [M:js] `12345678901234567890` → `12345678901234567000`, and `1.0` is indistinguishable from `1` (`Number.isInteger` is `true`). `NaN` is rejected. `__proto__` is an ordinary own key, no prototype pollution at parse time ([M:js] `Object.keys` → `['__proto__']`, prototype unchanged); MDN calls it "the only instance where a piece of JSON text represents a different value from the same JavaScript expression".
- **F.** Only one error kind exists (`SyntaxError`); shape errors do not exist at this layer.
- **G.** Not applicable.
- **H.** Neither: the return type is `any`, which switches type checking off for everything downstream. `JSON.stringify` is the inverse but is lossy (drops `undefined`, throws on BigInt).
- **I. Regrets / redesigns.** The number-precision loss was serious enough to get a language change: the TC39 `proposal-json-parse-with-source` is at **stage 4** ("Transformation between ECMAScript values and JSON text is lossy"), giving revivers a third `context` argument with `source` and adding `JSON.rawJSON` (<https://github.com/tc39/proposal-json-parse-with-source>). [M:js] On node 24 it works: a reviver returning `ctx.source` recovers `"12345678901234567890"`; `typeof JSON.rawJSON` is `function`. MDN notes the reviver "is run after the value is parsed", so without `source` precision is already gone.

## 2. Zod (v3 and v4)

- **A. Extra keys.** **Stripped** by default: "By default, unrecognized keys are *stripped* from the parsed result" (<https://zod.dev/api>). [M:zod] `z.object` → `{"model":"m","n":1}`. `z.strictObject` rejects, reporting all extras in **one** issue: `{"code":"unrecognized_keys","keys":["extra","e2"],"path":[],"message":"Unrecognized keys: \"extra\", \"e2\""}`. `z.looseObject` keeps them untyped. `.catchall(schema)` types them: with `z.number()`, `extra: true` → path `["extra"]`, "Invalid input: expected number, received boolean".
- **B. Missing field.** [M:zod] `{"expected":"string","code":"invalid_type","path":["model"],"message":"Invalid input: expected string, received undefined"}`. Path points **at the missing key**; "missing" is not its own code, it is "received undefined". v3 [M:zod3] said `"message":"Required"` with `"received":"undefined"`.
- **C. Errors.** All issues collected [M:zod]; I found no abort-early switch (absence unverified, from memory). `safeParse` returns `{success, data | error}`; `parse` throws `ZodError`. Issue base: `code`, `path`, `message` (+ `expected`, `keys`, `values`… by code). `z.prettifyError` renders `✖ Invalid input: expected string, received undefined\n  → at a[1].model` [M:zod]. **Failed plain union: one `invalid_union` issue at the union's path with message "Invalid input" and `errors: [[…],[…],[…]]`, one issue list per member**; `prettifyError` prints just `✖ Invalid input` [M:zod]. v3 used `unionErrors: [ZodError…]` [M:zod3]. `z.discriminatedUnion` collapses that to the one relevant issue (see G).
- **D. null vs absent.** Three separate wrappers: `.optional()` "to allow `undefined` inputs", `.nullable()` "to allow `null` inputs", `.nullish()` both (<https://zod.dev/api>). [M:zod] `{a: optional}` given `a: null` fails ("expected string, received null"); `{b: nullable}` absent fails ("received undefined"). `optional` does **not** separate absent from present-`undefined` (both pass); v4 added `.exactOptional()` "to allow an absent key without allowing an explicit `undefined`".
- **E. Input.** An already-parsed `unknown`. No built-in text entry point. `z.json()` validates "any JSON-encodable value" and is a recursive union, so its failure output is a deeply nested `invalid_union` [M:zod]. `z.int()` "restricts to safe integer range": [M] `9007199254740993` → `Too big: expected int to be <=9007199254740991` — but the value was already rounded by `JSON.parse`. `1.0` passes `z.int()` [M].
- **F. Not-JSON vs wrong shape.** Out of the box they are different exception classes (`SyntaxError` from `JSON.parse` vs `ZodError`). v4.1 added codecs ("Introduced in `zod@4.1`"), and the docs give a `jsonCodec` snippet, explicitly not built in: "these are not included as first-class APIs in Zod itself… you should copy/paste them" (<https://zod.dev/codecs>). With it [M:zod] not-JSON becomes a ZodError issue `{"code":"invalid_format","format":"json","message":"Expected property name or '}' in JSON at position 1 (line 1 column 2)","path":[]}` — same error type, distinguishable by `code`.
- **G. Tagged unions.** `z.discriminatedUnion("type", [...])` reads the key and dispatches. Docs' reason is speed: "regular unions are *naive*… This can be slow for large unions". [M:zod] valid tag, missing key → a single `path: ["url"]` issue. Unknown **or absent** tag → `{"code":"invalid_union","errors":[],"note":"No matching discriminator","discriminator":"type","options":["text","image","tool"],"path":["type"],"message":"Invalid discriminator value. Expected 'text' | 'image' | 'tool'"}`. v3 used a dedicated code `invalid_union_discriminator` [M:zod3].
- **H.** Type derived from the validator (`z.infer`). Decoding was one-way (`.transform`) until v4.1 codecs added `encode`.
- **I. Changes and reasons** (<https://zod.dev/v4/changelog>, <https://zod.dev/v4>): v4 motivated by speed, `tsc` instantiation counts (25,000 → ~175 in the docs' example) and bundle size. `.strict()`/`.passthrough()` deprecated for `z.strictObject`/`z.looseObject`; `.merge()` deprecated because `.extend()` "avoids ambiguity around strictness inheritance". Issue codes merged (`invalid_literal` + `invalid_enum_value` → `invalid_value`); `invalid_union_discriminator` removed as a runtime code. `z.unknown()`/`z.any()` keys no longer inferred optional, and from 4.4.0 must be present: "requiring it is a soundness fix". Defaults inside optional fields now apply ("resolves a long-standing usability issue"). `.deepPartial()` removed ("lots of footguns"). `z.number()` no longer accepts infinities. Long-running complaint: plain-union errors are unreadable (search hits on zod issues "Detailed errors for union schema", "Incorrect error for unions with literals" — titles seen via search, issue bodies not fetched).

## 3. Valibot

- **A.** **Stripped**: "The `object` schema removes unknown entries… neither validated nor added to the output" (valibot `guides/objects`, <https://github.com/fabian-hiller/valibot/tree/main/website/src/routes/guides>). `looseObject` keeps; `strictObject` "returns an issue for the **first** unknown entry found" — confirmed [M:valibot]: with two extras only `extra` is reported: `type: "strict_object", expected: "never", received: "\"extra\"", message: "Invalid key: Expected never but received \"extra\"", path: ["extra"]`. `objectWithRest(entries, rest)` types the extras.
- **B.** [M:valibot] `{kind:"schema", type:"object", expected:"\"model\"", received:"undefined", message:"Invalid key: Expected \"model\" but received undefined", path:["model"]}`. A missing key is an *object-level* issue (`type: "object"`) whose `expected` is the key name, located at the key.
- **C.** All issues by default: "Valibot exhaustively collects every issue"; `abortEarly: true` stops at the first (measured: 2 issues → 1). Issue: `kind`, `type`, `input`, `expected`, `received`, `message`, `path` (array of path items, each with `key`), optional `issues`. Plain `union` failure: one issue, **no path**, `"Invalid type: Expected Object but received Object"`, members' issues flattened into one `issues` list (6 sub-issues, member boundaries lost) [M:valibot]. Docs admit: "the issues of `union` can contradict each other".
- **D.** `optional` (absent or `undefined`), `exactOptional` ("allows missing entries in objects, but does not allow `undefined` as a specified value"), `undefinedable`, `nullable`, `nullish`. [M:valibot] `nullable` key absent → "Invalid key: Expected "b" but received undefined"; `optional` given `null` → "Expected string but received null".
- **E.** Parsed value. A `parseJson()` pipe action exists.
- **F.** With `v.pipe(v.string(), v.parseJson(), Schema)` both are issues of the same type; not-JSON is `kind: "transformation", type: "parse_json"`, message `Invalid JSON: Received "Expected property name or '}' in JSON at position 1 (line 1 column 2)"` [M:valibot].
- **G.** `variant('type', [...])`, recommended "for better performance, more type safety, and a more targeted output of issues". [M:valibot] valid tag → single `path: ["url"]` issue; unknown tag → `type: "variant", expected: "(\"text\" | \"image\" | \"tool\")", received: "\"video\"", path: ["type"]`; absent tag → same with `received: "undefined"`.
- **H.** Type from validator (`InferInput`/`InferOutput`). One-way transforms.
- **I.** v0.31 rewrote the API around `pipe` and split `object(…, rest)` into `looseObject`/`strictObject`/`objectWithRest` (reasons: unverified, from memory — the release page fetched only links to a migration guide I could not retrieve). Positioning is bundle size: 1.37 kB vs Zod's 15–17 kB in their own comparison (<https://valibot.dev/guides/comparison/>).

## 4. io-ts

- **A.** **Kept**: `t.type` ignores and preserves extras [M:iots]. `t.exact(type)` / `t.strict({...})` do **not reject** — they strip: "You can make a codec exact (which means that additional properties are stripped)" (<https://github.com/gcanti/io-ts/blob/master/index.md>); [M:iots] both return `{"model":"m","n":1}`. No rejecting mode and no typed-rest in the stable API.
- **B.** [M:iots] `PathReporter` → `Invalid value undefined supplied to : Req/model: string`. Context keys `["", "model"]`. Missing = "value undefined".
- **C.** All errors collected. `decode` returns `Either<Errors, A>`; each `ValidationError` has `value`, `context` (array of `{key, type, actual}`), optional `message`. The path includes codec names and, for unions/intersections, **member indexes** as path segments (`(A | B | C)/1: B/url: string`), so paths are not data paths. A union of structs with literal tags is auto-detected ([M] constructor name `TaggedUnionType`): valid tag → one error; unknown tag → `Invalid value {"type":"video","url":"x"} supplied to : (A | B | C)`, no path to `type`.
- **D.** `t.partial` for optional keys, `t.union([X, t.null])` for null. A `t.type` key typed `X | undefined` accepts an absent key [M] — absent and `undefined` are not separated.
- **E.** Parsed value only.
- **F.** Distinct (`SyntaxError` vs `Left<Errors>`).
- **G.** Implicit, by literal fields (above).
- **H.** Type from codec (`t.TypeOf`). **Symmetric by design**: `Type<A, O, I>` carries `decode` and `encode`.
- **I.** Superseded in practice: fp-ts README says "the fp-ts project is officially merging with the Effect-TS ecosystem" (<https://github.com/gcanti/fp-ts>); that Effect Schema is io-ts's direct successor is (unverified, from memory) — the fetched page does not name io-ts. PathReporter output embeds codec names and member indexes [M:iots]; that users find it hard to read is (unverified, from memory).

## 5. Effect Schema (v3 `effect@3.22.2`, and v4 `effect@4.0.2`)

- **A.** **Stripped** by default; parse option `onExcessProperty` "(default value: `"ignore"`)" with `"error"` and `"preserve"` (<https://effect.website/docs/schema/getting-started/>). [M:effect3] error → `└─ ["extra"]\n   └─ is unexpected, expected: "model" | "n"`; ArrayFormatter `{"_tag":"Unexpected","path":["extra"],…}`. Typed extras via a `Schema.Record` index signature. **v4 dropped `"preserve"`**: its type is `"ignore" | "error"` (`node_modules/effect/dist/SchemaAST.d.ts`), [M:effect4] passing `"preserve"` strips, and the v4 doc says "To retain additional keys, describe and validate them with `Schema.Record` or `Schema.StructWithRest` so they are represented in the schema's type" (<https://github.com/Effect-TS/effect/blob/main/packages/effect/SCHEMA.md>). Note this is a per-call option, not a property of the schema.
- **B.** [M:effect3] `{ readonly model: string; readonly n: number }\n└─ ["model"]\n   └─ is missing`; array form `{"_tag":"Missing","path":["model"],"message":"is missing"}`. v4 [M:effect4]: `Missing key\n  at ["model"]`. "Missing" is a first-class issue kind, distinct from a type mismatch.
- **C.** **First error only by default** ("By default only the first error is returned"); `{errors: "all"}` collects. Error is a tree (`ParseIssue`), with `TreeFormatter` and `ArrayFormatter` (`_tag`, `path`, `message`) (<https://effect.website/docs/schema/error-formatters/>). Unions of tagged structs are auto-discriminated [M:effect3]: valid tag → only `["url"] is missing`; unknown tag → `["type"]` `Expected "text" | "image" | "tool", actual "video"`. Non-discriminable union → nested per member in the tree, flat in the array form.
- **D.** The most complete treatment: `Schema.optional` (absent or `undefined`), `optionalWith({exact: true})` (absent only; [M] `c: undefined` → "Expected string, actual undefined"), `optionalWith({nullable: true})` (null "transforms to `<missing value>`"; [M] `d: null` decodes to no key), `NullOr`. v4 renames: `optionalKey` vs `optional`.
- **E.** Parsed value, or text via `Schema.parseJson(schema)` (v3) / `Schema.fromJsonString` (v4), which uses `JSON.parse`/`JSON.stringify` (<https://effect.website/docs/schema/transformations/>), so it inherits every `JSON.parse` behaviour in section 1.
- **F.** Same error type, different node: [M:effect3] not-JSON → `_tag: "Transformation"`, path `[]`, message is the engine's `SyntaxError` text, under "Encoded side transformation failure"; wrong shape → "Type side transformation failure". v4: `Expected a valid JSON string`.
- **G.** No dedicated constructor needed in v3; `Schema.TaggedStruct`/`Schema.tag` are conveniences. Docs: "union members are evaluated in the order they are defined"; the literal-tag shortcut is an optimisation that also fixes the error.
- **H.** Type from schema; **every schema is a codec** (`Type` vs `Encoded`), so `parseJson` encodes back to text.
- **I.** v4 rewrote Schema (new issue names `MissingKey`, `UnexpectedKey`, `InvalidType`, `OneOf`, `AnyOf`; `optionalWith` gone; `preserve` gone). [M:effect4] v4's unknown-tag message regressed to `Expected { readonly "type": "text", ... } | { readonly "type": "image", ... } | { readonly "type": "tool", ... }` with no path.

## 6. ArkType

- **A.** **Kept**: "Like TypeScript, ArkType defaults to ignoring undeclared keys during validation… `"ignore"` (default): Allow undeclared keys on input, preserve them on output" (<https://arktype.io/docs/configuration>). Per object: `"+": "reject" | "delete" | "ignore"` (<https://arktype.io/docs/objects>). [M:arktype] reject → one error **per** extra key: `extra must be removed` / `e2 must be removed`. Typed extras via index signature `"[string]": "..."`.
- **B.** [M:arktype] `model must be a string (was missing)`; `{code:"required", path:["model"], expected:"a string", actual:"missing"}`. "missing" is distinct from "was undefined".
- **C.** All errors (`type.errors`, an array with `.summary`). Each: `code`, `path`, `expected`, `actual`, `message`, composed as "path must be ⟨expected⟩ (was ⟨actual⟩)". **Plain unions are discriminated automatically** — "all unions are optimally discriminated" (<https://arktype.io/docs/blog/2.0>). [M:arktype] with ordinary `.or(...)`: (3a) → `url must be a string (was missing)`; (3b) → `type must be "tool", "text" or "image" (was "video")`. A union with no discriminant collapses to one `union` error joining the branches with "or": `a must be a string (was missing) or b must be a number (was missing)`.
- **D.** `"key?"` is absent-only by default ("ArkType validates optional keys as if TypeScript's `exactOptionalPropertyTypes` is set to `true`"); [M] `a: undefined` → `a must be a string (was undefined)`. Null is just `string | null`.
- **E.** Parsed value; `"string.json.parse"` morph for text.
- **F.** Same error type: [M:arktype] `must be a JSON string (SyntaxError: Expected property name or '}' in JSON at position 1 (line 1 column 2))`.
- **G.** No API: the discriminant is found by set-theoretic analysis of the members (the algorithm is not described in pages fetched).
- **H.** Type from definition (string syntax parsed at the type level). Morphs are one-way.
- **I.** 2.0 leads with "100x faster than Zod" and set-theoretic reduction. Its keep-by-default choice is the outlier among TS validators and is justified by matching TypeScript's structural typing.

## 7. TypeBox + Ajv / JSON Schema

- **A.** **Kept**: "By default any additional properties are allowed" (<https://json-schema.org/understanding-json-schema/reference/object>). `additionalProperties: false` rejects, one error per key [M:ajv]: `{"instancePath":"","keyword":"additionalProperties","params":{"additionalProperty":"extra"},"message":"must NOT have additional properties"}`; a schema there types extras. Ajv `removeAdditional` strips, mutating the input (<https://github.com/ajv-validator/ajv/blob/master/docs/options.md>). `additionalProperties` "only recognizes properties declared in the same subschema as itself", which is why `unevaluatedProperties` was added — closedness does not compose through `allOf`.
- **B.** [M:ajv] `{"instancePath":"","schemaPath":"#/required","keyword":"required","params":{"missingProperty":"model"},"message":"must have required property 'model'"}`. **The path is the parent object**; the key is in `params`. Nested: `instancePath: "/a/1"`. Also: "By default, the properties defined by the `properties` keyword are not required" — optional is the JSON Schema default; TypeBox flips it by emitting `required`.
- **C.** **First error by default**: `allErrors` "Default is to return after the first error". Errors are flat with `instancePath` (JSON Pointer), `schemaPath`, `keyword`, `params`, `message` (<https://github.com/ajv-validator/ajv/blob/master/docs/api.md>). A failed `anyOf` (what `Type.Union` emits [M]) lists every branch's errors flat plus `must match a schema in anyOf` — 7 errors for input (3a), distinguishable only by `schemaPath`. TypeBox's own `Value.Errors` gives one `Expected union value` with nested errors [M].
- **D.** "In JSON a property with value `null` is not equivalent to the property not being present." Optional = not in `required`; nullable = type union with `null`. [M:ajv] optional `a: null` → `data/a must be string`.
- **E.** Parsed value. `type: "integer"` accepts `1.0` and a rounded 2^53+1 [M].
- **F.** Distinct.
- **G.** `discriminator` is an OpenAPI keyword, off by default in Ajv ("limited support… not enabled by default"), requires `oneOf`. [M:ajv] valid tag → 1 error at `#/oneOf/1/required`; unknown tag → `{"keyword":"discriminator","params":{"error":"mapping","tag":"type","tagValue":"video"},"message":"value of tag \"type\" must be in oneOf"}`; absent tag → `tag "type" must be string`.
- **H.** TypeBox: TS type from the schema object. The schema is data, shareable across languages. No codec in JSON Schema; TypeBox adds `Value.Decode`/transforms.
- **I.** TypeBox 1.x is a new generation (ESM-only, own JIT compiler positioned as an Ajv alternative, <https://github.com/sinclairzx81/typebox>); only 0.34.52 was measured.

## 8. Standard Schema

- The shared interface Zod, Valibot and ArkType authors agreed on (byline handles @colinhacks, @fabianhiller, @ssalbdivad, <https://standardschema.dev/>). From the spec source (<https://github.com/standard-schema/standard-schema/blob/main/packages/spec/src/index.ts>): `validate: (value: unknown, options?) => Result<Output> | Promise<Result<Output>>`; `FailureResult { issues: ReadonlyArray<Issue> }`; `Issue { message: string; path?: ReadonlyArray<PropertyKey | PathSegment> }`.
- **A, B, D, E, G:** not specified (left to each library). **C:** a flat list of `{message, path}` — **no `expected`, no `received`, no code, no union nesting**. **E:** input is `unknown`, not text. **F:** not addressed. **H:** carries `types: {input, output}`, so input ≠ output is in the standard. **I:** a later `StandardJSONSchemaV1` adds JSON Schema export.
- Evidence of convergence: the common denominator is *path + human message, all issues, result-not-throw*. A structured `Expected` is beyond what the ecosystem could agree on.

## 9. Pydantic v2

- **A.** **Ignored (dropped)**: "By default, Pydantic models **won't error when you provide extra data**, and these values will simply be ignored"; `extra='ignore' | 'forbid' | 'allow'`, and with allow "`__pydantic_extra__` can explicitly be annotated to provide validation for extra fields" (<https://github.com/pydantic/pydantic/blob/main/docs/concepts/models.md>). [M:py] forbid → one error per key: `{"type":"extra_forbidden","loc":["extra"],"msg":"Extra inputs are not permitted","input":true}`. `extra` can also be overridden per validation call.
- **B.** [M:py] `{"type":"missing","loc":["model"],"msg":"Field required","input":{"n":1}}`; `str(e)`: `1 validation error for Req\nmodel\n  Field required [type=missing, input_value={'n': 1}, input_type=dict]`. Path is the missing key; `input` is the **parent** object. Nested: `loc: ["a", 1, "model"]`, printed `a.1.model`.
- **C.** All errors, always. Each: `type` (stable code), `loc` (tuple), `msg`, `input`, `ctx`, `url`. No `expected` field as such (`ctx.expected` on some types). **Failed smart union: flat list, each `loc` prefixed with the member's class name** — [M:py] 6 errors for (3a): `A.type` "Input should be 'text'", `A.text` "Field required", `B.url` "Field required", `C.type`, `C.name`, `C.input`. So `loc` is not purely a data path. Docs: discriminators avoid "a proliferation of errors when validation fails".
- **D.** `Optional[X]` without a default is **required but nullable**; "Any default value if provided makes a field not required" (<https://github.com/pydantic/pydantic/blob/main/docs/migration.md>). [M:py] `{}` → "Field required"; `{"a": null}` ok; `c: str = "d"` given `null` → "Input should be a valid string". Absent vs explicit null is recoverable afterwards via `model_fields_set` ([M] `{'a'}`).
- **E.** `model_validate_json` takes `str | bytes | bytearray`. Docs: "In general, use `model_validate_json()` not `model_validate(json.loads(...))`… the JSON is parsed in Python, then converted to a dict, then it's validated" (<https://github.com/pydantic/pydantic/blob/main/docs/concepts/performance.md>). Parser is `jiter` since 2.5 (<https://github.com/pydantic/pydantic/blob/main/docs/concepts/json.md>). It also changes *semantics*: strict mode is "looser… when validating from JSON" because JSON has no date type. [M:py] invalid UTF-8 bytes → `json_invalid` "invalid unicode code point at line 1 column 12"; trailing data rejected; **duplicate keys last-wins silently**; big ints exact (`123456789012345678901234567890`); lax mode: `1.0` → `1`, `"1"` → `1`, `1.5` → `int_from_float` "got a number with a fractional part"; `strict=True` rejects `"1"` and `1.0` (`int_type`). `NaN` token accepted for `float`.
- **F.** **Same exception type, distinct code**: [M:py] `{"type":"json_invalid","loc":[],"msg":"Invalid JSON: key must be a string at line 1 column 2",…}` inside `ValidationError`. Line/column appear only for syntax errors, not shape errors (docs: location-in-JSON for validation errors is future work).
- **G.** `Field(discriminator='type')`. [M:py] valid tag → `{"type":"missing","loc":["image","url"],"msg":"Field required"}` (**the tag value appears as a path segment**); unknown tag → `{"type":"union_tag_invalid","loc":[],"msg":"Input tag 'video' found using 'type' does not match any of the expected tags: 'text', 'image', 'tool'","ctx":{"discriminator":"'type'","tag":"video","expected_tags":"'text', 'image', 'tool'"}}`; absent tag → `union_tag_not_found` "Unable to extract tag using discriminator 'type'". Smart mode otherwise scores members by fields set and "exactness"; "The exact algorithm may change between Pydantic minor releases" (<https://github.com/pydantic/pydantic/blob/main/docs/concepts/unions.md>).
- **H.** Validator derived from the type annotations. `model_dump_json` is the inverse; not a codec in the io-ts sense but round-trips for plain data.
- **I.** v1 → v2: `Optional[X]` stopped implying a default — author's reason: "I didn't like using the word "optional" in relation to a field which was not optional" (<https://pydantic.dev/articles/pydantic-v2>); strict mode added because "People have long complained about pydantic for coercing data instead of throwing an error"; float → int now only when lossless; number → str coercion off; `smart_union` became the default; direct JSON validation "both improves performance and avoids issue with strictness".

## 10. msgspec

- **A.** **Skipped**: "By default `msgspec` will skip unknown fields… it allows for schema-evolution"; downside noted: "typos may go unnoticed" (<https://github.com/jcrist/msgspec/blob/main/docs/structs.rst>). `forbid_unknown_fields=True` → [M:py] `Object contains unknown field \`extra\`` (first only). No extras capture.
- **B.** [M:py] `Object missing required field \`model\`` at root; nested: `Object missing required field \`model\` - at \`$.a[1]\``. Path is the **parent object**, JSONPath-style, omitted at root.
- **C.** **First error only**, a string message; no structured fields. [M] missing + wrong type reported only `Expected \`int\`, got \`str\` - at \`$.n\``.
- **D.** `x | None` without default is required-nullable; `UNSET` "to differentiate between a message where a field is missing and a message where the field is explicitly `None`" — [M] `c=UNSET` vs `c=None`.
- **E.** Text: bytes or str, validated "during decoding, with *no* added runtime cost" in one pass. **Strict by default**: "integer is specified and a string is provided instead, an error is raised"; `strict=False` for lax. [M:py] `1.0` into `int` rejected; big ints exact; duplicate keys last-wins; `NaN` rejected; trailing data rejected.
- **F.** Related but separable: `ValidationError` subclasses `DecodeError` [M]. Malformed → `DecodeError: JSON is malformed: object keys must be strings (byte 1)`; **invalid UTF-8 escapes as a bare `UnicodeDecodeError`**, outside the hierarchy [M].
- **G.** `tag`/`tag_field` on structs (default field `"type"`). [M:py] valid tag → `Object missing required field \`url\``; unknown tag → `Invalid value 'video' - at \`$.type\``; absent → `Object missing required field \`type\``.
- **H.** Validator from type. Symmetric encode/decode.
- **I.** None found in pages fetched.

## 11. attrs / cattrs

- **A.** Ignored; `Converter(forbid_extra_keys=True)` → [M:py] `extra fields found (extra) @ $` (<https://github.com/python-attrs/cattrs/blob/main/docs/customizing.md>).
- **B.** [M:py] underlying exception is a raw `KeyError('model')`; `transform_error` → `required field missing @ $.model`.
- **C.** All errors, as a PEP 654 `ExceptionGroup` tree ("ExceptionGroups are trees of exceptions"); `transform_error` flattens to strings with `@ $.path` (<https://github.com/python-attrs/cattrs/blob/main/docs/validation.md>).
- **D.** Not found in pages fetched.
- **E.** Already-parsed values only. **Coerces by calling the constructor**: [M:py] `{"model": 5, "n": "1"}` → `CReq(model='5', n=1)`.
- **F.** Distinct.
- **G.** Default strategy infers a discriminator from `Literal` fields, else from "unique required fields"; an explicit tagged-union strategy exists (<https://github.com/python-attrs/cattrs/blob/main/docs/unions.md>). Not measured.
- **H.** From type; structure/unstructure are symmetric.
- **I.** Not found.

## 12. Python stdlib `json.loads`

- **A–D, G, H.** Not applicable (no schema).
- **C/F.** `JSONDecodeError` (a `ValueError`), first error. [M:py] `Extra data: line 1 column 4 (char 3)`.
- **E.** `str`, `bytes` or `bytearray`; "The input encoding should be UTF-8, UTF-16 or UTF-32". Invalid UTF-8 → `UnicodeDecodeError`, a different class [M]. "Infinite and NaN number values are accepted and output"; "Repeated names within an object are accepted, and only the value of the last name-value pair is used" (<https://github.com/python/cpython/blob/main/Doc/library/json.rst>). Ints are arbitrary precision and `1` vs `1.0` are kept apart ([M] `[1, 1.0]`). `object_pairs_hook` is the escape hatch for detecting duplicates.
- **I.** `parse_int` now limits digit count (docs note).

---

## What stands out

1. **Drop-unknown is the majority default, and reject is never the default.** Zod, Valibot, Effect, Pydantic, msgspec strip or skip. ArkType, io-ts and raw JSON Schema keep. Every library offers reject as opt-in, and the stated reason for leniency is schema evolution (msgspec says so outright).
2. **Typed capture of extras exists in most** (`catchall`, `objectWithRest`, index signatures, `__pydantic_extra__`), and Effect v4 *removed* untyped preserve in favour of it, so extras are "represented in the schema's type".
3. **Where a missing key is reported splits two ways.** At the key (`["model"]`: Zod, Valibot, ArkType, Effect, Pydantic) or at the parent with the key in the message (Ajv `instancePath: ""`, msgspec `$.a[1]`). Only ArkType, Effect, Pydantic, Ajv and msgspec name "missing" as its own thing; Zod, Valibot and io-ts report "received undefined", which cannot be told apart from a present-but-wrong value.
4. **A failed undiscriminated union is the worst error in every library**: Zod's bare "Invalid input", Valibot's "Expected Object but received Object", Ajv's 7 flat errors, Pydantic's 6 with class names leaking into `loc`. Every library's docs steer users to a discriminated form.
5. **Three libraries discriminate automatically from literal fields with no extra API** — ArkType, Effect Schema 3 and io-ts — and get the good error for free. This is the closest prior art for a set-theoretic type system: the tag is discovered from the member types, not declared.
6. **Unknown tag reports at the tag path with the allowed set** (Zod, Valibot, ArkType, Effect 3, msgspec). Pydantic reports at the union root. Zod gives the same message for an absent tag as an unknown one; Valibot, ArkType, Pydantic and msgspec separate them.
7. **Collect-all is the TS default (Zod, Valibot, ArkType, io-ts) and Pydantic's; first-error is the default for Effect, Ajv and msgspec** — the three that prioritise speed.
8. **Structured `expected` is not universal.** Zod, Valibot, ArkType have it; Pydantic and Ajv use a code plus params; Standard Schema standardised only `{message, path}`.
9. **Text-in is rare in TS and standard in Python.** All TS validators take an already-parsed value and inherit `JSON.parse`: last-wins duplicates, doubles, `1.0 ≡ 1`. Pydantic and msgspec take str/bytes, keep big ints exact, and can reject `1.0` for an int. Nobody measured rejects duplicate keys.
10. **"Not JSON" vs "wrong shape"**: Pydantic puts both in one exception with a distinct `type` (`json_invalid`, path `()`, line/column in the message). TS libraries only unify them when the JSON parse is wrapped as a transform. Invalid UTF-8 leaks out as a third, unrelated exception in msgspec and stdlib `json`.
11. **Paths are polluted in several libraries**: io-ts and Pydantic put union-member names or tag values into the path; a `{Path, Expected}` design should decide whether a path is purely a data path.
12. **null / absent / undefined is three-way in JS and two-way in JSON.** The designs that aged best separate *key may be absent* from *value may be null* (Effect `optionalKey` vs `NullOr`, ArkType `"key?"`, Pydantic v2's default-vs-`Optional`, msgspec `UNSET`). Pydantic v1 conflated them and v2 broke compatibility to undo it.

## Could not verify

- That Effect Schema is the named successor to io-ts (only the fp-ts → Effect merger statement was fetched).
- Zod v3's original rationale for strip-by-default, any `z.switch` plan, and Zod 4's release date.
- The bodies of the Zod union-error GitHub issues (titles came from search results only).
- Valibot v0.31's stated reasons for splitting `object` (migration guide not retrievable).
- ECMA-262's own wording for duplicate keys and `__proto__` (behaviour measured; MDN is silent on duplicates).
- ArkType's discrimination algorithm, and its per-version history of the undeclared-key default.
- TypeBox 1.x behaviour (only 0.34.52 measured); TypeBox `Value.Parse`/`Clean` semantics beyond README line references.
- cattrs: null/optional handling, tagged-union error output, and its `__version__` (attribute absent; version from `uv` install log).
- Pydantic's duplicate-key behaviour is measured only; no documentation found for it.
- msgspec and cattrs redesign history.
