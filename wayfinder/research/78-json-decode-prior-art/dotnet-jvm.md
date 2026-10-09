# Prior art: decoding wire JSON into typed values — .NET and the JVM

Researched 2026-10-09. Written for the design of `FromJson<T>(text)` returning a value or `{Path, Expected}`.

## How to read this

- Every claim carries a source key (`[S7]`); the keys resolve to URLs in *Sources* at the end. All were fetched in this session.
- Error text in `code font` is copied from library source or official docs. `{0}`, `%s`, `$x` are the library's own placeholders, so the surrounding words are exact and the substituted values are not.
- **(unverified, from memory)** marks anything not fetched.
- **Nothing was measured.** `which dotnet java kotlinc` found `/usr/bin/dotnet` and `/usr/bin/java`, no `kotlinc`. `dotnet --list-sdks` is empty ("No .NET SDKs were found"); only the runtimes `Microsoft.NETCore.App 9.0.19` and `10.0.11` are present, so no C# can be compiled. Java 26 has `javac` but no Jackson/Gson jars and no Maven/Gradle; fetching jars was outside the write scope. All behaviour below is from docs and source, not from a run.

---

## 1. System.Text.Json (C#)

- **A. Unknown keys.** Ignored by default: "they're simply ignored". Since .NET 8, `JsonUnmappedMemberHandling.Disallow` (attribute or option) rejects them [S1]:
  ```csharp
  [JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
  public class MyPoco { public int Id { get; set; } }
  JsonSerializer.Deserialize<MyPoco>("""{"Id" : 42, "AnotherId" : -1 }""");
  // JsonException : The JSON property 'AnotherId' could not be mapped to any .NET member contained in type 'MyPoco'.
  ```
  Extras are captured with `[JsonExtensionData]` on a `JsonObject` / `IDictionary<string, JsonElement>` member; without it they "have nowhere to go and are lost" [S2].
- **B. Missing field.** Not an error by default. `JsonSerializer.Deserialize<Person>("{}")` on `record Person(string Name, int Age)` yields `Person { Name = , Age = 0 }` — "Prior to .NET 9, constructor-based deserialization treated all constructor parameters as optional" [S3]. An error only with `required` / `[JsonRequired]` (.NET 7) or `RespectRequiredConstructorParameters = true` (.NET 9, opt-in) [S3]. Text [S5]: `JSON deserialization for type '{0}' was missing required properties including: {1}.` The field is named in the message as a list (several can be listed, with a length cut-off [S6]); it is not a path to the missing field.
- **C. Errors.** First error only, as a thrown `JsonException` with public `Path`, `LineNumber`, `BytePositionInLine` [S7]. The message gets a suffix built as `" Path: {path} | LineNumber: {lineNumber} | BytePositionInLine: {bytePositionInLine}."` [S6]. There is no structured expected/found: the expected type is prose in the message, e.g. `The JSON value could not be converted to System.String.` [S4][S5], and the found value is not reported. Path syntax being JSONPath-like (`$.a[0].b`) is (unverified, from memory).
- **D. null vs absent.** Treated as orthogonal axes: "System.Text.Json treats required and non-nullable properties as orthogonal concepts" [S8]. With `RespectNullableAnnotations` (.NET 9), `{"Name":null}` into non-nullable `string Name` throws `The constructor parameter 'Name' on type 'Person' doesn't allow null values. Consider updating its nullability annotation.`, while `{}` does **not** throw and leaves `Name` null [S8]. Without the flag both give null. "NET doesn't have an `undefined` concept, so both cases deserialize to `null`" [S8].
- **E. Input.** `Utf8JsonReader` reads "UTF-8 encoded JSON text, read from a `ReadOnlySpan<byte>`" [S4]; `Deserialize` overloads for both `string` and UTF-8 spans are (unverified, from memory). Invalid UTF-8: the resource `Cannot transcode invalid UTF-8 JSON text to UTF-16 string.` exists [S5]; where it fires was not traced. Trailing data: `'{0}' is invalid after a single JSON value. Expected end of data.` [S5]. Trailing commas and comments are rejected by default "because the RFC 8259 specification doesn't allow them"; `AllowTrailingCommas` opts in [S4][S9]. Duplicate keys: last wins by default (`{ "Value": 1, "Value": -1 }` gives `-1`); .NET 10 adds `AllowDuplicateProperties = false`, which throws (`Duplicate property '{0}' encountered during deserialization of type '{1}'.`) [S10][S5]. Numbers: quoted numbers are rejected by default but accepted under ASP.NET Core's web defaults [S9]; leading zeros rejected [S4]. Overflow of an `int` target was not checked.
- **F. Not-JSON vs wrong shape.** Same public type. Docs show `JsonException` for a syntax error (`''' is an invalid start of a value.`) and for a type mismatch (`The JSON value could not be converted to System.String.`) [S4]. A caller cannot branch on the kind without reading the message.
- **G. Discriminators.** `[JsonDerivedType(typeof(X), "tag")]` on the base; default key `$type`, string or int [S11]. "By default, the `$type` discriminator must be placed at the start of the JSON object"; `AllowOutOfOrderMetadataProperties` (.NET 9) lifts that at the price of "over-buffering (and out-of-memory failures)" on large streamed objects [S11]. Unknown tag: `Read unrecognized type discriminator id '{0}'.` Missing tag on an abstract/interface base: `The JSON payload for polymorphic interface or abstract type '{0}' must specify a type discriminator.` Out-of-order resource: `The metadata property is either not supported by the type or is not the first property in the deserialized JSON object.` [S5]. A missing tag on a **concrete** base silently yields the base type (`value is WeatherForecastWithCity // False`) [S11]. A missing field inside a known member is reported exactly as in B — nothing says which member was chosen.
- **H. Derivation, symmetry.** Derived from the type by reflection or a source generator. Asymmetries: nullability cannot be enforced on top-level types, collection elements (`List<string>` vs `List<string?>` "are indistinguishable") or generic members [S8]; polymorphism works only when the *declared* type is the base, and "is supported in metadata-based source generation, but not fast-path" [S11]; the docs say `required` does not compile under source generation mode [S3].
- **I. Regrets and redesigns.** Every strictness feature arrived late and opt-in: required (.NET 7, [S12a]), unmapped members (.NET 8, [S12b]), nullable enforcement and required ctor params (.NET 9, [S12c]) — "implemented as an opt-in flag in .NET 9 to avoid breaking existing applications. If you're writing a new application, it's highly recommended that you enable this flag" [S3][S8] — out-of-order metadata (.NET 9, [S12d]), duplicate rejection (.NET 10, [S12e]: "can lead to unexpected results and security vulnerabilities" [S10]). .NET 10 bundles them as `JsonSerializerOptions.Strict` [S10]. `TypeNameHandling.All` was excluded on purpose: "Allowing a JSON payload to specify its own type information is a common source of vulnerabilities" [S4].

## 2. Newtonsoft.Json (C#)

- **A.** Ignored by default (`DefaultMissingMemberHandling = MissingMemberHandling.Ignore`) [S13]. `MissingMemberHandling.Error` throws `Could not find member '{0}' on object of type '{1}'` [S14]. Capturing extras via its own `[JsonExtensionData]` is (unverified, from memory).
- **B.** Default (`Required.Default`): not required. `[JsonProperty(Required = Required.Always)]` throws `Required property '{0}' not found in JSON.` [S14].
- **C.** First error. `JsonSerializationException` carries `Path`, `LineNumber`, `LinePosition` [S15]; message suffix is built from `Path '{0}'` and `, line {0}, position {1}` [S16]. Line info on this exception was only added in 12.0.1 [S17]. Type errors read `Error converting value {0} to type '{1}'.` [S14] — found value and expected type, as prose.
- **D.** The one library here that names all four combinations in one enum [S18]: `Default` (not required), `AllowNull` ("must be defined in JSON but can be a null value"), `Always` ("must be defined in JSON and cannot be a null value"), `DisallowNull` ("not required but it cannot be a null value"). Texts: `Required property '{0}' expects a value but got null.` and `Property '{0}' expects a non-null value.` [S14].
- **E.** Trailing data ignored by default (`DefaultCheckAdditionalContent = false`); when on: `Additional text found in JSON string after finishing deserializing object.` [S13][S14]. Comments, trailing commas (even `,,]`), single quotes accepted; leading-zero numbers read as octal [S4]. Duplicate keys when loading a `JToken`: `DuplicatePropertyNameHandling.Replace` (last wins) by default, with `Ignore` and `Error` [S19]. Bytes and invalid UTF-8: not found.
- **F.** Distinct: `JsonReaderException` (syntax) and `JsonSerializationException` (shape), both deriving from `JsonException` [S15].
- **G.** `TypeNameHandling` writes the .NET type name as `$type`; default `None` [S13]. Errors: `Type specified in JSON '{0}' was not resolved.`, `Type specified in JSON '{0}' is not compatible with '{1}'.`, and for an abstract target with no tag `Could not create an instance of type {0}. Type is an interface or abstract class and cannot be instantiated.` [S14].
- **H.** Reflection over the type; one contract for both directions. Asymmetries: not researched.
- **I.** Microsoft's summary: "`Newtonsoft.Json` is flexible by default" against STJ's "strict by default" [S4]. `TypeNameHandling` "allows the remote client to embed an entire executable application within the JSON payload" (Black Hat 2017 "Friday the 13th JSON attacks") [S4]; the source now warns it "should be used with caution" and wants a `SerializationBinder` [S20]. `MaxDepth` defaulted to 64 only in 13.0.1 [S17], tracked as CVE-2024-21907 [S21].

## 3. Thoth.Json (F#)

- **A.** Ignored: a decoder reads only the fields it names (`field` calls `Helpers.getField fieldName value`; nothing inspects the rest) [S22]. No reject switch found.
- **B.** Error. `field` returns `BadField("an object with a field named `" + fieldName + "`", value)`, rendered as ``Error at: `$` `` then `Expecting an object with a field named `name` but instead got:` then the offending JSON [S22].
- **C.** The internal error is structured — `type DecoderError = string * ErrorReason`, path plus one of `BadPrimitive | BadPrimitiveExtra | BadType | BadField | BadPath | TooSmallArray | FailMessage | BadOneOf` [S23] — but the public result of `fromString` is `Result<'T, string>`: the structure is flattened to text at the boundary [S22]. The `object` builder **collects every field error** and reports them together under `The following errors were found:`; `oneOf` keeps each alternative's error and reports all of them the same way (`BadOneOf errors`) [S22]. Paths are `$.a.b`.
- **D.** Chosen per field by the decoder's author. `optional name d`: absent gives `Ok None`; present goes through `decodeMaybeNull`. In the builder API an optional getter maps null and missing (`BadField`, `BadPath`) to `None` but still reports a wrong-typed value as an error [S22].
- **E.** `fromString` takes a string and calls `JS.JSON.parse` [S22], so duplicates, UTF-8 and trailing data are the host parser's. Integers are width-checked by an `integral` helper given `Int32.MinValue`/`MaxValue` and labelled "an int"; `int64`, `uint64`, `bigint` are separate decoders [S22].
- **F.** Same type (`Result<_, string>`); a syntax error is told apart only by its prefix `Given an invalid JSON: ` [S22].
- **G.** Hand-written: `oneOf` tries decoders in order, or `andThen` dispatches on a tag field. Auto-decoder unknown case: `Cannot find case ` + name + ` in ` + type [S22].
- **H.** Hand-written decoders are separate from encoders, so nothing forces symmetry; `Auto.generateDecoder` derives one from the type by reflection, failing with `Cannot generate auto decoder for %s. Please pass an extra decoder.` for unsupported types [S22].
- **I.** Not found.

## 4. FSharp.SystemTextJson and FSharp.Data

**FSharp.SystemTextJson** (converters on top of STJ)
- **A.** Not stated in its docs; presumably inherits STJ's ignore (unverified).
- **B./D.** Stricter than STJ: it throws when "a field's JSON value is `null` or the field is unspecified" and the field type "isn't an explicitly nullable F# type (like `option`, `voption` and `Skippable`)" [S24]. Text: `Missing field for record type %s: %s` [S25]. `None` is `null` by default; `SkippableOptionFields` makes `None` a *missing* field instead; `Skippable<'T option>` "allows distinguishing between a null field and an absent field" [S24][S26].
- **C.** First error, a `JsonException` made by `failf`; mismatch text `Failed to parse type %s: expected %s, found %A` — expected and found, as prose [S27].
- **E./F.** STJ's.
- **G.** Default is adjacent tag `{"Case":..,"Fields":[..]}`; also external, internal, untagged [S24]. `UnionAllowUnorderedTag` is **on by default**, "at the cost of a slight performance penalty" — the opposite of STJ's own default; off: `Failed to find union case field for Example: expected Case` [S24]. Unknown tag: `Unknown case for union type %s: %s`; missing payload field: `Missing field for union type %s`; untagged mode: `Unknown case for union type %s due to unknown field: %s` [S25].
- **H.** Reflection over F# records/unions; same options both ways.
- **I.** Not found.

**FSharp.Data JsonProvider** — the type is *inferred from a sample document*, not declared, so most of A–I is not applicable. Shape errors are lazy: "a runtime error may occur (but only when explicitly accessing an element incompatible with the original sample — e.g. if it is no longer present)". A property missing from some sample records is inferred as `option` [S28].

## 5. Jackson (JVM)

- **A.** Jackson 2.x rejects: `FAIL_ON_UNKNOWN_PROPERTIES(true)` [S29], text `Unrecognized field "%s" (class %s), not marked as ignorable` [S30]. Spring disables it in every mapper it builds: "`DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES` is disabled" [S31][S32]. **Jackson 3.0 flipped the default to `false`** [S33], with the migration guide noting it "May mask real issues with name mismatch" [S34]. `@JsonAnySetter` capturing extras and `@JsonIgnoreProperties(ignoreUnknown = true)`: (unverified, from memory).
- **B.** Not an error: `FAIL_ON_MISSING_CREATOR_PROPERTIES(false)`; missing creator properties "are filled with null values ... (usually null for Object types, and default value for primitives)" unless "explicitly marked as `required`" [S29]. Texts: `Missing required creator property '%s' (index %d)` and ``Missing creator property '%s' (index %d); `DeserializationFeature.FAIL_ON_MISSING_CREATOR_PROPERTIES` enabled`` [S35]. That `required = true` is enforced only on creator parameters, not setters/fields, is (unverified, from memory).
- **C.** First error ("information on the first one (by index) of missing properties" [S29]). `MismatchedInputException`: ``Cannot deserialize value of type %s from %s (token `JsonToken.%s`)`` [S36], with the path appended as ` (through reference chain: ...)` [S37]. Expected type and found token are both in the prose.
- **D.** Not distinguished by default. `FAIL_ON_NULL_FOR_PRIMITIVES` is off in 2.x, so `null` into `int` becomes `0` ("same defaulting as what JVM uses"); "will be changed to enabled in 3.0" [S29], and was [S33].
- **E.** Trailing tokens: unchecked in 2.x "for backwards compatibility reasons" [S29], **enabled by default in 3.0** [S34]; text ``Trailing token (of type %s) found after value (bound as %s): not allowed as per `DeserializationFeature.FAIL_ON_TRAILING_TOKENS` `` [S36]. Duplicate keys: `STRICT_DUPLICATE_DETECTION(false)` because it "typically adds 20-30% to execution time"; when on, `Duplicate field '`name`'` [S38][S39]. Invalid UTF-8: `Invalid UTF-8 start byte 0x..` [S40]. Integers: `Numeric value (%s) out of range of int (%d - %s)` [S41]; `ACCEPT_FLOAT_AS_INT(true)` is on by default [S29]. `byte[]`/`String`/`InputStream` overloads: (unverified, from memory).
- **F.** Distinct: `JsonParseException` (a `StreamReadException`, jackson-core) vs `MismatchedInputException` (a `JsonMappingException`, databind) [S42]. In 2.x both descend from a checked exception extending `IOException`; 3.x makes them unchecked `JacksonException` [S34].
- **G.** `@JsonTypeInfo`. Unknown tag: `Could not resolve type id '%s' as a subtype of %s` plus `known type ids = [...]` — it lists the legal tags [S36][S43]. Missing tag: `missing type id property '%s'` [S44].
- **H.** Reflection plus annotations. Asymmetries: not researched.
- **I.** The polymorphic-deserialization CVEs: exploitable when a service takes untrusted JSON, "enables 'Default Typing' ... (or uses equivalent `@JsonTypeInfo` with base type of `java.lang.Object`)" and has "gadget" classes on the classpath; the block list reached "about 90 specific classes across 30-40 libraries" before 2.10 replaced it with an allow list (`PolymorphicTypeValidator`) because the "block-list approach has proven insufficient" [S45][S46]. Jackson 3.0 changed three wire-decoding defaults at once (A, D, E) [S34].

## 6. Gson (JVM, brief)

- **A.** Ignoring unknown keys: (unverified, from memory).
- **B.** Silent default: "a missing entry in JSON results in setting the corresponding field in the object to its default value: null for object types, zero for numeric types, and false for booleans" [S47]. Worse, without a no-args constructor Gson uses "JDK `Unsafe` ... to create an instance of your class without invoking the constructor and without running any initializers", so declared defaults vanish [S48].
- **C.** First error: `IllegalStateException: Expected a string but was BEGIN_ARRAY at line 2 column 17 path $.languages` — expected, found, line/column, JSONPath in one string [S48].
- **D.** Not distinguished; nulls are omitted on write unless `serializeNulls()` [S47].
- **E.** "Due to legacy reasons Gson performs parsing by default in lenient mode"; `Strictness.STRICT` since 2.11.0. An integer read as `Object` comes back as `double` [S48].
- **F.** `MalformedJsonException` for syntax vs `IllegalStateException` "Expected ... but was ..." for shape [S48].
- **G.** No built-in mechanism found in the user guide. **H.** Reflection over fields. 
- **I.** "Gson is currently in maintenance mode"; "Kotlin's non-`null` types or constructors with default arguments are not supported. This can lead to confusing and incorrect behavior" [S49].

## 7. kotlinx.serialization (Kotlin)

- **A.** Rejected by default: "By default, unknown keys encountered during deserialization produce an error" [S50]:
  ```
  kotlinx.serialization.json.JsonDecodingException: Unexpected JSON token at offset 29: Encountered an unknown key 'unknownKey' at path: $.inner
  Use 'ignoreUnknownKeys = true' in 'Json {}' builder or '@JsonIgnoreUnknownKeys' annotation to ignore unknown keys.
  ```
  Switchable globally (`Json { ignoreUnknownKeys = true }`) or per class [S50].
- **B.** Error [S51]: `kotlinx.serialization.MissingFieldException: Field 'language' is required for type with serial name 'example.exampleClasses04.Project', but it was missing at path: $`. All missing fields of one object are listed together: `Fields $missingFields are required for type with serial name '$serialName', but they were missing` [S52]. The path is the *object's*; the field is named in prose. A property is optional exactly when it has a default value [S51].
- **C.** First error; message = `Unexpected JSON token at offset $offset: ` + reason + ` at path: ` + JSONPath, often with a hint line naming the option that would accept the input [S53][S50].
- **D.** Distinguished by default: a nullable property without a default is still required; `null` into a non-nullable gives `Expected string literal but 'null' literal was found at path: $.language` [S51]. `explicitNulls = false` makes absence mean null; `coerceInputValues = true` treats "`null` inputs for non-nullable types" and "unknown values for enums" "as if the corresponding property was missing" [S50].
- **E.** Trailing data: `Expected EOF after parsing, but had ${...} instead`; overflow: `Numeric value overflow`, `Failed to parse int for input '$value'` [S54][S55]. Bytes/streams and duplicate keys: not found in the JSON guide.
- **F.** Syntax errors and most shape errors (unknown key, null, wrong token) share `JsonDecodingException`; a missing field is the separate `MissingFieldException`. `SerializationException` extends `IllegalArgumentException` [S52]; `JsonDecodingException` extending it is (unverified, from memory).
- **G.** Sealed classes get a discriminator key (`"type"` by default, `classDiscriminator` to rename) [S50]. Unknown tag: `Unexpected JSON token at offset 0: Serializer for subclass 'unknown' is not found in the polymorphic scope of 'Project' at path: $` [S56]. Missing tag: `Class discriminator was missing and no default serializers were registered $scope.` [S57]. `JsonContentPolymorphicSerializer` chooses by shape instead [S50].
- **H.** A compiler plugin generates the serializer from the `@Serializable` class; one `KSerializer` does both directions. Documented asymmetry: with `explicitNulls = false`, a nullable property with a non-null default "becomes asymmetrical" (`null` written, default read back) [S50].
- **I.** Not found.

---

## What stands out

1. **Lenient defaults get regretted, and are then unfixable.** STJ shipped five opt-in strictness flags over .NET 7–10 and finally a `Strict` preset, each time citing compatibility [S3][S8][S10]. Jackson 2.x left trailing-token checking off "for backwards compatibility reasons" and needed a major version to turn it on [S29][S34]. Gson is lenient "due to legacy reasons" [S48].
2. **Unknown keys is the one default with no consensus.** kotlinx rejects; Jackson 2 rejected, Spring switched that off for everyone, and Jackson 3 gave in and ignores [S31][S33]; STJ, Newtonsoft, Gson, Thoth ignore.
3. **Required and nullable are two axes.** Newtonsoft's four-value `Required` enum [S18] and STJ's "orthogonal concepts" [S8] say it outright; kotlinx gets it from the type (default value = optional, `?` = nullable) [S51]. Libraries that fuse them (Gson, Jackson 2 defaults) turn absent into `null`/`0` silently.
4. **Nobody returns `{Path, Expected}` as data.** All throw the first error with expected/found baked into prose. Thoth has the structure internally (`string * ErrorReason`) and flattens it to a string at its public boundary [S22][S23].
5. **Missing-field errors point at the parent.** STJ, kotlinx and Thoth all give the enclosing object's path and name the field in the message; STJ and kotlinx list *all* missing fields of that object at once [S5][S52].
6. **Collecting all errors is rare** and where it exists it is scoped: Thoth's `object` builder and `oneOf` [S22].
7. **Syntax vs shape:** Newtonsoft, Jackson and Gson use distinct exception types; STJ and kotlinx largely merge them; Thoth offers only a string prefix.
8. **Tag-must-be-first is a streaming-parser leak.** STJ required it until .NET 9 and still warns of over-buffering [S11]; FSharp.SystemTextJson defaults the other way [S24].
9. **Unknown-tag errors differ in usefulness:** Jackson lists the known type ids [S43]; STJ and kotlinx name only the offending tag. A missing tag on a concrete STJ base type silently decodes as the base [S11].
10. **Type names in the payload are the security story** (Newtonsoft `TypeNameHandling`, Jackson default typing); every later design uses a closed, declared tag set [S4][S45].
11. **Duplicate keys default to last-wins everywhere checked**, and STJ's own docs call that a vulnerability source [S10].

## Sources (all fetched 2026-10-09)

- S1 https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/missing-members
- S2 https://github.com/dotnet/docs/blob/main/docs/standard/serialization/system-text-json/handle-overflow.md
- S3 https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/required-properties
- S4 https://github.com/dotnet/docs/blob/main/docs/standard/serialization/system-text-json/migrate-from-newtonsoft.md
- S5 https://github.com/dotnet/runtime/blob/main/src/libraries/System.Text.Json/src/Resources/Strings.resx
- S6 https://github.com/dotnet/runtime/blob/main/src/libraries/System.Text.Json/src/System/Text/Json/ThrowHelper.Serialization.cs
- S7 https://github.com/dotnet/runtime/blob/main/src/libraries/System.Text.Json/src/System/Text/Json/JsonException.cs
- S8 https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/nullable-annotations
- S9 https://github.com/dotnet/docs/blob/main/docs/standard/serialization/system-text-json/invalid-json.md
- S10 https://github.com/dotnet/docs/blob/main/docs/core/whats-new/dotnet-10/libraries.md
- S11 https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/polymorphism
- S12a https://github.com/dotnet/runtime/issues/29861 · S12b https://github.com/dotnet/runtime/issues/37483 · S12c https://github.com/dotnet/runtime/issues/1256 and https://github.com/dotnet/runtime/issues/100144 · S12d https://github.com/dotnet/runtime/issues/72604 · S12e https://github.com/dotnet/runtime/issues/108521 (titles and milestones read via api.github.com; bodies not read) · polymorphism: https://github.com/dotnet/runtime/issues/63747
- S13 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/JsonSerializerSettings.cs
- S14 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/Serialization/JsonSerializerInternalReader.cs
- S15 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/JsonSerializationException.cs and `JsonReaderException.cs`, `JsonException.cs` beside it
- S16 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/JsonPosition.cs
- S17 https://api.github.com/repos/JamesNK/Newtonsoft.Json/releases (12.0.1, 13.0.1 notes)
- S18 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/Required.cs
- S19 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/Linq/DuplicatePropertyNameHandling.cs
- S20 https://github.com/JamesNK/Newtonsoft.Json/blob/master/Src/Newtonsoft.Json/TypeNameHandling.cs
- S21 https://github.com/advisories/GHSA-5crp-9r3c-p9vr
- S22 https://github.com/thoth-org/Thoth.Json/blob/main/packages/Thoth.Json/Decode.fs
- S23 https://github.com/thoth-org/Thoth.Json/blob/main/packages/Thoth.Json/Types.fs
- S24 https://github.com/Tarmil/FSharp.SystemTextJson/blob/master/docs/Customizing.md
- S25 https://github.com/Tarmil/FSharp.SystemTextJson/blob/master/src/FSharp.SystemTextJson/Record.fs and `Union.fs` beside it (the grep ran across both; which file holds which line was not separated)
- S26 https://github.com/Tarmil/FSharp.SystemTextJson/blob/master/docs/Format.md
- S27 https://github.com/Tarmil/FSharp.SystemTextJson/blob/master/src/FSharp.SystemTextJson/Helpers.fs
- S28 https://github.com/fsprojects/FSharp.Data/blob/main/docs/library/JsonProvider.fsx
- S29 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/DeserializationFeature.java
- S30 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/exc/UnrecognizedPropertyException.java
- S31 https://github.com/spring-projects/spring-boot/blob/3.5.x/spring-boot-project/spring-boot-docs/src/docs/antora/modules/how-to/pages/spring-mvc.adoc
- S32 https://github.com/spring-projects/spring-framework/blob/6.2.x/spring-web/src/main/java/org/springframework/http/converter/json/Jackson2ObjectMapperBuilder.java
- S33 https://github.com/FasterXML/jackson-databind/blob/3.x/src/main/java/tools/jackson/databind/DeserializationFeature.java
- S34 https://github.com/FasterXML/jackson/blob/main/jackson3/MIGRATING_TO_JACKSON_3.md
- S35 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/deser/impl/PropertyValueBuffer.java
- S36 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/DeserializationContext.java
- S37 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/JsonMappingException.java
- S38 https://github.com/FasterXML/jackson-core/blob/2.19/src/main/java/com/fasterxml/jackson/core/JsonParser.java
- S39 https://github.com/FasterXML/jackson-core/blob/2.19/src/main/java/com/fasterxml/jackson/core/json/JsonReadContext.java
- S40 https://github.com/FasterXML/jackson-core/blob/2.19/src/main/java/com/fasterxml/jackson/core/json/UTF8StreamJsonParser.java
- S41 https://github.com/FasterXML/jackson-core/blob/2.19/src/main/java/com/fasterxml/jackson/core/base/ParserBase.java or `ParserMinimalBase.java` beside it (grep ran across both)
- S42 class declarations in jackson-databind `exc/MismatchedInputException.java`, `JsonMappingException.java` and jackson-core `JsonParseException.java`, `exc/StreamReadException.java` (2.19 branches, same repos as S36/S38); only the class names were read, the `extends` clauses were not
- S43 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/jsontype/impl/TypeDeserializerBase.java
- S44 https://github.com/FasterXML/jackson-databind/blob/2.19/src/main/java/com/fasterxml/jackson/databind/jsontype/impl/AsPropertyTypeDeserializer.java
- S45 https://github.com/FasterXML/jackson/wiki/Jackson-Polymorphic-Deserialization-CVE-Criteria
- S46 https://github.com/FasterXML/jackson/wiki/Jackson-Release-2.10
- S47 https://github.com/google/gson/blob/main/UserGuide.md
- S48 https://github.com/google/gson/blob/main/Troubleshooting.md
- S49 https://github.com/google/gson/blob/main/README.md
- S50 https://github.com/Kotlin/kotlinx.serialization/blob/master/docs/json.md
- S51 https://github.com/Kotlin/kotlinx.serialization/blob/master/docs/basic-serialization.md
- S52 https://github.com/Kotlin/kotlinx.serialization/blob/master/core/commonMain/src/kotlinx/serialization/SerializationExceptions.kt
- S53 https://github.com/Kotlin/kotlinx.serialization/blob/master/formats/json/commonMain/src/kotlinx/serialization/json/internal/JsonExceptions.kt
- S54 https://github.com/Kotlin/kotlinx.serialization/blob/master/formats/json/commonMain/src/kotlinx/serialization/json/internal/lexer/AbstractJsonLexer.kt
- S55 https://github.com/Kotlin/kotlinx.serialization/blob/master/formats/json/commonMain/src/kotlinx/serialization/json/internal/StreamingJsonDecoder.kt
- S56 https://github.com/Kotlin/kotlinx.serialization/blob/master/docs/polymorphism.md
- S57 https://github.com/Kotlin/kotlinx.serialization/tree/master/formats/json/commonMain/src/kotlinx/serialization/json/internal (the string was matched by a grep across `Polymorphic.kt`, `StreamingJsonDecoder.kt`, `TreeJsonDecoder.kt`, `JsonExceptions.kt`; the exact file was not isolated)

Not reachable: https://cowtowncoder.medium.com/on-jackson-cves-dont-panic-here-is-what-you-need-to-know-54cd0d6e8062 returned HTTP 403; the Jackson wiki page S45 that summarises it was used instead.
