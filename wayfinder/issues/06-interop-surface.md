# 06 — The Erlang/Elixir interop surface a new BEAM language must satisfy

Type: research
Status: open

## Question

What must a new BEAM language support to interoperate with existing Erlang and Elixir code?

Establish:

- **Data types** it must produce and consume: atoms, binaries vs charlists, proper and
  improper lists, tuples, maps, pids, refs, ports, funs, bitstrings, and the ordering rules
  across term types.
- **Module and function conventions**: name-and-arity identity, exports, `-spec`
  attributes, module attributes the ecosystem expects.
- **Behaviours and callbacks**: how a language declares it implements `gen_server`,
  `supervisor`, `application`; what the compiler must emit for the behaviour check.
- **Elixir specifics**: how structs, protocols and the `Elixir.` module prefix appear from
  outside; whether Elixir libraries are reachable without an Elixir dependency.
- **Error propagation across the boundary**: `throw`, `error`, `exit`, and how they surface
  to a caller in another language.
- **What a language must emit to be visible to dialyzer** and to Elixir's v1.20 type
  checker — and whether that is worth doing.
- **Where a static type system's assumptions can be violated by an untyped caller**, and
  what other typed BEAM languages (Gleam, purerl) do about it — runtime checks at the
  boundary, or nothing at all.

Write findings to `wayfinder/research/06-interop-surface.md` and link here.

## Notes

AFK. Feeds tickets 14 and 15, and the fog around runtime defence against untyped callers.
