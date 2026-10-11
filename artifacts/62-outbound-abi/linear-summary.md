**Brief for ticket 62 (outbound ABI). This is a recommendation; the ticket stays open.**

The ticket's premise is wrong. It says Elixir cannot call a PascalCase export except through `apply/3`. In fact `:Shop."New"(1)` parses and runs (probe 01). Pipes, captures, `Enum.map`, dynamic receivers, macros and `defdelegate` all work with it. Only the unquoted `:Shop.New(1)` is a syntax error, and Elixir's message for it never mentions quoting. `LANGUAGE.md` section 12 repeats the wrong claim and needs fixing whatever is decided.

Options (each as a program plus compiler delta in the brief):
- **A. Accept it and document the quoted call.** No compiler change. a bare call after `import :Shop` stays impossible (a macro-built call works).
- **B. Emit snake_case aliases.** `:Shop.new(1)` and `import` work. Measured at 200 functions: exports double; .beam +25% to +53% and compile time +15% to +76%, depending on body size (verifier reran it). The runtime hop is a `call_only` jump, under about 1 ns/call (0.0 to 0.4 ns/call measured, positive control sees +8 ns). The derivation rule becomes a public ABI. `NewUrl`/`NewURL` and `ModuleInfo` collide.
- **C. Change B# to snake_case functions.** Removes the lexical rule ticket 26 relies on. Not costed by implementation.

**Recommendation: A**, plus a doc fix. Gating question for David: is `:Shop."New"(1)` acceptable to tell an Elixir team?

Also: ticket 10's "Gleam downcases PascalCase" is true only for type-variant constructors. Gleam refuses a PascalCase function name, so it is no precedent for aliases. Gleam's `@external` into B# now runs, not just compiles.

Most surprising measurement: the boundary checks only what the clause patterns name. A map with the right tag and a missing field is accepted by `Which` and fails later in `Amount`.

Brief: `artifacts/62-outbound-abi/brief.md` (probes in `artifacts/62-outbound-abi/probes/`).
