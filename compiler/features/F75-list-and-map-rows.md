# F75 — `List` and `Map` rows: what is specific to each, over `lists` and `maps`

**Status**      **closed 2026-10-25** (built 2026-10-21) — 44 tests in `standard_rows_tests`;
                `check-reserved-qualifiers.sh` gained P8, seen red on master first,
                twelve red stubs and one green. Closed by David in part: the pairs
                moved to [ENG-324](https://linear.app/davewil/issue/ENG-324)
**Implements**  [ticket 96](../../wayfinder/issues/96-standard-environment-breadth.md) Q1, Q2
                and Q5, resolved 2026-09-25, and [ticket 118](../../wayfinder/issues/118-the-list-and-map-rows-that-need-a-decision.md),
                which this build raised and David resolved 2026-10-21: the rows that can
                find nothing are not built here, see *Left*. Decides nothing
**Closes**      [ENG-454](https://linear.app/davewil/issue/ENG-454) **in part**: every
                total row, not the pairs
**Depends on**  F62 (the signature table and `otp_args/3`), F45 (the polymorphic
                signature, which each row's signature now is), F33 (`map<K, V>`)
**Leaves**      the pairs (`Map.Get`, `Map.Find`, `List.First`, `Last`, `At`), which wait on
                [ENG-324](https://linear.app/davewil/issue/ENG-324) building ticket 108's `?`,
                `Map.Update/3` among them; ticket 94's `TryMap`
                ([ENG-435](https://linear.app/davewil/issue/ENG-435))

## Why this one now

Exemplar 25f declared OTP's `maps:from_list` and `maps:to_list` in a `using :maps` block, and
25g declared `from_list`, `put`, `remove` and `find`. A foreign declaration may promise only
what one guard decides, so each returned `map<term, term>` or `list<term>`, and 25f validated
a map's entries a second time to get back the type the map already had. It was also the last
blocker on [ENG-612](https://linear.app/davewil/issue/ENG-612), 25f's request side.

## The program

```csharp
module Pending

record State { Pending: map<reference, term> }

public State Track(State s, reference ref, term from)
Track(s, ref, from) -> s with { Pending = Map.Put(s.Pending, ref, from) }

public list<(string, int)> Entries(map<string, int> counts)
Entries(cs) -> Map.ToList(cs)
```

`Map.Put` compiles to `maps:put(Ref, From, Pending)` and keeps `map<reference, term>`.
`Map.ToList` compiles to `maps:to_list(Cs)` and is `list<(string, int)>`, so nothing is
validated twice.

## The rule

- **A row's signature is B# source.** `bs_check:declared_rows/0` holds each new row as
  `{Key, Target, Order, Signature}`, the signature written as an author would write it:
  `"map<K, V> Put<K, V>(map<K, V> m, K k, V v)"`. It is parsed by the compiler's own parser
  and typed exactly as a call to a user's polymorphic function is (F45): the arguments solve
  `K` and `V`, and the return is rewritten with the solution. This is the move F62 said the
  next polymorphic row owed, and F62's `Sum`, `Length`, `Reverse`, `Sort` and
  `Float.FromInt` moved with it, their `reserved_sig/4` clauses deleted and F62's tests
  unchanged. `Map`, `Filter`, `Fold`, `FoldRight` and `Term.Compare` keep theirs: the first
  four compute a callback's expectation in `reserved_args/5`, and `Fold`'s accumulator is
  iterated, which a declared signature does not yet say.
- **The order is the only per-row emitter fact.** `[2, 3, 1]` says OTP's first argument is
  B#'s second. `bs_emit:otp_args/3` reads it for every declared row; F62's hand-written
  clauses for `Map`, `Filter` and `Fold` stay.
- **Names and argument order are Elixir's** (ticket 96 Q2): the collection first, so a pipe
  feeds it (David, 2026-10-21: *"should definitely be pipe friendly order"*). **Behaviour is
  the OTP function's** (Q1), **chosen to be Elixir's where the two differ** (ticket 118):
  `List.Zip` stops at the shorter list, as `lists:zip/3` does with `trim` (Q1). Where neither
  ticket reaches, OTP's stands: `List.Seq(5, 1)` fails as `lists:seq/2` does.
- **An order entry can be a constant.** `{atom, trim}` in `Zip`'s order is an argument the
  row supplies, not one the author writes.
- **A sought value the collection cannot hold is refused** (ticket 118 Q5). `List.Contains`,
  `List.Delete`, `Map.Remove`, `Map.Has`, `Map.Take` and `Map.Drop` type the value or keys
  looked for as `term`, so the signature accepts anything and widens nothing, and
  `bs_check:sought_row/1` says which argument is searched for which: when its type has no
  overlap with the element or key type, the call is refused as `sought_never_found`, naming
  both. An empty collection, or an argument already refused, refuses nothing; nor does a
  type variable inside a polymorphic function, which a caller may choose to hold the value.
- **`List.Flatten` is Elixir's, at every depth** (ticket 118 Q2), over `lists:flatten/1`. Its
  return is computed, because no signature text says *"the innermost element"*: a
  `reserved_sig/4` clause returns `list<flat(element)>`, where `bs_types:flat_elem/1` opens
  every list member at every depth and a type met a second time adds nothing, so
  `type Tree = int | list<Tree>` opens to `int`. Inside a polymorphic function a `list<T>` is
  read as `list<term>`: `T` has no shape until a caller picks one (F45), and a caller may pick
  a list, so `List.Flatten` over it cannot promise `list<T>` back, and the same holds for a `T`
  at any depth (`list<list<T>>`). The cold review found this promise being made and kept by
  the checker while the value broke it.
- **How a variable is recognised.** While a polymorphic body is checked, `T` is the singleton
  atom `'T'` (F45). `bs_types:names_atom/2` looks for it as a named member of a finite atom set,
  at any depth, so a plain `atom`, which admits `'T'` without naming it, is not a variable. A
  `:T` literal written inside a generic over `T` is the same atom and reads as the variable:
  that is F45's representation, not this feature's, and it only makes these two rules more
  permissive there.
- **The refusal stands down further than the typing.** A body that joins a variable with
  `atom`, `[x, ..ys]` with `ys` a `list<atom>`, absorbs the variable's singleton into `atom`,
  and nothing names it any more. The sought-value check therefore asks
  `bs_types:admits_atom/2`, *could* this type hold the variable, and stands down if so: inside
  a polymorphic function it costs the diagnostic wherever either side holds `atom` (or `term`)
  at any depth, `List.Contains(list<atom>, 5)` among them, and it never refuses a program a
  caller's choice makes right. The absorption itself is an F45 defect, measured on
  master before this feature: `G<T>(T x, list<atom> ys) -> [x, ..ys]` is accepted as
  `list<atom>` and returns `[[5], :a]`. Filed as
  [ENG-881](https://linear.app/davewil/issue/ENG-881); `List.Flatten` over such a list
  inherits it.
- **`List.Insert` is Elixir's `insert_at`** (ticket 118 Q3): no OTP function inserts at an
  index, so it is the second `generated` row after `Term.Compare`, a local function over
  `lists:split/2` written into the module that calls it. An index past the end appends; a
  negative one counts from the end, `-1` appending; one before the start prepends.
- **`Map.Update` is Elixir's `update/4`** (ticket 118 Q4), over `maps:update_with/4`: the
  function on a present key, the default on a missing one. `Map.Update/3`, which fails on a
  missing key, is one of 96 Q3's pairs and is not a row.

| Row | Target | Signature |
|---|---|---|
| `List.Seq/2` | `lists:seq/2` | `list<int> Seq(int first, int last)` |
| `List.Concat/2` | `erlang:'++'/2` | `list<T> Concat<T>(list<T> xs, list<T> ys)` |
| `List.Zip/2` | `lists:zip/3`, with `trim` | `list<(A, B)> Zip<A, B>(list<A> xs, list<B> ys)` |
| `List.Flatten/1` | `lists:flatten/1` | computed: `list<flat(element)>` |
| `List.Insert/3` | generated | `list<T> Insert<T>(list<T> xs, int i, T x)` |
| `List.Contains/2` | `lists:member/2`, swapped | `bool Contains(list<term> xs, term x)` |
| `List.Delete/2` | `lists:delete/2`, swapped | `list<T> Delete<T>(list<T> xs, term x)` |
| `List.Duplicate/2` | `lists:duplicate/2`, swapped | `list<T> Duplicate<T>(T x, int n)` |
| `Map.FromList/1` | `maps:from_list/1` | `map<K, V> FromList<K, V>(list<(K, V)> pairs)` |
| `Map.ToList/1` | `maps:to_list/1` | `list<(K, V)> ToList<K, V>(map<K, V> m)` |
| `Map.Put/3` | `maps:put/3`, the map last | `map<K, V> Put<K, V>(map<K, V> m, K k, V v)` |
| `Map.Remove/2` | `maps:remove/2`, swapped | `map<K, V> Remove<K, V>(map<K, V> m, term k)` |
| `Map.Update/4` | `maps:update_with/4`, reordered | `map<K, V> Update<K, V>(map<K, V> m, K k, V init, fn(V) -> V f)` |
| `Map.Has/2` | `maps:is_key/2`, swapped | `bool Has(map<term, term> m, term k)` |
| `Map.Keys/1` | `maps:keys/1` | `list<K> Keys<K, V>(map<K, V> m)` |
| `Map.Values/1` | `maps:values/1` | `list<V> Values<K, V>(map<K, V> m)` |
| `Map.Size/1` | `erlang:map_size/1` | `int Size(map<term, term> m)` |
| `Map.Merge/2` | `maps:merge/2` | `map<K, V> Merge<K, V>(map<K, V> a, map<K, V> b)` |
| `Map.Take/2` | `maps:with/2`, swapped | `map<K, V> Take<K, V>(map<K, V> m, list<term> keys)` |
| `Map.Drop/2` | `maps:without/2`, swapped | `map<K, V> Drop<K, V>(map<K, V> m, list<term> keys)` |

## A variable under `map<K, V>` is solved, not erased

F45 kept a variable alive in a list, a tuple, a union and an arrow, and erased it to `term`
anywhere else, a map included. Under that rule every `Map` row above returns
`map<term, term>`, which is what the `using :maps` blocks already gave. So the template now
reads `map<K, V>` the way it reads `list<T>`: `bs_types:map_kv/1` gives the keys and values
an argument's map part can hold, as `list_elem/1` gives a list's element, and the domain map
is covariant in both (measured: `map<atom, int>` is within `map<term, int>`, and not the
reverse). A named field contributes its key as `fields_fit/5` reads it, a name as its atom and
a string key as `string`, and its value's type; an open field set can hold any key, so it
contributes `term` for both.

**The key is `string`, not the literal, and the review found why it must be.** The first build
read `{ "a" = n }`'s key as the literal `"a"`, and `Map.Keys({ "a" = n })` was refused: the
algebra puts `{ "a": int }` within `map<string, int>` but not within `map<"a", int>`, because
`bs_types:key_type/1` still types a string key as `string`. Its comment says *"the algebra has
no singleton binary"*, which F68 made untrue. Narrowing `key_type/1` would change what F58 and
F68 built, so it is left; `map_kv/1` reads keys through it, so the solved key always admits the
field set it came from.

**Why this is the build and not a decision.** Ticket 37 decided that a call's arguments choose
each variable by matching (*"instantiation is matching"*), and F45 built that matching for the
positions it reached. Its erasure of a map position is recorded in F45 as a build boundary, not
as a rule: a value reaching the body through an erased position must not be promised a
narrower type. `map<K, V>` now has a share to match, the same way `list<T>` has, so the rule
that erased it no longer applies. Variables under a named field or a refinement are still
erased, for F45's reason.

This reaches a user's own signature too: `map<K, V> Same<K, V>(map<K, V> m)` called with a
`map<string, int>` now returns `map<string, int>`, where it returned `map<term, term>` and was
refused against that return. A variable under a named field or a refinement is still erased.

## What the import chunk can and cannot see

erlc compiles `maps:put/3` and `maps:is_key/2` to instructions, so a program calling
`Map.Put` or `Map.Has` imports nothing for them. The artefact test lists every other row's
import and leaves those two to their value tests, and P8's probe calls `Map.FromList`,
`Map.Merge` and `Map.Size`, whose imports survive.

## The exemplars

- **25f**: the `using :maps` block is deleted. `request.bs` builds its bodies with
  `Map.FromList`, and `decode.bs`'s `Decode` walks `Map.ToList(answers)` directly, so its
  `ValidateAs<list<(string, AnswerWire)>>` and the failure arm that could not fire are gone,
  and it returns an `Evaluation` rather than a `result`.
- **25g**: the block keeps `find` alone, which is `Map.Find`'s crash-free half and waits on
  ENG-324. `Pending` is `map<reference, term>`, built with `Map.FromList([])` and kept by
  `Map.Put` and `Map.Remove`.

`25f_surface_probe.sh` and `25g_surface_probe.sh` print byte-identical output before and
after: both compile, and both replays return what they returned.

## Left

- **The pairs.** `Map.Get`/`Map.?Get`, `Map.Find`, `Map.Update/3`, `List.First`, `Last` and
  `At` are ticket 96 Q3's pairs, spelled by ticket 108 and built by ENG-324. Each is a declared
  row once the `?` parses.
- **Ticket 118's history.** The first build of this file left `Flatten`, `Insert` and `Update`
  unbuilt and `Zip` and the sought value on OTP's reading, and raised the five as ticket 118
  ([ENG-878](https://linear.app/davewil/issue/ENG-878)). David answered all five the same day;
  the rules above are the answers.

## Scenarios

| Id | Given | Then |
|---|---|---|
| F75.1 | `List.Seq(1, 3)`; `List.Concat([1, 2], [7])`; `List.Zip([5, 2], ["a", "b"])`; `List.Contains([1, 2, 3], 2)`; `List.Delete([1, 5, 1], 1)`; `List.Duplicate(4, 3)` | `[1, 2, 3]`; `[1, 2, 7]`; `[(5, "a"), (2, "b")]`; `:true`; `[5, 1]`; `[4, 4, 4]` |
| F75.2 | `List.Concat` of `list<int>` and `list<string>`; `List.Zip` returned as `list<(string, int)>`; `List.Delete(xs, :x)` as `list<int>` | `list<int \| string>` and not `list<int>`; refused; compiles |
| F75.3 | every `Map` row run once | each returns what its OTP function returns, `Merge` preferring the second map's value |
| F75.4 | `Map.Put(m, "k", n)` as `map<string, int>`; `Map.Put(m, "k", :x)` as the same; `Map.ToList`, `Keys`, `Values` as `list<(string, int)>`, `list<string>`, `list<int>`; `Map.Keys` and `Map.Values` of `{ "a" = n, "b" = 2 }`, and `Map.Keys({ A = n })` as `list<atom>`; `Map.Keys` of an open field set | compiles; refused, naming `:x`; compiles; `["a", "b"]`, `[n, 2]`, compiles; refused, not crashed |
| F75.5 | `Map.Size` of a record | refused as an argument the row does not accept |
| F75.6 | one program calling every row | the import chunk holds each row's OTP function, `maps:put` and `maps:is_key` excepted, and no `List` or `Map` |
| F75.7 | a user's `map<K, V> Same<K, V>(map<K, V> m)` returned as `map<string, int>` | compiles |
| F75.8 | `List.Zip([5, 2], [:a])`; its import chunk | `[(5, :a)]`; `{lists, zip, 3}` |
| F75.9 | `List.Flatten([[5, [2]], [3]])`; `List.Flatten([[], [5]])`; a `list<int \| list<int \| list<int>>>` and a `list<Tree>` returned as `list<int>`; a `list<list<string>>` returned as `list<int>`; `list<T> G<T>(list<T> xs) -> List.Flatten(xs)` | `[5, 2, 3]`; `[5]`; compile; refused, naming `string`; refused, `G` returning a value its signature does not declare |
| F75.10 | `List.Insert([1, 2, 3], i, 9)` at `i` = 1, 10, -1, -2, -10; `:x` into a `list<int>` returned as `list<int>` | `[1, 9, 2, 3]`, `[1, 2, 3, 9]`, `[1, 2, 3, 9]`, `[1, 2, 9, 3]`, `[9, 1, 2, 3]`; refused |
| F75.11 | `Map.Update(m, k, 0, n => n + 1)` over `{"a" = 1}` at `"a"` and `"b"`; as `map<string, int>`; `Map.Update/3` | `{"a" = 2}`, `{"a" = 1, "b" = 0}`; compiles; refused |
| F75.12 | `List.Contains(list<int>, "x")`; `Map.Has`, `Remove`, `Take`, `Drop` and `List.Delete` with a value no key or element could equal; the same over `list<int \| string>`, `list<term>`, `[]` and a `term` key; `List.Contains(list<T>, "x")` in a polymorphic function, and `List.Contains([x, ..ys], "x")` with `x : T` and `ys : list<atom>`, called with `T` a `string`; `Map.Has` of a record; `Map.Take(m, [1])` | refused as `sought_never_found`, naming both; refused; compile; compiles, and the second answers `:true`; refused once, as an argument not accepted; *"an element of argument 2"* |
