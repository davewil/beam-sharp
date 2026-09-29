# F65 — list comprehensions: `[r for Receipt r in cs]`

**Status**      **in progress** — 17 tests in `comprehension_tests`, 1245 in the suite; F65.1–16 seen
                red before the build (`syntax error before: for`), F65.17 red on the first cut's
                wording; a must-compile block and a `diagnoses: vacuous_generator` block in
                LANGUAGE.md §8, the first seen PROMOTED from `not-yet` and the second seen red;
                yecc 6 shift/reduce and 0 reduce/reduce before and after; tree-sitter parses a
                scratch file of five comprehensions with no ERROR node
**Implements**  [ticket 114](../../wayfinder/issues/114-comprehensions-revisited.md), A1–A7.
                Decides nothing
**Closes**      [ENG-571](https://linear.app/davewil/issue/ENG-571)
**Depends on**  F53 (the part prefix, legal at a generator's top), F41 (guard rules, which a
                filter keeps), F51 (the guard-level operator refusals, which reach a filter)
**Leaves**      map, binary and `Enumerable<T>` comprehensions (ticket 114 A7, fog on the map); a
                filter narrowing its binders, so `[n for int n in xs when n >= 0]` is `list<int>`,
                not a refinement; an expected arrow for a lambda written in a comprehension's head

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
- A guard keeps guard rules: a call to a user function is refused (`call_in_guard`), and the
  guard-level operator refusals (`mixed_operands`) reach it.
- A later generator and every guard see the bindings before them. Nothing bound inside a
  comprehension is visible after it, and a generator may not rebind a name already bound
  (`rebinding`), as a switch arm and a lambda parameter may not.
- A comprehension in a guard is refused (`comprehension_in_guard`), as a `switch` is: the BEAM
  has no comprehension in a guard.
- It lowers to one Erlang list comprehension with `<-` generators, which skip. A pattern's kind
  and relational tests become filters directly after its generator, and each `when` becomes one
  filter.

What the build read that no ticket spelled, for David to overrule:

- `in` is now a keyword.
- `generator_not_list` and `comprehension_in_guard` refuse what ticket 114 did not list; both
  would otherwise compile and crash (`bad_generator`, or an Erlang compile error).

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
| F65.10 | `[f for float f in xs when f > 0]` | refused, `mixed_operands` |
| F65.11 | a generator's binder named after the `]` | refused, `unbound_variable` |
| F65.12 | a generator binding a parameter's name | refused, `rebinding` |
| F65.13 | a source of type `int`, and one of type `term` | refused, `generator_not_list`, both |
| F65.14 | a comprehension inside a clause guard | refused, `comprehension_in_guard` |
| F65.15 | `Settled`, emitted | one `lc` with a `generate` over `Cs`, no `case` |
| F65.16 | the three new diagnostics on the term channel, in `--batch` and standalone | byte-identical (ENG-349) |
| F65.17 | `[v for { "a": v } in ms]` over `list<map<string, int>>` | refused, `map_pattern_deferred` at site `generator`, whose reason is the deferred form rather than exhaustiveness, since a generator skips |
