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
