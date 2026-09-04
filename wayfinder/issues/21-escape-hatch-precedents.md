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

---

# Partial retraction — ticket 18, 2026-08-13

**This ticket's claim that no language defends its boundary by checking data is false as stated.**
Elm does, and Elm was descoped here after this ticket stalled on a bundled narrative question. The
narrow technical half was picked up by [ticket 18](18-boundary-defence.md) and measured:
[`research/18-elm-port-validation.md`](../research/18-elm-port-validation.md), Elm 0.19.1, mostly
`local` rather than cited.

**What was wrong.** This ticket concluded: *"No language in the file defends its boundary by checking
data; they defend by controlling who may be on the other side."* The second clause is right and the
first is not. `Optimize/Port.hs toDecoder` synthesises a JSON decoder from each port's declared type,
and `_Platform_setupIncomingPort` runs it on **every** incoming value — `send` *is* the decode, and
`sendToApp` is unreachable unless it succeeded, byte-identical under `--optimize`. Elm does **both**:
it owns the door *and* checks what comes through it.

**The sharpened claim, which is what ticket 18 actually used:** *checking data is what you do at a
door you own.* Roc trusts its host and Unison's handler receives whatever the runtime hands it
because neither has a door where a foreign value becomes a typed one; Elm has exactly one
(`return { send: send }`) and checks there. **The BEAM's problem was never that checking data is
unusual — it is that there is no door.** That is why ticket 18's answer is a check emitted at every
point beam-sharp *compiles*, which is this ticket's original conclusion reached by the route this
ticket got wrong.

**Two findings that survive intact and were load-bearing for 18.**

- Elm's admissible port type set is a closed whitelist — measured rejections include functions, type
  variables, extended records, `Dict`, `Set`, `Char`, `Result` and **every** custom union, including a
  payload-free enum. That set is precisely *"types with a decidable structural test"*: **ticket 09
  §4's rule, and ticket 11 §3's arrow exclusion, reached independently on a different runtime.**
- **A checking boundary can still be unsound.** `_Json_decodeInt` accepts any finite whole number, so
  `1e300` crosses an `Int` port, `String.fromInt` yields `"1e+300"` and `n + 1 == n`. Ticket 06's
  outcome 3, inside a language that defends. beam-sharp does not inherit it — `is_integer/1` is exact
  — but it is the measured reason the strongest possible claim ("your types hold, whoever calls you")
  is harder to keep than it sounds, and it is why 18 chose a claim with its concession stated.

**Not retracted**: everything about Roc's link-time closure, Unison's abilities reaching one of the
eight channels, the DbC survival analysis, and `requires` as a stealable contract mechanism. Elm's
inclusion changes the *general* claim about how languages defend, not any finding about the languages
this ticket actually examined.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Escape-hatch precedents](issues/21-escape-hatch-precedents.md) — **neither Roc's nor Unison's
  mechanism transplants, and they fail for the same reason in opposite directions: both control
  what a program may *reach*, where ticket 06's problem is what may reach the *program*.** Roc's
  guarantee rests on **link-time closure**, which the BEAM is committed to not having — `apply/3`,
  no visibility modifiers, hot code loading, and "no way to publish a function to your own compiler
  but not to `erl`". Unison's abilities discharge at a *call site*, so they reach **1 of the 8
  violation channels** — nothing invokes your handler when a monitor fires. **No language in the
  file defends its boundary by checking data; they defend it by controlling who may be on the other
  side.** So the only mechanism reaching all eight is a **check emitted where an external term
  becomes a typed value** — a codegen obligation, and available precisely because beam-sharp
  compiles the `receive`, the `handle_info`, the ETS wrapper and `code_change`. Three further
  findings: every model that enforces anything does so **with the tool that already builds the
  code** (the one needing a second tool, .NET Code Contracts, was simply not run); **no model has
  both enforcement and revisability** — Phoenix could move contexts three times because nothing
  depended on them, and Roc's FAQ answers "No" to swapping platforms; and Roc's **`requires`**
  clause is directly stealable as a typed, compiler-checked OTP behaviour contract, strictly better
  than Erlang's `-callback`. **A premise in my own brief was inverted by the research**: DbC did not
  survive as libraries — Eiffel's `require`/`ensure` are *still grammar*, Ada's `Pre`/`Post` are
  *still aspects*, and it is the **library** form that died (.NET Code Contracts, archived
  2023-07-15). The discriminator is **tooling weight**, and **Microsoft's named successor is
  nullable reference types — the contract that survived is the one that became a type.**
```
