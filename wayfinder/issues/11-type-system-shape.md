# 11 — Type system shape and the `dynamic()` boundary

Type: grilling
Status: open
Blocked by: 03, 04, 09

## Question

Ticket 00 committed to "static-by-default set-theoretic types". What shape does that take
concretely?

Decide:

- **Generic syntax.** C# angle brackets, or something else? Does the language even need
  parametric polymorphism given set-theoretic unions can express a lot without it?
- **Inference strength.** Full inference, or annotations required at module boundaries?
  Elixir infers without annotations; Gleam infers within a module and encourages
  annotations at the edges. Note that set-theoretic inference has a performance cost that
  Elixir's roadmap is explicitly gated on.
- **Subtyping rules** — what the subtype relation is, and whether variance needs stating.
- **The `dynamic()` boundary**, the critical part:
  - Where is `dynamic()` introduced — only at declared interop points, or anywhere?
  - What operations are permitted on a `dynamic()` value?
  - Do values crossing from Erlang arrive dynamic by default, or must the programmer
    declare a typed boundary?
  - What happens when a dynamic value flows into an exhaustively-checked function — does
    exhaustiveness still mean anything?
- **What is checked at compile time versus what is trusted.** Name the guarantee the
  language actually offers, in one sentence a user would understand.

## Notes

HITL. Waits on ticket 04 for the algorithms, ticket 03 for what has and has not worked
before, and ticket 09 because the union model determines what a type even is here.
