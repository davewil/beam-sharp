# 10 — Atoms in a C# skin

Type: grilling
Status: open
Blocked by: 01, 09

## Question

C# has no atom literal. How are atoms written, and how do they relate to the union and enum
story?

Constraints that make this harder than it looks:

- Atoms are **values, not types** — `:ok` is a value that can be a map key, a message tag, a
  return tag, or a module name.
- They are **globally interned and never garbage collected**, so a language that mints them
  freely creates a resource leak.
- They are pervasive in Erlang APIs: no interop story works without them.
- Booleans and module names *are* atoms on the BEAM.

Candidate directions to weigh: a sigil literal borrowed from Elixir; promoting C# `enum`
members to atoms; treating singleton case types of a union as atoms; a distinct
string-adjacent literal type; or requiring atoms be declared before use (which trades
ergonomics for leak safety and better exhaustiveness).

Decide the literal syntax **and** the typing story — what is the type of `:ok`, and how does
a function say it accepts exactly `:ok | :error`?

## Notes

HITL. Waits on ticket 01 for a concrete look, and ticket 09 because the answer differs
sharply depending on whether unions are nominal or structural.
