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

## Constraints from ticket 12 — resolved 2026-08-12

Ticket 12 settled the *mechanism* for failing-by-crashing and left this ticket everything about
the *shape* of failure.

**Decided there, binding here:**

- **`raise` is the spelling** for a deliberate crash — a tier-2 borrow from Elixir, verified to
  produce the **error** class (`{:error, %RuntimeError{}}`), the same class as `:erlang.error/1`.
  It is deliberately *not* C#'s `throw`, because the BEAM's `throw` is the catchable non-local-
  return class. Evidence: [`prototypes/12b_raise_classes.exs`](../prototypes/12b_raise_classes.exs).
- **`none` is the bottom type**, first-class and writable. So a user may declare
  `none Reject(Reason);` — a named, greppable, type-checked crash site. Any error-model design
  here can use `-> none` as its "does not return" marker without inventing one.
- **The stance is signature-directed**: fail through the channel your signature declares; `raise`
  where it declares none. So *whether* a function fails as a value is a property of its return
  type, not of a global error-model preference.

**Left open for this ticket:**

- **What `raise` takes.** Elixir's takes a message or an exception struct; beam-sharp has no
  structs decided (→ ticket 26). An atom? A tagged tuple? A structured value?
- **Whether `throw` and `exit` surface at all.** The language cannot opt out of the platform's
  three classes, only decide how it presents them. Ticket 12 committed only to the error class.
- **Whether `try`/`catch` exists**, unchanged.
- **The two failure spellings still have no rule.** `ValidateAs<T>` returns `T | :error` and
  `option<T>` is `T | :nothing`. Ticket 12 §3 explains *when* a failure value rather than a crash
  is used, but not *which* value.
- **A false friend to design around**: `none` is a type with no values; `:nothing` is a value
  meaning absence. They read as near-synonyms and are opposites.

## Constraints from ticket 14 — resolved 2026-08-12

**The crash policy at the OTP boundary is already decided; this ticket inherits it rather than
setting it.** Ticket 14 §4 settled that `[module: GenServer]` names a contract the compiler knows
as a *type*, and the user writes a **narrower** callback signature which the compiler checks for
containment. Per ticket 12 that narrowing *is* the crash policy, so the error model at the OTP
layer is a consequence of signatures, not a separate mechanism.

Three inheritances that bind this ticket:

- **A failed call surfaces as an exit, not as a typed value**, in four of the five ways a client
  function can be handed the wrong pid ([`14d`](../prototypes/14d_wrong_pid_outcomes.erl)):
  `noproc` for a dead pid, the callee's own crash propagated for an unrecognised request, and
  `timeout` for a process that is not a gen_server. Only a *shape collision* returns a wrong
  value, and that is ticket 18's. So an error model that assumes failures arrive as values will be
  wrong about the OTP boundary specifically.
- **The argument position of a callback is `term`, and narrowing it is unsound** — Dialyzer permits
  it silently and you get `function_clause` at runtime
  ([`14e`](../prototypes/14e_callback_contract_containment.md)). beam-sharp rejects it by
  contravariance. Any error-model construct that appears in an argument position inherits this.
- **`(:noreply, s)` is the evasion to watch for.** Ticket 14 §4 rejected the wide OTP contract
  because it makes an evasive `(:noreply, s)` always type-correct on an unrecognised request,
  producing a **five-second silent hang** and then a `timeout` exit *at the caller* — the failure
  reported in the wrong process, at the wrong time, with the wrong reason.

Also relevant: ticket 14 §5 makes `receive` a **filter**, so a message that no `receive` clause
matches is not an error condition — it stays in the mailbox. An error model must not treat an
unmatched selective receive as a failure; the failure is the *timeout*, if one is declared.
