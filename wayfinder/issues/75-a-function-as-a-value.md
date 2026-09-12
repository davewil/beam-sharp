# 75 — A function as a value: the arrow type, the lambda, and a name in value position

Type: grilling
Status: claimed 2026-09-12 — [ENG-364](https://linear.app/davewil/issue/ENG-364). Raised 2026-09-12 by
[ticket 37](37-instantiation-by-matching.md)'s ordering round ([ENG-204](https://linear.app/davewil/issue/ENG-204));
picked by `/frontier` the same day as the sole unblocked High issue.
Blocked by: —

## Why this is raised now

Three documents filed the lambda under ticket 27 §(c): `LANGUAGE.md`'s *"Polymorphic function
signatures — next"* (*"`Map` above needs `fn(T) -> U` in a signature and a lambda to pass to
it"*), the exemplar README's waiting table (*"Lambdas — decided, unbuilt — 27 §(c)"*), and
[ticket 25](25-exemplar-programs.md)'s frontier row (*"decided at ticket 27 §(c)"*); ENG-295 said
*"`fn(T) -> U` … is part of §(c), not a separate debt"*. [27 §(c)](27-parametric-polymorphism.md)
decides *"a variable quantified in a value-level signature, instantiated at each call site"* and
nothing about an arrow type or a function value, and ticket 37 read it that way from its first
line (*"blocked on something that is not §(c)"*). So a line decided on 2026-08-13 was carrying the
largest unasked design question on the map. David, 2026-09-12, ticket 37 round 1 Q1: **own
ticket**; round 2 Q3: **three forms, one type**.

## The program

25b's wall, and the shape every traverse in the corpus (`Rowed`, `Checked`) generalises to:

```csharp
module Shop.Reports

public int Double(int n)
Double(n) -> n * 2

public list<int> Twice(list<int> xs)
Twice(xs) -> List.Map(xs, Double)              // a name in value position

public list<int> Thrice(list<int> xs)
Thrice(xs) -> List.Map(xs, (n) => n * 3)       // the lambda, same arrow type

public int Total(list<Order> os)
Total(os) -> os |> List.Fold(0, (acc, o) => acc + o.Total)
```

None of it compiles today. `=>` lexes and is a `switch` arm only (`bs_lexer.xrl:123`); `ty()` has
six parts — atoms, ints, tuples, lists, maps, bins — and none is an arrow (`bs_types.erl:139`);
`xs |> Sum` is refused as a syntax error by design (`LANGUAGE.md`, the pipe section — *"the right
operand is a call, never a bare name"*).

## The three forms this ticket decides

1. **The arrow in the algebra.** `fn(T) -> U` as a seventh `ty()` part. What its subtyping is
   under [27 §5](27-parametric-polymorphism.md)'s no-variance; whether an arrow is a guard-decidable
   member (`is_function/2` is a BEAM guard, and a clause head over `term` may ask it); whether it
   prints in a corrected signature.
2. **The lambda expression.** `=>` in expression position; whether its parameters are a clause
   head (patterns, a guard, exhaustiveness over the arrow's domain) or binders only; what it closes
   over (ticket 34's bindings); emission as an Erlang `fun`.
3. **A named function as a value.** `List.Map(xs, Double)` and `xs |> Sum` — a `uident` where an
   expression is expected; how arity is chosen when a name carries more than one
   ([ticket 40](40-module-and-namespace-system.md)); emission as `fun Double/1`.

Three forms because the type is the same: a ticket deciding two of them would leave
`List.Map(xs, Double)` undecided while `List.Map(xs, (n) => Double(n))` compiled.

## Out of this ticket

- **`List.Fold`, `Map`, `Filter` themselves.** ENG-321's waiting table entries — breadth, landing
  when the arrow does. [Ticket 67](67-stdlib-shape-as-a-principle.md) settled that they are
  compiler-known and inlined; the arrow changes nothing there.
- **The polymorphic signature.** 27 §(c), ENG-295 — the algorithm is ticket 37's and the ordering
  is decided: **the first feature inside this increment**, blocked by this ticket in Linear.

## Binding constraints

- [27](27-parametric-polymorphism.md) §1, §2, §3, §5, §7 — prenex, opaque in clause heads,
  unbounded, no variance, no row variables. An arrow that reopened any of these would reopen
  instantiation as a constraint problem.
- [08](08-head-and-guard-syntax.md) — one arrow per arity, dispatch on a union parameter; a
  function type is `(A | B) -> (C | D)`, never an intersection of arrows.
- [17](17-pipeline-and-comprehension.md) — the pipe is a syntactic rewrite of a call; whether a
  bare name on its right becomes legal is form 3 and nothing else about the pipe moves.
- [67](67-stdlib-shape-as-a-principle.md) — `List` is compiler-known; a lambda handed to
  `List.Map` is typed at the site like every other argument.

## Round 1 — is a function a value, or an argument? (2026-09-12)

Grilled at `d309dae`, the day the ticket was raised. **One gating question, and the record holds
two answers to it already.** Everything else on this ticket follows from it and is not asked here.

### What moved, measured

- **Ticket 67 decided against this ticket's framing nine days before the framing was chosen.**
  [67](67-stdlib-shape-as-a-principle.md), resolved 2026-09-03, under *"the function-taking
  operations wait on the lambda"*: *"under (b) a lambda is only ever an argument to an inlined
  operation, so it never has to be a **value** at run time — `xs |> Sum` stays a syntax error and
  **no function values** survives intact."* Ticket 37's Q3, 2026-09-12: *"one ticket, three forms
  … a named function as a value."* Both are David's. `CONTEXT.md`'s *Pipe* entry and
  `LANGUAGE.md:1416` state 67's line as the language's (*"a function value is not a form this
  language has"*); whichever way Q1 goes, both get corrected after the round, not asked.
- **A fourth form is implied and unlisted: calling a value.** `f(n)` is not a call form — every
  `call ->` production has a `uident` or a foreign `atom_lit '.' lident` callee
  (`bs_parser.yrl:491–518`), and a lowercase name followed by `(` is a syntax error. 27 §2's own
  `Map` example writes `f(h)` in a clause body. Under the value reading this is a new production
  and a new `type_of` clause; under 67's reading no user program ever contains it.
- **Ticket 11 already fixed the arrow's two hard facts.** `ValidateAs<T>` refuses any `T`
  containing an arrow (`CONTEXT.md`, *ValidateAs*); the top arrow is `fn(none) -> term`, uncallable,
  because `subtype?(fn(int)->int, fn(none)->term) = true` and `subtype?(fn(int)->int,
  fn(term)->term) = false` (measured, `11b_fun_evidence.erl`). So a `term` narrowed by
  `is_function/1` in a clause head is holdable and returnable, never callable — and
  `:erlang.is_function(x, 1)` is admitted in a guard today as a foreign call, because `bs_check`
  asks `erl_internal:guard_bif/2` rather than keeping a list (`bs_check.erl:2524`). Nothing in a
  guard moves.
- **Two lambda spellings are already in the record, both C#'s.** 17 §1's program:
  `os |> List.Filter(o => o.Status == :open)`; 25b's: `List.Fold("", (acc, c) => …)`. 08's table
  reserves `=>` *"for lambdas"*. No spelling is decided.
- **The grammar, measured** — yecc with `{report, true}` on `bs_parser.yrl` at `d309dae`, baseline
  **0 conflicts**, each production added alone:

  | production | conflicts | what the conflict is |
  |---|---|---|
  | `fn(n) => e`, an `expr` | **0** | `fn` becomes a keyword |
  | `(n) => e`, an `expr` | 1 s/r, shift | a switch arm's guard: `x when (n > 3) => :high` shifts into a lambda and is a **syntax error** |
  | `n => e`, an `expr` | +1 s/r, shift | the same, on a bare-name guard: `x when flag => 1` |
  | `(n) => e` and `n => e`, **as a call argument only** | **0** | — |
  | `Double`, an `expr` | 2 s/r, shift | `Double(` and `Double{` read as call and construction — the intended read |
  | `Double/1` | **0** | — |
  | `f(n)`, a lowercase call | 1 s/r, shift | `f(` reads as a call — the intended read |
  | `fn(int) -> int \| :nothing`, codomain a `type_expr` | 1 s/r, shift | the union is absorbed into the result |
  | `fn(int) -> (int \| :nothing)`, codomain a `type_prim` | **0** | a union result is parenthesised |

  Two things the table says on its own. **C#'s lambda is conflict-free exactly when a lambda is an
  argument** — the grammar draws 67's line without being asked. And the four shift-resolved
  conflicts on the value forms are all the same shape: a bare name or a parenthesised expression
  followed by the token that opens the value form, and the shift is the read every author means
  except in one place, a switch arm whose guard is a bare name or a parenthesised expression.

### The questions

❓ **Q1 — Is a function a value, or only an argument?** Program A compiles under either answer:

```csharp
public list<int> Twice(list<int> xs)
Twice(xs) -> List.Map(xs, (n) => n * 2)
```

Program B compiles only if the arrow is a type of the language — declared in a signature, returned
from a clause, bound to a name, and called through it:

```csharp
module Shop.Pricing

public fn(int) -> int Rule(atom tier)
Rule(:standard) -> (cents) => cents
Rule(:member)   -> (cents) => cents - 100
Rule(:staff)    -> Free

public int Charge(fn(int) -> int rule, int cents)
Charge(rule, cents) -> rule(cents)

private int Free(int cents)
Free(_) -> 0
```

Under 67's reading B is refused three times over: `fn(int) -> int` is not a type expression, a
lambda is not a clause body, and `rule(cents)` is not a call form. Under the value reading it
compiles to

```erlang
'Rule'(standard) -> fun(Cents) -> Cents end;
'Rule'(member)   -> fun(Cents) -> Cents - 100 end;
'Rule'(staff)    -> fun 'Free'/1.
'Charge'(Rule, Cents) -> Rule(Cents).
```

with `-spec 'Rule'(atom()) -> fun((integer()) -> integer()).` — the `fun` type form `bs_emit`
already builds for every function's own spec (`bs_emit.erl:1159`).

**The compiler delta under the value reading:**

1. **`bs_types`** — a seventh part beside atoms, ints, tuples, lists, maps, bins:
   `funs := [{[ty()], ty()}]`, a union of arrows. `is_subtype` is pairwise, domain contravariant and
   codomain covariant — 11's measured rule, and 08's *one arrow per arity, never an intersection*
   is what keeps it pairwise. `subtract` over arrows is **all-or-nothing**: contained gives `none`,
   otherwise the arrow is returned whole — the same over-approximation the algebra already takes on
   a map's domain, and the one place the residual is coarser than the set.
2. **Grammar** — `type_prim -> 'fn' '(' type_list ')' '->' type_prim` (0 conflicts); the lambda
   production, Q2; `call -> lident '(' expr_list ')'` (one shift-resolved conflict, the intended
   read). `fn` joins the keywords and leaves the variable namespace.
3. **`bs_check`** — three `type_of` clauses: `e_lambda` binds its parameters to the expected arrow's
   domain and synthesises the body; `e_apply` requires the callee's type to be arrows of that arity,
   contains each argument in the domain, and returns the join of the codomains; `e_fname` reads the
   declared signature as an arrow, keyed `{Name, Arity}` in the table `sig/3` already builds
   (`bs_check.erl:350`), arity per Q3. A lambda's parameters enter 34's scope pass: they bind, and
   under *bindings do not shadow* they may not reuse an enclosing name.
4. **`bs_emit`** — `{'fun', L, {clauses, …}}`, `{'fun', L, {function, Name, Arity}}`,
   `{call, L, {var, L, F}, Args}`. The BEAM does the closure.
5. **A clause head cannot dispatch on an arrow's type** — 11: `fun_info` yields identity, never
   types — so two arrows of one arity in a union parameter are a ticket-70-shaped container: legal,
   undispatchable, and F30's discriminability check says so at the declaration. Arity alone
   (`is_function/2`) discriminates.

**Under 67's reading:** no `ty()` change and no keyword. The lambda is admitted as a call argument
only, in C#'s spelling, conflict-free; ENG-321's `List.Map` / `Filter` / `Fold` entries land with
the inliner substituting the lambda's body at the site, which is 17 §2's precision argument at its
strongest; `Map<T, U>` in user code stays unwritable, so 27 §(c)'s stated purchase shrinks to
`Prepend` and `LANGUAGE.md:1685`'s `not-yet` block is withdrawn rather than shipped.

➡️ **A value.** The later call is David's and was made without 67's sentence in view; 67's
sentence sits in a list of what that ticket does *not* reopen and is reasoning about `List`'s
shape, not the language's (*"which operations exist at all is breadth"*). The record already leans
on the value reading: 27 §2's canonical example is a user-written `Map<TSource, TResult>` taking
`fn(TSource) -> TResult`, `LANGUAGE.md` ships it as *next*, and 11 priced the arrow's subtyping
and its boundary rule two weeks before anything needed them. The cost is one partition part with
an all-or-nothing subtract, three checker clauses and three emitter forms. The cost to state
plainly: a `switch` over a value of arrow type has one useful arm per arity, and the residual over
arrows is coarse.

---

❓ **Q2 — The lambda's spelling.** Live under either Q1 answer, and the measurement splits it:
C#'s spelling is conflict-free as an argument and collides with the switch arm's guard as a general
expression. Two spellings, the same program:

```csharp
public int Total(list<Order> os)
Total(os) -> os |> List.Fold(0, (acc, o) => acc + o.Total)      // C#'s
Total(os) -> os |> List.Fold(0, fn(acc, o) => acc + o.Total)    // the keyword
```

and the one program C#'s spelling refuses, as a general expression:

```csharp
Grade(n) -> n switch {
    n when (n > 3) => :high,     // shifts into a lambda `(n > 3) => :high`; syntax error at `,`
    _              => :low
}
```

The refusal is a syntax error, never a silent misparse: the shifted lambda runs to the `,` and the
arm has lost its `=>`. Every guard in the corpus is written `when n > 3`, and a guard whose whole
body is parenthesised or is a bare name is the only shape that collides. Under Q1's value reading
`fn` is a keyword anyway, spent on the type; the keyword lambda costs nothing further.

➡️ **C#'s spelling, both forms — `(a, b) => e` and `n => e` — as an `expr`**, the tier-1 borrow
both audiences read, already written twice in the record. The two shift/reduce conflicts are
documented in the grammar as expected and resolved as shifts, and `bs_parser` gains nothing else.
If a conflict-free grammar is the standing bar — ENG-331 was measured to it — the keyword form is
the fallback and the programs above read the same but for two letters.

---

❓ **Q3 — A name in value position: `Double` or `Double/1`?** 40 §2 permits arity overloading, so a
bare `Double` may name two functions. C# resolves a method group from the target type and refuses
`var f = Double` when nothing fixes the arity; the BEAM writes it, `fun 'Double'/1`.

```csharp
public int Double(int n)
public int Double(int n, int k)

Twice(xs) -> List.Map(xs, Double)          // arity from the arrow `List.Map` expects: 1
Twice(xs) -> List.Map(xs, Double/1)        // arity written
Pick()    -> Double                        // `fn(int) -> int Pick()` declares it: 1
Later()   -> var f = Double                // nothing fixes it: refused
```

The bare spelling reads its arity at an obligation site with an expected type — call argument,
clause return, construction — and the signature table is already keyed `{Name, Arity}`, so the
lookup is a map get once the arity is known. The two shift-resolved conflicts are the reads every
author intends. `Double/1` is conflict-free and needs no expected type.

➡️ **The bare name where an expected type fixes the arity; `Double/1` legal everywhere and
required where nothing does.** C#'s rule with the BEAM's escape, and the refusal at
`var f = Double` names the two arities and the spelling that picks one. **The pipe does not move**:
`xs |> Sum` stays a syntax error, because 17's pipe is a rewrite of a *call* and a name in value
position is a value; `xs |> Sum()` is the spelling.

**Answered:** —

### What round 2 holds, once Q1 is answered

- A lambda's parameters: patterns (a clause head — 33's site 5 irrefutability, `subtract` against
  the domain, the residual as the refusal) or binders only; one clause or many.
- What a lambda closes over, and 34's *bindings do not shadow* at its parameters.
- Whether an arrow prints in a corrected signature (F25) and in `pattern_parts` (F29).
- ENG-321's function-taking entries: whether the inliner substitutes a lambda's body or calls the
  fun, which is 17 §2's precision rule meeting a value it cannot see through.
- The `-spec` shape for a signature holding an arrow, and 18's boundary tier for it.
