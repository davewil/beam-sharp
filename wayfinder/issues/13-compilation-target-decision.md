# 13 — Compilation target decision

Type: grilling
Status: open
Blocked by: 02, 11

## Question

Given the survey in ticket 02 and the type system shape settled in ticket 11: which target
does the compiler emit — **Core Erlang**, the **Erlang Abstract Format**, or **BEAM
bytecode**?

State:

- The choice, and the decisive reason.
- What it costs in expressible semantics — particularly whether multi-clause dispatch is
  inherited from the target or must be synthesised by the frontend, and whether the
  frontend's clause-merging can be made to agree with the exhaustiveness checker.
- What it costs in tooling: stack traces, debugger, dialyzer, hot code loading, crash-report
  legibility.
- The exposure to OTP release churn, and the mitigation.
- Whether the choice is reversible later, and at what cost.

## Notes

HITL, but heavily fact-led — most of the work is in ticket 02. Blocked by ticket 11 because
a type system that erases entirely has different target needs than one wanting to emit
type-derived runtime checks at boundaries.
