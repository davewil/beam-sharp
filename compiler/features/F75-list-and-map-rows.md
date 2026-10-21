# F75 — `List` and `Map` rows: what is specific to each, over `lists` and `maps`

**Status**      **built 2026-10-21, not closed** — 24 tests in `standard_rows_tests`;
                `check-reserved-qualifiers.sh` gained P8, seen red on master first,
                twelve red stubs and one green. Closing is David's call
**Implements**  [ticket 96](../../wayfinder/issues/96-standard-environment-breadth.md) Q1, Q2
                and Q5, resolved 2026-09-25: the rows that can find nothing are not built
                here, see *Left*. Decides nothing
**Closes**      [ENG-454](https://linear.app/davewil/issue/ENG-454) **in part**: its total
                rows, less three, see *Left*
**Depends on**  F62 (the signature table and `otp_args/3`), F45 (the polymorphic
                signature, which each row's signature now is), F33 (`map<K, V>`)
**Leaves**      the pairs (`Map.Get`, `Map.Find`, `List.First`, `Last`, `At`), which wait on
                [ENG-324](https://linear.app/davewil/issue/ENG-324) building ticket 108's `?`;
                `List.Flatten`, `List.Insert` and `Map.Update`, each of which needs a
                decision this file does not take; ticket 94's `TryMap`
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
  feeds it. **Behaviour is the OTP function's** (Q1): `List.Zip` of unequal lengths fails as
  `lists:zip/2` does, and `List.Seq(5, 1)` fails as `lists:seq/2` does.
- **A value that can only be looked for is `term`.** `List.Contains`, `List.Delete`,
  `Map.Remove`, `Map.Has`, `Map.Take` and `Map.Drop` take the sought value or keys as `term`:
  a value of another type is never found, so it neither fails nor widens the result.

| Row | Target | Signature |
|---|---|---|
| `List.Seq/2` | `lists:seq/2` | `list<int> Seq(int first, int last)` |
| `List.Concat/2` | `erlang:'++'/2` | `list<T> Concat<T>(list<T> xs, list<T> ys)` |
| `List.Zip/2` | `lists:zip/2` | `list<(A, B)> Zip<A, B>(list<A> xs, list<B> ys)` |
| `List.Contains/2` | `lists:member/2`, swapped | `bool Contains(list<term> xs, term x)` |
| `List.Delete/2` | `lists:delete/2`, swapped | `list<T> Delete<T>(list<T> xs, term x)` |
| `List.Duplicate/2` | `lists:duplicate/2`, swapped | `list<T> Duplicate<T>(T x, int n)` |
| `Map.FromList/1` | `maps:from_list/1` | `map<K, V> FromList<K, V>(list<(K, V)> pairs)` |
| `Map.ToList/1` | `maps:to_list/1` | `list<(K, V)> ToList<K, V>(map<K, V> m)` |
| `Map.Put/3` | `maps:put/3`, the map last | `map<K, V> Put<K, V>(map<K, V> m, K k, V v)` |
| `Map.Remove/2` | `maps:remove/2`, swapped | `map<K, V> Remove<K, V>(map<K, V> m, term k)` |
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
reverse). A named field contributes its key as a literal and its value's type; an open field
set can hold any key, so it contributes `term` for both.

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

- **The pairs.** `Map.Get`/`Map.?Get`, `Map.Find`, `List.First`, `Last` and `At` are ticket 96
  Q3's pairs, spelled by ticket 108 and built by ENG-324. Each is a declared row once the `?`
  parses.
- **`List.Flatten`.** `lists:flatten/1` flattens at every depth. No signature says that: typed
  `list<T> Flatten<T>(list<list<T>>)`, a `list<list<list<int>>>` would be promised
  `list<list<int>>` and handed `list<int>`. One level is `lists:append/1`, which Elixir calls
  `Enum.concat/1`. Which one `List.Flatten` is needs a decision.
- **`List.Insert`.** No OTP function inserts at an index, so it would be the second
  `generated` row after `Term.Compare`, and Elixir's `List.insert_at/3` clamps an index past
  the end and counts a negative one from it. Whether B# does the same needs a decision.
- **`Map.Update`.** Elixir has `Map.update/4`, with a default, and `Map.update!/3`, which
  fails on a missing key: the second is one of Q3's pairs in all but name. Which of the two
  `Map.Update` is, and whether the other is its `?` form, needs a decision.

## Scenarios

| Id | Given | Then |
|---|---|---|
| F75.1 | `List.Seq(1, 3)`; `List.Concat([1, 2], [7])`; `List.Zip([5, 2], ["a", "b"])`; `List.Contains([1, 2, 3], 2)`; `List.Delete([1, 5, 1], 1)`; `List.Duplicate(4, 3)` | `[1, 2, 3]`; `[1, 2, 7]`; `[(5, "a"), (2, "b")]`; `:true`; `[5, 1]`; `[4, 4, 4]` |
| F75.2 | `List.Concat` of `list<int>` and `list<string>`; `List.Zip` returned as `list<(string, int)>`; `List.Delete(xs, :x)` as `list<int>` | `list<int \| string>` and not `list<int>`; refused; compiles |
| F75.3 | every `Map` row run once | each returns what its OTP function returns, `Merge` preferring the second map's value |
| F75.4 | `Map.Put(m, "k", n)` as `map<string, int>`; `Map.Put(m, "k", :x)` as the same; `Map.ToList`, `Keys`, `Values` as `list<(string, int)>`, `list<string>`, `list<int>` | compiles; refused, naming `:x`; compiles |
| F75.5 | `Map.Size` of a record | refused as an argument the row does not accept |
| F75.6 | one program calling every row | the import chunk holds each row's OTP function, `maps:put` and `maps:is_key` excepted, and no `List` or `Map` |
| F75.7 | a user's `map<K, V> Same<K, V>(map<K, V> m)` returned as `map<string, int>` | compiles |
