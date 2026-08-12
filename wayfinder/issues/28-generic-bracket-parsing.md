# 28 — Angle brackets versus less-than: how does the parser disambiguate?

Type: grilling
Status: open
Blocked by: 27 — resolved

## Question

Raised by [ticket 27](27-parametric-polymorphism.md) on 2026-08-12, which listed this among its
own questions and **did not answer it**. 27 settled that the language has real parametric
polymorphism with C#-style angle brackets; this ticket owns the consequence that
`<` and `>` are now overloaded.

The classic problem, and beam-sharp has every ingredient for it:

```csharp
F(a < b, c > d)
```

Two readings. Either two arguments — `a < b` and `c > d`, both comparisons — or one argument,
`a<b, c>` applied to `d`. C++ made this famously painful; C# and TypeScript both ship
disambiguation rules; Rust sidestepped it entirely with turbofish (`::<>`).

**Why it bites harder here than in C#.** Ticket 08 settled `&&`/`||` guards with comparison
operators, so `<` appears in guard position routinely, and guards sit directly against clause
heads where patterns and types are already dense:

```csharp
(x, y) when x < y && Total(x) > 0 -> ...;
```

Decide:

- **The disambiguation rule.** C#'s is specified (ECMA-334): after parsing a candidate type
  argument list, the token that follows decides. Confirm it is expressible for beam-sharp's
  grammar rather than assuming — beam-sharp's declaration syntax is not C#'s, and 27 §4 put
  variables in a *declaration* list on the signature, which C# also has but which beam-sharp
  pairs with a signature carrying types-only and no parameter names (ticket 08).
- **Whether an explicit-instantiation spelling is needed at all.** 27 left open when a call site
  must *write* `Map<Order, Money>(...)` rather than have the arguments determine it. If the
  answer is *never* — because instantiation is always recoverable by matching (27 §1) — then the
  ambiguity only ever arises in *type* positions, which is a much smaller grammar problem, and
  the whole question may shrink. **Establish this first; it may resolve the rest.**
- **Whether the guard sub-grammar is exempt.** Ticket 08 fixed guards to the BEAM guard set with
  no user function calls. If types cannot appear in a guard at all, guards can be parsed with `<`
  unambiguously as comparison, and the problem is confined to signatures and expressions.
- **The tier-3 fallback.** If no borrowed rule fits, a distinct spelling for instantiation
  (Rust's turbofish, or something else) is available — but note the map's amended heuristic:
  resemblance, not reproduction. A divergence needs a reason, not an apology.

## Binding constraints

- **Ticket 27 §4 is settled and not reopenable here.** Variables are declared and named with C#'s
  `T` convention; this ticket decides *parsing*, not spelling.
- **Ticket 08's guard vocabulary is settled** — BEAM guard BIFs, `&&`/`||`, no user function
  calls, expansion rule for named guards.
- **Ticket 08's signature form is settled** — types only, no parameter names; clauses do not
  repeat the function name.
- **The standing constraint applies asymmetrically.** A parser rule an agent must be *prompted*
  about is the expensive kind; a rule that merely costs keystrokes is nearly free.

## Notes

HITL. Small compared to most tickets on this map, and possibly much smaller than it looks — the
second bullet may collapse it. Also carries one loose end 27 recorded and did not place: **the
provisional list-pattern spelling `[h, ..t]`**, which ticket 08 constrains ("prefix-plus-rest
only") but pins no spelling for. It is a grammar question and belongs here unless a later ticket
claims it.
