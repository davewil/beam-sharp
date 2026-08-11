# 08 — Multi-clause head and guard syntax

Type: grilling
Status: open
Blocked by: 01, 05

## Question

What is the concrete syntax for multiple clauses of one function, and for guards?

**SETTLED by [ticket 01](01-sample-code.md): Variant A — equations under a signature.**

```csharp
Verdict Classify(Reading r);

Classify((:ok, n)) when n > 0 => :positive;
Classify((:ok, 0))            => :zero;
```

Chosen as a design preference. This ticket no longer decides the clause shape; it decides
everything around it, and must **mitigate rather than revisit** the two known costs of Variant A:

- **Signature and clauses can drift apart in a file.** Is contiguity required? Enforced?
- **Repeated declarations read as C# overloads** to the audience this syntax courts — different
  methods dispatched on static type, which is the wrong mental model and the misconception most
  likely to stick. What in the syntax, tooling or error messages prevents it?

Decide:

- **Doubled parentheses.** `Classify((:ok, n))` — the outer pair is the parameter list, the inner
  the tuple pattern. Every single-argument clause looks like this. Accept it, or find a form that
  doesn't?
- **Patterns in parameter position.** How are literal, tuple, map, list and constructor
  patterns written where C# expects `Type name`? What happens to type annotations — are
  they per-clause, or declared once for the function?
- **Guards.** What is the keyword (`when`?), and what expressions may appear? The BEAM
  restricts guards to a small set of guard BIFs with no user function calls — so this is
  constrained by the platform, not just taste.
- **Ordering.** BEAM clauses are tried in order. Does the language preserve
  first-match-wins, and how does that interact with the exhaustiveness checker — does it
  also report redundant, shadowed clauses?
- **Arity.** BEAM identifies functions by name *and* arity. Must every clause of a function
  have the same arity? What becomes of C#'s optional parameters and overloads-by-arity?

- **List patterns.** Ticket 05 flagged that C#'s interior and suffix slice patterns
  (`[first, .., last]`) are not one-pass expressible over cons cells. Decide what subset of
  list patterns survives, and whether a non-one-pass pattern is permitted at a cost.

## Reformulation from prototype 01f — tested against OTP 28

Running the `Orders` lowering ([01f_orders_lowering.erl](../prototypes/01f_orders_lowering.erl))
found two errors in sample code that had only been read, and both change this ticket:

**"Patterns count, guards don't" is the wrong rule.** `{ Status: not :shipped }` cannot be an
Erlang pattern — the BEAM has no negation pattern — and lowers to `when S =/= shipped`. Yet it is
still checkable, because the *type system* computes `Status \ :shipped` as a set difference. The
exhaustiveness credit comes from the type system, not from what codegen emits. The rule is:

> **The checker credits any condition it can translate into a type operation.**
> `not :shipped` → set difference. `n > 1` → interval refinement. `HasSku(lines, sku)` → nothing.

So this ticket's real question is not "guard or pattern" but **which surface conditions have a
type-level meaning** — a far more tractable question, and one shared with ticket 11.

**Friction #1 may be soluble rather than merely survivable.** `when amt >= Total(o)` is illegal
(user function in a guard) and had to be hand-lowered to a clause dispatching to a `pay/3` helper.
**The compiler could perform that hoist automatically** — and Erlang cannot, because it has no
purity guarantee, while beam-sharp does. Costs to weigh: the hoisted call is evaluated even when
an earlier clause would have matched, and a diverging or crashing call changes semantics (which
interacts with ticket 12's totality stance). But this is the first evidence the biggest ergonomic
threat to the design has an answer rather than a workaround.

## Binding constraint from ticket 04 — signatures are not optional

**Exhaustiveness is only well-posed against a declared input type.** Redundancy is *relative*
(clause i against clauses before it); exhaustiveness is *absolute* (the union of clauses
against a domain someone hands you). Elixir cannot check exhaustiveness precisely because it
*builds* the function type as an intersection from the clauses themselves — checking the union
of clause domains against a domain defined as that same union is vacuous. CDuce can check it
only because functions carry a mandatory interface, and it checks once **per arrow** of that
interface.

So this language's headline guarantee **requires a signature on every multi-clause function**.
Inference alone does not weaken the guarantee — it makes the question disappear. This ticket
must therefore decide not only the clause syntax but **where the signature lives**: once above
the clause group, repeated per clause, or somewhere else. That is a language-surface decision,
not a type-theory one, which is why it lands here.

Note the knock-on: an interface may have **several arrows**, and the check runs per arrow. A
syntax that admits only one input type per function forecloses overloading across arrows.

## Prior art to consult first (from ticket 03)

- **Gleam prototyped this and dropped it silently.** An abandoned `examples/clauses.glm`,
  described by lpil as "an experiment to see how we could represent multiple function clauses
  without duplicating the name". No reason was recorded for dropping it. Worth finding and
  reading before designing from scratch — the phrasing suggests the sticking point was
  notational (name duplication), which is exactly this ticket's first decision.
- **Do not accept lpil's "no function overloading results in a much simpler language" as
  evidence about this feature.** It answers a question about same-name-different-arity
  overloading. Multi-clause heads are same name, *same arity*, one signature. Two independent
  searches flagged this conflation; expect to meet it again.
- ~~**purerl's successor backend compiles PureScript equations to native Erlang clause heads.**~~
  **Retracted by ticket 19** — it emits exactly one clause, always, with no guard. Read ticket
  19 instead: it is a **counter-example**, not a precedent, and it carries a guard finding that
  bears directly here. `purescript-backend-erl` emits **no guards at all** (`when` appears zero
  times across all 44 golden files). It carries a hardcoded 36-name whitelist — Erlang's guard
  set minus `is_record` — routing guard-legal conditions into an Erlang `if` and demoting
  everything else to `case Cond of true -> …`. That sidesteps the fail-to-false subtleties
  ticket 02 documents, at the cost of never using a guard. Decide deliberately whether to do
  the same.
- **Alpaca shipped a constructor-pattern-in-head parse ambiguity and never fixed it.** A
  concrete, known grammar hazard sitting exactly where this ticket designs. Find what the
  ambiguity was before choosing a clause syntax, not after.

## Notes

HITL. The headline feature's surface. Depends on ticket 01 for something concrete to react
to, and ticket 05 for what C# syntax is available to borrow.
