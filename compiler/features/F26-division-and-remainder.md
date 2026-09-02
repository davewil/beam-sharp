# F26 — `/` and `%`, and the one divisor the compiler refuses

**Status**      **done 2026-08-25** — 519 tests, and a new gate,
                `check-division.sh`. `LANGUAGE.md`'s Fuel block loses its
                `not-yet` fence, so the language gate goes 40 ok → 41 ok
**Implements**  [ticket 38](../../wayfinder/issues/38-division-and-modulo.md), decided
                2026-08-19 and unbuilt since. It **decides nothing**
**Unblocks**    the AoC 2019 Day 1 workload that raised 38 in the first place —
                `Fuel(mass) -> mass / 3 - 2` is the block in `LANGUAGE.md` §
                *Division and remainder*, and it could not compile until now
**Depends on**  F2 (`int_lit`, and the refinement that lets `int where value != 0`
                stand as a divisor), F7 (`switch`, only because the test suite
                narrows with it)

## Why this one now

David, reviewing the complete terminal alphabet: *"I thought we tackled div mod
`/` `%` previously, or is that a ticket in the future."* He was right and the
survey that prompted the question was wrong — it had recorded the absence of `/`
as *"a gap rather than a decision"*, **asserted without searching**. Ticket 38
settled the semantics six days earlier. What was missing was only the
implementation, which makes this the cheapest kind of feature: no decision to
take, four touch points, and a spec sentence already written.

## What ships

| | |
|---|---|
| `bs_lexer.xrl` | two token rules, `/` and `\%` |
| `bs_parser.yrl` | two terminals, `Left 500 '*' '/' '%'`, two `expr` productions |
| `bs_check.erl` | `op_type/1` gains both; `divisor_diags/4` is new |
| `bs_emit.erl` | `erl_op('/') -> 'div'`, `erl_op('%') -> 'rem'` |
| `bs_diag.erl` | a `descriptor/2` and a `message/1` clause for `divide_by_zero` |

## Measured before this file was written, not assumed

**Erlang's semantics are ticket 38's semantics, checked rather than recalled.**
On OTP 28: `-7 div 2` is `-3`, `-7 rem 2` is `-1`, and `-7 / 2` is `-3.5`. So
38's *"`/` maps to `div`, never Erlang's `/`"* is not a stylistic preference —
Erlang's `/` returns a **float** where the signature promised `int`, and the
type checker cannot see it because the emitter runs after it.

**That is why the tests assert values and not the emitted forms.** A test that
reads the beam looking for `div` can be satisfied by a beam that also contains
`/` somewhere else. A test that asserts `-7 / 2` is the integer `-3` cannot pass
at all if the wrong operator shipped, because the answer would be `-3.5`. The
value assertion *is* the emission assertion, and it needs no disassembly.

**Yecc conflicts, measured on the before and after grammar**, per the repo's
rule that a quiet build is not evidence: `warnings=0` on both. Adding `/` and
`%` at `*`'s precedence introduces nothing.

**`int` is a bignum, and now something proves it.** Raised by David mid-build:
*"on the BEAM an int is arbitrarily long, not int32, not int64, more like
BigNumber."* The type model already agreed — `bs_types:int()` is
`[{neg_inf, pos_inf}]`, unbounded at both ends, with no machine width anywhere
in the interval representation — and Erlang's `div`/`rem` are exact on bignums.
But **nothing tested it**: every other case in the suite fits in a machine word,
so a future change that clamped `int` to 64 bits would have left the suite
green. Two tests now use 2^100, one passing it in and one writing it as a
literal so the lexer and the emitted form are exercised too.

## Three things that went red before they went green

**`%` is a comment character in leex.** A bare `%` rule is read as the start of
a comment, so the rule vanishes and the token is *silently never produced* —
the build stays clean and every `%` in source becomes a syntax error somewhere
else. It is escaped as `\%`, and the reason is written next to it.

**The gate's first probe layout violated F15.** It put `module G` in a directory
called `src`, and B# makes a module's declaration and its path the same name
written twice, so every probe returned the path diagnostic instead of a
quotient. The gate reported it as four failures rather than passing — which is
the harness working, and is the reason each module now gets a directory of its
own name.

**The gate first matched on the internal tag.** It grepped the CLI output for
`divide_by_zero` and went red against a compiler that was refusing the program
correctly, because what the CLI prints is the *message*. It now matches the
user-visible text, which is the better boundary anyway: the eunit suite already
asserts the tag.

## The rule that needed a third probe

Ticket 38's precondition rule fails in **two** directions, and a gate that
checked one would pass a compiler that got the other wrong:

- **not firing** — `n / 0` compiles and crashes at run time;
- **firing too widely** — the check refuses `n / 2`, or every literal divisor.

So `check-division.sh` has four probes, and its `--self-test` builds three
defects: the float emission, the missing check, and a **cry-wolf** stub that
satisfies the zero probe and refuses a good program. All three go red, and the
correct form goes green — both halves, because a check that fires on everything
passes the red half and is worthless.

The subtype test is 38's own — `is_subtype(Divisor, range(0,0))` — and it is
deliberately a subtype test rather than an equality one against the literal. It
catches `n / 0`, and it also catches a divisor narrowed to nothing but zero by a
refinement or a clause head, which an equality test would miss. It cannot fire
on `int`, which is what keeps `Mean(total, count) -> total / count` compiling.

## The scenarios

`division_tests.erl` opens its sections with these identifiers, and this is what each one
establishes. The lettered `F26.1b` is a sub-part of `F26.1` rather than a fourth scenario:
it asserts the same two operators over a value no machine word holds.

| | | |
|---|---|---|
| F26.1 | `Slash(-7, 2)`, `Pct(-7, 2)`, and the identity over a spread of signs | `-3` and `-1` — `/` truncates **toward zero** and `%` is signed by the **dividend**, so `q * b + r` reconstructs `a` |
| F26.1b | 2^100 divided by 7, passed in **and** written as a literal in B# source | exact — `int` is a bignum at both ends, and the front end carries a 101-bit literal through |
| F26.2 | `total / count`; then `n / 0`, `n % 0`, `n / 2`, and `n / d` where `d` is `int where value != 0` | the possibly-zero divisor **compiles** (ticket 38: `/` carries no precondition); only the *provably* zero one is refused, at both operators, and neither control is touched |

**Why `F26.1b` exists at all**, since it asserts something that was already true: every other
case in the file fits in a machine word, so a change that clamped `int` to 64 bits or emitted a
fixed-width operator would leave the whole suite green. It is a scenario about what the *other*
scenarios cannot see.

**Why the last two rows of `F26.2` are controls and not cases.** A rule that refused every
literal divisor satisfies `n / 0` and `n % 0` and is still wrong; a rule keyed on literals alone
misses that a refinement excluding zero is a different way of saying the same thing. Both are
listed here because a reader counting assertions would otherwise read four tests as one claim.

## What this does not do

- **No `float / float`.** 38 phrased the rule over the operand types precisely
  so that stays open, and B# has no float type to open it with.
- **No exact interval arithmetic.** `7 / 2` is `int`, not `range(3,3)`, for the
  same reason `1 + 2` is — that is F2's business.
- **No `div`/`rem` spelling.** One spelling per operation, which is ticket 44's
  rule for `and`/`or` applied in the same direction.
