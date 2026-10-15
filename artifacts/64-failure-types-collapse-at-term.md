# 64 -- `option<term>` and `result<term, E>`: where does the tag live?

Status: brief only; ticket left OPEN for David. Written at HEAD 019533d (+ 8b09c30, artifacts only). Probes: `artifacts/probes/64_*`.

## What the ticket asks, and what changed since

ENG-254 asks what an author reaches for at a `map<string, term>` lookup once `option<term>` is refused at the declaration, and whether the refusal reaches `result<T, E>` at `E = term`. Four things moved since it was written (2026-08-25, narrowed 2026-09-06):

1. **The "collapse" is no longer silent at a written declaration.** F31 built the refusal (S5, S7). At HEAD `option<term>`, `result<term, atom>` and `result<term, term>` are refused in every written position (below). The ticket's four-signature table (FindR, FindT "COLLAPSED") is stale.
2. **`ToExistingAtom` is no longer owed.** There is no `PRELUDE.md` in the tree. `ToExistingAtom` is built (F54) and returns `result<atom, string>` (`STANDARD-ENVIRONMENT.md:115`, `examples/Names`).
3. **Ticket 48's day-one escape was overtaken without anyone noticing.** 48 Q6 (lines 1028-1031) said the collapse "stops blocking" because `Get` can return a tagged `(:ok, V) | :absent`. Ticket 108 (decided 2026-09-25) then fixed `Map.?Get`'s return as `option<V>` ("Return types unchanged"), and 96 Q3 did the same for every `?` pair. `grep -n 'ENG-254\|ticket 64' 96 97 108` finds nothing, so none of those tickets checked this. As decided, **`Map.?Get` on a `map<string, term>` returns the refused type**, in all three motivating cases.
4. Tickets 68 and F31 settled that the refusal is real and is one rule (`M ⊆ union(others)`, `absorbed/2` at `bs_check.erl:3282`, `each_member` at 1195). What remains is the "leaves the author with nothing" half.

## The gating question (alone)

**Does the tag live in the type, or in one operation?** Concretely: when `Map.?Get` / `List.?First` / `Process.?Whereis` find nothing at a value type `V` that contains `:nothing` (`term`, `atom`, `(atom, term)`), is their return a prelude-named tagged type that replaces `option<V>` for every `?` operation (type), or does `option<V>` stay exactly as 108 decided and one extra operation `Map.Fetch` return `(:ok, V) | <absent>` (operation)?

Follows from the answer, not asked here: the absent atom's spelling (`:absent` per 48, `:error` per OTP, `(:some, T) | :nothing` per F31's hint: three live spellings); whether a default-valued `Map.Get(m, k, d)` exists; the name of the tagged operation in 108's `?` scheme; and `result<T, E>` (Q3 is answered by measurement, below, without a decision).

## Findings

**F1. Four-signature table at HEAD. PARTLY: the ticket's "COLLAPSED" is stale; two of four are refused, not collapsed.**
`./64_collapse_table.sh` (signature / record field / alias, each a separate module), `64_silent_routes.sh` R3:

| declared | HEAD |
|---|---|
| hand-rolled `:absent \| (:ok, atom\|int\|list<term>)` | accepted, survives (R3b) |
| `option<int>` | accepted, `:nothing \| int` |
| `result<term, atom>` | REFUSED `(:error, atom)` is absorbed by `term` (sig, field, alias) |
| `option<term>` | REFUSED `:nothing` is absorbed by `term` (sig, field, alias) |
| `option<atom>` | REFUSED `:nothing` is absorbed by `atom` |
| `result<term, term>`, `result<term, binary>` | REFUSED |
| `result<(atom, term), binary>` | REFUSED `(:error, binary)` absorbed by `(atom, term)` |
| `result<int, term>`, `result<list<term>, term>` | **accepted**, `int \| (:error, term)` |
| `option<list<term>>`, `option<map<term,term>>`, `option<(atom,term)>`, `option<pid>`, `option<binary>` | accepted |
| `option<option<int>>` | REFUSED `:nothing` is absorbed by `:nothing \| int` |

Diagnostic for `option<term>` (verbatim, `64_programs/HeadersOptTerm`): `error: `:nothing` is absorbed by `term`` / `the failure channel does not survive normalisation, so the type declared here IS `term`...` / `hint: tag it - (:some, term) | :nothing`.

**F2. Q3 answered: the refusal does NOT reach `result<T, E>` at `E = term`. CONFIRMED by measurement.** `(:error, term)` is a tuple and `int`/`list<term>` do not contain it. `result<int, term>` is accepted. The collapse reaches `result` at **`T`** being `term`, or any tuple top `(:error, _)` fits (`(atom, term)`). So "`result<T, E>` at `E = term`" is a non-problem; the real `result` exposure is `T = term` and `T = (atom, term)`.

**F3. One route still collapses silently. CONFIRMED (new).** `64_silent_routes.sh` R2: a generic `public option<T> Wrap<T>(T x)` called with a `term` is accepted with no diagnostic, and `Use(:nothing)` prints `0`, i.e. a present `:nothing` reads as absent. The same program with `T=int` is accepted (control). A user parametric alias at `term` (R1, `type MyOpt<T> = T | :nothing`, the case F31's 2026-10-08 amendment said was unmeasured) is **refused** at the use site, so only instantiation by inference leaks. The refusal fires on written types only; I did not read why R2 slips (mechanism not measured). Unmeasured prediction: `Map.?Get` built as a `reserved_sig` (`bs_check.erl:1717-1744`) would hit the same hole, since its return is computed, not written. This hole exists under every option below.

**F4. A route exists today and the corpus already uses it. CONFIRMED.** `exemplars/25g-jev-server/triage_index.bs:42` declares `(:ok, term) | :error find(term key, map<term, term> m)` and `triage_crash.bs:21` switches on it. So "nothing to reach for" is false for foreign `:maps`; what is missing is a blessed in-language operation. Corpus scale (`compiler/examples`, grep): 18 `option<...>` uses, 0 at `term`; 1 map lookup, tagged.

**F5. The refusal prevents a real wrong answer. CONFIRMED.** `64_cases.sh`, AssignsNaive (`maps:get/3` with `:nothing` default): `RunAnon` and `RunLoggedOut` both give `:no_assign_or_logged_out`. The tagged versions give `:no_assign` and `:explicitly_logged_out`. Counter-case: JsonDefault (`maps:get(k, m, :undefined)`) gets all three JSON outcomes right, because JSON decoding cannot produce `:undefined` (its atoms are `true/false/null`). A sentinel default is safe exactly when the sentinel is outside the value domain.

**F6. Ticket 48's `:absent` spelling is not OTP's, and the difference crashes. CONFIRMED.** AssignsBRaw declares a foreign `find` returning `:absent` over `maps:find`: `RunAnon` prints `crashed: case_clause :error`. A lowered tagged op needs a `case` that renames `error` to `:absent` (AssignsB, works), or adopts `:error` and needs none.

**F7. Req headers: PARTLY.** The ticket says all three cases carry `term`. Modelled as `map<string, list<term>>` (header name to values list), `option<list<term>>` is accepted and runs (HeadersOpt: `:has_header` / `:no_header`); at `term` it is refused (HeadersOptTerm). I could not read Req's source (hex blocked), so which shape Req uses is not verified here.

**F8. The collapse is a property of untagged unions. CONFIRMED.** `64_untagged_vs_tagged.exs` (Elixir 1.18.5 `Module.Types.Descr.equal?`): `T | :nothing == T` is true for `atom`, `term` and for the nest `option<option<int>>`; false for `int`. `{:ok,T} | :absent == T` is false for `int`, `atom`, `term`, and the nest stays two levels.

**F9. Tagged shapes survive everywhere bsc checks, and close F3. CONFIRMED.** `64_tagged_shapes.sh`: all three spellings accepted at `term`; `Found<Found<int>>` prints two levels; generic `Found<T> Wrap<T>` at `T=term`, `Use(:absent)` prints `1` (present), where F3's untagged one prints `0`.

**F10. Bare success is the better shape where it is sound. CONFIRMED.** `64_cases.sh` BareWins vs TaggedOption (same program, both print 2): the tagged version needs a `(:some, v)` wrapper at each success clause and a `(:some, n)` head pattern in each consumer (counts printed: 0 vs 1 and 0 vs 1 in a 3-clause program). Size: an int hit costs 0 words bare vs 3 words tagged.

## Neighbours

- **Erlang** `stdlib-7.3.0.3/src/maps.erl:138` `-spec find(Key, Map) -> {ok, Value} | error`; `:686-692` `get(Key, Map, Default)`: `#{Key := Value} -> Value; #{} -> Default`. Two operations, one tagged, one bare-with-sentinel.
- **Elixir** 1.18.5 `lib/elixir/lib/map.ex:298-299` `@spec fetch(map, key) :: {:ok, value} | :error` / `def fetch(map, key), do: :maps.find(key, map)`; `:526` `def get(map, key, default \\ nil)` (the `nil` default is the sentinel, with F5's ambiguity). `fetch!` at 317.
- **Gleam** (`gleam-lang/stdlib` v0.62.0, cloned from GitHub; `dict.gleam:150` `pub fn get(from: Dict(k, v), get: k) -> Result(v, Nil)`; `gleam_stdlib.erl:41-44` `case maps:find(Key, Map) of error -> {error, nil}; OkFound -> OkFound`). Ran `64_gleam.sh`: stored `None` gives `present, value is None`, missing key gives `absent`, and a stored `dynamic.nil()` still gives `present`. Never collapses: `Option` is a constructor type and the result is tagged.
- **Elm**: **not run**; `package.elm-lang.org` returns 403 through the proxy and `elm make` needs the registry. Source only (`elm/core` 1.0.5 `Dict.elm:94` `get : comparable -> Dict comparable v -> Maybe v`; `Maybe.elm:39` `type Maybe a = Just a | Nothing`). I did not execute an Elm program.

All four return a **tagged** result from the lookup that can distinguish absent from "present, value looks like absent". B#'s `option<T>` is the only one whose success is the bare value, hence the only one that can absorb.

## Measurements

`64_repr_cost.escript`, OTP 28, 64-bit (8 B/word), shared 4-core host at load avg ~6, so timings are noisy.

| value | bare words / term_to_binary B | `{ok,V}` words / B | `{just,V}` words / B |
|---|---|---|---|
| small int 42 | 0 / 3 | 3 / 9 | 3 / 11 |
| bignum 2^70 | 3 / 13 | 6 / 19 | 6 / 21 |
| atom | 0 / 8 | 3 / 14 | 3 / 16 |
| 3-key map | 10 / 21 | 13 / 27 | 13 / 29 |
| 40 B binary | 7 / 46 | 10 / 52 | 10 / 54 |
| 1,000,000 B binary | 8 / 1000006 | 11 / 1000012 | 11 / 1000014 |

Tagging costs a constant 3 words heap, 6 B (`ok`) or 8 B (`just`) in the external format, whatever V is; it is invisible on a large binary and 3 words (24 B) on an int that was free. `flat_size` (send copy): int 42 bare 0, `{ok,42}` 3.

1e6 lookups, 1000-key int map, ~9% misses, 21 runs each (ms, min / median; saved run): `maps:get/3` default (what an untagged `option<int>` lowers to) 27.1 / 33.3; `maps:find` unwrapped to `V | nothing` 36.3 / 37.0; `maps:find` tagged and matched 36.3 / 44.5; `{just,V}` rebuilt from find 36.4 / 46.6. Over 7 invocations (6 unsaved) the `get/3` min was 27-31 ms in 6 and 35 ms in 1, the `find`-based mins 36-38 ms, and medians overlapped. Reading: `maps:find` allocates the tuple itself (a BIF), so only the `get/3` lowering avoids it, and only where `:nothing` cannot be a stored value. Not measured: compile time, `.beam` size, cost through a non-inlined call boundary, cost on a loaded VM with GC pressure.

## Options

### A. The operation: `option<V>` unchanged; one tagged operation, `Map.Fetch`

```csharp
module AssignsA
using :maps { (:ok, term) | :error find(term key, map<atom, term> m) }   // written by hand today, as 25g does
private atom Lookup(map<atom, term> assigns)
Lookup(assigns) -> :maps.find(:user, assigns) switch {
    :error          => :no_assign,
    (:ok, :nothing) => :explicitly_logged_out,
    (:ok, u)        => :has_user }
```
Runs: `RunAnon` `:no_assign`, `RunLoggedOut` `:explicitly_logged_out` (also JsonA: set / clear / leave_alone; HeadersA). `option<term> Map.?Get(...)` stays refused with the diagnostic above and its hint (`tag it`). Measured on HEAD, no patch.
Compiler delta: (1) a `reserved_sig('Map','Fetch',2,[MapTy,_])` clause (`bs_check.erl:1717`) whose return is built from the map's value type, as `List.Map` already builds its list return; add to `reserved_arities` (1752). (2) one `otp_args`/lowering clause in `bs_emit.erl` (the `List` ones are at 2112): `Map.Fetch` becomes `maps:find/2` if the spelling is `:error`, or a `case` rename if `:absent`. (3) **a check that a computed or inferred `option<T>` return at an absorbing `T` is refused** (F3; needed under every option). (4) 108 names `Map.Get`/`Map.?Get`; the third form needs a spelling from ENG-324's owner.
Strongest counterargument (the type's proponent): "You have made the author learn which operation to call by checking whether their `V` contains `:nothing`. `List.?First` on a `list<term>`, `Process.?Whereis`, every 96 Q3 pair has the same hole, and each needs its own tagged sibling or the `?` marker means 'safe except at `term`'. Generic code (F3) can't be fixed by a sibling operation at all."

### B. The type: a prelude-named tagged shape that every `?` operation returns

```csharp
type Found<T> = (:ok, T) | :absent          // prototyped as a user alias; the prelude version is lowercase `found<T>`
private Found<term> Fetch(atom key, map<atom, term> m)   // what a lowered Map.?Get must emit
Fetch(key, m) -> :maps.find(key, m) switch { (:ok, v) => (:ok, v), :error => :absent }
```
Runs identically to A (AssignsB, JsonB); the raw `:absent`-over-`error` version crashes (F6). `Found<T> Wrap<T>` at `term` is correct (F9). Measured by prototyping with a user alias on HEAD; no compiler patch, so the prelude entry itself is unbuilt.
Compiler delta: (1) a `found` entry in `stratum_one()` (`bs_check.erl:1338`), plus the `CONTEXT.md` term. (2) Re-point 96 Q3 / 97 / 98 / 108 return types from `option<T>` to `found<T>` for every `?` row (`Map.?Get`, `List.?First`, `?Last`, `?At`, `?Max`, `?Min`, `?MaxBy`, `?Find`, `Process.?Whereis`, `System.?Env`). (3) Decide the `:absent`/`:error` spelling and emit the rename or none. (4) `option<T>` stays for hand-written APIs, so two absence types coexist: when does an author pick `option` over `found`?
Strongest counterargument (A's proponent): "You are reversing 108's 'return types unchanged' and 96 Q3 to fix a case the corpus does not contain (0 of 18 `option` uses at `term`), and you pay at `option<int>` for it: F10 shows a wrapper per success clause and per consumer head, 3 words per int hit, where the bare shape was free. Two absence types is the thing `option` was meant to prevent."

### C. Retag `option<T>` itself, `(:some, T) | :nothing` (the ticket's own Notes warn against it)

Measured as a variant only: TaggedOption compiles and prints 2, the same as BareWins; cost is F10 on every use (18 in the corpus), and it revises ticket 08's `as T` yields `T | :nothing`. Delta: edit `stratum_one()`'s `option` and every `:nothing` pattern in the 19 corpus sites. Best proponent: "one type, no choice, nests, no refusal needed at all; Gleam/Elm/Elixir all do this." I measured no technical blocker; the argument against is 15 §1's recorded trade (the untagged union is the showcase), not a measurement.

## Recommendation

**A, with the F3 check.** The tag lives in the operation. Reasons: the refusal is already loud and correct; the term-valued route already exists and the corpus uses it (F4); all three languages with a bare-with-default operation also ship the tagged sibling beside it (maps:find/get, Map.fetch/get), so a sibling is the convention, not a patch; bare success wins on every cost I measured where it is sound (F10, table). Spell the tagged operation's absent as `:error` unless David wants `:absent`: it is `maps:find` unchanged (F6 crash without an adapter) and 25g already switches on it. The F3 check (refuse an inferred or computed `option<T>`/`result<T,E>` that normalises to `T`) is separate defect work and is the more urgent item: it is what makes A's "refusal is loud" true for generic code and for the unbuilt `Map.?Get` row.

What would change my mind: (1) finding term-valued `?`-lookups common in the audition tickets or exemplars beyond 25g's single `find` (this brief counted only `compiler/examples`), which moves the weight to B; (2) a reading of Req showing header values are `term`, not `list<...>`; (3) a prototype in which F3's check cannot be written without false positives on generic code, which makes the type-level B the only closed answer.

## Probe log

- **Ticket text refuted by the first run:** F1, the "collapsed in one place, refused in another" reading. At HEAD the written positions are all refused; only the inferred generic (F3) collapses. Expected going in: some written position still collapsing. It did not.
- **Surprise 1:** AssignsB's first draft (blessed `:absent` declared straight over `maps:find`) crashed `case_clause :error`. Kept as the control AssignsBRaw and added the adapter as AssignsB. This produced F6.
- **Surprise 2:** AssignsA/B/Naive first drafts used `map<atom, term>` as a foreign return and were refused ("one guard cannot decide"). I rewrote them to build `map<term, term>` and `ValidateAs<map<atom, term>>`. A program design change after seeing a diagnostic, not a patched expectation.
- HeadersA's first draft declared a nonexistent foreign `get_opt`; removed, replaced by HeadersOpt (a hand-written `Header`).
- `bsc FILE` writes `.beam`/`.abstr` into the cwd without `-o`; my first runs littered `artifacts/probes/` and I deleted my files by name. All probes now pass `-o` a scratch dir. (`C.*` and `M.*` there are not mine.)
- `64_collapse_table.sh` extended with 7 more instantiations after the first run, and temp paths stripped from output; no verdict changed.
- `64_repr_cost.escript`: first version 11 runs, raised to 21; labels renamed after the first run to say what each lowering is. Timing medians moved between runs (host load); the `get/3` min advantage repeated in 6 of 7 invocations (one showed none).
- Not run / not measured: Elm program; Req source; the prelude `found<T>` itself; `Map.?Get` as a built operation (F3's prediction); compile time and `.beam` size; any cost beyond `erts_debug`/`term_to_binary`/the one loop above.

## Probe index

All from `/home/user/beam-sharp/artifacts/probes`; `. ./env.sh` first. Outputs sit beside as `<probe>.out`.

| probe | command | refuted by |
|---|---|---|
| `64_collapse_table.sh` | `./64_collapse_table.sh` | any `option<term>`/`result<term,_>` row printing ACCEPTED with rc=0 (F1); `result<int, term>` printing REFUSED (F2) |
| `64_silent_routes.sh` | `./64_silent_routes.sh` | R2 printing a diagnostic, or `Use :nothing` printing `1` (F3); R5 control REFUSED |
| `64_tagged_shapes.sh` | `./64_tagged_shapes.sh` | any S/N/G case REFUSED, or G1 printing `0` (F9) |
| `64_cases.sh` + `64_programs/*` | `./64_cases.sh` | AssignsNaive printing two different answers; any expected-green case crashing; HeadersOptTerm compiling (F4-F7, F10) |
| `64_untagged_vs_tagged.exs` | `ELIXIR_ERL_OPTIONS=+fnu elixir 64_untagged_vs_tagged.exs` | a TAGGED row true, or UNTAGGED atom/term row false (F8) |
| `64_gleam.sh` | `./64_gleam.sh` (needs github) | the Gleam lines not being three distinct outcomes |
| `64_neighbour_sources.sh` | `./64_neighbour_sources.sh` (needs github) | any section printing no line |
| `64_repr_cost.escript` | `escript 64_repr_cost.escript` | tagged minus bare not 3 words for every row; medians equal AND mins equal for get/3 vs find |
