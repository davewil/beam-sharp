# 44 — One conjunction or two? `and`/`or` against `&&`/`||`, now that patterns have taken `and`

Status: open
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

- `compiler/examples/math.bs` — two occurrences, and `examples/` is a **must-run** surface.
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

<!-- recorded on resolution -->
