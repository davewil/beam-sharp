# F33 — `map<K, V>` is a third map member kind, not a wider record

**Status**      **done 2026-09-04** — 14 new tests, 615 in the suite, up from 601.
                No new gate: `check-status-claims.sh` already carried the entry
                and this feature is what turns its row green
**Implements**  [ticket 48](../../wayfinder/issues/48-a-map-type-in-the-prelude.md),
                resolved 2026-08-25. It **decides nothing** — 48 settled the
                kind, the exclusion, the scope line and the shape to borrow, and
                this file builds them
**Closes**      [ENG-319](https://linear.app/davewil/issue/ENG-319)
**Depends on**  F3 (records as a tagged map, which is what Q3's exclusion is
                stated against), F6 (angle brackets, which is how the type is
                spelled), F32 (which reserved the `Map` qualifier this type's
                operations will hang from)
**Leaves**      the **pattern form** ([ENG-323](https://linear.app/davewil/issue/ENG-323))
                and **`Map.Get`** ([ENG-324](https://linear.app/davewil/issue/ENG-324)).
                Both are deferrals with reasons recorded, not omissions, and
                each is refused today with a diagnostic that says so

## What shipped

`map<K, V>` resolves as a type. It can be **declared, passed, stored and
returned** — 48 Q2's scope line exactly, chosen with its reasoning recorded so it
is not re-litigated here. It cannot be destructured in a clause head.

```
type Assigns = map<atom, term>

public int Use(map<atom, term> x)
Use(x) -> 0
```

### The algebra gained a third member kind

48 Q1's answer, and the reason it was the expensive question. A
`{closed | open, #{atom() => ty()}}` member is a **finite product keyed by
atom**: `maps:keys/1` has something to enumerate, and `same_keys/2` and
`keys_subset/2` decide by comparing those lists. A domain is **one uniform rule
over unboundedly many keys** — there is no list to sort — so the key machinery
cannot run on it at all. "Just allow key types other than atom" is not the fix,
because the problem is not what type the keys are; it is that there is a finite
list at all.

Q7 fixed the shape and it is borrowed rather than invented: in Elixir's `Descr`
the named-key and domain-key maps are the **same constructor with a different
tag value**, not two constructors. So `{dom, K, V}` sits beside `{closed, F}` and
`{open, F}`, and **being a 3-tuple beside two 2-tuples is load-bearing** —
`m_subset({_, FP}, {open, FQ})` and `discriminator({_Kind, Fields})` both match
any 2-tuple, so a domain member cannot fall into a named-field clause by
accident.

`m_meet/3` and `m_minus/3` were each a 2×2 over `closed`/`open` and are now 3×3.
The cost grew by multiplication, which is what 48 priced.

### Q3 lives in the member's meaning, not in a fourth field

`{dom, K, V}` means *"every key in K, every value in V, **and no `Kind` key**"*.
A record is `{closed, #{'Kind' => atom_lit(Tag), ...}}`, so the exclusion is
decidable by `maps:is_key('Kind', Fields)` on the other side and needs nothing
stored. `fields_fit/5` is the one place it is enforced, and it is what makes
`Order` fail to be a `map<atom, term>` while a `Kind`-less brace map succeeds —
Q7's "one type family", Q3's boundary.

### Subtyping is where this is decided, and Q2 does not spare it

Worth stating plainly because 48 Q2 makes it easy to assume otherwise.
`is_subtype(A, B) -> is_none(subtract(A, B))` at `bs_types.erl:431`, so **every
parameter pass in the language routes through map subtraction**. Deferring the
pattern form spares `m_decompose/3`; it does not spare `m_minus/3`. A domain cell
returning the minuend unconditionally would type-check nothing and refuse
everything, and no test that only asks "is this refused?" would notice.

Each cell that cannot decide keeps the minuend **whole** — too big rather than
too small, the same honesty `{open, FA} \ {closed, _}` already applies. Too big
costs a refusal; too small costs a false exhaustiveness proof, and that is the
one thing this language promises never happens.

## The two hazards, both of which fail silent

Neither would have shown up as a red test. Each has a test of its own because of
that, and the header of `map_type_tests.erl` names both.

**1. `m_empty/2` is not the named-field rule.** A named field must be *present*,
so a field typed `none` admits no map and the member collapses. A domain is a
constraint on entries that exist, so `#{}` satisfies it vacuously and
`map<atom, none>` is **inhabited**. Reusing the field rule would make the type
empty, and every containment over it would then pass — the compiler going
quieter rather than red, which is the failure `is_none/1`'s own comment
describes.

This edge **cannot be reached from the surface**: ticket 15 §1 refuses an empty
type at its declaration and ticket 63 left negation with no spelling, so no `.bs`
file can put an empty type in the value position. It is reached from *inside*, by
`m_meet/3` intersecting the value types — `map<atom, int>` meeting
`map<atom, string>` produces a domain member whose value is `none`, and the two
maps do overlap, because `#{}` is in both. That is the one unit test in this
feature, and CLAUDE.md's exception is exactly this case.

**2. `map_cases/1` drops an unknown kind rather than crashing.** `bs_emit`
builds its validator worklist as
`[M || M = {closed,_} <- Ms] ++ [M || M = {open,_} <- Ms]`. A third kind matches
neither comprehension and is silently discarded, so `ValidateAs<map<atom, term>>`
would generate a validator that walks nothing and **certifies every term it is
handed**. Measured before the fix: it compiled and returned `ok`. It is now
refused, and the refusal is `ENG-324`'s and `ENG-323`'s shared prerequisite — a
decomposition over an unbounded key set.

## Three things the build found that the plan did not have

**The `map<K, V>` row already existed.** ENG-319 says *"`PRELUDE.md`'s stratum
tables have no `map<K, V>` row"*, and that was true when it was filed at
`7a945bb`. Ticket 67 added the row the **same evening**, at `ef6fadf`, so the
first edit of this session added a duplicate. The gate said so in the only way it
could: the probe count stayed at 11. Measuring the count rather than the exit
status is what caught it, which is the rule the count exists for.

**The describe channel and the paste channel are not the same printer.**
`m_pat/1` feeds `to_pattern/1`, which *describes* a set; `m_hd/2` feeds the head
channel, which produces text to paste back into source. Only the second runs
`nb/5`, and only `nb/5` strips `binder/1`'s delimiters — which are the raw
control bytes 0 and 1. The first cut used `binder("m")` in `m_pat/1` and the
author's diagnostic read `the declared input is ( m)`, two invisible characters
around a name. `ms_pat(top) -> ["map"]` is the convention that was already there
and was not read.

**Letting the deferral fall out of the algebra states a falsehood.** Before the
explicit refusal, `Use({ Status: s })` over a `map<atom, term>` was reported as
*"this clause's pattern is not a member of it"* — because `fields_fit/5` refuses
every `open` member conservatively. But `#{Status => 1}` **is** a member of
`map<atom, term>`; the sentence is false about the language and true only about
this compiler. `redundancy/4`'s own comment names the rule that was being broken:
*"Reporting otherwise would be the checker announcing its own ignorance as the
author's mistake."* The refusal moved to `map_pattern_diags/4`, before the walk,
and says which half of ticket 48 shipped.

## `components/1` was silently skipping the new kind

Its own comment says it exists so that *"a part added later is added here too
rather than being silently skipped by three separate walks"* — and the
`[maps:values(F) || {_, F} <- Fs]` comprehension is a **filter**, so a 3-tuple
did not crash it, it simply vanished, taking `K` and `V` with it. The failure the
paragraph warns about, arriving by the exact route it names.

## What a domain member emits

`map_field_assoc` is Erlang's `=>`, so `#{K() => V()}` is its own spelling for
this type and the emitted `-spec` is precise. The paragraph above `map_parts/1`
claims *"Nothing is widened to `map()`"* for the whole constructor, and the third
kind keeps that promise rather than becoming its first exception.
