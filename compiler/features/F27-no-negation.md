# F27 — There is no `not`, and the absence teaches

**Status**      **done 2026-08-26** — 7 new tests, and a new gate,
                `check-negation.sh`. `LANGUAGE.md` gains a *There is no `not`*
                paragraph, prose rather than a `not-yet` block: `not-yet` means
                *decided and unbuilt*, and this form is decided and **refused**,
                which is not the same category
**Implements**  [ticket 63](../../wayfinder/issues/63-negation-has-no-spelling.md),
                resolved 2026-08-26. It **decides nothing** — David answered the
                round, and the obligation to teach came with the answer
**Unblocks**    nothing. This is the rare feature that ships a *refusal*, so no
                exemplar starts compiling because of it
**Depends on**  F16 (the diagnostic is a term and prose is a pure function of
                it — without it this would have been an `io:format` at the parse
                site and invisible to every gate)

## Why this one now

Ticket 63 was measured on 2026-08-25/26 and put a round of four questions to
David. He answered on 2026-08-26, and the answer to Q1 was not simply *"refuse"*
— it was **refuse, and name the complement to use**. That second half is a
compiler change, so the decision does not land by editing a document.

The estimate quoted to David alongside the option was *"compiler delta: none,
plus one diagnostic descriptor"*. That was optimistic and is corrected here:
detecting `not` needs a rule, because unlike `;` it lexes perfectly well.

## What ships

| | |
|---|---|
| `bs_diag.erl` | two `descriptor/2` clauses (one lexer-site, one parse-site), one `message/1` clause, and `not_in_prefix_position/2` |
| `bsc.erl` | `parse_string/2` passes the **tokens** alongside the parse error |
| `bin/check-negation.sh` | five probes, four self-test defects |
| `test/negation_tests.erl` | seven tests, none of which drive a subprocess |
| `LANGUAGE.md` | *There is no `not`, and no `!`* |

## Measured before this file was written, not assumed

**`not` is a legal identifier today, and that is what stops this being a
one-line lexer rule.** `F(not) when not > 100 -> :big` compiles and runs on
master. Adding `not : {token, {'not', TokenLine}}.` beside `and` and `or` would
have produced a sharp message in one line and **silently taken a name out of the
language**. Reserving names is [ticket 65](../../wayfinder/issues/65-reserved-names-policy.md),
which is open, and a feature that needs a decision raises a ticket rather than
making one. So the hint is raised at the **parse failure** instead, where it
cannot reach a program that parses, and `not` stays an identifier until 65 says
otherwise. `check-negation.sh` P4 is the probe that goes red if a later session
reaches for the keyword.

**The two positions the decision covers fail at different tokens.** This is the
finding that shaped the rule, and a plausible implementation misses it:

    when not (n > 100)             syntax error before: '('
    int where not (value > 100)    syntax error before: '>'

A hint keyed on *the token yecc reported* passes the guard case and misses the
refinement case completely. Ticket 63's own §4 argues that a guard and a
refinement cannot come to disagree because they share one `alternatives/1` — but
that is the **checker**, and this lives in the **parser**, which they do not
share. So the rule is a *shape* in the token stream — `not` immediately followed
by something it would have to apply to — and the refinement position is
asserted separately rather than inherited. The self-test's `half` stub builds
exactly this defect.

**Why the shape cannot mis-fire on a valid program**, which is the argument that
makes a parse-site hint safe at all. It runs only after the parse has already
failed; and the shape it looks for cannot occur in a program that parses,
because applying a variable needs an arrow and **F6 measured that `ty()` has no
arrow part and the surface language has no lambda**. A bare `not` used as a
variable is followed by an operator, a comma or a bracket, never by an operand,
so it is untouched. **If lambdas ever arrive, `not (` becomes parseable** and
this rule wants revisiting — recorded in `bs_diag.erl` beside the code and in
63's re-open trigger.

**`!` fails one stage earlier, in the lexer.** `!n` is `illegal characters "!n"`,
never reaching the parser, so it needs its own descriptor clause beside
`stray_semicolon` — which is the exact precedent, and whose comment already
states the principle: *"both audiences type one from habit, so it gets the
sharpest message rather than leex's raw tuple."* `!=` is a token of its own and
never arrives as an illegal character; the suite asserts that rather than
assuming it.

## The one that went red before it went green

**The gate's own control was a false green, in the way this repo has recorded
three times.** P4 exists to prove `not` still works as an identifier, and its
first fixture declared `public :atom Go(int not)` — which does not cover `:big`,
so the module never compiled and P4 held a *return-type diagnostic*. That
diagnostic's text contains `:small`, and the judge was matching a **substring**,
so it went green against a program that had not compiled at all. Caught by
writing the eunit test for the same fact, where the failure was loud.

Two changes came out of it, and the second is the general one: the fixture
declares a real return type, and **the judge now matches P4 exactly rather than
by substring**. An absence asserted against a run that never happened is this
repo's oldest recurring defect, and it reappeared *inside the gate written to
prevent it*.

## Scenarios

| id | input | command | expected | exit |
|---|---|---|---|---|
| F27.1 | `Go(n) when not (n > 100) -> :small` | `bsc G/G.bs Go 5` | `beam-sharp has no \`not\`` + the complement list | 1 |
| F27.2 | `type S = int where not (value > 100)` | `bsc R/R.bs Go 5` | same message, at the refinement's line | 1 |
| F27.3 | `Go(n) when !n -> :small` | `bsc B/B.bs Go 5` | `beam-sharp has no \`!\`` + the same complement list | 1 |
| F27.4 | `Go(int not)`, `Go(not) when not > 100` | `bsc K/K.bs Go 5` | exactly `:small` — it compiles and runs | 0 |
| F27.5 | `Go(n) when n > -> :small` | `bsc U/U.bs Go 5` | the ordinary `syntax error`, **not** the negation message | 1 |

F27.4 and F27.5 are the two absences. F27.4 asserts it against a **clean
compile** and F27.5 against an **unrelated syntax error**, because a hint that
fired on every parse failure would satisfy F27.1–F27.3 and be worthless.
