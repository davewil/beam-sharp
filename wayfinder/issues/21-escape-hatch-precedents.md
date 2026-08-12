# 21 — How do opinionated languages preserve guarantees across their escape hatches?

Type: research
Status: resolved

## Question

beam-sharp is considering enforced conventions in the core (a DDD-shaped structure) with
**ports and adapters out to everything else**. That is a known language-design shape with real
precedents, and the precedents have known failure modes. Establish them before committing.

> **ATTEMPT LOG.** Two agents have died on this ticket without writing anything — the first
> stalled for ~48 minutes without claiming it, the second was interrupted at ~52 minutes with
> nothing on disk. Neither produced a partial file. If a third attempt also fails, the ticket is
> the problem rather than the agent, and it should be split into one narrow question per
> language rather than a comparison across five.
>
> **DESCOPED 2026-08-12: Elm is out of this ticket, by instruction.** The agent working it made
> no progress in ~48 minutes and had claimed nothing. Diagnosis: the brief bundled two different
> research shapes — a crisp technical question (what Elm validates at a port) and a *narrative*
> question (what Elm 0.19's removal of native modules cost). A fact either is or is not in a
> source; a narrative absorbs unbounded reading without ever feeling finished. They were bundled
> because they arrived in one conversation, not because they are one investigation.
>
> The Elm section below is struck. **One question from it survives and has moved to
> [ticket 18](18-boundary-defence.md)**: whether Elm validates values crossing a port at runtime.
> That is the only known candidate for a language that defends its boundary — ticket 06 found
> Gleam and purerl validate nothing — so it is worth ten minutes there rather than being lost
> with the rest.

Cover, from primary sources — language docs, RFCs, release notes, the designers' own writing:

### ~~Elm — the closest analogue~~ — DESCOPED, see above

- **How ports work**: what types may cross, synchronous versus asynchronous, and — the decisive
  question for [ticket 18](18-boundary-defence.md) — **what validation happens to a value
  entering Elm from JavaScript**, at runtime, and what happens when it fails. Ticket 06 found
  neither Gleam nor purerl validates at the FFI boundary; if Elm does, it is the working
  precedent for emitting boundary guards.
- **The Elm Architecture as an enforced architecture** — how much is grammar, how much is the
  type of `Browser.element`/`Program`, how much is convention.
- **What Elm 0.19's removal of native modules / third-party effect managers cost.** Find the
  stated rationale and the actual consequences: what broke, what the community response was, what
  the maintainers said afterwards. This is the case study in *retracting* an escape hatch, and it
  is the risk beam-sharp takes on if it bakes conventions into the grammar.

### Roc — platforms as hexagonal architecture in the language

- What a platform is, what it provides, and where the boundary between platform and app sits.
- How effects cross that boundary and what the type system says about them.
- Whether an app can be moved between platforms, and at what cost.
- Whether this is genuinely ports-and-adapters as a language feature or a different thing wearing
  the name.

### Unison — abilities

- How algebraic effects/abilities express the same separation.
- What the handler boundary guarantees, and what it costs in inference or ergonomics.
- Whether abilities scale to a large application or remain elegant-in-the-small.

### And for contrast, at least briefly

- ~~**Eiffel's Design by Contract** — a methodology baked into a language. What happened to it, and
  why DbC survived as libraries and annotations elsewhere rather than as language features.~~
  **This premise was wrong and the research inverted it.** Eiffel's `require`/`ensure`/`invariant`
  are *still grammar*; Ada's `Pre`/`Post` are *still aspects*. It is the **library** form that died
  — .NET Code Contracts is unsupported in .NET 5+, repo archived 2023-07-15. The discriminator is
  **tooling weight**: Code Contracts needed a binary rewriter, a separate static checker and a
  `CONTRACTS_FULL` define, all of which could simply not be run. **Microsoft's named successor is
  nullable reference types — the contract that survived is the one that became a type.**
- **Rails and Phoenix** — convention layered *above* a neutral language. What that separation
  bought when the conventions changed (Phoenix contexts changed more than once without touching
  Elixir).

### The synthesis the ticket exists for

For each: **what does the escape hatch owe the guaranteed core, and who enforces it?** Then state
plainly which of these models could work on the BEAM, where processes, mailboxes and untyped
Erlang callers make the boundary far more porous than Elm's single JavaScript edge — ticket 06
enumerated **eight** violation channels, not one.

## Answer

Full findings: [research/21-escape-hatch-precedents.md](../research/21-escape-hatch-precedents.md).
Roc and Unison covered properly; Eiffel and Rails/Phoenix as the brief's contrast pair. Elm not
researched, per the descope.

**Neither Roc's nor Unison's mechanism transplants to the BEAM, and they fail in opposite
directions.** Roc's "there are no escape hatches" rests on *link-time closure* — the app physically
cannot contain a primitive the platform did not compile in. Ticket 06 §C establishes the BEAM is
architecturally committed to the negation of that: name-based dispatch, `apply/3` from runtime data,
no way to export to your own compiler but not to `erl`, plus hot code loading. Unison's abilities
are sound and reach further — every effect is named in the type and inherited by every caller, and
even the planned FFI is *itself* an ability rather than a hole — but a handler discharges an ability
**at a call site in a lexical scope**, and channels 2–8 are not calls. Nothing invokes your handler
when a monitor fires. Mapped against the eight channels, ability propagation reaches one fully and
three partially; only a **check emitted where an external term becomes a typed value** reaches all
eight, and that is a codegen obligation, not a type-system feature.

For [ticket 22](22-how-opinionated.md), the contrast pair points one way. Eiffel's `require`/`ensure`
survived in the grammar and Ada's `Pre`/`Post` survived as aspects, while .NET Code Contracts — same
idea, but needing a binary rewriter, a separate static checker and a `#define` — is unsupported and
archived, with nullable reference types named as its successor. **The contract that survived is the
one the compiler that already builds your code can check; the one that became a type.** And Phoenix
moved contexts, route helpers and generator scaffolding repeatedly on ordinary Elixir minor
releases, keeping the old convention working behind an option each time — which is the specific
thing a grammar keyword forfeits: two conventions coexisting during a migration.

## Notes

AFK. Feeds [ticket 22](22-how-opinionated.md) directly and [ticket 18](18-boundary-defence.md)
substantially. Raised 2026-08-12 out of ticket 01's design conversation.
