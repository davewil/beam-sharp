# Decision brief — ticket 64 (ENG-254): `option<term>` and `result<term, E>` collapse to bare `term`

**Status: OPEN. Nothing is resolved.** Prepared autonomously 2026-10-13. Probes:
[`probes/64/`](probes/64/). The verifier section at the end records which a second agent re-ran.

## The one question

**When the value type is `term`, what is the program that says "absent"?** Tickets 68 and F31 settled
that the bare form is refused. The ticket's remaining half is what the author writes instead, and
the probes show two things the ticket did not have: the compiler already prints an answer, and
there is a way to reach the collapse that the refusal does not cover.

## What the ticket got wrong or left unmeasured

| Ticket says | Measured 2026-10-13 | Probe |
|---|---|---|
| the refusal "leaves the author with nothing to reach for" | the diagnostic ends `hint: tag it - (:some, term) \| :nothing`, and that shape declares and `--api`s cleanly | P1 |
| Q3: does the rule reach `result<T, E>` at `E = term`? "not measured" | **no**: `result<int, term>` survives as `int \| (:error, term)`. The collapse is at `T`, not `E`: `result<term, atom>` and `result<(atom, binary), binary>` are refused, `result<atom, binary>` is not | P1 |
| the refusal is built (F31, F68/ticket 68) | built **at written type annotations only**; an inferred `option<term>` (a generic's result, a local binding, a switch) is never checked (verifier-confirmed). A generic `option<T> Wrap<T>(…)` compiles, and instantiated at `T = term` it silently loses the distinction | P2, P2b |

## Evidence

**P1 — declaration verdicts** (`bsc --api`, HEAD): accepted — `option<int>`, `option<map<string,
term>>`, `option<list<term>>`, `result<int, atom>`, `result<int, term>`, `result<atom, binary>`,
`result<atom, atom>`, `(:ok, term) | :absent`, `(:some, term) | :nothing`, and a record wrapper
`Found | :nothing`. Refused with "absorbed by" — `option<atom>`, `option<term>`, `result<term,
atom>`, `result<(atom, binary), binary>`, `option<option<int>>`.

**P2/P2b — the hole.**

```csharp
public option<T> Wrap<T>(T x, bool keep)
Wrap(x, true) -> x
Wrap(_, false) -> :nothing

public bool PresentIfKept(term x)
PresentIfKept(x) -> Check(Wrap(x, true))      // Check(:nothing) -> false; Check(_) -> true
```

`bsc H PresentIfKept ":nothing"` → `:false`; `bsc H PresentIfKept "5"` → `:true`. A value the
author explicitly kept (`keep = true`) reads as absent. No diagnostic anywhere; `--api` prints
`option<T> Wrap<T>(T, bool)`.

**P3 — what the collapse costs in meaning** (Erlang, executed). With `M = #{present => nothing}`:

| lookup | key present, value `nothing` | key absent |
|---|---|---|
| bare + sentinel (`maps:get(K, M, nothing)`) | `nothing` | `nothing` — **identical** |
| tagged (`maps:find`) | `{ok,nothing}` | `absent` |

**P4 — what the tag costs** (`erts_debug:flat_size`; compiled bench, 5M iterations, median of 11,
two runs):

| | bare | tagged |
|---|---|---|
| heap words for a hit on an int | 0 | 3 |
| heap words added to a small map value | 0 | 3 |
| lookup, key present | 3.30 / 3.48 ns | 17.12 / 17.83 ns |
| lookup, key absent | 2.32 / 2.46 ns | 11.83 / 12.05 ns |

The lookup rows compare the two things the designs would lower to — `maps:get/3`, a BIF that
allocates nothing, against `maps:find/2`, which allocates the tuple — so they price the tag as
implemented, not a floor. About 9–14 ns per lookup.

**P7 — the tagged type already exists in user-land.** `type Maybe<T> = (:some, T) | :nothing` compiles
today, instantiates at `term` and at `int`, and `Or((:some, :nothing), :dflt)` returns `:nothing`
(present) while `Or(:nothing, :dflt)` returns `:dflt` (absent) — the distinction P3 shows bare
lookups losing. So an author who wants this has it now, generically, in six lines.

**P5 — what tagging `option<T>` itself would touch.** 22 `option<` sites in 10 example `.bs` files,
20 `:nothing` sites, 52 `option<` lines in `compiler/test/*.erl`.

## Neighbours

| | absence | evidence |
|---|---|---|
| Gleam 1.19.0 | **always tagged**: `Some(5)` → `{some,5}`, `None` → `none`, and `Some(None)` → `{some,none}` so nesting survives; `Ok(5)` → `{ok,5}` | `probes/64/gl`, run |
| Elixir 1.18.5 | `Map.fetch/2` tagged, `{:ok, v} \| :error` (`elixir/lib/elixir/lib/map.ex:299`, `= :maps.find(key, map)`); `Map.get/3` bare with default `nil` (`map.ex:526`) | run: `Map.fetch(%{a: nil}, :a)` → `{:ok, nil}`; `Map.get(%{a: nil}, :a)` → `nil`, same as absent |
| Erlang | both: `maps:find/2 -> {ok, V} \| error` (`maps.erl:138`), `maps:get/3` bare with a default (`maps.erl:686`) | — |
| Elm | `Maybe` is tagged | **not run** — registry unreachable from the sandbox |

Every neighbour that has a bare lookup ships a tagged one beside it, and the bare one is where the
`nil`/`nothing` ambiguity of P3 lives. None of them makes the bare form the only form.

## Options

The question is one: what does `Map.Get(map<string, term>, k)` return (ENG-324, unbuilt). Each
option is a program and the compiler work it implies.

### A — lookups return a tagged success; `option<T>` stays bare (what ticket 48 Q8 already leans to)

```csharp
public term OrAnon((:ok, term) | :absent r)       // compiles today (clause heads, verified)
OrAnon((:ok, v)) -> v
OrAnon(:absent)  -> "anonymous"
// Map.Get(m, "name") would feed it once ENG-324 is built
```

Compiler delta: `Map.Get`'s signature is `(:ok, V) | :absent` for **every** `V` (so it never
collapses and `option<int>` callers are untouched). No prelude change. **Plus the P2b fix**, which
every option needs: run the absorbed-member predicate at each generic instantiation, not only at
declarations.

**Strongest counterargument.** Two idioms for one idea — `option<int>` is bare, a lookup is
tagged — and the repo's own rule ("absence carries nothing, failure carries a reason", `STANDARD-
ENVIRONMENT.md`) says the bare form is `option`'s whole point. Authors will write `option<V>` for
their own functions at `V = term` and be sent to hand-roll a tag the compiler has already printed.

### B — name the hint: a prelude type for the case the compiler already refuses

```csharp
type Maybe<T> = (:some, T) | :nothing            // compiles today (P7); B makes it the prelude's
public Maybe<term> Find(map<string, term> m, string k)
```

Compiler delta: one prelude row (stratum 1) so that nobody re-declares it per module; the
absorbed-member diagnostic's `hint:` line names it instead of printing the raw union; the same
instantiation check as A. `Map.Get` may then return it, or stay as in A. Note the prelude's own
`option`/`result` are lowercase and a user alias must be capitalised (`type maybe<T>` is a syntax
error: `syntax error before: 'maybe'`), so the name has to be chosen across that line.

**Strongest counterargument.** It is a second spelling of absence in the prelude itself, bought to
save an author six lines (P7) and to give a diagnostic hint a name it already prints in full. If
the hint works as text, the prelude row is the only thing B adds, and it adds a name David has to
choose across the lowercase/uppercase line.

### C — tag `option<T>` itself

```csharp
type option<T> = (:some, T) | :nothing
```

Not built. Dominated on the measurements: it touches the 22 + 20 + 52 sites of P5, adds 3 heap
words to every present `option<int>` that is an immediate today (P4), and changes the wire shape of
every `option<…>` a caller outside B# sees. The ticket's own "Notes" warn against it for the first
reason; P3 and P4 supply the other two.

## Recommendation

**A, plus the instantiation check — the check is the real defect, and it is independent of the
choice.** P2b is a silent wrong answer in a program that compiles clean, in a feature whose whole
promise (68 Q1) is that this cannot happen. Take B only if a second prelude function wants the same
shape; until then the printed hint is already the name.

If David wants a one-line decision for this ticket: *"`Map.Get` is tagged; `option<T>` is refused at
an absorbing `T` whether written or inferred."*

## Reproduce

```
export BSC=compiler/_build/default/bin/bsc
artifacts/probes/64/run.sh      # P1 matrix, full diagnostic, P2 generic, P2b run, P3, P4, P4b, P5, P6
# bench64.erl is compiled by run.sh; gl/ is the Gleam option probe
```

## Verifier result

(filled in below by the independent re-run)
