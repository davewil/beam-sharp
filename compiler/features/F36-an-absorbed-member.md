# F36 — an absorbed member, and a union no clause head can take apart

**Status**      **done 2026-09-07** — 20 new tests, 677 in the suite, up from
                657. No new gate: `check-language.sh` already compiles every
                `csharp` block and already judges a `diagnoses:` claim, so both
                refusals are demonstrated and checked by the gate that was
                there. `check-collapse.sh` covers the widened rule unchanged
**Implements**  [ticket 68](../../wayfinder/issues/68-an-absorbed-member.md),
                resolved 2026-09-06 over five rounds. 68 settled both rules,
                both sentences, the diagnostic's path, the grammar's reach and
                how matchability is decided; this file builds them and decides
                nothing
**Decides**     **two spellings, and they are named here rather than left
                implicit, because 68 named neither**: the two diagnostic tags
                are `absorbed_member` and `indiscriminable_union`, and the path
                is **dotted text** (`Job.Tag`, `Route.x.1`) rather than the
                prose 68 Q5(b) sketched for a parameter (*"the first element of
                Route's parameter"*). Dotted text is one renderer for every
                position and is what the tests assert; if David wants the prose
                form for parameters, this is the line to overrule. The old tag
                `collapsed_failure_channel` is **gone**, because 68 Q3 ruled the
                failure channel a hint variant and *"not a tag of its own"*, and
                a tag still named for it would lie about the 3 shapes it now
                covers
**Closes**      [ENG-332](https://linear.app/davewil/issue/ENG-332)
**Depends on**  [ENG-331](https://linear.app/davewil/issue/ENG-331) (2026-09-07),
                which made a union writable in `param`, `signature` and
                `foreign_sig` — without it rule 1 could not fire at a bare
                inline union, only at the four nested positions; and F31, whose
                `absorbed/2` predicate is reused **unchanged**
**Leaves**      the **`bins` bucket's missing sizes** — `CONTEXT.md` asserted
                that two binary types overlapping without containment are
                rejected, and the checker cannot represent that: `bin_part()`
                carries UTF-8-ness, not `M`/`N` (ticket 30 open). The entry is
                corrected rather than the checker; and **ticket 64's Q1/Q4**,
                which 68 Round 2 said to mark answered in 64's own file — see
                *What is owed* below

## The two rules, and why they are two

1. **An absorbed member is an error where it is written.** Any member `M` where
   `M ⊆ union(others)`. This generalises F31 from the failure channel to every
   member: the predicate `absorbed/2` is untouched, and what went is the
   `failure_channel/1` filter in front of it.
2. **A union no clause head can take apart is an error where it is written.**
   Ticket 09 §4, built at last, with 68 Q2(a)'s corrected criterion:
   reachability by a **clause head, pattern or guard**, not 09 §4's own *"a BEAM
   guard"*, which refuses `list<int> | list<binary>` that the same section
   lists as accepted.

**The order is the rule, not an optimisation.** Absorption raises first, so
indiscriminability only ever sees members that survived normalisation — 09 §4's
own *normalise first, then check pairwise*, which is what keeps `:ok | atom`,
the section's named false positive, out of the second rule's reach.

## The matchability oracle (68 Q8(b), Q9(b))

`head_parts/2` is refactored onto a structured intermediate: each part is
tagged `shape`, `guarded`, `binder` or `annotated`. The printer renders the
text and the oracle reads the tag, and **neither reads the other's words** —
the mistake this codebase already made once, when `pattern_parts/1` was reached
for as an oracle and returned `"map<string, int>"` beside `"[int, ..]"`.

Only the pattern half is volatile. `map<K, V>` is the one `annotated` in the
language, and the day ticket 48 ships a map pattern form `m_hd/2` stops
returning one and this refusal stops firing **with no edit to the check**. The
guard half stays a table (`guard_buckets/1`) because it is the BEAM's
vocabulary rather than the language's.

**`guarded` is a fourth kind and 68 did not name it.** A bounded int span prints
as a relational pattern at argument position and as a binder-plus-`when` below
it. With three kinds and the oracle asked at `nested`, two disjoint refined ints
inside a tuple are both "a bare binder in the int bucket" and the union is
refused — though `n when n >= 10` decides them, and Q2(a)'s criterion says
*pattern **or guard***. The oracle is asked at `nested` deliberately: it is the
conservative position, the two differ for exactly this one constructor, and both
of its spellings reach, so a member reachable at `nested` is reachable at `arg`.

## The finding: `head_parts/2` never terminated on a recursive type

`unfold/1` substitutes the **whole `mu`** back into its own body rather than
leaving a `recvar` behind, so `hd_parts/3` met the same `mu` again one level
down and unfolded it again, forever. The printer's own header had said since
F28 that one unfolding is *"all that terminates and all that is useful"* — the
implementation never enforced it, and **no caller had ever reached the case**,
because a residual over a recursive type is not a shape the diagnostics reach.

The oracle is the first caller that asks about an arbitrary declared type, so
`type Tree<T> = (T, list<Tree<T>>)` under `option<Tree<int>>` hung the suite.
The fix is the guard the paragraph already described: a `Seen` list of `mu`
names, and a repeat renders as a binder, which is what the `recvar` clause did
and what a hand-written clause does. This was latent on master and is fixed
here rather than filed, because the feature cannot land without it.

## Blast radius: the ticket measured one test, and there were two

68 measured **one** — `strings_tests:string_or_binary_absorbs_to_binary_test`,
whose doc twin is F9.7. Both are updated, and F9.7 keeps its reasoning: *"09 §4
errors on indiscriminable members and `string` is nested"* is still true, and
the rule that refuses it did not exist when the sentence was written.

The second was **not** in the measurement, because the sweep read top-level
union declarations and this one is a union of two *spellings of one type*:

    records_tests:a_hand_written_type_with_the_same_tag_is_the_same_type_test

`type Either = Order | Spelled`, where `Spelled` is a hand-written map carrying
`Order`'s minted tag. F3.2 asserted it compiles, to prove the mint is not a
nominal identity. Under rule 1 each member absorbs the other, so it is refused —
**and the refusal proves the same thing more directly**: were the mint nominal,
the two would be distinct types, neither would absorb the other, and the
program would compile. The test asserts the refusal and says so.

## The record, checked rather than assumed

- **Ticket 64's Q1 and Q4 were already marked answered** when 68 resolved, at
  `64-failure-types-collapse-at-term.md:51-65`, struck through and attributed.
  Nothing owed. *(This file first claimed the opposite; the claim was checked
  and was false.)*
- **09 §4's own text was not.** Its criterion still read *"discriminable iff the
  compiler can synthesise a BEAM guard expression that decides it"* — the
  wording 68 Q2(a) overturned for refusing `list<int> | list<binary>`, which the
  same section lists as accepted — and the ticket cited 68 nowhere. The compiler
  now enforces a criterion its own source ticket contradicted, so an amendment
  is recorded there. It records a decision 68 made; it does not make one.
