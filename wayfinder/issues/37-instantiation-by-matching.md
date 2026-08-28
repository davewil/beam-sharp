# 37 — "Instantiation is matching, not solving": what is the algorithm?

Type: grilling
Status: **algorithm resolved 2026-08-28** — [ENG-204](https://linear.app/davewil/issue/ENG-204).
Three steps, measured by [`37a`](../prototypes/37a_instantiation_by_matching.escript) over the
real algebra; see [Answer](#answer-2026-08-28). **The ORDERING question is not the algorithm and
stays open for David** — and the corpus moved under it again, see below. Raised 2026-08-14 from
building [F6](../../compiler/features/F6-angle-brackets.md); re-measured 2026-08-26.

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

Twelve days on, at `5fdfdcc`, with F7–F27 landed since. *(Corrected 2026-08-28: this said
`117d850`, which is not the commit the section landed in; Linear's copy said `5fdfdcc` and is
right. One session, two SHAs.)* **Nothing here resolves the ticket.** Three
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

**25d does not parse today**, and its own header says so — it is *"a target for the compiler, not a
passing example."* That is precisely what ticket 25's corpus is for, exemplars the design **must
serve**, so this is evidence about what the language is asked to express and not about what
compiles. It does not weaken the point: the shape is what an alias cannot reach.

That is `Prepend<T, E>(T, result<list<T>, E>) -> result<list<T>, E>`, written out at one
instantiation. **A parametric alias cannot express it.** An alias substitutes ground arguments into a
type; this relates the *first parameter's* type to the *return's element* type, which is a variable
in a signature — exactly §(c). And it needs **no arrow**, so it is not blocked on what the first half
of the cost argument is blocked on.

Swept for company across all 37 exemplar signatures, `Prepend` is the **only** one of its kind.
*(Corrected 2026-08-28 — **this went false 51 minutes after it was written.** The sweep covered
four exemplar directories; `25e` landed at `caa3c52`, 20:37, against this section's `5b56c47` at
19:46 the same evening. See [The corpus moved again](#the-corpus-moved-again-2026-08-28).)* The
two neighbours that look similar — `Rowed(list<WireRow>) -> result<list<OrderRow>, FetchError>` and
`Checked(list<term>) -> result<list<WireRow>, FetchError>` — are traverses, and generalising *those*
does need an arrow. So the corpus **splits** the cost argument rather than overturning it: one
first-order case §(c) alone would serve, and a higher-order library still waiting on arrows.

### What this does to the ordering question — evidence, not an answer

The corpus now answers a *piece* of the closing question with measurement instead of argument: there
is exactly one exemplar case, it is first-order, and it is a private helper inside one module. The
honest reading is that §(c) is **not blocked** on arrows, and **not yet earned** by the corpus at
n = 1. Which of those two facts governs is David's call, and **n = 1 is itself the finding**.
*(Corrected 2026-08-28: n is no longer 1. Two distinct shapes, three occurrences, and the third
one the language **refuses**.)*

## The corpus moved again (2026-08-28)

The section above swept **four** exemplar directories and found `Prepend` alone. There are **five**.
`25e-dynamic-web-page` landed at `caa3c52` (2026-08-26 20:37), fifty-one minutes after this ticket's
last edit at `5b56c47` (19:46). The re-measure could not have seen it and its `n = 1` was true when
written.

A clean count across all five directories, taking a signature to be a `public`/`private` declaration
line carrying no `->`: **54 signatures** (9 / 5 / 9 / 17 / 14). *The earlier "37 across four" is not
re-derivable by this method, which gives 40 for the same four directories — the counting rule
differs, and neither number is load-bearing.*

**`25e` finding 9 is the new datum, and it is stronger than a second sighting.** `escape.bs` and
`rows.bs` each need the same six-token accumulator reversal, differing in one word of the signature:

```csharp
private list<binary> ReverseParts(list<binary> xs, list<binary> acc)
private list<Iodata> ReverseRows(list<Iodata> xs, list<Iodata> acc)
```

A module is a directory compiling to one beam (ticket 13), so `Reverse/2` declared twice is
`error: Reverse/2 is declared more than once` — **measured, in the write-up**. Duplication is not
available. The cost is therefore paid in the *namespace*, in two invented names that "describe
nothing except which clone they are", and it compounds once per further element type.

So the corpus now stands at **two distinct shapes, three occurrences**:

| Shape | Where | Needs an arrow? | Cost of not having §(c) |
|---|---|---|---|
| `Prepend<T, E>(T, result<list<T>, E>) -> result<list<T>, E>` | 25d `rows.bs:38` | no | written at one instantiation |
| `Reverse<T>(list<T>, list<T>) -> list<T>` | 25e `escape.bs`, `rows.bs` | no | **the module refuses the duplicate** |

*Counted as shapes, which is what the `n = 1` claim was about — 25e's own note calls `Reverse` a
"third sighting of 25d's `Prepend`", but they are different shapes, and only the occurrence count is
three.* Neither needs an arrow. The two traverses that would (`Rowed`, `Checked`) are unchanged, so
the split the re-measure identified survives: **one first-order group §(c) alone would serve, and a
higher-order library still waiting on arrows.**

## Answer (2026-08-28)

**Instantiation is three steps, and the third is not the one this ticket expected.** Measured by
[`37a`](../prototypes/37a_instantiation_by_matching.escript) — six measurements, each with a control,
over the real `bs_types` operations. The probe implements the algorithm *in the probe*: there is no
type variable in the algebra (`ty()` has six parts and none is one) and the surface cannot spell a
`<T>` declaration list, so a green run says the algorithm is **expressible on the algebra that
exists**, and says nothing about `bs_check`, which still does not solve for a variable.

> 1. **Solve, least, per occurrence.** A bare variable takes the whole share. Under `list<_>`, take
>    the element type. Under a tuple component, take that component. Inside a **union**, a member's
>    share is the argument **minus the union of every other member's maximal extent** — that member
>    with all its variables set to `term`. Ticket 63 is what makes that subtraction exact.
> 2. **Join across occurrences.** A variable occurring more than once takes the **union** of its
>    per-occurrence solutions.
> 3. **Substitute, then contain.** Two operations — and the diagnostic problem this ticket feared
>    does not arise, for a reason the ticket did not anticipate.

### §1 — where a variable may appear, and how it is recovered

Four positions, and only one of them is a choice. Bare, under a list, and under a tuple component
all *read off* — the recovery is forced and 27 §1's word is accurate. A **union** is the only
position where the equation admits a family, and `37a` M1's control confirms the ambiguity belongs
to that shape and not to the machinery: `list<T>` against `list<int>` has a unique solution, and
`option<T>` against `int | :nothing` has two.

### Uniqueness — **least**, and the reason is the return type, not soundness

This was the ticket's sole surviving doubt after 63, and the honest finding is that **soundness does
not choose**. M1 measured both endpoints computable and *both accepted at site 1*: `T = int` and
`T = int | :nothing` each contain the argument. So the tie-break has to come from somewhere else,
and M2 is where it comes from — `option<T> First<T>(option<T> o)` handed exactly `:nothing`:

* **least** ⟹ the function returns `:nothing`, exactly. The caller learns it could not have
  returned anything else, and a `switch` over the result is exhaustible with one arm.
* **greatest** ⟹ the function returns `term`. Sound, and worth nothing: measured, it admits `int`.

**Least, because it is the only choice that keeps the return type worth having.** *Exactness is not
uniqueness* stands as written; what the re-measure was missing is that uniqueness was never the
thing to want. The interval is real, both ends are sound, and the one that is chosen is chosen on
what it tells the caller.

### §2 — a variable twice **joins**

M5: `T Pick<T>(T, T)` with an `int` and an `atom` gives `T = :a | int`, the call checks, and the
control shows the join collapses rather than widens when both arguments agree. **27 §2 licenses
this and no new rule is needed** — a variable is opaque in clause heads, so the body cannot inspect
what the join widened to, and a union it cannot look inside is exactly a slot for values it carries.

### §3 — "solve then contain": two operations, and the diagnostic worry dissolves

This is where the measurement overturned the expected answer. The hypothesis M4 was written to test
— *containment cannot fail after a solve that found a part*, argued from 27 §5's no-variance, since
the join only widens and widening only widens the substituted parameter — is **false**. Over 781
(template, argument) pairs, **382 counterexamples**.

The reason is worth stating plainly: **a template only interrogates the parts it names.**
`F<T>(list<T>)` handed `list<int> | :nothing` solves `T = int` quite happily, because `list_elem`
reads the list part and simply cannot see the `:nothing`. The solve is not wrong — it is partial by
construction — and the argument's other parts survive untouched into the residual.

What replaces it, measured over the same 781 pairs with **zero disagreements in either direction**,
and with a control (a deliberately wrong extent) that disagrees 314 times so the predicate is known
to be discriminating:

> **Containment fails exactly when some argument escapes its parameter's maximal extent** — the
> parameter's ground skeleton, every variable at `term`.

Three consequences, and together they are the answer to §3:

1. **Solve is total.** It never fails; in the worst case a variable solves to `none`.
2. **Contain fails only on a shape mismatch**, and that mismatch is decidable **before** solving,
   from a skeleton that mentions no variable at all.
3. So **the failure diagnostic never has to say which half failed** — only one half can fail, and it
   is the half `arg_diags/7` already emits a residual for (`bs_check.erl:2117-2119`). The ticket
   feared "two passes over one argument list, and the failure diagnostic must say which of the two
   failed or it is unreadable." It is two passes, and the diagnostic is the one that exists.

### The finding the ticket did not ask for: both prelude aliases are unfailable in a bare-variable position

M6 follows straight from the rule above. If a parameter rejects exactly what escapes its maximal
extent, then a parameter whose extent **is** `term` rejects nothing, whatever the algorithm does:

| Parameter | Rejects nothing |
|---|---|
| `T`, `option<T>`, `result<T, E>` | **yes** |
| `list<T>`, `result<list<T>, E>`, `(T, int)`, `option<int>` | no |

The ticket's §2 worry — that the union answer "makes the variable decorative" — is therefore **true,
precisely, and of a narrower thing than the ticket supposed**: not of the join, but of *a bare
variable as a direct member of a union*. `option<int>` is the control and it is failable, so this
belongs to the **alias shape**, not to the algorithm and not to the union. `option<T> = T | :nothing`
with `T` unbounded simply denotes the top type; a discriminated spelling would not.

**Recorded, not decided.** It is not a defect the algorithm can fix, and it costs nothing today —
`result<list<T>, E>`, which is `Prepend`'s own parameter, is failable, and so is every corpus shape.
Whether the prelude wants a discriminated `option` is a different ticket than this one.

### What §(c) would cost the compiler

Stated so the ordering question below can be answered against a number rather than a feeling.

* **`bs_types` — one addition.** The algorithm uses only `subtract/2`, `union/2`, `is_subtype/2`,
  `list_elem/1`, `list/1`, `tuple/1`, `none/0`, `term/0`, all exported today. **No new `ty()` part
  and no variable node.** The one thing missing is a *tuple-component projection*: `tuple/1` has no
  inverse, and `37a` reads the raw `tuples` part to get one — recorded in the probe as an
  assumption rather than hidden.
* **`bs_check` — three edits, all on paths that already exist.** `resolve/2` (`:878`) currently
  treats `{t_ref, V}` as a user type reference and must learn the signature's own variable list —
  the `{parametric, Params, Body}` treatment `type_env/1` (`:666`) already gives aliases, extended
  to `#fn{}`. `sig/3` (`:574`) stores a resolved `ty()` per parameter and would store a template
  plus its variables, resolved at the call site instead of once per directory. `arg_diags/7`
  (`:2114`) gains solve-and-join ahead of the `subtract`+`is_none` it already does.
* **Grammar — nothing.** F6 already parses `Name<T, U>` in type position, and a signature's `<T>`
  declaration list is the same three tokens. 28's lexer rule keeps `<` comparison outside the closed
  codegen set, and that set is unaffected.
* **Diagnostics — nothing new for failure.** By §3 above the only failure is the existing site-1
  residual. F25's corrected-signature paste (`type_source/1`, `:1164`) already keeps the surface
  alias name, so `option<int>` still prints as `option<int>`.
* **Emitted specs — no obligation.** Prototype `27b` measured it: Erlang's spec grammar accepts
  variables and **Dialyzer does not enforce the relation across them**, reading `A` and `B` as
  `any()`. The control fired, so the negative is real. A polymorphic emitted spec is honest about
  its shape and inert as a check, which is a ticket-06/18 boundary fact and not a cost here.

## The ordering question — David's call

Everything above is the algorithm and it is decided. This is the part that is not.

Today, `25e` is obliged to write this — two copies, and the second name invented only to escape
`error: Reverse/2 is declared more than once`:

```csharp
private list<binary> ReverseParts(list<binary> xs, list<binary> acc)

ReverseParts([], acc)          -> acc
ReverseParts([x, ..rest], acc) -> ReverseParts(rest, [x, ..acc])

private list<Iodata> ReverseRows(list<Iodata> xs, list<Iodata> acc)

ReverseRows([], acc)          -> acc
ReverseRows([x, ..rest], acc) -> ReverseRows(rest, [x, ..acc])
```

§(c) makes it this, and nothing else in the language changes:

```csharp
private list<T> Reverse<T>(list<T> xs, list<T> acc)

Reverse([], acc)          -> acc
Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])
```

**The two facts, and they still point opposite ways.** §(c) is **not blocked** — no arrow, no
lambda, no new algebra part, and the grammar already spells it. And it is **not obviously earned** —
two shapes across five exemplars, both private helpers. What the corpus added since the re-measure
is that the second shape's cost is **not duplication but a refused module**, which is a
language-level workaround and compounds per element type rather than per site.

**Not answered here on purpose.** The re-measure left this to David and nothing measured this
session takes it off him; the corpus moved the evidence and did not settle the call.

## Notes

HITL. **Not urgent, and that is the finding rather than an excuse**: the two things §(c) buys are a
shared container library (27 §1's cost argument) and relating a function's output type to its input.
The first needs arrows and lambdas. **The second was recorded here as something parametric aliases
already cover for the cases the exemplars contain — measured false 2026-08-26**, see *Re-measured*
above; exemplar 25d's `Prepend` is a case they cannot cover, and it needs no arrow.

So the honest ordering question this ticket asks the map is whether §(c) is wanted **before** a
higher-order function type exists, or falls out of the same increment as one. **25d moved this
question without settling it**: the arrow is no longer a precondition for every case, only for the
library. *(2026-08-28: 25e moved it again and still did not settle it — see
[The ordering question](#the-ordering-question--davids-call). The **algorithm** half of this
ticket is now resolved and is no longer HITL; the ordering half still is.)*

**Linear**: [ENG-204](https://linear.app/davewil/issue/ENG-204). Verified against the workspace
before creating rather than derived — ENG-203 was the highest issue in the team, so the offset held
here. The map's instruction is to check every time, because the rule has already broken once.
