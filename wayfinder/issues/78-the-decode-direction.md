# 78 — The decode direction: does `ValidateAs<T>` learn the wire form, or is there a `FromJson<T>`?

Type: grilling
Status: resolved 2026-09-24 — [ENG-373](https://linear.app/davewil/issue/ENG-373). Raised 2026-09-15 on resolving
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

**Answered 2026-09-24 (David): Q3 yes, Q4 no.**

- **Q3.** A trailing `..` makes a wire type an open field set. `ValidateAs` checks the named keys
  and returns the value unchanged; the type stays exact without it; `ToJson` refuses an open type
  at the declaration. `ValidateAs` converts nothing *(corrected in round 5: nothing beyond the
  one conversion 26 §4 already decided, an absent key to `:nothing` for an `option<T>` field)*.
- **Q4.** Reading a B# record back from JSON is **deferred**. A record written by `ToJson` comes
  back through a wire type and a clause head, as in the `ReadingWire` program above.

**What the deferred inverse would need**, so it is not lost (the user's rule on deferred options):
a walk that accepts the key `<<"Kind">>` with a binary equal to the minted tag's name, binary keys
equal to the declared field names, and a binary at an atom-typed position equal to one of that
type's atoms, returning the erasure; the exact-set test 26 §4 owes; and the choice this ticket was
raised on, `ValidateAs<T>` learning it or a `FromJson<T>(string)`, which is where it would be
decided. Its test is `examples/Intake` handed the output of `json:decode(ToJson<Reading>(r))`. The
trigger to reopen: a B# program that exchanges records with another B# program over JSON rather
than distribution.

## Round 4 — 2026-09-24: telling wire shapes apart, and reading a field

**Measured first** (atom keys standing in for string keys, which do not parse yet):
`{ Type: string, Choice: string } | { Type: string, Noul: float }` validates and dispatches by key
presence, `Go({ Choice: c })` / `Go({ Noul: p })`, exhaustive. That works because both members are
**exact**. Q3 made wire types open, and an open member may carry another member's keys, so key
presence stops identifying the member. A string in type position, `{ Type: "noul" }`, is a syntax
error: ticket 30 admitted a string literal as a *pattern*, and the algebra has no string singleton
type.

**Q5. May a wire field be a string literal, so a union of wire types is told apart by its
discriminator's value?**

Anthropic's streaming events, the shape every LLM client reads:

```csharp
type Start = { "type": "content_block_start", "index": int, "content_block": map<string, term>, .. }
type Delta = { "type": "content_block_delta", "index": int, "delta": map<string, term>, .. }
type Stop  = { "type": "message_stop", .. }
type Ping  = { "type": "ping", .. }
type Event = Start | Delta | Stop | Ping

private result<Event, ValidationError> Read(term doc)
Read(doc) -> ValidateAs<Event>(doc)

private atom Kind(Event e)
Kind({ "type": "content_block_start" }) -> :start
Kind({ "type": "content_block_delta" }) -> :delta
Kind({ "type": "message_stop" })        -> :stop
Kind({ "type": "ping" })                -> :ping
```

Under **yes**, this compiles and `Kind` is exhaustive with no `_`: a new event type in `Event`
makes `Kind` fail to compile. `ValidateAs<Event>` refuses an event type the union does not name.
Compiler delta: a string literal is a type; the `bins` part of `bs_types` gains finite sets of
literal values beside `utf8` and `other`, as the atom part has finite and cofinite sets; a string
literal pattern then subtracts its singleton, so a union of literal-tagged members closes;
`ValidateAs` tests the value with `=:=`; `ToJson` writes it unchanged. `string` itself stays open,
so ticket 30's *a `string`'s residual is always open* still holds.

Under **no**, `Stop` and `Ping` are the same type, `{ "type": string, .. }`, so `Event` collapses
and cannot be dispatched. The author validates one flat shape and branches by hand:

```csharp
type Event = { "type": string, .. }

private atom Kind(Event e)
Kind({ "type": t }) -> t switch {
    "content_block_start" => :start,
    "content_block_delta" => :delta,
    "message_stop"        => :stop,
    "ping"                => :ping,
    _                     => :unknown
}
```

with a second `ValidateAs` per branch for that event's own fields, and no exhaustiveness.

Recommended: **yes.** A tagged union whose tag is a string is how JSON APIs model variants, and
proving a dispatch over it exhaustive is what this language is for. Q3 is what makes it necessary.

**Q6. Is a string-keyed field read only by a clause head, for now?**

`o.Status` projects because a lowercase receiver followed by a PascalCase field is settled
lexically (26 §3). A string key has no such spelling, and inventing one (`r."model"`, `r["model"]`)
is a surface question of its own. Under **yes**, a wire field is read by destructuring, as Q2's
`Tokens` does, and projection is deferred with its requirements recorded. Under **no**, this ticket
also chooses a projection spelling.

Recommended: **yes, clause heads only.** Q2's answer already routes every wire object through a
clause head into a domain record, where projection works. A projection on the wire type would mostly
serve code that skips that step.

**Answered 2026-09-24 (David): Q5 yes, Q6 yes.**

- **Q5.** A string literal is a type. `{ "type": "ping", .. }` is a member a clause head can name,
  a union of literal-tagged wire types can be covered without `_`, `ValidateAs` compares the value
  with `=:=`, and `ToJson` writes it unchanged. `string` stays open.
- **Q6.** A string-keyed field is read by a clause head. Projection on a wire type is **deferred**;
  what it would need: a spelling for a string key after a value (`r."model"` and `r["model"]` are
  the two on the table), a rule that it is legal only where every member carries the key (26 §3's
  union rule), and a reason to want it, which would be code that reads a wire field without
  copying the object into a record. Reopen on the first such program.

## Round 5 — 2026-09-24: building a wire value, absent keys, and atoms in a wire type

**Measured first** (`bsc` at `17ffead`, atom keys standing in):

| Probe | Result |
|---|---|
| `ValidateAs<{ Id: option<string>, Model: string }>` on a map with no `Id` | refused, `Path = []` |
| the same with a record, `record R { Id: option<string>, … }` | refused, `Path = []` |
| `ValidateAs<{ Id: option<string>, … }>` with `Id => null` | refused, `Expected = ":nothing \| string", Path = [".Id"]` |

26 §4 decided *"`ValidateAs<T>` maps an absent JSON key to `:nothing` for an `option<T>` field"*.
That is **decided and unbuilt**. It is also a conversion, which the Q3 record above now says.

**Q7. Is a wire value built with a brace expression?**

25f's request body, today `:maps.from_list` over pairs, typed `map<term, term>`, so `ToJson` can
say nothing about it:

```csharp
type QuestionWire = { "type": "choice" | "score" | "noul", "instructions": string }
type RequestWire  = { "model": string, "state": Json, "questions": map<string, QuestionWire> }

private string Body(Model m, Json state, map<string, QuestionWire> qs)
Body(m, state, qs) -> ToJson<RequestWire>({ "model" = m.Id, "state" = state, "questions" = qs })

private QuestionWire Wire(YesNo y)
Wire(y) -> { "type" = "noul", "instructions" = y.Instructions }
```

The expression is `{ key = value, … }`: record construction's `=` with no type name in front,
keys being string literals or PascalCase names. It is checked against the type its site expects,
as a record construction is, and it builds an exact field set. Ticket 48 measured this as the one
missing level (type and pattern already take bare braces; `bs_parser.yrl`'s expression rule needs a
record name), and it is 25a's front wall with atom keys, so both exemplars move on one change.
The request side uses exact types, because `ToJson` refuses an open one (Q3).

Compiler delta: `expr -> '{' assign_fields '}'` with a string-literal key form; an `e_map` node;
a `type_of` clause beside `e_record`'s; an expression clause in `bs_emit`.

Recommended: **yes**, for both key kinds at once, since 48 said construction reshapes exactly when
keys become values, and Q2 made them values.

**Q8. Does 26 §4's absent-key rule reach wire types, and is JSON `null` absent?**

TypeSafe's reply has no `id`; OpenRouter's has `"id": "gen-jev-test"`. OpenAI's sends
`"refusal": null`.

```csharp
type ReplyWire = { "id": option<string>, "model": string, "refusal": string | :null, .. }
```

Under the recommendation, `ValidateAs<ReplyWire>` on TypeSafe's reply returns `"id" => :nothing`,
on OpenRouter's returns the string, and a `null` refusal stays `:null`, JSON's own value (10 §2).
An author who wants `null` and absent to mean the same writes `option<string | :null>` and matches
both. Compiler delta: build 26 §4's rule, for records and wire types alike: in the generated check,
an absent key at an `option<T>` field inserts `:nothing` instead of failing.

Recommended: **yes, 26 §4 reaches wire types; `null` is not absent.** 26 §4 is decided, and a wire
type is where absent keys actually occur. Mapping `null` too would be a second conversion, and 10 §2
already gave `null` its own value.

**Q9. Is an atom other than `:null`, `:true` or `:false` in a wire type refused?**

`json:decode` produces no other atom, and `ValidateAs` does not convert a binary to one, so
`{ "type": :ping }` never validates a decoded reply. It fails at run time with `Expected` naming
`:ping` at `["type"]`. But a string-keyed map built on the BEAM may hold any atom, and `ToJson`
writes `:ping` as `"ping"`, so the type is legal for both of those.

Recommended: **not refused.** The type is correct for BEAM-built maps and for encoding; the runtime
error names the field and the expected atom; Q5 gives the author the right spelling,
`"type": "ping"`.

**Answered 2026-09-24 (David): Q7 yes, Q8 yes, Q9 allowed.**

- **Q7.** `{ key = value, … }` builds an exact field set, keys string literals or PascalCase names,
  checked against the type its site expects. It is 25a's front wall too.
- **Q8.** 26 §4's rule reaches wire types: an absent key at an `option<T>` field validates as
  `:nothing`. JSON `null` stays `:null`; `option<string | :null>` accepts both.
- **Q9.** An atom in a wire type is allowed. A decoded reply fails it at run time, naming the field
  and the atom.

## Round 6 — 2026-09-24: from text to a wire value

Every answer so far starts from a decoded term. The step before it, text to term, is where 25f
friction 5 sits: the author declares `json:decode` by hand, and because `result<term,
foreign_error>` collapses (15 §1), the declaration has to list six members, one of them a bare
`atom`:

```csharp
type Json = map<term, term> | list<term> | binary | int | float | atom

using :json {
    result<Json, foreign_error> decode(binary text)
}

private result<ReplyWire, EvalError> Parse(binary body)
Parse(body) -> :json.decode(body) switch {
    (:error, _) => (:error, (:malformed, "the body is not JSON")),
    doc         => ValidateAs<ReplyWire>(doc) switch {
        (:error, e) => (:error, (:malformed, e.Expected)),
        reply       => reply
    }
}
```

**Q10. Is there a `FromJson<T>`, text in, a `T` out?**

```csharp
private result<ReplyWire, ValidationError> Parse(string body)
Parse(body) -> FromJson<ReplyWire>(body)
```

`FromJson<T>(string)` is the platform's `json:decode` followed by `ValidateAs<T>`, returning
`result<T, ValidationError>`. Text that is not JSON is a `ValidationError` with `Path = []` and
`Expected = "JSON"`. `T` is any type `ToJson` accepts, **except one containing a record**, which is
refused at the call naming Q4's deferral: a record's inverse is the part left undecided. It converts
nothing `ValidateAs` does not.

Compiler delta: `FromJson` joins the closed set of names that take a type argument (28's lexer
rule, five names instead of four); `bs_check` resolves it beside `ToJson` (F50) and refuses a record
with a new diagnostic; `bs_emit` inlines `json:decode` under a catch, then the `ValidateAs` walk;
`STANDARD-ENVIRONMENT.md` gains a row. The hand-written `Json` union and its `using` block go.

Recommended: **yes.** It is the ticket's own second program with its scope set by Q2 and Q4: the
inverse of `ToJson` for every type whose wire form is itself. `ValidateAs<T>` stays a check on BEAM
terms, which answers the question this ticket was raised on.

**Answered 2026-09-24 (David): Q10 yes.** `FromJson<T>(string)` is `json:decode` then
`ValidateAs<T>`, returning `result<T, ValidationError>`; invalid text is `Path = []`,
`Expected = "JSON"`; a `T` containing a record is refused, naming Q4's deferral. `ValidateAs<T>`
stays a check on BEAM terms.

The design tree has no open branch. **Confirmed as a whole by David, 2026-09-24.**

## Round 7 — 2026-10-09: what building `FromJson<T>` found (asked after resolution)

The ticket stays resolved. F69 ([ENG-410](https://linear.app/davewil/issue/ENG-410)) built Q10 and
met four points it may not settle itself. They are numbered on from Q10 so they cannot collide
with the rounds above. Each is independent of the other three; what hangs off each is named and
waits for its answer.

**Q11. Is an open type a `FromJson` target?**

```csharp
type ReplyWire = { "id": option<string>, "model": string, .. }

public result<ReplyWire, ValidationError> Parse(string body)
Parse(body) -> FromJson<ReplyWire>(body)
```

Q10's text says *"`T` is any type `ToJson` accepts"*, and Q3 has `ToJson` refuse an open type. Read
to the letter, the program above, which is Q10's own, is refused. F69 compiles it, and still
refuses `ToJson<ReplyWire>`.

Compiler delta: none, it is built. Under the other answer, `unencodable/4` loses its direction for
open members, and 25f's three wire types lose their `..` and refuse any reply with a key they do
not name.

Recommended: **yes, an open type is read.** Q3's reason for the refusal is that writing one
publishes keys no type declares, which is about writing.

**Q12. Is an absent required key blamed at its own path?**

```csharp
type ReplyWire = { "model": string, "answers": map<string, AnswerWire>, "usage": UsageWire, .. }

Parse("{\"answers\":{}}")

// today
(:error, { Kind = :'ValidationError', Path = [], Expected = "{ \"model\": string, ... }" })   // 299 characters

// asked
(:error, { Kind = :'ValidationError', Path = ["[\"model\"]"], Expected = "string" })
```

No ticket decided this. F61 recorded what the validator already did: an absent required key is
refused at the object, `Path = []`. 25f is the first exemplar to meet it, and its malformed case
went from `(:malformed, "model")` to the first value above.

Compiler delta: in `bs_emit`, a field-set validator with one map member checks each required key
with `is_map_key` before its guard clause and returns the error at that key, the first absent one
in declaration order. `ValidateAs`, `FromJson` and a record target share the validator, so all
three change. F61.5 and the `ToJson` guard's crash path are re-read against it.

Recommended: **yes, for a type with one field-set member.** Three things hang off a yes and are
asked next: what a union of field sets does (`AnswerWire` with no `"confidence"`), whether several
absent keys are reported as the first or as all, and what 25f's `(:malformed, …)` then carries.

**Q13. Does `FromJson<T>` take a `binary`?**

```csharp
private result<Evaluation, EvalError> Parse(binary body)

// today: Q10 says `string`, so the body is validated first
Parse(body) -> (ValidateAs<string>(body) |?> FromJson<ReplyWire>()) switch { … }

// asked
Parse(body) -> FromJson<ReplyWire>(body) switch { … }
```

An HTTP body is a `binary`. `string` is `binary` refined by valid UTF-8, and the platform's decoder
refuses text that is not UTF-8 itself, so the first stage checks what the second checks again.

Compiler delta: `FromJson`'s `type_of` clause checks its argument against `binary` instead of
`string`; a `string` still goes in, being a subset. One row of `STANDARD-ENVIRONMENT.md` and one
paragraph of `LANGUAGE.md` change.

Recommended: **yes.** Every string inside the result is still a `string`, because the validator
checks each one. Hanging off a yes: whether bytes that are not UTF-8 are reported as
`Expected = "JSON"` or told apart.

**Q14. Does ENG-410 close on three clauses, with 25f's request side following its blockers?**

```csharp
// still in 25f's index.bs, for the request side
type Json = map<term, term> | list<term> | binary | int | float | atom
using :json { term encode(term value) }
```

Q10's delta ends *"the hand-written `Json` union and its `using` block go"*. They have not gone.
`Body` on `ToJson<RequestWire>` needs a parameter of the recursive JSON value type, which hangs the
compiler ([ENG-609](https://linear.app/davewil/issue/ENG-609)) and whose validator refuses every
object ([ENG-552](https://linear.app/davewil/issue/ENG-552)), and a `map<string, QuestionWire>`
built from pairs ([ENG-454](https://linear.app/davewil/issue/ENG-454)).

Recommended: **close ENG-410**, and raise one build issue for the request side, blocked by those
three, so the clause has a home. The two review findings F69 left (a hand-written dotted `Kind`
called a record; the indiscriminable refusal not naming `FromJson`) are filed as defects.

**Answered 2026-10-09 (David), after [the prior-art review](../research/78-json-decode-prior-art.md):
Q11 yes, Q13 yes, Q14 yes. Q12 moves to round 8.**

- **Q11.** An open type is a `FromJson` target. `ToJson` still refuses to write one. Q10's sentence
  *"`T` is any type `ToJson` accepts"* is corrected by this: `T` is any type `ToJson` accepts, or an
  open one.
- **Q13.** `FromJson<T>` takes a `binary`. Unbuilt: its build issue is
  [ENG-611](https://linear.app/davewil/issue/ENG-611).
- **Q14.** ENG-410 is closed on three clauses. 25f's request side is
  [ENG-612](https://linear.app/davewil/issue/ENG-612), blocked by ENG-609, ENG-552 and ENG-454. The
  two review findings are [ENG-613](https://linear.app/davewil/issue/ENG-613) and
  [ENG-614](https://linear.app/davewil/issue/ENG-614).

## Round 8 — 2026-10-09: what the prior-art review found

David reopened tickets [15](15-error-model.md) and [79](79-validationerror-as-a-record.md) for
this round, since two of its questions change what they decided. The round is written here, once,
and those two files point at it. Evidence for each question is in
[the review](../research/78-json-decode-prior-art.md), by finding number.

Q15, Q16, Q17, Q18 and Q19 do not depend on each other. Q12 depends on Q16 and is asked with it
because David moved it here; its recommendation is conditional and says so.

**Q15. Is JSON with a repeated key refused?** *(finding 7)*

```csharp
type W = { "a": int }

FromJson<W>("{\"a\":1,\"a\":\"x\"}")

// today: the first value is kept and the second is never validated
{ "a" = 1 }

// asked
(:error, ValidationError { Path = [], Expected = "JSON" })
```

David's lean, 2026-10-09: reject, so that `FromJson` cannot introduce the vulnerability. He asked
whether a callback changes that. It does not: the callback is OTP's, and it is how the generated
code would see the second key at all. A B# author never writes or passes one, so there is no form
of the call that accepts a repeated key.

Compiler delta: `bs_emit`'s `text_form` calls `json:decode/3` in place of `json:decode/1`, with an
`object_push` that raises on a key it has already pushed, under the catch that is already there.
`decode/3` hands back the unread remainder where `decode/1` refused it, so the generated function
also refuses a remainder that is not whitespace. The error is at `Path = []`: the decoder's
callbacks carry no path. What it reports beyond that follows Q16.

Recommended: **yes, always, with no way to switch it off.** The parsers that accept a repeated
key disagree about which value wins, and that disagreement is what the published attacks use.

**Q16. Does `ValidationError` say what kind of failure it is?** *(findings 2, 9, 10; reopens ticket 79)*

```csharp
// ticket 79, as built
ValidationError { Path: list<string>, Expected: string }

// asked
ValidationError { Path: list<string>, Expected: string,
                  Reason: :not_json | :missing | :unknown_key | :duplicate_key | :mismatch }

public string Explain(ValidationError e)

Explain(ValidationError { Reason: :not_json })      -> "the body is not JSON"
Explain(ValidationError { Reason: :missing })       -> "a required key is absent"
Explain(ValidationError { Reason: :unknown_key })   -> "a key is not one the type names"
Explain(ValidationError { Reason: :duplicate_key }) -> "a key is repeated"
Explain(ValidationError { Reason: :mismatch })      -> "a value is not of its type"
```

Today the five cases differ only in the `Expected` string: `"JSON"` for the first, a type for the
rest. A handler that wants to answer them differently compares strings, and `Explain` above cannot
be written with a residual the compiler checks.

Compiler delta: the stratum-two entry for `ValidationError` gains `Reason`; `error_expr/1` in
`bs_emit` takes the reason at each of the sites that build one; `LANGUAGE.md`'s renderings of the
record gain the field. `Expected` keeps its meaning. `found`, which ticket 79 left open, stays
open: this does not echo the offending value.

Recommended: **yes.** A closed atom union in a clause head is what the language is for, and the
five members are exactly the five things a wire decoder can find wrong.

**Q12. Is an absent required key blamed at its own path?** *(finding 2; moved from round 7)*

```csharp
type ReplyWire = { "model": string, "answers": map<string, AnswerWire>, "usage": UsageWire, .. }

Parse("{\"answers\":{}}")

// today
ValidationError { Path = [], Expected = "{ \"model\": string, ... }" }          // 299 characters

// asked, under a yes to Q16
ValidationError { Path = ["[\"model\"]"], Expected = "string", Reason = :missing }
```

Compiler delta: as written in round 7. A field-set validator with one map member checks each
required key with `is_map_key` before its guard and returns the error at the first absent key, in
declaration order.

Recommended: **yes if Q16 is yes, and no if Q16 is no.** Without `Reason`, the asked value is the
same as the one a `"model"` holding `7` produces, and a caller cannot tell the key was absent. Zod
and Gleam have that fault. With `Reason`, the path at the key is what the libraries that return
errors as values do.

**Q17. Does a failed decode return one error, or all of them?** *(finding 3; reopens ticket 15)*

```csharp
// ticket 15, as built: every function that calls FromJson or ValidateAs says this
public result<ReplyWire, ValidationError> Parse(binary body)

// the other answer
public result<ReplyWire, list<ValidationError>> Parse(binary body)
```

Compiler delta for the other answer: every generated validator stops returning at its first
failure and threads a list; `result<T, ValidationError>` changes in every signature in the corpus,
the exemplars, `LANGUAGE.md` and the tour; a failed union has to say which members' errors it is
reporting.

Recommended: **one, as ticket 15 decided.** Three reasons. Collecting across a union's members is
where every surveyed library's worst output comes from. Untrusted input should fail at the first
fault. And the other answer is not lost by waiting: it can arrive later as a second name beside
`FromJson`, returning a list, without changing a signature that exists. What that later form would
need is recorded in ticket 15 if this is the answer.

**Q18. Does a `float` field read a JSON integer?** *(finding 8)*

```csharp
type F = { "price": float }

FromJson<F>("{\"price\":1}")

// today
ValidationError { Path = ["[\"price\"]"], Expected = "float" }

// asked
{ "price" = 1.0 }
```

JSON has one number type, and JavaScript writes the float `1.0` as `1`. A `float` field therefore
works on `0.5` and is refused on `1`, from the same sender. 25f writes `int | float` at each such
field to avoid it.

Compiler delta: the validator `FromJson` generates treats an integer at a `float` position as that
float, when the integer has an exact one, and refuses it otherwise. `ValidateAs<T>` over a BEAM
term does not change: there `1` is an `int` because the program that made it said so. This is a
second conversion beside Q8's absent key, and the first that `FromJson` makes and `ValidateAs`
does not, so Q10's *"it converts nothing `ValidateAs` does not"* would no longer hold.

Recommended: **yes.** The alternative is a field that passes its tests and fails in service. An
`int` field still refuses `1.0`.

**Q19. Is a failed tagged union blamed at the tag, or inside the member the tag names?** *(finding 4)*

```csharp
type AnswerWire = { "type": "choice", "choice": string, .. }
                | { "type": "score", "score": int, .. }

// today, all three
ValidationError { Path = [], Expected = "{ \"choice\": string, \"type\": \"choice\", .. } | { … }" }

// asked
FromJson<AnswerWire>("{\"type\":\"tri\",\"choice\":\"x\"}")
ValidationError { Path = ["[\"type\"]"], Expected = "\"choice\" | \"score\"" }

FromJson<AnswerWire>("{\"type\":\"score\",\"score\":\"x\"}")
ValidationError { Path = ["[\"score\"]"], Expected = "int" }
```

Compiler delta: where every map member of a union has one key in common whose types are string
literals no two members share (what F68 already closes a field set on), the generated validator
reads that key first. A value no member names is the first error above. A value one member names
validates against that member alone, so its errors carry their own paths. A union with no such key
is reported as today. No new syntax: the tag is found from the types, as ArkType, Effect Schema
and io-ts do.

Recommended: **yes.** What an absent tag reports follows Q12.

**Waiting on this round:** how a repeated key is reported (Q16); whether an unknown key under an
exact type is named (Q16); what an absent tag reports (Q12, Q19); what bytes that are not UTF-8
report (Q16); what 25f's `(:malformed, …)` carries (Q12, Q16).

**Answered 2026-10-09 (David): all six as recommended.**

- **Q15 yes.** JSON with a repeated key is refused, always, with no switch.
- **Q16 yes.** `ValidationError` gains `Reason: :not_json | :missing | :unknown_key |
  :duplicate_key | :mismatch`. Ticket 79 carries the amendment.
- **Q12 yes.** An absent required key is blamed at its own path, with `Reason = :missing`; the
  first absent key in declaration order.
- **Q17: one error.** Ticket 15 stands, and records what a later list-returning form would need.
- **Q18 yes.** Under `FromJson`, a `float` position reads a JSON integer that has an exact float.
  `ValidateAs` over a BEAM term is unchanged, and an `int` position still refuses `1.0`. Q10's
  *"it converts nothing `ValidateAs` does not"* no longer holds: this is the one exception.
- **Q19 yes.** A union whose map members share a key of disjoint string-literal types is
  validated by that key first: an unknown tag is blamed at the tag with the tags as `Expected`, a
  known one validates against its member alone.

## Round 9 — 2026-10-09: what each new reason reports

Round 8 settled that the error has a `Reason` and where two of the failures point. What is left is
the exact value for the cases round 8 listed as waiting. Each is one value, and none depends on
another.

**Q20. What does a repeated key report?**

```csharp
FromJson<W>("{\"a\":1,\"a\":\"x\"}")

ValidationError { Path = [], Expected = "\"a\" once", Reason = :duplicate_key }
```

The decoder's callback is handed the key and not where the object sits, so `Path` is `[]` however
deep the object is. `Expected` is the only place the key can go.

Compiler delta: none beyond Q15's; the `object_push` that raises carries the key.

Recommended: **as written.** The alternative, `Expected = "JSON"`, loses the key.

**Q21. Is an unknown key under an exact type named?**

```csharp
type W = { "a": int }

FromJson<W>("{\"a\":1,\"b\":2}")

// today
ValidationError { Path = [], Expected = "{ \"a\": int }" }

// asked
ValidationError { Path = ["[\"b\"]"], Expected = "\"a\"", Reason = :unknown_key }
```

`Path` is the key that should not be there. `Expected` is the keys the type names, joined as a
union when there are several, which is the form Q19 gives an unknown tag. With several unknown
keys, the first in the term's key order is reported (Q17).

Compiler delta: an exact field-set validator with one map member, on a size mismatch its guard
would have refused, finds the first key outside its own and returns the error there. `ValidateAs`
shares it.

Recommended: **yes.**

**Q22. What does an absent tag report?**

```csharp
FromJson<AnswerWire>("{\"choice\":\"x\"}")

ValidationError { Path = ["[\"type\"]"], Expected = "\"choice\" | \"score\"", Reason = :missing }
```

It is Q12 applied to the key Q19 reads first: the tag is a required key of every member.

Compiler delta: none beyond Q12's and Q19's.

Recommended: **as written.**

**Q23. What do bytes that are not UTF-8 report?**

```csharp
FromJson<W>(bytes)      // a body holding the byte 0xFF

ValidationError { Path = [], Expected = "JSON", Reason = :not_json }
```

The same value as any other text that is not JSON. Pydantic and serde do this; msgspec and
Python's `json` raise a second, unrelated exception for it, which a caller then forgets to catch.

Compiler delta: none. OTP's decoder already refuses the byte under the catch that is there.

Recommended: **as written.**

**Q24. What does 25f's `:malformed` carry?**

```csharp
type EvalError = … | (:malformed, ValidationError)

// {"answers":{}} before F69
(:error, (:malformed, "model"))

// under rounds 8 and 9
(:error, (:malformed, ValidationError { Path = ["[\"model\"]"], Expected = "string", Reason = :missing }))
```

Compiler delta: none. The exemplar keeps the record F69's rewrite gave it; its replay's malformed
case asserts the value above.

Recommended: **keep the record.** It now says everything the string did, and a caller can match
on it.

**Answered 2026-10-09 (David): all five as recommended.** The frontier is empty: no question waits
on these. Nothing in rounds 8 and 9 is built except what F69 already did; the build issues are
raised once David confirms the tree is complete.

- **Q20.** A repeated key reports `Path = []`, `Expected = "\"a\" once"`, `Reason = :duplicate_key`.
- **Q21.** An unknown key under an exact type is named: `Path` is the key, `Expected` the keys the
  type names, `Reason = :unknown_key`. `ValidateAs` shares it.
- **Q22.** An absent tag reports the tag's path, the tags as `Expected`, `Reason = :missing`.
- **Q23.** Bytes that are not UTF-8 report the same value as any text that is not JSON.
- **Q24.** 25f's `:malformed` keeps the `ValidationError`.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [The decode direction](issues/78-the-decode-direction.md) — **JSON a program does not own is
  read through a structural wire type whose keys are the wire's strings, and `FromJson<T>` is
  `json:decode` then `ValidateAs<T>`; `ValidateAs<T>` stays a check on BEAM terms.** Resolved
  2026-09-24 in six rounds, ten questions, on exemplar 25f (an LLM evaluation client reading
  TypeSafe's and OpenRouter's replies), which reframed the ticket: both programs it was raised with
  read back a record the program wrote, and neither reaches a lowercase, `Kind`-less, snake_case
  reply. Q1: foreign schemas are in scope. Q2: a field's wire name lives in a field-set type,
  `{ "input_tokens": int }`, copied into the domain record by a clause head, so records, `Kind`
  and 77's record row are untouched. Q3: a trailing `..` makes a wire type open; `ToJson` refuses
  an open type. Q4: reading a B# record back from JSON is **deferred**, requirements and reopen
  trigger recorded above. Q5: a string literal is a type, so a union tagged by `"type"` is covered
  without `_`; `string` stays open. Q6: wire fields are read by clause heads; projection deferred,
  requirements recorded. Q7: `{ key = value }` builds a field set, which is 25a's front wall too.
  Q8: 26 §4's absent-key-to-`:nothing` rule, decided and unbuilt, reaches wire types, and JSON
  `null` stays `:null`. Q9: atoms in a wire type are allowed. Q10: `FromJson<T>(string)`, refused
  for a type containing a record. **One correction on the record**: this ticket's Q3 note said
  `ValidateAs` converts nothing, and 26 §4 had already decided one conversion. Build issues:
  string keys [ENG-405](https://linear.app/davewil/issue/ENG-405), open field sets
  [ENG-406](https://linear.app/davewil/issue/ENG-406), string-literal types
  [ENG-407](https://linear.app/davewil/issue/ENG-407), the brace expression
  [ENG-408](https://linear.app/davewil/issue/ENG-408), 26 §4's absent key
  [ENG-409](https://linear.app/davewil/issue/ENG-409), `FromJson<T>`
  [ENG-410](https://linear.app/davewil/issue/ENG-410). **Amended 2026-10-09 (round 7)**, after F69
  built Q10: an open type is a `FromJson` target though `ToJson` refuses to write one (Q11), and
  `FromJson<T>` takes a `binary` (Q13, [ENG-611](https://linear.app/davewil/issue/ENG-611)).
  **Amended 2026-10-09 (round 8)**, on [the prior-art review](research/78-json-decode-prior-art.md):
  JSON with a repeated key is refused (Q15); `ValidationError` gains a `Reason`
  ([79](issues/79-validationerror-as-a-record.md), Q16) and an absent required key is blamed at
  its own path as `:missing` (Q12); one error, not a list ([15](issues/15-error-model.md), Q17);
  under `FromJson` a `float` position reads a JSON integer, the one conversion `ValidateAs` does
  not make (Q18); a union tagged by a string-literal key is validated by that key first (Q19).
  **Amended 2026-10-09 (round 9)**, the value each reason reports: a repeated key is `Path = []`
  with the key in `Expected` (Q20); an unknown key under an exact type is blamed at that key with
  the type's keys as `Expected` (Q21); an absent tag is `:missing` at the tag's path (Q22); bytes
  that are not UTF-8 are `:not_json` like any other text that is not JSON (Q23); 25f's
  `:malformed` keeps the record (Q24). Rounds 8 and 9 are decided and unbuilt.
```

