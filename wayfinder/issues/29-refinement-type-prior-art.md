# 29 — Refinement types in shipping languages: what did ticket 20 reinvent?

Type: research
Status: resolved 2026-08-13
Blocked by: —

## Question

[Ticket 20](20-untheorised-term-shapes.md) gave beam-sharp **refinement types in two tiers**,
divided by whether the predicate is a BEAM guard:

- **Guard refinements** (`type Positive = int where value > 0`) — O(1), reasoned about by the
  checker, legal in a clause head and in a foreign declaration, **user-declarable**.
- **Opaque refinements** (`type string = binary where valid_utf8`) — O(n), established once by
  generated code where a value enters, never reasoned about afterwards, **compiler-known only**.

It also brought **integer intervals** into the type algebra so that `n > 1` is credited as a type
operation, per ticket 08's rule.

**It decided all of this without a prior-art pass.** The map's borrow heuristic ran correctly —
C# has no refinement or subrange type, the BEAM has none, so tier 3 (invent deliberately) applied
— but the heuristic has **no rung for a language neither audience uses which solved exactly this
problem**. A grep of the whole map at resolution found **zero** mentions of Liquid Haskell, F\*,
Dafny, Whiley, Idris or Nim, and Ada only via ticket 21's treatment of `Pre`/`Post` **aspects**,
which is design-by-contract at the function level rather than refinement at the type level.

The decisions are **not** re-opened by this ticket. This is a check for divergence, and anything
it finds arrives as an amendment to ticket 20 in the map's normal way.

### 1. Ada and SPARK — the closest prior art, and the priority

`subtype Positive is Integer range 1 .. Integer'Last` has been in the language since **Ada 83**,
with Pascal's subrange types behind it from 1970. Establish, from primary sources:

- What a range-constrained subtype actually guarantees, **where** the compiler inserts checks, and
  what raises `Constraint_Error` at runtime versus what SPARK proves statically.
- **Ada 2012's `Static_Predicate` versus `Dynamic_Predicate`.** If these split predicates by what
  the compiler can decide, that is ticket 20's two-tier structure reached independently on a
  different platform — the strongest possible corroboration, or the sharpest available
  counter-example. **This is the single highest-value question on the ticket.**
- Whether subtypes confer **type identity**. Ticket 20 concluded refinements do not, because
  ticket 09 made naming pure aliasing — so `Meters` and `Feet` over a non-negative `float` remain
  one type. Ada has nominal typing and `type ... is new Integer`, so it may separate *subtype* from
  *derived type* exactly where beam-sharp cannot. If so, say what Ada buys with nominality that
  beam-sharp forfeited in ticket 09, and whether ticket 09's tuple-tag remedy is the same trade.
- Whether a user may declare a predicate the compiler **cannot** decide, and what happens if so.

### 2. Does any language split refinements by decidability of the predicate?

Ticket 20's line is *"is the predicate a guard the runtime decides in O(1)?"* Look for the same
split elsewhere under any name — static vs dynamic predicates, decidable vs SMT-discharged,
checked vs assumed. **Liquid Haskell** and **F\*** discharge refinements through an SMT solver;
establish whether either offers a cheaper tier for arithmetic-only predicates, or whether the
solver is unconditional. **Nim's `range[0..10]`**, **Whiley** and **Dafny** are the other
candidates.

The specific worry to answer: ticket 20 argued intervals are affordable *because* they are not
SMT. Verify that this distinction is real in a shipping implementation rather than a hopeful line
— i.e. that someone ships interval-only refinement reasoning without a solver, at a cost anyone
has published.

### 3. CDuce's intervals, measured rather than cited

CDuce is named **88 times** across this map and has never been *measured*. The
evidence-provenance rule says prefer measuring to citing, and ticket 20 leaned on *"CDuce has
them, so this is a paved path"* — inherited from ticket 11, never checked.

Install CDuce if it can be installed, and establish what its integer intervals actually do:
union, intersection, complement, and what the checker costs at the clause counts ticket 04 flagged
as pathological. If it cannot be installed, say so explicitly and downgrade every CDuce claim on
the map from `doc` to what it really is.

### 4. Structural binary typing outside Erlang

Ticket 20 adopted `<<_:M, _:_*N>>` from Erlang as a tier-2 borrow. Establish whether any *typed*
language types bit-level structure — sized or unit-constrained binaries as a first-class type
rather than a parsing library. Gleam's `BitArray` is the obvious near-miss; look wider. If nothing
does, that is worth knowing: it makes the borrow a genuine differentiator rather than table
stakes.

### 5. The `string` versus `binary` borrow ticket 20 missed

Ticket 20 decided `string` on the `json:encode/1` evidence alone and never noticed the borrow
heuristic supports it independently — C# has `string` and `byte[]`, TypeScript has `string` and
`Uint8Array`. Confirm the tier-1 reading, and check what each does when bytes are **not** valid
text, since that is the case ticket 20's generated entry check exists for.

## What this ticket must produce

A findings file at `research/29-refinement-type-prior-art.md`, claims marked `doc` / `src` /
`local` per the map's provenance rule, and an explicit verdict on each of:

- Does Ada's static/dynamic predicate split corroborate or contradict ticket 20's two tiers?
- Is interval-only refinement reasoning without a solver a thing anyone ships?
- Do ticket 20's decisions need amending, and if so which?

## Answer — 2026-08-13

Findings: [`research/29-refinement-type-prior-art.md`](../research/29-refinement-type-prior-art.md).
Probes: [`29a`](../prototypes/29a_cduce_intervals.sh), [`29b`](../prototypes/29b_cduce_clause_scaling.sh),
[`29c`](../prototypes/29c_ada_predicate_tiers.sh), [`29d`](../prototypes/29d_string_vs_bytes.sh),
[`29e`](../prototypes/29e_binary_structure_in_types.sh), [`29f`](../prototypes/29f_spark_proves_predicates.sh).

**Nothing ticket 20 decided is wrong.** The three questions this ticket owed:

1. **Ada corroborates the structure and contradicts the cut.** Two tiers, the privileged one legal
   in a dispatch construct and participating in coverage checking, shipped since 2012 — reached
   independently on an unrelated platform. But Ada cuts on the predicate's **syntactic form**, not
   its cost: `Odd mod 2 = 1` is refused the static tier while `Positive_Ish > 0` is accepted, at
   identical runtime cost (GNAT 12.2 [L3]). **Ticket 20's line is attested nowhere in the prior art
   surveyed.** The two cuts stand in **containment, not conflict** — every Ada static predicate is
   one BEAM guard and the converse fails — so beam-sharp liberalises a line Ada drew syntactically
   for want of a platform-given decidable predicate language.
2. **Yes — solver-free interval refinement ships.** CDuce 0.6.0 (2017-03-17, installed via
   `archive.debian.org`) is exact at union, intersection, complement and difference over integer
   intervals with **no SMT library linked** at binary or package level [L6], which turns ticket 20's
   affordability argument from asserted into demonstrated. Nim carries solver-free interval
   reasoning too, but pragma-gated, warning-only, with no user-declarable predicate [s3]. Nobody had
   published the cost; [`29b`](../prototypes/29b_cduce_clause_scaling.sh) now does — **below the
   measurement floor at ticket 04's 40-clause shape, quadratic past ~200** [L7].
3. **Five amendments, all taken; a sixth carried as a caution.** A (record the cut as a tier-3
   divergence with its reason), C (CDuce `doc` → `local`, pinned), D (the `string`/`binary` split is
   a tier-1 borrow, and U+FFFD substitution is the deliberate divergence), E (a third `erl_types`
   lossiness — `t_bitstr(8,72)` → `<<_:64,_:_*8>>`, motive *termination*, and beam-sharp escapes it
   because ticket 04 made signatures mandatory) are recorded in
   [ticket 20 §"Amended by ticket 29"](20-untheorised-term-shapes.md). **B was David's call and was
   taken narrowed**: user-declared opaque refinements are **barred from clause heads and foreign
   declarations, permitted elsewhere** — not barred outright. F is a caution, not an amendment: Ada's
   predicate checks are absent without `-gnata` where beam-sharp's have no opt-out, so a reader
   arriving from Ada will expect an assertion policy that does not exist.

**Gap [g3] is closed** — the one gap the amendments turned on. GNATprove 12.1.0 **discharges a
`Dynamic_Predicate` statically whenever the caller's contract entails it, including an O(n) content
predicate** [L10], so Ada's permissiveness is not "permit and check later". It is also why B narrowed
to placement rather than opening: SPARK proves it where the caller is inside the verified subset, and
at beam-sharp's boundary the caller never is. Residual limit: `alt-ergo` would not run, so a
*negative* proof result from these probes must not be read as unprovable.

**What this leaves owed** — recorded on [ticket 20](20-untheorised-term-shapes.md) §5 and surfaced in
the map's **Not yet specified**: whether the compiler may emit a call to arbitrary user code at a
boundary; a spelling for the check site, since beam-sharp has no subtype-conversion site to hang one
on; and what happens when a user predicate itself raises (ticket 15's `result<T, E>`, with Ada's
`Predicate_Failure` as the worked precedent).

## Notes

AFK. Raised 2026-08-13 immediately after ticket 20 resolved, on David's call, because the ticket
invented a mechanism without checking who had built one before. Does not block anything; ticket
20 stays closed.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Refinement types in shipping languages: what did ticket 20 reinvent?](issues/29-refinement-type-prior-art.md)
  — the prior-art pass ticket 20 was resolved without. **Nothing it decided is wrong**, and the
  amendments are folded into 20's entry above; what belongs to *this* ticket is the verdict.
  **Ada corroborates the two-tier structure and contradicts the cut** — it divides on the
  predicate's *syntactic form*, not its cost, so beam-sharp's O(1) line is **attested nowhere in the
  prior art surveyed** (Ada, Liquid Haskell, F\*, Nim, Whiley, Dafny) and is a tier-3 divergence
  rather than the map's recurring rule applied again. The relation is **containment**: every Ada
  static predicate is one BEAM guard, so beam-sharp liberalises a line Ada drew for want of a
  platform-given decidable predicate language. **Solver-free interval refinement does ship** — CDuce
  0.6.0 measured at last, exact including complement, no SMT linked, free at 40 clauses and quadratic
  past ~200 — which is what turns 20's affordability argument from asserted into demonstrated. And
  **GNATprove discharges an O(n) content predicate statically when the caller's contract entails
  it**, the measurement that narrowed 20's blanket refusal to a placement rule. Method note worth
  keeping: the borrow heuristic ran *correctly* and still missed this, because it has no rung for a
  language neither audience uses which solved exactly this problem — the reason to raise a prior-art
  ticket is the mechanism being invented, not the heuristic misfiring.
```
