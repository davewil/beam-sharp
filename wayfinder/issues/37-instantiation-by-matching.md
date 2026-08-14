# 37 — "Instantiation is matching, not solving": what is the algorithm?

Type: grilling
Status: **open** — raised 2026-08-14 from building
[F6](../../compiler/features/F6-angle-brackets.md)

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

## Notes

HITL. **Not urgent, and that is the finding rather than an excuse**: the two things §(c) buys are a
shared container library (27 §1's cost argument) and relating a function's output type to its input.
The first needs arrows and lambdas, and the second is what parametric *aliases* already do for the
cases the exemplars contain.

So the honest ordering question this ticket asks the map is whether §(c) is wanted **before** a
higher-order function type exists, or falls out of the same increment as one.

**Linear**: [ENG-204](https://linear.app/davewil/issue/ENG-204). Verified against the workspace
before creating rather than derived — ENG-203 was the highest issue in the team, so the offset held
here. The map's instruction is to check every time, because the rule has already broken once.
