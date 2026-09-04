# 48 — A map type in the prelude: opaque, matchable, or not at all?

Type: grilling
Status: **resolved 2026-08-25** — [ENG-230](https://linear.app/davewil/issue/ENG-230). Survey landed
2026-08-25 ([research](../research/48-map-type-prior-art.md)); probes
[`48f`](../prototypes/48f_brace_map_type_and_pattern.sh)–[`48m`](../prototypes/48m_elixir_maps_under_descr.exs)
falsified five of this file's own claims and priced both sides of question 1. **All nine questions
are answered** — see *DECIDED … the remaining six* and *DECIDED … Q9* below, and the file's own
verdict: *"Ticket 48 is answered."*

> *Header corrected 2026-08-26. It read `claimed … Q3 and Q4 remain open` for a day after the body
> recorded every answer, and ENG-230 stayed `In Progress` beside it — so both trackers called a
> finished ticket in-flight. The sections below are the record; this line was simply never updated
> when they landed. Two consequences were also owed and are now discharged: Q3's settlement of
> [ticket 50](50-naming-a-foreign-struct.md) is recorded there, and Q6's new ticket is 64.*

> **The ticket-to-issue arithmetic is dead, and this is a third data point.** 48 is ENG-230,
> not the ENG-214 that `CLAUDE.md`'s `166+NN` rule predicts. Read the number, never compute it —
> tickets 46 and 47 recorded the same thing.

Raised 2026-08-21 by David while [ticket 31](31-composable-middleware.md) was resolving:
*"probably want to add map to prelude"*.

## Question

There is no map type. The prelude has `list<T>`, `option<T>` and `result<T, E>`, and
`Assigns: map<atom, term>` is refused at the declaration:

> `error: no type named map takes a type argument` — *the prelude has `list<T>`, `option<T>` and
> `result<T, E>`; your own take one with `type map<T> = ...`.*

Ticket 31 §4 found this while writing Plug's `conn.assigns` — an open key/value channel every
middleware stage writes into without coordinating with the others. **It is not blocking**:
`list<(atom, term)>` compiles and carries the same state, declared centrally once, after which a
stage prepends its own key without the record growing. The cost is that values are `term` and
lookup is a list walk.

So the question is not whether the gap exists. It is:

**Should `map<K, V>` be in the prelude, and if so does it have a pattern form?**

## What is already measured, and what it removes from the question

[`prototypes/31e_elixir_maps_vs_structs.exs`](../prototypes/31e_elixir_maps_vs_structs.exs) —
Elixir 1.19.5, `Module.Types.Descr`, the instrument tickets 10 and 15 used.

| measured | result |
|---|---|
| Is a map *pattern* open or closed? | **open** — `closed %{a: int}` is a subtype of `open %{a: int}`, not the reverse |
| Two structs, identical fields, disjoint? | **yes**, on the `__struct__` tag alone |
| Does an open map pattern match a struct? | **yes** — `%Order{}` is a subtype of `open %{a: int}` |
| Does closing the map exclude the struct? | **yes** |
| Can a map type declare the tag key **absent**? | **yes** — `open %{a: int, __struct__: not_set}` is disjoint from `%Order{}` *and* still admits plain `%{a: 1}` |

**This kills the objection that looked fatal.** A record erases to a map carrying a minted `Kind`
(ticket 26), so the worry was that a map pattern would silently also match records and dissolve the
tag that gives aggregates their identity. The last row shows the opposite: the tag is exactly what
keeps them apart. `map<K, V>` would be internally *"open map, `Kind` absent"* — disjoint from every
record by construction, needing no new discriminability rule. Row 2 also confirms ticket 26's own
argument against a shipping implementation that made the same call for the same reason.

**What survives — and it is narrower than this paragraph first claimed.** Where a map's key set is
**open**, a pattern over it never closes a residual, so a catch-all is always legal there (ticket
12's rule) and exhaustiveness over it is vacuous. Elixir pays nothing for that because it never
promised exhaustiveness; beam-sharp would be adding its first type over which the headline
guarantee says nothing.

> **Corrected 2026-08-25 by [`48g`](../prototypes/48g_map_exhaustiveness_not_vacuous.sh), which
> ran it.** This paragraph used to assert *"Exhaustiveness over a map is **vacuous**"* flatly, and
> that is false of the map beam-sharp **already ships**. A brace map is keyed by a fixed set of
> PascalCase field names (`bs_parser.yrl:98`, `:490`), so its key set is **closed**: the compiler
> refuses a map pattern that lacks a catch-all and prints the residual —
> `Kind({ Status: _ }) -> ...` — as precisely as it does for the closed union standing beside it
> as a control. The vacuity cost is real, but it attaches **only to the unbounded key domain this
> ticket is actually asking for**, which is the new thing. Scoping it correctly matters, because
> the cost was being charged to the pattern form, and the pattern form is already built.

> **Corrected 2026-08-25 by the survey — that last clause attaches to the wrong scope.** The
> unbounded-key-domain half is confirmed and measured
> ([`48a`](../prototypes/48a_map_forms_erlang_elixir.sh) §4: the fall-through clause `#{}` matches
> every map, including maps lacking the key the previous clause asked for). But *"beam-sharp would
> be adding its first type over which the headline guarantee says nothing"* is a cost of
> **candidate 2 alone**, not of having a map type. Gleam has a map type and does not pay it,
> because it has no map *pattern*: the only pattern over a `Dict` is a variable, total by
> construction, so the checker is never asked. Absence moves into the value domain instead —
> `dict.get` returns a `Result`, a closed two-constructor union the checker *can* see
> ([`48b`](../prototypes/48b_gleam_dict_opacity.sh) §4–5). Under candidate 1 the guarantee stays
> total everywhere, and the prelude already ships the return type that makes it work. **The
> objection that reads as fatal to "a map type" is an objection to "a map pattern".**

## There are two tags, not one — measured 2026-08-25

> **Written under the working name `dict`, renamed in place 2026-08-25 when Q4 chose `map<K, V>`.**
> David's raising quote below is left verbatim, as are every reference to Gleam's `Dict` and the
> measurement that `map` and `dict` refuse identically today.

Raised by David while reading the survey: *"if I name map type dict in B#, does the interop with
Elixir hold on struct/record types?"* The name does not reach the wire — `map<K, V>` erases to the
same BEAM map whatever it is called — but the question underneath is real, and this ticket's
proposal had only ever considered **one** tag.

    a B# record      is a map carrying   Kind        => :'MyApp.Response'
    an Elixir struct is a map carrying   __struct__  => :'Elixir.Req.Response'

Different atoms. So *"open map, `Kind` absent"* — this ticket's wording above — says **nothing at
all** about `__struct__`. Measured on the `Descr` instrument
([`48e`](../prototypes/48e_dict_vs_two_tags.exs), four controls first, both `true` and `false`
reachable on each predicate):

| | `map` = *`Kind` absent* | `map` = *both tags absent* |
|---|---|---|
| disjoint from a B# record | **yes** | **yes** |
| admits a plain map | **yes** | **yes** |
| **admits an Elixir struct** | **YES** | no — disjoint |

**So the choice is real and both options work.** This is a decision, not a constraint:

- **`Kind` absent only.** A foreign struct *is* a `map`, so
  [ticket 50](50-naming-a-foreign-struct.md)'s candidate 2 — *"read the struct as an ordinary open
  map, keys narrowed at use"* — works with no extra surface. The price is that `map` stops meaning
  "not somebody else's aggregate": `Req.get!()`'s return value type-checks as `map<atom, term>`.
- **Both tags absent.** `map` means what it says, and a foreign struct is not one. The price is
  that reading a foreign struct then needs somewhere else to land, and the obvious candidate does
  not work: an **unrestricted** open map admits a B# record *and* an Elixir struct (measured), so it
  cannot tell them apart. 50's candidate 2 would need its own type rather than reusing this one.

One reassurance from the same run: **a B# record and an Elixir struct are disjoint from each other**,
so the two-tag scheme is sound in itself. The question is only which of them `map` is allowed to
overlap.

<!-- the ex_struct shape is modelled on 51a's real measurement of 2026-08-21: Req's value carries __struct__ and does not carry Kind -->

**This is the joint between 48 and 50**, and it is the concrete reason 50 asks to be resolved
alongside this one rather than after it.

## The three candidates — the axis is wrong, measured 2026-08-25

> **These are not three points on one axis, and running them is what showed it.**
> [`48f`](../prototypes/48f_brace_map_type_and_pattern.sh) went to price candidate 2 and found it
> already paid: beam-sharp has had an anonymous map **type** and a map **pattern**, spelled with
> **bare braces**, since F3. They compile, they dispatch (`:ok` on `200`, `:other` on `404`), and
> the catch-all beside them is not merely legal but *live* — it fires. `Auth({ User: :anonymous })`
> in the 31d middleware prototype has been one all along, without being called a map.
>
> So *"should a map be matchable"* is not an open question. What is missing is a key that is a
> **value** rather than a PascalCase field name, and behind it an **unbounded key domain**.
> [`48i`](../prototypes/48i_key_position_takes_no_value.sh) pins that: all three brace forms take
> the single terminal `uident` in key position (`bs_parser.yrl:98`, `:490`, `:702`), and a string,
> a lowercase name, an atom literal and a pinned variable are each refused **at the parser** —
> while the same pin runs one position to the left. Both wants are gated by one line,
> `bs_types.erl:99`, where `map_member()` is `{closed | open, #{atom() => ty()}}`: keys are atoms
> end to end, and every intersection, subtraction and absorption routes through an atom-set
> comparison (`bs_types.erl:735-738`). A parser change alone would emit a key with nowhere to land.
>
> **The three are kept below as the record of how the question was framed**, not as the menu the
> grilling chose from. The live axis is: does the key domain become unbounded (the expensive
> question — new algebra, not a table entry), does the pattern form extend to it (the machinery is
> built), and does expression-level construction land with it (three files, no lexer change).

1. **Opaque, Gleam-shaped.** `map<K, V>` with `Get`/`Put`/`Delete`/`Keys` as compiler-known
   functions and **no pattern form**. Records stay the only brace-pattern surface; the pattern
   grammar, the residual algebra and the catch-all rule are all untouched. ~~Gleam's `Dict` is this,
   deliberately.~~ **Both of those words are wrong, corrected 2026-08-25 by the survey.** Gleam's
   `Dict` is not `opaque` — that is a real Gleam keyword meaning *constructors exist but are
   module-private*, and `Dict` is declared `pub type Dict(key, value)` with **no constructors at
   all** and `@external` operations. And *"deliberately"* asserts an intent **no primary source
   states**: the behaviour is documented, the reason is not. Gleam's `Dict` is this shape, shipped,
   without a published argument. Keep the candidate; drop both claims about why.

   **And its operations have nowhere to live — measured 2026-08-25.** This candidate is *defined
   by* its operation set, and beam-sharp has no mechanism to ship one. There is no prelude of
   callable functions: `prelude/0` (`bs_check.erl:706`) holds **types** only, and `callees/3`
   (`bs_check.erl:520`) is built from local signatures, `foreign` declarations and qualified
   imports — nothing injects a prelude entry. Nor could an unqualified call reach one:
   `unqualified_key/4` (`bs_check.erl:2129-2144`) resolves local, then the `using` import table,
   then fails — there is no prelude step. `ValidateAs<T>`'s generator cannot host `Get`/`Put`
   either, because that machinery keys on the resolved type inside the angle brackets and
   `Get(m, k)` has none. `List.Sum` is not compiler-known; it is an ordinary `.bs` file.
   **So the option the survey called a shipped precedent is the one that needs a new subsystem
   here, while candidate 2's machinery is already running.** That inverts the cost model this
   ticket was working from.
2. **Matchable, Erlang-shaped.** A pattern form in clause heads. ~~Now known to be *possible* — the
   `Kind`-absent construction keeps it off records — at the price that matching a map proves
   nothing.~~ **This candidate is not a proposal; it is a description of the compiler.** Measured
   2026-08-25 by [`48f`](../prototypes/48f_brace_map_type_and_pattern.sh): the pattern form ships,
   and `pattern_type/3` already carries a *"closes nothing"* flag with three precedents
   (`p_bin`, `p_str`, `p_eqvar`, `bs_check.erl:2323` ff.) while `m_minus({open,_},{closed,_})`
   already keeps a map residual open. The price *"matching a map proves nothing"* is **not** being
   paid today, because today's key set is closed — see the correction above. It would be paid on an
   unbounded key domain, and that is the only place it applies.
3. **Not at all.** `list<(atom, term)>` already carries the case that raised it.

## The bar this has to clear — cleared on the exemplar arm, 2026-08-25

**The destination is a clean-room spec.** Every construct is a section an agent fleet implements
from prose without David in the room, and a matchable map is the paragraph most likely to be got
wrong — it is the one place the language's headline promise goes quiet, and the reader has to be
told why without concluding the promise is soft everywhere.

So the test is the one that cut function values: [ticket 27](27-parametric-polymorphism.md) §(c)
was cut on three measurements and one of them was flatly **"no exemplar declares one"**
(→ [ticket 37](37-instantiation-by-matching.md)). Same test here.

**That test is now passed, by a different exemplar than this ticket predicted — 2026-08-25.**
This paragraph used to say *"blocked by evidence that does not exist yet"* and nominate the **25a**
pipeline rewrite as the gate. That rewrite has still not happened, and it is no longer the gate:
[`25d`](../prototypes/25d-database-querying.md), the database exemplar written 2026-08-24, wants a
map **three times** without one, and says so in its own words — *"this exemplar wanted one and
worked around it, which is the sharper datum"*.

| where 25d wanted a map | what it did instead |
|---|---|
| `epgsql:connect/1` takes a **map** of options | passed a proplist — a legacy form the library still accepts. **It compiled by luck**: the idiomatic configuration literal of every modern BEAM library is the one literal B# does not have |
| a decoded `jsonb` document | stayed `term`. *What type it would be* is this ticket's question, reached from a second direction |
| group-by on an **open** key (`string`) | an assoc list of pairs built by hand, O(n) per lookup. **A closed key is a record; an open key is this ticket, and nothing in between exists** |

Add 25a's front wall — anonymous map **construction**, recorded in `FRONTIER` as `#{ ... }` — and the
exemplar arm has four independent demands from two exemplars. So the ticket-27 §(c) test that this
paragraph set up (*"no exemplar declares one"*) does not cut the map: real code asked for it and
paid to go around. Maps are extremely familiar from Elixir, which is why they would otherwise slip
in without paying the toll — the toll is now paid on this arm, and **owed on the survey arm below**,
which is what remains before this resolves.

> **The `FRONTIER` wording is a foreign spelling — corrected 2026-08-25 by
> [`48j`](../prototypes/48j_the_two_walls.sh).** Recording the wall as *"`#{ ... }`, the anonymous
> map literal"* names an **Erlang** form. beam-sharp spells anonymous maps with **bare braces** at
> the type and pattern levels (48f), and `#` is *absent* from `bs_lexer.xrl` rather than excluded —
> it appears there only inside comments about C#. Adding `#` would give the language a second
> spelling for a construct bare braces already serve at two of three levels.
>
> The wall is at the **third** level: there is no bare-brace **expression** production. Measured —
> `{ Status = 200 }` in expression position is `syntax error before: '{'`, because
> `bs_parser.yrl:696` is `expr -> uident '{' assign_fields '}'` and requires a record name in
> front. So 25a's front wall is anonymous map **construction**, and it is three files with no
> lexer change: an expr rule plus an `e_map` node, a `type_of` clause beside `e_record`'s, and an
> `expr` clause in `bs_emit`.

## Surveyed — 2026-08-25

Done, and every arm **run** rather than read:
[`research/48-map-type-prior-art.md`](../research/48-map-type-prior-art.md), from
[`48a`](../prototypes/48a_map_forms_erlang_elixir.sh) (Erlang/Elixir, OTP 28),
[`48b`](../prototypes/48b_gleam_dict_opacity.sh) (gleam 1.18.1) and
[`48c`](../prototypes/48c_csharp_dictionary_forms.sh) (dotnet 9.0.306).

| | Erlang | Elixir | Gleam | C# |
|---|---|---|---|---|
| matchable in a clause head | yes | yes | **no** | on properties only, never on keys |
| enforces exhaustiveness | no | no | **yes — refuses to compile** | no — warning only |
| absence of a key is | a failed clause | a failed clause | **a returned value** | an exception or `TryGetValue` |
| the type is called | `map` | `map` | `Dict` | `Dictionary` |
| the map *function* is called | `lists:map` | `Enum.map` | `list.map` | `Select` |

**The one surveyed language that shares this ticket's problem is also the only one with no map
pattern.** Gleam is the only source that enforces exhaustiveness — `48b` runs that as a control
before anything else and it goes red (`Inexhaustive patterns … The missing patterns are: Blue`) —
and the only one you cannot match a map in. Absence moved to the value domain instead, where the
checker can see it: `dict.get` returns a `Result`. That is candidate 1, shipped.

Two precisions the survey insists on, both of which change how candidate 1 should be written:

- **`Dict` is not `opaque`.** `opaque` is a real Gleam keyword — a custom type whose constructors
  exist but are module-private. `Dict` has none to hide: it is declared `pub type Dict(key, value)`
  with no constructor list and `@external` operations. Patterns destructure constructors, so there
  is nothing for one to take apart. Candidate 1's *effect* is right; its mechanism is **"a type with
  no constructors, implemented externally"**, not "a type whose constructors are hidden".
- **Correction — "candidate 1 with the reasoning already done" is not true.** The behaviour is
  documented (*"There is no dict literal syntax in Gleam, and you cannot pattern match on a dict.
  Dicts are generally not used much in Gleam, custom types are more common."*) but **no primary
  source gives a reason**, and specifically the exhaustiveness argument is nobody's but ours. The
  FAQ's twelve rejected features do not include map patterns; there is no feature request and so no
  rejection. Candidate 1 is a **shipped precedent with no published argument** — still worth a lot,
  since a language promising exhaustiveness has lived without map patterns for years, but the
  grilling must supply the argument rather than inherit it.

**Correction — the `:=` / `=>` premise this section used to carry was wrong.** It said the
distinction was *"a form beam-sharp has no equivalent of"*, implying a pattern form. Measured
(`48a` §1–3, §5): `=>` is **illegal** in an Erlang pattern — `illegal pattern, did you mean to use
':='?` — `:=` is **illegal** in an Erlang construction, and `:=` **is not an Elixir operator at
all**. The two meet in exactly one place, Erlang's *update* expression, where `:=` demands the key
exist (`{error,{badkey,k}}`) and `=>` inserts. **So it is an update form, not a pattern form.**

The survey's own first draft then added *"and beam-sharp already has one — `with`"*, and that was a
claim about this compiler made without running it. Run
([`48d`](../prototypes/48d_with_is_record_only.sh)), it is false: `with` on a `list<(atom, term)>`,
on a `term`, **and on an `int`** are all accepted at exit 0, while `with` on a record with an
undeclared field is refused precisely (*"not declared by Order: NoSuchField"*). Three controls
establish the checker is looking. **`with`'s subject is unchecked** *(was — fixed 2026-09-03 under
ENG-249, and all three are now refused with the member that lacks the field)*, so its acceptance of
a list is a hole rather than support — beam-sharp has a *record*-update form, not a map-update one.
The arm
therefore relocates to a construct that **would have to be added**, which is a different input to
the grilling than "one that already exists".

**On the name, all three sources disagree, so this is tier 3, not the tier-1 borrow this section
assumed.** Erlang and Elixir call the type `map` and tolerate the collision with `Enum.map`; C#
calls it `Dictionary` and never had a collision, because LINQ took its verb from SQL and named the
function `Select` (`48c` measures both: fourteen BCL types say `Dictionary`, no collection type
says `Map`, `Enumerable.Select` exists and `Enumerable.Map` does not). Gleam is the one that had
beam-sharp's exact problem — BEAM host, a `map`-named list function — and it is the one that
changed the type's name, **for that reason, on the record**:

> "`Map` is a little confusing as it collides with the common map function. Let's rename it."

<!-- lpil, gleam-lang/gleam issue 2405, 2023-11-11; shipped as stdlib#510, deprecated in gleam_stdlib v0.33.0, removed in v0.35.0 -->

Note *"the common map function"* — the map/filter/reduce family in general, not `list.map`
specifically. The same release renamed `gleam/dynamic`'s `map` function to `dict`, which is what
tells you the driver was the name and not the data structure. ~~**This is the tie-break datum, and
unlike the pattern-form question it is a documented decision rather than a silent one.**~~ The choice
is still the grilling's to make.

> **The tie-break is disqualified, not overruled — measured 2026-08-25 by
> [`48h`](../prototypes/48h_map_name_is_free.sh).** A borrowed reason is worth what its premise is
> worth *here*, and Gleam's premise is that **one namespace holds both** the type and the
> map/filter/reduce family. beam-sharp does not share it. The prelude owns the lowercase namespace
> while user types and functions are PascalCase, and `bs_check.erl:710-712` states that as a
> decision: *"so the two cannot collide."*
>
> Both halves were run. `Map` declares, resolves **unqualified** through `unqualified_key/4`, and
> runs — `Uses(21)` → `42`. And a lowercase prelude type coexists with a PascalCase module of the
> same word in one file, which the shipped surface has been doing all along:
> `compiler/examples/Shop/Collections/List/List.bs:8-10` is `module Shop.Collections.List`
> declaring `public int Sum(list<int> xs, int acc)`. The control holds too — `Map<T, U>` is still
> `not-yet` (LANGUAGE.md:966-970) and refuses, so the collision has neither half.
>
> This matters more than a naming preference: it was **the one documented decision in the whole
> four-language survey**, and it does not reach this language. The name is therefore decided on
> accuracy rather than caution, and 48j confirms availability is not a factor either — `map` and
> `dict` refuse *identically* today, both for want of a prelude entry.

## Notes

Do not re-derive the record/map collision — it is measured above and it is not a problem. And do
not treat "Elixir has maps" as an argument; ticket 31 §6 is a worked example of a premise that
read as obvious and was wrong on inspection.

**Do not re-derive the pattern form either.** It ships. `48f` is the measurement; the failure mode
this ticket kept hitting was reasoning about the compiler instead of running it, and four separate
claims went false that way.

## Answer

**`map<K, V>` enters the prelude as a second map member kind — declarable, passable and
returnable, but not yet destructurable in a clause head — with `Map.Get` a compiler-known
operation under a qualifier the language reserves.**

All nine questions are answered. The detail is in the three `DECIDED` sections below, which are
kept as they were put because each records what David was asked and what he replied:

| | question | decision | where |
|---|---|---|---|
| **Q1** | does the key domain become unbounded? | **yes** — a second map member kind | *Q1 yes, Q2 type first* |
| **Q2** | one widened brace form, or a second? | **neither yet** — the type ships before the pattern form | *Q1 yes, Q2 type first* |
| **Q3** | which tag does it exclude? | **`Kind` absent only** | *the remaining six* |
| **Q4** | what is it called? | **`map<K, V>`** | *the remaining six* |
| **Q5** | where do the operations live? | a compiler-known operation, qualified spelling, inlined (17 §2) | *the remaining six* |
| **Q6** | does the `option<T>` collapse get fixed here? | **no — its own ticket** | *the remaining six* |
| **Q7** | is the shipped brace map a `map<K, V>`? | **yes, one type family** | *the remaining six* |
| **Q8** | what shape do the operations take? | **two, assertive preferred** | *the remaining six* |
| **Q9** | how is the operation spelled? | **`Map.Get`, with the qualifier reserved** | *Q9* |

**Two of this ticket's own premises were falsified on the way, and both corrections stand with
the decision rather than beside it.** Elixir does **not** reserve `Map` — it is an ordinary
module in a flat global namespace and the qualifier is unprotected, measured on Elixir 1.19.5 —
so reserving it here is beam-sharp's choice and not a borrowed one. And the argument that
unbounded keys make the language *more* exhaustive is backwards on its own terms: an open key
domain is the one place exhaustiveness cannot work, since no finite clause set closes the
residual. The decision stands on the corrected reason — **unbounded keys do not make the
language more exhaustive, they make an already-unexhaustive corner honest and typed**, where
today that corner is `list<(atom, term)>` with no checking at all.

The expensive half of this feature is matchability, not existence, which is why Q2 ships the
type first: a type no pattern narrows never reaches `m_decompose/3`, so deferring the pattern
form defers the permanently-mandatory catch-all and most of the algebra with it.

## DECIDED 2026-08-25 — the remaining six

David, closing round 3: *"Q3 yes, Q4 map, Q5 prelude, q6 own ticket, q7 yes, q8 two, assertive
preferred."*

| | question | decision |
|---|---|---|
| **Q1** | does the key domain become unbounded? | **yes** — a second map member kind |
| **Q2** | one widened brace form, or a second? | **neither yet** — the type ships before the pattern form |
| **Q3** | which tag does it exclude? | **`Kind` absent only** |
| **Q4** | what is it called? | **`map<K, V>`** |
| **Q5** | where do the operations live? | **corrected** — a compiler-known operation, qualified spelling, inlined (17 §2) |
| **Q6** | does the `option<T>` collapse get fixed here? | **no — its own ticket** |
| **Q7** | is the shipped brace map a `map<K, V>`? | **yes, one type family** |
| **Q8** | what shape do the operations take? | **two, assertive preferred** |

**Ticket 48 is answered.** What remains is consequences, and one of them is large enough to be a
new question rather than execution — see *Round 4* below.

**Consequences that are execution, not decisions:**

- **Q3 settles [ticket 50](50-naming-a-foreign-struct.md).** `Kind` absent only means a foreign
  struct **is** a `map<atom, term>`, so 50's candidate 2 works with no new surface. Record it there;
   50's candidate 1 stays unbuilt and keeps its measured silent trap, which is now a defect report
  rather than a design option.
- **Q4 renames this file's own prose.** The *"two tags"* section was written under `dict` and is
  renamed in place above, with David's raising quote, every Gleam `Dict`, and the measurement that
  both spellings refuse identically all left verbatim.
- **Q6 owes a new ticket**: `option<T>` and `result<T, E>` collapse at `T = term`, because their
  success case is the bare value and `:nothing` is an atom inside it. Not a map defect; a prelude
  one that maps merely expose.
- **Q8 owes a naming decision downstream**, and it is not free: `!` was settled out of B#
  identifiers, so the raising form needs a name that is not `Get!`. `PRELUDE.md` also lists `raise`
  as decided-but-unbuilt, so the assertive half may have no mechanism yet — that wants checking
  before the feature file is written, not after.
- **Q7 has a shape to borrow**: in `Descr` the named-key and open-key maps are the *same
  constructor with a different tag value*, not two constructors (`48m`).

> **Vocabulary corrected 2026-08-25, on David reading Elixir's `Kernel` page.** Q5, Q8 and Q9 were
> written calling this *"a function prelude"*, and that is wrong by `CONTEXT.md`'s own definition:
> a **prelude** is what is reachable *without import*, unqualified. `Map.Get` requires the `Map.`
> prefix, so it is not prelude — it is the **standard library**, a layer B# does not have yet and
> had no name for. Elixir draws the same line explicitly: *"You can invoke Kernel functions and
> macros anywhere in Elixir code without the use of the `Kernel.` prefix"*, while `Map`, `List` and
> `String` are *"the standard library"* and are not auto-imported. Both terms are now in
> `CONTEXT.md`, and Q5's answer reads **"the standard library's first module"** rather than
> "a function prelude".

## DECIDED 2026-08-25 — Q9: `Map.Get`, with the qualifier reserved

David: *"Elixir reserves or qualifies Map right? I'm ok with Map.Get as builtin/prelude"* —
option (a), qualified.

**The premise is false, and measuring it changes what (a) has to include.** Elixir does **not**
reserve `Map`. It is an ordinary module in a flat global namespace, and the qualifier is
unprotected. Measured 2026-08-25 on Elixir 1.19.5:

    defmodule Map do
      def get(_m, _k), do: :mine_not_stdlibs
    end

    warning: redefining module Map (current version loaded from .../Elixir.Map.beam)
    ** (UndefinedFunctionError) function Map.update!/3 is undefined or private
            (elixir 1.19.5) lib/module/types.ex:291: Module.Types.local_handler/5

A warning, then the user's module **clobbers the standard one**, and **Elixir's own type checker
crashes** — it was calling `Map.update!/3`. So Elixir's model is *first come, we warn*: the name is
qualified, the qualifier is not protected, and shadowing it is catastrophic rather than merely
confusing.

**So B# takes (a) and adds the part Elixir lacks: the qualifier is reserved.** `Map` becomes a name
a user cannot declare as a module, refused at the declaration with a diagnostic that says why.
That keeps the decision loud rather than silent, which is what the standing least-surprise
constraint asks for, and it is strictly better than the source it borrows from.

**Why reserving the qualifier beats the alternatives**, and it answers the objection that sank
option (c): reserving `Map` burns **one name per prelude module**, not a growing list of *function*
names. `Get`, `Put`, `Delete` and `Keys` never compete with user identifiers at all, because they
are only ever reached through the qualifier.

**Measured costs, all cheap today:**

| | |
|---|---|
| does anything declare `module Map`? | **no** — the name is free |
| does anything declare a bare `module List`? | only [`48h`](../prototypes/48h_map_name_is_free.sh), a probe, not shipped code |
| does B# already reserve any name? | **no** — this is the first. Ticket 08 reserved the `=>` **token**; no identifier or module name is reserved |

**One policy question this opens, and it should be settled once rather than per module.** The same
rule applied to the rest of the collection library reserves `List`, `String` and whatever else
`PRELUDE.md` eventually names. That is predictable and familiar — every language protects its
standard module names somehow — but it should be decided as a **policy** now, while the list is
empty, rather than one name at a time as each prelude module lands. The alternative to a growing
reserved list is a namespace the user's syntax cannot reach at all, which was Q9's option (d) and
remains available if the list ever gets uncomfortable.

## Where the grilling is — round 2 put 2026-08-25, undecided

**Round 1's six questions are withdrawn and replaced by these four.** Not because they were
answered — they never were — but because [`48k`](../prototypes/48k_widening_the_key_position.sh)
and the probes before it moved their prerequisites. Two of the six collapsed into others, and the
sub-question round 1 deferred as *"the sharpest thing left"* is now on the frontier, because 48i
and 48j settled what it was waiting for.

What changed, precisely:

- **Round 1's Q2 is gone.** Its stated cost — *"a catch-all becomes permanently mandatory there,
  the first such place in B#"* — was charged to the pattern form, and `48g` showed the shipped
  brace map already enforces exhaustiveness with a precise residual. That cost belongs to the
  unbounded key domain alone, which is Q1 below.
- **Round 1's Q3 and Q5 are consequences, not peers.** Construction is `assign_field` at
  `bs_parser.yrl:702` — one of the three brace forms — so it reshapes if and only if keys become
  values. It is folded into Q2. Where the *operations* live is downstream of Q1 and Q2 and belongs
  to a later round.
- **Round 1's Q6 was the wrong shape.** Whether ticket 50 resolves *alongside* is procedural; the
  substance is which tag `map` excludes, and that is asked directly as Q3.

### The parser half is measured, and the measurement is not the conflict count

[`48k`](../prototypes/48k_widening_the_key_position.sh), run 2026-08-25 with both controls
(the untouched grammar reports 0; a deliberate reduce/reduce grammar reports 7, so the harness can
see a conflict — the repo's rule that yecc conflicts are measured, not inferred from a quiet build):

| grammar | conflicts | PascalCase key | string key | atom key | type decl |
|---|---|---|---|---|---|
| pristine (control) | 0 | ok | refused | refused | refused |
| bounded `map_key`, all three positions | **0** | **ok** | ok | ok | ok |
| literals inlined per rule, no shared nonterminal | **0** | **ok** | ok | ok | ok |
| maximal: key becomes `pattern` | **0** | **REFUSED** | ok | ok | refused |

**The last row is the finding.** It measures zero conflicts and destroys the PascalCase key that
ships today, because there is no bare `pattern -> uident` in the grammar — only `:504`, `:516`,
`:523`, all of which need more tokens. Widening the key to the value's own nonterminal *removes*
the form that works. The subagent measurement that first found this also ran the full suite on that
grammar: **475 pass, 34 fail**, against 508/509 on the bounded widening. Two shapes, the same
conflict count, thirty-three tests apart. **A conflict count cannot see a regression, so it is not
the measurement that decides this question** — which is the same trap `check-shell.sh` hit at
severity `warning`.

Caveat carried forward from that run, because it bounds what the green above means: the end-to-end
build only type-checked a string key by coercing it to an atom, which collides `"acme"` with
`acme` and `7` with `'7'`. **The parser is free; the type side is not.** That is Q1.

## DECIDED 2026-08-25 — Q1 yes, Q2 type first

David, after the cost was priced on both sides: *"Q1 yes, Q2 type first, matchability later"*, with
the standing constraint *"I want the language to have the least surprise, not subtle edge cases."*

**Q1 — the key domain becomes unbounded. Yes.** `map<K, V>` enters the prelude as a second map
member kind in `bs_types`, not as a widening of the existing one.

**Q2 — the type ships before the pattern form.** `map<K, V>` can be declared, passed, stored and
returned. It cannot be destructured in a clause head yet. This was chosen with the reasoning
recorded, so it is not re-litigated later: **the expensive half of this feature is matchability, not
existence.** `subtract/2` is driven by residual computation (`bs_check.erl:1951`, `:1984`, `:2253` —
clause and arm exhaustiveness), so a type no pattern narrows never reaches `m_decompose/3`. Deferring
the pattern form defers the permanently-mandatory catch-all, the asterisk on the exhaustiveness
guarantee, and most of the algebra.

> **The correction that survived the decision.** The lean into Q1 was argued as *"unbounded by key
> domain is the right way forward to be the most exhaustive"*. That is backwards on its own terms —
> an open key domain is the one place exhaustiveness **cannot** work, since no finite clause set ever
> closes the residual (`48l`: adding `[]`, then `[(:user_id, _), ..]`, then `[(:locale, _), ..]`
> still reports non-exhaustive). The decision stands on the corrected reason: **unbounded keys do not
> make the language more exhaustive, they make an already-unexhaustive corner honest and typed.**
> Today that corner exists as `list<(atom, term)>` with no checking at all.

### The least-surprise constraint, and the one rule that discharges it

B# **already ships a matchable brace map** — `Read({ Status: 200 })` dispatches today (`48f`). So
"the type exists but is not matchable" risks two map-ish things with different rules, which is the
subtle edge case the constraint forbids. The framing that makes them **one** rule:

> **You can pattern-match exactly the keys you wrote down.**

A key set written in the source can be named by a pattern. An open key domain has nothing for a
pattern to name — the same reason a function cannot be destructured. One sentence, learnable, and it
makes the eventual arrival of a pattern form an *extension* of the rule rather than a reversal.

**This puts a hard requirement on the diagnostic, and the requirement is not met today.** Measured
2026-08-25 — matching a value key emits a bare parser error that explains nothing:

    Read({ "user-id": v }) -> 1
    error: syntax error before: "user-id"

Under the rule above the compiler knows exactly what happened and must say so: the key domain of this
type is open, so its keys cannot be named in a pattern; bind it and use the operations. **A syntax
error here would violate the constraint on day one**, so the diagnostic is part of the feature, not
a follow-up.

<!-- the gate for this ships before the implementation, per the repo's own rule: a test that asserts
     the value-key diagnostic names the rule, and a --self-test that goes red on a bare syntax error -->

### How Elixir does it — measured 2026-08-25 by [`48m`](../prototypes/48m_elixir_maps_under_descr.exs)

David, after Q1 and Q2 were decided: *"I need to see again how Elixir handles maps with pattern
matching and set-theoretic typing."*

Elixir is a sharper comparison than Gleam and the survey under-used it. It is **the only shipped
system with both map patterns and a set-theoretic type system**, which is exactly B#'s combination.
31e and 48e used `Module.Types.Descr` for tag questions; this asks the two structural ones.

**1. The unbounded key domain exists — and it is not a second member kind.** Descr's map
representation is a BDD of pairs `{tag_or_domain, fields}`, where `tag_or_domain` is `:closed`,
`:open`, **or a map from domain keys to types**, and `fields` is the finite atom-keyed part. There
are twelve domain key types: binary, integer, float, atom, tuple, map, list, fun, pid, port,
reference, empty_list.

So the thing this ticket called *"a second member kind"* is, in the one shipped set-theoretic
implementation, **a third value of the existing tag slot**. B#'s
`map_member() :: {closed | open, #{atom() => ty()}}` is the same shape with that case missing. That
is a smaller and far more borrowable change than Q1's write-up assumed — the slot already exists.

**2. Its subtraction is exact where B#'s surrenders.** `bs_types.erl`'s last `m_minus` clause says
*"these fields, plus at least one more" is not something this algebra can name* and keeps the
minuend whole. The same subtraction on the same instrument:

| | |
|---|---|
| `closedA` is a subtype of `openA` | true |
| **gave up** (`diff == openA`) | **false** |
| `diff` excludes `closedA` | true |
| `diff` still within `openA` (sound) | true |
| `diff` empty (degenerate) | false |
| `diff` still admits `%{a, b}` | true |

**Elixir names the case B# cannot.** The reason is representational and stated in its own source:
B#'s map part is a **flat list of members with no negation node**, while Descr keeps negations
**symbolic in a BDD** — *"this representation keeps negations symbolic, and avoids distributing
difference"*. So **the precision unknown is not inherent to set-theoretic maps. It is a consequence
of the representation B# chose**, and there is a shipped fix for it.

**3. But Elixir does not enforce exhaustiveness at all**, and this is what decides how much of the
above transfers. Measured by compiling rather than reasoning: a function with a clause for `%{a: _}`,
no clause for `%{b: _}` and no catch-all compiles at **exit 0 with no warning**. What Elixir does
instead is **infer the domain from the clauses and check callers against it** — `pick(%{b: 1})`
warns, `given types: -%{a: not_set(), b: integer()}-` against `expected: dynamic(%{..., a: term()})`.

**What transfers, and what does not.** Elixir's exactness proves the imprecision is **fixable**, and
hands over the shape to fix it with. It does **not** tell us how much precision B# needs, because
Elixir is never asked to close a residual — it spends its precision on call-site checking, not
totality. B# is asking a question Elixir does not ask, so the precision budget is still B#'s to set
on its own terms.

**And it makes the Q2 decision look better rather than worse.** Elixir's BDD exists to serve pattern
matching; B# has just deferred pattern matching. Under *type first*, the domain-key tag is needed for
**assignment compatibility and union membership** — `m_meet` and `m_subset` — and not for residual
computation, which is what drives `m_decompose`. So the representation question can travel with the
pattern form and be taken as one decision when it arrives, instead of being paid for now.

### Elixir's two kinds of map, and assertive style — read 2026-08-25

David: *"Elixir has 2 kinds of map … and recommended practice … and also structs are records which
enforce pre-defined keys — does this material help with making a decision?"*

**It does, and it is a different kind of input from everything above it**: `48m` measured the type
system's *mechanics*, this is the ecosystem's *convention*. Two primary sources, read rather than
recalled.

**1. The two-worlds split is Elixir's documented convention, not an artefact.** The getting-started
guide names both uses and gives each its own idiom:

> *"Use maps when working with data that has a predefined set of keys."* … *"Elixir developers
> typically prefer to use the `map.key` syntax and pattern matching instead of the functions in the
> `Map` module when working with maps."*

<!-- elixir hexdocs 1.20.3, keywords-and-maps -->

against *"whenever you need to store key-value pairs, maps are the go-to data structure"* for the
dynamic use, where the idiom is `map[key]` and the `Map` module. **So B#'s proposed rule — you can
pattern-match exactly the keys you wrote down — is the same seam the BEAM already draws.** B# would
be enforcing in the type system what Elixir enforces by convention, which is the strongest possible
answer to the least-surprise constraint: the reader already thinks in these two worlds.

**2. Assertive access is the ecosystem's answer to the exact defect `48l` measured.** The guide is
explicit about why the strict form is preferred:

> *"These operations have one large benefit in that they raise if the key does not exist … This
> makes them useful to get quick feedback and spot bugs and typos early on."*

and Dashbit's assertive-style post makes it a rule — *"we should prefer the strict syntax when
possible as it helps us find bugs early on"*, `map.name` raising where `map[:name]` returns `nil`
and *"opens code to unintended flexibility"*.

<!-- dashbit.co/blog/writing-assertive-code-with-elixir -->

`48l` measured B#'s workaround doing precisely the non-assertive thing: a misspelled key returns the
absent answer, silently, at compile time and run time alike. **The BEAM's own guidance says that is
the failure mode to design against.**

**3. Structs are emphatically NOT dynamically accessible, and that sharpens Q3.** The post calls
`Access` on structured data *"an anti-pattern itself"*; structs do not support `struct[:key]` unless
you explicitly derive the protocol. Applied here, that says **B#'s own records must not be
dictionaries you can `Get` from** — but a *foreign* aggregate, for which you have no declaration and
whose only alternative is a measured silent trap (ticket 50 candidate 1), must be readable somehow.

`48e`'s two options split on exactly that line:

| | excludes B# records | admits a foreign struct |
|---|---|---|
| **`Kind` absent only** | yes | **yes** |
| both tags absent | yes | no |

**So `Kind`-absent-only is the option that honours the anti-pattern for your own data while leaving
a foreign struct readable.** This confirms Q3's recommendation and replaces its reason: not merely
*"50's fallback is a trap"*, but *"your own aggregates should not be dynamically accessible; someone
else's, which you cannot declare, must be."*

**4. `Map.fetch/2` unblocks round 3's Q6 without fixing the prelude first.** Elixir's dynamic-world lookup
returns `{:ok, value} | :error` — a **tagged** success. B#'s `option<T>` and `result<T, E>` collapse
at `T = term` because their success case is the *bare* value and `:nothing` is an atom inside it. A
tagged success does not collapse. So `Get` can return `(:ok, V) | :absent` and be usable at
`V = term` on day one. **The prelude collapse remains a real defect and still wants its own ticket —
it just stops blocking this one.**

**What this leaves for round 3's Q8 — not Q5, which asks where the operations live rather than
what they are.** Elixir ships *both* operations and recommends the strict one:
`Map.fetch!` raises, `Map.fetch` returns the tagged pair. If B# follows, it needs a name for the
raising form, and **`!` is not available** — that spelling was settled out of B# identifiers. Also
unmeasured: `PRELUDE.md` lists `raise` as decided-but-unbuilt, so the assertive half may have no
mechanism yet. Both are downstream questions, not blockers on the shape.

### The four questions

> **Q1 and Q2 are now decided — see above.** Q3 and Q4 below are still open. The text of Q1 and Q2
> is kept as the record of what was weighed.

**None of these is decided.** The arrows are the grilling's recommendation, recorded so the
reasoning is not lost, not a resolution.

❓ **Q1 — Does the key domain become unbounded, given what that costs?**

This ships today and is not in question:

    record Order { Status: int }
    Read({ Status: s }) -> s          // dispatches; exhaustiveness enforced, residual printed

This is what the ticket is actually asking for, and nothing about it exists:

    type Assigns = map<atom, term>
    Get({ "user-id": id }) -> id

**In plain terms, before the line numbers.** A B# map type today is a *struct definition*: a known
list of field names, written in the source, complete before the program runs. The checker stores it
as a flag plus that list —

    {closed, #{'Status' => integer}}      "exactly these fields"
    {open,   #{'Status' => integer}}      "at least these fields"

A dictionary is a *phone book*. `map<string, int>` says "any string key at all, values are ints" —
there is no list of names, the keys arrive at runtime, and there can be unboundedly many.

That matters because exhaustiveness is proved with set operations, and for maps every one of them
works by **comparing the lists of key names**:

    same_keys(A, B)   -> lists:sort(maps:keys(A)) =:= lists:sort(maps:keys(B)).
    keys_subset(S, P) -> lists:all(fun(K) -> maps:is_key(K, P) end, maps:keys(S)).

Sort the keys, compare them. A phone book has nothing to sort, so the machinery that proves
exhaustiveness cannot run on it at all.

And the obvious fix is not one. *"Just allow key types other than atom"* — loosening
`#{atom() => ty()}` — does not help, because the problem is not what **type** the keys are, it is
that there is a **finite list at all**. A dictionary type is not a longer list of fields; it is a
different kind of statement: one uniform rule covering unboundedly many keys, rather than an
enumeration of them. Hence *second member kind*, not *widening* — the checker learns a second shape
of map type, and every set operation learns to handle a mixture of the two.

That last point is where the cost comes from. Intersection and subtraction each carry four clauses
today, one per combination of `closed`/`open` on the two sides — a 2×2 grid. A third shape makes
each a 3×3. The work grows by multiplication, not addition, which is the whole reason this is the
expensive question.

The compiler delta is not a table entry. `bs_types.erl:99` is
`map_member() :: {closed | open, #{atom() => ty()}}` — a **finite product keyed by atom**, and the
module says so itself at `:95-97`: *"The field product decomposes exactly the way the tuple product
does, keyed by field name instead of by position."* An unbounded domain is not a wider product; it
is a uniform key-type-to-value-type constraint, so it is a **second member kind**, not a widening of
the existing one. `maps:keys/1` has nothing to enumerate, `same_keys/2` and `keys_subset/2`
(`:735-738`) cannot decide, and `m_decompose/3` (`:664`) emits one member per key of a set that is
now infinite. **9 functions / 18 clauses** destructure the pair — `m_meet` and `m_minus` are each a
2×2 over `closed`/`open` and become 3×3 — with **16 more** routing through it, plus
`bs_emit.erl:950-961` outside the module.

<!-- the criterion, stated once because three different totals have been in circulation: 9/18 is
     "destructures the {closed|open, Fields} pair", which is the defensible figure. The 16 are
     second and third tier — they touch the field map or dispatch on the part without destructuring
     the pair. Earlier drafts said ~14 and ~25; both were counting something else. -->

The floor is real and should be said plainly: ticket 31 found `list<(atom, term)>` carries the same
state and **is not blocking**. The price of "no" is `term` values and a list walk.

Worth knowing before answering: the algebra already has an unbounded escape, and it is
maximally imprecise. `map_part()`'s `top` (`:143`) is *any map whatsoever* and prints as bare
`"map"`. So today B# can say *"exactly these named fields"*, *"at least these named fields"*, and
*"any map at all"* — with **nothing in between**. `map<K, V>` is precisely the missing middle.

➡️ **Yes, and pay for it as a second member kind rather than a widened one.** The middle is missing,
**seven** distinct places have wanted it and worked around it (counted below, not three as this line
first said), and a coercion-based shortcut is unsound. But this is the expensive answer and the only
one of the four that is, so it is the one worth refusing.

### What "no" loses and what "yes" costs — measured 2026-08-25 by [`48l`](../prototypes/48l_what_the_workaround_costs.sh)

David, on being given Q1: *"If the key domain doesn't become unbounded what is lost? And if it does
become unbounded what is the cost? That's what I need to make a decision."*

> **The framing this measurement was written to test was wrong, and it is worth saying which half.**
> The prediction was *"no map means the values are `term`, so nothing is checked"*. Run
> ([`48l`](../prototypes/48l_what_the_workaround_costs.sh) §2): **false**. A bare `term` reaching an
> `int` parameter is a **compile error**, so the checker forces a narrowing and a wrong value type
> fails loudly. The **value** domain is checked. What is unchecked is the **key** domain — and that
> is unchecked at compile time *and* at run time. The blindness is specific, not general.

**What "no" loses.**

1. **A misspelled key is silent end to end.** `48l` §1, three entry points over one assigns channel:
   `Correct` → `42`; `Typo`, which reads `:userid` where the writer wrote `:user_id`, → **`0`**,
   compiling clean and running clean. It returns the absent answer, and it is **indistinguishable
   from a legitimately absent optional key**. Discipline does not fix it: even a hand-rolled
   `(:ok, term) | :absent` — which the author must write, see (3) — gives `:absent` for a typo and
   for a real absence alike. The checker can be made to force absence *handling*; it can never say
   the absence is a misspelling.

2. **A clause head cannot ask the key question.** `48l` §3. The only head form that parses asks a
   **positional** question, not a key one. Two stages writing the same keys in different orders:

       [(:user_id, 42), (:locale, :en)]   ->  :saw_user
       [(:locale, :en), (:user_id, 42)]   ->  :no_user

   Both compile without a warning. So key dispatch has to move out of the head and into the body,
   which is exactly what B#'s dispatch story exists to avoid.

3. **Ceremony, per channel and per read.** No prelude keyfind exists — PRELUDE.md still has the
   collection library open — so every program hand-writes a ~4-line recursive lookup. Every read
   costs ~5 lines of `ValidateAs<T>` + `switch`, per value type, because a `term` cannot reach a
   concrete parameter and neither head-level narrowing nor `is_int`-style guards exist yet. And the
   failure channel has to be hand-rolled, because **both prelude failure types collapse at exactly
   the value type the workaround forces**: `option<term>` and `result<term, E>` both normalise back
   to bare `term`, so a lookup cannot report "absent" in a type the checker can see. Lookup is O(n).

4. **Seven confirmed wants, not four.** `fog.md:533` records *"four demands from two exemplars"*.
   Opening the files gives seven, across four tickets and two exemplars: ticket 31 (`assigns`);
   25d three times over (`epgsql:connect/1`'s options, a decoded `jsonb` document, and a group-by on
   an open `string` key); 25a (response-body construction); ticket 50 (Req's untagged body and
   headers); and ticket 09 — `type Json = ... | map<string, Json>`, the JSON type itself, cited
   again by tickets 11 and 27.

5. **"Compiled by luck" is a mechanism, not an anecdote, and it is the worst of the five.** 25d
   declares `epgsql:connect/1` as taking `list<term>`; epgsql documents a **map**. It type-checks
   because the author's `using` block and the author's caller agree *with each other* — a closed
   loop that never touches the library's real contract. Reproduced directly by declaring
   `:maps.size/1`, which takes a map, as taking a `list<term>`: **compiles at exit 0 with no
   diagnostics, then crashes `badmap` at run time inside the callee.** B# could not spell the
   documented form, so the author was pushed onto a legacy one — and the compiler's silence there is
   the same silence it gives a declaration that is simply wrong.

**What "yes" costs.**

Already paid, and this is most of the surface:

| | |
|---|---|
| the parser | **free** — `48k` measured 0 conflicts for a bounded `map_key` at all three positions |
| the pattern form | **ships** — `48f`; exhaustiveness over closed keys enforced, `48g` |
| the erasure target | **already value-keyed** — records erase to Erlang maps; the emitter mints `{atom, L, K}` from the field name and would need `expr(K, C)`. Mechanical |

The real cost is the algebra, and it is the only real cost: **9 functions / 18 clauses** destructure
`{closed | open, Fields}`, intersection and subtraction each go from a 2×2 grid to a 3×3, and 16
more functions route through the pair, plus `bs_emit.erl:950-961` outside the module.

**And one deflation, because it changes the size of the prize.** `map<atom, term>` buys much less
than it looks. It removes the hand-written lookup, the O(n) walk and the position dependence in (2).
It does **not** remove the `ValidateAs` + `switch` ceremony, and it does **not** fix the
`option<term>` collapse in (3) — both survive unless the **value** type is concrete. The realistic
saving at `map<atom, term>` is roughly 17 lines to 13, not 17 to 8. The large win needs
`map<atom, int>`, which is to say: the prize is proportional to how concrete the values are.

**What actually decides it.**

**The unchecked open key domain exists today, spelled as a list.** Adding `map<K, V>` does not create
it — it makes it a shape the compiler knows the name of. Exhaustiveness over open keys is vacuous
either way, and `48l` §4 controls that claim from the other side: over a **closed** key set the
guarantee is fully live, and growing a union by one member turns the clause set red. So "no" does
**not** preserve a guarantee that "yes" gives up. That trade is not on the table; it only looked
like it was.

What "yes" buys, stated narrowly: the lookup becomes a language form instead of hand-written code,
key dispatch returns to the clause head, and the value type can be concrete so the narrowing
ceremony disappears. What it does not buy is any checking of the key domain itself — a misspelled
key stays silent under `map<atom, term>` exactly as it is silent under the list.

<!-- two things found on the way and not filed, both wanting a ticket: closing the key domain to a
     union makes the typo an error but emits "clause 1 is unreachable ... matched by an earlier
     clause" when there is no earlier clause; and the non-exhaustive residual prints only the record
     tag without naming the missing member, which 25d's write-up records independently -->


---

❓ **Q2 — One widened brace form, or a second form standing beside it?**

Measured above: a **bounded** `map_key` (name | string | atom | integer) is free at the parser — 0
conflicts at each of the three positions and at all three together, in both the shared-nonterminal
and the inlined shape, with the PascalCase key intact. The **maximal** generalisation is not free,
and its cost is invisible to the conflict count.

The repo's habit points the other way, though. F13 (binary patterns) added a new delimiter and
three new nonterminals; F2 (intervals) added a new chain folded in by one alternative; F22/ticket 55
added four parallel `pattern` productions beside the bare brace form. **All parallel.** F20
(list-spine) is the only in-place generalisation, and it went the *other* direction — it
**restricted** the rest position from any `pattern` to five named forms.

The sharp edge, and the reason this is not merely a grammar question: records already erase to
maps with **atom** keys (`bs_emit.erl:592`, `:759-761`, `:768-769`, where the key node is
`{atom, L, K}` minted from the field name). So under one widened form, `{ Status: s }` is
ambiguous *by construction* — a record field, or the atom key `'Status'` of a dictionary. At
runtime they are the same map. Which reading the checker takes is decided by Q3, not here.

➡️ **One form, widened to a bounded `map_key`.** A second brace form would have to be
distinguished by a delimiter B# does not have spare, and the two would erase identically anyway.
Construction (`assign_field`, `:702`) comes with it in the same change — three productions, no
lexer change.

---

❓ **Q3 — Which tag does it exclude: `Kind` only, or both?**

`48e` measured both options sound on the `Descr` instrument, so this is a choice, not a constraint,
and it is the one with a consequence outside this ticket.

    a B# record      is a map carrying   Kind        => :'MyApp.Response'
    an Elixir struct is a map carrying   __struct__  => :'Elixir.Req.Response'

- **`Kind` absent only** — a foreign struct *is* a `map<atom, term>`. Ticket 50's candidate 2 then
  works with no new surface, and `Req.get!()`'s return value reads directly. The price: the type
  stops meaning *"not somebody else's aggregate"*.
- **Both absent** — the type means what it says, and a foreign struct is not one. The price: 50
  needs its own answer, and its candidate 2 cannot be it, because an unrestricted open map admits
  a B# record *and* an Elixir struct and cannot tell them apart.

➡️ **`Kind` absent only** — and this reverses the recommendation first written here, which was
*"both absent"*. Two things overturned it. First, **50 candidate 1 is not a fallback that exists**:
`50b` measured that a record-typed foreign return is *accepted* by the checker and then crashes
`function_clause` at run time **with no diagnostic** (50's file, *"B# side: neither, and one of the
refusals is silent"*). Sending 50 there means building a new declaration form *and* the diagnostic
that plain form is missing. Second, the discriminability argument does not actually reach: B# has an
identity to defend for **its own** records, and `Kind`-absent keeps them disjoint either way. An
Elixir struct is not a B# aggregate, so an open map admitting one dissolves nothing — it is
permissive exactly where an open map is supposed to be.

**This is still the one to argue with**, because it decides 50 rather than merely informing it. The
case for *both absent* is that `map` then means what it says; the measured price is that 50's only
remaining shape is the one with a live silent trap.

---

❓ **Q4 — Is it called `map<K, V>` or `dict<K, V>`?**

**This file currently says both**, which is the honest state: `dict` 20 times in the newest
sections, `map<K, V>` in round 1's table, and both from David — *"probably want to add map to
prelude"* on 2026-08-21, then *"if I name map type dict in B#"* on 2026-08-25.

There is no mechanism left on either side. `48h` disqualified the survey's one documented
tie-break: Gleam renamed `Map` to `Dict` because **one namespace held both** the type and the
map/filter/reduce family, and B# does not share that premise — the prelude owns lowercase while
user types and functions are PascalCase, stated as a decision at `bs_check.erl:710-712`
(*"so the two cannot collide"*), and measured — `Map` declares, resolves unqualified, and runs.
`48j` confirms availability is not a factor either: `map` and `dict` refuse identically today, both
for want of a prelude entry.

➡️ **`map<K, V>`.** It erases to a BEAM map, every BEAM language calls that a map, it sits beside
`list<T>`, and the collision that made Gleam rename is measured not to exist here. Per the map's
own rule, refuse on mechanism and not on taste — and there is no mechanism against `map`.

### Round 3 — put 2026-08-25, open

**Numbering note, because this file briefly had two schemes.** Round 1's questions were numbered
1–6 and are referred to above only as *"Round 1's Q3"*, *"Round 1's Q5"* and so on. Rounds 2 and 3
share a single run of numbers: **Q1–Q4 from round 2** (Q1 and Q2 decided, Q3 and Q4 open), **Q5–Q8
from round 3**. A bare `Q5` anywhere below this line means round 3's.

Q1 and Q2 being settled unblocked these. Q5 and Q8 are both consequences of Q2 in particular: with
no pattern form, the operations are the *only* way into a map.

❓ **Q5 — where do the operations live?** A hosting question, not a shape one.

> **Q5's options list was incomplete, and the missing option was already decided — found 2026-08-25
> while tracing where the word "prelude" entered the project.** Q5 offered *(a) build a function
> prelude*, *(b) compiler-known forms*, *(c) index syntax*, and recommended (a) on the premise that
> **no function-prelude mechanism exists**. The premise is true and **irrelevant**, because
> [ticket 17 §2](17-pipeline-and-comprehension.md) had already settled the mechanism and it is not a
> callable:
>
> > **The compiler-known prelude is inlined; user code is called. Precision follows the inlining.**
>
> It is spelled **`List.Map`** — *qualified* — while being compiler-known and **inlined at the call
> site**, not a function in a module. So the shape `Map.Get` needs already exists, is decided, and
> has a worked precedent. Q5's answer is therefore **(b), not (a)**: a compiler-known operation with
> a qualified spelling, lowered to an inlined form.
>
> **This is a better answer than (a) on four counts, three of them measured by 17 §2 itself:**
>
> 1. **No mechanism has to be built.** Inlining needs no prelude of callables, which was (a)'s entire
>    cost.
> 2. **It is strictly more precise than a call.** 17 §2 measured `filter` emitting
>    `[pos_integer()]`, narrowed out of the guards, where the surface signature can only say
>    `list<T>` — *"the emitted code knows a fact the language's own type system discards"*.
> 3. **A generic call is measured to be worse than Erlang's own.** A declared spec on a generic
>    `list_map/2` overrides success typing of the body, so emitting the call loses what inlining
>    keeps.
> 4. **It does not cross a recorded boundary.** *BOUNDARY — Standard library breadth* rules out
>    *"a library designed module-by-module"*. Under (a) `Map` was a module and 48 was designing one;
>    under (b) nothing is designed — `Map.` is a qualified spelling for compiler-known operations.
>
> **What survives of Q9 is the smaller half.** The `Map.` qualifier must still be reserved, because
> a user can declare `module Map` today. But there are **no prelude functions to collide with user
> functions**, so Q9's unqualified-collision problem does not arise. It was created by (a), and (a)
> is withdrawn.
>
> **What this does not settle:** whether these operations belong to *the prelude* (17 §2's own words,
> "the compiler-known prelude", reached through a qualifier) or to *the standard library* as
> `CONTEXT.md` now defines it. 17 §2 uses "prelude" for a qualified thing, which is the same
> conflation corrected earlier today. The vocabulary needs one more pass; the **mechanism** is
> settled either way.

There is **no function prelude at all**, and none reachable: `unqualified_key/4` has three
resolution steps and no prelude step among them, and `ValidateAs<T>`'s generator keys on a resolved
type inside angle brackets, which `Get(m, k)` has not got.

- **(a) build a standard library** — the largest, and the only non-throwaway option: `PRELUDE.md`
  still has the whole collection library open, `List.Map/Filter/Fold` unbuilt, so this bill arrives
  anyway;
- **(b) compiler-known forms**, special-cased in the checker the way `ValidateAs<T>` is — cheaper,
  but each is a permanent special case;
- **(c) index syntax** — `m[k]`. `[` in that position is a syntax error today, so it is grammar
  work, and it *fights the design*: C#'s indexer throws on absence while B# wants absence in the
  value domain.

➡️ **(a)**, and the Elixir reading above strengthens it rather than replacing it. Elixir hosts its
map operations in **all three** places — `map.key` is syntax, `map[key]` is syntax via the Access
protocol, and `Map.fetch/2` is a **library module**. The row B# cannot copy is the third, because it
has no module-function mechanism for a prelude entry to live in. So if the `Map.fetch` equivalent is
wanted at all, (a) is not avoidable.

❓ **Q6 — does the `option<T>` collapse get fixed before the lookup ships?**

`option<term>` and `result<term, E>` both normalise back to bare `term`, because their success case
is the *bare* value and `:nothing` is an atom inside it. All three motivating cases use `term`
values.

➡️ **It stops blocking, and stays its own ticket.** `Map.fetch/2` returns `{:ok, value} | :error` —
a **tagged** success, which does not collapse. A lookup returning `(:ok, V) | :absent` is therefore
usable at `V = term` on day one. The collapse remains a real prelude defect and should be raised
separately; shipping it together would have the lookup feel broken and the map type take the blame.

❓ **Q7 — is the shipped brace map a `map<K, V>`?** One type family, or two that look alike?

➡️ **One family.** Two unrelated map-ish types is precisely the surprise the standing constraint
forbids. `48m` gives the shape to borrow: in `Descr` they are **the same constructor with a
different tag value** — `:closed`, `:open`, or a domain-key map — not two constructors. Partly
downstream of Q3, which decides where the boundary sits.

❓ **Q8 — what shape do the operations take?** Raised 2026-08-25 by the Elixir reading, and
distinct from Q5: Q5 asks *where they live*, this asks *what they are*.

Elixir ships **two** and prefers the strict one — `Map.fetch!` raises, `Map.fetch` returns the
tagged pair — because *"they raise if the key does not exist … useful to get quick feedback and spot
bugs and typos early on"*. `48l` measured B#'s workaround doing the opposite: a misspelled key
returns the absent answer silently.

➡️ **Two operations, assertive preferred**, following the ecosystem. Two things are unresolved
underneath it and neither blocks the shape: **`!` is not available** as a name for the raising form,
that spelling having been settled out of B# identifiers; and `PRELUDE.md` lists `raise` as
decided-but-unbuilt, so the assertive half may have no mechanism yet.

### Round 4 — put 2026-08-25, one question

Q5's answer opens one thing that would otherwise be assumed silently, and it is the same problem the
type prelude was explicitly designed around.

❓ **Q9 — what namespace does a prelude *function* live in?**

The type prelude has no collision problem, and `bs_check.erl:710-712` says why, as a decision:
lowercase is the prelude's, PascalCase is the user's, *"so the two cannot collide."* **That
reasoning does not reach functions**, because a prelude function and a user function would both be
PascalCase. Measured 2026-08-25, and both halves compile and run:

    public int Get(int n)      // a user's own Get         -> 42
    module Map                 // a user's own module Map  -> 42

So neither the unqualified name nor the obvious qualifier is free.

- **(a) qualified only — `Map.Get(m, k)`.** Reads well and matches Elixir's `Map.fetch`. But `Map`
  is takeable as a module name today, so the prelude would have to reserve it, which is the first
  reserved name in the language.
- **(b) unqualified, user wins.** A user's `Get` shadows the prelude's. No breakage, and exactly the
  kind of silent subtlety the standing constraint forbids.
- **(c) unqualified, collision refused.** Declaring `Get` becomes an error. Honest and loud, but it
  breaks code that compiles today, and the set of burned names grows with every prelude addition.
- **(d) a namespace the user cannot take** — a sigil, a reserved prefix, or lowercase functions for
  the prelude alone, mirroring what the type prelude already does.

➡️ **(d), mirroring the type prelude.** It is the only option that keeps the existing decision's
shape — the prelude owns a namespace the user's syntax cannot reach — instead of introducing
reserved words (a), silent shadowing (b), or a growing list of burned names (c). It also answers
Q8's naming problem in passing, since a distinct namespace can spell the assertive and tagged forms
however it likes without competing with user identifiers.

**This is a language-wide decision, not a map one.** It governs the whole collection library that
`PRELUDE.md` still has open, so it wants deciding here and recording somewhere more central than
ticket 48.

### Deferred further, because it is downstream of Q5

Where the **operations** live — `Get`/`Put`/`Delete`/`Keys`, or pattern-and-`with` only. One
premise for it is now measured rather than assumed: the prelude at `bs_check.erl:706-726` is a
**type** prelude, two strata, both about type authorship. There is no function-prelude mechanism,
so a Gleam-shaped opaque interface would have to invent one.

Related defect found on the way and not fixed here: `with`'s subject is unchecked
(`bs_check.erl:1742`, where `declared_fields/1` returning `unknown` is read as "no information"
rather than "wrong kind of subject") — filed as ENG-249, and 48d is its measurement. *Resolved
2026-09-03: the `unknown` now routes to site 3's subtraction, and 48d prints REFUSED on all three.*
Note the
contrast `48i` §6 draws: a malformed **key** is caught at the parser, while a wrong-kind
**subject** passes at exit 0.

A decision brief with the corrected tree as a diagram, the six questions and a claim→source table
is published at <https://claude.ai/code/artifact/64ddb8ca-a67c-4975-8591-f879c6311a7a>, refreshed
to round 2 on 2026-08-25 with the 48k measurement table and round 1 kept below it as the record.
This file stays canonical; that page is an ungated snapshot.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [A map type in the prelude](issues/48-a-map-type-in-the-prelude.md) — **`map<K, V>` enters the
  prelude as a second map member kind, declarable but not yet destructurable, with `Map.Get` a
  compiler-known operation under a reserved qualifier.** All nine questions are answered across three
  dated `DECIDED` sections. The type ships before the pattern form because **the expensive half of
  this feature is matchability, not existence** — a type no pattern narrows never reaches
  `m_decompose/3`, so deferring the pattern form defers the permanently-mandatory catch-all and most
  of the algebra. The excluded tag is **`Kind` absent only**, which is what makes an Elixir struct a
  member of the map type and settles ticket 50 as execution. **Two of the ticket's own premises were
  falsified and both corrections stand with the decision**: Elixir does *not* reserve `Map` — an
  ordinary module in a flat namespace, measured on 1.19.5 — so reserving it is beam-sharp's choice,
  not a borrowed one; and unbounded keys do **not** make the language more exhaustive, since an open
  key domain is the one place exhaustiveness cannot work. They make an already-unexhaustive corner
  honest and typed, where today it is `list<(atom, term)>` with no checking at all. Resolved
  2026-08-25 — [ENG-230](https://linear.app/davewil/issue/ENG-230).
```
