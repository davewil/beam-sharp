# 15 — Error model

Type: grilling
Status: open
Blocked by: 06, 14

## Question

How are errors represented and propagated?

Weigh: C#-style **exceptions** with `try`/`catch`; **tagged-tuple or `Result` values** as in
Elixir and Gleam; the BEAM's own **`throw`/`error`/`exit`** trio; or a defined combination.

Decide, and state:

- Whether error types appear in a function's return type, and what that does to the
  ergonomics of the multi-clause head — an `Ok`/`Error` union is exactly the shape clauses
  dispatch on, which may be an argument for values over exceptions.
- How this interacts with the totality stance from ticket 12 and with supervision. If
  let-it-crash is the primary error strategy, an elaborate error-value discipline may be
  the wrong instinct imported from a platform without supervisors.
- What happens with **Erlang callers and callees that will throw and exit regardless** —
  the language cannot opt out of the platform's three exception classes, only decide how it
  presents them.
- Whether `try`/`catch` exists at all, and if so what it may catch.

## Notes

HITL. Blocked by ticket 14 because the answer differs sharply depending on whether the
language leans on supervision or on in-process error handling.

## Constraints from ticket 11 — resolved 2026-08-12

**The language now has its first error-*shaped* commitment, and this ticket owns whether it
generalises.** `ValidateAs<T>` — the generated deep validator for a value arriving as a `term` —
returns **`T | :error`**. So the one boundary construct decided so far **fails as a value, not a
crash**, and it does so with a bare atom rather than a structured error.

Three things to settle here that follow directly:

- **Does `:error` carry a payload?** A bare `:error` says validation failed and nothing about
  *where* — which under the standing constraint is a diagnostics problem, since the consumer is an
  agent in a loop (→ [ticket 23](23-what-the-language-owes-an-agent.md)). Gleam's decoders return
  `Result(t, List(DecodeError))` with a path into the term; ticket 11 did not decide whether
  beam-sharp owes the same.
- **Does the `T | :error` shape generalise to every fallible operation**, or is it specific to
  boundary validation? Ticket 10 already put `type option<T> = T | :nothing;` in the prelude, so
  there are now **two** failure spellings in play — `:nothing` and `:error` — and no rule saying
  which is used when.
- **How does this sit against ticket 12?** That ticket owns totality versus let-it-crash;
  `ValidateAs<T>` has effectively voted "value, not crash" for one case. Whether that is precedent
  or exception is a joint question.

Note there is **no `dynamic`** and no exception-like escape: a `term` is narrowed by a clause head
or by `ValidateAs<T>`, so every boundary failure is reachable as ordinary control flow.
