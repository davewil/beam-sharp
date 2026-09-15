# 79 — `ValidationError` as a record, so the 422 body can go on the wire

Type: grilling
Status: resolved 2026-09-15 — [ENG-374](https://linear.app/davewil/issue/ENG-374). Raised 2026-09-15 on resolving
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

**A1 — yes** (David, 2026-09-15 18:27). Resolved on the one question, one round.

## The answer

`ValidationError` is the compiler-known record `{ Path: list<string>, Expected: string }`. Its
tag is bare, `:ValidationError`, as the program on show carried it: a user-minted tag always
holds a module and a dot (F), a compiler-known type has no module to carry, and a reserved
qualifier (ticket 67) names operations, which a type is not. The content is 15 §2's, unchanged;
only the carrier moved, and it moved the day the wire (77) made the tuple cost something.

*Corrected 2026-09-15 on building it (F49, ENG-379):* the atom decided here is `'ValidationError'`,
and B# source and `bsc` output spell it `:'ValidationError'`. The unquoted `:ValidationError` in
this ticket does not lex — the bare atom sigil takes a lowercase name — and was written, not
measured. The wire form, `"Kind":"ValidationError"`, is unchanged.

What a program can now write, and what it gets:

- `Rejected(ValidationError { Path: p })` and `ValidationError e` in a clause head; `e.Path` and
  `e.Expected` in a body. Program A and program B compile.
- The validator emits `{Kind = :ValidationError, Expected = "int", Path = [".Total"]}` where it
  emitted `(:error, ([".Total"], "int"))`'s inner tuple; the `:error` wrapper is unchanged, so
  `result<T, ValidationError>` and every `(:error, e)` arm in the corpus stand as written.
- Under `ToJson<T>` (ENG-375), the 422 body is
  `{"Kind":"ValidationError","Path":[".Total"],"Expected":"int"}`, measurement D. 25a's
  friction 0 closes when that feature lands.
- A hand-built `{ Kind: :ValidationError, Path: [], Expected: "int" }` *is* the type, 26 §1's
  own test; construction `ValidationError { Path = [], Expected = "int" }` mints the same tag.

### What follows

- **The feature** is [ENG-379](https://linear.app/davewil/issue/ENG-379), F49: the three sites
  under *The compiler delta*, the failing test first — program A compiled and run against a bad
  term, printing the record — and the priced surfaces in *What the change costs*.
- **ENG-375** loses its `ToJson<ValidationError>` refusal example; the row is 77's, and 77's
  entry names *today's* `ValidationError` deliberately.
- **`found`**, Gleam's third field, stays fog on the map: cheap now, still a decision.
- **`CONTEXT.md`**'s entry drops *"a tuple today; a record candidate"* in this commit.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [`ValidationError` as a record](issues/79-validationerror-as-a-record.md) — **`ValidationError`
  is the compiler-known record `{ Path: list<string>, Expected: string }`, tagged bare
  `:ValidationError`, so a handler destructures it as any record and the 422 body goes on the
  wire.** Raised and resolved 2026-09-15 in one round on one question, the day
  [ticket 77](issues/77-what-goes-on-the-wire.md) made the tuple cost something: a tuple has no
  wire form, and prototype 25a's friction 0 was exactly that refusal landing on a handler's own
  error reason. The content is [15](issues/15-error-model.md) §2's, unchanged; the carrier was
  a placeholder awaiting [26](issues/26-data-modelling.md)'s record form, which landed
  2026-08-14 and sat unclaimed for a month. Measured under today's compiler before asking: the
  record pattern is refused as *not a record*, the projection as *may not carry Path*, and the
  tuple arm with a hand-written `Rejection` compiles and runs; `json:encode` takes the erased
  map and refuses the tuple; `--api` prints the structure, never the name, so no printer changes;
  `qualified/2` always joins with a dot, so a bare tag cannot collide with any record a `.bs`
  file declares. The delta is three sites and not the pattern site, because `record_of/3` and
  `bs_emit:record_tag/2` read `Kind` out of the resolved type rather than re-minting it: the
  stratum-two entry gains `Kind`, `error_expr/1` emits the map, and construction stops minting
  from the module. Cost: one test file, five renderings in `LANGUAGE.md`, the F-file. The
  corpus and the audition packet are untouched. Unbuilt —
  [ENG-379](https://linear.app/davewil/issue/ENG-379), F49; `found` stays fog.
```
