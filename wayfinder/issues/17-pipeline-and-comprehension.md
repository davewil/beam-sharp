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

## Notes

HITL. Graduated from the map's fog after ticket 05 established the question sharply. Blocked
by 01 because this is exactly the kind of argument the sample code settles fastest.
