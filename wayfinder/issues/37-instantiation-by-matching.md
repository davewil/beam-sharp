# 37 — "Instantiation is matching, not solving": what is the algorithm?

Type: grilling
Status: **open** — raised 2026-08-14 from building
[F6](../../compiler/features/F6-angle-brackets.md); **re-measured 2026-08-26** — three of the four
premises verified intact, one measured false and corrected below

## Question

F6 built ticket 27's §(a) and §(b) — parameterised type constructors and parametric aliases. Both
are **substitution with ground arguments**, and the ticket's own line is why that was a clean cut:
*"the costs are asymmetric and they do not chain: declining (c) would have left (a) and (b)
untouched."*

§(c) — a **polymorphic function signature** — is the other side, and it is not substitution. It is
matching, and the phrase everything rests on is stated in three places and specified in none:

> Ticket 27 §1: *"match `list<Order>` against `list<TSource>`, read off `TSource = Order`.
> Structural, cheap, unique answer."*

**Decide the algorithm.** Specifically:

- **Where may a variable appear in a parameter type, and how is it recovered from each position?**
  `list<T>` reads T off the algebra's element type. A bare `T` takes the whole argument type. A
  tuple component takes the component. What about a **union**?

  ```csharp
  int Unwrap<T>(option<T> o, T fallback)
  ```

  `option<T>` is `T | :nothing`, so the checker is handed `int | :nothing` and must solve
  `T | :nothing = int | :nothing`. That is not "read off"; it is **subtraction with an unknown on
  one side**, and 27 §1's three adjectives (*structural, cheap, unique*) are all in doubt for it —
  uniqueness most of all, since `T = int` and `T = int | :nothing` both satisfy it.

  This is not an exotic case. `option<T>` is the prelude's most-used alias, and F6 shipped it.

- **What happens when a variable appears twice?** `T Pick<T>(T, T)` called with an `int` and an
  `atom`: is T their union, or is that a type error? 27 §2 says a variable is *"a slot for values
  you carry"* and the union answer keeps the signature honest — but it also means the call site
  never fails, which makes the variable decorative.

- **Is the check "solve, then contain", or is it one operation?** F5's site 1 is plain containment
  (`type_of(arg) ⊆ param`). With a variable it becomes: solve from every parameter, substitute,
  then contain — two passes over one argument list, and the failure diagnostic must say which of
  the two failed or it is unreadable.

## Binding constraints

- **Ticket 27 §1, §2, §3, §5 and §7 are settled and not reopenable here.** Prenex, opaque in clause
  heads, unbounded, no variance, no row variables. Each is named there as *the thing that keeps
  instantiation a matching problem*, so this ticket works inside them, not against them.
- **Ticket 28 §1's companion rule is settled**: every type variable in a user function's signature
  must appear in at least one **parameter** position. That is what makes recovery possible at all;
  it does not say how.
- **Ticket 04 made signatures mandatory** — inference is not being asked for, and this ticket must
  not drift into it.

## What F6 measured, so it is not re-derived

- **`Map` cannot be written**, and neither can any of 27's other examples that take a function.
  `ty()` has an atom part, an integer part, a tuple part, a list part and a map part — **no arrow
  part** — and there is no lambda in the surface language. So the canonical motivating example for
  §(c) is blocked on something that is not §(c).
- **No exemplar declares a polymorphic function.** Every angle bracket in `examples/exemplars/` is
  a ground application or a `ValidateAs<...>` codegen obligation.
- **The bracket itself is not what was missing.** F6's grammar already parses
  `Name<T, U>` in type position, and a signature's `<T, U>` declaration list is the same three
  tokens. Whatever this ticket decides, it inherits a parser that can spell it.

## Re-measured 2026-08-26

Twelve days on, at `117d850`, with F7–F27 landed since. **Nothing here resolves the ticket.** Three
of F6's four measurements are unchanged, one is now false, and ticket 63 narrows the algorithm
question from three doubts to one.

### Still true — verified against the tree, not carried over

- **`ty()` still has no arrow part.** Its six parts are `atoms`, `ints`, `tuples`, `lists`, `maps`,
  `bins`. The map part arrived with ticket 48 and is not one, so `Map` still cannot be written.
- **There is still no lambda.** `=>` lexes as a switch arm, and the lexer's own header says `=>` is
  *"reserved for lambdas, which this slice does not have"*.
- **No exemplar declares a polymorphic function.** All 37 signatures across the four exemplar
  directories were swept. Every angle bracket is a ground application or a `ValidateAs` obligation,
  and no signature carries a `<T>` declaration list.
- **Nothing in the checker solves for a variable.** `bs_check.erl` names instantiation only in
  comments — 28's bracket rule and 15's failure-member rule. The tree's only `unify/4` is
  `bs_repl.erl`'s, which matches *values* in the REPL. The algorithm is still unwritten rather than
  written badly, so this ticket is stale in its facts and not in its question.

### Ticket 63 collapses two of the three doubts, and sharpens the third

The union bullet above puts all three of 27 §1's adjectives — *structural, cheap, unique* — in doubt
for `T | :nothing = int | :nothing`. Ticket 63 measured, and F27 shipped against, the guard fragment
being **closed under complement**: `bs_types:subtract/2` is exact part by part, and the atom part
carries a `{finite, …} | {cofinite, …}` representation whose complement is a one-line flip.

So **`structural` and `cheap` are no longer in doubt** — the subtraction is a real, total, cheap
operation on the algebra that exists today.

**Uniqueness is the sole survivor, and 63 does not touch it.** Exactness is not uniqueness. `T = int`
and `T = int | :nothing` both still satisfy the equation; an exact subtraction yields the *smallest*
solution without establishing that smallest is *intended*. That is a materially narrower question
than the one this ticket was raised with — not *"is matching well-defined over a union"* but
**"when a union admits a family of solutions, does the algorithm take the least, and is least
right?"**

### Now false — the claim that parametric aliases already cover §(c)'s second use

Exemplar **25d** landed 2026-08-24, ten days after this ticket was written. Its `rows.bs` contains:

```csharp
private result<list<OrderRow>, FetchError> Prepend(OrderRow row, result<list<OrderRow>, FetchError> rest)

Prepend(row, (:error, e)) -> (:error, e)
Prepend(row, rows)        -> [row, ..rows]
```

That is `Prepend<T, E>(T, result<list<T>, E>) -> result<list<T>, E>`, written out at one
instantiation. **A parametric alias cannot express it.** An alias substitutes ground arguments into a
type; this relates the *first parameter's* type to the *return's element* type, which is a variable
in a signature — exactly §(c). And it needs **no arrow**, so it is not blocked on what the first half
of the cost argument is blocked on.

Swept for company across all 37 exemplar signatures, `Prepend` is the **only** one of its kind. The
two neighbours that look similar — `Rowed(list<WireRow>) -> result<list<OrderRow>, FetchError>` and
`Checked(list<term>) -> result<list<WireRow>, FetchError>` — are traverses, and generalising *those*
does need an arrow. So the corpus **splits** the cost argument rather than overturning it: one
first-order case §(c) alone would serve, and a higher-order library still waiting on arrows.

### What this does to the ordering question — evidence, not an answer

The corpus now answers a *piece* of the closing question with measurement instead of argument: there
is exactly one exemplar case, it is first-order, and it is a private helper inside one module. The
honest reading is that §(c) is **not blocked** on arrows, and **not yet earned** by the corpus at
n = 1. Which of those two facts governs is David's call, and **n = 1 is itself the finding**.

## Notes

HITL. **Not urgent, and that is the finding rather than an excuse**: the two things §(c) buys are a
shared container library (27 §1's cost argument) and relating a function's output type to its input.
The first needs arrows and lambdas. **The second was recorded here as something parametric aliases
already cover for the cases the exemplars contain — measured false 2026-08-26**, see *Re-measured*
above; exemplar 25d's `Prepend` is a case they cannot cover, and it needs no arrow.

So the honest ordering question this ticket asks the map is whether §(c) is wanted **before** a
higher-order function type exists, or falls out of the same increment as one. **25d moved this
question without settling it**: the arrow is no longer a precondition for every case, only for the
library.

**Linear**: [ENG-204](https://linear.app/davewil/issue/ENG-204). Verified against the workspace
before creating rather than derived — ENG-203 was the highest issue in the team, so the offset held
here. The map's instruction is to check every time, because the rule has already broken once.
