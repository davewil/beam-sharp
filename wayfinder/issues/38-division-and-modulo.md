# 38 — Division and modulo: which of the three answers, and what happens at zero?

Type: grilling
Status: **resolved 2026-08-23** — [ENG-210](https://linear.app/davewil/issue/ENG-210).
See [Answer](#answer) at the end. Raised 2026-08-15 from running
[AoC 2019 Day 1](../../aoc/2019/Day01/day01.bs).

Two of this ticket's own premises were false when re-measured. **They are corrected in place
below**, each marked `CORRECTED 2026-08-23` at the sentence that was wrong, rather than left
standing under a banner — a stale claim that survives in the body is what a clean-room reader
takes as spec. The Answer's *Premises measured* table is the summary.

## Question

**The language has no division.** The operator table is `+ - *`, there is no `/` in the lexer at
all, and there is no `%`, `div` or `rem` either.

**It is absent by oversight, not by decision.** Measured 2026-08-15: `LANGUAGE.md`, every ticket
and every fog patch mention division **zero** times. `+ - *` were what the walking skeleton needed
and nobody ever asked the question.

It surfaced the first time an **outside** workload was run. AoC 2019 Day 1 is
`floor(mass / 3) - 2`, so the most ordinary arithmetic in the puzzle crossed the FFI on line one:

```csharp
using :erlang {
    int div(int a, int b)
}

Fuel(m) -> :erlang.div(m, 3) - 2
```

That works — ticket 32 makes a foreign declaration a signature attached to a name Erlang already
has — and it is the wrong place for integer division to live.

**Provenance is why this is worth a ticket rather than a shrug.** No exemplar divides; the
exemplars were written to answer ticket questions. A puzzle written by someone with no stake in
this language demanded it immediately, which is a different and better class of evidence — the
lesson the same session learned the hard way when a self-invented check was presented as
validation.

## §1. Truncated, floored, or Euclidean — and this half is easy

The classic divergence, **measured locally 2026-08-15** rather than cited:

| | `-7 / 2` | `-7 % 2` | `7 / 0` |
|---|---|---|---|
| **C#** (net9.0) | `-3` | `-1` | `DivideByZeroException` |
| **JavaScript** (`BigInt`) | `-3n` | `-1n` | `RangeError` <!-- corrected 2026-08-23; the row here was `Number`, i.e. FLOAT division --> |
| **Erlang** (`div` / `rem`) | `-3` | `-1` | `badarith` |
| Python 3, for contrast | `-4` | **`1`** | — |

**All three of this language's sources agree**: truncate toward zero, and the remainder takes the
sign of the dividend. Python is the outlier and is not an audience.

That is the strongest position the borrow heuristic can produce — the tiers do not have to be
ranked because they converge. So §1 should be settled by writing it down: **truncated division,
remainder signed by the dividend**, which is C#'s meaning, TypeScript's meaning, and exactly
Erlang's `div`/`rem`.

**One consequence to state in the spec rather than discover.** beam-sharp's `/` would then *not*
mean Erlang's `/`, which is always float division (`-7 / 2` is `-3.5`, measured). It means Erlang's
`div`. An Erlang reader will expect the other thing.

## §2. Divide by zero — the half that looked open

**CORRECTED 2026-08-23 — the sources do not diverge here.** This section was written on the
premise that JavaScript dissents, and it does not:

- **C# throws**, **Erlang raises `badarith`** — agree on "it is a crash".
- **JavaScript** yields `Infinity` only for `/` on a `Number`, which is *float* division. The
  comparable integer operation is `BigInt`, and `7n / 0n` **throws `RangeError`**. Measured.

So all three agree that integer division by zero is a crash, and the choice below is between a
crash and a stricter-than-any-source static check rather than between three traditions:

**(a) It is a crash.** Consistent with ticket 12's let-it-crash stance and with both agreeing
sources. Costs nothing and decides nothing else.

**(b) It is a proof obligation.** `a / b` requires `b` to exclude `0`, checked. **The machinery
already exists**: ticket 20 put real integer intervals in the algebra, `subtract(int, range(0,0))`
is `int <= -1 | int >= 1`, and `to_pattern/1` already prints residuals in exactly that shape — the
checker emitted `int <= 1 | int >= 3` in an unrelated diagnostic the same day.

**(b) would make `/` the first operator in the language carrying a precondition**, which is the
reason it is a decision and not a detail. Every other operator is total over its declared operand
types. It also has a cost the ticket must price: `Fuel(m) -> :erlang.div(m, 3) - 2` divides by a
*literal* 3 and would be fine, but `a / b` over two parameters would demand the caller narrow `b`.
**CORRECTED 2026-08-23**: this sentence ended *"and nothing in the surface yet says `int` without
zero except a guard"*. False — `type Nz = int where value != 0` compiles and genuinely excludes
zero. The cost to the caller is real; the claim that it was unsayable was not.

**One datum that argues (b) is not exotic**: `erlc` already refuses the constant case at compile
time — measured, `7 div 0` produces *"Warning: evaluation of operator 'div'/2 will fail with a
'badarith' exception"*. Erlang catches the literal; beam-sharp's intervals could catch strictly
more, which is the whole shape of this project's bet.

## §3. Spelling

`/` and `%` are C#'s and TypeScript's; `div` and `rem` are Erlang's. Two of three for the symbols,
and `%` is not currently a token. Note `%` is also not free in every BEAM context — it begins a
comment in Erlang source — but beam-sharp emits *terms*, never Erlang text, so that costs nothing
here.

**And `rem` versus `mod` is not a spelling question.** Under truncation the operation is a
*remainder*, not a modulus; they differ exactly on negative operands, which is §1's table. Whichever
symbol is chosen, the name in prose should be the one that is true.

## §4. What `float` does to this later

`float` is **open** (`LANGUAGE.md` §4 marks it so, and it has no decided literal syntax). If it
ever lands, C#'s `/` is operand-dependent — integer division on two ints, float division otherwise
— and this ticket's answer must not make that impossible. Deciding §1 as *"`/` on two `int`s is
truncated integer division"* leaves that door open; deciding it as *"`/` always truncates"* does
not.

## Consequences elsewhere

- **[Ticket 20](20-untheorised-term-shapes.md)** owns the interval algebra §2(b) would use, and
  its refinement spelling is what lets a caller declare a non-zero divisor without a guard.
  **CORRECTED 2026-08-23**: this bullet said §2(b) was "close to unbuildable until that lands".
  It landed on 2026-08-16, and `int where value != 0` compiles today.
- **[Ticket 12](12-totality-vs-let-it-crash.md)** owns the crash stance §2(a) leans on.
- **[F2](../../compiler/features/F2-interval-refinements.md)** is the feature that would carry
  either answer. **CORRECTED 2026-08-23**: this bullet said F2 was "already blocked on two
  spellings". F2 is **done (2026-08-16)** and blocks nothing here.

## Notes

Raised from a feature run rather than from the map, like ticket 33 (from F3) and ticket 37 (from
F6). Those two established that a ticket raised this way is a **timestamped claim about the
compiler**, so re-measure §1's table and the `erlc` warning before resolving — both were taken on
2026-08-15 against OTP 28 / erts-16.4, node, dotnet net9.0 and Python 3.

---

## Answer

**Resolved 2026-08-23.** Re-measured first, as the Notes demanded, by
[probe 38a](../prototypes/38a_division_survey.sh) (the four-language survey) and
[probe 38b](../prototypes/38b_divisor_expressiveness.sh) (seven cases against the real `bsc`).
Both are scripts, so the next reader re-runs them rather than trusting this paste.

### §1 — truncated, and the phrasing is load-bearing

**`/` on two `int`s is truncated integer division, and `%` is the remainder it leaves, taking the
sign of the dividend.** `-7 / 2` is `-3` and `-7 % 2` is `-1`.

Written that way on purpose. §4 asked that this not close the door on `float`: C#'s `/` is
operand-dependent, so *"`/` on two `int`s truncates"* leaves a future `float / float` free, where
*"`/` always truncates"* would not. The rule is about the operand types, not about the operator.

All three sources converge, re-measured 2026-08-23 against OTP 28 / erts-16.4, node v22.22.3 and
dotnet 9.0.306, so the borrow heuristic never had to rank them. Python's floored `-4` and `1` is
the outlier and is not an audience.

### §2 — `/` does NOT carry a precondition

**A divisor needs no proof that it is non-zero. The compiler refuses only a divisor it can prove
*is* zero.**

```csharp
Mean(total, count) -> total / count      // compiles. count may be anything.
Bad(n)             -> n / 0              // refused at compile time.
```

So `/` stays total over its declared operand types like every other operator, a divisor that
*might* be zero crashes at run time with `badarith` exactly as [ticket 12](12-totality-vs-let-it-crash.md)
says it should, and the one thing the compiler can prove wrong, it refuses.

**This is the smaller half of what §2 framed, and it is chosen over the larger half.** §2(b) as
written — every divisor's type must exclude zero — would have made `/` the first operator carrying
a precondition, and §2 was right that this is the decision rather than a detail. It is refused on
cost to the caller: `Mean(total, count)` is ordinary code, and demanding the caller narrow `count`
taxes every division in the language to buy a guarantee at one of them.

**What it costs is nothing, and what it buys is more than either source catches.** The check is
`is_subtype(DivisorType, range(0,0))` over a type the checker already computes — no new pass, no
new surface, no residual to hand back. And measured 2026-08-23, it strictly dominates both agreeing
sources:

| | catches `7 / 0` | catches `X / 0` |
|---|---|---|
| `erlc` | warning | **no** — silent |
| `csc` | error CS0020 | n/a (C# has no such shape) |
| this decision | error | **error** |

`erlc` constant-folds only when *both* operands are literals, so `variable(X) -> X div 0` compiles
clean today. An interval that is exactly `0..0` catches it whatever the dividend is.

### §2's own framing was wrong in two places, and one of them mattered

**The sources do not split on divide-by-zero.** §2 said C# and Erlang crash while "JavaScript
yields `Infinity`", making JS the dissenter. But `-7 / 2` in JS is `-3.5` — `/` on a `Number` is
*float* division, and the ticket had already ruled float out as unrepresentable. The comparable
operation in JavaScript is **BigInt**, whose only numeric behaviour is integral: `-7n / 2n` is
`-3n`, `-7n % 2n` is `-1n`, and **`7n / 0n` throws `RangeError: Division by zero`**. Measured.
Read against the operation beam-sharp actually has, all three sources agree twice over — truncate,
and crash at zero — and §2's "genuinely open" half was less open than it looked.

**And C# does not merely throw.** `7 / 0` with a literal divisor is a *compile error*, CS0020, not a
`DivideByZeroException` that waits for run time. The ticket recorded only the exception. So a
compiler refusing a provable divide-by-zero is not novel at all — it is what C# already does, and
this decision is that behaviour with a better analysis behind it.

### §3 — `/` and `%`, and the word is *remainder*

Two of three sources spell them as symbols; only Erlang uses words, and beam-sharp emits terms
rather than Erlang text, so `%` costs nothing here even though it opens a comment in Erlang source.

**`%` is a remainder, not a modulus**, and the prose must say so. They differ exactly on negative
operands, which is §1's table — Python's `-7 % 2 = 1` is a modulus and this language's `-1` is not.
Naming it `mod` anywhere in the spec would describe an operation the compiler does not implement.

### Premises measured, and two were false

The Notes ask for re-measurement because a ticket raised from a feature run is a timestamped claim
about the compiler. Three of five held; two did not.

| Premise, as written 2026-08-15 | 2026-08-23 |
|---|---|
| No `/`, `%`, `div` or `rem` in the lexer | **holds** — the operator table is still `+ - *` |
| Division appears zero times in `LANGUAGE.md` | **holds** — still zero |
| §1's truncation table | **holds** — re-measured, all four languages unchanged |
| *"nothing in the surface yet says `int` **without** zero except a guard"* | **false** |
| *"§2(b) is close to unbuildable until [ticket 20's spelling] lands"* | **stale** |

The last two were written on 2026-08-15. [F2](../../compiler/features/F2-interval-refinements.md)
landed on 2026-08-16 — the day after — and `type Nz = int where value != 0` compiles today. It is
not a no-op either: `Id(0)` against a parameter of that type is refused at the call site, measured.
So the surface the ticket said was missing had been there for a week.

This does not change the answer, but it changes what the answer is *choosing between*. §2(b) was
not refused for being unbuildable. It was buildable, and is refused on its cost to the caller.

### One finding chased past the ticket

Measuring §2(b) turned up a defect that is not about division at all, and it is
**[ticket 57](57-negative-literals-in-refinements.md)**: a negative integer literal cannot be
written in a refinement. `int where value >= -5` is refused as *"not a predicate the checker can
read"* — while `Sign(<= -1)` as a relational **pattern** reads the same literal fine. Patterns have
`int_lit -> '-' integer`; a refinement is an ordinary `expr`, where `-5` desugars to
`{e_op,'-',{e_int,0},{e_int,5}}`, a subtraction node the refinement translator cannot fold.

It is worth recording here because it is precisely what would have blocked §2(b). For a bounded
divisor the residual is `-10..-1 | 1..10` (measured), and the compiler would have handed back a
clause the language cannot spell — in the one place this project's doctrine, *the residual IS the
missing case*, is load-bearing. The answer chosen needs no residual, so 57 does not block it.

### What must be built

Not now — this is a decision, and nothing here is sanctioned for execution yet. When it is:

1. `/` and `%` as lexer tokens at `*`'s precedence level. **Measure the yecc conflict count on the
   before and after grammar rather than trusting a quiet build**, and check `%` actually lexes:
   `%` opens a comment in leex's *own* source, so that rule may need a character class where `*`
   did not.
2. `op_type/1` in the checker: both are `int × int -> int`.
3. The one refusal — `is_subtype(Divisor, range(0,0))` — as a named diagnostic, so it joins the
   corpus rather than crashing.
4. `erl_op/1` in the emitter maps `/` to **`div`** and `%` to `rem`. Not to Erlang's `/`, which is
   float division and would silently change `-7 / 2` from `-3` to `-3.5`.
5. A gate that goes red before it goes green, with a self-test that builds the defect it names —
   both halves, per the working rules.

### Consequences

- **[Ticket 12](12-totality-vs-let-it-crash.md)** — unchanged and relied upon. A possibly-zero
  divisor crashes, and that is the stance, not a gap.
- **[Ticket 20](20-untheorised-term-shapes.md)** — its intervals are what make the refusal exact,
  but nothing new is asked of them.
- **[F2](../../compiler/features/F2-interval-refinements.md)** — no longer blocking anything here;
  it is what falsified two of this ticket's premises.
- **[Ticket 57](57-negative-literals-in-refinements.md)** — raised by this one. Does not block it.
- **AoC 2019 Day 1** can drop its `using :erlang { int div(int a, int b) }` once `/` is built, which
  is the whole reason the ticket exists.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Division and modulo](issues/38-division-and-modulo.md) — **`/` on two `int`s is truncated
  integer division and `%` is the remainder it leaves, signed by the dividend** (`-7 / 2` is `-3`,
  `-7 % 2` is `-1`). Phrased over the operand types on purpose, so a later `float / float` stays
  open. **`/` carries no precondition**: a divisor needs no proof it is non-zero, and only a
  divisor the compiler proves *is* zero is refused — `Mean(total, count) -> total / count` compiles,
  `Bad(n) -> n / 0` does not. A possibly-zero divisor crashes at run time, which is ticket 12's
  stance and not a gap. §2(b) — every divisor's type must exclude zero — was refused on cost to the
  caller, not on feasibility. The check is `is_subtype(Divisor, range(0,0))` over a type the
  checker already computes, and it strictly beats both agreeing sources: `erlc` constant-folds only
  when *both* operands are literals, so `variable(X) -> X div 0` warns nowhere today.
  **Two of the ticket's own premises were false on re-measurement.** The sources do not split on
  divide-by-zero: JavaScript's `Infinity` is *float* division, and the comparable integer operation
  is BigInt, which truncates and throws `RangeError` — so all three agree twice over. And C# does
  not merely throw at run time; `7 / 0` is compile error CS0020, so a compiler refusing a provable
  divide-by-zero is not novel. Also stale: *"nothing in the surface says `int` without zero except
  a guard"* — F2 landed the day after the ticket was raised, and `int where value != 0` compiles.
  Emission maps `/` to Erlang's **`div`**, never its `/`, which is float division. Raised by an
  outside workload (AoC 2019 Day 1), which is the better class of evidence.
```
