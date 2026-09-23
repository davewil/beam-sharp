# 78 — The decode direction: does `ValidateAs<T>` learn the wire form, or is there a `FromJson<T>`?

Type: grilling
Status: claimed 2026-09-24 — [ENG-373](https://linear.app/davewil/issue/ENG-373). Raised 2026-09-15 on resolving
[ticket 77](77-what-goes-on-the-wire.md), whose finding 2 is this ticket's premise
Blocked by: —

## Why this is raised

[Ticket 16](16-ad-hoc-polymorphism.md) §4 decreed the serialisation obligation and said *"only the
encode direction is new"*: decoding is *parse to a `term`, then `ValidateAs<T>`*, and that is
already built. Ticket 77 measured that sentence on `examples/Intake`, whose `Decode` is exactly
that, and it is built for the erasure only:

```
Decode([#{'Kind' => 'Intake.Reading', 'Sensor' => <<"a">>, 'Value' => 1}])
   => [{Kind = :'Intake.Reading', Sensor = "a", Value = 1}]              the erasure: accepted

Decode([#{<<"Kind">> => <<"Intake.Reading">>, <<"Sensor">> => <<"a">>, <<"Value">> => 1}])
   => (:error, (["[0]"], "{ Kind: :'Intake.Reading', Sensor: string, Value: int }"))
                                                                           json:decode's output: refused
```

`json:decode` returns binary keys and a binary tag; `ValidateAs<Reading>` accepts only the
erasure's atom keys and atom tag. The same holds for a field typed `:credit | :debit`, which
arrives as `<<"credit">>`. So an HTTP handler's first request is refused today, and 77 could not
close the decree without leaving this half owed.

## What is already decided, and is not reopened here

- **77** — the encode direction: the wire form is the platform's encoding of the erased term, and
  the published mapping's rows. This ticket is its inverse and changes no row.
- **18** — `ValidateAs<T>` is the explicit deep check that a `term` inhabits `T`, returning
  `result<T, ValidationError>`; the boundary guard is emitted unconditionally where generated code
  consumes a term (18 §1(c)).
- **26 §1** — a record erases to a map with `Kind` minted from the qualified type name and the
  field names as atoms. The erasure is the value the language computes on; it is not in question.
- **10 §2** — `:null` is the atom OTP's `json` returns for JSON `null`; **10 §4 / F39** —
  `ParseAtom<T>` is the check that a runtime-built value is one of `T`'s atoms, and the atoms a
  type names exist in the table by construction.
- **67** — an obligation is a compiler-known entry, inlined at its site.
- **69** — `float`, resolved 2026-09-15 and built as F51 (ENG-378). A JSON number with a fraction
  decodes to one; `ValidateAs<float>` is F51's.

## The program

25a's handler receiving its request body. The body has been through the platform's parser, so its
keys are binaries.

```csharp
module Intake

record Reading { Sensor: string, Value: int }

public result<list<Reading>, ValidationError> Decode(term body)
Decode(body) -> ValidateAs<list<Reading>>(body)
```

### Under "`ValidateAs<T>` learns the wire form"

The program above compiles unchanged and accepts both terms. At a record, the walk accepts the
key `<<"Kind">>` beside `'Kind'` and a binary tag equal to the minted tag's name; at every field
whose declared key is an atom, the binary spelling of that key; at an atom-typed position, a binary
equal to the name of one of the type's atoms. The value it returns is the erasure — atom keys, atom
tag, atoms — so `ValidateAs<T>` converts as well as checks, and the atoms it makes are ones the
type names, so `binary_to_existing_atom` cannot fail.

```
Decode([#{<<"Kind">> => <<"Intake.Reading">>, <<"Sensor">> => <<"a">>, <<"Value">> => 1}])
   => [{Kind = :'Intake.Reading', Sensor = "a", Value = 1}]
```

The cost: two terms now validate to one value. A BEAM sender that meant `<<"Kind">>` as a binary
key in a `map<string, int>` and a JSON sender that meant it as a record's tag are told apart today
and would not be; and a `string`-typed field whose value happens to spell an atom of a sibling
union member gains a second reading.

### Under "`FromJson<T>`, the inverse walk"

```csharp
public result<list<Reading>, ValidationError> Decode(string body)
Decode(body) -> FromJson<list<Reading>>(body)
```

A sixth stratum-2 obligation: the platform's `json:decode`, then a walk over the normalised
members of `T` that converts by type — binary keys to the declared atoms, a binary tag to the
minted tag, a binary at an atom-typed position to that atom — and then `ValidateAs<T>`'s check on
the result, with the exact-set test 26 §4 owes. `ValidateAs<T>` is untouched and remains a check on
BEAM terms. Refused at the declaration for the same members `ToJson<T>` refuses, since nothing on
the wire can produce them.

The cost: a second name, and a handler whose framework has already parsed the body (a map in hand,
not a string) has no entry — it would have to re-encode, or the language owes a `FromWire<T>` on
the parsed term as well, which is the first option under a different name.

## The compiler delta

Under the first: `bs_check`'s `ValidateAs<T>` walk gains a wire clause at three positions (record
key, record tag, atom-typed leaf), and `bs_emit`'s generated check gains the conversion; F18's
tests gain the wire-form controls; `check-validate-target.sh`'s stub set gains a wire term.

Under the second: `bs_check` gains `FromJson<T>` beside `ToJson<T>` (ENG-375), `string` in,
`result<T, ValidationError>` out, ground `T` only; `bs_diag` reuses `unencodable_member`;
`bs_emit` inlines `json:decode` then the conversion walk then the check; `STANDARD-ENVIRONMENT.md`
gains a row.

## The question

Which of the two programs above is the language's — `ValidateAs<T>` accepting the wire form beside
the erasure and returning the erasure, or `FromJson<T>` as `ToJson<T>`'s inverse with
`ValidateAs<T>` left a check on BEAM terms? The round is written when it is asked.

## Round 1 — 2026-09-24: whose schema does the decode direction serve?

Asked alone, because it gates the question above. Both programs in *The question* read back a
record **this program wrote**: `Kind` on the wire, PascalCase keys. Exemplar 25f
([`25f-llm-evaluation-client.md`](../prototypes/25f-llm-evaluation-client.md), friction 2) is the
other case, and neither program reaches it. The reply comes from TypeSafe's API, as `json:decode`
hands it over:

```
#{<<"model">> => <<"jev-1.13.0">>,
  <<"answers">> => #{<<"urgent">> => #{<<"type">> => <<"noul">>, <<"noul">> => 0.93}},
  <<"usage">> => #{<<"input_tokens">> => 100, <<"output_tokens">> => 20}}
```

No `Kind`, lowercase keys, snake_case. The program an author wants:

```csharp
record Usage { InputTokens: int, OutputTokens: int }
record Reply { Model: string, Answers: map<string, map<string, term>>, Usage: Usage }

private result<Reply, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<Reply>(doc)          // or FromJson<Reply>(text)
```

**Q1. Must ticket 78's answer make `Read` above decode that reply?**

- **Yes:** 78 grows. Before choosing between `ValidateAs` and `FromJson`, it has to settle where a
  field's wire name is written (`InputTokens` ↔ `"input_tokens"`) and whether a record may arrive
  without `Kind`. Because 77 decided encode writes `Kind` and PascalCase, a yes also raises whether
  `ToJson<Reply>` writes the same names back, so it touches 77's record row.
- **No:** 78 stays as written: the program's own records coming back. 25f's `decode.bs` stays at
  `:maps.find` plus one `ValidateAs` per value, 101 lines, until a separate ticket takes foreign
  schemas.

Recommended: **yes.** A BEAM program reading its own records back mostly uses
`term_to_binary`, not JSON. JSON on the BEAM is overwhelmingly someone else's schema: an HTTP API,
a webhook, an LLM provider. A decode answer that cannot read one leaves the common case on
`:maps.find`.

**Answered 2026-09-24 (David): yes.** Ticket 78's answer must decode a schema the program does not
own. The choice between `ValidateAs<T>` and `FromJson<T>` waits on where a wire name lives.

## Round 2 — 2026-09-24: does a wire name live in a type, or on the record?

Asked alone: whether a record may arrive without `Kind`, whether `ToJson` writes the names back,
and `ValidateAs` against `FromJson` all depend on it.

**Measured first** (a scratch module per probe, `bsc` at `17ffead`). The brace field-set type
ticket 48 found shipped already does most of it, with atom keys:

| Probe | Result |
|---|---|
| `type UsageWire = { InputTokens: int, OutputTokens: int }`, destructured `Tokens({ InputTokens: i, OutputTokens: o })`, handed a map with an extra key | matches; extra keys pass, as a pattern is partial |
| `ValidateAs<UsageWire>` on the same map | `(:error, … Path = [])`: the validator's field set is **exact** (26 §4), so the extra key is refused |
| `ValidateAs<UsageWire>` with no extra key | accepted, returned unchanged |
| `ToJson<UsageWire>` | `{"InputTokens":100,"OutputTokens":20}`: no `Kind`, since the type has none |
| `type UsageWire = { "input_tokens": int }` | syntax error before `"input_tokens"` |

So the field-set type has no tag and already crosses both directions; what it lacks is a key that
is the wire's string.

**The program, if the wire name lives in a type:**

```csharp
type UsageWire = { "input_tokens": int, "output_tokens": int }
type ReplyWire = { "model": string, "answers": map<string, map<string, term>>, "usage": UsageWire }

record Usage { InputTokens: int, OutputTokens: int }

private result<ReplyWire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<ReplyWire>(doc)

private Usage Tokens(UsageWire u)
Tokens({ "input_tokens": i, "output_tokens": o }) -> Usage { InputTokens = i, OutputTokens = o }
```

The wire type is structural: no `Kind`, no minted tag, keys exactly as the other side writes them.
The domain record stays as 26 and 77 made it, and a clause head moves one to the other.
Compiler delta: the field-set grammar takes a string literal as a key (`bs_parser.yrl`, the type
and the pattern rule); `bs_types` map members keyed by a binary beside an atom; the printer writes
it back quoted; `ValidateAs` and `ToJson` walk it unchanged, since both read the key from the type.

**The program, if the wire name lives on the record:**

```csharp
record Usage { InputTokens: int <wire name "input_tokens">, OutputTokens: int <wire name "output_tokens"> }

private result<Usage, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<Usage>(doc)
```

(`<wire name …>` is a placeholder; no spelling is proposed.) One declaration, no copying. But the
record now has two names per field, it must be allowed to arrive without `Kind`, and `ToJson<Usage>`
must decide whether it writes `"InputTokens"` (77's row) or `"input_tokens"`. Compiler delta: a
field annotation in the grammar; the validator matches the wire key and supplies the minted
`Kind`; the encoder chooses a key per field; 77's record row is amended.

**Q2. Does a field's wire name live in a structural type whose keys are the wire's strings, or on
the record?**

Recommended: **a type.** It is one grammar addition to a construct that already carries no tag
and already crosses both directions, and it leaves `Kind` and 77's record row alone. The copy into
the domain record is one clause head per object, which is the language's own idiom for taking a
term apart. The record route makes three decisions (field annotation, `Kind`-less arrival, which
name `ToJson` writes) in order to avoid that clause.

**Answered 2026-09-24 (David): a type.** A field's wire name lives in a structural field-set type
whose keys are the wire's strings, `{ "input_tokens": int }`; the domain record stays as 26 and 77
made it, and a clause head copies one into the other. Records, `Kind` and 77's record row are not
touched.

## Round 3 — 2026-09-24: extra keys, and whether a record still comes back from JSON

**Measured first** (`bsc` at `17ffead`):

| Probe | Result |
|---|---|
| `type W = { InputTokens: int, .. }` | syntax error before `..`: no open field-set type can be written |
| `ToJson<W>(w)` where `w` arrived through a public `W` parameter carrying an extra key | the parameter guard passed it (presence and value tests, no size test, §11); `ToJson` crashed with `to_json {… Expected = "{ InputTokens: int }", Path = []}` |

So `ToJson` already refuses to publish an undeclared key at its own site, which is the reason
26 §4 / 18 §1(c) gave for the exact-set test. And with string-keyed wire types, `json:decode`'s
output validates as it stands: binary keys against binary keys, no conversion. The choice this
ticket was raised on, `ValidateAs<T>` learning the wire form or a `FromJson<T>`, is then only about
a **record** coming back.

**Q3. May a wire type say it accepts keys it does not name?**

OpenRouter's reply to the same request carries `id`, `provider` and `usage.cost`; TypeSafe's does
not. Today `ValidateAs<ReplyWire>` refuses the OpenRouter reply outright.

```csharp
type UsageWire = { "input_tokens": int, "output_tokens": int, .. }
type ReplyWire = { "model": string, "answers": map<string, map<string, term>>, "usage": UsageWire, .. }

private result<ReplyWire, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<ReplyWire>(doc)
```

With a trailing `..`, the type is an open field set: `ValidateAs` checks the named keys and returns
the value unchanged, extra keys included. Without it the type stays exact, as today. `ToJson` over
an open type is refused at the declaration, since it would publish keys no type declares. The `..`
is the list pattern's rest marker, meaning *and more* in the same way.

Compiler delta: the field-set type rule takes a trailing `..` (`bs_parser.yrl`); `bs_types`
already has `{open, Fields}` members, so the type needs only to be built as one; `ValidateAs`'s
generated check drops its size test for an open member; `ToJson`'s declaration walk refuses an
open member with `unencodable_member`.

Recommended: **yes, with `..`, exact by default.** The type says what the value is, so
`ValidateAs` stays a check and converts nothing. The alternative that needs no syntax, a validator
that drops unnamed keys, makes `ValidateAs` rewrite the value, which this ticket's first program
was already criticised for.

**Q4. Does ticket 78 still owe reading a record back from JSON?**

The case left is `examples/Intake`: a B# service reading a `Reading` that another B# service wrote
with `ToJson<Reading>`, so `"Kind":"Intake.Reading"` and PascalCase keys are on the wire.

If **yes**, the original question stands and is asked next: `ValidateAs<Reading>` accepting
`<<"Kind">>` and a binary tag, or `FromJson<Reading>(text)`.

If **no**, a record comes back like any other object, through a wire type and a clause head:

```csharp
type ReadingWire = { "Kind": string, "Sensor": string, "Value": int }

private result<Reading, ValidationError> Decode(term body)
Decode(body) -> ValidateAs<ReadingWire>(body) |?> Rebuild()

private Reading Rebuild(ReadingWire w)
Rebuild({ "Sensor": s, "Value": v }) -> Reading { Sensor = s, Value = v }
```

and the inverse of `ToJson<Reading>` is deferred, recorded with what it would need.

Recommended: **no, deferred.** B# services talking to each other on the BEAM use distribution or
`term_to_binary`, where the erasure crosses intact and `ValidateAs<Reading>` already works. JSON
between two B# services is the rare case, and the wire type covers it at the cost shown. What the
deferred inverse would need is recorded when this is answered.

