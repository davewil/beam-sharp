# 01 — What does a page of idiomatic beam-sharp look like?

Type: prototype
Status: claimed

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

## Interim — not resolved

> **Closed prematurely on 2026-08-11 and reopened.** Variant A was chosen on the evidence of a
> single four-clause function; every substantial example in the first prototype was written in
> Variant B. The clause shape cannot be judged from a toy, and the point of this ticket is a
> long considered look. A second prototype writes a realistic module set entirely in Variant A.
> What follows below stands, except that "settled" now means "chosen, pending reading it at
> length".

Prototype: [`wayfinder/prototypes/01-sample-code.md`](../prototypes/01-sample-code.md), with a
runnable Erlang lowering at [`01_counter_lowering.erl`](../prototypes/01_counter_lowering.erl).
Second pass: [`01b-variant-a-at-length.md`](../prototypes/01b-variant-a-at-length.md).

**Chosen: Variant A — equations under a signature.**

```csharp
Verdict Classify(Reading r);

Classify((:ok, n)) when n > 0 => :positive;
Classify((:ok, 0))            => :zero;
Classify((:ok, _))            => :negative;
Classify((:error, _))         => :unknown;
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

**Left open, and now owned by their own tickets:**

- **Atom literal** — `:atom` versus `#atom`. `:` collides with both the ternary operator and
  the base-type list separator (`module Counter : GenServer`), visible in the prototype itself.
  → [ticket 10](10-atoms-in-a-csharp-skin.md).
- **Guard punctuation** — the prototype's ugliest line is `when amt > 0, amt <= a.Balance`,
  keeping Erlang's `,`/`;` conjunction with its fail-to-false semantics rather than `&&`/`||`.
  → [ticket 08](08-head-and-guard-syntax.md).
- **Doubled parentheses** on single-argument clauses — `Classify((:ok, n))` — afflict Variant A
  as much as B. → [ticket 08](08-head-and-guard-syntax.md).
- No binary patterns appear anywhere in the prototype, deliberately: ticket 04 found binaries
  are *untheorised* in the set-theoretic literature, so inventing syntax would have been
  fiction. → [ticket 20](20-untheorised-term-shapes.md).

## Notes

Leads the frontier deliberately: language-design arguments conducted in the abstract go in
circles; the same argument conducted over a snippet resolves quickly, because everyone can
see what they are objecting to. It also unblocks more tickets than any other.

HITL — the reactions are the deliverable, not the code.
