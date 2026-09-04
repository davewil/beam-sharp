# 44 — One conjunction or two? `and`/`or` against `&&`/`||`, now that patterns have taken `and`

Status: resolved 2026-08-15 — one conjunction, `and`/`or`; `&&`/`||` removed
Amends: ticket 08 (guard operators)
Raised by: ticket 42, and by David — *"For ticket 8, I think with more info, and/or would probably sit better"* (2026-08-15)
Type: `wayfinder:grilling`

## Question

[Ticket 42](42-interval-pattern-spelling.md) put relational patterns in the parameter position, and
took C#'s pattern combinators with them: `Classify(>= 4 and <= 7)`. Ticket 08 chose `&&`/`||` for
guards. So the language now spells conjunction two ways, and this ticket asks whether it should.

## The three positions, as they stand today

```csharp
type Octet = int where value >= 0 && value <= 255      // 1. refinement predicate  (&&)

Classify(>= 4 and <= 7)          -> :reserved          // 2. pattern position      (and)
Classify(n) when n >= 4 && n < 8 -> :reserved          // 3. guard position        (&&)
```

Lines 2 and 3 mean the same thing and sit one above the other.

## Why C#'s split does not obviously transfer

C# uses `and`/`or` inside patterns and `&&`/`||` in expressions, deliberately, so a pattern
combinator can never be confused with the boolean operator. That works in C# because **patterns and
expressions rarely touch**: patterns live in `switch` arms and `is` tests, and the boolean operators
live everywhere else.

**beam-sharp's defining move is putting patterns in the parameter position.** Patterns and guards
therefore sit on the *same line*, in the language's central construct, in every non-trivial
function. The condition that makes C#'s split cost nothing is exactly the condition beam-sharp
does not satisfy — which is the map's *"deviate where this language is better served"* clause with
a concrete reason attached rather than a preference.

## What was measured

The one thing that could make `and` a false friend on this platform is Erlang's own `and`, which
does **not** short-circuit where `andalso` does. Measured on OTP 28 by
[`44a_guard_operator_probe.escript`](../prototypes/44a_guard_operator_probe.escript), using
`10 div X` with `X = 0` so the second operand genuinely raises:

```
=== GUARD context, X = 0 ===
  `,` : fell_through    `and` : fell_through    `andalso` : fell_through

=== EXPRESSION context, X = 0 ===
  `and`     : {raised,error,badarith}
  `andalso` : false
```

**In guard context the distinction is unobservable.** A guard that raises simply fails, so
non-short-circuit evaluation cannot be detected — all three spellings fall through identically.
The difference is real, and it is real *in expression context only*.

This matters because beam-sharp's guards are a restricted predicate set lowered to BEAM guards. In
that position, spelling conjunction `and` is semantically exact: there is no Erlang meaning it could
be confused with, because both Erlang meanings coincide there. For an Elixir reader `and` is already
the strict-boolean short-circuiting conjunction, so it reads correctly too.

**Note this is the inverse of ticket 42's finding, and it is worth stating as such.** 42 refused
`4..7` because C# had the glyph meaning something adjacent — a false friend. Here `and` means
conjunction in C#, in Elixir, and (observably) in Erlang guards. Same test, opposite result: the
rule 42 sharpened is *"borrow the construct, or don't borrow the glyph"*, and here the construct and
the glyph agree everywhere they are visible.

## What ticket 08 owes this decision

08's guard-operator choice is **not free-standing** — its `dynamic`-in-a-guard answer rests on it:

> *"Guards use `&&`/`||` because a guard over typed values cannot fail. A guard mentioning a
> `dynamic` value can, so something must give… `as` is total… C#'s lifted comparison… `&&` never
> changes meaning; the possibility of failure is visible in the expression as a nullable."*

The lifting that makes `(d as int) > 0` yield false is on the **comparison**, not on the
conjunction, so the argument looks like it survives a rename intact. **But 08's prose leans on the
sentence "`&&` never changes meaning", and that sentence is about the specific operator.** Whoever
resolves this must re-read 08's `as` answer against the new spelling rather than assume it carries
— the map has already been bitten twice by a ticket's premises going stale between raising and
resolving.

## Blast radius, which is small but gated

`&&` is shipped, not merely decided:

- `compiler/examples/Math/math.bs` — two occurrences, and `examples/` is a **must-run** surface.
- `LANGUAGE.md` — prose *and* code blocks, and CI validates the blocks **bidirectionally**, so the
  prose and the compiler must agree or the gate fails.
- The refinement predicate in F2's own scenarios (`where value >= 0 && value <= 255`).

So this is a real migration rather than a spec edit, though a small one. It is also the cheapest it
will ever be: F2 is unbuilt, and every later feature that writes a guard makes it dearer.

**And the lexer half is already paid.** Measured in `src/bs_lexer.xrl`: `&&` and `||` are tokens
(lines 112–113) and **`and` / `or` are not reserved today** — they lex as ordinary lowercase
identifiers. Ticket 42 reserves them anyway, for the pattern combinator. So whichever way this
ticket goes, the keywords exist and the variable namespace has already lost them; **44's marginal
lexer cost is zero.** What remains is a parser rule, a migration of three call sites, and the
decision itself. That is worth knowing before weighing it, because the obvious objection to moving
guards — *"a new keyword pair for a rename"* — is not true here.

## What this ticket owes

1. One spelling or two.
2. If one: whether the refinement predicate position follows the same rule (it reads as an
   expression, not a pattern, so it could reasonably stay `&&` even if guards move).
3. Confirmation that ticket 08's `as` answer survives the rename, quoted against 08's own text.
4. Whether `&&`/`||` remain legal as synonyms or are removed — synonyms are cheap to lex and
   expensive to read, and the standing constraint says read cost carries full weight.

## Answer

**Resolved 2026-08-15. One conjunction: `and` / `or`, in every position. `&&` and `||` are
removed, not kept as synonyms.**

```csharp
type Octet = int where value >= 0 and value <= 255    // refinement predicate

Classify(>= 4 and <= 7)           -> :reserved        // pattern position
Classify(n) when n >= 4 and n < 8 -> :reserved        // guard position
```

### 1. One spelling, not two

David's call — *"For ticket 8, I think with more info, and/or would probably sit better"* — and the
information that made it safe is measured rather than argued. The one thing that could have made
`and` a false friend on this platform is Erlang's own `and`, which does not short-circuit where
`andalso` does. Measured on OTP 28 in
[`44a_guard_operator_probe.escript`](../prototypes/44a_guard_operator_probe.escript), using
`10 div X` with `X = 0` so the second operand genuinely raises:

```
GUARD context:       `,` fell_through   `and` fell_through   `andalso` fell_through
EXPRESSION context:  `and` {raised,error,badarith}   `andalso` false
```

**In guard context the distinction is unobservable** — a guard that raises simply fails, so
non-short-circuit evaluation cannot be detected. beam-sharp's guards are a restricted predicate set
lowered to BEAM guards, so this is the only context where the question arises, and there it has no
answer to get wrong.

### 2. This is ticket 42's new rule applied in the opposite direction, and that is the point

[Ticket 42](42-interval-pattern-spelling.md) minted *"borrow the construct, or don't borrow the
glyph"* while refusing `4..7`. A rule that only ever forbids is a rule nobody can apply, so its
second use being a **permission** matters more than its first being a refusal.

The test is whether the glyph's meanings diverge:

- **`..` diverged.** C#: a half-open slice specification over *indices*, not enumerable. Proposed
  use: a span of integer values. Different denotations — a reader who reads fluently reads wrong.
- **`and` does not diverge.** C#'s pattern `and` is conjunction. Elixir's `and` is conjunction.
  Erlang's `and`, in the only context beam-sharp uses it, is conjunction and observably identical to
  the alternatives. A reader who reads "both must hold" is correct in every case.

That C# spells its *expression* conjunction `&&` and its *pattern* conjunction `and` is a fact about
C#'s grammar, not about what `and` means. **The rule is about meaning, not about position** — and
this ticket is where that gets stated, because 42 alone could be misread as "only ever use a C#
symbol exactly where C# uses it", which would have forbidden this and been wrong.

### 3. And the reason to unify is beam-sharp's, not C#'s

C#'s split costs nothing there because **patterns and expressions rarely touch** — patterns live in
`switch` arms and `is` tests. beam-sharp's defining move puts patterns in the parameter position, so
a pattern and a guard sit **on the same line**, in the language's central construct, in every
non-trivial function:

```csharp
Classify(>= 4 and <= 7)           -> :reserved
Classify(n) when n >= 4 && n < 8  -> :reserved
```

Two spellings for one meaning, one line apart. The condition that makes C#'s split free is precisely
the condition this language does not satisfy — which is the map's *"deviate where this language is
better served"* clause with a mechanism attached rather than a preference.

### 4. Ticket 08's `as` answer survives — checked, not assumed

08 made `(d as int) > 0` the answer to `dynamic` in a guard, and its reasoning names the operator:

> *"`as` is total — it never raises, yielding a nothing-value on failure. And C's lifted comparison…
> `&&` never changes meaning; the possibility of failure is visible in the expression as a nullable
> rather than implied by the operand types."*

**The lifting is on the comparison, not on the conjunction.** `(d as int) > 0` yields `false` on
failure before any conjunction sees it, so the operator joining it to anything else is irrelevant to
the mechanism. The sentence *"`&&` never changes meaning"* is a claim that the conjunction needs no
special guard-failure rule — and that claim is about the *absence* of special behaviour, which
survives a rename intact. Renaming it `and` changes nothing 08 relied on.

**08's own table row is amended** rather than contradicted: `Guard operators | &&/||` becomes
`and`/`or`, and the `as` answer beneath it stands unaltered.

### 5. `&&` and `||` are removed, not kept as synonyms

The standing constraint settles this: **write cost carries little weight, read cost carries full
weight.** Synonyms are nearly free to lex and expensive to read — a reader meeting both spellings in
one codebase must ask whether the difference is meaningful, and the answer being "no" is a question
they should never have been made to ask. Two spellings for one meaning is the exact thing this
ticket exists to remove, so keeping them would resolve it in name only.

**This is the piece of the answer most worth overruling**, and it is flagged as such: it is the only
part not forced by the reasoning above, and a synonym is the cheapest possible migration.

### 6. What this does NOT do, deliberately

**No source changes here.** The map is plan-by-default and this ticket produces a decision. The
migration — `math.bs`, `LANGUAGE.md`, and F2's refinement predicates — belongs to a feature.

**And it cannot be done first, which is a real sequencing constraint.** `LANGUAGE.md` is gated
*bidirectionally*: its code blocks must compile. The compiler does not lex `and` today (measured:
`src/bs_lexer.xrl` has `&&` and `||` at lines 112–113 and no `and`/`or` rule), so editing the doc
before the lexer would turn the gate red. **Lexer first, then the doc and the example, in one
change.** F2 is the natural home, since 42 already obliges it to reserve the keywords.

### 7. What it costs, now that 42 has landed

- **Lexer**: nothing further. Ticket 42 reserves `and` / `or` for the pattern combinator regardless,
  and the variable namespace has already paid for them there. **44's marginal lexer cost is zero.**
- **Parser**: the guard grammar's `&&` / `||` productions take the new tokens; `expr` loses two.
- **Migration**: three call sites — `compiler/examples/Math/math.bs` (two occurrences),
  `LANGUAGE.md` (prose and blocks), and F2's own scenarios.
- **Removed**: two lexer rules, which is a rare direction of travel for a language decision.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- **One conjunction: `and` / `or`** — [ticket 44](issues/44-conjunction-spelling.md), resolved
  2026-08-15, amending [ticket 08](issues/08-head-and-guard-syntax.md). Raised by ticket 42, which
  put relational patterns in the parameter position and took C#'s `and`/`or` combinators with them,
  leaving the language spelling conjunction two ways. David: *"For ticket 8, I think with more info,
  and/or would probably sit better."* **One spelling now, in every position — pattern, guard and
  refinement predicate — and `&&`/`||` are removed rather than kept as synonyms.**

  **Safe because measured, not argued.** The only thing that could have made `and` a false friend
  here is Erlang's own `and`, which does not short-circuit where `andalso` does. On OTP 28
  ([`44a`](prototypes/44a_guard_operator_probe.escript)), using `10 div X` with `X = 0` so the
  second operand genuinely raises: in **guard** context `,`, `and` and `andalso` all fell through
  identically, because a guard that raises simply fails — **non-short-circuit evaluation is
  unobservable there**. In expression context the difference is real (`and` raises `badarith`,
  `andalso` returns false). beam-sharp's guards are a restricted predicate set, so the only context
  it uses is the one where the question has no answer to get wrong.

  **This is ticket 42's new rule applied in the opposite direction, and that is why the entry is
  worth reading.** 42 minted *"borrow the construct, or don't borrow the glyph"* while **refusing**
  `4..7`. A rule that only ever forbids is a rule nobody can apply, so its second use being a
  **permission** matters more than its first being a refusal. The test is whether the glyph's
  meanings diverge: `..` diverged (a half-open slice over *indices* against a span of *values* — a
  reader who reads fluently reads wrong), and `and` does not (conjunction in C#, in Elixir, and
  observably in Erlang guards). That C# spells its expression conjunction `&&` and its pattern
  conjunction `and` is a fact about C#'s grammar, not about what `and` means. **The rule is about
  meaning, not position** — recorded because 42 alone could be misread as *"only use a C# symbol
  exactly where C# uses it"*, which would have forbidden this and been wrong.

  **And the reason to unify is beam-sharp's own.** C#'s split costs nothing there because patterns
  and expressions rarely touch. This language's defining move puts patterns in the *parameter*
  position, so a pattern and a guard sit on the **same line**, in the central construct, in every
  non-trivial function. The condition that makes C#'s split free is exactly the one beam-sharp does
  not satisfy.

  **Ticket 08's `as` answer survives, and was checked rather than assumed.** 08 made
  `(d as int) > 0` the answer to `dynamic` in a guard, reasoning that *"`&&` never changes
  meaning"*. The lifting that yields false on failure is on the **comparison** — it produces `false`
  before any conjunction sees it — so 08's sentence is a claim about the *absence* of special
  conjunction behaviour, and an absence survives a rename. 08's table row is amended; the row
  beneath it stands.

  **`&&`/`||` are removed rather than aliased**, on the standing constraint: write cost carries
  little weight, read cost carries full weight, and a reader meeting both spellings must ask whether
  the difference is meaningful — a question they should never have been made to ask. **Flagged in
  the ticket as the piece most worth overruling**, being the only part not forced by the reasoning.

  **No source changed, and it could not have.** `LANGUAGE.md` is gated bidirectionally and the
  compiler does not lex `and` today (`src/bs_lexer.xrl` carries `&&`/`||` at lines 112–113 and no
  `and`/`or` rule), so editing the doc before the lexer turns the gate red. Lexer first, then doc and
  example, in one change — F2's job, since 42 already obliges it to reserve the keywords. **44's own
  marginal lexer cost is therefore zero**, and it *removes* two rules, which is a rare direction of
  travel for a language decision.
```
