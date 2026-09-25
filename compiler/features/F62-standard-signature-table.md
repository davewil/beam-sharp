# F62 — A standard operation is a row over OTP's own function

**Status**      **in progress** — 13 tests in `reserved_qualifier_tests` (40 there),
                `check-reserved-qualifiers.sh` P2 rewritten and seen red on master first,
                nine red stubs and one green
**Implements**  [ticket 96](../../wayfinder/issues/96-standard-environment-breadth.md) Q1,
                resolved 2026-09-25. Decides nothing
**Closes**      [ENG-452](https://linear.app/davewil/issue/ENG-452)
**Depends on**  F32 (the reserved qualifiers, their refusals, and the six operations
                that move here), F46 (a function as a value, which `Map`, `Filter`
                and `Fold` take), F51 (`Float.FromInt`, the one row that already
                lowered to OTP)
**Leaves**      every other row: the `List` and `Map` breadth (ENG-454), `Enum`
                (ENG-453), `String` (ENG-455), the OTP client calls (ENG-456),
                `Logger`/`System` (ENG-457), the conversions (ENG-462), `Task`/`Agent`
                (ENG-463). Each is one row here, so none of them needs a mechanism of its own.
                **The signature half is not yet declarative.** The ticket's row reads
                "B# signature (polymorphic ones typed as F45 types a polymorphic call)";
                here it is still `reserved_sig/4`'s hand-written clauses, one per row,
                with `Map`/`Filter`/`Fold`'s expectation logic in `reserved_args/5`. The
                next row that adds a polymorphic signature owes that move

## The program

```csharp
module Leaderboard

public list<int> Top(list<int> scores)
Top(scores) -> List.Reverse(List.Sort(scores))

public int Total(list<int> scores)
Total(scores) -> List.Fold(scores, 0, (acc, s) => acc + s)
```

`Top` compiles to `lists:reverse(lists:sort(Scores))`. `Total` compiles to
`lists:foldl('bs@List@flip'(fun ...), 0, Scores)`. No `List.beam` ships,
and the program's import chunk names `lists` and nothing called `List`.

## The rule

- A standard operation is a row, `{Qualifier, Name, Arity}` → its B# signature →
  the OTP function that already does it. The rows live in
  `bs_check:standard_table/0`, and the signature half of each row is `reserved_sig/4`,
  as it was under F32.
- `bs_emit` writes the row's target as a remote call at the site. Where OTP takes
  its arguments in another order, `otp_args/3` adapts them, one clause per row:
  `lists:map(F, Xs)` and `lists:filter(F, Xs)` against `List.Map(xs, f)`.
- A row with no OTP function that answers in B#'s terms is `generated` and keeps
  F32's local function. `Term.Compare` is the only one: its answer is three atoms,
  and OTP has no function that returns them.

| Row | Target |
|---|---|
| `List.Sum/1` | `lists:sum/1` |
| `List.Length/1` | `erlang:length/1` |
| `List.Reverse/1` | `lists:reverse/1` |
| `List.Sort/1` | `lists:sort/1` (new) |
| `List.Map/2` | `lists:map/2`, arguments swapped |
| `List.Filter/2` | `lists:filter/2`, arguments swapped |
| `List.Fold/3` | `lists:foldl/3`, arguments reversed, callback flipped |
| `List.FoldRight/3` | `lists:foldr/3`, as `Fold` (new) |
| `Float.FromInt/1` | `erlang:float/1` (F51, unchanged) |
| `Term.Compare/2` | generated (F32, unchanged) |

## `Fold` is the row where the argument order was not enough

B#'s fold callback takes the accumulator first, `(acc, o) => acc + o.Total`. Ticket
75 wrote it that way, and C#'s `Aggregate` does the same. `lists:foldl` calls its fun
as `F(Elem, Acc)`, and so do `foldr` and `mapfoldl`, so no OTP target has B#'s order.
Reordering only the arguments would call the author's lambda with its two parameters
swapped. For `(acc, x) => acc + x` over integers that goes unnoticed; for
`(acc, x) => [x, ..acc]` it is wrong.

The site wraps the callback: `lists:foldl('bs@List@flip'(F), Seed, Xs)`,
where the generated `flip` returns `fun(E, Acc) -> F(Acc, E) end`. The helper is a
function, not a `fun` written at the site, for two reasons:

- **`F` is evaluated once.** A fun written at the site would re-evaluate the author's
  callback expression on every element.
- **Nested folds cannot shadow.** A variable bound at the site would collide with the
  same name in an enclosing fold's callback, and erlc's shadowing warning would then
  surface against the author's `.bs`, as F32's `Bs@h` warning once did.

`List.FoldRight` is the same row over `lists:foldr/3`, which calls its fun the same
way, so it takes the same `(acc, x)` callback and shares the one `flip` helper. That
order was chosen to match `Fold` (and Gleam's `fold_right`); Haskell's `foldr` takes
`(x, acc)` instead, which is the one alternative anybody would argue for.

The callback order is kept here, not decided. Changing it to Elixir's `(x, acc)`
would be a ticket, and every exemplar that folds would move with it.

## What the gate reads now

F32's P2 refused `lists` in the import chunk: it read ticket 67 as forbidding a stdlib
call. Ticket 96 found that 67 never weighed one. P2 now has three arms:

- **Any capitalised module** is red. The probe imports nothing and every OTP module is
  lowercase, so a capitalised name there is one B# would have to ship: `List`, `Map`,
  or a qualifier a later row adds, with no list of names in the gate to fall behind.
  The over-informed `shipped_module` stub stays red, and `shipped_map` and
  `shipped_enum` join it.
- **No `lists`** is red: `generated_local` is F32's own lowering, the right value
  from the wrong design.
- **`lists` present** is green.

The five stubs that test other probes carry `lists` in their P2. Otherwise each would
go red on P2 as well as on its own defect, and its self-test half would prove nothing.

## One F32 test changed

`a_reserved_qualifier_call_emits_no_remote_call_test` asserted `lists` absent. It is
now `a_reserved_qualifier_call_lowers_to_otp_not_to_a_list_module_test` and asserts
`List` absent and `{lists, sum, 1}` imported. This is the ticket's own reversal, not
a regression. The rest of F32's suite runs unchanged.

## Measured

The `.abstr` of every example directory, built by master's `bsc` (`a59bfc4`) and by
this one: 29 modules compiled under both, and 27 are identical. The two that differ,
`Shop.Pricing` and `Stats`, are the two that call `List.*`. They differ at those
call sites, in the deleted `bs@List@*` walkers, and in one added `flip`.

## Scenarios

| Id | Given | Then |
|---|---|---|
| F62.1 | `List.Sum([n, n, n])` compiled | the import chunk has `{lists, sum, 1}` and no `List` |
| F62.2 | one program calling all seven `List` rows | the chunk has `lists:sum/reverse/sort/map/filter/foldl` and `erlang:length` |
| F62.3 | `List.Sort([n, 1, n + 1, 0])` at `n = 5`; `List.Sort(xs)` returned as `list<int>`; `List.Sort(n)` | `[0, 1, 5, 6]`; compiles; a type error, not an import one |
| F62.5 | `List.FoldRight` with `(acc, x) => [x, ..acc]`; piped with a named `Push`; its import chunk; a callback returning a string over an `int` seed | `[1, 2, 3]` twice; `{lists, foldr, 3}`; a type error |
| F62.4 | `List.Fold` with `(acc, x) => [x, ..acc]`; with a named `Push(acc, x)`; after a `List.Map`; piped, `xs \|> List.Fold([], (acc, x) => [x, ..acc])` | `[3, 2, 1]`, `[3, 2, 1]`, `-19`, `[3, 2, 1]`: the accumulator is first |
