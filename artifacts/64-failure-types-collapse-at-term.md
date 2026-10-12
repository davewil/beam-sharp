# Decision brief: ticket 64, ENG-254. What does `Map.?Get` return at `map<string, term>`?

**DRAFT FOR HUMAN REVIEW. Ticket remains open.** Not resolved, no ticket or Linear edit, nothing committed.
Measured at `git HEAD 019533d` with the `bsc` in `compiler/_build` (built 2026-10-12). The ticket is dated 2026-08-25 and was narrowed 2026-09-06.
All probes are under `artifacts/probes/64/NN/` (`run.sh` plus `out.txt` from a real run). OTP 28, Elixir 1.18.5, Gleam 1.19.0, Elm 0.19.2.

## 1. What the ticket bundles, and what the gate is

| Sub-decision | State |
|---|---|
| Q1, Q4: is the collapse a defect, one rule or two? | Answered by ticket 68 (`M ⊆ union(others)` is refused where written). Not reopened. |
| **Q3: does the reasoning reach `result<T, E>` at `E = term`?** | **Measured here, answered below.** The question is mis-aimed: see §2. |
| **Q2: what does the author reach for at `map<string, term>`?** | **Open. This is the gating design question.** |
| (new) the refusal does not see an instantiation through a type variable | Found by probe 02. Needed under every option except C. Independent of Q2. |
| (new) a second site: an optional *key* holding any term | Found by probe 16. Follows from Q2 only if C is chosen. |

Ticket 108 fixed the non-crashing form as `Map.?Get`, `List.?First`, `?Find`, `?Max` and so on, returning `option<T>`. Ticket 96 owes all of them. Every one of those rows is refused at `T = term`, so Q2 is a decision about the whole `?` family, not about maps.

**The gating question, alone.** The author has a `map<string, term>` (assigns, a `jsonb` document, headers: ticket 48's three cases). Which of these programs should compile?

```csharp
public string Who(map<string, term> a)
Who(a) -> Map.?Get(a, "user") switch {
    :nothing => "anonymous",        // today: Map has no operation Get at all (probe 12 A)
    u        => Name(u)             // and option<term> is `term`, so this arm would catch everything
}
```

## 2. What the current compiler does (probes 01, 02, 03, 11, 12)

Run in `out.txt`, summarised:

| Declared | bsc now |
|---|---|
| `option<int>` | `:nothing \| int`, accepted |
| `option<term>`, `type M = option<term>`, `list<option<term>>`, `(option<term>, int)`, a record field, a map value | **refused** at the declaration: "`:nothing` is absorbed by `term`" (01 B, I; 03 R1-R3, R7) |
| `result<term, atom>`, `result<term, term>`, `result<term, binary>` | **refused** (01 C, E, G) |
| `result<int, term>`, `result<atom, term>` | **accepted**, `int \| (:error, term)` (01 D, F) |
| hand-rolled `(:ok, term) \| :absent`, `(:some, term) \| :nothing` | accepted, and `Maybe<term>` by a parametric alias too (01 H; 03 R8, R9) |
| `ValidateAs<term>` | refused (`result<term, ValidationError>`), 03 R5 |
| `Map.Get(m, k)` | "`Map` has no operation of that name": still unbuilt (12 A) |

**Q3 answered.** The collapse is on the *success* side. `result<T, E>` collapses when `T ⊇ (:error, E)`, so `T = term` collapses at every `E`. `E = term` is harmless: `(:error, term)` is a tuple and `int` does not contain it. The question should read "`result<T, E>` at `T = term`", and the answer is yes, already refused by the same predicate (`absorbed/2`, `bs_check.erl:3282`).

### Falsified or stale against the ticket
1. **"The loudness is settled" is false for generic code.** F31 and ticket 68 check only *written* members. `option<T>` instantiated at `term` through a type variable is silently collapsed (probe 02):
   ```
   public option<T> Head<T>(list<T> xs) ...      public term AtTerm(list<term> xs)
   AtTerm []          -> :nothing                AtTerm(xs) -> Head(xs)     // compiles, exit 0
   AtTerm [:nothing]  -> :nothing                // same value for "empty" and "holds :nothing"
   ```
   Same for `atom`. `bsc --api` prints `term AtTerm(list<term>)`. The refusal is at the declaration with `T` opaque (`opaque_env`, F45), and `call/6` never re-checks the instantiated return.
2. **"Leaves the author with nothing to reach for" is partly stale.** A user-declared `type Maybe<T> = (:some, T) | :nothing` already works at `term`: generic, nests (`Maybe<Maybe<int>>`), and a `switch` missing the `:nothing` arm is refused (probe 04). Exemplar 25g (whose header says it does not parse today; probe 12 B is the running evidence) looks up a `map<term, term>` through the tagged foreign signature `(:ok, term) | :error find(...)` (`triage_index.bs:38-43`); probe 12 B runs it and tells `:present_and_is_nothing` from `:absent`. What is missing is a *standard* operation that returns it.
3. **Not re-run verbatim:** the ticket's four-signature table. Its source program is not in the repo, so probe 01 rebuilds each row. `FindI` and `FindF` give the shapes the ticket printed; `FindR` and `FindT` no longer print as `term` because F31 now refuses them. Prototype `48l` re-runs unmodified and its verdicts all hold (probe 11).

## 3. The cost of tagging, measured (probes 05, 06, 07, 14, 15)

- **Heap, words** (`erts_debug:flat_size`, 8-byte words): `{ok,V}` and `{some,V}` cost **+3 words for every V** (small int 0 to 3, 3-element list 6 to 9, 3-key map 10 to 13). `term_to_binary` grows by 6 or 8 bytes. A failure atom costs 0. 1000 present small-int options in a list: 2000 words bare, 5000 tagged (05).
- **Time, representation only** (06): lookup loop, 3M lookups, 9 runs, inline map match. Bare vs tagged, small int, 100% hit: min 45280 vs 44983 us, median 47658 vs 46872. 50% hit and 3-list values: within about 3% in this run, but the verifier's four re-runs of the 100%-hit case gave +1%, +8%, +6%, +8% on min and 3-list values reached +7% — read it as single-digit percent, noisy. The tagged run did 2160 minor GCs against 0 in the bare run: the cost is allocation, not speed.
- **Time, B# end to end** (07): the same 20-element assoc-list lookup as `option<int>` and as `Maybe<int>`, compiled by real `bsc`: `.beam` 2096 vs 2136 bytes; 2M iterations min 89546 vs 91367 us (about 2%), median 104594 vs 110802 (about 6%). Compile wall time is noise (min 491 vs 375 ms). The emitted `Find` differs only in `V` vs `{some, V}`.
- **Time, which BIF** (14, caution): `maps:find` is 2.5x slower than `maps:get/3` (71377 vs 27286 us min) because it is a BIF call, not because of the tuple. `is_key` + `get` (two lookups) is 77528 min, about 9% over `find`. What `Map.Get` will emit is unbuilt, so none of this predicts it.
- **Repo's own programs** (15): no `.bs` file writes `option<term>` or `result<term`. The 3 AoC programs use no `option`/`result`. Exemplars and examples: 10 files spell `option<`, 7 files and 19 lines spell `:nothing`. Allocation cost of always-tagging today's exemplars is not computed (the option values are rare and small; no number claimed).

## 4. Neighbours (probes 08, 09, 10)

| Language | Behaviour | Evidence |
|---|---|---|
| Erlang | `maps:find` is tagged (`maps.erl:138`); `maps:get/3` takes a default (`:686`); `proplists:get_value/2` defaults to `undefined` (`proplists.erl:202,208`) and cannot tell `[{a,undefined}]` from `[]`; `proplists:lookup` (`:140`) and `lists:keyfind` (`:115`) are tagged | run, 08 |
| Elixir | `Map.fetch` tagged (`map.ex:298`), `Map.get(m,k,nil)` ambiguous (`:525-526`), `Keyword.get` likewise (`keyword.ex:394`). `Map.get(%{a: nil}, :a) == Map.get(%{}, :a)` is `true`. 1.18.5's own `Descr`: `term() \| nil == term()` is `true`, `{:ok, term()} \| :error` survives | run, 08 |
| Gleam | `dict.get -> Result(v, Nil)` (stdlib v0.62.0 `dict.gleam:150`), `list.first` likewise (`list.gleam:230`), `Option` is `Some(a) \| None` (`option.gleam:19`). **Always tagged**; `Ok(None)` vs `Error(Nil)` are distinct; `Some(None)` nests. On the BEAM: `{ok,none}` vs `{error,nil}`; `{ok,{some,1}}` is 6 words vs `{ok,1}` 3 | run, 09 (stdlib source cloned from github; hex is blocked) |
| Elm | `Dict.get : comparable -> Dict comparable v -> Maybe v` (`Dict.elm:94`), `type Maybe a = Just a \| Nothing`. Always tagged | **source-cited only.** `elm make` could not run: it needs package.elm-lang.org, which the proxy refuses (403). Recorded in 10 |
| C#, F# | knowledge only: C# `TryGetValue(out v)` returns a bool beside the value, so the ambiguity cannot arise; F# `Map.tryFind` returns `'T option`, a DU, so it nests | not probed |

Reading: the languages that have an untagged "absent" (`undefined`, `nil`) have the ambiguity and bolt a tagged twin beside it. Elixir and Erlang ship *both* forms. The languages that always tag have no collapse. None has B#'s trick of a *bare* success inside a union.

## 5. Options (each is B# code plus the compiler delta)

### A. Tag only the standard operations, and only where `:nothing` would be absorbed

```csharp
Who(a) -> Map.?Get(a, "user") switch {          // a : map<string, term>
    (:some, u) => Name(u),
    :nothing   => "anonymous"
}
Who(s) -> Map.?Get(s, "user") switch {          // s : map<string, string>: unchanged, bare
    :nothing => "anonymous",
    u        => u
}
```
**Delta.** `reserved_sig/4` already receives the call site's argument types (`bs_check.erl:1723`, `Reverse` uses `[ATy]`). Add: if `absorbed(:nothing, V)`, the signature returns `(:some, V) | :nothing`, else `V | :nothing`. The emitter wraps `maps:find`'s `{ok,V}` as `{some,V}` (one `case` per call). Rows: 1 new clause per `?` op, no prelude change. Cost: +3 words per hit at `term` only.
**Strongest counterargument.** The shape depends on `V`, so no user function can say it. Generic code is emitted once (probe 02's `Head` has one body returning bare `X`), so a wrapper `option<V> MyGet<V>(map<string,V> m, ...)` instantiated at `term` returns the wrong representation. A is therefore only sound together with the instantiation check of §6, and even then the author cannot write the wrapper at `term`. Changing `V` from `string` to `term` also changes the `switch` arms.

### B. Operation pair, no new type: `Map.Has` plus `Map.Get`

```csharp
Who(a) -> Map.Has(a, "user") switch {
    true  => Name(Map.Get(a, "user")),          // Get raises on a missing key (F34); 96 Q3's plain name
    false => "anonymous"
}
// and the escape that already compiles today (probe 04, 12 B):
type Maybe<T> = (:some, T) | :nothing
```
**Delta.** One row, `Map.Has` (`maps:is_key`, already listed in ticket 96's `Map` row) beside the owed `Map.Get`; the refusal diagnostic for `option<term>` gets a hint naming `Has`/`Get` and `Maybe<T>`. No change to 15 §1, 68, 108 or any representation. Cost: a second lookup, about +9% over `maps:find` (14).
**Strongest counterargument.** It is the least pleasant at the one call site everyone writes first, and two lookups is wasted work. It does not generalise: `List.?Find(xs, pred)` has no `Has` twin that avoids running the predicate twice, and `List.?Max` needs an emptiness test the author may forget (the raising `Max` makes forgetting loud).

### C. Always tag: `type option<T> = (:some, T) | :nothing` (Gleam and Elm's shape)

```csharp
Who(a) -> Map.?Get(a, "user") switch {          // the SAME text at every V
    (:some, u) => Name(u),
    :nothing   => "anonymous"
}
```
**Delta.** The prelude entry in `stratum_one/0` changes (`bs_check.erl:1338`); `failure_channel({t_atom, nothing})` (`:1208`) stops firing for `option`. Every producer and consumer of a bare success changes: `as T` (ticket 08), F61's absent-key fill (the decoder would also have to wrap *present* values as `(:some, v)`), F72, 41 of 73 test files mention `nothing` (210 lines), `LANGUAGE.md` 31 lines, `TOUR.md` 9 (probe 15). Runtime: +3 words per present option (05), single-digit percent in time, noisy (06, 07; verification/64.md).
**Strongest counterargument.** Ticket 15 §1 rejected exactly this, and its reason is still true: the cost lands on narrowing, which is the language's showcase (`d as int` reads `int | :nothing`). It also does nothing for `result<term, E>`, which stays refused. The ticket's own Notes warn against buying `option<term>` with a more awkward `option<int>`. 78 compiled programs contain zero occurrences of `option<term>`, but see §7.3: that zero is produced by the refusal itself.

(A dedicated prelude `maybe<T>` is C's representation under a second name. It costs one declared-entry line, but then there are two absence types and the author must choose, which is the tax 15 §2 was written to avoid. Probe 04 shows the author can already declare it.)

## 6. Independent of Q2: close the instantiation hole

Whatever Q2 gives, `option<T>` at `T = term` through a variable must be as loud as the written form (except under C, where it disappears for `option`). A prototype, `probes/64/13/inst_collapse.patch`, 24 lines in `call/6` at `bs_check.erl:4282` plus one forwarding clause in `bs_diag.erl`, runs the existing `absorbed/2` per template member after `solution/2`. It works because `subst_tpl` keeps union members apart until substitution. Result (13): the stock compiler accepts `AtTerm` and `AtAtom`; the patched one refuses both at the call line with the existing sentence and leaves `AtInt` alone. **It has no test, no gate and no self-test**, so it is evidence of feasibility, not a feature. The patched eunit run in a full-repo copy passed: all 1448 tests (verification/64.md).

## 7. Recommendation

**Take B now, plus §6, and keep C as the measured fallback. Do not take A.**

1. B changes no decided ticket (15 §1, 68, 108, 96, 48 Q8 all stand) and gives the author a program that compiles today at `map<string, term>`: `Has` plus `Get`, or the `Maybe<T>` alias, or the tagged foreign `find` that exemplar 25g already uses.
2. A reads best, but its shape depends on `V`, which no generic wrapper can express, and it is unsound without §6. It adds a second spelling of the same operation, which is the surprise the standing constraint forbids.
3. C has the cleanest semantics and the runtime price is small (3 words, single-digit percent in time), but the price is paid in spec, tests and decoder shape, and the repo has zero programs using `option<term>` — but that zero is produced by the compiler refusing the spelling; the exemplar prototypes did write it and hit the wall (`wayfinder/prototypes/32e-ffi-on-the-page.md:29,58`, `25d-database-querying.md:148,402,509`, `wayfinder/issues/25-exemplar-programs.md:521`), which is demand evidence for C or A. It becomes the right answer if the optional-key case below turns up in a real exemplar.
4. The one thing B does not serve is the wire case (probe 16): "key may be absent, value is any term, returned as-is". `option<term>` is refused. `(:some, term) | :nothing` makes an absent key `:nothing` (F61 reads any type admitting `:nothing`), but a *present* key must then arrive pre-wrapped (`"extra" = (:some, 7)`), which JSON does not. Only C, or an F61 rule that wraps, spells it. That is a new finding for ticket 78's reader, not a 64 decision.

If David wants A's readability, the question to ask is "may the shape of a standard op's result depend on the value type?", and the answer needs §6 first.

## 8. Not decided, not measured

- Not decided: the name of a `Has` (96 lists `Map.Has`; spelling is 96's row ticket), whether a prelude `maybe<T>` ships, whether F61 should wrap present values.
- Not measured: what `Map.Get` / `Map.?Get` will emit (unbuilt, ENG-324), so no end-to-end lookup cost for A or B; wire-decode cost under C; the allocation cost of C over the exemplars (counts only); Elm by execution; Elixir's inference-warning output for `Map.get` (only `Descr` was run); C# and F# are knowledge only.
- The §6 prototype's effect on the full eunit suite: the author's run was cut short (694 passed, 1 copy artefact); the verifier's complete run in a whole-repo copy passed all 1448 tests. `verify.sh` was not run. The prototype still has no test or gate of its own.

## Probe index

| Probe | Claim checked | Result |
|---|---|---|
| `01` | the four signatures plus six more, against current bsc | `option<term>` and `result<term, E>` refused; `result<T, term>` survives; tagged forms accepted |
| `02` | `option<T>` instantiated at `term`/`atom` via a type variable | **silently collapsed**, `Head([])` equals `Head([:nothing])`; one erased body |
| `03` | which positions the refusal reaches | field, tuple, list, map value, wire key all refused; `ValidateAs<option<term>>` accepted by `--api` only — a full compile refuses it (verification/64.md); `Maybe<term>` fine |
| `04` | a user `Maybe<T>` works at `term` | generic, nests, exhaustive; absent vs present-`:nothing` told apart at run time |
| `05` | words and bytes for `V`, `{ok,V}`, `{some,V}` | +3 words for every V; +6 or +8 bytes serialised |
| `06` | lookup loop, bare vs tagged, 9 runs | within 3% in time; 2160 minor GCs vs 0 |
| `07` | same lookup in real B#, `.beam` size, compile time, run time | 2096 vs 2136 bytes; run about 2% (min), 6% (median); compile noise |
| `08` | Erlang and Elixir tagged/default lookups, sources and runs | ambiguity reproduced; `Descr` `term() \| nil` collapses |
| `09` | Gleam always tags | `Ok(None)` vs `Error(Nil)` distinct; BEAM shape `{ok,none}` |
| `10` | Elm | source cited; `elm make` blocked (403), not run |
| `11` | ticket's own prototype 48l, unmodified | all verdict lines hold at HEAD |
| `12` | what an author can write today at `map<string, term>` | `Map.Get` unbuilt; tagged foreign `find` works and discriminates |
| `13` | prototype closing the instantiation hole | stock accepts, patched refuses `AtTerm`/`AtAtom`, accepts `AtInt` |
| `14` | cost of `find` vs `is_key`+`get` vs `get/3` | `find` 2.5x slower than `get/3` (BIF); pair about +9% over `find` |
| `15` | blast radius of always-tagging, by count | 10 `.bs` files, 41 test files, 3 documents; 0 uses of `option<term>` |
| `16` | the optional-key-holding-any-term wire case | no spelling; a tagged field forces pre-wrapped input |
