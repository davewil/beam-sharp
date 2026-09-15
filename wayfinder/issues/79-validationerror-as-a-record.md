# 79 — `ValidationError` as a record, so the 422 body can go on the wire

Type: grilling
Status: claimed 2026-09-15 — [ENG-374](https://linear.app/davewil/issue/ENG-374). Raised 2026-09-15 on resolving
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

## What was measured, 2026-09-15, OTP 28.5

`ToJson<T>` is not in `codegen_obligations()` — building it is
[ENG-375](https://linear.app/davewil/issue/ENG-375) — so `Rejected` as written above compiles
under neither answer today. The round asks the type's carrier, not the obligation; the three
programs below are the ticket's program with `Rejected` returning the path instead of the body,
which is the same question with the unbuilt call taken out.

**A. The record pattern, today's compiler.** `Rejected(ValidationError { Path: p }) -> p`:

```
Orders.bs:9:10: error: ValidationError is not a record, so it cannot name a pattern
  only a `record` declaration mints the tag a type prefix matches on.
  to constrain fields without naming a type, write `{ Field: ... }`.
```

**B. The projection, today's compiler.** `Rejected(e) -> e.Path`:

```
Project.bs:9:17: error: Rejected projects Path from a value that may not carry it
  this member has no Path:
    (list<string>, string)
  discriminate on the tag first, in a clause head.
```

**C. The tuple arm with a hand-written `Rejection` record** compiles and runs today:

```
$ bsc Tuple Where "{ Kind = :'Tuple.Order', Id = 1, Total = :x }"
{Kind = :'Tuple.Rejection', Expected = "int", Path = [".Total"]}
```

**D. The platform, on the two carriers.** From the repo root:

```erlang
json:encode(#{'Kind' => 'ValidationError', 'Path' => [<<"[0]">>, <<".Value">>], 'Expected' => <<"int">>})
  => {"Kind":"ValidationError","Path":["[0]",".Value"],"Expected":"int"}
json:encode({error, {[<<"[0]">>, <<".Value">>], <<"int">>}})
  => ** exception error: {unsupported_type, {error, {[...], <<"int">>}}}
```

The first line is the 422 body. The second is 77's refusal, measured at the value.

**E. The printers do not name the type.** `bsc --api` on program C prints `Decode`'s return as
`(:error, (list<string>, string)) | { Kind: :'Tuple.Order', Id: int, Total: int }` — the
structure, never `ValidationError`. A record form prints as every record already does; no
printer gains a case under either answer.

**F. The tag cannot collide.** `bs_check:qualified/2` is one line, `Mod ++ "." ++ Name`; every
user-minted tag contains a dot, so a bare `'ValidationError'` is not the tag of any record a `.bs`
file can declare. And the pattern side never re-mints: `record_of/3` and
`bs_emit:record_tag/2` both read `Kind` back out of the *resolved* type, so a stratum-two entry
that carries `Kind` makes program A resolve with no change at the pattern site.

## The compiler delta, under "yes"

Three sites, and program A and program B compile.

1. **`stratum_two/0`** (`bs_check.erl`): the entry becomes the map a `record` declaration would
   have desugared to —
   `{t_map, [{field, 'Kind', {t_atom, 'ValidationError'}}, {field, 'Path', list<string>}, {field, 'Expected', string}]}`.
   Every consumer follows: `validate_error/1` builds `(:error, ValidationError)` from the entry,
   `validate_collapses/2` and `inseparable_pair/1` read it, `record_of/3` finds the tag.
2. **`bs_emit:error_expr/1`**: the single site that builds the value emits the map instead of the
   inner tuple, `Path` reversed as today, `Expected` the same `bin_str`.
3. **`bs_emit:expr({e_record, …})`**: construction mints through `qualified(Mod, Name)` directly,
   the one site that does not read the tag from the resolved type. It moves to `record_tag/2`, so
   a program that builds a `ValidationError` by hand — a test double, a handler synthesising one —
   gets the same tag the validator emits. 26 §1's test still holds: the hand-written
   `{ Kind: :ValidationError, Path: …, Expected: … }` *is* the type.

No parser change: `record_of/3` already accepts the name. No printer change (E). The collapse
equation is untouched: `absorbed/2` asks `(:error, ValidationError) ⊆ T` of whatever the entry
is, and `term` absorbs the map form as it absorbs the tuple form today.

## What the change costs

Measured on the tree at `3fb8bb7`:

| Surface | Reads the tuple | Under "yes" |
|---|---|---|
| `validate_as_tests.erl` | 18 asserts of `{error, {Path, Expected}}` | `{error, #{'Kind' := 'ValidationError', 'Path' := …}}` |
| `map_validate_tests.erl` | the same shape | the same |
| `LANGUAGE.md` | 5 renderings `(:error, ([…], "…"))` — three in the `map<K, V>` validation passage, the tree, `Decode` | the record's own rendering, as program C printed `Rejection` |
| `TOUR.md` | 1 | the same |
| F18's scenario table | 3 rows | the same, and the F-file's §"assumptions" rewritten from tuple to record |
| ticket 61 | 4 renderings, historical | untouched: a resolved ticket records what was measured that day |
| `CONTEXT.md` | *"a tuple today; a record candidate"* | the candidate clause goes |
| `compiler/examples` | `Intake/intake.bs` shows the rendering in a comment; no `.bs` destructures the tuple | one comment line |
| `handoff/` | 0 renderings | nothing |

The audition packet is untouched. The corpus is untouched apart from a comment. The cost is a
test file, five lines of `LANGUAGE.md`, and the F-file.

## What follows the answer, and is not asked in this round

- **The tag's spelling.** The program under "yes" shows it bare: `"Kind":"ValidationError"`.
  That is the ticket's proposal on show, grounded in F — user tags always carry a module, a
  compiler-known type has none to carry, and a reserved qualifier (ticket 67) is for
  *operations*, which a type is not. If David wants it qualified, that is round 2's one
  question; it does not gate Q1.
- **`found`, Gleam's third field.** F18 parked it on 16 §4's mapping, which 77 has now written.
  A record makes adding a field cheap, and property patterns are open, so no head would break —
  but a field on a compiler-known record is a decision, and it gets a ticket, not a commit.
- **Building `ToJson<T>`** is ENG-375, unchanged by this ticket; under "yes" its refusal table
  loses the `ValidationError` row and 25a's friction 0 closes.
- **The F-file** that lands the record is raised on resolution, with the failing test first:
  program A compiled and run against a bad term, printing the record.

## Round 1 (2026-09-15)

**Q1.** Read program A and the 422 body under D. Does `ValidationError` become the compiler-known
record `{ Path: list<string>, Expected: string }` — so that `Rejected(ValidationError { Path: p })`
and `e.Path` compile, the validator emits
`{Kind = :ValidationError, Expected = "int", Path = [".Total"]}` — program C's own output with
the tag swapped — and the wire carries
`{"Kind":"ValidationError","Path":[".Total"],"Expected":"int"}`?

Recommended: **yes.** The content was settled by 15 §2 and is unchanged; the carrier was a
placeholder awaiting 26, and 26 landed a month ago. The costs are one test file, five lines of
prose and the F-file. Under yes, the tag's spelling follows as above, and the feature is raised
at resolution. Under no, the tuple stays the decision, 25a's friction 0 stays the language's
answer, and every handler writes program C's `Rejection` record and arm.
