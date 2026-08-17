# 38 — Division and modulo: which of the three answers, and what happens at zero?

Type: grilling
Status: **open** — raised 2026-08-15 from running
[AoC 2019 Day 1](../../aoc/2019/Day01/day01.bs)

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
| **JavaScript** (node) | `-3` | `-1` | `Infinity`, and `0/0` is `NaN` |
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

## §2. Divide by zero — the half that is genuinely open

Here the sources **diverge**, and one of them is unrepresentable:

- **C# throws**, **Erlang raises `badarith`** — agree on "it is a crash".
- **JavaScript yields `Infinity` / `NaN`** — and beam-sharp has no `float`, so this is not
  available even if it were wanted.

So the real choice is between two answers, and the second is novel:

**(a) It is a crash.** Consistent with ticket 12's let-it-crash stance and with both agreeing
sources. Costs nothing and decides nothing else.

**(b) It is a proof obligation.** `a / b` requires `b` to exclude `0`, checked. **The machinery
already exists**: ticket 20 put real integer intervals in the algebra, `subtract(int, range(0,0))`
is `int <= -1 | int >= 1`, and `to_pattern/1` already prints residuals in exactly that shape — the
checker emitted `int <= 1 | int >= 3` in an unrelated diagnostic the same day.

**(b) would make `/` the first operator in the language carrying a precondition**, which is the
reason it is a decision and not a detail. Every other operator is total over its declared operand
types. It also has a cost the ticket must price: `Fuel(m) -> :erlang.div(m, 3) - 2` divides by a
*literal* 3 and would be fine, but `a / b` over two parameters would demand the caller narrow `b`,
and nothing in the surface yet says `int` **without** zero except a guard.

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
  its `type Positive = int where value > 0` spelling is what would let a caller declare a non-zero
  divisor without a guard. §2(b) is close to unbuildable until that lands.
- **[Ticket 12](12-totality-vs-let-it-crash.md)** owns the crash stance §2(a) leans on.
- **[F2](../../compiler/features/F2-interval-refinements.md)** is the feature that would carry
  either answer, and is already blocked on two spellings.

## Notes

Raised from a feature run rather than from the map, like ticket 33 (from F3) and ticket 37 (from
F6). Those two established that a ticket raised this way is a **timestamped claim about the
compiler**, so re-measure §1's table and the `erlc` warning before resolving — both were taken on
2026-08-15 against OTP 28 / erts-16.4, node, dotnet net9.0 and Python 3.
