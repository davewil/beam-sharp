# 48 — Prior art on a map type: Gleam, Erlang/Elixir, C#

Research for [ticket 48](../issues/48-a-map-type-in-the-prelude.md), 2026-08-25. This is the
borrow survey the ticket recorded as owed: *"the borrow heuristic wants all four sources and only
one has been measured."* The fourth (Elixir's type algebra) was measured at
[`31e`](../prototypes/31e_elixir_maps_vs_structs.exs) and is not repeated here — 48's own Notes
say not to re-derive it.

**Everything below is either MEASURED or CITED, and the two are never mixed in one sentence.**
Measured means a probe in this repo produced the output quoted. Cited means a primary source says
it and no probe here can show it. The distinction matters because one arm of this survey turns on
a design *rationale*, which is not a thing a compiler can be asked.

| arm | instrument | what it can show |
|---|---|---|
| Gleam | [`48b`](../prototypes/48b_gleam_dict_opacity.sh), gleam 1.18.1 | measured: the behaviour. cited: the reason |
| Erlang / Elixir | [`48a`](../prototypes/48a_map_forms_erlang_elixir.sh), OTP 28 / Elixir on OTP 28 | measured, entirely |
| C# | [`48c`](../prototypes/48c_csharp_dictionary_forms.sh), dotnet 9.0.306 | measured, entirely |

---

## Summary — what the survey returns

| | Erlang | Elixir | Gleam | C# |
|---|---|---|---|---|
| has a map type | yes, `#{}` | yes, `%{}` | yes, `Dict` | yes, `Dictionary<K,V>` |
| **matchable in a clause head** | **yes** | **yes** | **no** | **on properties only, never on keys** |
| **enforces exhaustiveness** | no | no | **yes, refuses to compile** | no — warning only |
| absence of a key is | a failed clause | a failed clause | **a returned value** (`Error(Nil)`) | an exception or `TryGetValue` |
| the type is called | `map` | `map` | `Dict` | `Dictionary` |
| the map *function* is called | `lists:map` | `Enum.map` | `list.map` | **`Select`** |

**The one source that shares beam-sharp's problem is also the only one with no map pattern.**
Gleam is the only surveyed language that enforces exhaustiveness, and the only one you cannot match
a map in. Both halves are measured in `48b`, with a control run first to confirm the promise is
real before the pattern result is read.

**The survey does not claim those two facts are connected, because no source connects them.** The
reading that suggests itself — exhaustiveness forces the refusal — is a reconstruction, and the
citation hunt below came back empty on it: there is no published Gleam rationale for the missing
pattern form, no feature request for one, and therefore no rejection with a reason. What Gleam
documents instead is a *usage* position: dicts are "generally not used much", custom types are
where data goes. Treating the correlation as causation here would be the same error as the version
trap recorded at the end of Arm 1, so the survey states both facts and stops.

---

## Three of ticket 48's own premises did not survive the survey

The first two were checked before any prose was written, because a grilling that reasons from a
false premise inherits it. The third emerged from the citation hunt and is recorded in full under
Arm 1: **"candidate 1 with the reasoning already done" is not true** — Gleam's behaviour is
documented and its *rationale* is not, so the argument for candidate 1 has to be supplied here
rather than inherited.

### 1. The `:=` / `=>` distinction is not a pattern form at all

**48's survey stub said:** *"Erlang / Elixir — matchable, and the `%{k := v}` / `%{k => v}`
distinction between 'must be present' and 'may be' is a form beam-sharp has no equivalent of."*

**Measured** (`48a` §1, §2, §3, §5) — the two operators do not compete in pattern position, because
only one of them is legal there:

| position | `:=` | `=>` |
|---|---|---|
| Erlang **pattern** | **legal, and the only form** | **refused**: `illegal pattern, did you mean to use ':='?` |
| Erlang **construction** | **refused**: `only association operators '=>' are allowed in map construction` | legal, and the only form |
| Erlang **update** | legal — requires the key to exist | legal — inserts or overwrites |
| Elixir, anywhere | **`:=` is not an operator in Elixir at all** — `Code.string_to_quoted("a := b")` returns a syntax error | the only form |

So the presence/absence distinction lives in exactly one place: **Erlang's update expression**,
measured at runtime in `48a` §3 —

```
on a map that HAS the key #{k => 0}:
      M#{k := 9}  -> #{k => 9}
      M#{k => 9}  -> #{k => 9}
on a map that LACKS the key #{}:
      M#{k := 9}  -> {error,{badkey,k}}
      M#{k => 9}  -> #{k => 9}
```

**This relocates the arm.** The construct beam-sharp would be missing an equivalent of is not a
pattern form — it is an **update** form, and beam-sharp already has one: `with`, which
[25d](../prototypes/25d-database-querying.md) records earning its place in the fold accumulator.
The live question that survives is therefore *"does `with` on a map require the key to exist, or
insert it?"* — a real question, a smaller one, and one about a construct that already exists rather
than one that would have to be invented. Elixir is not a source on it either way.

### 2. "Exhaustiveness over a map is vacuous" is true of candidate 2 only

**48's "What survives" paragraph said:** *"A map's key domain is unbounded, so a pattern over it
never closes a residual… Exhaustiveness over a map is **vacuous**… beam-sharp would be adding its
first type over which the headline guarantee says nothing."*

The first half is confirmed. `48a` §4 measures it directly: `#{}` as a clause head matches every
map, including maps that do not carry the key the previous clause asked for —

```
f(#{k => 1}) -> {present,1}
f(#{})       -> absent
f(#{j => 2}) -> absent
```

**But the conclusion attaches to the wrong scope.** It is a property of *matching a map*, not of
*having a map type*. Gleam has a map type and does not pay it, because it has no map pattern:
`48b` §4 measures that the only pattern available over a `Dict` is a plain variable, which is total
by construction, so the exhaustiveness checker never has anything to say. And `48b` §5 measures
where the question went instead — `dict.get` returns a `Result`, so **absence became a value in a
closed two-constructor union**, which is precisely the shape an exhaustiveness checker *can* see:

```
a -> Ok 1
zzz -> Error(Nil) — absence is a VALUE, not a clause
```

So the sentence *"beam-sharp would be adding its first type over which the headline guarantee says
nothing"* is a cost of **candidate 2** and not of candidates 1 or 3. Under candidate 1 the guarantee
stays total everywhere, and the prelude already ships the return type that makes it work —
`option<T>` and `result<T, E>` are both already there. This materially changes the grilling: the
objection that reads as fatal to *"a map type"* is in fact an objection to *"a map **pattern**"*.

---

## Arm 1 — Gleam

### Measured

`48b` runs a control before anything else, because an unmatchable `Dict` proves nothing in a
language that never checked coverage. Gleam **refuses** an incomplete case outright:

```
error: Inexhaustive patterns
  This case expression does not have a pattern for all possible values. If it
  is run on one of the values without a pattern then it will crash.
  The missing patterns are:
      Blue
```

The same case with every constructor present compiles. **The promise is real**, so the rest of the
arm is readable.

With that established, three measurements:

| probe | result |
|---|---|
| a `dict.from_list([...])` literal in pattern position | **refused** — `Invalid pattern`, *"I'm expecting a pattern here, or a variable to bind a value to"* |
| an Erlang-style `#{"a": v}` pattern | **refused** — syntax error, `Found '{', expected one of: '('` |
| naming the `Dict` constructor: `case d { Dict(inner) -> … }` | **refused** — `` `Dict` is a type, it cannot be used as a value `` |

The third is the sharp one, and it needs a word this survey initially got wrong. **`Dict` is not
`opaque`** — `opaque` is a real Gleam keyword meaning *a custom type whose constructors exist but
are module-private*. `Dict` has no constructors to hide. Its declaration in `gleam_stdlib` is one
line with no constructor list at all, its operations supplied by `@external` implementations:

```gleam
pub type Dict(key, value)
```

<!-- src/gleam/dict.gleam, gleam-lang/stdlib, read raw 2026-08-25 -->

So nothing can pattern-match a `Dict` because Gleam's patterns destructure **constructors** and
this type has none. The effect is what candidate 1 describes — no pattern form, operations as
known functions — but the mechanism is *"a type with no constructors, implemented externally"*
rather than *"a type whose constructors are hidden"*. For a clean-room spec that distinction is the
difference between two implementable sentences, so it is worth carrying.

What remains is `case d { everything -> dict.size(everything) }` — a variable binding, total by
construction — and `dict.get`, which returns `Result(v, Nil)`.

### Cited — the reason

Ticket 48 called this *"the most valuable unread thing here, because it is candidate 1 with the
reasoning already done."* **Searched, and the reasoning was never written down.** That is premise
correction 3, and it is the least comfortable of the three.

**The behaviour is confirmed by a primary source**, from the source file that generates the
official cheatsheets:

> "There is no dict literal syntax in Gleam, and you cannot pattern match on a dict. Dicts are
> generally not used much in Gleam, custom types are more common."

<!-- src/website/cheatsheet.gleam, gleam-lang/website; rendered at gleam.run/cheatsheets/gleam-for-erlang-users/ -->

The second sentence is worth as much as the first. Gleam does not merely decline to let you match a
dict; it tells you the dict is **not where the language expects you to keep your data**. Custom
types are. That bears on candidate 3 as much as on candidate 1, and it is the only *stated* Gleam
position on the whole question.

**The rationale is NOT FOUND, and specifically the exhaustiveness argument is not Gleam's.** The
reading that suggests itself — a map's key domain is unbounded, so a pattern over it could never be
proven exhaustive, so a language that promises exhaustiveness must refuse the pattern — is a
reconstruction. Nobody at Gleam is on record making it. Checked and empty: the "will not be added
to Gleam" list in the official FAQ (which names twelve rejected features and does not name map
patterns), the language tour's dict page, the `gleam/dict` module docs, GitHub issue search across
the gleam-lang org for dict/map pattern and literal terminology including the pre-rename spelling,
and GitHub Discussions. **There is no feature request for map patterns and therefore no rejection
with a reason.**

So candidate 1 is *not* "the reasoning already done". It is **a shipped precedent with no published
argument** — which is still worth a great deal, because a language that promises exhaustiveness has
lived without map patterns for years and its users have not forced the issue. But the grilling has
to supply the argument itself rather than inherit one, and this survey cannot hand it over.

### The naming rename, which *is* documented — and says exactly what 48 needed

Gleam renamed the type, and the reason is on the record from the language's creator:

> "`Map` is a little confusing as it collides with the common map function. Let's rename it.
> Keep the old module around for a few versions but make all the functions as deprecated.
> What should the new name be? In discord `Dict` and `Dictionary` were popular."

<!-- lpil, gleam-lang/gleam issue 2405, opened 2023-11-11, closed 2023-11-21 -->

Shipped as PR `gleam-lang/stdlib#510`, merged 2023-11-21. `gleam/map` was **deprecated in
gleam_stdlib v0.33.0** (2023-11-30) and **removed in v0.35.0** (2024-02-15), both dates corroborated
against the Hex publish timestamps. The same release renamed `gleam/dynamic`'s `map` function to
`dict`, which corroborates that the driver was the **name collision** and not anything about the
data structure.

Note what the wording does and does not say: *"the common map function"* — the map/filter/reduce
family in general, not `list.map` specifically. That is the collision, stated, by the person who
made the call.

> **Trap, for anyone re-checking this.** `gleam_stdlib` **v0.33.0** (the dict rename) and the Gleam
> **compiler** v0.33 release post *"Exhaustive Gleam"* are different products three weeks apart that
> share a version number by coincidence. The "Exhaustive Gleam" post does not mention dicts, maps or
> the rename at all. Citing them together would imply a causal link between the rename and the
> exhaustiveness work that **no source supports**, and the coincidence is close enough to be
> genuinely misleading.

---

## Arm 2 — Erlang / Elixir

Measured in full at `48a`; the two premise corrections above carry most of it. Three further results
worth having in the grilling:

1. **A map pattern never closes a residual, and both languages are fine with that** because neither
   promises exhaustiveness. `48a` §6 measures Elixir compiling a `case` over a map with no
   catch-all and raising `CaseClauseError` at run time — the coverage question is simply deferred to
   the crash.
2. **Neither language can say a key is ABSENT in a pattern.** There is no syntax. The only spelling
   is clause order, and the fall-through clause `#{}` / `%{}` matches every map. Note the contrast
   with the *type* algebra: `31e` measured that Elixir's `Descr` **can** express `__struct__:
   not_set`. So the ability to say "this key is absent" exists in the type system and not in the
   surface language — which is exactly the asymmetry beam-sharp would be relying on if it built
   `map<K, V>` as *"open map, `Kind` absent"* internally.
3. **Elixir contributes almost nothing to this arm.** It has no `:=`, no absent-key form, and no
   exhaustiveness. On this question the BEAM tier is really *Erlang*, and it is a tier-2 source at
   best.

---

## Arm 3 — C#

### Measured

**The control fails, and that is the finding.** `48c` §1 measures a switch expression over an enum
with a case missing:

```
warning CS8509: The switch expression does not handle all possible values of its
input type (it is not exhaustive). For example, the pattern 'Colour.Blue' is not covered.
    COMPILES
```

A warning, and it compiles. **C# never had to answer 48's hard question**, so it cannot be cited on
the exhaustiveness half at all. That is worth stating plainly rather than leaving implicit: on this
ticket C# is a source on *naming* and on nothing else.

On the pattern half, C# has a partial form:

| probe | result |
|---|---|
| property pattern `d switch { { Count: 0 } => … }` | **compiles** |
| indexer pattern `d switch { { ["a"]: var v } => … }` | **refused** — `CS1513: } expected`; there is no such syntax |
| list pattern `d switch { [] => …, [_, ..] => … }` | **refused** — `CS1503: cannot convert from 'System.Index' to 'string'` |

So C# can match on a dictionary's *properties* but never on its *keys*, and the list-pattern refusal
is incidental rather than principled — it fails because `Dictionary<string,int>`'s indexer takes a
`string`, so the pattern cannot reach it. 48's stub called this *"no pattern form worth borrowing"*
and that holds, with the correction that a `{ Count: 0 }` pattern does exist and is occasionally
useful.

### Measured — the naming inventory

Reflection over the loaded framework rather than recollection (`48c` §3):

```
ConcurrentDictionary   Dictionary            DictionaryEntry      FrozenDictionary
IDictionary            IDictionaryEnumerator IImmutableDictionary ImmutableDictionary
ImmutableSortedDictionary  IReadOnlyDictionary  ListDictionaryInternal
OrderedDictionary      ReadOnlyDictionary    SortedDictionary

types named *Map*: BestFitMappingAttribute, IdnMapping, InterfaceMapping
```

**Fourteen BCL types say `Dictionary`. Not one collection type is called a map** — the three
`*Map*` hits are an interop attribute, an internationalised-domain-name helper, and a COM interface
map. C# is unambiguous and repetitive about the word.

---

## The naming question, which is the one place all three sources disagree

`48c` §4 measures the other half of it:

```
Enumerable.Select exists?  True
Enumerable.Map exists?     False
Enumerable.ToDictionary?   True
```

That completes a three-way split, and none of it is a tier-1 borrow:

| language | the **type** | the **function** | so it |
|---|---|---|---|
| Erlang / Elixir | `map` | `lists:map` / `Enum.map` | **tolerates the collision** |
| Gleam | `Dict` | `list.map` | **renamed the type to avoid it** |
| C# | `Dictionary` | `Select` | **never had one** — LINQ took its verb from SQL |

**beam-sharp is in Gleam's position, not C#'s.** It is a BEAM language whose function name will be
`Map`: [25d](../prototypes/25d-database-querying.md) records that it has *"no lambda yet, no
`List.Map`"* — *yet* being the operative word, and ticket 27 §(c)'s function values are deferred
rather than refused. So the day `List.Map` lands, a prelude type spelled `map` puts `map<K, V>` and
`List.Map` in the same language, which is the exact collision Gleam moved off.

This is **tier-3 territory with a beam-sharp-specific tie-break**, not a tier-1 borrow: the three
sources disagree, so there is no agreement to inherit, and per the standing rule C# does not win
ties by being C#. What the survey supplies is the tie-break datum — that the only surveyed language
sharing beam-sharp's exact shape (BEAM host, `map`-named function, exhaustiveness promise) is the one
that changed the name.

---

## What this survey does not decide

It reports; it does not choose. Opaque, matchable, or not at all is the grilling, and so is the
name. Three things it deliberately leaves open:

1. **Whether the `Result`-returning lookup is affordable here.** Gleam pays a `Result` on every
   read. beam-sharp has `option<T>` and would presumably pay a `:nothing`. `48b` measures that
   Gleam does it, not that it is right — and [ticket 49](../issues/49-what-the-valve-keys-on.md) is
   currently open on whether the valve even admits `option<T>`, which is the same value flowing
   through the same pipeline.
2. **Whether `with` on a map requires the key to exist.** Premise correction 1 relocates the
   Erlang `:=` / `=>` question here, and nothing in this survey answers it.
3. **The name.** The tie-break datum is supplied above; picking is the grilling's job.
4. **The argument for candidate 1.** This is the one the survey expected to bring back and could
   not. Gleam ships the shape but never published why, so the grilling has to make the case on
   beam-sharp's own terms. The materials are here — the exhaustiveness promise stays total, absence
   becomes an `option<T>` the checker can see, and the pattern grammar, residual algebra and
   catch-all rule are all left untouched — but they are materials, not a borrowed conclusion.
