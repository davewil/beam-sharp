# 63 — Negation has no spelling

Type: grilling
Status: open — [ENG-253](https://linear.app/davewil/issue/ENG-253)

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

## What it costs today

`!=` exists, so a **comparison** can be negated. What cannot be written is negation of an arbitrary
predicate: `when not IsAdmin(u)` has no spelling, and a refinement predicate cannot be complemented.

That costs more here than in most languages, because B#'s guards are *"a restricted predicate set"*
and the clause head carries the dispatch. A predicate you cannot negate has to be re-expressed as a
second clause or an inverted helper — which the exhaustiveness checker then has to see through.

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

## Notes

Do not treat `!=`'s existence as evidence that negation is available — it negates one comparison,
not a predicate. And do not assume the answer is yes: item 4 is a real reason it might not be.
