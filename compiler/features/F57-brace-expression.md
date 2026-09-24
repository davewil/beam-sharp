# F57 — the brace expression `{ Key = value }` builds a field set

**Status**      **in progress** — 10 tests in `map_construction_tests`, 1074 in
                the suite; `check-language.sh` gained a must-compile block and a
                `diagnoses: duplicate_field` block, both seen red first; the
                tree-sitter grammar gained `map_construction`
**Implements**  [ticket 78](../../wayfinder/issues/78-the-decode-direction.md) Q7,
                the level [ticket 48](../../wayfinder/issues/48-a-map-type-in-the-prelude.md)
                measured missing. Decides nothing
**Closes**      the atom-key half of [ENG-408](https://linear.app/davewil/issue/ENG-408).
                The string-key form, `{ "model" = m.Id }`, needs string keys in
                the type algebra first: [ENG-405](https://linear.app/davewil/issue/ENG-405)
**Unblocks**    exemplar **25a**'s front wall, the map literal. Its five files now
                parse, and its wall moved to the missing `module` line
**Depends on**  F3 (record construction's `assign_fields`), F33 (field-set types)

## Why this one now

Ticket 48 found bare braces at two of three levels. The type
`{ Status: int }` and the pattern `{ Status: s }` shipped; the expression
needed a record name in front (`expr_low -> uident '{' assign_fields '}'`).
25a has stopped on that since it was written, recorded in `FRONTIER` as
`illegal characters "#"` because the exemplar used Erlang's spelling.
Ticket 78 Q7 decided the expression on 2026-09-24.

## The program

```csharp
module Replies

type Problem = { Error: string, At: { Line: int } }

public Problem Invalid(int line)
Invalid(line) -> { Error = "invalid", At = { Line = line } }

public int Where(Problem p)
Where({ At: { Line: l } }) -> l
```

`Invalid(7)` is `#{'Error' => <<"invalid">>, 'At' => #{'Line' => 7}}`: a plain
map, no `Kind`.

## The rule

- The value's type is the **exact** field set its values give. The ordinary
  check sites (argument, return, field, arm, lambda result) compare it with
  what they expect, so a wrong value, a missing key and an extra key are the
  existing `return_not_declared` / `arg_not_accepted` diagnostics.
- It has no `Kind`, so it is never a record, even one with the same fields.
  A brace that writes `Kind = :'M.Reply'` itself is that record: ticket 73
  Q1 made the tag an ordinary key, legal wherever the grammar admits it and
  refused by the compiler nowhere, as Elixir's `__struct__` is.
- Each value takes the type its field has in the type the site expects, so a
  lambda there has its arrow, as a record construction's value does.
- A key written twice is refused, `duplicate_field`. An Erlang map literal
  would keep the last value. No ticket decides this outright; it is
  [ticket 89](../../wayfinder/issues/89-what-the-f57-f60-review-left-open.md) Q6.

## What it compiles to

`{map, L, [{map_field_assoc, L, {atom, L, K}, E} …]}`, record construction's
emission without the `Kind` pair. The grammar change adds no yecc conflict:
5 shift/reduce before and after, and the 231 precedence-resolved conflicts are
the same set by symbol (state numbers differ).

## Scenarios

| Id | Program | Expected |
|---|---|---|
| F57.1 | `Ok(n) -> { Status = n, Body = :ok }` | runs; `#{'Status' => 200, 'Body' => ok}` |
| F57.2 | `{ Status = :x }` against `{ Status: int }` | `return_not_declared` |
| F57.3 | a key missing | `return_not_declared` |
| F57.4 | an extra key | `return_not_declared` |
| F57.5 | as an argument; a wrong value there | runs; `arg_not_accepted` |
| F57.6 | handed to a `Reply` record parameter with the same fields | `arg_not_accepted` |
| F57.7 | `{ Status = n, Status = 2 }` | `duplicate_field` |
| F57.8 | `ToJson<{ Status: int }>({ Status = n })` | `{"Status":201}` |
| F57.9 | nested, with a record inside, destructured by a clause head | runs |
| F57.10 | in a switch arm inside a lambda | runs |
| F57.11 | `{ F = (x) => x + n }` returned as `{ F: fn(int) -> int }`, and handed to a parameter of that type | runs; `5`, `8` |

## Out of scope

- String keys, `{ "model" = m.Id }`: built by F58 (ENG-405) the same day.
- A mismatch prints its residual in pattern syntax, `{ Status: _ }`, so the
  wrong field's value is not named, and no corrected signature is offered.
  The printer elides every map value by design; spelling them is ENG-350's
  printer decision, and the review's example is on that issue.

## Done when

The scenarios pass, the LANGUAGE.md blocks compile, 25a's `FRONTIER` record
moves past the map literal, the tree-sitter grammar parses the construct, and
`./bin/verify.sh` is green twice from a clean clone.

## Evidence — 2026-09-24

The first clean-clone run, on `e03731d`, failed at stage 43: the frontier
gate's self-test faked 25a's advance by rewriting the `#{ ... }` literal this
feature removed, so its control stayed green. Fixed in `47b7ff4`, where the
stub adds the `module` line 25a now stops on.

`./bin/verify.sh` twice from a clean clone of `47b7ff4`, one command per run:
**All 46 stages passed**, 323 s and 320 s. The atom-key half of ENG-408 is
done by the conditions above; the status stays *in progress* until David
calls it, and the string-key half waits on ENG-405.

## Evidence — 2026-09-24, the review fixes

The `/code-review` of `0e51c9a..01c4a56` found the defects this change fixes;
its open decisions are [ticket 89](../../wayfinder/issues/89-what-the-f57-f60-review-left-open.md).
A brace's values take the field types the site expects (`cabead1`, F57.11).

`./bin/verify.sh` twice from a clean clone of `a6123f3`, one command per run:
**All 46 stages passed**, 264 s and 270 s. A first clone passed run 1 (325 s)
and failed run 2 at stage 11, whose gate and `--self-test` then passed alone
in that clone: ENG-329's race, and this change touches no tour file. The
status stays *in progress* until David calls it.
