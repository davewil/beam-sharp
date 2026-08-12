# 17c — Does `else` exist in Elixir or Gleam?

Asked during ticket 17's grilling (David), while deciding whether beam-sharp keeps `if`/`else`
alongside a `switch` expression. It looked like a vocabulary check. It settled the decision.

Measured locally: **Gleam 1.18.1**, **Elixir 1.19.5 (compiled with Erlang/OTP 28)**. Provenance
`local` throughout — both were run, not read.

## 1. Gleam has no `if` at all, and says so by design

```gleam
pub fn label(total: Int) -> String {
  if total > 100 { "large" } else { "small" }
}
```

```
error: Syntax error
2 │   if total > 100 { "large" } else { "small" }
  │   ^^ Gleam doesn't have if expressions

If you want to write a conditional expression you can use a `case`:

    case condition {
      True -> todo
      False -> todo
    }
```

The error is **written for this case specifically** and suggests the replacement. That is a
deliberate refusal with a designed diagnostic, not a feature that was never reached. It is the
same evidential shape ticket 03 looked for and did not find for multi-clause heads: here the
rationale is compiled into the compiler.

Since Gleam has no `if`, it has no `else` **anywhere in the language**.

## 2. Gleam's answer to the subject-less ladder is a multi-subject `case`

```gleam
pub fn ladder(admin: Bool, total: Int) -> String {
  case admin, total > 100 {
    True, True -> "priority"
    _, True -> "large"
    _, _ -> "normal"
  }
}
```

Compiles. This is the construct that replaces `if`/`else if`/`else` — and it is the same shape
as beam-sharp's clause heads, which is why the tuple-subject `switch` was adopted for ticket 17
§6 rather than a `cond`.

## 3. Gleam's non-exhaustive `case` names the missing pattern

```gleam
case total > 100 {
  True -> "large"
}
```

```
error: Inexhaustive patterns
This case expression does not have a pattern for all possible values. If it
is run on one of the values without a pattern then it will crash.

The missing patterns are:

    False
```

**Ticket 04's finding observed live in a shipping compiler**: the exhaustiveness residual *is*
the missing case, and the compiler prints it. Ticket 04 established this from CDuce, which
prints a residual type plus a sampled counter-value; this is the same behaviour in a BEAM
language with a type system, in a diagnostic a user sees today. Evidence for
[ticket 23](../issues/23-what-the-language-owes-an-agent.md), whose question is whether that
residual should be a first-class machine-readable output rather than prose.

## 4. In Elixir, `else` belongs to `if` and nothing else

```
one-armed if, false branch: nil
cond: :b
cond with else: error: unexpected option :else in "cond"
case with else: error: unexpected option :else in "case"
```

Three findings in four lines:

- A one-armed `if` returns `nil`, confirming what ticket 10 routed to ticket 17.
- `cond`'s catch-all is `true ->`. It is a **pattern-shaped clause**, not a keyword.
- Both `case` and `cond` **reject `else` outright** — it is not merely unidiomatic, it is not
  in the grammar.

`with`, `try` and `receive` have their own `else`/`after` clauses, which are about a *different*
thing (the non-matching and timeout paths), not about a binary conditional's second arm.

## Conclusion, and why it decided ticket 17 §6

**`else` is what a language needs when its conditional is binary and unnamed.** A pattern-based
construct never needs one, because its fall-through is just another pattern — `_` carries no
special status. Every pattern construct measured here spells the catch-all as a clause.

So retaining `if`/`else` in beam-sharp would not merely have added a keyword. It would have added
the **only** construct in the language whose fall-through case is not expressible as a pattern,
in a language whose entire thesis is that patterns and exhaustiveness are the mechanism. Ticket 17
§6 therefore has no `if`, no `else` and no `cond` — one branching construct, the way Go has one
looping construct (David).
