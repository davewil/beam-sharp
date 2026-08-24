# 48 — A map type in the prelude: opaque, matchable, or not at all?

Type: grilling
Status: claimed — [ENG-230](https://linear.app/davewil/issue/ENG-230). Survey landed 2026-08-25
([research](../research/48-map-type-prior-art.md)); the grilling itself is unstarted.

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

**What survives.** A map's key domain is unbounded, so a pattern over it never closes a residual,
so a catch-all is always legal there (ticket 12's rule). Exhaustiveness over a map is **vacuous**.
Elixir pays nothing for that because it never promised exhaustiveness; beam-sharp would be adding
its first type over which the headline guarantee says nothing.

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

## The three candidates

1. **Opaque, Gleam-shaped.** `map<K, V>` with `Get`/`Put`/`Delete`/`Keys` as compiler-known
   functions and **no pattern form**. Records stay the only brace-pattern surface; the pattern
   grammar, the residual algebra and the catch-all rule are all untouched. ~~Gleam's `Dict` is this,
   deliberately.~~ **Both of those words are wrong, corrected 2026-08-25 by the survey.** Gleam's
   `Dict` is not `opaque` — that is a real Gleam keyword meaning *constructors exist but are
   module-private*, and `Dict` is declared `pub type Dict(key, value)` with **no constructors at
   all** and `@external` operations. And *"deliberately"* asserts an intent **no primary source
   states**: the behaviour is documented, the reason is not. Gleam's `Dict` is this shape, shipped,
   without a published argument. Keep the candidate; drop both claims about why.
2. **Matchable, Erlang-shaped.** A pattern form in clause heads. Now known to be *possible* — the
   `Kind`-absent construction keeps it off records — at the price that matching a map proves
   nothing.
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

Add 25a's front wall — `#{ ... }`, the anonymous map literal, recorded in `FRONTIER` — and the
exemplar arm has four independent demands from two exemplars. So the ticket-27 §(c) test that this
paragraph set up (*"no exemplar declares one"*) does not cut the map: real code asked for it and
paid to go around. Maps are extremely familiar from Elixir, which is why they would otherwise slip
in without paying the toll — the toll is now paid on this arm, and **owed on the survey arm below**,
which is what remains before this resolves.

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
establish the checker is looking. **`with`'s subject is unchecked**, so its acceptance of a list is
a hole rather than support — beam-sharp has a *record*-update form, not a map-update one. The arm
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
tells you the driver was the name and not the data structure. **This is the tie-break datum, and
unlike the pattern-form question it is a documented decision rather than a silent one.** The choice
is still the grilling's to make.

## Notes

Do not re-derive the record/map collision — it is measured above and it is not a problem. And do
not treat "Elixir has maps" as an argument; ticket 31 §6 is a worked example of a premise that
read as obvious and was wrong on inspection.
