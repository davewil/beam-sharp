# 13 — Compilation target decision

Type: grilling
Status: open
Blocked by: 02, 11

## Question

Given the survey in ticket 02 and the type system shape settled in ticket 11: which target
does the compiler emit — **Core Erlang**, the **Erlang Abstract Format**, or **BEAM
bytecode**?

State:

- The choice, and the decisive reason.
- What it costs in expressible semantics — particularly whether multi-clause dispatch is
  inherited from the target or must be synthesised by the frontend, and whether the
  frontend's clause-merging can be made to agree with the exhaustiveness checker.
- What it costs in tooling: stack traces, debugger, dialyzer, hot code loading, crash-report
  legibility.
- The exposure to OTP release churn, and the mitigation.
- Whether the choice is reversible later, and at what cost.

## What ticket 02 established

The survey is done; this ticket only has to choose. The decisive facts:

- **The Abstract Format expresses multi-clause heads natively** — a function form *is* a list
  of `{clause, ANNO, Patterns, Guards, Body}`, and the guard sequence keeps Erlang's full
  list-of-lists disjunction/conjunction structure. The frontend owes nothing.
- **Core Erlang costs a mechanical wrapper**, not a match compiler: one `fun` over fresh vars,
  one `case` over the value list, one clause each, order preserved, plus a synthesised failure
  clause. Perhaps fifty lines. Its `when` is also strictly *wider* than Erlang's.
- **BEAM bytecode costs a full match compiler.** That is the real cliff.
- **Choosing Core Erlang forfeits Erlang-side type publication.** A `-spec` survives the
  Abstract Format path by construction and is lost through `.core`; Dialyzer cannot read a
  `.core`-built beam at all, and fails *silently*. Ticket 06 recommends emitting `-spec`, so
  these two tickets must be decided together — or ticket 06's recommendation withdrawn.
- **Core Erlang is less stable than its reputation**: 2004 spec hosted outside OTP, OTP's own
  source saying the format can change between releases, spec-implementation drift (maps), and a
  wholesale backend replacement at OTP 27.
- **`from_abstr` allows an out-of-process frontend in any language** to emit `.abstr` text and
  shell out to `erlc` — which decouples this decision from the compiler's host language.

Note that Gleam and LFE both route through Core Erlang, so choosing the Abstract Format would
be a departure from the closest precedents. Ticket 02 could not establish a stated rationale
for *any* project's target choice except Gleam's — so precedent here is weak evidence.

## Notes

HITL, but heavily fact-led — most of the work is in ticket 02. Blocked by ticket 11 because
a type system that erases entirely has different target needs than one wanting to emit
type-derived runtime checks at boundaries.
