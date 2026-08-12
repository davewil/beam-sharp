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

## Evidence from prototype 01g — the case against `:atom` largely collapsed

Two objections were raised against Elixir's `:atom` sigil and **both fail on examination**:

- **"It costs the ternary operator."** No BEAM language has a ternary. Not Erlang, not Elixir, not
  LFE, and Gleam explicitly replaces it with `case`. The objection was imported from C#, not from
  the platform. And the replacement is better than the thing given up — **make `if` an
  expression**, as Rust and Kotlin do and as Elixir effectively already does (`if cond, do: a,
  else: b`). Expression-`if` takes blocks as well as expressions, is a more familiar keyword to a
  C# developer than the symbol lost, and partly relieves the intermediate-value friction from 01b
  since a conditional no longer forces a drop into a block body.
- **"`{ Status: :draft }` puts two colons adjacent."** That is exactly the shape Elixir writes as
  `%{status: :draft}` — the most-read syntax in that ecosystem. An aesthetic objection dressed as
  a technical one.

What remains against `:atom` is `[module: GenServer]` sharing the character in a positionally
distinct place. The alternatives fare worse: `#atom` collides with the `#{}` map literal, and
`'atom'` inherits Erlang's oldest confusion (`'ok'` the atom versus `"ok"` the binary).

**A consequence to decide with the sigil**: if `if` becomes an expression, that is a language-wide
change, not an atoms decision. It should be recorded wherever expression-versus-statement is
settled. → ticket 08 or 17.

## Notes

HITL. Waits on ticket 01 for a concrete look, and ticket 09 because the answer differs
sharply depending on whether unions are nominal or structural.
