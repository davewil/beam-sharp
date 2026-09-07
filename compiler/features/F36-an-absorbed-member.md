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
**Leaves**      the **`bins` bucket's missing sizes**. `CONTEXT.md` asserted
                that two binary types overlapping without containment are
                rejected at the declaration, and the checker cannot represent
                the question: `bin_part()` carries UTF-8-ness, not `M`/`N`.
                Ticket 30 gave sizes to binary **patterns**, not to type
                expressions, so the entry is corrected rather than the checker.
                A size partition can refine the bucket later without changing
                its shape, and this rule would then reach those unions for free

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

## Scenarios

Asserted in `compiler/test/absorbed_member_tests.erl`, which is a separate file
from `collapse_tests.erl` for the reason that file gives: a capability whose
whole behaviour is a rejection has nowhere in `examples/` to be looked at.

**F36.1 — absorption outside the failure channel.** The four shapes ENG-273
measured — `binary | string`, `atom | :ok`, `term | int`, `list<term> |
list<int>` — each resolve to a single member and reported zero diagnostics
before this feature. All four are refused now. The last is the control that
absorption reaches *through a container*: an implementation comparing only the
members' outermost constructor accepts it, since both members are lists.

**F36.2 — the failure-channel hint survives.** `option<atom>` keeps the
`nothing` hint and `result<term, atom>` keeps the `error` one, under the single
`absorbed_member` tag. These assert the discriminator rather than the prose: a
widening that dropped the channel would still pass F36.1.

**F36.3 — the diagnostic carries a path.** `Job.Tag` names a record's field and
`Route.x.1` the first element of a tuple parameter. The pair that matters is
one record absorbing at `Tag` and another at `Owner`: a path hardcoded to the
declaration, or to whichever field comes first, fails exactly one of them.

**F36.4 — every site a union can be written in.** ENG-331 made a union writable
wherever a type is, so the rule is asserted at a bare inline union in a
parameter, in a return, and in a `foreign_sig` — not only at the four nested
positions that parsed before it.

**F36.5 — indiscriminability.** `map<string, int> | map<string, binary>` keeps
both members through normalisation and no clause head reaches either, so it is
refused under the second rule rather than the first.

**F36.7 — normalise first, and the two witnesses that it was not free.** A
written member that is itself a union is **not** a member of the normalised
type. `type C = A | B` writes two and normalises to however many the algebra
keeps, so the pairs come from `bs_types:constituents/1` and not from what was
written. Pairing the written members is wrong in both directions:
`type A = map<string,int> | int` beside `type B = map<string,int> | atom` makes
`type C = A | B` **refused** though its normal form `atom | int |
map<string,int>` is decided by a guard — ticket 20:389's *"conflating them
would reject a legal type"*, exactly; and `type A = list<int> |
map<string,int>` beside `type B = A | map<string,binary>` **compiles** though
the flattening holds the two domain maps `Slot` exists to refuse, because the
lump's list spine satisfied *"something here has a pattern"*. Neither is
reachable through a union of atomic members, so every case in F36.5 and F36.6
passes without normalisation.

**F36.6 — the controls, which outnumber the refusals.** Ticket 20:389 warns
that *"subsumption is not indiscriminability, and conflating them would reject a
legal type"*, and 09 §4's stated criterion does exactly that to its own accepted
example. So every shape 68 accepts is asserted to **compile**: `list<int> |
list<binary>` (pattern reaches inside a container), `atom | int` (guard
separates two bare binders), `(:a, int) | (:b, binary)`, `map<string, int> |
int` (a domain map is not indiscriminable *on its own* — `is_map` tells it from
an int), two records, and two disjoint refined ints both nested in a tuple and
at the top. A wrong implementation of rule 2 passes every refusal above and
fails these.

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

## What the two-axis review caught, after the pair was green

Both findings were made by `/code-review` against `b3d468d` **after** 37 stages
had passed twice. Neither gate could have caught either: the suite had no union
of unions in it, and no gate compares a shipped sentence with the predicate
underneath it.

**The normalisation defect (fixed here).** The spec axis measured both witnesses
in F36.7 above and named the wrong belief in this feature's own source comment —
*"comes free here because absorption has already raised"*. It does not: absorption
proves no written member is contained by the others, which is not the same as
making each one atomic. The false positive is the serious half, since it refuses
a legal declaration.

**The container limit ([ENG-334](https://linear.app/davewil/issue/ENG-334), open,
NOT fixed here).** The standards axis measured that
`list<map<string,int>> | list<map<string,binary>>` is accepted while
`map<string,int> | map<string,binary>` is refused — the same members one
container level in. `discriminable/4` asks whether a pattern *reaches* a
constituent, never whether it *separates* the pair, and a list spine reaches
both without telling them apart. That matches 68 Q2(a) as written and
contradicts `LANGUAGE.md`'s *"can distinguish two of its members"*. It
**under**-refuses, so no legal program breaks. Deepening it decides more
programs illegal and needs its own blast radius, so it is a ticket rather than a
build call, and `LANGUAGE.md` now states the limit and cites it.

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
