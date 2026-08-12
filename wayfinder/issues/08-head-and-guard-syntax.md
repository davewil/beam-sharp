# 08 — Multi-clause head and guard syntax

Type: grilling
Status: claimed
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

## SETTLED — arity, defaults, variadics, and same-arity dispatch

Decided under the map's audience constraint: **C# *or* TypeScript developers**, so a construct
familiar to either counts as borrowed.

### Same-arity dispatch on different types → a union parameter, not overload signatures

```csharp
string Describe(int | Order);

(n) when n > 0  -> "positive number";
(n)             -> "number";
({ Status: s }) -> "order: " + s;
```

Native to TypeScript, and readable to a C# developer as soon as unions exist — which C# 15 is
adding anyway. TS-style overload signatures (several signatures, one clause set) were the
alternative and were rejected: the whole clause set is checked **once per arrow**, so every clause
is checked against every signature, which *reads* as though clauses belong to one arrow or another
when they do not.

**Knock-on that simplifies ticket 04 and ticket 11**: **one arrow per arity**. The per-arrow check
therefore runs *once*, not once per signature, and the question of which clause belongs to which
arrow disappears. Multiple arrows remain expressible only if a later ticket reintroduces them.

### Defaults and variadics — both kept, because both audiences have both

C# has `b = 0` and `params T[]`; TypeScript has `b?` and `...args`. The reader sees one function,
as in either language. Arity generation is **codegen**, not surface.

```csharp
Money Total(Order o, Money acc = 0);      // source: one function; emits Total/1 and Total/2

void Log(...list<string> parts);          // Log("a", "b")  ->  Log(["a", "b"]); always Log/1
```

Variadics never vary the arity — rest lowers to a single list-taking function and the call site is
rewritten, exactly as C# constructs an array at the call site.

**The leak, stated rather than hidden**: Erlang callers see the generated exports, and so do stack
traces. That is an interop-surface consequence, not a source-surface one.

### Defaults do NOT subsume the accumulator pair

`Money Total(Order o, Money acc = 0)` generates `Total/1` and `Total/2` — but **both take an
`Order` first**. The recursive helper needs `Total(list<Line>, Money)`, a different first parameter
type. A default value cannot change a parameter's type.

So two distinct mechanisms both produce multiple arities, and the spec must distinguish them:

- **Defaults** — for genuinely optional arguments of the same type.
- **Two functions sharing a name** — for the public/private accumulator pattern, exactly as the
  prototypes have it. Name-plus-arity identity makes this free, and it is the BEAM idiom.

Otherwise someone reaches for a default where they need a second function, and the types will not
line up.

## SETTLED — guards use the expansion rule, and named guards take a `guard` modifier

**The rule** (adopted from Elixir, verified locally on 1.19.5 / OTP 28): *a guard may contain
anything that **expands** to guard-legal operations, and nothing requiring a runtime call.*

Elixir enforces the same restriction Erlang does, and states the principle in its own error text:

```
error: cannot find or invoke local big?/1 inside a guard.
       Only macros can be invoked inside a guard and they must be
       defined before their invocation.
```

…and ships the escape as `defguard`, which is a **macro** — compile-time expansion, not a call.

**The spelling**: a `guard` modifier on an ordinary function declaration, in the position C#
already uses for `static`, `async` and `partial`.

```csharp
guard bool IsPositive(int n) -> n > 0;
guard bool IsDraft(Order o)  -> o.Status == :draft;

(o, (:pay, amt)) when IsPositive(amt) -> ...;    // expands to: when amt > 0

(o, sku) when HasSku(o.Lines, sku) -> ...;       // error: HasSku iterates, cannot expand
```

**Why expansion beats verification.** The properties fall out rather than being checked:
non-recursion (a recursive macro cannot expand finitely), boundedness (the expansion contains only
guard-legal operations), and cost visibility (there is no hidden call, because there is no call).
An earlier proposal had the compiler *verify* a function body and inline it; expansion means there
is nothing to verify.

**Two prior objections resolved by this.**

- *"Friction #1 is the biggest threat to the design."* Downgraded. Under the map's standing
  constraint the hand-restructuring cost is a **write** cost, and those carry little weight. What
  survives is the read cost — the restructured form is two functions where the clause table was
  one.
- *"Auto-hoist any pure call."* Rejected. Hoisting **hides the cost**: `when amt >= Total(o)` reads
  as a cheap test and is O(n), and in a `receive` clause that is paid per message. Erlang's
  restriction is what forces the expense into view. Also, the bounded-guard guarantee is protected
  **across the BEAM**, not only in Erlang — two independent language designs arrived at the same
  restriction plus a compile-time abbreviation, and Elixir had every chance to relax it.
- *"Is `[Guard]` premature, before ticket 22 decides about attributes?"* Moot — it is `defguard`
  with a different spelling, an established BEAM idiom rather than an invention, and the modifier
  form avoids loading semantics onto an attribute.

**Composes with the `as` answer below**: `as` is an operator, not a call, so it expands cleanly;
and an inferred narrowing inserts an operator too. No conflict.

Not checked locally: Gleam and LFE (Gleam is not installed — see the map's evidence-provenance
note). Their positions are doc-level.

## `dynamic` in a guard — candidate answer: the `as` operator

Guards use `&&`/`||` because a guard over typed values cannot fail. A guard mentioning a
`dynamic` value *can*, so something must give. Five options were weighed; **the strongest is
David's suggestion of `as`** (2026-08-12).

```csharp
(d, s) when (d as int) > 0 -> ...;
```

**`as` is total** — it never raises, yielding a nothing-value on failure. And **C#'s lifted
comparison operators already return `false` when an operand is null**. So if `d` is not an
integer, the comparison is false, the guard fails, and the next clause is tried.

That is Erlang's fail-to-false arrived at through *standard C# semantics* rather than a special
guard rule — which gains the benefit of the fail-to-false option (existing BEAM code shapes work,
nothing needs restructuring) without its cost. `&&` never changes meaning; the possibility of
failure is **visible in the expression** as a nullable rather than implied by the operand types.

**And it satisfies the prototype 01f rule below**: `as` is a *type operation*, so the
exhaustiveness checker can credit it — `when (d as int) > 0` tells the checker the clause accepts
integers greater than zero. A fail-to-false guard rule would have been invisible to the checker.

Three things to settle with it:

1. **It requires an option type**, which set-theoretic unions give free: `d as int` has type
   `int | :nothing`. Ticket 05 dropped C#'s *nullable reference types* as CLR-dependent, but that
   is a different mechanism; a union with a nothing case needs no CLR support. → ticket 11.
2. **It diverges from C# in the simplifying direction.** In C#, `o as int` is a compile error
   (CS0077) — `as` requires a reference or nullable value type, so one writes `o as int?`.
   beam-sharp has no reference/value distinction, so `as T` yielding `T | :nothing` for any `T`
   is simpler than C#'s rule. State it in the spec as a deliberate divergence.
3. **It inherits a known C# gotcha**: with lifted comparison, `x > 0` and `x <= 0` can both be
   false. Arguably correct here — "not an integer" satisfies neither — but it will catch someone.

### Or infer the narrowing — and a correction about Erlang that changes it

The compiler could **insert the narrowing** rather than requiring `as` be written: `when d > 0`
becomes `when (d as number) > 0` because `>` demands a number. This is not an invention — it is
standard gradual typing, Siek and Taha's cast insertion, and it is what a BEAM programmer would
write and an agent would generate.

**But a correction, verified locally on OTP 28.** Erlang's comparison operators **never
fail-to-false, because they never fail** — they are total across all term types via the standard
order (`number < atom < reference < fun < port < pid < tuple < map < nil < list < bitstring`):

```
foo > 0      -> true          {a} > foo -> true          [] > 0 -> true

guard X > 0         on foo  -> comparison_succeeded   (does NOT fall through)
guard X + 1 > 0     on foo  -> fell_through           (arithmetic raises)
guard length(X) > 0 on foo  -> fell_through           (BIF raises)
```

Fail-to-false applies to **arithmetic and BIFs**, not to comparison. So inferring `d as number`
for `when d > 0` makes `:foo > 0` **false**, where Erlang says **true**. Inference does not
reproduce Erlang's behaviour — it *diverges* from it.

Arguably in the right direction: `:foo > 0` being true is an artefact of Erlang needing a total
order for sorting and reusing the operators for it. But it is a divergence and must be a stated
design decision, not something a BEAM programmer discovers when a comparator misbehaves.

**Candidate rule**: infer where the operation determines the type unambiguously (`d > 0`,
`d + 1` — one candidate, no guessing); require `as` where it does not (`d.Length` — list, binary
and map all have one). **Ambiguity is an error, not a guess**: *"cannot infer the narrowing for
`d.Length`; write `d as list<T>`"*.

Residual cost: an inferred narrowing is invisible, so a failure occurs in code nobody wrote and
the diagnostic must point somewhere sensible — sharper under the standing constraint, since an
agent must be able to act on that message. → ticket 23.

### The four alternatives, for the record

- **Total predicates plus narrowing in the guard** — `when IsList(d) && d.Length > 0`, relying on
  short-circuit to narrow. Familiar from C# null-state analysis and TypeScript. Needs
  flow-sensitive narrowing inside a guard expression. Composes with `as` rather than competing.
- **Forbid `dynamic` in guards** — narrow in the head with a type pattern instead. Simplest
  semantics, and pushes conditions into patterns where the checker credits them. Rejects code that
  would have worked. **Note it is forward-compatible**: every program legal under this rule stays
  legal if `as` or narrowing is added later.
- **Fail-to-false as a guard rule when `dynamic` is involved** — matches the platform, requires no
  restructuring, but makes `&&` mean two things depending on operand types, invisibly.
- **Hoist and let it raise** — honest C# semantics via 01f's hoisting mechanism, and fits
  let-it-crash. Diverges from every BEAM language, and degrades the diagnostic from
  `function_clause` at the call site to a `badarg` from a hoisted expression.

## `Self` — resolved, and the answer is to remove the need

Prototype 01e left `Self` undefined: `StartLink` needs to name its own module, Erlang's `?MODULE`.

**C# has no `?MODULE` idiom.** There is no way to say "the current type" without naming it —
`this` is an instance reference, `typeof(X)` requires writing `X`, and reflection via
`MethodBase.GetCurrentMethod().DeclaringType` is something nobody writes deliberately. In a static
class a C# developer simply writes the class name. So *any* self-reference keyword would be new
vocabulary; `Self` is Rust and Swift, not C#.

**The better answer removes the need.** `[module: GenServer]` already declares the behaviour, and
the compiler knows which module it is in, so the module argument should not be exposed:

```csharp
(:ok, Pid) | (:error, dynamic) StartLink();

() -> GenServer.StartLink(:no_args, []);          // not StartLink(Self, :no_args, [])
```

This matches how C# developers experience frameworks — you never hand "this class" to ASP.NET or
to DI; the framework knows through an attribute, a base class or a registration. Passing a module
handle to `gen_server:start_link/3` is a BEAM idiom with no C# analogue, so exposing it would
import unfamiliarity rather than avoid it. It also removes a class of error: the `?MODULE`
argument and the `[module: GenServer]` attribute cannot disagree if there is only one of them.

**Residual cases still need a module as a value** — `spawn(Mod, Fun, Args)`, `apply/3`, supervisor
child specs, `code:which`. Those name *another* module anyway (`Child(:orders,
OrderServer.StartLink, …)`), so writing the name covers them.

**Decide here**: whether module references are first-class values (a module name in value position
being the BEAM atom), and which OTP entry points get the compiler-supplied module treatment versus
requiring an explicit name.

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
