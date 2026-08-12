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

## Constraints from ticket 27 — resolved 2026-08-12

**A measurement was made for another ticket that sizes this one.**

[`prototypes/27a`](../prototypes/27a_comprehension_vs_hof_typing.erl), OTP 28.5, `typer` against a
PLT of erts/kernel/stdlib:

```
-spec via_comprehension([number()]) -> [number()].          % syntax: relation preserved
-spec roundtrip([integer()]) -> [binary()].                 % a -> b, precise on BOTH sides
-spec via_lists_map([any()]) -> [number()].                 % inline fun: input element type LOST
-spec via_fun_arg([any()], fun((_) -> any())) -> [any()].   % opaque fun arg: everything collapses
```

**A comprehension relates output element type to input element type exactly, under an analysis with
no parametric polymorphism whatsoever.** The relation survives because the comprehension is *syntax
the analyser sees through* — the typing rule is written by the compiler rather than solved for.
Route the identical computation through an opaque fun argument and every element type degrades to
`any()`.

Ticket 27 chose real parametric polymorphism, so this is **not** the mechanism the language depends
on for `Map`. What it means here:

1. **The comprehension's typing rule is beam-sharp's to write, and it should be at least this
   precise.** The measurement is a lower bound on what is achievable, established on the target.
2. **It covers map and filter cleanly. It does not cover fold** — there is no comprehension syntax
   for `foldl`, and 27 did not create one. Whether the pipeline idiom this ticket designs should
   reach fold, and how, is now a live question rather than a stylistic one.
3. **It is the reason ticket 27 declined row polymorphism** (§7), via the parallel argument that
   record update is `with`/spread and therefore also syntax. So the general principle —
   *compiler-visible syntax recovers type relations that a function signature would need a variable
   for* — is now load-bearing in two places, and this ticket is where it gets designed rather than
   merely relied upon.

## Constraints from ticket 15 — resolved 2026-08-12

**This ticket now owns the sequencing construct for fallible steps, and inherits two constraints.**

Ticket 15 settled the error model as `result<T, E> = T | (:error, E)` and found that pipelines of
fallible steps cost a named helper function per stage. It deliberately did **not** spell the
sequencing construct, because 15 owns the error *model* and this ticket owns the sequencing
*idiom* — and the two must match.

- **`with` is unavailable.** Elixir's sequencing construct is `with`; C#'s `with` is record update,
  which ticket 26 owns and ticket 05 found becomes *more* central here than in C#, since there is
  no mutation at all. Do not reach for it.
- **LINQ query syntax is the leading candidate.** Ticket 05 established the query translation is a
  pure syntactic rewrite bound before type binding, needing a rule for eleven names and no
  `IEnumerable<T>` — which is exactly why C# programmers already use query syntax as do-notation
  over non-collection types. **It costs nothing new if this ticket adopts LINQ for collections
  anyway, and is expensive if this ticket chooses `|>` chaining and the construct then exists
  solely for error sequencing.** That conditional is the decision this ticket must make with both
  cases in view.

Recorded and not chosen: a **`?` postfix operator**, Rust's spelling. Smallest thing that removes
the tax and independent of whatever this ticket picks for collections — but it introduces early
return into a language otherwise built entirely from total clauses, putting a hidden exit in the
middle of an expression.

## Constraint from ticket 16 — 2026-08-12

**This ticket inherits nothing new, and that is the finding.**
[Ticket 16](16-ad-hoc-polymorphism.md) §6 established that C#'s extension methods were
miscategorised by ticket 05 as an ad-hoc polymorphism mechanism. They are not. Their call-syntax
half — `xs.Where(f)` reading left to right — has belonged to this ticket all along.

The constraint that comes with it: **whatever this ticket picks for `.` versus `|>`, it is a
static rewrite with no dispatch in it.** Ticket 16 settled that the language has exactly one
dispatch mechanism, the clause head; the dot is not a second one and must not be read as one. A
`.` that resolved by looking at the receiver's runtime shape would be reintroducing the protocol
dispatch ticket 16 refused.

Also relevant to the LINQ conditional in the section above: ticket 16 §4 makes serialisation a
**codegen obligation** with a language-published mapping, so a JSON-shaped pipeline stage is
generated rather than chained. That removes one motivating case for adopting LINQ query syntax as
do-notation, without settling the conditional either way.
