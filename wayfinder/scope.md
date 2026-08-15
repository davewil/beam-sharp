# Out of scope — the boundaries

> **Split out of [`map.md`](map.md) on 2026-08-15**, which had reached 1,564 lines while its own
> comment promised *"one line per closed ticket"*. The split was verified to reconstruct the
> original byte-for-byte; **nothing here was edited, only moved**. `map.md` carries the index —
> headline, ticket number and topic tags per entry — and this file carries the bodies.
>
> Audited 2026-08-15. None of the four is a refusal: three wait on a use case, one on demand. Every entry states which it is and what would reopen it.

## Out of scope

<!-- AUDITED 2026-08-15 (David: "audit the rest of out of scope"). This section used to carry the
     single marker `ruled beyond the destination; closed, never graduates`, and that marker was the
     defect rather than the entries. **All four below are BOUNDARIES written in the costume of
     REFUSALS** — three narrowed by hand within three days of each other, and the fourth
     demand-gated the same evening the audit ran. Four for four is not a coincidence; the marker
     was making a claim the entries never supported.

     Three kinds of entry could live here and they are NOT the same claim:

       REFUSAL (mechanism)  — a reason in the design that does not expire. Argue with the mechanism
                              or the entry stands.
       BOUNDARY (this map)  — not being decided by THIS effort. No claim about the language. May
                              return when a use case arrives that nothing else serves.
       BOUNDARY (demand)    — as above, with a NAMED reopening condition rather than an open one.

     Every entry states which it is, and the audit's result is worth stating plainly: **none of the
     four is a refusal.** Alternative backends was the last candidate and David demand-gated it the
     same evening, so all four are boundaries on this effort's scope and not claims about the
     language. That is the map's own rule about refusing on mechanism and never on taste, arriving
     from the other direction — a section that reads as four walls turns out to contain none. An
     implementer handed the spec in a clean room would have read it exactly wrong. -->


- **BOUNDARY — Tooling and ecosystem** — package manager, build tool, hex/rebar3/mix integration, LSP,
  formatter, docs generation. Every decision here is downstream of the language surface,
  and Gleam's experience suggests it is a multi-year track of its own.
  **Clarified 2026-08-13 (David, ticket 23): this rules out the ecosystem *track*, not any
  capability that happens to serve tooling** — *"tooling is not out of scope if there's a genuine
  need"*. A compiler mode answering a question an agent has (23 §10's `bsc --api`) is in; a package
  manager is not. Read the boundary as "is this the multi-year track, or one capability the
  language owes its author", and note ticket 23 raised the bar for what counts as a genuine need by
  making the compiler an interlocutor rather than only a gate.
- **BOUNDARY — Standard library breadth** — module-by-module design. The spec names stdlib *shape* as
  a design principle only.

  **AUDITED 2026-08-15: this entry was already narrower than it reads, and the narrowing was
  written somewhere else.** The fog patch *"Stdlib shape as a principle"* says in its own words
  **"Breadth is out of scope; the shape is not"**, and goes further — *"the prelude now has known
  contents"* (ticket 10's `bool`, `option<T>`, `ParseAtom<T>`, `ToExistingAtom`; ticket 11's
  `ValidateAs<T>`), which makes *what is in the prelude versus a module you import* a **live
  sub-question rather than a hypothetical one**. Ticket 17 §2 then decided that every
  compiler-known prelude collection operation is **inlined** at the call site, and ticket 14 §6
  answered *"may a user add to the prelude's second stratum"* — **no**. That is a lot of stdlib
  content decided inside a map whose Out of scope section appeared to forbid the subject.

  So the boundary is: **a broad library designed module by module is not this effort's work; the
  prelude is, and always has been.** Three things sit on the in side and are named here because
  David listed them 2026-08-15 as owed before any handoff: *what is in the prelude*, **wrapping
  the Erlang stdlib in beam-sharp happy forms**, and hex-package interop. The middle one is
  genuinely **deferrable rather than refused** — measured the same day,
  `bsc examples/interop.bs Total '[1,2,3,4]'` → `10` through `:lists.sum`, so `using :erlang { … }`
  serves it today at the cost of the wrapper's ergonomics, which is a price and not a wall.
- **BOUNDARY — Macros and metaprogramming** — quote/unquote, source generators, compile-time
  evaluation. A large semantic surface that interacts hard with a type system, and nothing
  about the core bet needs it.

  **CLARIFIED 2026-08-15 (David): this entry does NOT carry the section's "closed, never
  graduates" marker — it is a *maybe*, not a refusal.** In his words: *"Macros are not excluded,
  except from the current map, they may be included in the future should a valid use case emerge.
  Such as the DDD surface I'm interested in that Ash in Elixir makes heavy use of macros. Or maybe
  beam-sharp can do without them, I don't know yet."* The same shape as the tooling entry's
  clarification two days earlier, and the same underlying correction: the section had been read as
  ruling on the language rather than on **this map's scope**. What is settled is that the core bet
  does not need them and this effort is not designing them; what is open is whether a use case
  arrives that nothing else serves. **A DDD/resource surface of Ash's kind is the named candidate**,
  and it is a stronger one than ticket 31's, because a resource DSL is where Elixir's macros earn
  their keep rather than where they are merely convenient.

  Two things this does not do. It does not license a feature to build one, and it does not disturb
  the *"who may generate"* line below — a codegen obligation remains the compiler-owned answer, and
  a user-wielded facility remains a redrawing of the destination. It changes the **status** of that
  redrawing from ruled out to unpriced.

  **The neighbours are split, and the split is informative** (2026-08-13, measured locally where
  installed). **Elixir** has full macros, hygienic by default and escapable with `var!` — and its
  AST is genuinely homoiconic, verified here: `quote do: 1 + f(x)` yields
  `{:+, meta, [1, {:f, [], [{:x, [], Elixir}]}]}`, every node a `{form, meta, args}` triple.
  **LFE** and **Clojerl** have real Lisp macros. **Gleam refuses them outright** — the same shape
  as its refusal of `if` (→ 17c), and the closest neighbour to this language does without.
  **purerl**, **Caramel** and **Alpaca** have none. **Erlang has two weaker things and the
  underrated one is not the preprocessor**: `epp`'s `-define`/`?M` is C-like token substitution,
  but a **parse transform** receives an entire module's abstract forms and returns whatever forms
  it likes — cruder than Elixir's macros in ergonomics (no hygiene, module-wide rather than
  call-site) and strictly wider in reach. This map already depends on that mechanism: ticket 13's
  host-language choice turned partly on `merl`'s `?Q` riding a parse transform Elixir cannot use.

  **The first pressure on this exclusion comes from inside, and it is worth recording rather than
  acting on.** The standing constraint says beam-sharp is written by agents with generators
  scaffolding files, and Elixir's macros exist substantially so libraries can define DSLs.
  [Ticket 31](issues/31-composable-middleware.md) now hangs on `Plug.Builder`, which is exactly
  that — `@plugs` accumulated at compile time and a pipeline function generated. **If 31 concludes
  that middleware composition needs compile-time assembly, it is asking for something Elixir does
  with a macro.**

  **This does not reopen the exclusion, and the reason is already decided**: the map's answer to
  "the compiler writes it" is a **codegen obligation** (ticket 16 §4, ticket 27's ground-type rule),
  which is compile-time generation *the compiler owns* rather than a facility the user wields. The
  line to hold is **who may generate** — not whether generation happens, since six codegen
  obligations already do. Recorded here so that the next ticket to feel this pressure finds the
  answer rather than re-deriving it, and so that a *user-extensible* generation mechanism is
  recognised as a redrawing of the destination rather than an increment.
- **BOUNDARY (demand) — Alternative runtimes and backends** — a JavaScript or WASM target of the
  kind Gleam ships alongside its Erlang backend. Doubles the codegen surface and forces semantic
  compromises that would muddy a BEAM-native design.

  **SETTLED 2026-08-15 (David): *"alternative runtime/backend is out of scope unless this project
  gains traction and is requested."*** So the reopening condition is **named**, which is what
  separates this from the other three: they wait on a use case nobody can predict, this one waits on
  users who do not exist yet. It is also stated as *runtime or backend*, which is wider than the
  original entry's "JavaScript or WASM target" and covers any non-BEAM execution target.

  **What a requester would inherit, so the condition is actionable rather than decorative.** Traction
  reopens the *question*; it does not waive the *objection*, and the objection is now measured
  rather than asserted — see below. Whoever asks arrives holding: 36 of 38 tickets defining the
  language in BEAM terms, a runtime to write before the first line runs, and three BEAM-family
  projects that each declined to bring OTP to JavaScript. Being asked is not an answer to any of
  that; it is a reason to go and find one.

  **Audit note.** During the 2026-08-15 audit this was briefly classified a REFUSAL, as the only
  entry arguing from a mechanism rather than from scope, and it was the only one with no
  counter-evidence elsewhere in the map — the prelude, tooling and macro entries were each
  contradicted by decisions taken in this same document. David demand-gated it the same evening,
  which means **none of the four entries is a refusal**. The section's apparent walls are all
  boundaries.

  **CONFIRMED 2026-08-15 (David): *"yeah alternative backends out, too much work."*** Nobody has
  asked for one.

  ~~Ticket 13's emission contract — the frontend never depends on in-process compiler state, and
  what is emitted is a serialised text file — is precisely the property that would make a second
  backend *cheap* to bolt on later, so the **cost** argument is the erodable one and the entry
  should rest on the **design** argument instead.~~

  **RETRACTED WITHIN THE HOUR, and measured rather than argued.** David: *"hang on, you said it
  might be cheap?"* It is not. The claim conflated a clean **seam** with a small **job**, and the
  correction runs the opposite way to the sentence it replaces.

  What the emission contract genuinely buys is frontend reuse, and the split looks encouraging:
  **2,254 lines of lexer, parser, checker and algebra against a 499-line emitter** — 82% reusable,
  and a second emitter really can be plugged in without touching any of it.

  **The line count is the trap.** The emitter is small *because the BEAM already supplies the
  semantics*: atoms as first-class values, clause-head pattern matching, tail calls, immutable
  maps, binaries, and a failure arm `erlc` inserts and **cannot be suppressed** — `bs_emit`'s own
  header records that one as coming *free*. A JavaScript or WASM target does not translate to those
  things, it has to **implement** them, as a runtime, before the first line of beam-sharp runs.

  And the entanglement is not confined to the emitter. **36 of 38 tickets name BEAM, OTP,
  `gen_server` or Erlang mechanism in their decisions** — records erase to BEAM maps with minted
  atom tags (26 §1), the FFI is module-as-atom (32), `-behaviour` and `-spec` are emitted verbatim
  (13, 14), and the whole concurrency story is OTP. This language is not BEAM-*hosted*, it is
  BEAM-*defined*. **Gleam is the control**: it ships a JavaScript backend and drops OTP entirely on
  it, shipping a runtime library and, in effect, a different language per target.

  **And the neighbourhood was checked rather than cited (2026-08-15, David asking what else compiles
  to JS). Every BEAM-family project that ships JavaScript routes *around* the hard problem rather
  than solving it:**

  - **Gleam** — an official JS target, with OTP dropped on it.
  - **[Hologram](https://github.com/bartblast/hologram)** — *"intelligently compiles Elixir
    client-side code to JavaScript"*. It builds a **call graph** to decide which code runs on the
    client and transpiles only that, through an IR; the server stays on the BEAM and the two halves
    talk over websockets. So it is a **subset** strategy, not a language port. *(Whether it
    implements processes client-side was not established — checked and not found, rather than
    assumed.)*
  - **ElixirScript** — the earlier Elixir-to-JS attempt, dormant.

  Three projects, three ways of not bringing OTP to JavaScript. That is the strongest available
  evidence for this entry, and it is evidence about the *semantics* rather than the effort — which
  is why the design objection outlives the cost one.

  **So the cost argument is the better-supported of the two, not the weaker one.** David's *"too
  much work"* is what the measurement backs. The design objection stands beside it and is stronger
  still, since it would hold even if the work were free. Neither is in danger from the emission
  contract, which makes the *seam* clean and says nothing whatever about the *runtime*.
