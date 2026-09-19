# F53 — the numeric-union mixed pair, and the type prefix that takes it apart

**Status**      **done 2026-09-19** · [ENG-394](https://linear.app/davewil/issue/ENG-394) — 21
                tests in `type_prefix_tests`, 1033 in the suite, up from 1011; new gate
                `check-advice-compiles.sh`, seen red on the tree before the build, with three
                fabricated advices in its `--self-test`; `examples/Ledger/ledger.bs`, one roster
                row and the tour section it obliges; the clean-pair evidence is the dated line at
                the end of this file
**Implements**  [ticket 83](../../wayfinder/issues/83-a-union-operand-at-an-operator.md) (a union
                whose parts are all numeric is the mixed pair at an operator) and
                [ticket 84](../../wayfinder/issues/84-dispatching-the-parts-of-a-numeric-union.md)
                (a clause head dispatches the parts with the type prefix). It **decides nothing**
**Depends on**  F51 (the `float` part and the mixed-pair refusal this widens), F22 / ticket 55
                (the type prefix over a record, which this extends to a part), F2 (the relational
                pattern whose lowering slot the new pattern shares), F24 (the boundary kind test,
                whose `is_float` is the same BIF one site over)
**Leaves**      whether a NAMED type may wear the prefix — a refinement (`Meters m`) or an alias
                to a part (`Amount a`) — raised as
                [ticket 85](../../wayfinder/issues/85-which-names-may-wear-the-type-prefix.md) /
                [ENG-395](https://linear.app/davewil/issue/ENG-395) and not decided; `term x`, refused
                for spanning every part rather than decided either way; a numeric union with a
                non-numeric part (`int | float | :none`), which ticket 83 scoped out and which
                keeps the older behaviour; `Int.FromFloat`, still named and not decided, which is
                why `Pence` below returns the union rather than narrowing to `int`

## Why the two ship together

**The refusal's only correct advice is a form that did not parse.** Ticket 83 refuses
`amount * 100` over an `int | float`, and the refusal next door, `mixed_operands`, advises the
author to write the int literal as a float. Over a union that spelling is refused too — the
`int` part would stand beside a float, and ticket 80's no-flow rule is symmetric — so the only
thing left to say is "dispatch the parts", which was a syntax error until this feature.

F19 shipped the other version of this: a refusal whose recommended workaround carried the exact
lie the refusal existed to prevent. Nothing caught it, because a test asserts the *words* of the
advice and words that read well are what the defect looks like. Hence the gate below.

## What ships

```csharp
module Ledger

type Side = :debit | :credit

public Side Post(int | float amount)

Post(int a)   when a < 0   -> :credit
Post(int a)                -> :debit
Post(float f) when f < 0.0 -> :credit
Post(float f)              -> :debit
```

```
$ bsc --src-root examples examples/Ledger Post -2.50
:credit
$ bsc --src-root examples examples/Ledger Post -250
:credit
```

Measured at `44ca20c`, before this feature, the same rule written the only way available
answered `:debit` for `-2.50`: a £2.50 refund posted as a charge. `a < 0` fell through
`op_result/5` to `op_type/1`, which answered `int` for any operand in neither part, and the
emitter conjoined ENG-330's `is_integer` — silently removing the float half of the parameter
from the clause.

The body face of the same hole was worse, because nothing about it looked like a guard:

```csharp
public int Owed(int | float amount)

Owed(a) -> a * 100
```

It compiled, published `int Owed(int | float)` through `--api`, and `Owed(-2.50)` returned
`-250.0` — a float from a function declared `int`, which is what §10's guarantee exists to rule
out and what F42 closed at every *foreign* declaration on 2026-09-11.

## The delta, site by site

**The grammar.** Two productions, `lident lident` and `lident '<' type_list '>' lident`, minting
`{p_type, Line, TypeExpr, Var}`. NOT `type_prim`, which reaches `uident` and would collide with
ticket 55's record path. The generic spelling parses so that the checker can refuse it in
`map<K, V>`'s words; a grammar that stopped it would answer "syntax error before: ns", which says
none of that.

Measured at **zero conflicts added, over a baseline of 5 shift/reduce**, by
[`84a_type_prefix_yecc.sh`](../../wayfinder/prototypes/84a_type_prefix_yecc.sh) with `yecc:file/2`
and `{report, true}`, both productions, with a reduce/reduce control proving the harness can see
one. 55f's three zeros do not carry over — every variant there began with a `uident` — and 55f's
own "baseline zero" comment is stale: the bare-name lambda moved it to 5 (ticket 76, F46). The
self-test compares DELTAS against the tree's baseline for that reason.

**The criterion.** `bs_types:part_test/1` answers `{ok, Bif}` where one BEAM guard BIF decides a
type exactly, and `{no, Why}` otherwise. It is ticket 09 §4's criterion read at its **separating**
half: `T x` emits one test, so *deciding* is the criterion where for union legality *reaching*
is. The two come apart on `list<int> | list<binary>` — a legal union, because `[x, ..rest]`
reaches a member and `is_integer` on the binding decides it, and not a prefix, because `is_list`
is true of both.

`Why` travels with the refusal because **the sentence has to be true of the type in front of it**:
"no single test decides `list<int>`" is true, and the same sentence about `term` is false. So
`narrower` carries the over-approximating BIF by name, `several_parts` says the type spans more
than one, and `empty` is `none`.

One reader, used by both the checker's refusal and the emitter's guard, so the two cannot
disagree about which types the form reaches.

**The checker.** One clause in `pattern_type/3`: the pattern's type is the type named, exact,
binding its name. The residual subtracts the whole part, which is what closes the clause set with
no catch-all and narrows the binding for the guard and the body.

**The refusal is RAISED there, and that is the wiring.** An arm is classified in `arms/10` and a
head in `walk/6`, and both ask `pattern_type/3` for a pattern's type — so the arm is covered by
construction rather than by a second call site someone has to remember. F51 shipped a dead arm by
refusing at one of the two, and a vacuous arm is only a warning, so that program compiled with
the dead arm in it. It is also `not_a_record`'s own mechanism, one member kind away.

**The operator.** `union_result/5` beneath `op_result/5`'s existing clauses, inheriting their
operator set — everything but `and`/`or` — rather than naming a second one, and requiring both
operands inhabited for the reason they do: an operand already refused is `none`, and refusing
again stacks a second error on the first.

**`mixed_pair/1` gained the new tag**, and that line is load-bearing: `keep_from_guard/1` is what
lets a refusal out of a guard, so a tag missing from it is reported in a body and DROPPED in a
guard. `Owed(a) -> a * 100` would refuse while `Post(a) when a < 0` compiled — the defect ticket
83 named, surviving its own fix.

**The emitter.** `desugar/2` resolves the type to its BIF (where `Ctx`'s env is in scope, beside
the record tag) and `strip_rels/2` turns the pattern into a variable plus that test, the slot the
relational pattern already uses. Stripping there is what keeps `ensure_var/3`, `constrains_kind/1`,
`pins_float/1` and `skips/2` from meeting a shape they have no clause for. No kind test is
conjoined, unlike a relational pattern's: `is_float/1` **is** the kind test.

## The gate

`check-advice-compiles.sh` does what an author does. It compiles the refused program, reads the
clause heads out of the diagnostic the compiler printed, **pastes them into a program and compiles
that**. Green means the advice is a program; red means the compiler is giving instructions it will
not accept.

Its `--self-test` fabricates four advices and derives a program from each through the same code
path, so a red is a program `bsc` actually refused rather than a string the script disliked:

| stub | what it is | why it is red |
| --- | --- | --- |
| `good` | the dispatch | — (it is the green half) |
| `literal` | `mixed_operands`' own "write `100.0`" | names no head, and offers a spelling ticket 83 refuses |
| `half` | one clause, not two | the paste-back is inexhaustive |
| `plausible` | `when a is int`, C#'s and TypeScript's type test | **reads like help and does not parse** — F19's own shape |

## What it cost, stated plainly

`a < 0.0` over an `int | float` **stops compiling**. It compiled before this feature, emitted no
kind test, and answered correctly for both parts — and it is refused now, because the no-flow
rule is symmetric. Ticket 83 took that cost with its eyes open; nothing shipped paid it, since no
`int | float` operand appeared in `LANGUAGE.md`, `TOUR.md` or the corpus, and
`float_tests:int_or_float_is_discriminable_test` dispatches on literal heads, which are patterns
and never reach an operator.

## A finding this build turned up

**The open question ticket 84 left cannot currently be spelled.** A refinement is a *named* type
and type names are PascalCase, so `Meters m` is a `uident` prefix and goes down ticket 55's record
path, where only a minted tag is accepted — the part prefix is lowercase-only and reaches no named
type at all. So F53 widens nothing there by construction rather than by a refusal it had to
write, and the ticket it raises asks the sharper question the grammar now poses: may a NAME wear
the prefix, and which names. `not_a_record`'s message gained a line naming the part spelling, so
an author who writes `Amount a` is told what to write instead.

## What the review caught, and both were shipped defects

**1. A nested prefix killed the compiler.** `Go((int n, a))` reached `bs_emit:pattern/2`, which
has no clause for the lowered form, and `bsc` printed an Erlang stack trace instead of a
diagnostic. `strip_rels/2` walks the top of each argument — exactly as the `p_rel` header beside
it says of itself — and nothing refused the nested case, so the comment claiming every later pass
was safe was true only at argument top.

The refusal is F2's, one form over: whole argument or nothing. **The first fix was also wrong**,
and is worth recording: it read the PATH, as `argument_position/2` does, and a path cannot tell
the two legal tops apart from one level down — a clause-head parameter is `[I]` and so is a tuple
element of a switch SUBJECT, whose own top is `[]`. The nested form inside an arm sailed through
it and crashed exactly as before. `child_type/3` refuses structurally instead: a prefix may not be
a child, which is what "whole argument" actually means, and every composite pattern already calls
it.

**2. The advice did not compile for a function of two parameters.** The heads were built from the
function's NAME, so `public int Sum(int | float a, int b)` was advised to write `Sum(int n)`,
which pastes back as *"Sum has a signature but no clauses"*. That is F19's defect in the refusal
whose gate exists to catch it — and **the gate could not see it, because every probe it had took
one parameter**.

The heads are now built from the function's real parameter list, dispatching the position that
carries the union and keeping the author's own names for the rest: `Total(count, int amount)`.
Where no parameter carries it — the value came from a binding or a call — there is no honest head
to write, and the message says where to dispatch rather than inventing one. The gate gained a
second probe whose union is the **second** parameter, since a template that always dispatched the
first would compile and still be the wrong fix.

**The self-test had three rules nothing drove.** `A1`, `A6` and the new `A7` could not go red,
because every stub carried the word `error` and the answers they judge were hardcoded. Six stubs
now, one per rule, and the correct advice still green beside them — a gate agreeing only with
itself is the failure mode this repo has already named.

Smaller, all from the same review: the "inherited operator set" comment flattered a third copy of
the same guard, and `every_operator_but_the_boolean_pair` now asserts the exclusion it is named
for rather than only the five arithmetic operators; `part_test/1`'s header claimed a new type kind
would make the form unavailable, when `inhabited_parts/1` names the eight keys and would simply
not see a ninth, so the header now states that obligation instead of a safety it does not have;
the undecidable refusal did not actually carry `map<K, V>`'s words, and now carries both of them,
asserted; the glossary entry explained *why* the form exists, which `CLAUDE.md` reserves for the
ticket; and `not_a_record`'s new line printed a clause shape for a function whose parameters it
cannot see, so it names the form instead of a head it cannot guarantee.

## Scenarios

| id | what | assertion |
|---|---|---|
| F53.1 | ticket 83's table on the dispatched program — `Post(-250)`, `Post(-2.50)`, `Post(250)`, `Post(2.50)`, and zero in both spellings; and `f < 0.0` inside the `float` clause | `:credit`, `:credit`, `:debit`, `:debit`, `:debit`, `:debit`; no diagnostic, because the prefix narrowed the binding before the guard read it |
| F53.2 | a part dropped from the clause set | `inexhaustive`, residual `(float)` — so the exhaustiveness above is credited to the pattern and not to something else |
| F53.3 | `Norm(atom a)` / `Norm(int n)`; `Count(list<int> ns)`; `Far(Meters m)`; `Go(term t)`; `Post(Amount x)` | `0` and `7`; `{narrower, is_list}` naming `is_list` and *not built*; `not_a_record`, the form being unspellable; `several_parts`, and the message must NOT claim no test decides `term`; `not_a_record` whose message now names the part spelling |
| F53.4 | the prefix in a switch arm, accepted and refused; the prefix nested in a tuple, in a head and in an arm | `25000` and `0`; the same `{narrower, is_list}` refusal, reached without a second call site; `type_prefix_nested` at both sites, where the compiler used to die inside `bs_emit:pattern/2` |
| F53.6 | the advice for a two-parameter function whose union is the SECOND parameter; and for a union with no parameter carrying it | `Total(count, int amount)` / `Total(count, float amount)`, which paste back and run; the sentence naming where the value enters, with no head invented |
| F53.5 | `Owed(a) -> a * 100`; `Post(a) when a < 0`; `a < 0.0` over the union; the advice's text; `+ - * / %`; `int \| float \| :none`; a single `float` beside an int literal | `numeric_union_operand` in a body AND in a guard, and for the float-literal spelling too; advice naming `Owed(int`/`Owed(float` and never `0.0` or `Float.FromInt`; all five operators; unmoved, per ticket 83's scope; `mixed_operands` keeping its own `2.0` advice |

## Verified

**2026-09-19, `431a6c1`** — `./bin/verify.sh` twice from a clean clone of that commit, sequentially
(two clean runs started together race on the per-user tree-sitter cache): **45/45 stages, 261s and
257s**. The pair was run once, at the final SHA, after the tree stopped moving.

Two stages went red on the way there and both were the gates working rather than the tree being
wrong:

- **Stage 19** read *"the defect ticket 83 opened on"* in this feature's README row as a claim
  that ticket 83 is open — its probe is `[0-9]+ open`, which "83 opened" satisfies. The prose was
  reworded rather than the gate widened; a second occurrence would make it a gate defect worth
  fixing, and this is the first.
- **Stage 40** found `type_prefix_tests` citing `F53.1`–`F53.5` before this document defined them,
  which is exactly the drift that stage exists to catch: the scenarios table below was written
  from the suite afterwards, so the identifiers now mean something.
