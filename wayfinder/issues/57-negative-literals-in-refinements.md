# 57 — A refinement cannot say `-5`, though a pattern can

Type: grilling
Status: **open** — [ENG-239](https://linear.app/davewil/issue/ENG-239). Raised 2026-08-23 while
measuring [ticket 38](38-division-and-modulo.md) §2, by
[probe 38b](../prototypes/38b_divisor_expressiveness.sh).

## The repro, in two lines

```csharp
type T = int where value >= -5      // error: not a predicate the checker can read

Sign(<= -1) -> :neg                 // compiles. Same literal, same operator.
```

Measured 2026-08-23. Every refinement containing a negative integer literal is refused, whatever
the operator and whatever it is joined with:

| refinement | |
|---|---|
| `int where value >= -5` | refused |
| `int where value >= -5 and value <= 5` | refused |
| `int where value >= 1 or value <= -1` | refused |
| `int where value <= 3 or value >= 10` | **accepted** — disjointness is not the problem |
| `int where value != 0` | **accepted**, and it genuinely excludes `0` |

The diagnostic is `opaque_refinement`, whose text reads:

> a refinement narrows a type, so the compiler has to be able to reason about it: comparisons on
> `value`, joined with `and`/`or`. `int where value >= 0 and value <= 255` is one.

**The refused form is exactly what the diagnostic recommends** — a comparison on `value` — so the
message sends the reader back to write the thing it just rejected. That is the shape where a
refusal is the defect it protects against, and it is why this is a ticket rather than a footnote.

## Why it happens

Two sites read the same literal through different grammar.

A pattern has a real negative-literal rule, `bs_parser.yrl`:

```erlang
int_lit -> integer     : value('$1').
int_lit -> '-' integer : -value('$2').
```

A refinement is an ordinary expression — `refinement -> expr` — and unary minus over an expression
desugars to a subtraction:

```erlang
expr -> '-' expr : {e_op, line('$1'), '-', {e_int, line('$1'), 0}, '$2'}.
```

So `value >= -5` reaches the checker as
`{e_op,'>=',{e_var,value},{e_op,'-',{e_int,0},{e_int,5}}}`. `refine/3` asks `alternatives/1` to
read that, the right-hand side is an arithmetic node rather than a constant, and the whole
refinement is declared unreadable. `refine/3`'s comment is explicit that this must be an error and
not a silent widening — that part is right, and the bug is upstream of it, in what counts as a
constant.

## The question

**Where does the fold belong — the grammar or the checker?**

This is the decision, and the two answers are not equivalent:

- **In the grammar**, mirroring `int_lit`, so a refinement's comparand is a literal and `-5` never
  becomes a node. Smallest change, and it makes the two sites agree by construction. But a
  refinement is deliberately an `expr` so that it and a guard cannot come to disagree about what
  they mean — `bs_check.erl` says so at the `refinement` rule — and narrowing the grammar at one
  site reintroduces exactly that split.
- **In the checker**, by constant-folding a literal arithmetic node before asking whether the
  comparand is constant. Keeps one grammar and one meaning. Costs a fold, and raises the question
  of where it stops: `-5` certainly, `2 + 3` probably, `value >= n` never.

The second looks right on the stated design intent, but the first is what patterns already do, and
this ticket should not guess.

## Why it matters beyond tidiness

**The refinement is the only way to name a numeric domain**, and half of every signed domain is
unreachable. `type Delta = int where value >= -100 and value <= 100` cannot be written at all
today, so any bounded quantity that can go negative — a temperature, an offset, a balance, a
correction — has no refinement and falls back to bare `int`.

**And it silently caps the residual doctrine.** `wire.bs` is written around the claim that the
residual *is* the missing case: delete a clause and the compiler hands back the type to add. That
holds only while every residual is writable. Measured, `subtract(-10..10, 0)` is `-10..-1 | 1..10`
— a residual the compiler prints and the surface cannot accept. Ticket 38 chose an answer that
never needs to hand one back, so nothing is blocked today, but the next feature over a signed
bounded domain will meet this.

## Consequences elsewhere

- **[Ticket 38](38-division-and-modulo.md)** raised this and is **not** blocked by it — its §2
  answer refuses only a provably-zero divisor, which produces no residual.
- **[Ticket 20](20-untheorised-term-shapes.md)** owns the interval algebra, which is fine: the
  algebra represents negative bounds correctly. This is a surface defect, not an algebra one.
- **[F2](../../compiler/features/F2-interval-refinements.md)** is where the refinement landed
  (2026-08-16) and where the fix goes. Every one of F2's five scenarios is non-negative, which is
  why the gap survived a feature that was gated and green.

## Notes

Found by chasing a ticket's premise rather than its question, which is the third time that has paid
better than the answer did. The first reading was also wrong and nearly shipped: two refused probes
both happened to contain a negative literal *and* to be disjoint unions, and "the checker cannot do
a disjoint union" fits both. `int where value <= 3 or value >= 10` is the probe that separates
them, and it is accepted.

## Round 1 — 2026-11-07

Reproduced at `HEAD` `bd75ace` on **OTP 25** (the sandbox; the repo pins 28.5) with a scratch build of
`compiler/src`; probes and raw output in
[research/57-negative-literals.md](../research/57-negative-literals.md). Still open, and no later
ticket touches it (grep of `wayfinder/issues/` and `compiler/features/` for 57 / ENG-239 finds only
ticket 38). **Two things have moved since the ticket was written:**

- `-5` no longer reaches the checker as `{e_op,'-',{e_int,0},{e_int,5}}`. The parser now builds
  `{e_neg, L, E}` (`bs_parser.yrl:591`, `negate/2` at :947), and `negate/2` **already folds a
  negated float literal into a float literal** (:948). Integers are the one literal it leaves as a node.
- The defect reaches **guards**, not only refinements, and there it is silent. Both go through
  `alternatives/1` → `comparison/1` (`bs_check.erl:5136`, `5154`), which reads only `{e_int,_,K}`.

### The program

```csharp
module Sign

public atom Sign(int n)
Sign(n) when n <= -1 -> :neg
Sign(0) -> :zero
Sign(n) when n >= 1 -> :pos
```

Today it is refused, and the clause the author wrote is the one that is "missing":

```
Sign.bs:3:1: error: Sign is not exhaustive
  no clause matches:
    Sign(<= -1) -> ...
```

The same function written with patterns, `Sign(<= -1) -> :neg` and `Sign(>= 1) -> :pos`, compiles. And the
refinement the ticket opened with is still refused:

```csharp
type Delta = int where value >= -100 and value <= 100     // error: not a predicate the checker can read
```

### The question

**Is a comparand in a refinement or guard a literal with an optional sign, or any constant integer
expression?**

The ticket asked "grammar or checker?", and the float precedent answers where a sign is read: in the
parser, as a literal. Narrowing the grammar was never the cost (a refinement stays an `expr`; `negate/2`
returns a literal node, not a different production). What is left to decide is the reach, and it is
observable:

```csharp
type Band = int where value >= 2 + 3
```

### What each answer does to the program

**A literal with an optional sign.** `Sign` and `Delta` compile, and `n <= -1` in a guard is read and
credits coverage. `Band` stays refused with `opaque_refinement`.
The compiler must gain: one clause in `bs_parser.yrl`, `negate(_L, {e_int, IL, I}) -> {e_int, IL, -I};`
beside the float clause at :948. No checker change, no symbol-table entry, no new pass.
Measured with exactly that clause in a scratch parser: `Delta` and `Sign` compile, `Band` is still
refused.

**Any constant integer expression.** `Sign` and `Delta` compile, and so does `Band` (`value >= 5`).
The compiler must gain: a new `bs_check:const_int/1` folding `e_neg`, `+`, `-`, `*` over `e_int`
(and a rule for `/` and `%`: truncation, and a zero divisor, which ticket 38 refuses elsewhere),
called from both `comparison/1` clauses at :5154-5155; the guard path shares it, so a guard such as
`n >= 2 + 3` becomes readable at the same time; and a test per operator. It also needs the answer to
"where it stops" written down before it is built — a ticket's job, not a feature's.

### Recommended answer

A literal with an optional sign: patterns already say `int_lit` (`bs_parser.yrl:471-472`), the float
precedent already folds the sign in the parser, and it is one clause that leaves no fold to specify.
