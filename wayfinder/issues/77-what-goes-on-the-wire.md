# 77 — What goes on the wire: is ticket 16 §4's serialisation mapping the platform's, with the compiler refusing what the platform refuses?

Type: grilling
Status: open — [ENG-372](https://linear.app/davewil/issue/ENG-372). Raised 2026-09-15 to unblock
[ENG-298](https://linear.app/davewil/issue/ENG-298), the diagnostic term's JSON encoding, and
through it [ENG-305](https://linear.app/davewil/issue/ENG-305), the LSP server
Blocked by: —

## Why this is raised now

[Ticket 16](16-ad-hoc-polymorphism.md) §4 decreed that serialisation is a codegen obligation —
*"the language publishes the mapping that fills the gap"* — and its *Not decided here* left the
mapping's published rules as *"spec-drafting details with the decision above already binding"*.
Nothing has drafted them. Since then four places have taken a dependency on the unwritten text:

- [Ticket 23](23-what-the-language-owes-an-agent.md) §5: the diagnostic term's JSON encoding
  *reuses* 16 §4's mapping, because a diagnostics-only spelling would leave two renderings of
  `(:ok, 5)`. F16 and F17 both kept the encoding out on that ground.
- [ENG-298](https://linear.app/davewil/issue/ENG-298), the LSP's second prerequisite, is
  *"blocked on a design decision that has no ticket"*. It blocks
  [ENG-305](https://linear.app/davewil/issue/ENG-305). The other two prerequisites are done
  (F35, ENG-299), so this is the whole of what stands between the compiler and a server.
- [Ticket 26](26-data-modelling.md) §4 owes this mapping one question: an `option<T>` field
  holding `:nothing` — `"notes": null`, or omit the key.
- F18 (b) deferred `ValidationError`'s `found` field on it, and
  [ENG-296](https://linear.app/davewil/issue/ENG-296) has F25 §5 waiting on it.

And [prototype 25a](../prototypes/25a-http-api-server.md), friction 0, found where the decree
lands: *"the compile error then lands on the single most common thing an HTTP handler does, which
is putting its own error reason on the wire."*

This is that ticket. Its job is to get the rules written, and the one question that decides
their shape is asked below.

## What is already decided, and is not reopened here

- **16 §4** — the rule: a capability is a codegen obligation when the type determines the result,
  inherently or by published decree. Serialisation qualifies by decree; a generated `ToJson<T>`
  *"reads the declared type and refuses at compile time, naming the member that has no
  encoding"*; **only the encode direction is new**. 16 §8 places `ToJson<T>` in prelude
  stratum 2 as the fifth obligation, and its *Not decided here* makes the name a drafting
  detail, so this ticket uses it and does not ask about it.
- **23 §5** — JSON is a published encoding of the diagnostic term, not a rival form, and it
  inherits whatever this ticket decides.
- **26 §1** — a record erases to a map carrying a tag minted from the qualified type name under
  the key `Kind`; field keys are the declared names as atoms. 26 §4 also decided the
  exact-set test is emitted where an obligation consumes a record, because an encoder would
  publish fields no type declares.
- **10 §2** — `:null` is an atom, and it is the atom OTP's `json` returns for JSON `null`.
- **15** — `result<T, E>`'s failure member is the tuple `(:error, E)`, chosen because an untagged
  channel collapses. `ValidationError` is a tuple today (CONTEXT.md).
- **18** — a generated encoder trusts its input; the boundary guard is emitted unconditionally
  where generated code consumes a term (18 §1(c)).
- **67** — an obligation is a compiler-known entry, inlined at its site; nothing ships as a
  module.
- **69 is open** — the language may or may not have `float`. This ticket says nothing about
  `float` and inherits whatever 69 decides; JSON numbers with a fraction decode to one.

## What was measured, 2026-09-15, OTP 28.5

**The platform's mapping, value by value** (`json:encode/1`, then `json:decode/1` where it
matters):

```
#{a => 1}                  => {"a":1}
ok                         => "ok"
nothing                    => "nothing"
<<"s">>                    => "s"
"s"                        => [115]                       a charlist is a list of ints
1.5                        => 1.5
#{1 => x}                  => {"1":"x"}                   a non-string key is stringified
#{<<"k">> => v}            => {"k":"v"}
<<255>>                    => {invalid_byte,255}          a binary that is not UTF-8
{error, bad}               => {unsupported_type,{error,bad}}
[1, {a, b}]                => {unsupported_type,{a,b}}    at any depth
{1, 2}                     => {unsupported_type,{1,2}}

json:decode("\"ok\"")      => <<"ok">>                    an atom does not come back
json:decode("1e300")       => 1.0e300
```

**A record, erased as the language erases it, both ways:**

```
#{'Kind' => 'Intake.Reading', 'Sensor' => <<"a">>, 'Value' => 1}
   encode  => {"Kind":"Intake.Reading","Sensor":"a","Value":1}
   decode  => #{<<"Kind">> => <<"Intake.Reading">>, <<"Sensor">> => <<"a">>, <<"Value">> => 1}

#{'Kind' => 'Parcel.Parcel', 'Id' => 1, 'Note' => nothing}
   encode  => {"Kind":"Parcel.Parcel","Id":1,"Note":"nothing"}

{error, {["[0]"], "{ Kind: ... }"}}                        a ValidationError
   encode  => {unsupported_type, ...}
```

Three findings, each labelled by what to do with it.

**1. Record, and it corrects 23 §5: the diagnostic term carries no tuples.** 23 §5 wrote
*"tuples are what these diagnostics are made of"* on 2026-08-13, measured on `{neg_inf,-1}`. F29
made every residual and every pasteable head a string on 2026-08-27. What `bsc --diagnostics
term` prints today for an inexhaustive function is

```
#{function => 'Describe', line => 10, column => 15, tag => inexhaustive, severity => error,
  file => "/…/Ledger.bs",
  heads => #{kind => products, products => [[["int <= 0","(:error, string)"]]],
             pasteable => ["Describe(<= 0) -> ...", "Describe((:error, s)) -> ..."]},
  residual => "(int <= 0 | (:error, string))"}
```

— atoms, integers, lists, maps and **charlists**. `json:encode` on that term *succeeds*, and
emits `"file":[47,86,111,…]` for every string in it. So the LSP's blocker is not the tuple rule.
It is that the term's strings are Erlang strings where B#'s `string` is a binary, which is a
compiler internal: ENG-298's encoder converts them and calls the platform. David is not asked
about it.

**2. Record, and it corrects 16 §4: "decode is already built" is false for a record, and for any
atom-typed field.** 16 §4 said decoding is *parse to a `term`, then `ValidateAs<T>`*. Measured on
`examples/Intake`, whose `Decode` is exactly that:

```
Decode([#{'Kind' => 'Intake.Reading', 'Sensor' => <<"a">>, 'Value' => 1}])
   => [{Kind = :'Intake.Reading', Sensor = "a", Value = 1}]              the erasure: accepted

Decode([#{<<"Kind">> => <<"Intake.Reading">>, <<"Sensor">> => <<"a">>, <<"Value">> => 1}])
   => (:error, (["[0]"], "{ Kind: :'Intake.Reading', Sensor: string, Value: int }"))
                                                                           json:decode's output: refused
```

`json:decode` returns binary keys and a binary tag; `ValidateAs<Reading>` accepts only the
erasure's atom keys and atom tag. The same holds for a field typed `:credit | :debit`, which
arrives as `<<"credit">>`. So the decree adds an inverse too — or `ValidateAs<T>` learns the wire
form. That follows the question below and is not asked in this round; **the LSP chain needs the
encode direction only.**

**3. A dependency, not a question.** `float` is ticket 69's, open.

## The program

25a's handler, written in the shipped surface. Every clause is the commonest thing an HTTP
handler does: put a value of its own declared type on the wire.

```csharp
module Orders

record Order  { Id: int, Total: int }
record Parcel { Id: int, Note: option<int> }

// The 200 body. Every field is in the platform's domain.
public string OrderBody(Order o)
OrderBody(o) -> ToJson<Order>(o)

// The 200 body with an absent field.
public string ParcelBody(Parcel p)
ParcelBody(p) -> ToJson<Parcel>(p)

// The 422 body: the language's own failure reason, on the wire.
public string Rejected(ValidationError e)
Rejected(e) -> ToJson<ValidationError>(e)

// A result on the wire, which is what a handler that calls ValidateAs holds.
public string Outcome(result<Order, ValidationError> r)
Outcome(r) -> ToJson<result<Order, ValidationError>>(r)
```

### Under "yes, the wire form is the platform's"

`ToJson<T>` is a compile-time walk over `T`'s normalised members that refuses any member the
platform would refuse at runtime, followed by the platform's encoder inlined at the site. Nothing
is generated per member; the generation *is* the check.

```
OrderBody(o)   =>  json:encode(O)        {"Kind":"Orders.Order","Id":1,"Total":5}
ParcelBody(p)  =>  json:encode(P)        {"Kind":"Orders.Parcel","Id":1,"Note":"nothing"}

Rejected(e)    =>  refused at the declaration:
                   ToJson<ValidationError>: (list<string>, string) has no encoding — a tuple
Outcome(r)     =>  refused at the declaration:
                   ToJson<result<Order, ValidationError>>: (:error, ValidationError) has no
                   encoding — a tuple
```

Every row of the published mapping is then a sentence that reads off the measurement table: an
atom is its name; a `string` is itself; a record is an object whose keys are the declared field
names and whose `Kind` is on the wire; a list is an array; a `map<K, V>` is an object with `K`
stringified; `int` is a number. Refused at compile time, naming the member: a tuple at any depth,
an arrow (already refused by `ValidateAs`), and `binary` — the platform refuses a *value* with an
invalid byte, and the only type-level refusal that keeps the promise is the whole of `binary`,
leaving `string`, which is UTF-8 by refinement. C# is the precedent for the keys:
`System.Text.Json` writes property names as declared, PascalCase, unless a policy says otherwise.

The two refusals are the cost, and they are 25a's finding restated: the 422 body and the
`result` are the two values a handler most wants on the wire, and both are tuples. The repair
25a named is available for one of them — `ValidationError` becomes a record, which is what
CONTEXT.md already calls it a candidate for — and the other stays refused until someone converts
it to a record in the arm, exactly as 15's design intends the arm to be written.

### Under "no, the language owns the mapping"

`ToJson<T>` emits an encoder per member, as `ValidateAs<T>` emits a check per member, and the
rows above become choices: whether the tag goes on the wire, whether the keys are the declared
spelling, whether `:nothing` is `null` or an omitted key, and whether a tuple is an array. That
is round 2, one row at a time, and only if the answer is no.

## The compiler delta, under "yes"

- `bs_check`: `ToJson<T>` joins the stratum-2 entries beside `ValidateAs<T>` and `ParseAtom<T>`.
  Ground `T` only (27's rule for every obligation). Returns `string`. A walk over the normalised
  members of `T` — after absorption, per the rule that a written member is not a normalised
  member — refusing a tuple, an arrow or `binary` anywhere in it.
- `bs_diag`: one new tag, `unencodable_member`, carrying the obligation, the member and the path
  to it; the prose names the member the way `validate_indiscriminable` (F18.22) names its target.
  Wired at both declaration sites, `check/2` and `exports_of/1`, because `--api` is a second
  pass through the latter.
- `bs_emit`: `iolist_to_binary(json:encode(V))` inlined at the site, per 67. The exact-set test
  26 §4 already owes at an obligation site is emitted here.
- `STANDARD-ENVIRONMENT.md`: a row for `ToJson<T>`, so `check-status-claims.sh` has a status to
  read. `CONTEXT.md` gets a term once the mapping is settled, not before.
- **ENG-298, which was blocked on this**: `bs_diag` converts the term's charlists to binaries
  and calls the platform; `bsc --diagnostics json` publishes it; `check-diagnostics.sh` gains a
  round-trip control. No language decision inside it once the answer above is yes.

Whether `ToJson<T>` is *built* is a feature and gets an F-file; 16 §4's *Not decided here* put
that under stdlib breadth, but 67 has since closed the standard environment by construction and
ENG-305 records David asking for the server directly, so the mapping is owed whether or not the
obligation ships first.

## What follows the answer, and is not asked in this round

- **The decode direction** (finding 2). Either a `FromJson<T>` obligation, the inverse walk, or
  `ValidateAs<T>` accepting the wire form for a record, an atom union and a `map<K, V>`. The LSP
  does not need it; a handler does, on its first request.
- **`ValidationError` as a record** — 25a's repair, CONTEXT.md's candidate. A decision for
  ticket 15 or 26 to take, raised once this one is answered.
- **The exact-set test's placement** (26 §4) lands here unchanged.
- **F18 (b)**, `found`: rendering an arbitrary foreign term to a `string` inside generated
  code is this mapping applied to `term`, which has tuples in it, so under "yes" `found` stays
  absent for the reason F18 gave.

## Round 1 (2026-09-15)

**Q1.** Read the four lines under *"yes, the wire form is the platform's"* — the two bodies as
printed and the two refusals as worded. Is that the language's published mapping: the platform's
encoding of the erased term, with the compiler refusing at compile time exactly what the platform
refuses at runtime?

Under yes, every row is written from the measurement table and ENG-298 is unblocked as
mechanical work. Under no, round 2 asks the rows you refused, one at a time, starting with the
tag on the wire.
