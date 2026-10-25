# Decision brief: ticket 64 (ENG-254), what does an author reach for to say "absent" at `map<string, term>`?

> **VERIFICATION CORRECTIONS (read first; details in verification.md).** An independent verifier re-ran the probes.
> - **p16 is invalid.** It used `--api`, which does no type checking (`bsc.erl:152`), so its control cannot fail. In a real compile the scratch `option<V>` row is rejected ("no type named option takes a type argument"). Every statement below that "all eight ticket-108 `?` rows collapse silently today" is **unsupported**: those rows are unbuilt and `Map.?Get` does not parse (p04). Read the gating claim as: *user-written generics* collapse silently at `V = term` (p05 stands, with a control the verifier added: the same generic returned as `public int` at `V = int` is refused, at `term` accepted). Whether future standard rows would is a hypothesis, not a measurement.
> - **p12's explanation is false.** The null result is noise, not inlining: `LoopTag.beam` does build `{some, ...}`. p12 says nothing either way about allocation cost.
> - **p11:** GC counts re-measured 1 vs 363 (brief: 2 vs 593); slowdown +2% to +17% on mins, medians -25% to +11%. Only the direction survives.
> - **p18 cannot support "whatever E is".** `result<(atom,int), term>` is accepted although `(:error, 5)` is both a success and a failure. Open 3 closes only as "no new refusal needed".
> - **p03's stored `.out`** is stale and lacks the `Tup` refusal block; the verifier's fresh run supports the brief.
> - **p17:** "17 modules" is 17 per-file iterations over about 12 distinct directories; the 3 worse modules and +6 errors are correct.
> - **Citations:** `declared_rows` is at `bs_check.erl:1722`, not 1721; the `ToExistingAtom` row is `STANDARD-ENVIRONMENT.md:116` (`:108` is `Map.Get`); p07's comment cites unrelated `bs_check.erl:710-712`.
> - "hex.pm blocked", "package.elm-lang.org unreachable" and "records erase to maps" have no probe behind them.
> - The recommendation's part 1 (refuse at instantiation) therefore rests on p05 alone and is narrower than written.


Compiler under test: `bsc` built from `compiler/src` at HEAD `1429fdc`, OTP 29 (the ticket says OTP 28).
Every claim below cites a probe in `probes/`; probe names are `pNN_*`. Nothing under `wayfinder/` was touched.
Where a probe needed a modified compiler it ran a scratch copy of `bs_check.erl` (diffs kept in `probes/delta*.diff`);
the repo source is unmodified.

## 1. What is left to decide, in dependency order

The ticket is already narrowed to its expressiveness half (ticket 68 Q1 answered "sound, and refused"). Re-reading it
against HEAD, four sub-decisions remain, and the first one is not in the ticket at all.

1. **GATING. Is the refusal reached at the place the collapse actually happens?** Ticket 64 says the refusal is "real"
   (F31 S5/S7, F36). It is real at a *written* `option<term>`. It is **not** reached when `V` arrives by instantiating
   a polymorphic function or standard-environment row. Ticket 108 has already decided that all eight option-returning
   `?` rows (`Map.?Get`, `List.?First`, `?Last`, `?At`, `?Max`, `?Min`, `?MaxBy`, `?Find`) return `option<T>`. Every one of
   them collapses silently at `T = term` today (p05, p16). Nothing in 96, 108 or 118 mentions ticket 64.
   This has to be answered first, because options A and B below both depend on it and only C avoids it.
2. **Given a refusal, what does the author write?** (the ticket's Open 2). This is the brief's central question.
3. **Does `result<T, E>` need anything at `E = term`?** (Open 3). Answered by measurement: no (p18). Not a decision.
4. **Which tag vocabulary does the repair use?** (`(:some, V) | :nothing` in the diagnostic hint, `(:ok, V) | :absent` in
   ticket 48 Q6, `(:ok, V) | :error` in OTP.) A follow-on to 2. It is flagged in section 6 and should be asked alone, after 2.

## 2. What is true at HEAD (ticket claims re-checked)

| Ticket claim | Status at `1429fdc` | Evidence |
|---|---|---|
| `option<term>` and `result<term, atom>` normalise to bare `term` | **Stale.** Both are now *refused at the declaration* (`` `:nothing` is absorbed by `term` ``, hint `tag it - (:some, term) | :nothing`). Only the table row "COLLAPSED" in the ticket predates F31/F36 | p01, p03 |
| `option<atom>` collapses | Refused, same tag | p01 |
| `result<int, term>` | Accepted and survives as `int | (:error, term)` | p01, p18 |
| 48l: typo is silent, head cannot ask "has key K", closed key set stays exhaustive | **Reproduces** on OTP 29 (Correct 42, Typo 0, WrongType "unset", First `:saw_user`, Second `:no_user`, closed union refused when grown) | p02 |
| The `(:ok, V) | :absent` shape survives | Yes, and so does `(:ok, term) | :error` (maps:find shape) | p03, p06 |
| "`PRELUDE.md` still records `ToExistingAtom` as owed" | **Stale.** There is no `PRELUDE.md`; the file is `STANDARD-ENVIRONMENT.md`; `ToExistingAtom` was built as F54 (2026-09-21) and returns `result<atom, string>` | `STANDARD-ENVIRONMENT.md:108` area, F31 header |
| Ticket 48 Q6: lookup "usable at V=term on day one" | **Not yet true in the standard environment.** `Map.Get` is refused (`Map has no operation of that name`), `Map.?Get` does not parse. It is true only through a user-written foreign `:maps.find` or a hand scan (p04, p06) | p04 |
| Generic `Find<V>` returning `option<V>` is safe | **Not safe at `V = term`**: no declaration is refused, the caller's result is `term`, and a stored `:nothing` reads as absent | p05, p16 |

## 3. The gating question, asked alone

Program (compiles today, no diagnostic, runs):

```csharp
module GenOptTerm2
private option<V> Find<V>(list<(atom, V)> xs, atom k)
Find([], k) -> :nothing
Find([(kk, v), ..rest], k) when kk == k -> v
Find([_, ..rest], k) -> Find(rest, k)

public term AtTerm(list<(atom, term)> xs)
AtTerm(xs) -> Find(xs, :a)
```

`bsc --api` prints `term AtTerm(list<(atom, term)>)`. `AtTerm([(:a, :nothing)])` and `AtTerm([(:b, 5)])` both return
`:nothing` (p05). The same happens with a *standard-environment* row: with a type-only row
`option<V> PeekOpt<K, V>(map<K, V> m, K k)` standing in for ticket 108's unbuilt `Map.?Get`, `OnTerm` types as `term` and
`Use(m) -> Map.PeekOpt(m, "k") switch { :nothing => :absent, v => :present }` compiles (p16, scratch compiler #2).

**Why the existing check misses it.** `collapse_decl/2` (`bs_check.erl:1109-1135`) scans *declared* type expressions;
a signature's type variables are opaque there (`opaque_env(TV, Env0)`, line 1110) and parametric aliases are skipped.
`absorbed/2` (`bs_check.erl:3415`) is the right predicate and is already applied at one instantiation site
(`validate_collapses/2`, `bs_check.erl:3410`, for `ValidateAs<T>`; F18). Calls to polymorphic functions and declared rows
(`declared_op/6`, `bs_check.erl:3338`, via `reserved_op/6`, `bs_check.erl:3295`) have no such check.

**The decision this asks.** When `V` is bound to a type that already contains the failure member, is the *call* refused
(as `ValidateAs<term>` is), or does the author get a bare `term`? It is the same rule as ticket 68's, at the one place
68 did not look. I do not think this one needs a menu: refusing is the rule 68 already settled, and A and B below both
assume it. Option C is the only way to avoid it.

Compiler delta (**not prototyped**; I could not reach the binding of `V` without reading `checked_call_typed/7` and
`template/4` more closely than the time allowed, so treat the size as an estimate): after `declared_op/6` types a call whose
signature return is `option<TV>` or `result<TV, _>` for a type variable `TV`, take the instantiated binding of `TV` and call
`absorbed(failure_member, Binding)`; on true raise a new tag reusing `absorbed_member`'s sentence with a call-site path.
The same function covers user generics (`Find<V>` above), so it is not Map-specific.

## 4. The three options for the central question

All three assume the gating answer above (refuse at the call) except C, which makes it unnecessary.
The concrete program is the Plug-style assigns read that all three of ticket 48's motivating cases share.

### Option A. Say nothing new: the author writes `Map.Has` then `Map.Get`

```csharp
module Assigns
public string Describe(map<string, term> m)
Describe(m) -> Map.Has(m, "user_id") switch {
    :true  => Show(Map.Get(m, "user_id")),
    :false => "anonymous"
}
```

`Map.?Get(m, "user_id")` at this type is refused by the gating answer, with a hint pointing here. Lowers to
`maps:is_key/2` then `maps:get/2`; no new emitted function.

- **Compiler work.** One row: `{{'Map','Get',2}, {maps,get}, [2,1], "V Get<K, V>(map<K, V> m, K k)"}` in
  `declared_rows()` (`bs_check.erl:1721`, beside `Has` at line 1747). That is ENG-324's `Map.Get` regardless of this
  ticket. Plus the call-site check from section 3.
- **Evidence.** The pair works today with foreign `:maps.get` and built `Map.Has`: stored `:nothing` reads
  `:stored_nothing`, absent key reads `:absent`, and a bare `Get` on an absent key crashes `badkey "nope"` (p06 C2).
  It is not slower: `is_key + get` 14.9 ms vs `maps:find` 22.6 ms per 1M lookups (min of 7, p14; the BIF-inlined opcode wins).
- **Strongest counterargument.** The compiler cannot connect the guard to the read. A typo in one of the two key
  spellings (`Has(m, "userid")` then `Get(m, "user_id")`) compiles and crashes at runtime, which is the exact
  failure 48l §1 measured and ticket 48 Q8 wanted the *assertive* form to catch early. Exhaustiveness is not checked
  at all: the switch over `:true/:false` is exhaustive whatever `Get` does. Of the three options this one gives the
  type system the least to say about "absent". Elixir's own docs recommend against the shape (`Map.get` with a sentinel, see section 5).

### Option B. A tagged sibling row beside the `?` convention, `Map.Fetch`, returning `(:ok, V) | :error`

```csharp
module Assigns
public string Describe(map<string, term> m)
Describe(m) -> Map.Fetch(m, "user_id") switch {
    (:ok, :nothing) => "stored nothing",
    (:ok, uid)      => Show(uid),
    :error          => "anonymous"
}
```

The name `Fetch` is Elixir's (`Map.fetch/2`); it is a placeholder, see section 6. `Map.?Get` stays `option<V>` for the
`V` where it does not collapse and is refused (gating answer) where it does.

- **Compiler work (prototyped, p15).** Two lines in `declared_rows()` (`bs_check.erl:1721`) and one widened clause in
  `sought_row/1` (`bs_check.erl:1763`) so a key of the wrong type is refused the way `Has` already refuses it:
  `{{'Map','Fetch',2}, {maps,find}, [2,1], "(:ok, V) | :error Fetch<K, V>(map<K, V> m, K k)"}`. No emitter work:
  the row lowers to one `maps:find/2` call, whose return *is* the B# type. (A bare-`option<V>` row cannot do this; it
  needs a `generated` wrapper like `List.Insert`, `bs_check.erl:1738`, `bs_emit.erl:2153`.)
- **Evidence (scratch compiler #1, `delta_rows.diff`).** `Kind("user_id")` `:present`, `Kind("flag")` `:stored_nothing`,
  `Kind("nope")` `:absent`; `--api` prints `:error | (:ok, term) Raw(string)`. Negative: a switch missing `:error` is refused
  (`this switch in Kind is not exhaustive / no arm matches: :error => ...`); a key `:a` against `map<string, int>` is
  refused by the existing row machinery. The stock compiler refuses `Map.Fetch` (control). The same shape works today with a
  hand-written foreign declaration or a list scan (p06 C1, C3), so B changes who writes the signature, not what is possible.
- **Strongest counterargument.** Ticket 64's own Notes: this is "one call site choosing a type that happens not to
  collapse", not a repair. It adds a *second* spelling for the crash-free half of the pair beside the `?` marker that
  ticket 108 chose precisely so there would be one convention. And it covers only `Map`. The other seven option rows at
  `term` (for example `List.?Find` over `list<term>`) get no sibling. Lists at least have patterns
  (`[x, ..rest]`) to fall back on. Maps do not and will not soon: `Who({ "user_id": uid })` is refused on purpose
  because an unbounded key set cannot be proved exhaustive (p19, ticket 48 Q2, ENG-323).

### Option C. Tag `option<T>` universally: `option<T> = (:some, T) | :nothing`

```csharp
public option<Level> Parse(string s)
Parse(s) when s == "debug" -> (:some, :debug)
Parse(_) -> :nothing
// every caller: Parse(x) switch { (:some, lv) => ..., :nothing => ... }
```

`option<term>`, `option<atom>`, `option<option<int>>` all stop colliding (p08: `Maybe<atom>`, `Maybe<term>`,
`Maybe<Maybe<int>>` all survive with the same shape as a user alias). The gating question disappears.

- **Compiler work.** One line: the prelude alias at `bs_check.erl:1351`. Also `ParseAtom<T>`
  (`bs_check.erl:3446`, `T | :nothing`) and ticket 08's `as T` narrowing, which this scratch change did **not** touch (so the
  measurement below is a lower bound). `failure_channel/1` (`bs_check.erl:1219`) loses its `nothing` arm.
- **Evidence (scratch compiler #3, `delta3_tagged_option.diff`, p17).** Compiling the 17 repo modules that mention
  `option<` or `:nothing`: 3 modules that compile clean today (`Levels`, `Parcel`, `31d/Optional`) gain errors (+6 total) from
  that one-line change alone, each at both producers (`returns a value its signature does not declare / (:some, ...)`)
  and consumers. Ticket 15 §1 kept the shape bare for this reason ("the showcase": `as T` reads well in a clause head).
- **BEAM cost per lookup (p11, erts_debug:flat_size).** `{ok,V}` costs a fixed **+3 words (24 bytes)** per *present* result,
  for every value shape (small int 0 to 3, atom 0 to 3, 100-byte refc binary 8 to 11, list-of-3 6 to 9). An absent result
  costs 0 words in both forms (both are atoms). `{some,V}` is the same size as `{ok,V}`. In 1M lookups, half hits:
  bare 15.0 / 15.5 / 19.8 ms (min/median/max of 7), tagged 15.9 / 16.1 / 26.2 ms, minor GCs 2 vs 593. With an existing
  3-element list as the value: bare 15.7/16.1/17.7 ms, tagged 17.1/18.0/19.0 ms, minor GCs 0 vs 970. So **`option<int>`
  under universal tagging costs roughly +4% to +12% in a pure lookup microbenchmark, 3 extra heap words per hit, and
  GC pressure that appears at all.** The end-to-end B# loop (p12) shows nothing: 450-570 ms either way, spread larger
  than any difference, because `erlc` inlines the private `Probe` and never builds the tuple. That result says the cost is
  avoidable by the optimiser in the easy case; it does not show the cost is zero.
- **Strongest counterargument against C is the ticket's own: it spends the type system's advantage.** The
  counterargument *for* C, stated fairly: it is the one option with no special cases (one rule for every `T`, nests
  correctly, matches Elixir/Gleam/Elm and the interop boundary), and the gating check and the hint-vocabulary question
  both vanish. The per-hit cost is small in absolute terms and an optimiser may erase it. What makes me advise against
  is blast radius, not speed: 27 `option<` lines across 14 `.bs` sources, 17 compiler sources/tests, 66 docs (p13), plus
  eight ticket-108 rows and `as T`, all rewritten to protect a use (`term` values) that one row of Option B already
  covers.

### What I considered and rejected (so it is on the record)

- **A generic `record Some<T>`.** Not possible: `record_decl` takes no type parameters (`bs_parser.yrl:132`, syntax error
  before `<`, p07). And records erase to maps with a tag, so it would be a larger term than the tuple anyway.
- **Choosing the representation by `T`** (bare unless `T` absorbs `:nothing`, then tagged). Generic bodies cannot do
  it: `Find<V>` in section 3 returns `v` bare in a body typed once for all `V` (ticket 27 opacity).
- **A user-written alias `type Maybe<T> = (:some, T) | :nothing`.** Works today at every `T` including `term`, `atom`
  and nested (p07, p08). It is the existing escape hatch; the diagnostic already tells the author to write exactly
  this (`bs_diag.erl:1973`, `LANGUAGE.md:1651`). Its weakness is that each author re-declares it, and no stdlib row returns it.

## 5. Neighbours (real sources only)

| Language | Absent-or-value at an unconstrained value type | Source |
|---|---|---|
| Erlang | `maps:find/2 -> {ok, Value} \| error` (tagged); `maps:get/2` raises `{badkey,K}`; `maps:get/3` default; `maps:is_key/2`. The pair `is_key`+`get` and the tagged `find` both exist | OTP stdlib-8.1.1 `maps.erl:138` (find), `:115` (get/2), `:686` (get/3), `:304` (is_key) |
| Elixir | `Map.fetch/2 :: {:ok, value} \| :error`, `Map.fetch!/2` raises, `Map.get/3` takes a default, `Map.has_key?/2`. Executed: `Map.get(%{a: nil}, :a)` and `Map.get(%{}, :a)` are both `nil`; `Map.fetch` gives `{:ok, nil}` vs `:error` | compiled Docs chunk of `Elixir.Map` (doc lines 287 fetch, 311 fetch!, 566 get/3, 271 has_key?); `Keyword` 579/600/379/1120. Executed in p09. Elixir `.ex` source: **source unavailable** (conda ships `ebin` only) |
| Gleam | `dict.get` returning `Result(v, Nil)` | **source unavailable**: tried npm `gleam_stdlib` (404), pip (no distribution), a filesystem search, the gleam 1.19.1 binary (no embedded stdlib); hex.pm is blocked (p10). Not cited |
| Elm | `Dict.get` returning `Maybe v` | **source unavailable**: the package cache `~/.elm/0.19.3/packages` holds only `lock`; package.elm-lang.org is not reachable (p10). Not cited |

Reading across the two sources that are real: both ecosystems that run on the BEAM keep *two* lookups, one that tells
absent from stored (`find`, `fetch`: tagged) and one that is cheap but ambiguous when the value type can hold the
sentinel (`get/3` with a default; `Map.get`). The OTP default form is precisely Option A's unsoundness, executed:
`maps:get(a, #{a => nothing}, nothing)` returns `nothing`, `maps:find` returns `{ok,nothing}` (p14). Neither ecosystem
tags a *universal* optional; that decision is made per operation. This is closer to Option B than to C.

## 6. Recommendation

**Gating answer first: refuse the call at instantiation (section 3).** It is the same rule ticket 68 settled, applied at the
site 68 did not look; without it every ticket-108 `?` row will reintroduce the silent collapse at `term`, and Options A and
B are both incoherent. Ask this alone.

**Then Option B for the author's reach, with A as what the author already has.** Concretely:

- Ship `Map.Get` (assertive, `maps:get`) and a **tagged** crash-free sibling for the one family where there is no pattern
  to fall back on, `Map`. At `V = term` the refusal's hint then points at that sibling instead of at a hand-written alias.
- Leave `option<T>` bare. Option C costs more than the problem (3 of 6 clean repo modules need hand edits, plus `as T`
  and `ParseAtom`, plus +3 words per hit) and its benefit is already available per call site.
- `result<T, E>` needs nothing at `E = term` (p18): the error tag keeps the member apart, whatever `E` is. Close Open 3.
- Do not count the tagged sibling as "fixing the prelude" (the ticket's own warning). The prelude is not broken; what was
  missing is the instantiation check, and the sibling is a spelling for a reading the check forbids.

**What I am not sure of.** (1) B adds a second crash-free spelling next to ticket 108's `?`. A reasonable reading is
that 108 should be re-opened to say the `?` form is `option<T>` *only where `T` allows it*, and that Map carries one
documented exception. I have not argued that; David should. (2) The sibling's name and tag are a separate question and
should be asked alone, after the shape: `Fetch` with `(:ok, V) | :error` is a zero-conversion lowering to `maps:find`
(measured, p15), whereas `(:some, V) | :nothing` is what the diagnostic hint already tells authors to write
(`bs_diag.erl:1973`) but needs a `generated` wrapper. Three vocabularies are in the repo (`:some/:nothing`, `:ok/:absent`
in ticket 48 Q6, `:ok/:error`); the hint and the row should not disagree. (3) The call-site check's size (section 3) was
not prototyped.

## 7. Surprises and failed probes

- **First draft of p03 failed**: I wrote `(:ok, tuple)` and `FindR` with `result<term, atom>` in one module; the compiler
  refused the whole module (`tuple is not a builtin type`, then F36's absorbed-member error). Rewritten; the ticket's four-row table
  could not be reproduced as written because two of its rows are now compile errors (stale, see section 2).
- **p06 attempt 1** forgot the `:maps.` qualifier on foreign calls ("nothing binds"); output kept as `p06_*.attempt1.*`.
- **p07 attempt 1** used lowercase alias names, which the prelude owns; kept as `p07_*.attempt1.*`.
- **p18 attempt 1** used controls that do not collide (`(:error, atom)` is not inside `(:error, int)`), so its "accepted"
  proved nothing; kept as `p18_*.attempt1.*`, controls rewritten before the re-run.
- **p14 surprised me**: `maps:find` is ~50% slower than `is_key`+`get` in this microbenchmark (22.6 vs 14.9 ms), the opposite
  of what I expected. I did not tune the loop; the most likely cause is a real BIF call plus a tuple allocation against inlined
  opcodes, which I did not verify.
- **p12 is uninformative on allocation** (inlining), as said in Option C.
- `| head` closing the pipe left an `erl_crash.dump` (epipe in `halt`); harmless, deleted. `bsc` also drops `.beam`/`.abstr`
  files in its cwd when it runs a function; deleted.
- The harm named in the ticket (a stored `:nothing` indistinguishable from absent) was executed, not inferred (p05, p14).

## 8. Probe index

Re-run from `probes/` with `./pNN_*.sh` (they source `lib.sh`; `.escript` ones with `escript`). Raw output in the matching `.out`.

| Probe | Claim it supports |
|---|---|
| `p01_refusal.sh` | `option<term>`, `result<term, atom>`, `option<atom>` refused at the declaration; `result<int, term>` and `option<int>` accepted |
| `p02_rerun_48l.sh` | the repo's 48l prototype reproduces unchanged on OTP 29 (only the `BSC` path substituted) |
| `p03_four_signatures.sh` | the hand-rolled tagged form survives `--api`; F31's non-atom-top controls are refused |
| `p04_map_rows_today.sh` | `Map.Get` is refused, `Map.?Get` does not parse, `Map.Has/Put/FromList/ToList` work today |
| `p05_generic_instantiation.sh` | a generic `option<V>` instantiated at `term` types as `term` with no diagnostic; stored `:nothing` = absent |
| `p06_candidates_today.sh` | tagged `maps:find`, `Has`+`get`, and list scan all compile today and tell stored-`:nothing` from absent; non-exhaustive tagged caller refused |
| `p07_generic_record_wrapper.sh` | user alias `Maybe<T>` works at `term`; generic `record Some<T>` is a syntax error |
| `p08_tagged_option_nests.sh` | tagged option survives at `atom`, `term`, nested; bare option refused at `atom`, `option<int>` |
| `p09_neighbours_elixir_otp.sh` | OTP `maps.erl` line numbers; Elixir `Map`/`Keyword` specs and `nil` ambiguity, executed |
| `p10_neighbours_unavailable.sh` | Gleam stdlib and Elm core sources unreachable |
| `p11_term_size.escript` | +3 words per present hit; 1M-lookup time and minor GC counts, bare vs tagged |
| `p12_bsharp_loop_cost.sh` | end-to-end B# loop shows no measurable difference (inlining) |
| `p13_blast_radius.sh` | how many sources/tests/docs mention `option<` / `:nothing` |
| `p14_has_get_vs_find.escript` | `find` vs `is_key`+`get` vs sentinel `get/3` timing; the sentinel's unsoundness executed |
| `p15_delta_tagged_row.sh` | scratch compiler #1 (`delta_rows.diff`): `Map.Get` and tagged `Map.Fetch` as two table rows, run, with a negative |
| `p16_delta_option_row_silent.sh` | scratch compiler #2 (`delta2_peekopt.diff`): an `option<V>` standard row silently collapses at `term` |
| `p17_universal_tag_blast.sh` | scratch compiler #3 (`delta3_tagged_option.diff`): one-line tagged `option<T>` breaks 3 clean repo modules |
| `p18_result_at_E_term.sh` | `result<T, term>` needs nothing; colliding controls still refused |
| `p19_map_pattern_refused.sh` | the dispatch route (map key in a clause head) is refused today |
| `lib.sh`, `src_*.bs` | shared helper; every B# source the probes generated |
