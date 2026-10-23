# Ticket 64 — what an author writes when a lookup must say "absent" at `term`

**Ticket** [64](../wayfinder/issues/64-failure-types-collapse-at-term.md) · **Linear** [ENG-254](https://linear.app/davewil/issue/ENG-254) · **Brief date** 2026-10-23
**Status: DECISION OPEN — for David's review; nothing resolved.** Ticket file, Linear state and `CONTEXT.md` are untouched.

Probes: `artifacts/probes/64/` (`run_all.sh`; captured run in `output.txt`). OTP 28.5 (erts 16.4) built from source,
x86_64 Linux; Elixir 1.19.5; Gleam 1.18.1 with `gleam_stdlib` at `13359e5`; `bsc` is a pristine build of this repo's
`compiler/` at HEAD. Elm 0.19.3 is installed but cannot compile offline here (see 64k); Elm statements below are
source-read only.

## The short version

1. **The refusal does not leave the author "with nothing". It leaves them with two things that work today, and it
   hides a third that does not work at all.** A hand-rolled `(:ok, term) | :error` lookup compiles and is correct
   (64b). A user-declared `Maybe<T> = (:some, T) | :nothing` compiles, works at `term`, nests, and keeps exhaustiveness
   (64c). What they cannot have is `Map.?Get` over a `map<string, term>`, because that row is unbuilt and its decided
   return type, `option<V>`, is the refused shape (108; see below).
2. **Open question 3 is answered, and the answer is not "E = term".** `result<int, term>` compiles (64a R3). The
   refusal fires when the **success** type contains the failure member: `result<term, E>`, and equally
   `result<(atom, term), atom>` (64a Q1). The ticket's mechanism is right and its framing of Q3 was backwards.
3. **New finding, outside the five options: the refusal is silent when `T` is inferred as `term` at a call.**
   A polymorphic `option<T> Head<T>(list<T>)` called on `list<term>` compiles, and `Head([:nothing])` answers
   `:empty` (64i). This is the bug the refusal exists to prevent, one door over. It needs its own ticket whichever
   option below is chosen, except option C, which dissolves it.
4. **Recommendation:** keep `option<T>` bare (Option A), close the inference hole, and decide `Map.?Get`'s term-valued
   behaviour when ENG-324 builds it. Option B is the follow-up if you judge term-valued maps common. Option C is
   the only one that removes the whole class, and it costs the valve's ergonomics and a measured 2.3–2.9× on
   consuming large option lists.

## The gating question, alone

CLAUDE.md asks for one gating question. Here it is: **does `option<T>` stay bare-success for every `T`, or is
absence always tagged?** Everything else in the ticket follows from it. The notes in ticket 64 already say this
("do not tag `option<T>`'s success without first answering 1").

The same two programs, verified by 64g and 64a:

```csharp
// Under "stays bare" (today): the stage takes the unwrapped value; option<term> is refused.
private option<int> Fetch(int id)
Fetch(0) -> :nothing
Fetch(n) -> n

private option<int> Double(int v)               // v is int
Double(v) -> v * 2

public option<int> Load(int id)
Load(id) -> Fetch(id) |?> Double()              // Load(4) = 8, Load(0) = :nothing
```

```csharp
// Under "always tagged": option<term> compiles, and Double has to take the tag.
private option<int> Double((:some, int) v)      // the documented stage shape is refused:
Double((:some, v)) -> (:some, v * 2)            //   "Load hands Double an argument it does not accept"
                                                //   (64g, TaggedNarrow)
public option<int> Load(int id)
Load(id) -> Fetch(id) |?> Double()              // Load(4) = (:some, 8)
```

The valve still stops on `:nothing` in both. What changes is that it hands the stage `(:some, int)` rather than
`int` (64g), so `LANGUAGE.md:1953`'s "a chain of lookups that may find nothing is the shape the valve was borrowed
for" stops reading the way it is written.

## Sub-decisions, in dependency order

| # | Sub-decision | Status |
|---|---|---|
| S1 | Does `option<T>` stay bare for every `T`? | **Gating.** Everything below follows |
| S2 | If bare stays: what does a term-element lookup return (`Map.?Get` over `map<string, term>`, `List.?First` over `list<term>`)? | Follows S1; options A and B |
| S3 | The inferred-instantiation hole (64i): refuse it at the call? | **Independent defect**, not a design choice. Needs a ticket. Moot under C |
| S4 | `result<T, E>` at `E = term` (ticket Q3) | **Answered by probe**: not reached; the reach is `T` containing `(:error, E)` (64a) |
| S5 | `ToExistingAtom` (PRELUDE's "owed") | Already closed by ticket 67 / F54 (`result<atom, string>`); nothing left here |

## What is measured about the refusal today (64a, 64i)

| Declaration | Result | Probe |
|---|---|---|
| `option<int>`, `option<binary>`, `result<int, binary>`, `result<int, atom>` | compile (controls) | C1–C4 |
| `option<term>`, `option<atom>`, `option<option<int>>` | refused: "`:nothing` is absorbed by …" | O1–O3 |
| `result<term, binary>`, `result<term, atom>` | refused: "`(:error, …)` is absorbed by `term`" | R1, R2 |
| **`result<int, term>`** | **compiles**, `int \| (:error, term)` | R3 |
| `result<(atom, term), atom>`, `result<(atom, binary), binary>` | refused (tuple contains the failure member) | Q1, Q3 |
| `result<(int, term), atom>`, `result<(atom, binary), atom>` | compile | Q2, Q4 |
| `option<list<term>>`, `option<map<string, term>>`, `option<(:ok, term)>` | compile | N5, N6, N8 |
| `option<term>` as parameter, record field, list element, map value | all refused, path named (`Go.x`, `Row.Note`) | P1, F1, L1, K1 |
| `type X = term \| reference` / `pid` / `port` / `:marker` | refused ("already a `term`") | 64h A1–A4 |

The diagnostic for `option<term>` already ends: `hint: tag it - (:some, term) | :nothing`. That shape compiles
today (64a C6). The diagnostic for `result<term, E>` ends: "narrow the success type until it cannot hold an
`(:error, ...)` of its own." Both hints were written by F31/F36; neither mentions a standard-environment spelling,
because none exists.

**What the collapse costs, executed (64b).** A lookup over `Map.FromList([("a", :nothing), ("b", :error), ("c", 5)])`:

| key | bare `term` lookup (`Bare`, compiles with no diagnostic) | tagged `(:ok, term) \| :error` (`Lookup`) |
|---|---|---|
| `"a"` (stored `:nothing`) | `:absent` **(wrong)** | `:present_nothing` |
| `"b"` (stored `:error`) | `:present` | `:present_error` |
| `"c"` (stored `5`) | `:present` | `:present` |
| `"zzz"` (missing) | `:absent` | `:absent` |

The control is the bare column's row `"c"` and `"zzz"`, which are right. The failure is only at the stored
sentinel, which is why a test that stores ordinary values never finds it.

## The three options

### A — Keep `option<T>` bare. Term-element lookups are refused with a repair, or hand-rolled. Close the inference hole.

```csharp
// What an author writes today for the three motivating cases (Plug assigns, jsonb, Req headers).
// Measured: 64b. Compiles; all four keys answer correctly.
using :maps {
    (:ok, term) | :error find(string key, map<string, term> m)
}

Current(ss, t) -> :maps.find(t, ss) switch {
    (:ok, s) => s,
    :error   => (:error, :no_session)
}
```

**Compiler delta.** No new type, no change to `option<T>`, `result<T,E>`, the valve, F61, F39 or any existing
program. Concrete work:

- `bs_check.erl` `checked_call_typed/7` (the clause at `:4427` taking a `{poly, …}` template). After `solution/2`,
  run the F36 predicate over the declared return's *surface* members with `Sub` applied, and raise the existing
  `absorbed_member` diagnostic at the call line. Today `subst_tpl({t_union, Ms}, S)` (`bs_check.erl:1015`) calls
  `bs_types:union/1`, which erases the member boundary before anything can ask. The pieces already exist:
  `each_member/5` (`:1211`) and `absorbed/2` (`:3424`). That function is where ticket 68 found that a
  parametric *alias* is already checked at instantiation (68, "Blast radius": `scan_ty/4`'s `t_generic` clause);
  a polymorphic *function* is the case it did not look at.
- When ENG-324 builds `Map.?Get` and the `List.?…` rows, they inherit that check. A term-valued call is refused
  at the call with the existing words, and the hint (`bs_diag.erl`, `absorbed_member` message) gains a sentence
  naming the `using :maps { … find … }` shape.

**Evidence for.** The hand-rolled shape works and is exhaustiveness-checked (64b, 64c). Blast radius is zero: it
touches no existing program. The cost of the refusal is paid only by authors whose value type is exactly `term`.
Elixir and Erlang draw the same line for their own term-valued case: `Map.fetch/2` and `maps:find/2` return the
tagged shape (64f; `map.ex:303-304`, `maps.erl:138`), while the bare, default-argument form is documented but
collapses (64f).

**Strongest counterargument.** The three cases ticket 48 motivated the map type with (Plug `assigns`, a decoded
`jsonb` document, Req's headers) all carry `term`. Under A, the decided-but-unbuilt `Map.?Get` is unusable on
exactly those, and every author re-declares the same `using :maps { (:ok, term) | :error find(…) }` block. That is
a foreign declaration for an operation the standard environment is supposed to own (96 Q3, 108). The cost is
real and recurring, and A defers it rather than answering it. I did not count how many term-valued maps real B#
programs will have, because none exist yet. The one `maps:find` use in the repo,
`compiler/examples/exemplars/25g-jev-server/triage_crash.bs:21`, is already this shape.

### B — Add an always-tagged prelude sibling, and make the element-generic `?` rows return it. `option<T>` itself is untouched.

```csharp
Current(ss, t) -> Map.?Get(ss, t) switch {          // ss : map<string, term>
    (:some, s) => s,
    :nothing   => (:error, :no_session)
}
```

A user can already write the type: `type Maybe<T> = (:some, T) | :nothing` compiles, works at `term`, nests
(`Maybe<Maybe<int>>` keeps both layers, 64c `Deep`), and removing a switch arm is refused as non-exhaustive
(64c `Missing`). A lowercase `maybe<T>` is not writable by users: `type maybe<T>` is a syntax error (64c), because
prelude entries are lowercase and `type` takes PascalCase (`LANGUAGE.md:1618`).

**Compiler delta.**

- `bs_check.erl:1352` `stratum_one/0`: one new entry,
  `maybe => {parametric, ['T'], {t_union, [{t_tuple, [{t_atom, some}, {t_ref, 'T'}]}, {t_atom, nothing}]}}`.
  Whether the name is `maybe`, `some`, or something else is a naming question this brief does not answer.
- The `?` rows over an element type (`Map.?Get`, `Map.Find`, `List.?First/?Last/?At/?Max/?Min/?MaxBy/?Find`: 8–9
  rows, 96:223-224 and 108) declare `maybe<T>`. `Process.?Whereis` (`option<pid>`) and `System.?Env` keep `option<…>`:
  their element can never absorb `:nothing`.
- **This reverses a decided sentence.** Ticket 108's decisions entry says "Return types unchanged: `option<T>` for
  a lookup". B needs 108 reopened, so it is David's call, not a feature's.

**Evidence for.** Uniform: one return shape for every `V`, so a generic function wrapping `Map.?Get` cannot
change representation with its element type. A type-dependent return (`option<V>` unless `V` absorbs, then
`maybe<V>`) was considered and rejected on that ground. Cost is one prelude entry plus a row table. A tagged
success is what all three BEAM neighbours use for lookup (survey below).

**Strongest counterargument.** It splits absence into two spellings in one standard environment: `option<T>` for
declarations and `Process.?Whereis`, `maybe<T>` for collection lookups. And it breaks the exact example 108 wrote
for `Map.?Get`: `Map.?Get(ss, t) |?> F()` hands `F` a `(:some, v)` (64g), so `F` is declared over the tuple, not the
value. The valve is borrowed from C#'s `?.` (`LANGUAGE.md:1953`); a lookup chain is its stated use case, and under B
the lookup is the one place it stops reading like `?.`.

### C — Tag `option<T>` itself (Gleam's shape). `option<T> = (:some, T) | :nothing` for every `T`.

**Compiler delta.** This is the large one; the measured surface:

| Where | Size | Why it moves |
|---|---|---|
| `bs_check.erl:1352` `stratum_one/0` | 1 entry | the definition |
| Valve: `bs_lower.erl:70-91` (F30) | the `:nothing` arm is emitted unconditionally, and the stage receives the residual | needs an unwrap rule or the stage sees `(:some, v)` (64g) |
| `ValidateAs` absent-key fill: `bs_emit.erl:2349-2366`, `:2431` (F61) | `optional/1` and the `Defaults` map | a present JSON value at an option field must now be **wrapped** on validate and **unwrapped** by `ToJson`; today validate passes present values through unchanged |
| `ParseAtom<T>`: `bs_check.erl:3137`, `:3455`; `bs_emit.erl:996` (F39) | `T \| :nothing` result | result becomes `(:some, atom) \| :nothing` |
| `failure_channel/1`, `bs_check.erl:1221` | the `nothing` hint | the tagged shape cannot be absorbed; this hint dies with the check |
| Examples | **11 `.bs` files** use `option<` or `:nothing` (18 + 19 lines) | each pattern and construction changes |
| Tests | **21 test files** (52 `option<` lines, 76 `:nothing` lines) | counted by `grep` across `compiler/test` |
| Docs | `LANGUAGE.md` 26 + 31 lines, `STANDARD-ENVIRONMENT.md` 6 + 4, `TOUR.md` 8 + 9, `compiler/features/*.md` 105 + 114 | prose and gated code blocks (`check-language.sh`, `check-tour.sh`) |
| Decided but unbuilt: every `?` row (108) | 14 rows | all would be built tagged |

**Measured runtime cost (64d, OTP 28.5, x86_64, a shared cloud VM).**

| | bare | tagged | note |
|---|---|---|---|
| one present small int | 0 words | 3 words | `erts_debug:flat_size` |
| one present binary | 3 words | 6 words | |
| absent | 0 words | 0 words | the atom `nothing` in both |
| list of 10⁶ options, 3⁄4 present | 2,000,000 words | 4,250,000 words (+112.5%) | |
| same list, `term_to_binary` | 5,999,431 B | 11,999,431 B (+100%) | |
| consume 10⁶ (25 runs) | min 3,320 / med 4,591 / max 7,028 µs | min 9,058 / med 10,509 / max 14,428 µs | **spreads do not overlap**; 2.3–2.9× across my two runs |
| produce 10⁶ (25 runs) | min 11,074 / med 36,821 / max 80,959 µs | min 24,969 / med 29,642 / max 261,232 µs | **spreads overlap heavily (GC noise); no difference resolved** |

The asm confirms the shape (64d, `erlc -S`): the bare consumer is one `is_eq_exact` against `nothing`; the tagged
one adds `is_tuple`, `is_tagged_tuple` and a `get_tuple_element`. I measured a million-element list because that is
the largest realistic case; a typical option is a handful of values, where 3 words is noise. The finding is that C
has a measurable per-value cost and A and B have none for code that does not use them.

**Evidence for.** It is the only option under which the collapse class cannot exist: no declaration, written or
inferred, can absorb a tagged member. S3 disappears; so do F31, F36's option half, and the hint. It matches Gleam
(`option.gleam:19-21`), Elm (`Maybe.elm:39-41`) and Elixir's own `fetch` (`map.ex:303-304`). Gleam's
`decode.optional_field` tells absent from "present holding an atom named `nothing`" at `Dynamic` (64e).

**Strongest counterargument.** It pays everywhere to fix one corner, and the corner has two working repairs today
(A). It reverses ticket 15's decision that `option<T>` is "an ordinary parametric alias" holding the bare
value (15 line 125), and rebuilds three shipped features (F30, F39, F61). And it removes the pipe operator's
selling point for the thing that is most of its use.

### Considered and rejected on evidence: a sentinel "outside `term`" (the ticket's "refinement/opaque" idea)

64h asks the current lattice for a member outside `term` and gets "already a `term`" for every opaque kind and a
fresh atom (A1–A4). The unique-reference idiom Erlang programmers use is safe only while the sentinel is never
stored; once stored it reads back as absent (64h, treatment). Making it sound needs a new lattice bucket that
`term()` (`bs_types.erl:216`) excludes: roughly 40 sites mention `opaques` (27 in `bs_types`, 6 in `bs_check`,
7 in `bs_emit`), and runtime membership cannot be tested, since every BEAM value is a term. That is Option C's
tagging, enforced statically instead of dynamically, at a larger price.

## Neighbour survey (real sources; `path:line` read before citing)

| Language | The lookup | Absent vs stored sentinel at its top type | Source |
|---|---|---|---|
| Gleam | `dict.get -> Result(v, Nil)` | **distinguishes** at `Dynamic`; `Option(a) = Some(a) \| None`; erlang repr `{some, X}`, `{ok, …}` | `stdlib/src/gleam/dict.gleam:165`, `option.gleam:19-21`, `gleam_stdlib.erl:42-46`, `decode.gleam:452-454, 581-597` |
| Elixir | `Map.get/3` returns the default; `Map.fetch/2` returns `{:ok, v} \| :error` | `get` **cannot** (`Map.get(%{a: nil}, :a)` = `Map.get(%{}, :a)` = `nil`); `fetch` can | `map.ex:531-532` (get), `:303-304` (fetch); 64f |
| Erlang | `maps:get/3` with default; `maps:find/2` → `{ok, V} \| error` | same split | `maps.erl:686`, `:138`; 64f |
| Elm | `Dict.get : comparable -> Dict comparable v -> Maybe v`; `Maybe a = Just a \| Nothing` | **source-read only**: Elm has no top type, so the question cannot arise; `Maybe (Maybe a)` keeps both layers by construction | `core/src/Maybe.elm:39-41`, `Dict.elm:94` (elm/core `65cea00`) |

Gleam's `Dynamic` is the closest analogue to B#'s `term`, and the evidence is that a tagged `Option` makes the
question vanish there (64e). Elixir is the counter-example for the *bare* form: its documented default-argument
`Map.get` is the collapse, and its own docs steer to `fetch` for the ambiguous case. The three BEAM languages agree
on a tagged **lookup**. Only Gleam also tags the general optional. A bare general optional is B#'s own choice
(ticket 15), and it is what the valve keys on.

## Evidence ledger

| Probe | Claim tested | Control | Result | Does **not** show |
|---|---|---|---|---|
| 64a | which declarations are refused, with which words; Q3 | `option<int>`, `result<int,_>`, tagged shapes compile | table above | positions beyond signature/param/field/list/map; refusal inside `ValidateAs<T>` targets |
| 64b | bare lookup silently conflates; tagged does not | `Bare` vs `Lookup`, same data | `"a"` stored `:nothing` → `:absent` in `Bare` only | anything about `Map.?Get`, unbuilt |
| 64c | user `Maybe<T>` works at `term`, nests, is exhaustiveness-checked | `Missing` (arm removed) refused; lowercase `maybe` refused | all as stated | that a *prelude* `maybe` has no new corner (valve, `ValidateAs`, `--api`) |
| 64d | words / bytes / time / asm, bare vs tagged | both compute the same sum | table above | JIT code size; `option<T>` for non-int `T` at scale; cold call sites |
| 64e | Gleam distinguishes at `Dynamic` | stored `nothing`/`none`/`Nil` vs `None` | all four stored sentinels read "present" | Gleam's JS target |
| 64f | Erlang/Elixir bare default collapses; `find`/`fetch` do not | tagged form beside the bare form | as stated | anything beyond maps and keyword lists |
| 64g | valve over bare vs tagged | `TaggedNarrow` (documented stage shape) refused | stage receives `(:some, int)` | a valve that unwraps (not built; that would be new work) |
| 64h | no sentinel outside `term` in the current lattice; stored ref sentinel reads absent | `int \| reference`, `binary \| :marker` compile | A1–A4 refused; treatment reads back as absent | the design cost of a new lattice bucket, estimated from `grep` only |
| **64i** | **inferred `T = term` is not refused** | `list<int>` calls; written `option<term>` refused (64a) | `Empty([:nothing])` = `:empty`; `Outcome([(:error, :boom)])` = `:failed` | that this is unintended: no ticket text says whether "instantiation" includes inference |
| 64j | compile time, `option<int>` vs `Maybe<int>` | same six functions | min/med/max 402/438/502 ms vs 415/460/627 ms (n=30) | **no difference resolved**: spreads overlap, and the medians flipped between my two runs; escript start-up dominates |
| 64k | Elm | n/a | **blocked**: `package.elm-lang.org` is 403 through the proxy | everything Elm runs; Elm claims are source-read only |

## Not measured, and caveats

- **Elm was not executed.** Its rows are source-read.
- Timings are on a shared VM; the produce-side comparison is unresolved, and I report the consume side only because
  its ranges do not overlap. Absolute numbers will differ on other hosts.
- The repo pins OTP 28.5 (`.tool-versions`). I built that from source, so versions match. The Elixir version
  (1.19.5) is mine; the repo does not pin one.
- I did not count real-world term-valued maps (no B# programs of that kind exist). Option A's counterargument rests
  on ticket 48's own three cases, not on a measured frequency.
- Option C's blast radius is counted by `grep` across `compiler/examples`, `compiler/test`, the docs and the feature
  files. I did not prototype C, so the "what each program must change" column is an estimate from the matches.
- 64i is a finding, not a ruling: whether "an instantiation is rejected at the declaration" (`CONTEXT.md`) covers
  inference at a call is a question for you or for a ticket. CLAUDE.md's rule applies: I grepped `wayfinder/issues`
  and `compiler/features` for `instantiat` and `polymorphic` (ticket 68 and F31 only cover written parametric
  aliases) before calling it unaddressed.

## Recommendation

**Option A, plus the inference fix as its own ticket.**

- The gating answer is "bare stays". The valve is the one place `option<T>` is exercised the way it was designed,
  and the blast radius of C (11 example files, 21 test files, three shipped features) is large for a defect that
  affects a single type, `term`.
- A leaves nothing broken that works today and fixes the one thing that is silently wrong (64i).
- **What would change this:** if you read the three motivating cases as common, so that `Map.?Get` over
  `map<string, term>` is the usual lookup rather than the corner, B is the next step and needs 108 reopened. The
  natural moment to decide is when ENG-324 builds `Map.?Get`: by then there are real `map<string, term>` call sites
  to count instead of three examples. I would not pre-build the sibling before that.
