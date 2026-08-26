# 63 — Negation has no spelling

Type: grilling
Status: **RESOLVED 2026-08-26 — no `not`, no `!`; the absence teaches** —
[ENG-253](https://linear.app/davewil/issue/ENG-253). Answer and full reasoning in
[`decisions.md`](../decisions.md); built the same day as
[F27](../../compiler/features/F27-no-negation.md), gated by `compiler/bin/check-negation.sh`.
David's answers to the round are at the foot of this file.
All four of *Open* below are measured; item 4's stated reason is **false** and the correction is the
answer. Probes [`63a`](../prototypes/63a_can_the_algebra_complement.escript),
[`63b`](../prototypes/63b_guard_probe/), [`63c`](../prototypes/63c_guards_close_under_complement/);
63b and 63c are run together by [`63bc_run.sh`](../prototypes/63bc_run.sh), which states the exit code
each of its five cases must produce before running them.
The recommendation is **no `not`**, on redundancy — see *Measured* and *The round* at the foot.

Raised 2026-08-25 by David while reviewing the complete terminal alphabet:
*"Keywords is missing not at the minimum."*

## Question

**B# can spell conjunction and disjunction and cannot spell negation.** Measured: there is no `not`
token in `bs_lexer.xrl` and no production for it in `bs_parser.yrl`.

## Why this is a gap and not a decision

[Ticket 44](44-conjunction-spelling.md), amending [ticket 08](08-head-and-guard-syntax.md), settled
the conjunction spelling — *"One spelling now, in every position — pattern, guard and refinement
predicate — and `&&`/`||` are removed rather than kept as synonyms."* It decided `and` and `or`.
**It says nothing about negation**, and neither does any other ticket. This is a hole, not a
recorded omission that can be cited.

*Corrected 2026-08-26: "neither does any other ticket" was too strong. No **ticket** covers
negation, but `bs_parser.yrl:337-339` carries a decided rationale for refusing general negation in
**pattern** position, which narrows this ticket's scope to two positions rather than three. See
Measured §1.*

## What it costs today

`!=` exists, so a **comparison** can be negated. What cannot be written is negation of an arbitrary
predicate: `when not IsAdmin(u)` has no spelling, and a refinement predicate cannot be complemented.

That costs more here than in most languages, because B#'s guards are *"a restricted predicate set"*
and the clause head carries the dispatch. A predicate you cannot negate has to be re-expressed as a
second clause or an inverted helper — which the exhaustiveness checker then has to see through.

*Corrected 2026-08-26: this section's example does not hold. `when IsAdmin(u)` is **illegal** —
a user function cannot appear in a guard at all (63b) — so `when not IsAdmin(u)` was never available
with or without a `not`, and the cost described here is not a negation cost. See Measured §4.*

## Open

1. **Is `not` wanted at all?** `is_atom/1` and friends are recorded as *"absent by design — the
   clause head and the checker do this"*, and the same argument might reach negation.
2. **If wanted, how is it spelled?** `not` follows `and`/`or` and the Erlang family. `!` follows the
   C# family, but that spelling was settled out of B# identifiers and `!=` already uses the
   character.
3. **Where is it legal?** 44's answer for `and`/`or` was *"every position — pattern, guard and
   refinement predicate"*. The same scope is the obvious default and should be stated, not assumed.
4. **Does the checker complement cleanly?** `bs_types` has **no negation node** — measured
   2026-08-25, and it is why `m_minus({open, _}, {closed, _})` over-approximates rather than
   computing the difference. A `not` over a refinement predicate may be asking the algebra for
   exactly the thing it cannot represent. **This is the question that could make the answer "no".**

   *Corrected 2026-08-26. The first half is true and the second does not follow. The algebra
   complements **exactly** — cofinite atom sets close it under complement with no negation node,
   `bs_types.erl:20-23` — and `m_minus`'s widening has a different, named cause. Item 4 is not a
   reason to refuse. See Measured §2.*

## Notes

Do not treat `!=`'s existence as evidence that negation is available — it negates one comparison,
not a predicate. And do not assume the answer is yes: item 4 is a real reason it might not be.

*Corrected 2026-08-26: item 4 is **not** a real reason it might not be — it was measured and
falsified. The real reason to refuse is redundancy, which is a different argument and is set out
below. The first sentence stands.*

---

## Measured 2026-08-26 — four of this file's own claims, and what they turn into

This ticket's *Open* list is four claims, not four facts. Measuring them first is the repo's rule
after ticket 43, where two premises were false and the corrections **were** the answer. Three of the
four here survive; the fourth — the one the file nominates as *"the question that could make the
answer 'no'"* — does not.

### 1. The two grammar claims hold, and pattern position is already decided

`not` is absent from `bs_lexer.xrl` and from `bs_parser.yrl` — verified separately rather than as
one fact. Every textual hit in both files is prose in a comment. `and` and `or` are two ordinary
token rules (`bs_lexer.xrl:101-102`), so the lexer cost of a `not` is one more line.

**But item 3's assumed default scope is one position too wide.** It proposes *"every position —
pattern, guard and refinement predicate"* by analogy with ticket 44. Pattern position has already
refused general negation, with a reason on the record at `bs_parser.yrl:337-339`:

> A pattern takes a negative LITERAL and not a general negation, because a pattern is a value and
> `-x` is a computation. The interval algebra needs nothing new: `range(-1, -1)` is what `p_int`
> already produces.

So the live scope is **two** positions, not three, and 44's answer cannot simply be copied across.

### 2. The algebra complements EXACTLY — item 4's reason is false

Item 4 says `bs_types` *"has no negation node… and it is why `m_minus({open, _}, {closed, _})`
over-approximates"*. Those are two claims welded together. The first is true. The second is not, and
the module's own header says why, twenty lines in:

> Atoms are held as a finite set or a **cofinite** one, because ticket 10 made the atom universe
> open: `atom` is the cofinite top, and `atom \ :ok` has no finite representation. **Cofinite sets
> close the algebra under complement without a negation node.**
> — `bs_types.erl:20-23`

A missing negation *node* and an inability to *complement* are different things.
[`63a`](../prototypes/63a_can_the_algebra_complement.escript) measures the difference, each arm with
a control:

| | measurement | result |
|---|---|---|
| M1 | `atom \ (atom \ :ok)` | **`:ok`** — double complement round-trips, so atoms complement exactly |
| M2 | `binary \ string` | **representable and printed**, and the reverse direction is `none` |
| M3 | `open{Kind::user} \ closed{Kind::user}` | minuend kept **whole** — while `closed \ closed` is exact |
| M4 | the reason the source gives | *"these fields, plus at least one more"* — an unnameable **map member** |

M3's control is the load-bearing one: the *same* call shape subtracts exactly when both members are
closed, so the widening belongs to the open/closed pairing and not to map subtraction in general.
A negation node would not touch it — what the open member cannot name is a **cardinality**
("at least one more field"), which is a different missing thing.

**And M2 is the case item 4 actually fears** — `not` over a refinement predicate. `string` is a
refinement of `binary` (20 §4), and its complement inside its base is exactly what such a `not`
would denote. It is representable today. `bs_types.erl:998-1002` names the real gap, and it is the
opposite of the one this ticket assumed:

> the surface has a word for the top and a word for the refinement, and **none for the complement of
> a refinement inside its base**. It is representable because the alternatives are unsound…

So `not` is not asking the algebra for something it cannot represent. It is asking the **surface**
for a word the algebra already has. That inverts item 4 from a reason to refuse into an argument to
consider.

### 3. The guard fragment is already closed under complement

The reason to refuse is elsewhere, and it is redundancy. `alternatives/1` (`bs_check.erl:2659-2693`)
is the only thing that reads a guard, and the fragment it translates is small and exact:

- `and` / `or` over comparisons — **De Morgan duals, and both are in the language**;
- six integer comparisons, `>` `>=` `<` `<=` `==` `!=`, variable against literal in either order;
- two atom comparisons, `==` and `!=`;
- **anything else is `unknown`.**

Every operator in that set has its own complement inside the set. `not (n > K)` is `n <= K`;
`not (n == K)` is `n != K`; `not (a == :ok)` is `a != :ok`. The set is closed by construction.

[`63c`](../prototypes/63c_guards_close_under_complement/) states that claim in the strongest form the
language offers. A clause pair split on `P` and `complement(P)` **with no catch-all** compiles only
if the checker proves the two together exhaust the domain — so this is closure in the *type algebra*,
not agreement at run time. All nine pairs compile at exit 0, and both controls are refused:

| file | result | what it shows |
|---|---|---|
| `Complement` — 9 pairs, no catch-all | **exit 0** | six int operators, both atom operators, both De Morgan rewrites |
| `NotComplement` (int control) | **refused** | `Gt is not exhaustive … Gt(int <= 999)` |
| `NotComplementAtom` (atom control) | **refused** | `AtomEq is not exhaustive … AtomEq(atom \ (:error \| :ok))` |

The atom control earns its place. `atom` is the cofinite top and ticket 12 permits a catch-all over
an **open** residual, so the atom pair could have compiled from permissiveness rather than from
`!=` being exact. It could not: two includes over an open domain are refused, and the residual is
printed as a complement — `atom \ (:error | :ok)` — which is M2's finding showing up in a diagnostic.

### 4. `when not IsAdmin(u)` is not a negation gap

This file's motivating example assumes the un-negated `when IsAdmin(u)` is legal. It is not.
[`63b`](../prototypes/63b_guard_probe/) compiles it:

    erlc: guardprobe.bs:21: call to local/imported function 'IsAdmin'/1 is illegal in guard

with a control differing in one respect — `u == 1` instead of `IsAdmin(u) == :yes` — that compiles
at exit 0. Erlang admits only guard BIFs in a guard, never a user function, and B# emits Erlang
Abstract Format, so the restriction is inherited.

**So the example was never available with or without a `not`.** Whether guards should admit
user-defined predicates at all is a real question, and a much larger one — it is not this ticket, and
on this platform it does not have an easy answer.

That measurement also surfaced a defect, filed separately rather than fixed here: **the refusal is
raw `erlc` text**, in Erlang's words and Erlang's arity notation, naming a file the author never
wrote. F16 made the diagnostic a term and prose a pure function of it; this one escapes that
machinery entirely. → **ENG-256**, which takes no `wayfinder/issues/` file: it is a compiler defect
rather than a map ticket, and the precedent is ENG-249, found the same way while probing ticket 48.

### 5. What the neighbours negate, measured rather than cited

A survey looks unanimous — Erlang, Elixir, Gleam and Roc all spell negation — and resolving against
a unanimous survey is a reversal waiting to happen. It is not unanimous against *this* question,
because the neighbours negate something B# has not got.

Every `not` inside a guard in OTP 28's `stdlib` and `kernel`, 16 unique occurrences, read directly
rather than counted by a regex that also catches English prose in comments:

    not is_list(…) ×8   not is_tuple(…) ×4   not is_map_key(…) ×3
    not is_pid(…)       not is_function(…)   not is_binary(…)   not is_integer(…)

**Sixteen of sixteen wrap a type test or `is_map_key`. Not one wraps a comparison.** And type tests
are recorded in `PRELUDE.md:134` as *"absent by design — the clause head and the checker do this"*,
while `is_map_key` is a **pattern** in B# (`{ Kind: k }`), which is head-level too. The category
Erlang's `not` exists to negate is the category B# deliberately moved into the clause head.

So B# is not diverging from four neighbours here. The construct they negate does not exist in this
language, and the construct B# does have — a comparison — they negate with an operator B# also has.

---

## Recommended answer — no `not`

**On redundancy, not on danger.** An earlier draft of this section argued that an unlearned `not`
would be *harmful*, and that is wrong in the direction that matters. `bs_check.erl:2636-2645` is
explicit: a guard the checker cannot read yields `{none, Ty}`, so the clause credits **nothing** —

> A guard the checker cannot read might always fail, so nothing is guaranteed to be matched here.
> Getting this backwards let `F(n) when Weird(n)` report as exhaustive, which is the precise failure
> the map's guarantee exists to rule out; a test caught it.

An unlearned `not` in a guard would therefore make the function **refused as inexhaustive** — loud,
and sound. In a refinement it is louder still: an untranslatable predicate there is
`{opaque_refinement, Line}`, a hard error (`bs_check.erl:985-987`), because a refinement that
resolved to its bare base would silently admit the opaque tier 29 barred. Neither position can be
made unsafe by a `not`. So the case against is only this:

1. **Where the checker can read the guard, `not` adds no expressive power** — the fragment is closed
   under complement, measured nine ways with two controls (63c).
2. **Where it cannot, `not` adds none either** — the clause is refused rather than credited.
3. **A `not` the translator *did* learn would be a De Morgan rewrite into the existing fragment** —
   it would compile `not (n > K)` into precisely the `n <= K` the author could have written. A
   construct whose entire implementation is "rewrite it into the spelling you already have" is the
   definition of redundant.
4. The refinement position shares one translator with guards by construction — *"the checker then
   reads it back with the SAME `alternatives/1` a guard goes through. One translator, so a refinement
   and a guard cannot come to disagree"* (`bs_parser.yrl:195-199`) — so the closure result covers it
   without a second measurement.
5. Pattern position already refused general negation for an unrelated and still-good reason.

**This is a tier-3 divergence and should be recorded as one**: B# declines a construct all four
neighbours have, because the thing they use it for lives in the clause head here.

### What it costs, stated honestly

The one thing that becomes unsayable is the complement of a predicate the checker cannot read — and
that is already unsayable, since such a predicate cannot appear in a refinement at all and credits
nothing in a guard. **`PRELUDE.md`'s open collection library is where this could change**: if a
future `Map.HasKey` or `List.Any` becomes guard-legal and compiler-known, it would be the first
guard predicate with no complement operator beside it, and this decision should be re-opened then
rather than assumed to have covered it. That is the trigger to write down, and it is Q3 of the
round below.

### The delta if the answer is yes, so this is a choice between two costed options

- **Lexer** — one rule, `not : {token, {'not', TokenLine}}.` beside `and`/`or`.
- **Parser** — one prefix production and a precedence entry above `and`. Unmeasured: yecc conflicts
  must be counted with `yecc:file/2` on the before and after grammar, with both controls the way
  `48k` did it (pristine → 0, a deliberate reduce/reduce grammar → non-zero), because a quiet rebar
  build proves nothing.
- **Checker** — a De Morgan clause in `alternatives/1`: push `not` inward through `and`/`or`,
  flipping each leaf with the existing `flip/1` extended to `==`/`!=`. No new node in `bs_types`,
  because nothing new needs representing.
- **Emitter** — nothing, if the rewrite happens before emission; the emitted guard is the existing
  comparison either way.

That delta is small. It is not the reason to refuse — redundancy is.

---

## The round — put 2026-08-26

Recorded here rather than only in chat: round 3 of ticket 48 lived in conversation and its numbers
silently collided with round 1's.

**Q1 — Is `not` refused?** Recommended **yes, refused**, on the redundancy argument above and
recorded as a deliberate tier-3 divergence. The alternative is to take it for familiarity alone: a
C#/TS reader reaches for `!` on sight, and *"a construct a C# developer reads on sight versus one
they must be taught"* is the map's own test. Refusing means a reader who writes `not` gets a
diagnostic; **if refused, that diagnostic should name the complement operator to use**, which turns
the absence into a teaching moment rather than a gap.

**Q2 — If taken instead, is it `not` or `!`?** `not` follows `and`/`or` and the platform; `!` follows
C#/TS but the character is already spent on `!=`, and ticket 55 settled `!` out of B# identifiers.
Recommended **`not`** if Q1 goes the other way.

**Q3 — Does the refusal get a re-open trigger?** Recommended **yes**: the first guard-legal
compiler-known predicate that is not a comparison re-opens this. `PRELUDE.md`'s collection library is
open, so this is reachable rather than theoretical.

**Q4 — Does `when` admit user-defined predicates at all?** Not this ticket, and 63b shows the answer
is currently *no* by inheritance from the BEAM rather than by decision. Worth its own ticket if it is
wanted; say so and it gets raised.

---

## Answered 2026-08-26 — David

The round above was put into this file and into ENG-253 and **not in front of David**, who read the
recommendation as a resolution: *"I didn't see any questions and thought it was decided not isn't
required."* The repo's rule is that a round is not asked until it is in the ticket, and that was
kept; what it does not cover is that it also has to be **asked**. Recording the gap here because the
rule as written was satisfied while the round still sat unanswered for two hours.

**Q1 — refused, and the diagnostic teaches the complement.** Not a plain syntax error. The message
names the opposite of each comparison the guard fragment admits, so a reader who types `not` is told
what to write. `!` is covered on the same grounds — it is the spelling the C#/TS audience reaches
for on sight, and the map's own test is *"a construct a C# developer reads on sight versus one they
must be taught"*.

**Q2 — moot.** It only applied if Q1 went the other way.

**Q3 — yes, the refusal carries a re-open trigger**, and building it surfaced a second. Both are in
[`decisions.md`](../decisions.md): the first guard-legal, compiler-known predicate that is not a
comparison; and a **lambda**, which would make `not (` parseable and change what the detection rule
can assume.

**Q4 — left as it is, with no ticket.** User-defined predicates in guards stay illegal by
inheritance from the BEAM. Consequence worth knowing: this **stabilises ENG-256's repro**, since the
input that provokes the raw `erlc` text stays illegal rather than becoming legal under a later
decision.

## What the build corrected in the estimate above

**The delta quoted for the *no* branch was "none", and that was wrong.** It is stated in *The delta
if the answer is yes* that refusing costs nothing in the compiler — true of the refusal, false of
the obligation David attached to it. Unlike `;`, `not` **lexes perfectly well** as an identifier, so
nothing would have noticed it without a rule. What shipped: two `descriptor/2` clauses, one
`message/1` clause, a `not_in_prefix_position/2`, and the tokens now travelling with the parse error.

**And the two positions fail at different tokens**, which the ticket's §4 argument would have hidden.
That argument — *"one translator, so a refinement and a guard cannot come to disagree"* — is about
`alternatives/1` in the **checker**, and the diagnostic lives in the **parser**, which they do not
share. Measured: `when not (n > 100)` fails before `'('`, `int where not (value > 100)` fails before
`'>'`. An implementation keyed on the token yecc reported would have covered guards and missed
refinements silently. F27's gate asserts them separately for that reason.
