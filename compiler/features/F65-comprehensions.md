# F65 — list comprehensions: `[r for Receipt r in cs]`

**Status**      **done 2026-09-29** · [ENG-571](https://linear.app/davewil/issue/ENG-571) — 21 tests
                in `comprehension_tests`, 1249 in the suite. F65.1–16 seen red before the build
                (`syntax error before: for`), F65.17 red on the first cut's wording, F65.18–21
                red on the first cut where the review measured them. A must-compile block and a
                `diagnoses: vacuous_generator` block in LANGUAGE.md §8, the first seen PROMOTED
                from `not-yet` and the second seen red. yecc 6 shift/reduce and 0 reduce/reduce
                before and after; tree-sitter parses a scratch file of five comprehensions with
                no ERROR node.
                **Amended 2026-09-29** ([ENG-572](https://linear.app/davewil/issue/ENG-572)): a
                `when` narrows the generator before it, as an arm's guard narrows its pattern —
                F65.22–25, 25 tests in `comprehension_tests`, 1253 in the suite. F65.22–23
                and §8's `Kept` block seen red before the build; F65.23 red with each `when`
                narrowing from the generator's first domain, F65.25 red with `apply_guard/3`
                dropping the alternatives that read another generator's binder. The emitted
                `.abstr` is byte-identical to `9f2ace2`'s over the examples corpus and four
                guarded comprehensions
**Implements**  [ticket 114](../../wayfinder/issues/114-comprehensions-revisited.md), A1–A7.
                Decides nothing
**Closes**      [ENG-571](https://linear.app/davewil/issue/ENG-571)
**Depends on**  F53 (the part prefix, legal at a generator's top), F41 (guard rules, which a
                filter keeps), F51 (the guard-level operator refusals, which reach a filter)
**Fixes**       a relational pattern nested in a switch arm's tuple, `(>= 0, n) =>`, crashed
                `bs_emit:pattern/2` with a stack trace since F2: `argument_position/2` reads the
                path, which cannot tell a head parameter from a subject's tuple element (the
                trap F53 met for the part prefix). `child_type/3` now refuses it structurally,
                for an arm and a generator alike (F65.21)
**Leaves**      map, binary and `Enumerable<T>` comprehensions (ticket 114 A7, fog on the map);
                advice naming `== x` for `(x, x)` in a generator, which today says "rename the
                second one" ([ENG-573](https://linear.app/davewil/issue/ENG-573)); an expected
                arrow for a lambda written in a comprehension's head

## The program

```csharp
module Shop.Billing
record Receipt { OrderId: int, Pence: int }
type Charge = Receipt | (:error, string)

public list<Receipt> Settled(list<Charge> cs)
Settled(cs) -> [r for Receipt r in cs]

public list<string> Declines(list<Charge> cs)
Declines(cs) -> [reason for (:error, reason) in cs]

public list<Receipt> Large(list<Charge> cs)
Large(cs) -> [r for Receipt r in cs when r.Pence >= 10000]
```

## The rule

- `[expr for pattern in list quals]`, where `quals` is any mix of further generators
  `for pattern in list` and guards `when guard`. The result holds `expr` once for each combination
  of elements that every generator's pattern and every guard admit, in order.
- A generator's source must be a list. Anything else is refused (`generator_not_list`), `term`
  included, since `ValidateAs<T>` is where an outside value becomes a list.
- A generator's pattern is checked as a top, as a switch subject's is, so the part prefix
  (`float f`) is legal there. Its binders are narrowed to the list's element type intersected
  with the pattern's type. An element the pattern refuses is skipped. A pattern that no element
  can match is a warning (`vacuous_generator`), as a vacuous `switch` arm is.
- A guard is checked as a clause guard is: a call to a user function is refused
  (`call_in_guard`), and the guard-level operator refusals (`mixed_operands`) reach it.
- A guard narrows the binders of the generator before it, as an arm's guard narrows its pattern,
  so `[n for int n in xs when n >= 0]` is a `list<NonNegative>`. It is checked before it narrows, and
  each `when` narrows what the ones before it left. A guard that reads a name its generator did
  not bind, an outer one or another generator's, narrows nothing, as an arm's guard reading an
  outer name does.
- A later generator and every guard see the bindings before them. Nothing bound inside a
  comprehension is visible after it, and a generator may not rebind a name already bound
  (`rebinding`), as a switch arm and a lambda parameter may not, nor bind one name twice in
  its pattern, as a lambda may not.
- A comprehension in a guard is refused (`comprehension_in_guard`), as a `switch` is: the BEAM
  has no comprehension in a guard.
- It lowers to one Erlang list comprehension with `<-` generators, which skip. A pattern's kind
  and relational tests become filters directly after its generator, and each `when` becomes one
  filter. An Erlang generator binds its pattern's names fresh, so `== n` lowers to a fresh name
  and an `=:=` filter, and each generator's lowered names are unique in the module.

What the build read that no ticket spelled. David accepted all of it on 2026-09-29, reviewing
ENG-571, with the nested-relational fix under **Fixes**, and it is recorded in
[ticket 114](../../wayfinder/issues/114-comprehensions-revisited.md)'s Decisions entry:

- `generator_not_list` and `comprehension_in_guard` refuse what ticket 114 did not list; both
  would otherwise compile and crash (`bad_generator`, or an Erlang compile error).
- A generator may not rebind an outer name or bind one name twice (`rebinding`), following the
  switch arm and the lambda, where 114 said only that names are local.
- A map pattern over `map<K, V>` elements is refused at site `generator`, with the deferred form
  as its reason, since a generator owes no exhaustiveness.

## Scenarios

| Id | Scenario | Expected |
|---|---|---|
| F65.1 | `Settled` over a receipt, a declined charge and a receipt | compiles as `list<Receipt>` and returns the two receipts' `OrderId`s, `[1, 3]` |
| F65.2 | `Declines` over the same list | `["declined"]` |
| F65.3 | `Large`, a `when` guard after the generator | only the receipt of at least 10000 pence |
| F65.4 | `Fractional`, `[f for float f in amounts]` over `list<int \| float>` | the floats only, `[2.5]` |
| F65.5 | `Skus`, two generators, the second over the first's binding, and a guard | `[(1, "a"), (2, "c")]` |
| F65.6 | a comprehension nested in another's head, `[[x * 2 for x in row] for row in rows]` | `[[2, 4], [6]]` |
| F65.7 | a comprehension's head calling another module's function, after `using Shop.Tax` | `[100, 2500]` |
| F65.8 | `[r for Refund r in cs]` over `list<Charge>` | compiles with the `vacuous_generator` warning, and returns `[]` |
| F65.9 | a `when` calling a private function | refused, `call_in_guard` |
| F65.10 | `[f for f in xs when f > 0]` over `list<float>` | refused, `mixed_operands` |
| F65.11 | a generator's binder named after the `]` | refused, `unbound_variable` |
| F65.12 | a generator binding a parameter's name | refused, `rebinding` |
| F65.13 | a source of type `int`, and one of type `term` | refused, `generator_not_list`, both |
| F65.14 | a comprehension inside a clause guard, and inside a switch arm's guard | refused, `comprehension_in_guard`, both |
| F65.15 | `Settled`, emitted | one `lc` with a `generate` over `Cs`, no `case` |
| F65.16 | the three new diagnostics on the term channel, in `--batch` and standalone | byte-identical (ENG-349) |
| F65.17 | `[v for { "a": v } in ms]` over `list<map<string, int>>` | refused, `map_pattern_deferred` at site `generator`, whose reason is the deferred form rather than exhaustiveness, since a generator skips |
| F65.18 | `[1 for == n in xs]`, and `[(x, x) for x in xs for == x in ys]` | `== n` matches the bound `n`: `[1]` and `[(2, 2)]`; the first cut emitted `N <- Xs`, which an Erlang generator binds fresh, and returned `[1, 1, 1]` with erlc's shadowing warning |
| F65.19 | a relational pattern in each of two generators, `[1 for >= 0 in xs for >= 0 in ys]` | `[1]`, and no erlc warning: each generator's lowered variables are unique across the module |
| F65.20 | `[x for (x, x) in ps]` | refused, `rebinding`, as a lambda's repeated parameter is |
| F65.21 | `[n for (>= 0, n) in ps]`, and the switch arm `(>= 0, n) =>` | refused, `relational_pattern_nested`, as a clause head refuses it; both crashed `bs_emit:pattern/2` with a stack trace, the arm since F2 |
| F65.22 | `Kept`, `[n for int n in xs when n >= 0]` declared `list<NonNegative>` | compiles, and returns `[0, 3]` from `[-1, 0, 3]`; refused as `[int >= 0, ..] \| [int <= -1, ..]` before ENG-572 |
| F65.23 | `when n >= 0 when n <= 9` declared `list<Digit>`; and `when n >= 0 for int m in ys when m <= 9` declared `list<(NonNegative, Small)>` | both compile: each `when` narrows what the ones before it left, and a later generator keeps an earlier one's narrowing; `[0, 3, 9]` and `[(2, 5)]` |
| F65.24 | `[(x, y) for int x in xs for int y in ys when x < y]` declared `list<(int, int)>` | a guard that narrows nothing still compiles, and returns `[(1, 2)]` |
| F65.25 | `when x >= 0 or y >= 0`, across two generators, declared `list<(int, NonNegative)>` | refused, `return_not_declared`: either side of the `or` may admit the pair, so neither binder narrows; undeclared, it keeps `(0, -5)` |
