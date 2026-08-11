# 01 — What does a page of idiomatic beam-sharp look like?

Type: prototype
Status: claimed

## Question

Produce a page of idiomatic sample code in the imagined language — a concrete artifact to
react to, explicitly **not** a committed syntax.

It should exercise, at minimum:

- a function with several clauses, dispatching on literal patterns
- destructuring in the argument position: tuples, maps, and whatever stands in for records
- at least one guard
- a union declaration and a function that dispatches over its cases
- one OTP callback set in the `handle_call` / `handle_info` shape, since that is the
  feature's best showcase
- a value crossing the Erlang interop boundary

Write it to `wayfinder/prototypes/01-sample-code.md` and link it here. Where a choice is
genuinely open, show two variants side by side rather than picking silently.

The resolution should record which choices felt right, which felt wrong, and — most
valuable — which arguments the concrete code settled that prose was circling.

## Notes

Leads the frontier deliberately: language-design arguments conducted in the abstract go in
circles; the same argument conducted over a snippet resolves quickly, because everyone can
see what they are objecting to. It also unblocks more tickets than any other.

HITL — the reactions are the deliverable, not the code.
