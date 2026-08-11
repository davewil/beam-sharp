# 06 — The Erlang/Elixir interop surface a new BEAM language must satisfy

Type: research
Status: resolved

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

## Answer

Findings: [wayfinder/research/06-interop-surface.md](../research/06-interop-surface.md) — a
requirements checklist, the untyped-caller violation enumeration, and a claim→source table.
Evidence is marked **doc** / **src** / **local** (verified here on OTP 28, Elixir 1.19.5).

- **The interop surface is smaller than expected.** `-behaviour` has *no runtime effect* — a
  module with no such attribute runs fine as a `gen_server`; only exports matter. Elixir needs
  no special machinery either: modules are the atom `'Elixir.Foo.Bar'`, structs are maps with
  `__struct__`, protocols are ordinary modules after consolidation.
- **A binary *is* a bitstring**, and map key order is the opposite of term order for
  int-vs-float. Two traps for a type system that models them naively.
- **The violation surface is eight channels**, not one: direct calls, mailboxes, `EXIT`/`DOWN`
  signals, timers, ETS, decoded external terms, `code_change/3` state from a previous version
  of your own types, and ambient config.
- **The load-bearing finding: an untyped caller does not always crash.** A function typed
  `Int, Int -> Int` called as `add(1.5, 2.5)` returns `4.0` silently; `hold(self())` puts a pid
  inside a `Box(Int)` with no error ever. Three outcomes — immediate crash, deferred crash,
  and silent unsoundness — and only the third is an argument for guards. One `when is_integer`
  clause converts it to `function_clause` at the call site.
- **Neither Gleam nor purerl defends against this.** Both document FFI types as trusted and
  unverified, both push safety to a library (`gleam/dynamic`, `purescript-erl-untagged-union`),
  neither emits `-behaviour`. purerl's off-by-default `--checked` parallel module is the only
  compiler-level precedent, and it is incomplete by design.
- **Relevant to ticket 14**: Gleam's answer to typed OTP was to *not* implement the behaviour
  contract at all. Ticket 00 makes `handle_call/3` the headline feature's showcase, so that
  route is closed — which makes the mailbox-defence question unavoidable.
- **Recommendation on tooling**: emit `-spec` (cheap, benefits Erlang callers and docs); do
  **not** build a `debug_info` backend for dialyzer — success typings are strictly weaker than
  the committed type system. Elixir's v1.20 checker offers foreign languages nothing, and its
  roadmap phases Erlang typespecs out rather than adopting them.

## Notes

AFK. Feeds tickets 14 and 15, and the fog around runtime defence against untyped callers.
