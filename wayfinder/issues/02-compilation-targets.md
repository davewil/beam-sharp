# 02 — Compilation targets: Core Erlang vs Abstract Format vs BEAM bytecode

Type: research
Status: resolved

## Question

What are the tradeoffs between targeting **Core Erlang**, the **Erlang Abstract Format**,
and **BEAM bytecode** directly?

Establish, with sources:

- Which target each existing BEAM language uses and why — Gleam, LFE, Elixir, Caramel,
  purerl, Hamler, Alpaca.
- **Which forms express multi-clause function heads with guards natively**, versus
  requiring the frontend to merge clauses into a single-argument `case` itself. This is the
  decisive question for this effort: if the target already has clause dispatch, the
  compiler inherits it; if not, clause merging becomes frontend work that must agree with
  the exhaustiveness checker.
- What guards each target permits (the BEAM restricts guard expressions severely).
- Tooling consequences: stack traces, the debugger, dialyzer visibility, hot code loading,
  `:observer` and crash-report legibility.
- Stability of each format across OTP releases, and what breaks when OTP changes.
- Whether the target constrains the type system, or is neutral to it.

Write findings to `wayfinder/research/02-compilation-targets.md` and link them here.

## Answer

Findings: [wayfinder/research/02-compilation-targets.md](../research/02-compilation-targets.md)
— nine sections, 47-row claim→source table, empirical claims run on OTP 28.5 locally.

**The decisive question is not binary — it is three tiers, and the middle one matters.**

| Target | Multi-clause heads? | What the frontend owes |
|---|---|---|
| **Abstract Format** | **Yes, natively** — a function *is* a list of clauses | Nothing. One `{clause,…}` per source clause |
| **Core Erlang** | **No at the head, yes for the primitive** — `case` gives N clauses, each with its own multi-pattern list and guard, tried in order | A mechanical wrapper of maybe fifty lines, plus a synthesised failure clause |
| **BEAM bytecode** | **No, at any level** | A full match compiler: decision trees, `select_val`, register allocation, fail-label wiring |

The cliff is between tiers 2 and 3, not 1 and 2.

- **Dialyzer is the sharpest single discriminator, and it fails silently.** Dialyzer's IR *is*
  Core Erlang but it cannot read a `.core` file — it reads `debug_info` from a beam, and that
  chunk holds *abstract* code. Compiling from `.core` with `+debug_info` emits an **empty**
  abstract chunk with **no warning**; `core_v1` returns `failed_conversion` and Dialyzer refuses
  the file. The custom-`debug_info`-backend workaround (Elixir's and LFE's route) has a trap: a
  Core call node lacking a `{file,_}` annotation crashes the analysis with `function_clause`
  rather than reporting a diagnostic.
- **This collides with ticket 06's recommendation.** A `-spec` survives the Abstract Format
  path by construction, and is **lost through `.core`**. So targeting Core Erlang forfeits the
  ability to publish types Erlang-side tooling can consume — which ticket 06 recommended doing.
  Decisive input for ticket 13.
- **All three targets are untyped and equally neutral about beam-sharp's own type system** —
  checking happens in the frontend, what reaches the target is erased. They are *not* neutral
  about what the type checker can interoperate with.
- **`from_abstr` lets an out-of-process frontend in any implementation language emit `.abstr`
  text and shell out to `erlc`.** Relevant to the walking skeleton and to the compiler's host
  language, currently fog.
- **Core Erlang's stability is worse than its reputation**: the spec is from 2004 and hosted by
  Uppsala rather than OTP, OTP's own source says the format "can change between releases", the
  spec no longer matches the implementation (maps postdate it), and the Core-to-BEAM backend was
  wholesale replaced at OTP 27.

Ten items are recorded as **not established** rather than guessed, including which OTP release
added `from_abstr`, and any stated rationale for the target chosen by Elixir, Caramel, purerl,
Hamler or Alpaca — only Gleam has one. No secondary sources were used, and one delegated claim
was independently checked and found wrong.

## Notes

AFK. Feeds ticket 13, where the decision is actually made. This ticket establishes facts,
not the choice.

Resolved from a complete research file after the agent hit a session limit before it could
update this ticket; the findings are the agent's, the ticket update is not.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Compilation targets](issues/02-compilation-targets.md) — **three tiers, not a binary.** The
  **Abstract Format expresses multi-clause heads natively** (a function *is* a clause list);
  Core Erlang does not at the head but hands you the primitive one level down, costing a
  mechanical ~50-line wrapper; BEAM bytecode needs a full match compiler. The cliff is between
  Core and bytecode, not between Abstract Format and Core. **Dialyzer is the sharpest
  discriminator and it fails silently**: compiling from `.core` emits an empty abstract chunk
  with no warning, and a `-spec` is lost through that path — which collides directly with
  ticket 06's recommendation to emit specs.
```
