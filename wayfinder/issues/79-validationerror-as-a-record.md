# 79 — `ValidationError` as a record, so the 422 body can go on the wire

Type: grilling
Status: open — [ENG-374](https://linear.app/davewil/issue/ENG-374). Raised 2026-09-15 on resolving
[ticket 77](77-what-goes-on-the-wire.md)
Blocked by: —

## Why this is raised

Under 77's answer, `ToJson<ValidationError>` is refused at the declaration: `ValidationError` is
the tuple `(list<string>, string)`, and a tuple has no wire form. That is
[prototype 25a](../prototypes/25a-http-api-server.md)'s friction 0 — *"the compile error then
lands on the single most common thing an HTTP handler does, which is putting its own error reason
on the wire"* — and the repair 25a named is the one [ticket 15](15-error-model.md) §2 flagged as a
candidate *if* a record form landed, [ticket 26](26-data-modelling.md) §4 restated, and
`CONTEXT.md` still carries: *"a tuple today; a record candidate if one is ever introduced"*. 26
landed the record form on 2026-08-14. The candidate's precondition has been met for a month, and
77 is what makes it cost something to leave.

## What is already decided, and is not reopened here

- **15 §2** — `ValidationError` is a path into the term plus the type expected there; the shape
  Gleam's decoders return. The *content* is settled; only its carrier is asked.
- **26 §1** — a record erases to a map carrying `Kind`, minted from the qualified type name, and
  the declared field names as atoms. A record is told apart by `Kind`.
- **61** — the path stops at the row, and the two renderings beside it.
- **77** — a tuple is refused on the wire; a record is an object carrying `Kind` and its fields.
- **18** — `ValidateAs<T>` returns `result<T, ValidationError>`; the name is compiler-known.

## The program

25a's 422 body, and the handler that produces it.

```csharp
module Orders

record Order { Id: int, Total: int }

public string Rejected(ValidationError e)
Rejected(e) -> ToJson<ValidationError>(e)

public string Outcome(result<Order, ValidationError> r)
Outcome((:error, e)) -> Rejected(e)
Outcome(o)           -> ToJson<Order>(o)
```

### Under "`ValidationError` is a record"

```csharp
record ValidationError { Path: list<string>, Expected: string }     // compiler-known, in the prelude
```

`Rejected` compiles, and on the wire it is

```
{"Kind":"ValidationError","Path":["[0]"],"Expected":"{ Kind: :'Intake.Reading', Sensor: string, Value: int }"}
```

`Outcome` compiles as written. A handler that reads the reason destructures it as any record:
`Rejected(ValidationError { Path: p })`, or `e.Path`.

### Under "`ValidationError` stays a tuple"

`Rejected` is refused at the declaration, as 77 records, and the handler converts in the arm:

```csharp
record Rejection { Path: list<string>, Expected: string }

Outcome((:error, (path, expected))) -> ToJson<Rejection>(Rejection { Path = path, Expected = expected })
```

Every handler in every program writes that record and that arm.

## What the change costs

- **The minted tag.** 26 §1 mints `Kind` from the *qualified* type name, and a compiler-known type
  has no module. `"Kind":"ValidationError"` bare, or under a reserved qualifier, is the one
  sub-question; it is the same question `ParseAtom<T>` and `ToJson<T>` never had to answer
  because neither is a type.
- **The corpus.** Nothing in `compiler/examples` or `LANGUAGE.md` destructures a
  `ValidationError` today (measured 2026-09-15, `grep '(:error, ('` finds only user tuples). The
  tuple is read in F18.22's tests, F25's corrected-signature rendering, ticket 61's two renderings,
  and `validate_as_tests.erl`; each moves to the record.
- **The field names** are the decision's only free choice. `Path` and `Expected` read off 15 §2.

## The question

Does `ValidationError` become a compiler-known record — `{ Path: list<string>, Expected: string }`
— so that `Rejected` above compiles and the 422 body is
`{"Kind":"ValidationError","Path":[...],"Expected":"..."}`? Under yes, the minted tag's qualifier
follows as the round's second question. The round is written when it is asked.
