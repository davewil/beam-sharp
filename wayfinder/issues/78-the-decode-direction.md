# 78 — The decode direction: does `ValidateAs<T>` learn the wire form, or is there a `FromJson<T>`?

Type: grilling
Status: open — [ENG-373](https://linear.app/davewil/issue/ENG-373). Raised 2026-09-15 on resolving
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
- **69 is open** — `float`. A JSON number with a fraction decodes to one; this ticket inherits 69.

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
