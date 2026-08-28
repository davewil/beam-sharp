# 17 — Pipeline and comprehension idiom

Type: grilling
Status: resolved 2026-08-13
Blocked by: 01 — resolved

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

---

# Answer — resolved 2026-08-13

**The pipe is the only chaining form, it carries qualified names, and every other question this
ticket held turned out to be a lowering decision or a construct to delete.** Four things were
removed from the language here — dot-chaining, comprehension syntax, `if`, and `else` — and one
was added: a short-circuiting pipe called **the valve**. The ticket's own stated conditional was
answered by rejecting its premise.

## 1. The chaining form is `|>` with qualified names — and the dot fell to a mechanism, not to taste

```csharp
list<binary> Labels(list<Order> os) =>
    os |> List.Filter(o => o.Status == :open)
       |> List.Map(o => Format(o))
       |> List.Reverse();
```

Ticket 05 recorded that `xs.Where(f)` and `xs |> where(f)` are "the same rewrite", and ticket 16 §6
handed the call-syntax half of extension methods here. **Both were true and both concealed the
cost.** The rewrite target in `xs.Filter(f)` is an *unqualified* name, so the compiler must pick
`List.Filter` because `xs : list<T>`. That is **type-directed name resolution**, and this map has
closed both routes to it:

- **Ticket 08** settled one arrow per arity with union parameters *instead of* overload signatures,
  so there is no overload set to resolve against.
- **Ticket 16** settled exactly one dispatch mechanism, the clause head, and a `.` reading the
  receiver's shape is the protocol dispatch it refused.
- **Ticket 16 §6 had already parked this exact thing in the fog** — "C# lets you put a function in
  another namespace so it appears on that type without an import… it is name resolution, not
  polymorphism, and it has no beam-sharp answer."

The failure case is not hypothetical. Add the lazy `stream<T>` §5 defers and the expression is
ambiguous with no rule to break the tie:

```csharp
xs.Filter(p)      // list<T> → List.Filter?  stream<T> → Stream.Filter?  the static type is the only clue
xs |> List.Filter(p)   // no question is asked
```

**LINQ query syntax falls to the identical argument, which is what makes the ticket's stated
conditional unanswerable as posed.** ECMA-334's translation is indeed a pure syntactic rewrite bound
before type binding — and it emits `xs.Where(…)`, unqualified. Ticket 05's "no type-system cost" was
correct and beside the point: the cost was never in the type system, it is in name resolution, and
LINQ pays exactly what the dot pays. So the conditional's premise — *"costs nothing new if 17 adopts
LINQ for collections anyway"* — is false, and the branch it guarded never opens.

**This is the borrow heuristic's tier-1 test failing on semantics rather than syntax**, which is the
failure mode the heuristic exists to catch. LINQ is cheap *in C#* because extension methods and
overload resolution are already there; the query rewrite is a borrow on top of machinery this
language deleted twice over. The borrow arrives with its foundation missing.

The pipe rewrite is `x |> F(a)` → `F(x, a)`, and it needs nothing. Note it also **never passes a
function as a value** — the stage is written in call form — so this ticket incurs no obligation to
spell "the function `F` as a value". Ticket 01's observation that `Orders.Apply(o, e)` and
`o |> Orders.Apply(e)` are one rewrite survives; the third spelling, `o.Apply(e)`, does not.

**The dot is not abolished, it is narrowed**: `o.Total` as *projection* remains
[ticket 26](26-data-modelling.md)'s to decide. What is settled here is that the dot is **never a
call**. Nothing is dispatched by writing one.

## 2. There is no comprehension syntax. Precision is a lowering decision — measured

[`prototypes/17a`](../prototypes/17a_lowering_recovers_the_relation.erl), OTP 28, `typer` against a
PLT of erts/kernel/stdlib:

```
-spec roundtrip_lowered_to_comprehension([integer()]) -> [binary()].    % exact, both sides
-spec roundtrip_lowered_to_generic_call([any()])      -> [any()].       % everything gone
-spec filter_lowered_to_comprehension([any()])        -> [pos_integer()].
-spec chain_lowered_to_comprehension([any()])         -> [binary()].    % survives composition
-spec chain_lowered_to_fused_comprehension([any()])   -> [binary()].    % survives fusion
```

**The surface form and the emitted form are independent.** Ticket 27's prototype 27a established
that a comprehension preserves the element-type relation exactly under an analysis with no type
variables; 27 then chose real polymorphism, which left this ticket looking as though it had to buy
comprehensions at the surface to keep the precision. It does not. The compiler gets 27a's result by
**lowering `List.Map` to an inlined comprehension** rather than to a call.

So the rule is one line, and it belongs in the spec:

> **The compiler-known prelude is inlined; user code is called. Precision follows the inlining.**

Three things the measurement supplied that were not asked for:

1. **The generic call loses more than `lists:map/2` does.** 27a's `via_lists_map` kept the *result*
   element type because the inline fun's body stayed visible; here it does not, because beam-sharp's
   own `list_map/2` carries a **declared** spec — ticket 27 §6's widened emission — and a contract
   overrides success typing of the body. Emitting a generic call is strictly worse than calling
   Erlang's own.
2. **The lowering is more precise than the surface signature can be.** `filter` returns
   `[pos_integer()]`, narrowed out of the guards, where `List.Filter<T>(list<T>, fn(T) -> bool) ->
   list<T>` can only say `list<T>`. The emitted code knows a fact the language's own type system
   discards.
3. **Fusion is free.** The two-stage pipeline fused into a single comprehension yields the identical
   spec while building no intermediate list. Deforestation costs no precision — which is what
   removes the performance argument for laziness in §5.

**The limit is the interesting part, and ticket 18 inherits it.** Precision is a privilege of
whatever the compiler chooses to inline. A user-written `MyLib.Transform<T, U>` emits `[any()] ->
[any()]` no matter what, because the mechanism is inlining, not analysis. The language therefore has
a **two-tier emitted boundary**, and the spec must say so rather than let it be discovered.

## 3. Fold is not a second tier — 27a's limit was Erlang's syntax, not a limit on precision

27a recorded that the syntax route "covers map and filter cleanly. It does not cover fold." That
framing sized this ticket's fold question as a real one. It is not.
[`prototypes/17b`](../prototypes/17b_what_fold_costs.erl):

```
-spec sum_via_inlined_recursion([number()])   -> number().     % both sides kept
-spec sum_via_foldl([any()])                  -> number().     % input element lost
-spec sum_via_generic_fold([any()])           -> any().        % everything lost

-spec join_via_inlined_recursion([integer()]) -> bitstring().  % both sides kept
-spec join_via_generic_fold([any()])          -> any().
```

An inlined monomorphic recursive function recovers the relation on both sides for the
type-changing case, exactly parallel to §2's `[integer()] -> [binary()]`. **So the mechanism was
never "comprehension" — it is inlining a monomorphic body the analyser can see through**, and a
comprehension is merely the shortest spelling of that for map and filter. One lowering rule covers
map, filter and fold alike, which is a simpler rule than this ticket expected to write, and it
means the pipeline idiom reaches fold with no special case.

**Honest caveat, and it lands on ticket 20's pile.** Inlined recursion is more precise on the input
side but *less* on the output side in the binary case: `bitstring()` where `lists:foldl` gave
`binary()`, because the accumulator widens at the recursive fixpoint. It widens specifically at a
**binary** — the shape ticket 20 records as untheorised and ticket 25 puts three of six ordinary
workloads on. Not a reason to prefer `foldl`: losing the input element type is the worse loss, and
`bitstring()` is a sound supertype rather than a wrong answer.

## 4. Fallible sequencing is the valve, `|?>`

Ticket 15 handed this ticket the sequencing construct and found the tax: pipelines of fallible steps
cost a named helper per stage. The construct that removes it:

```csharp
result<Valid, Error> Validate(Request r);
result<Stock, Error> CheckStock(Valid v);          // signature stays honest: it takes a Valid
result<Order, Error> Charge(Stock s);

result<Order, Error> Place(Request r) =>
    Validate(r) |?> CheckStock() |?> Charge() |?> Confirm();
```

Failure case: `Validate` yields `(:error, :bad_request)`; nothing downstream runs; `Place` returns
that error unchanged. The escape hatch is the operator's **absence** — write `|>` and handle
`(:error, _)` in your own clause when a stage wants to inspect the failure.

**Three candidates were live and the winner was chosen on cost of mechanism, not on looks.**

- **`Result.Then` in the ordinary pipe** (Elm's `andThen`, Gleam's `result.try`) was rejected: it
  reads noisily at length — Gleam added `use` precisely because `result.try` chains wear — and it
  is the only candidate that forces this ticket to spell "function as a value".
- **The error-propagating clause written by hand** was rejected on review cost. It reads best of the
  three at the call site, and ticket 15's *untagged* `result` makes it better than it looks (a
  caller holding a plain `Valid` still type-checks, since `Valid` is a member of
  `result<Valid, Error>`), and exhaustiveness *forces* the clause to exist. But it is byte-identical
  boilerplate in every fallible function, and a reviewer reads two lines that have nothing to do
  with the function they are reviewing. Write cost is near-free here; read cost is not.
- **That boilerplate can be generated** — the clause is fully determined by the signature, so
  `[Propagates]` on the declaration is textbook ticket 16 §1. Rejected: it would be the language's
  **sixth codegen obligation**, after `ParseAtom<T>`, `ToExistingAtom`, `ValidateAs<T>`, ticket 15's
  foreign wrapper and ticket 16's serialisation encoder — every one of which owes the walking
  skeleton an unmeasured cost. It also widens the declared arrow to
  `result<Valid, Error> -> result<Stock, Error>`, so the signature again describes the function's
  pipeline position rather than the function; and it moves the short-circuit *out of* the code the
  reviewer is reading. **The valve costs one operator token and zero codegen obligations.**

**A fully implicit rule was closed by precedent, not by taste.** "If a `result<T, E>` meets a
parameter of type `T`, propagate" is inferred narrowing at a call site, and ticket 08 settled that
narrowing is **always written, never inferred** — *neither audience expects implicit cast
insertion*. So the marker is mandatory; the only question was where it sits, and the call site wins
because that is where the reader needs it.

**On the spelling.** `?` is free: prototype 01g and ticket 10 accepted losing C#'s ternary as the
price of `:atom`, and *no BEAM language has one*. The `?` is not decoration — C#'s null-conditional
`a?.B()` and TypeScript's optional chaining are the **same semantics**: if the left is the absent
case, the rest of the chain does not run and that case is the result. ~~Ticket 15's untagged
`result` makes `(:error, E)` the exact analogue of `null`.~~ **Overruled 2026-08-28 by
[ticket 49](49-what-the-valve-keys-on.md): `:nothing` is null's analogue, not `(:error, E)`.** What
this sentence got right is the *chain's silhouette* — the success side is bare, so a plain `Valid`
flows where a nullable `T?` would. What it got wrong is null itself: null is absence carrying no
information, which is [15](15-error-model.md) §2's own definition of `:nothing`, and a
`(:error, E)` carries a reason. The valve now keys on the fixed pair `(:error, _) | :nothing`, which
is the closer borrow. This is a **tier-1 borrow for both halves of the audience simultaneously**,
which is rare in this map. `|?>` keeps the `|>` silhouette intact with
the `?` inside it, so it reads as a variant of the pipe rather than a new token; `?|>` was the more
literal transcription of `?.` and was declined for splitting the pipe's shape. `?>` was rejected for
dropping the `|` and adding another `>` to a language where [ticket 28](28-generic-bracket-parsing.md)
is already open on `>` being overloaded — the valve adds no bracket ambiguity.

**It is called the valve** (David): a valve is a thing in a pipe that stops the flow, the metaphor
is already the language's own, and `|?>` looks like one.

**The pipeline is a family, and Elixir says so** (David): `|>` ships alongside `tap/2` and `then/2`,
so a companion operator is the neighbourhood's own habit rather than an oddity. It also means a
`tap` equivalent costs nothing here — `xs |> Debug.Tap(f)` is an ordinary prelude function in the
ordinary pipe, no new machinery.

## 5. Strict only. Laziness is deferred, and its requirements are recorded

Ticket 05 settled the language-level half: deferred execution "is not a language feature — it
belongs to the operator implementations, and becomes an explicit stream type here." §2's fusion
measurement settles the motivation: the classic performance argument for laziness — do not build the
intermediate list — is already answered by the lowering, at no cost in precision.

**Nothing is lazy. `stream<T>` is deferred, not refused** (David: *"defer lazy, we will want it"*).
What the deferred option needs, so it is not lost:

- **Compiler-known status in the prelude's second stratum**, with a fused lowering of its own.
  Without it, `xs |> Stream.Map(f)` is a user-level generic call and degrades to `[any()]` per §2's
  two-tier rule — the stream would work and be slow to reason about, which is the worst outcome.
- **An answer to how a lazy source meets ticket 14's process model.** A stream over a mailbox or a
  socket is a *process*, not a data structure, and the two have different failure semantics.
- **A position on early termination**, which is the one case fusion does not cover: `|> List.First()`
  after a map over a million rows still traverses a million rows.

**Adding it stays cheap because of §1.** Qualified names mean `Stream.Map` is a new module and
nothing existing changes. Had the dot won, adding a second collection type later would have meant
revisiting name resolution across both — so §1 bought this reversibility, and that is the second
time this map has taken the reversible branch deliberately (cf. ticket 11's refusal of contract
wrapping, ticket 14's wide behaviour contract).

## 6. There is no `if`. `switch` is the only branching construct

Routed here by ticket 10 via prototype 01g, which made `if` an expression and left the one-armed
case open. **The question is answered by deleting the construct.**

```csharp
int Discount(Order o) =>
    o switch {
        { Total: > 100, Status: :open } => 10,
        { Status: :frozen }             => 0,
        _                               => 5
    };

// the subject-less ladder — a tuple subject, which is tier-1 C# and Gleam's multi-subject case
(user.IsAdmin, o.Total > 100) switch {
    (true, true) => :priority,
    (_,    true) => :large,
    _            => :normal
}
```

C#'s switch expression is the **same pattern grammar** ticket 01 moved into the parameter position,
now reused in expression position — so it inherits the language's whole story for free: ticket 12
makes its exhaustiveness a hard error rather than C#'s warning, and ticket 04 makes the residual the
missing arm. It also answers 01b's intermediate-value friction, which is what made 01g reach for
expression-`if` in the first place: you can branch on an intermediate without inventing a parameter
to dispatch on. Spelling is C#'s postfix `o switch { … }`.

**The neighbourhood was measured, not cited** —
[`prototypes/17c`](../prototypes/17c_else_in_the_neighbourhood.md), Gleam 1.18.1 and Elixir 1.19.5:

- **Gleam has no `if` at all**, and its syntax error is written for this case specifically:
  *"Gleam doesn't have if expressions… you can use a `case`"*. A deliberate refusal with a designed
  diagnostic. Since there is no `if`, there is **no `else` anywhere in Gleam**.
- **Gleam's ladder is a multi-subject `case`** — `case admin, total > 100 { True, True -> … }` —
  which is the shape beam-sharp's clause heads already have, and which C# spells natively as a
  tuple pattern. That convergence is why no companion construct is needed.
- **Gleam's non-exhaustive `case` names the missing pattern**: *"The missing patterns are: False"*.
  Ticket 04's residual finding, observed live in a shipping BEAM compiler. → ticket 23.
- **In Elixir, `else` belongs to `if` and nothing else.** `cond`'s catch-all is `true ->`, a
  pattern-shaped clause; both `case` and `cond` **reject `else` outright** — `unexpected option
  :else`. A one-armed `if` returns `nil`, confirming what ticket 10 routed here.

**The structural reading, which is what decided it:** `else` is what a language needs when its
conditional is **binary and unnamed**. A pattern construct never needs one, because its fall-through
is just another pattern and `_` carries no special status. So keeping `if`/`else` would not merely
have added a keyword — it would have added the **only** construct in the language whose fall-through
case is not expressible as a pattern, in a language whose entire thesis is that patterns and
exhaustiveness are the mechanism.

**One branching construct, the way Go has one looping construct** (David). `switch` subsumes `if`,
`else`, `else if`, `cond`, `case` and the ternary the language already dropped.

**Two questions die with `if`.** The one-armed case has no spelling to have semantics. And ticket
15's `option<T>` collapse landmine never fires: had the one-armed `if` yielded `option<T>`, then
`if (ready) { :ok }` would have produced `atom | :nothing`, which ticket 15 §1 makes an **error at
the declaration** — a compile failure reported against a union the programmer never wrote, under one
of the most ordinary shapes in the language.

**`cond` is deferred, and what it would need is one keyword and a reason.** The residual cost of
switch-only is a ladder of *many* unrelated conditions: five independent booleans means a five-tuple
subject, and `(a, b, c, d, e) switch` is clumsy to read even with `_` handling the tail.
[Ticket 25](25-exemplar-programs.md) should report whether that shape occurs in the six exemplars
before a keyword is paid for it. Adding `cond` later is purely additive.

## 7. Consequences forced elsewhere

- **[Ticket 18](18-boundary-defence.md) gains a repair and its limit.** Ticket 27 §6 found that
  choosing generics made the emitted boundary strictly weaker and handed that to 18. §2 is the
  repair — but partial: precision is a privilege of whatever the compiler inlines, so user-written
  generics stay at `[any()]`. 18 now argues over a **two-tier** emitted boundary rather than a
  uniform one. The valve is also new surface for 18: a `|?>` chain emits a `case` per stage, and
  what a foreign caller can put into it is 18's question.
- **[Ticket 20](20-untheorised-term-shapes.md) gains a third binary datum.** §3's `bitstring()`
  widening at a recursive fixpoint is precision lost at a binary, joining 20's existing gap and
  ticket 16 §4's untested serialisation presumption for the same shapes.
- **[Ticket 23](23-what-the-language-owes-an-agent.md) gains live evidence**, not a citation:
  Gleam prints the missing pattern today (17c §3). 23's question narrows from *"could a compiler do
  this"* to *"should the residual be a machine-readable output as well as prose"*.
- **[Ticket 25](25-exemplar-programs.md) inherits two jobs**: whether a `cond`-shaped ladder occurs
  (§6), and whether the pipe reads well in the three binary-heavy exemplars, since §3 is where the
  lowering is least precise.
- **[Ticket 26](26-data-modelling.md) keeps `with` free** — this ticket never needed it — and now
  owns the *whole* of the dot: §1 settles that the dot is never a call, so 26 decides only whether
  it projects.
- **[Ticket 27](27-parametric-polymorphism.md)'s prototype 27a is corrected.** Its "covers map and
  filter cleanly, does not cover fold" reading was about Erlang's available syntax, not about a
  limit on achievable precision (§3).
- **[Ticket 28](28-generic-bracket-parsing.md) is unaffected.** The valve introduces no `>` and no
  new ambiguity; the absence of a ternary keeps `?` unambiguous.
- **The prelude-stratum fog gains a third candidate criterion.** What distinguishes stratum 2 is
  still open — ticket 27 offered "requires a ground type argument" (failed on 15's `foreign_error`),
  ticket 15 offered "what the compiler draws inferences from" (survives). This ticket adds **"what
  the compiler inlines"**, which is sharper than it looks: it is the property that actually produces
  the two-tier emitted boundary in §2, and it is observable in the output rather than being a claim
  about the compiler's intent.
- **The walking skeleton owes one more measurement.** Inlining every prelude collection op at every
  call site is a **code-size** cost that nothing here measured. §2 traded emitted size for emitted
  precision and did not price the trade; the skeleton should, at the clause and pipeline lengths the
  showcase implies.
- **Prototypes 01, 01b and 01g are now partly wrong and must be rewritten.** The showcase uses
  dot-chaining (`xs.Filter(f).Map(f)`, 01-sample-code §4), 01b §6 presents the three-spelling
  equivalence including `o.Apply(e)`, and 01g proposes expression-`if`. All three are superseded.

## 8. Not decided here

- **Whether the dot projects** (`o.Total`) — ticket 26's. Only "the dot is never a call" is settled.
- **The prelude's collection surface** — which operations exist, and their names. Stdlib breadth is
  out of scope on the map; §2's rule constrains only how the compiler-known ones are *emitted*.
- **How inlining interacts with hot code loading.** Ticket 13 settled aggregate-granularity loading;
  inlining a prelude function into a caller means a change to the prelude does not reach that caller
  without recompilation. The prelude is compiler-known so this is probably fine, but it is a stated
  assumption rather than an established one.
- **`cond`**, and **`stream<T>`** — both deferred above with their requirements captured.
