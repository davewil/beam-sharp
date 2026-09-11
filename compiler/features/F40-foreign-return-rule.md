# F40 — a foreign return may promise only what one guard decides

**Status**      **done 2026-09-11** — 14 new tests in `foreign_return_tests`, and
                the ten F9.11 assertions in `strings_tests` moved to the rule's
                wording; 772 in the suite, up from 758. No new gate: `check-language.sh`
                gained a `diagnoses:` block for 18 §2's own example and retagged
                the ENG-351 block, both seen red on the tree before the build
                (WRONG DIAG at `LANGUAGE.md:477` and `:1823`), and
                `check-examples.sh` compiles the rewritten `examples/Interop`.
                `./bin/verify.sh` green **twice from a clean clone**
**Implements**  [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §2,
                decided 2026-08-13, whose `string` slice F9.11 built and whose
                remainder no F-file, issue or row tracked until
                [ENG-354](https://linear.app/davewil/issue/ENG-354)
**Closes**      [ENG-354](https://linear.app/davewil/issue/ENG-354), and
                [ENG-355](https://linear.app/davewil/issue/ENG-355) absorbed into
                it (a foreign recursive return crashed the compiler)
**Decides**     nothing. Every spelling was settled by the ENG-351 grill of
                2026-09-11 before this was taken: the rule stands as written
                (Q2), a recursive return is refused (Q5), the Interop example
                moves to `:ets.lookup` (Q6), one diagnostic (Q7), a fixed field
                set is admissible and a named record is refused with its own
                sentence (Q8)
**Depends on**  F9, for `string` as a refined binary; F19, whose wrapper pass
                this now runs ahead of; F33, for the domain map member; F36,
                for the `mu` this refuses without unfolding

## What was there

Ticket 18 §2 says a foreign function's declared **return** type may mention only
what a BEAM guard decides in O(1), and that anything deeper is a compile error at
the declaration, with `list<Order>` as its own refused example. `LANGUAGE.md` §11
listed the rule as **decided** since 2026-08-13. What was built was F9.11's
slice: `opaque_refinement/1` refused a `string` anywhere in a foreign return, and
nothing else. So on `afdbde0` this compiled and ran:

```csharp
module Orders

using :maps {
    map<binary, int> from_list(list<term> pairs)
}

public map<binary, int> Counts()

Counts() -> :maps.from_list([(:not_a_binary, :not_an_int)])
```

```
$ bsc Orders.bs Counts
{not_a_binary = :not_an_int}
```

A map from a function declared `map<binary, int>` holding neither, printed
without complaint — ticket 06's outcome 3, the thing ticket 18 exists to rule
out. And this did not compile or refuse, but crashed:

```csharp
module Rec

type Tree = :leaf | (Tree, Tree)

using :trees {
    Tree grow(int n)
}
```

```
escript: exception error: no function clause matching
                 bs_check:error_members(#{mu => 'Tree', ...})
```

because `foreign_wrappers/2` ran before the refusal and asked a recursive type
for its tuple members (ENG-355).

## The program

Ticket 18 §2's own example, refused at the declaration:

```csharp
module Orders

record Order { Id: int, Total: int }

using :ets {
    list<Order> lookup(atom tab, term key)
}

public list<Order> Find(int id)

Find(id) -> :ets.lookup(:orders, id)
```

```
Orders.bs:6:5: error: :ets.lookup returns `list<Order>`, which one guard cannot decide
  a foreign return may promise only what one guard checks in O(1), and
  every element of this list would need inspecting.
  declare it `list<term>`, then `ValidateAs<list<Order>>` where it is used.
```

And the crossing, which compiles:

```csharp
public result<list<Order>, ValidationError> Find(int id)

Find(id) -> ValidateAs<list<Order>>(:ets.lookup(:orders, id))
```

## The rule as built

`bs_check:foreign_rets_decidable/2` runs in the declaration pass, right after
`collapse_refused/2` and **before** `foreign_wrappers/2`, and in `exports_of/1`
so that `bsc --api` refuses what a compile refuses. For each foreign return it
resolves the type and walks the positions one guard reaches — the whole value,
each tuple member, each field of an inline map — and stops at the first thing a
walk would be needed for, in this order:

| found | what one guard cannot do | admissible neighbour |
|---|---|---|
| `recursive` | a `mu`, wherever it sits: only a walk decides one, and it is not unfolded (F36) | — |
| `list` | a list part whose element type is narrower than `term` | `list<term>` is `is_list` |
| `map` | a domain member whose key or value is narrower than `term` | `map<term, term>` is `is_map` |
| `record` | a fixed-field member carrying `Kind`, which this compiler mints and Erlang never writes | the inline `{ Id: int, Total: int }`: `is_map` and one `map_get` test per field |
| `string` | a refined binary part; `valid_utf8` reads every byte (F9.11) | `binary` |

The structural four are looked for before a `string`, so `(string, list<Tree>)`
is refused as a list and the edit is the `term` route rather than `binary` under
a bracket that needs a walk anyway.

**One tag, `foreign_ret_beyond_one_guard`**, retiring `opaque_ret_at_boundary`.
The term carries `why` (the row above), `at` (`whole` or `inside`) and, for a
record or a recursive type, `name` and `fields`. The edit line is chosen from
those:

- a `string` keeps F9.11's edit: *declare it `binary`* for the whole return,
  *write `binary` where it says `string`* inside one;
- a record gets its inline field form — and **not** `ValidateAs<Order>`, which
  was measured to refuse a map without `Kind` at run time
  (`(:error, ([], "{ Kind: :'Va2.Order', Id: int, Total: int }"))`), so
  recommending it would be the refusal handing back the defect it refuses;
- everything else gets 18 §2's route: *declare it `list<term>`* /
  *`map<term, term>`* / *`term`* where the whole return is the offender, and
  *declare the part a guard cannot decide as `term`* where it is inside a
  tuple or a union — `result<list<Order>, atom>` resolves to a union whose list
  member sits in the top-level list part, so "whole" is measured as *the type
  is nothing but that part*, not as *the part is at the top*.

The message points at the route and says nothing about the route's state: for
a `map<K, V>` the `ValidateAs` site is refused today by `validate_domain_map`,
whose own text says the key walk is unbuilt (ENG-356).

## Scenarios

| # | scenario | asserted at | result |
|---|---|---|---|
| F40.1 | `list<int> reverse(list<int> xs)` — the example that shipped for three weeks | CLI: refused by name, `list<term>` edit | pass |
| F40.2 | `list<Order> lookup(atom tab, term key)` — 18 §2's own example | CLI | pass |
| F40.3 | `map<binary, int> from_list(...)` — the outcome-3 program above | CLI: `map<term, term>` edit | pass |
| F40.4 | `Account fetch(int id)`, a named record | CLI: own sentence, inline field form, no `ValidateAs<Account>` | pass |
| F40.5 | `Tree grow(int n)`, recursive (ENG-355) | CLI: refused by name, no stack trace | pass |
| F40.6 | `result<list<Order>, atom>` — the offender inside a union | CLI: *declare the part* | pass |
| F40.7 | `option<list<int>>` — through the prelude alias | CLI | pass |
| F40.8 | `list<term>`, `map<term, term>`, `(:ok, int) \| :undefined`, `result<int, foreign_error>` | build and run | pass |
| F40.9 | the wrapper still fires after the refusal moved ahead of it | run: `(:error, (:error, :badarg))` | pass |
| F40.10 | `int sum(list<int> xs)` — a parameter is not checked | build and run | pass |
| F40.11 | `{ Method: binary, Path: binary }` — an inline map type is admissible (Q8) | build and run | pass |
| F40.12 | `string read_file(term path)` — F9.11 under the one tag, `binary` edit kept | CLI | pass |
| F40.13 | the term form: `why := map, at := whole` | `--diagnostics term` | pass |
| F40.14 | `bsc --api` refuses the same declaration and prints no API | CLI | pass |

The F9.11 tests in `strings_tests.erl` — `list<string>`, `map<string, term>`,
`map<binary, string>`, `result<map<string, int>, atom>`, `result<string, atom>`,
an alias, a record field, `(string, list<Tree>)`, `(string, Tree)` — assert the
rule's wording now, and the four that asserted *no edit* under a walk assert the
`term` route instead.

## What moved with it

- `examples/Interop/interop.bs`, `LANGUAGE.md` §11 and `TOUR.md` §13 declared
  `list<int> reverse(list<int> xs)`, which the rule refuses and which
  `List.Reverse` does natively anyway (Q6). They declare
  `list<term> lookup(atom tab, term key)` on `:ets`, 18 §2's own example. The
  runnable shipped line is still `Total`.
- `LANGUAGE.md` §4's `diagnoses:` block is retagged, and §11 gained a
  subsection with the refusal and the crossing as gated blocks.
- `ffi_tests.erl`'s fixture declares `list<term>`.
- The §11 *Owed* paragraph and §13's "shipped, without the boundary guard" row
  are unchanged: the guard that checks the claim this rule narrows is ENG-357.

## Done when

- Every scenario above asserts at the CLI or by running the module.
- `check-language.sh` red before the build on both `diagnoses:` blocks, green after.
- The wrapper fixture in `foreign_wrapper_tests` is untouched and green: moving
  the refusal ahead of the wrapper pass changed what runs first, not what runs.
- `verify.sh` green twice from a clean clone at the final SHA.

## What building it found

**"Whole" is not "at the top".** The first cut called an offender `whole` when it
sat in the type's own list or map part, and offered *declare it `list<term>`* for
`result<list<Order>, atom>` — an edit that would replace a union with a list.
The algebra flattens `result<T, E>` into one type whose list part IS `T`'s, so
position in the parts says nothing about position in the declaration. What
`whole` measures now is containment: the declared type is a subtype of the
offending part alone.

**The record's recommended route was checked, not assumed.** `ValidateAs<Order>`
compiles over a `term`, so the obvious edit for a refused record return was the
same `term`-then-validate route as everything else. Run, it refuses every map
Erlang could hand back, because the validator demands the `Kind` the compiler
mints. The refusal now recommends the inline field form, which is admissible
under Q8 and was compiled to prove it (F40.11).

**A test string that wraps a phrase breaks the assertion that reads it.** The
`string` reason was rewrapped once because *entry check* fell across a line
boundary and `the_boundary_error_names_the_replacement_test`, which has asserted
that phrase since F9, went red.
