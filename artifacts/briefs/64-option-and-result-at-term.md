# Brief — ticket 64 (ENG-254): `option<term>` collapses to bare `term`

Status: **open, left open.** Evidence for David; nothing here is decided. Probes: `artifacts/probes/64/`.
What remains of the ticket after [68](../../wayfinder/issues/68-an-absorbed-member.md) is Q2 (how to fix it, given
the collapse is *refused*) and Q3 (does `result<T, E>` collapse at `E = term`).

## Q3 is answered by running it: no — only `T = term` collapses

`64-p3` (`bsc --api`, one declaration per row):

```
option<term>                  -> error: `:nothing` is absorbed by `term`            hint: tag it - (:some, term) | :nothing
result<term, binary>          -> error: `(:error, binary)` is absorbed by `term`
result<term, term>            -> error: `(:error, term)` is absorbed by `term`
result<int, term>             -> int | (:error, term) Go(int)                        accepted
result<binary, term>          -> (:error, term) | binary Go(int)                     accepted
option<list<term>>            -> :nothing | list<term> Go(int)                       accepted
option<map<string, term>>     -> :nothing | map<string, term> Go(int)                accepted
option<(atom, term)>          -> :nothing | (atom, term) Go(int)                     accepted
Found<term>   with  type Found<T> = (:found, T) | :absent   ->  :absent | (:found, term) Go(int)   accepted
```
Absorption needs the *success* member to be `term`; a `term` in the failure payload is a tuple member and `(:error, term)`
survives. Two sentences in the ticket are off: "sharpest at `map<string, term>`" — `option<map<string, term>>` is fine; the
bite is `option<V>` **where V is the map's value type**, i.e. a lookup's return — and "leaves the author with nothing to
reach for" — the diagnostic already prints the repair (`hint: tag it - (:some, term) | :nothing`) and a user-declared
parametric `Found<T>` compiles today.

## Why it is now on the critical path

Ticket 108 (2026-09-25) decided the crash-free form of every lookup returns `option<T>`: `Map.?Get`, `List.?First`,
`?Last`, `?At`, `?Max`, `?Min`, `?MaxBy`, `?Find`. At a value or element type of `term` each of those is an absorbed
`option<term>`, i.e. refused under 68's rule. ENG-324 (`Map.Get`/`Map.?Get`) is unbuilt, and F75 (2026-10-21) built
the total map operations but not the lookup. The decision here is what ENG-324 returns for the three motivating
`map<string, term>` shapes in ticket 48 (Plug `assigns`, a decoded `jsonb` document, Req's headers).

## What the bare form cannot do — run, in B# and in Erlang

`64-p4`, today's B#, a lookup over `list<(atom, term)>` written both ways:

```
Describe      k=:a kvs=[(:a, :nothing)] -> :present_and_nothing       // Found<term>
Describe      k=:a kvs=[(:b, 1)]        -> :absent
DescribeBare  k=:a kvs=[(:a, :nothing)] -> :absent_or_nothing         // bare `term`, the only honest signature
DescribeBare  k=:a kvs=[(:b, 1)]        -> :absent_or_nothing
```
(the bare form cannot tell a stored `:nothing` from a missing key. `64-p1` restates this in hand-written Erlang, which is a restatement of the encoding, not independent evidence; `64-p4` is the evidence.) The collapse is therefore not a
type-checker artefact: the bare encoding **loses information at run time**, and the compiler is right to refuse it.

Neighbours (all run, `64-p2`; sources cited):

| | lookup at a dynamic value type | tagged? |
|---|---|---|
| Elixir 1.18 | `Map.get/3` (`map.ex:526`, default `nil`): `{nil, nil}` for present-nil vs missing. `Map.fetch/2` (`map.ex:299` → `:maps.find`): `{{:ok, nil}, :error}` | `fetch` yes; `get` no |
| Gleam 1.12 | `dict.get` (`dict.gleam:150`) → `Result(v, Nil)`: `#(Ok(Nil), Error(Nil))`. `Option(a)` is `Some(a) \| None` (`option.gleam:19-21`), emitted `-type option(GA) :: {some, GA} \| none` | always |
| Elm core 1.0.5 | `Dict.get : comparable -> Dict comparable v -> Maybe v` (`Dict.elm:94`), `Maybe = Just a \| Nothing` (`Maybe.elm:39`) | always (not run; Elm cannot build offline here) |

Every neighbour tags uniformly. B#'s bare `option<T>` is the outlier, and the only one with a type that can
silently be vacuous.

## Cost of a tagged success (`64-p1`, OTP 28)

`{some, V}` is **3 words (24 bytes) extra for any payload** — small int, atom, 20-byte binary, 8-element list, 3-key map
all measured +3 words, payload shared. Returned-and-matched 50M times (callee returns `V` or `{some,V}`, caller unwraps and accumulates, not inlined): bare 506 ms, tagged 534 ms → ≈ **0.6 ns/op** (verifier: 0.6–1.1). A lookup that already walks a map or list is dominated by the walk.

Blast radius of changing `option<T>` itself: 32 `option<` mentions in 15 `.bs` files, and ticket 26 §4 /
F61 decided that an absent record key *is* `:nothing` at the boundary, so `option<int>` fields are bare on the wire.

## The options, as programs

**A — Leave `option<T>` as decided; make the `?` forms refuse `term` with a repair that exists.**
```csharp
Lookup(m, k) -> Map.?Get(m, k)           // m : map<string, term>
// error: Map.?Get returns option<term>, which is `term`: no caller can write the :nothing arm.
//   test first:  Map.Has(m, k) switch { :true => Map.Get(m, k), :false => … }        // Map.Has is built (F75)
//   or tag it:   own a Found<term>
```
Compiler delta: a call-site variant of the existing absorption diagnostic naming the operation and the
`Map.Has` / `Map.Get` pair; no change to `option`. Cost for the author: two calls (a double lookup) at exactly the
`term` case. *Strongest counterargument:* the three motivating cases of ticket 48 are all `term`-valued, so the
decided API is unusable at the shape that justified `map<K,V>`; the repair doubles the lookup and `Map.Get` (the
assertive half) is itself unbuilt.

**B — The `?` forms return a tagged success only where the element type absorbs `:nothing`.**
```csharp
Lookup(m, k) -> Map.?Get(m, k) switch {             // m : map<string, term>   ->  (:found, term) | :nothing
    (:found, v) => v,
    :nothing    => default }
// at map<string, int>:  Map.?Get(m, k)  ->  int | :nothing    (unchanged, 108 stands)
```
Compiler delta: the `Map.?Get`/`List.?First`… rows are compiler-known polymorphic signatures typed at each site's
ground types (67: lowered per site; F62's standard-signature table, `{Qualifier, Name, Arity}`), so a row can return
`Found<T>` when `absorbed(:nothing, T)` and `option<T>` otherwise: one predicate (`absorbed/2`, `bs_check.erl`,
already exists) and a second return template per `?` row. *Strongest counterargument:* the return **shape depends on
the instantiation**, so a caller's `switch` arms change when the value type goes from `int` to `term`, and no user code
can abstract over the difference (a user-written generic wrapper over `option<T>` is exactly where it would bite).
I could not probe that: it needs a compiler change.

**C — Every `?` form returns the tagged shape; `option<T>` stays for author-declared absence.**
```csharp
Lookup(m, k) -> Map.?Get(m, k) switch { (:some, v) => v, :nothing => default }   // at EVERY value type
```
Compiler delta: change the return templates of the `?` family (and 108's text); nothing in `option`, the
absorption rule, or F61's boundary fill. Cost: +3 words per hit (measured above), a hit always unwrapped by the
caller. *Strongest counterargument:* it overturns 108's stated return types and 97's `result<T, string>` /
`option<T>` pairing and makes `option<int>` (what a record field holds) and the lookup's shape differ for no
reason an `int`-valued caller can see.

## Recommendation

**B**, if the lookup is to ship at `term` at all, because it keeps 108's `option<T>` everywhere the type
can carry it (the common concrete cases) and the compiler already knows exactly when it cannot
(`absorbed/2`). The absorption diagnostic's existing hint (`(:some, term) | :nothing`) should name the *operation's*
tagged shape so the two spellings agree. **Take A first** if ENG-324 should not wait: it requires no new type
and its repair is measurable (a `Map.Has` guard) — then B is a follow-up with the ergonomics evidence in hand. I would
not take C: every neighbour tags uniformly and that is the argument for it, but it costs 108's return types to
pay for a case that only a `term`-valued container creates.

## What I could not measure

- Whether the instantiation-dependent shape in B actually hurts in practice (no generic user code exists to test it).
- Elm's behaviour (the compiler cannot fetch its package registry here); the Elm row is source-cited only.
- The 0.6 ns figure is a micro-loop on a shared 4-core container, not a per-lookup cost. My first draft stored the tuple in the process dictionary and read ≈11 ns; the verifier showed that measured `put/2`, so it was replaced.
