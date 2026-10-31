# Decision brief: ticket 64 (ENG-254), Q2 and Q3

Status of this document: a brief for a human. It resolves nothing, edits no ticket, touches no Linear.
Written 2026-10-30. Everything under `probes/` was run in this session; the commands and captured
`.out` files are beside the probes.

**Environment limits, stated first.** Installed: Erlang/OTP 25, Elixir 1.14.0, dialyzer. Not
installed: `bsc` (needs OTP 27+ leex), gleam, elm. So **no B# snippet below was compiled**. Every
"compiles" / "refused" verdict on B# is read off the F31/F36 scenario tables and the ticket text
(INHERITED), not re-executed. The measurements are about the BEAM terms and Erlang/Elixir
behaviour the lowerings would produce, plus one set-theoretic cross-check on a third algebra
(`erl_types`).

## 0. What the grep found (before any option)

Ticket 64's body says the author is left "with nothing to reach for". Grepping the tickets and
features shows the position is sharper than that, and the sharpness is the real question:

1. **The decided lookup surface already collides with the refusal.** Ticket 108 (resolved
   2026-09-25) decided `Map.Get` crashes on a missing key and `Map.?Get` "returns `:nothing`",
   "Return types unchanged: `option<T>` for a lookup". Ticket 96's table (line 224) also lists
   `Map.Find -> option<V>` (`maps:find`), and ticket 98:71 already writes
   `Agent.Get(a, m => Map.Find(m, k))`. F36 S5 refuses `option<term>`. So **at
   `map<string, term>` (the shape of all three of ticket 48's cases) the decided `Map.?Get` has no
   legal return type.** Nothing in `wayfinder/issues/` says what the row does there (grepped for
   `GetOr`, `OrDefault`, `Map.Find`, `ENG-254`, `64-failure`; the only hits are above and 68 Q4).
   Not built yet: ENG-324.
2. **The same wall stands in front of every ticket-96 Q3 pair at `T = term`:** `List.?First`,
   `?Last`, `?At`, `?Max`, `?Min`, `?Find` (96:99, 108:155). Lists differ from maps in one way
   that matters: a list has head patterns (`[h, ..t]`), so absence of a first element is
   expressible without any option type. A map with an open key domain has no pattern form
   (ticket 48 Q3, F33), so lookup is the only way in. That is why the problem is a *map* problem.
   (INHERITED from 48 and 48l; not re-executed.)
3. **`Map.Has` is already built** (F75 row `bool Has(map<term, term> m, term k)`, `maps:is_key`;
   `bs_check.erl:1763` lists it in `sought_row`). `Map.Get`, the crashing half, is decided and
   unbuilt. So "Has then Get" needs no new row once ENG-324 lands.
4. **Q3 has a wrong premise in its wording.** Ticket 64 Q3 asks about `result<T, E>` "at
   `E = term`". The collapse occurs at `T = term` (the *success* slot), not `E = term`. Section 4
   answers both readings.
5. **A hole to measure, not assume.** F31 says a parametric alias's unbound `T` reaching the
   absorption check "has not been measured" (F31 amendment, 2026-10-08), and `absorbed_member` is
   raised from `each_member/5` on *written* declarations (`bs_check.erl:1202-1216`), with a second
   site at the `ValidateAs` obligation (`bs_check.erl:3265`, `3410`). I did not find a call-site
   instantiation check for a *row* whose declared return is `option<V>` solved to `V = term`
   (reading source only; `bsc` unavailable). If none exists, `Map.?Get` at `V = term` would
   silently re-collapse, i.e. regress F31. UNPROBED; first thing to measure once `bsc` runs.

## 1. The gating question, asked alone

> When `Map.?Get` (and the other `?` pairs) is called at a `T` where `T | :nothing` is `T`, what
> does the author get?

Not asked here, because it follows: whether `option<T>` itself changes (ticket 64's Notes forbid it
without cause, and the evidence below gives none), and what `ValidateAs` and `ToExistingAtom`
do (already answered by 15 §1 / ticket 67 / F54).

Three candidate answers, each a program that compiles under it and one refused. Two further
shapes were considered and cut; see section 5.

## 2. Options

### Option A: refuse, and the way through is `Map.Has` then `Map.Get`

The `?` form is **refused at an absorbing `T`** (F36 already produces this), and the diagnostic's
hint names the two-call form. No tagged type enters the language.

```csharp
module Req.Headers

// compiles: the author asks the question the lookup cannot answer, first.
public string ContentType(map<string, term> hs)
ContentType(hs) -> Map.Has(hs, "content-type") switch {
    :true  => ValidateAs<string>(Map.Get(hs, "content-type")) switch {
                  (:error, _) => "application/octet-stream",
                  s           => s },
    :false => "application/octet-stream"
}

// compiles: option<string> does not collapse, so the ? form is fine where V is concrete.
public option<string> Token(map<string, string> m)
Token(m) -> Map.?Get(m, "token")
```

```csharp
// REFUSED (absorbed member, F36 S5): the value type absorbs :nothing
public option<term> Raw(map<string, term> m)
Raw(m) -> Map.?Get(m, "k")
//   error: Map.?Get returns option<term>, which is term; :nothing is absorbed by term
//   hint: test with Map.Has(m, k), then Map.Get(m, k)
```

**Compiler must gain.**
- ENG-324 builds `Map.Get` and `Map.?Get` as already decided; **no extra row.**
- One new hint variant on the existing absorption tag (68 Q3 already says the failure-channel
  wording survives "as a third hint variant"; this is a fourth, keyed on the *call* rather than the
  declaration). Concretely: in `bs_diag.erl` the `absorbed_member` builder gains a clause for a
  row-return origin that names `Map.Has`/`Map.Get`.
- **The check at the row call site** (section 0 item 5): after `V` is solved, run
  `absorbed(nothing, V)` on the rewritten return. A symbol-table-free change: it reuses
  `absorbed/2` (`bs_check.erl:3415`), the one predicate.
- Optionally `Map.GetOr(m, k, default)`: one row `V GetOr<K,V>(map<K,V> m, K k, V default)`
  lowering to `maps:get/3`. See "limits" below on why a *sentinel* default re-creates the problem.

**Measured evidence.**
- `probes/p5_hazard.out`: over a `map<binary, term>` holding `retry => nothing`,
  `upstream => {error, timeout}` and a typo'd key, an untagged lookup misreads 1 present key as
  absent (`<<"retry">>`), an untagged result misreads 1 present value as a failure
  (`<<"upstream">>`), while **Has+Get and the tagged form misread zero**. So Has+Get is *correct*,
  which is all A needs.
- `probes/p8_lookup_cost.out`: `is_key` then `get` costs 1.47x `maps:find` on a hit in a 100000-key
  map (7 reps, median; the VM is shared and noisy; an outlier is visible in the file), i.e. two
  hash probes instead of one. On a miss the two idioms are within noise.
- `probes/p1_erlang_lookup_shapes.out` and `p2_elixir_lookup_shapes.out`: `Map.has_key?` / `maps:is_key`
  separate absent from stored-`nil` in every row; this is the escape Elixir itself offers beside
  `Map.get/3`.

**STRONGEST COUNTERARGUMENT.** It answers "nothing to reach for" with "two calls and a crash
form", and the second call is the *crashing* `Map.Get` on `term`, so the author trades a type the
checker can see for a convention (`Has` before `Get`) the checker cannot enforce: nothing stops
`Map.Get(hs, k)` without the `Has`, which crashes at run time on the exact typo ticket 48l §1 is
worried about. The tagged forms in B and C put the absent branch in a type; A puts it in
discipline. It also pays a second hash probe (1.47x on a large-map hit).

### Option B: a tagged sibling row, because the author needs a type the checker can see

`option<T>` and the `?` pairs are untouched. The map gets one more compiler-known row whose result is
the tagged shape ticket 48 Q6 already named and F31 S10 already pins as legal. (The name `Fetch` is
a placeholder borrowed from Elixir's `Map.fetch/2`; naming is not part of this brief.)

```csharp
module Req.Headers

public string ContentType(map<string, term> hs)
ContentType(hs) -> Map.Fetch(hs, "content-type") switch {
    (:ok, v) => ValidateAs<string>(v) switch { (:error, _) => "application/octet-stream", s => s },
    :absent  => "application/octet-stream"
}
```

```csharp
// REFUSED (exhaustiveness, existing machinery): the :absent arm is the checker's to demand
public string Bad(map<string, term> hs)
Bad(hs) -> Map.Fetch(hs, "k") switch { (:ok, v) => "found" }
//   Bad is not exhaustive; no clause matches: :absent
```

**Compiler must gain.**
- One row in `bs_check:declared_rows/0` (F75's `{Key, Target, Order, Signature}`), signature
  written as B# source: `(:ok, V) | :absent Fetch<K, V>(map<K, V> m, K k)`. F31 S10 is exactly this
  type and is a pinned accept, so no change to the absorption pass.
- A lowering. `maps:find/2` returns `{ok, V} | error`, so either the row is `generated` (F75 has
  two: `List.Insert`, `Term.Compare`) as `case maps:find(K, M) of {ok, _} = R -> R; error -> absent end`,
  or the absence atom is spelled `:error` and the row is a bare `maps:find`. The second is free to
  lower but names absence `:error`, against 15 §2's "absence carries nothing, failure carries a
  reason" and next to a `(:error, E)` failure member. That choice is a naming question for
  the human; flagged, not made.
- Nothing in the diagnostics: S10 is already accepted and exhaustiveness is already enforced.

**Measured evidence.**
- `probes/p4_dialyzer.out` + `p4_check.out`: Dialyzer **sees through** `-spec f() -> {ok, term()} | absent`
  (flags the dead clause `{error, _}` in `use_tagged`), and gets **nothing** from
  `-spec f() -> term() | nothing` (zero warnings in `use_untagged`; the spec is `any()`). The
  emitted-spec story (ticket 13) is therefore better under B than under any collapsed form.
- `probes/p3_absorption_algebra.out`: `(:ok, term) | :absent` has `absorbed=false`; same for
  `result<int, term>`. (`erl_types`, not B#'s algebra; see section 6.)
- `probes/p6_term_cost.out`: the wrapper costs a flat **3 heap words on a hit** for every V
  measured (atom, int, 5-byte binary, 100-byte binary, 5-element list, nested map; the nested
  map's 28 words become 31), identical for `{ok,V}` and `{some,V}`, plus 7 bytes of external
  term format. A miss allocates nothing (the absence is an immediate atom).
- `probes/p7_code_cost.out`: at 20 call sites, matching the tagged result adds **one instruction
  per site** (`get_tuple_element`; 205 vs 225 instructions in `run/1`) and 144 bytes of beam (1912 vs
  2056). The timing line in that file shows ratio 1.12 but the tagged module's lookup helper also
  re-wraps the result, and the five repetitions overlap; **treat the timing as inconclusive**.

**STRONGEST COUNTERARGUMENT.** It is a second spelling of "maybe absent" (`option<T>` and the
tagged form), so the prelude would have two answers to one question and an author will have to
pick, which is the "two spellings with no rule" hole 15 §2 closed. The rule can be stated
(`?` pairs for concrete value types, `Fetch` when the value may be `term`), but it is a rule an author
learns only by hitting the F36 refusal, and ticket 64's own Notes warn against treating this
shape "as the answer: it is one call site choosing a type that happens not to collapse". B also
does not help `List.?First` & co. at `list<term>`.

### Option C: the `?` form tags itself, only where it must

`Map.?Get` (and the other `?` rows) return `V | :nothing` when that survives and
`(:some, V) | :nothing` when `:nothing` is absorbed by `V`. This is 15 §1's own hint
("tag it: `(:some, atom) | :nothing`") promoted from advice to a rule of the row.

```csharp
public string ContentType(map<string, term> hs)
ContentType(hs) -> Map.?Get(hs, "content-type") switch {
    (:some, v) => ValidateAs<string>(v) switch { (:error, _) => "application/octet-stream", s => s },
    :nothing   => "application/octet-stream"
}

public string Name(map<string, string> m)       // same row, untagged because string survives
Name(m) -> Map.?Get(m, "name") switch { :nothing => "anon", s => s }
```

```csharp
// REFUSED: a generic caller cannot write the arm, because the return shape depends on T
public T Pick<T>(map<string, T> m, T dflt)
Pick(m, d) -> Map.?Get(m, "k") switch { :nothing => d, v => v }
//   error: the shape of Map.?Get(m, "k") depends on T (untagged unless :nothing is absorbed)
```

**Compiler must gain.**
- In the row-return rewrite (F45: "the return is rewritten with the solution"), a conditional:
  after solving `V`, if `absorbed(:nothing, V)` then the return type is `(:some, V) | :nothing`.
- **The emitter must lower per instantiation**: `maps:get(K, M, nothing)` for the survivors,
  `case maps:find(K, M) of {ok,V} -> {some,V}; error -> nothing end` for the absorbed. So a
  second lowering path per `?` row (about 9 rows: `Map.?Get`, `Map.Find`, `List.?First/Last/At/Max/Min/Find`).
- A rule for unsolved `T` (generic code) because the refused example above must be decided one way
  or the other: refuse, or monomorphise. That is new machinery.
- The 15 §1 doc, `STANDARD-ENVIRONMENT.md` and `CONTEXT.md` (Failure channel) change meaning.

**Measured evidence.**
- `probes/p3_absorption_algebra.out`: a rule keyed on *"T is a cofinite atom top"* misses 4 of the 8 rows
  F31's predicate refuses (`option<option<int>>`, `result<(atom,binary),binary>`,
  `result<tuple,atom>`, `result<result<int,term>,term>`). So C must be keyed on `absorbed(nothing, V)`,
  not on `V` being `atom`/`term`. This is candidate (d), and it is **refuted as stated** (cofinite
  alone) by the probe and was already warned against in 15 §1 (INHERITED).
- `probes/p6_term_cost.out`, `p7_code_cost.out`: same wrapper cost as B, but paid only on the absorbed
  instantiations.

**STRONGEST COUNTERARGUMENT.** The representation of a *value* now depends on a type-level
predicate, so `option<T>` code that is correct for `T = int` is a compile error or a different term
shape at `T = term`: a program's behaviour changes when a type argument is widened from `string` to
`term`, which is precisely the silent-collapse surprise F31 exists to remove, relocated into the
run-time representation. It also makes `Map.?Get` the first row whose *result* constructor, not just
its type, varies per instantiation.

## 3. Recommendation

**A, with B held in reserve behind a measurement, not built now.** Reasons, in the order they weigh:

1. A adds no surface: it needs the F36 refusal (built), `Map.Has` (built), `Map.Get` (decided, ENG-324),
   and one hint variant. It does not make `option<int>` more awkward, which ticket 64's Notes name
   as the trade to avoid.
2. p5 shows A is *correct* (zero misreads), so the loss is checkability, not correctness. The
   cost is one extra hash probe on a hit (p8, 1.47x at 100k keys, noisy) and a convention the
   checker cannot enforce.
3. B is cheap to add later (one `generated` row; its type is already a pinned accept, F31 S10), so
   deferring it forecloses nothing. C is not cheap to add later or to remove.
4. The trigger for promoting B: an exemplar where the `Has`-then-`Get` pair is the *only* way to
   write a lookup at `term` and a real bug of the "forgot the Has" kind appears. This is the
   same standard 48l used for the map type.

If the human weighs "the checker must see absence" above "no second spelling", B is the answer and
A's `Has`/`Get` pair stays as the cheap form. Section 7 lists what that choice depends on.

## 4. Q3, answered explicitly

**Q3: does the same reasoning reach `result<T, E>` at `E = term`?**

- **At `E = term`: no, not by itself.** `result<int, term>` is `int | (:error, term)`; the failure
  member is a tagged tuple and `(:error, term)` is not a subset of `int`, so it survives
  (`probes/p3_absorption_algebra.out`: `result<int, term>` absorbed=false, `result<atom, term>`
  absorbed=false). This is also what 15 §2 says in its own table (INHERITED: `atom | (:error, binary)`
  survives; the payload "moves the failure member from absorbed to discriminable").
- **At `T = term` (the success slot): yes, identically.** `result<term, E>` is `term` for every E
  (p3: `result<term, binary>` and `result<term, term>` absorbed=true). F36 S7 already refuses it.
  This is the case ticket 64's own table calls COLLAPSED (`FindR(...) result<term, atom>`); the
  ticket's Q3 wording says `E` but means `T`.
- **The same rule reaches more than `term`.** `result<tuple, atom>` and
  `result<(atom,binary), binary>` absorb `(:error, E)` too (p3), and so does the nested
  `result<result<int, term>, term>`: the outer failure member `(:error, term)` is already inside the
  inner success type. The last is the one that matters for `E = term`: **the collapse shows up when
  `term` is used as `E` in a *nested* result, even though a single result is fine.**
- **Is there an expressiveness hole for `result` as there is for `option`?** Smaller. A
  `result<term, E>`-shaped lookup is spelled today with a tagged success, exactly as F31 S11 and 15 §2
  intend: `type Found<E> = (:ok, term) | (:error, E)` is the F31 S10/S11 shape (accept). The hole
  is therefore "no prelude spelling", not "no spelling", and the recommendation (A) does not need
  one: `Map.?Get` is an `option` row; no ticket-108 pair returns `result<term, E>` except the
  conversions (`result<T, string>`, concrete T) and `Await` (its own pair).
- Hazard evidence for the `result` side: `probes/p5_hazard.out`, key `upstream`: a legitimately
  stored `{error, timeout}` value is read as a failure by an untagged `result<term, atom>` lookup.
  That is the generalisation of `retry => nothing` to the tuple failure member, and it is the same
  rule (`M ⊆ union(others)`, ticket 68 Q1), not a second one.

## 5. Considered and cut

- **Tag `option<T>` itself** (`(:some, T) | :nothing` always). Ticket 64's Notes and 15 §1 reject it
  (cost falls on the narrowing showcase `as T`, ticket 08); this brief found no evidence against that
  reasoning. p6/p7 give the price it would add to *every* `option<int>`: 3 heap words per hit and one
  instruction per site.
- **Only a refusal and nothing else** (what F36 does now). That is the "leaves the author with
  nothing" half of the ticket; A is that plus the hint and the order of the two calls.

## 6. Limits of this evidence (candid)

- No B# program was compiled. `Map.?Get`, `Map.Get`, `Map.Fetch` are unbuilt; every B# verdict is
  read from F31 S1-S11, F36 and tickets 68/108.
- `erl_types` is Dialyzer's algebra. It is set-theoretic enough to evaluate `F ⊆ T` and it reproduces
  F31's S3/S4/S5/S6/S7/S8/S10 verdicts (all agree), but it is **not** B#'s `bs_types:is_subtype`,
  and **not** Elixir's `Descr` (1.14 has none; 15's table used Elixir 1.19.5). A disagreement on a
  row I did not list is possible. `bs_types` cannot be run here.
- p7's timing is inconclusive: shared VM, five overlapping repetitions, and the tagged helper
  rewraps `maps:find`'s result. The instruction and byte counts are the usable numbers, and they
  come from `erlc -S` on OTP 25 output, not from B#'s emitter.
- p8's idiom comparison is also noisy (e.g. `small miss` for `maps:get/3` at 40 ms is an outlier). Only the
  large-map-hit ratio is asserted.
- p5's "untagged" lookups are hand-written Erlang that *simulate* what a B# emitter would produce if
  the collapse were allowed; they demonstrate the hazard, not B#'s actual output.
- Elixir `.ex` sources are not installed (only `ebin`), so Elixir claims cite behaviour (p2) and
  the beam docs chunk (p2b), not file:line.
- Did not compare per-call-site cost of Option C's second lowering path.

## 7. Claims table

| Claim | Evidence |
|---|---|
| `maps:get/3` with default `nothing` cannot tell absent from stored `nothing` | `probes/p1_erlang_lookup_shapes.out` (assert holds); source `/usr/lib/erlang/lib/stdlib-4.3.1.3/src/maps.erl:285-293` |
| `proplists:get_value/2` returns `undefined` for both absent and stored `undefined` | `p1` out; `proplists.erl:194-230` |
| `maps:find/2`, `dict:find/2` return `{ok,V} \| error` and separate absent from stored `nothing`/`error` | `p1` out; `maps.erl:60-63`, `dict.erl:139-142` |
| Elixir `Map.get/2`, `Access.get`, `Keyword.get` conflate absent and stored `nil`; `Map.fetch`, `Keyword.fetch`, `Map.has_key?` do not | `probes/p2_elixir_lookup_shapes.out`; docs text in `p2b_elixir_docs.out` |
| Elixir `Map.fetch/2` returns the tagged `{:ok, value}` / `:error` | `p2b_elixir_docs.out` |
| Dialyzer gets no information from `-spec f() -> term() \| nothing`, and uses `{ok, term()} \| absent` | `probes/p4_dialyzer.out`, `p4_check.out` |
| Absorption is `F ⊆ T`; refuses option<atom>, option<term>, option<option<int>>, result<term,E>, result<tuple,atom>, result<(atom,binary),binary> | `p3_absorption_algebra.out` (erl_types). B#'s own: INHERITED from F31 S3-S8, not re-executed |
| A cofinite-only rule misses 4 of the 8 refused rows | `p3_absorption_algebra.out` last block (assert is a refutation that can fail). 15 §1's warning: INHERITED |
| `result<int, term>` and `result<atom, term>` survive | `p3` out. Matches 15 §2 table: INHERITED |
| nested `result<result<int,term>,term>` is absorbed | `p3` out only; **not** in F31's table, not B#-verified |
| Untagged lookup misreads a stored `nothing` as absent and a stored `{error,_}` as failure; tagged and Has+Get do not | `probes/p5_hazard.out` |
| Typo'd key gives the same answer under tagging as a real absence | `p5` out (`usr_id` line); matches 48l §1 (INHERITED) |
| Tagging costs 3 heap words per hit, same for `{ok,V}`/`{some,V}`, independent of V | `probes/p6_term_cost.out` |
| Tagged match adds ~1 instruction/site and 144 bytes over 20 sites | `probes/p7_code_cost.out` |
| Tagged vs bare run time | `p7` out timing: inconclusive, see section 6 |
| `is_key`+`get` is slower than `find` on a large-map hit (1.47x) | `probes/p8_lookup_cost.out` (noisy) |
| `Map.?Get` is decided to return `option<T>`; `Map.Get` crashes | ticket 108 decisions entry, `wayfinder/issues/108-the-second-forms-spelling.md:160-175`. INHERITED |
| `Map.Has` is built; `Map.Get`/`Map.?Get` unbuilt (ENG-324) | `compiler/features/F75-list-and-map-rows.md:119,181`; `bs_check.erl:1763`. INHERITED |
| `Map.Find -> option<V>` is also planned | `wayfinder/issues/96-standard-environment-breadth.md:224`; `98-task-and-agent.md:71`. INHERITED |
| F36/F31 refuse `option<term>` and `result<term,E>`; S10 `(:ok, term) \| :absent` accepted | `compiler/features/F31-collapse-at-the-declaration.md:175-190`. INHERITED, not re-executed |
| The absorption check runs on written declarations and the `ValidateAs` site, not found at a row call site | source reading: `bs_check.erl:1202-1216`, `3265`, `3410-3415`. UNPROBED (no `bsc`) |
| Parametric-alias unbound `T` reaching the check is unmeasured | F31 amendment 2026-10-08, `F31...md:160-165`. INHERITED |
| No `Map` pattern form for an open key domain; list head patterns exist | tickets 48/48l, F33. INHERITED |
| Gleam `dict.get` returns `Result(v, Nil)` (absence as a value in a closed union) | UNPROBED (cited from `wayfinder/research/48-map-type-prior-art.md:151,211` and ticket 48:86; no gleam installed) |
| Elm `Dict.get` returns `Maybe` (a tagged `Just`, so nests) | UNPROBED (cited from general knowledge, no local source; no elm installed) |
| B# snippets in section 2 compile / are refused as stated | UNPROBED: `bsc` not available. Verdicts follow F31/F36 and 108 |

---

## Decision left open for human review

Nothing above is decided. The brief recommends A (refuse, point to `Map.Has` + `Map.Get`, no new
surface) with B (a tagged sibling row) held in reserve. The calls that are the human's:

1. **Is "the checker must see absence at `term`" worth a second spelling (B)?** If yes, B is a
   one-row addition (`generated` row, pinned-legal type) and A's `Has`/`Get` pair stays as the
   cheap form.
2. **If B: what is the absence atom named?** `:absent` (needs a `generated` row) or `:error` (a bare
   `maps:find`, but it puts a bare `:error` beside the `(:error, E)` failure member against 15 §2).
3. **Measure first, whichever is chosen:** whether `absorbed/2` runs at a row's call-site
   instantiation (section 0 item 5). If not, `Map.?Get` at `V = term` re-collapses silently the
   day ENG-324 lands, and that is a gate to write *before* the row (CLAUDE.md: failing test and
   gate first), independent of A/B/C.
4. Ticket 64's Q3 wording says `E = term`; the substantive answer is at `T = term` (section 4).
   The ticket text may want correcting when it is resolved.
