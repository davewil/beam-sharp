# Map: beam-sharp — a C#-syntax BEAM language with multi-clause function heads

`wayfinder:map` · charted 2026-08-11

## Destination

A **language design specification** for a BEAM-targeting language with C#-family brace
syntax, whose defining feature is Erlang-style multi-clause function heads with pattern
destructuring, statically checked by a set-theoretic type system that proves clause
exhaustiveness.

The spec covers surface syntax, the type system, multi-clause semantics, the OTP /
concurrency and Erlang interop model, and the compilation target — complete enough that a
compiler build could start. It ends with a **walking-skeleton compiler** over a slice
carved from that spec; which slice, and in what implementation language, is fog until the
spec exists.

## Notes

- **Domain**: programming-language design; BEAM/OTP; C# language features; type theory
  (semantic subtyping / set-theoretic types).
- **Tracker deviation**: map at `wayfinder/map.md`, tickets at
  `wayfinder/issues/NN-<slug>.md`, research findings at `wayfinder/research/NN-<slug>.md`,
  prototypes at `wayfinder/prototypes/`. **Not** the local tracker's default `.scratch/`.
- **Execution override**: wayfinder is plan-only by default. This map sanctions execution
  for the **walking skeleton only**. Every other ticket produces a decision.
- **Skills each session should consult**: `/grilling` and `/domain-modeling` for decision
  tickets, `/research` for research tickets, `/prototype` for prototype tickets,
  `/diagram-artifact` before writing any mermaid.
- **Research findings land on `master`** as files under `wayfinder/research/`, linked from
  their ticket — not on throwaway branches, which parallel agents would collide over.
- The effort is understood to be large. The map exists so it need not fit in one session.
- **Evidence provenance**: research files mark claims `doc` / `src` / `local`, where `local`
  means directly observed here (OTP 28, Elixir 1.19.5). Known gaps carried forward, recorded
  so nobody assumes they were checked: Gleam is not installed locally so every Gleam claim is
  `doc` or `src`, and Gleam's stance on foreign callers is *inferred from the absence of guard
  emission* rather than documented first-party; Elixir 1.20 was not exercised.

## Decisions so far

<!-- one line per closed ticket: enough to judge relevance, then open the ticket for detail -->

- [Charting: differentiator, typing stance, scope](issues/00-charting-decisions.md) — the
  language exists for the multi-clause heads Gleam explicitly refuses; typing is
  static-by-default set-theoretic with enforced cross-clause exhaustiveness; tooling,
  stdlib breadth, macros and alternative backends are out of scope.
- [Prior art: static types plus multi-clause heads](issues/03-prior-art-static-multiclause.md)
  — **Gleam never rejected multi-clause heads; it never considered them.** No rationale
  exists, and the soundness hypothesis is affirmatively weakened (Gleam's shipped checker
  already runs Jules Jacobs' algorithm over nested multi-column patterns). Projects stall on
  **commercial dependency**, not type theory — purerl survives because a company ships on it;
  Hamler, Caramel and Alpaca each had zero internal consumers. The core bet is proven
  feasible: Alpaca shipped multi-clause heads on an HM BEAM language. **NVLang is a citation
  hazard** — see the ticket before citing it anywhere. *(One claim in this ticket was later
  retracted by ticket 19 — see there.)*
- [Audit of `purescript-backend-erl`](issues/19-purescript-backend-erl-audit.md) — **retracts a
  ticket 03 claim**: it emits **exactly one clause per function, always, with no guard**, not
  native clause heads. The cause is upstream and unreachable from any backend — `purs` merges
  equations into one CoreFn `ExprCase` and the optimiser's IR has no pattern node at all.
  **Net for ticket 13: no BEAM backend fed by a curried functional frontend emits clause heads.**
  The only two that keep heads are LFE and Elixir, whose surface syntax has them natively —
  which is beam-sharp's position, making this a counter-example rather than a template.
- [Compilation targets](issues/02-compilation-targets.md) — **three tiers, not a binary.** The
  **Abstract Format expresses multi-clause heads natively** (a function *is* a clause list);
  Core Erlang does not at the head but hands you the primitive one level down, costing a
  mechanical ~50-line wrapper; BEAM bytecode needs a full match compiler. The cliff is between
  Core and bytecode, not between Abstract Format and Core. **Dialyzer is the sharpest
  discriminator and it fails silently**: compiling from `.core` emits an empty abstract chunk
  with no warning, and a `-spec` is lost through that path — which collides directly with
  ticket 06's recommendation to emit specs.
- [Cross-clause exhaustiveness](issues/04-crossclause-exhaustiveness.md) — **the mechanism is
  not a research risk; it has been solved and shipped since 2003.** But exhaustiveness is only
  well-posed against a **declared** input type: redundancy is relative, exhaustiveness is
  absolute. CDuce checks it because functions carry a mandatory interface; Elixir cannot,
  because it *builds* the function type from the clauses, making the check vacuous.
  **Therefore multi-clause functions in this language must carry signatures — inference alone
  doesn't weaken the guarantee, it makes the question disappear.** That is a binding constraint
  on tickets 08 and 11. Also: Elixir v1.20 ships **redundancy only, not exhaustiveness**.
- [Erlang/Elixir interop surface](issues/06-interop-surface.md) — the surface is **smaller than
  expected** (`-behaviour` has no runtime effect; Elixir needs no special machinery), but the
  violation surface is **eight channels**, not one. The load-bearing finding: **an untyped
  caller does not always crash** — there are three outcomes, and the third is *silent
  unsoundness* (`add(1.5, 2.5)` returning `4.0` from an `Int, Int -> Int` function). Only that
  third case argues for emitted guards. Neither Gleam nor purerl defends against any of it.
  Gleam's answer to typed OTP was to not implement the behaviour contract at all — a route
  closed to this language, since ticket 00 makes `handle_call/3` the showcase.
- [C# 15 `union` and TypeScript discriminated unions](issues/07-csharp15-and-ts-unions.md)
  — C# unions are **preview, not shipped**, and the design is still moving (champion issue is
  #9662, not #8928; no primary source for "GA Nov 2026"). They are nominal, closed struct
  wrappers; exhaustiveness only suppresses a *warning*. **The rejected designs matter more**:
  C# killed both structural/erased union designs on CLR artefacts — reified generics and
  nominal identity — **and neither rock exists on the BEAM**. TypeScript is structural but
  stops short of set-theoretic (syntactic intersections, no negation, opt-in exhaustiveness).
- [C# functional feature inventory](issues/05-csharp-functional-inventory.md) — LINQ query
  comprehension is portable (ECMA-334 makes it a pure syntactic rewrite, bound before type
  binding, with no `IEnumerable<T>` dependency); extension-method chaining *is* already a
  pipeline rewrite; `with` becomes more central than in C#. Dropped: `init`/`readonly`,
  nullable reference types, iterators and `async`/`await`. Two debts left open — no ad-hoc
  polymorphism story, and slice patterns over cons cells.

## Not yet specified

<!-- in-scope fog: real, but not yet sharp enough to phrase as a ticket -->

- **The walking skeleton**: which slice of the spec it implements, and what language the
  compiler itself is written in. Cannot be phrased sharply until the language surface exists.
  One requirement is already known: it should **measure checker cost at the clause counts the
  showcase implies**. Ticket 04 found Etylizer's pathological inputs are `case` expressions
  with 40+ branches — precisely the large multi-clause `handle_info` this language advertises.
- **Data modelling**: records, structs, `with` expressions, and how they relate to Erlang
  maps and tuples. Entangled with the union-representation decision.
- **Module and namespace system**, and function identity — BEAM identifies functions by
  name *and arity*, which multi-clause heads and optional parameters both disturb.
- **The language's name.**
- **Stdlib shape as a principle** — Erlang-ish flat modules, C#-ish namespaced statics, or
  Gleam-ish. Breadth is out of scope; the shape is not.
- **Runtime behaviour against untyped callers** — what, if anything, the compiler emits to
  defend a typed function called from raw Erlang.
- **Consuming Gleam and Elixir libraries** — possible, and at what ergonomic cost.

## Out of scope

<!-- ruled beyond the destination; closed, never graduates -->

- **Tooling and ecosystem** — package manager, build tool, hex/rebar3/mix integration, LSP,
  formatter, docs generation. Every decision here is downstream of the language surface,
  and Gleam's experience suggests it is a multi-year track of its own.
- **Standard library breadth** — module-by-module design. The spec names stdlib *shape* as
  a design principle only.
- **Macros and metaprogramming** — quote/unquote, source generators, compile-time
  evaluation. A large semantic surface that interacts hard with a type system, and nothing
  about the core bet needs it.
- **Alternative backends** — a JavaScript or WASM target of the kind Gleam ships alongside
  its Erlang backend. Doubles the codegen surface and forces semantic compromises that
  would muddy a BEAM-native design.
