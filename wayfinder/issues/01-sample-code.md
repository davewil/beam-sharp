# 01 — What does a page of idiomatic beam-sharp look like?

Type: prototype
Status: resolved

## Question

Produce a page of idiomatic sample code in the imagined language — a concrete artifact to
react to, explicitly **not** a committed syntax.

It should exercise, at minimum:

- a function with several clauses, dispatching on literal patterns
- destructuring in the argument position: tuples, maps, and whatever stands in for records
- at least one guard
- a union declaration and a function that dispatches over its cases
- one OTP callback set in the `handle_call` / `handle_info` shape, since that is the
  feature's best showcase
- a value crossing the Erlang interop boundary

Write it to `wayfinder/prototypes/01-sample-code.md` and link it here. Where a choice is
genuinely open, show two variants side by side rather than picking silently.

The resolution should record which choices felt right, which felt wrong, and — most
valuable — which arguments the concrete code settled that prose was circling.

## Answer

> **Closed prematurely on 2026-08-11 and reopened**, because Variant A had been chosen on the
> evidence of a single four-clause function while every substantial example was written in
> Variant B. Six further prototypes followed — Variant A at length, module-as-focus,
> source-versus-real sub-modules measured on OTP 28, OTP callbacks under directory-as-module,
> and the closing syntax questions. **Resolved properly 2026-08-12**, after
> [ticket 08](08-head-and-guard-syntax.md) settled the three items handed to it.

**Seven prototypes**, two of them executable: `01-sample-code.md`, `01b-variant-a-at-length.md`,
`01c-module-as-focus.md`, `01d-submodule-realisation.md`, `01e-otp-under-directory-module.md`,
`01g-closing-the-syntax.md`, plus the runnable `01_counter_lowering.erl` and
`01f_orders_lowering.erl`.

**What the ticket settled**: Variant A · module-as-focus · directory-as-module · source-only
sub-modules · `->` for clauses and `=>` for lambdas · `&&`/`||` guards · `:atom` · expression-`if`.
Everything else went to ticket 08, which has since closed it.

**Two things the prototypes overturned that prose had not**: multi-clause heads are notationally
rather than semantically distinct from Gleam's multi-subject `case`, and running the lowerings
found two errors in sample code that had only been read.

Prototype: [`wayfinder/prototypes/01-sample-code.md`](../prototypes/01-sample-code.md), with a
runnable Erlang lowering at [`01_counter_lowering.erl`](../prototypes/01_counter_lowering.erl).
Second pass: [`01b-variant-a-at-length.md`](../prototypes/01b-variant-a-at-length.md).

**Chosen: Variant A — equations under a signature.**

```csharp
Verdict Classify(Reading r)

Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, _))            -> :negative
Classify((:error, _))         -> :unknown
```

Chosen over the clause-block form as closest to the intended language. The arguments I raised
for the block form — that signature and clauses can drift apart, and that repeated declarations
read as C# overloads — are **not** sufficient to override the preference; they become problems
for ticket 08 to mitigate within Variant A, not reasons to abandon it.

**The design is smaller than expected, and this is the prototype's most useful finding.** C#
already supplies every pattern form required: `{ Balance: 0 }` is a property pattern, `(:ok, n)`
a positional pattern, `when` the guard keyword, `=>` the expression-bodied member, `with` the
copy-update. The language is one structural move — **take C#'s pattern grammar out of `switch`
arms, put it in the parameter position, and allow N declarations where C# allows one.** The
design risk therefore sits almost entirely in the type system, which is where the research
already put it.

**The showcase runs.** The hand-written Erlang lowering compiles and executes on OTP 28
(`erts-16.4`): five beam-sharp clauses produce **five native Erlang clause heads** in the
compiled beam's `abstract_code` chunk, order and guards intact, guard correctly falling through
on a negative argument. No `-behaviour` attribute, and it still runs as a `gen_server` —
ticket 06's finding exercised rather than cited. Unexpected mailbox traffic is logged and the
process survives, so the `Known | dynamic` signature describes real behaviour.

**It also broke a locked decision.** Variant B made visible that multi-clause heads are
*notationally* rather than *semantically* distinct from Gleam's multi-subject `case`, and
ticket 02's mechanical Core Erlang rewrite proves the equivalence. The differentiator in
[ticket 00](00-charting-decisions.md) has been amended to a stated design preference; see the
amendment there, and do not re-derive it.

**Handed on, and now all closed except the last:**

- ~~**Atom literal**~~ — `:atom`, after both objections against it failed: no BEAM language has a
  ternary, and `{ Status: :draft }` is exactly what Elixir writes as `%{status: :draft}`.
  → [ticket 10](10-atoms-in-a-csharp-skin.md), settled.
- ~~**Guard punctuation**~~ — `&&`/`||`, because a guard over typed values cannot fail, which is
  the only thing fail-to-false exists to handle. → [ticket 08](08-head-and-guard-syntax.md), settled.
- ~~**Doubled parentheses** on single-argument clauses~~ — closed by choosing `->` for clauses;
  `(0) -> 0;` cannot be read as a lambda. → [ticket 08](08-head-and-guard-syntax.md), settled.
- **No binary patterns appear anywhere in the prototypes**, deliberately: ticket 04 found binaries
  are *untheorised* in the set-theoretic literature, so inventing syntax would have been fiction.
  **Still the largest gap in the design.** → [ticket 20](20-untheorised-term-shapes.md).

## Notes

Leads the frontier deliberately: language-design arguments conducted in the abstract go in
circles; the same argument conducted over a snippet resolves quickly, because everyone can
see what they are objecting to. It also unblocks more tickets than any other.

HITL — the reactions are the deliverable, not the code.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [A page of idiomatic beam-sharp](issues/01-sample-code.md) — **Variant A settled**: equations
  under a signature. The design is smaller than expected — **C# already supplies every pattern
  form needed**, so the language is one structural move: C#'s pattern grammar out of `switch`
  arms and into the parameter position, N declarations where C# allows one. The showcase was
  lowered to Erlang and **run on OTP 28**: five clauses in, five native clause heads out.
  **It also amended ticket 00** — multi-clause heads are notationally, not semantically,
  distinct from Gleam's multi-subject `case`; the differentiator is now a stated design
  preference. Do not re-derive this.
```
