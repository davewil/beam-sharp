# 17 — Pipeline and comprehension idiom

Type: grilling
Status: open
Blocked by: 01

## Question

What is the idiom for chaining transformations over collections?

Ticket 05 substantially reframed this question, which is why it graduated from fog:

- **LINQ query comprehension is portable.** ECMA-334 §12.22.3.1 makes the query translation
  "a syntactic mapping that occurs before any type binding or overload resolution has been
  performed" — it needs a rule for resolving eleven names (`Where`, `Select`, `SelectMany`,
  `Join`, `GroupBy`, `OrderBy`, and the rest) and nothing else. `IEnumerable<T>` appears only
  in a *note* about what `System.Linq` happens to provide. So `from x in xs where ... select`
  could exist here at no type-system cost.
- **Extension-method chaining is already a pipeline.** The invocation `xs.Where(f)` is a
  static rewrite to `Where(xs, f)` — the same rewrite `xs |> where(f)` performs. They are
  notational variants of one mechanism, not competing designs.
- **Deferred execution is not a language feature** — it belongs to the operator
  implementations, and would become an explicit stream type here.

So decide:

- Does query-comprehension syntax exist in the language, or only the chained form?
- Is the chained form written with `.` (C#-familiar, but reads as method call on an object in
  a language with no objects) or `|>` (BEAM-familiar, honest about being a rewrite)?
- If both a `.` chain and `|>` exist, what distinguishes them, and is having two worth it?
- Does anything lazy exist, or are all collection operations strict with an explicit stream
  type for the cases that need laziness?

## Routed here by ticket 10 — resolved 2026-08-12

Prototype 01g proposed making `if` an **expression** and noted this is a language-wide
statement-versus-expression decision, not an atoms one, routing it to "ticket 08 or 17".
**Ticket 08 is closed, so this ticket owns it.** Two parts, one settled and one open:

- **Settled by ticket 10 §2: `if` requires `bool`, and there is no truthiness.** `if (count)`
  is a type error, not a test against zero. Elixir's truthy/falsy split (only `nil` and `false`
  falsy; `0` and `[]` truthy) forces two operator families — `&&`/`||`/`!` over any term versus
  `and`/`or`/`not` strictly boolean, with `nil and true` raising `BadBooleanError`. Ticket 01's
  `&&`/`||` guard operators already committed this language the other way, and C# has no
  truthiness either, so this costs nothing with the audience.
- **Open, and this ticket's to decide: what does a one-armed `if` evaluate to?** Elixir returns
  `nil` (`if false, do: 1` → `nil`, verified locally). Under ticket 10 §5 the beam-sharp analogue
  would be `option<T>` — i.e. `T | :nothing` — which would mean every `else`-less `if` in
  expression position produces a union the caller must destructure. The alternative is requiring
  `else` whenever an `if` is used as an expression, keeping the type `T`. This interacts with the
  intermediate-value friction 01b raised, which expression-`if` was partly meant to relieve.

## Notes

HITL. Graduated from the map's fog after ticket 05 established the question sharply. Blocked
by 01 because this is exactly the kind of argument the sample code settles fastest.
