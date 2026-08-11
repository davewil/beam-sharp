# 12 — Totality versus let-it-crash

Type: grilling
Status: open
Blocked by: 04, 11

## Question

Must every function be exhaustive?

The conflict is cultural as much as technical:

- **Enforced totality** is the guarantee that justifies the type system. If clauses must
  cover the input type, a whole class of `function_clause` crashes disappears at compile
  time — and that is the headline claim.
- **But BEAM culture says a badly-shaped message should crash the process.** Erlang's
  `function_clause` error is a *feature*: the process dies, the supervisor restarts it, the
  system stays up. Defensive exhaustive handling of impossible cases is an anti-pattern
  there, not a virtue.
- And the compiler cannot know everything: a message arriving from an untyped Erlang caller
  may have any shape at all, so total-in-theory functions still meet impossible input in
  practice.

Decide the stance. Candidates: total by default with an explicit partial opt-in; partial
permitted with a warning; total only where the input type is fully known and dynamic
elsewhere; or totality enforced at typed boundaries and abandoned at dynamic ones.

Then state how it interacts with **supervision** — if a clause is proven exhaustive but the
runtime value defies it, what happens, and does the process still die cleanly?

## Notes

HITL. This is where the language's philosophy gets decided, not merely its semantics.
