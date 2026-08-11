# 02 — Compilation targets: Core Erlang vs Abstract Format vs BEAM bytecode

Type: research
Status: open

## Question

What are the tradeoffs between targeting **Core Erlang**, the **Erlang Abstract Format**,
and **BEAM bytecode** directly?

Establish, with sources:

- Which target each existing BEAM language uses and why — Gleam, LFE, Elixir, Caramel,
  purerl, Hamler, Alpaca.
- **Which forms express multi-clause function heads with guards natively**, versus
  requiring the frontend to merge clauses into a single-argument `case` itself. This is the
  decisive question for this effort: if the target already has clause dispatch, the
  compiler inherits it; if not, clause merging becomes frontend work that must agree with
  the exhaustiveness checker.
- What guards each target permits (the BEAM restricts guard expressions severely).
- Tooling consequences: stack traces, the debugger, dialyzer visibility, hot code loading,
  `:observer` and crash-report legibility.
- Stability of each format across OTP releases, and what breaks when OTP changes.
- Whether the target constrains the type system, or is neutral to it.

Write findings to `wayfinder/research/02-compilation-targets.md` and link them here.

## Notes

AFK. Feeds ticket 13, where the decision is actually made. This ticket establishes facts,
not the choice.
