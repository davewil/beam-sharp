# F49 — `ValidationError` as a record

**Status**      **done 2026-09-15** · [ENG-379](https://linear.app/davewil/issue/ENG-379) — 6 tests in
                `validation_error_record_tests` and 2 in `type_import_tests`, 36 assertions in
                `validate_as_tests` and
                `map_validate_tests` moved from the tuple to the record; new gate
                `check-validation-error-record.sh`, seen red on the tree before the build, with
                three stubs in its `--self-test`
**Implements**  [ticket 79](../../wayfinder/issues/79-validationerror-as-a-record.md): `ValidationError`
                is the compiler-known record `{ Path: list<string>, Expected: string }`, tagged with
                no module. It **decides nothing**
**Depends on**  F18 (`ValidateAs<T>` and the stratum-two entry), F3 (a record erases to a map
                carrying `Kind`), F22 (a record pattern names its type)
**Unblocks**    [ENG-375](https://linear.app/davewil/issue/ENG-375), `ToJson<T>`: its
                `ToJson<ValidationError>` refusal no longer applies, and the 422 body goes on the
                wire once that obligation exists

## What ships

```csharp
module Orders

record Order { Id: int, Total: int }

public result<Order, ValidationError> Decode(term t)
Decode(t) -> ValidateAs<Order>(t)

public list<string> Rejected(ValidationError e)
Rejected(ValidationError { Path: p }) -> p

public list<string> Where(term t)
Where(t) -> Decode(t) switch {
    (:error, e) => Rejected(e),
    o           => []
}
```

```
$ bsc Orders Where "{ Kind = :'Orders.Order', Id = 1, Total = :x }"
[".Total"]
$ bsc Orders Decode "{ Kind = :'Orders.Order', Id = 1, Total = :x }"
(:error, {Kind = :'ValidationError', Expected = "int", Path = [".Total"]})
```

Before this feature the pattern was refused (`ValidationError is not a record, so it cannot name a
pattern`) and the validator returned `(:error, ([".Total"], "int"))`. The `:error` wrapper is
unchanged, so every `(:error, e)` arm in the corpus stands as written. `e.Path`, `e.Expected` and a
hand-built `ValidationError { Path = [], Expected = "int" }` all compile.

## The compiler delta

The three sites ticket 79 named, and no others:

1. **`bs_check:stratum_two/0`** — the entry is the map a `record` declaration desugars to: `Kind`
   as the singleton `'ValidationError'`, then `Path` and `Expected`. `record_of/3`, `validate_error/1`,
   `validate_collapses/2` and `inseparable_pair/1` read the entry and follow unchanged.
2. **`bs_emit:error_expr/1`** — the validator builds that map where it built the inner tuple.
3. **`bs_emit:expr({e_record, …})`** — construction reads the tag through `record_tag/2`, as
   `desugar/2` does for a pattern, instead of minting it from the module. A record declared in
   the same module resolves to the tag `qualified/2` minted for it, so its construction is
   unchanged; the compiler-known record now carries its own, and so does a record imported
   through `using` (below). Where no record tag resolves, construction keeps the tag it always
   minted, for the reason under *What the build found*.

## What the build found

**Construction of an imported record carried the wrong tag.** Since F44 a consumer may write
`Order { Id = 1, Total = 5 }` for a record `using Orders` brings in, and the emitter minted the
tag from the consuming module: `'Billing.Order'`, which `Orders`' own guard refuses. Measured on
a `bsc` built from master before this feature, with a module `Cons` importing `Prod`'s `Order`:
`Make(3)` printed `{Kind = :'Cons.Order', Id = 3, Total = 0}`. Reading the tag from the resolved
type, which ticket 79 asked for so a hand-built `ValidationError` carries the bare tag, gives
`'Orders.Order'`. F49.8 pins it; it was written after the repair, and this measurement is its red.

**Construction over an untagged map alias is accepted by the checker.** `type Pair = { A: int }`
then `Pair { A = n }` compiles and returns `{Kind = :'Alias.Pair', A = 3}` — a tag the type does
not declare. `record_tag/2` finds no tag for `Pair`, and raising there turned a program the
checker accepted into a stack trace, so construction falls back to the old minting and the
behaviour is unchanged. The refusal belongs in the checker:
[ENG-381](https://linear.app/davewil/issue/ENG-381).

## The tag prints quoted

Ticket 79 wrote the tag as `:ValidationError`. That spelling does not lex: the bare atom sigil is
`:{LOWER}{ALNUM}*` (`bs_lexer.xrl`), so an atom starting with a capital is written quoted, as
`:'Shop.Order'` already is. The atom is the one the ticket decided — `'ValidationError'`, no
module — and B# source and `bsc`'s output spell it `:'ValidationError'`. The ticket's program never
had to write it, so the rendering was not measured before it was asked; no decision changes.

## The scenarios

| | what is exercised | what it establishes |
|---|---|---|
| F49.1 | `Where` over a bad order, and a good one | a record pattern takes apart the value the validator returns — the half only a run can see |
| F49.2 | `Decode` over a bad order | the value is `(:error, #{'Kind' => 'ValidationError', 'Path' => [...], 'Expected' => ...})` |
| F49.3 | `e.Expected` on that value | a projection reads a field |
| F49.4 | `ValidationError { Path = p, Expected = "int" }`, then `Rejected` of it | construction carries the bare tag, so a hand-built value reaches the same clause head |
| F49.5 | `Rejected` handed the tuple F18 used to return | refused at the boundary: a public record parameter is guarded on its tag |
| F49.6 | `json:encode` of the returned value | the platform encodes it and it decodes to `Kind`, `Path`, `Expected` — the tuple raised `unsupported_type` (ticket 79, D) |
| F49.8 | `Order { … }` built in a module that imports `Order`, then handed to a function over it | the value carries the producer's tag, `'Orders.Order'`, and passes that function's guard (`type_import_tests`) |
| F49.7 | `check-validation-error-record.sh` | the three runs print the exact values above; a validator still emitting the tuple, a construction minting `'Orders.ValidationError'`, and a compiler refusing the program are each red |

## The gate

`check-validation-error-record.sh` compiles ticket 79's program once and runs `Where`, `Decode`
and a hand-built round trip, asserting each printed value exactly. The checker cannot see either
defect it names: with the stratum entry changed, a validator that still emits the tuple and a
construction that still mints `'Orders.ValidationError'` both compile, and fail only at the tag
guard a public `ValidationError` parameter gets. `tuple_emitted` is red on the first two probes
and green on the third; `minted_tag` the reverse; `broken` is red on all three, so an absence is
never read as a pass.

## Out of scope

- **`found`**, Gleam's third field — fog on the map (ticket 79, *What follows*).
- **`ToJson<T>`** — [ENG-375](https://linear.app/davewil/issue/ENG-375), built as [F50](F50-to-json.md)
  on 2026-09-15.
