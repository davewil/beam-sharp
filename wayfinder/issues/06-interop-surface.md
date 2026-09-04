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

## The third outcome, demonstrated — from ticket 10, 2026-08-12

This file's load-bearing finding is that **an untyped caller does not always crash**, and that
the third outcome — *silent unsoundness* — is the only one arguing for emitted guards. It also
recorded that neither Gleam nor purerl defends against any of it, a claim the map flagged as
**inferred from the absence of guard emission** rather than observed.

**It is now observed.** Gleam 1.18.1 / OTP 28, calling a compiled Gleam module from raw Erlang
([`prototypes/10c_gleam_forge.erl`](../prototypes/10c_gleam_forge.erl)):

```
describe(red) from raw Erlang  : {ok,<<"r">>}     % foreign atom accepted as a nominal Colour
describe(purple) forged        : {caught,error,case_clause}
area({circle, <<"str">>})      : {ok,<<"str">>}   % -spec area(shape()) -> float().
```

The last line is the third outcome in the flesh, and **worse than this file's own example**:
`add(1.5, 2.5)` returning `4.0` is a wrong number, whereas this is a wrong *kind of term* —
a binary leaving a function whose spec says `float()`. No crash, no coercion, nothing logged.

The asymmetry between lines 2 and 3 is new and belongs to ticket 18: forging the **tag** is
caught, because the tag is what a clause head tests; forging the **payload** is not, because
the payload is bound rather than checked.

## Notes

AFK. Feeds tickets 14 and 15, and the fog around runtime defence against untyped callers.

## Constraints from ticket 13 — resolved 2026-08-12

**This ticket's `-spec` recommendation is confirmed, not withdrawn.**

The recommendation was contingent: ticket 02 found a `-spec` is lost through Core Erlang, where
Dialyzer cannot read the resulting beam and fails *silently*. Ticket 13 chose the **Erlang Abstract
Format**, on which a `-spec` survives by construction — both halves measured
([`prototypes/13a_target_measurements.md`](../prototypes/13a_target_measurements.md) §2): the
Abstract Format path preserves the spec attribute intact, while the `.core` path exits 0, emits no
warning, produces a working module, and leaves `{raw_abstract_v1,[]}` — a chunk that is *present
but empty*, which Dialyzer reads successfully and learns nothing from.

Ticket 13 §6 rules that the compiler **emits a `-spec` for every function whose beam-sharp type is
known**, widening to the nearest expressible supertype where a set-theoretic type has no Erlang
spelling. The FFI case this ticket left open — where a spec is an unverified claim — remains with
ticket 18.

Source-only sub-modules (ticket 13 §3) also settle this ticket's related ask directly: an Erlang
caller sees a normal module, `'Shop.Orders.Order':apply(O, E)`, with no facade.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Erlang/Elixir interop surface](issues/06-interop-surface.md) — the surface is **smaller than
  expected** (`-behaviour` has no runtime effect; Elixir needs no special machinery), but the
  violation surface is **eight channels**, not one. The load-bearing finding: **an untyped
  caller does not always crash** — there are three outcomes, and the third is *silent
  unsoundness* (`add(1.5, 2.5)` returning `4.0` from an `Int, Int -> Int` function). Only that
  third case argues for emitted guards. Neither Gleam nor purerl defends against any of it.
  Gleam's answer to typed OTP was to not implement the behaviour contract at all — a route
  closed to this language, since ticket 00 makes `handle_call/3` the showcase.
```
