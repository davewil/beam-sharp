# 75 — A function as a value: the arrow type, the lambda, and a name in value position

Type: grilling
Status: resolved 2026-09-12 — [ENG-364](https://linear.app/davewil/issue/ENG-364). Raised 2026-09-12 by
[ticket 37](37-instantiation-by-matching.md)'s ordering round ([ENG-204](https://linear.app/davewil/issue/ENG-204)),
picked by `/frontier` the same day as the sole unblocked High issue, and resolved in two rounds
that afternoon. The build is [ENG-365](https://linear.app/davewil/issue/ENG-365), sequenced
behind [ENG-295](https://linear.app/davewil/issue/ENG-295).
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
             f(3)
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

**Answered 2026-09-12 (David):** Q1 — **a value.** Q2 — **C#'s spelling.** Q3 — **as
recommended**: the bare name where an expected type fixes the arity, `Double/1` where nothing does,
the pipe unmoved.

> **Built narrower than Q2, 2026-09-12 — F46, and the call is open at
> [ENG-367](https://linear.app/davewil/issue/ENG-367).** The bare-name form `n => e` shipped as an
> *argument* only, not a general `expr`: as an expression it reads every switch-arm guard ending
> in a name — `x when x > m => 0`, F7's own test — as a lambda, a collision this round's table did
> not reach. `(a, b) => e` is a general expression as answered. The decision above stands until
> ENG-367 confirms or overrules the narrowing; this note is the cross-reference, not the ruling.
>
> **Ruled 2026-09-13, [ticket 76](76-the-bare-name-lambda-and-the-arrows-extent.md): Q2 stands as
> answered and the narrowing is reversed.** C# has the same collision and resolves it in the
> guard, parsed at the tier below the lambda; the same two-tier grammar in yecc measured at the
> landed four intended shifts and makes `x when (n > 3) => :high`, accepted above as a syntax
> error, a guard. The table's row *"`n => e`, an `expr`: +1 s/r"* undercounted what the shift
> reaches, not what it costs.

## Round 2 — what a lambda is made of (2026-09-12)

Settled by round 1: the arrow is a type of the language, spelled `fn(T) -> U`; a lambda is an
`expr` in C#'s spelling; a name is a value. Four things follow with no decision in them and are
recorded here rather than asked:

- **A lambda's body is one expression, not a body.** The switch arm's reason holds verbatim
  (`bs_parser.yrl:569`): arguments are comma-separated and a body has no terminator, so
  `(o) => var t = o.Total, t * 2` cannot be told from two arguments with one token of lookahead.
  A lambda that needs a binding names a private function.
- **A lambda closes over every name in scope, and its parameters bind under 34.** *Bindings do
  not shadow*, so a parameter may not reuse an enclosing name; the scope pass F4 built walks into
  the lambda as it walks into a `switch` arm. The BEAM does the capture.
- **The `-spec` form is `fun((A) -> B)`** — the form `bs_emit.erl:1159` already builds for every
  function's own spec, now nested. Under 18 it is the same tier as the rest of the declared
  signature: documentation to Dialyzer, enforced by `bs_check`.
- **The printer spells an arrow as the author does**, `fn(int) -> int`, in a corrected signature
  (F25) and wherever `pattern_parts` (F29) prints a type; an arrow has no pattern, so
  `pattern_parts` never prints one in head position.

The parsing half of a pattern-shaped parameter was measured in round 1: `'(' patterns ')'` cannot
share the parenthesis with the tuple expression (21 reduce/reduce), so parameters are parsed as
an `expr_list` and lowered — the `to_match/1` lowering the bare `=` already uses
(`bs_parser.yrl:633`), with one added clause, because `to_match` refuses a bare variable on
purpose (*"a bare `=` matches rather than introduces"*) and a lambda parameter introduces.

### The questions

❓ **Q4 — A lambda's parameters: binders, or patterns?** Four programs, one domain each:

```csharp
public int Sum(list<(atom, int)> pairs)
Sum(pairs) -> pairs |> List.Fold(0, (acc, (_, n)) => acc + n)                       // (b) a pattern
Sum(pairs) -> pairs |> List.Fold(0, (acc, p) => acc + p switch { (_, n) => n })     // (a) binders only

public int Oks(list<result<int, string>> rs)
Oks(rs) -> rs |> List.Fold(0, (acc, n) => acc + n)                    // refused either way: `int` ≤ `int | (:error, string)` fails
Oks(rs) -> rs |> List.Fold(0, (acc, (:ok, n)) => acc + n)            // (b): refused — residual `(:error, string)`, the clause you must write
```

Under (b) a parameter is a pattern checked **irrefutable** against the arrow's domain: `subtract`
of the domain by the pattern's type is `none`, or the residual is the refusal — the rule
[33](33-body-check-site.md) §5 wrote for the destructuring bind and F5/F8 built
(`bind_step({dbind, …})`, `bs_check.erl:3200`). One clause, no guard: a lambda with two cases is
`(x) => x switch { … }`, which already exists. Cost of (b) over (a): the `to_param` lowering
clause above, and `type_of({e_lambda, …})` calling the bind's own check per parameter instead of
binding a name. Cost of (a): every destructuring lambda carries a `switch` whose single arm is the
pattern (b) would have written in the head.

➡️ **(b), patterns, one clause, irrefutable.** The machinery exists to the line, the refusal is
the residual the language already prints, and it is the same rule a `var` binding follows — a
lambda parameter is a binding site and nothing else. Multi-clause lambdas stay out: 08's *one
arrow per arity* applies to a fun as it does to a function, and the `switch` is the dispatch.

---

❓ **Q5 — A lambda with no expected type.** C# admits `(int n) => n * 2` where nothing fixes the
parameter's type. Under Q3 the bare name is refused there; the lambda has the same hole:

```csharp
Later(xs) -> var twice = (n) => n * 2           // nothing fixes `n`'s type
             List.Map(xs, twice)

Later(xs) -> var twice = (int n) => n * 2       // C#'s typed parameter
             List.Map(xs, twice)

Later(xs) -> List.Map(xs, Twice)                // a private function, signed as everything is
```

The typed form is a new production, `'(' params ')' '=>' expr`, whose prefix `( lident` is also
an expression's; the parenthesised-parameter half of that is not measured and the round does not
guess at it. [04](04-crossclause-exhaustiveness.md) made signatures mandatory; a lambda's signature is
the arrow expected at its site, and a site with no expectation is a lambda with no signature.

➡️ **Refused, and the diagnostic names the two ways out**: hand the lambda to the site that
expects it, or write a private function. No typed-parameter form. This is Q3's rule applied to
the lambda — a value whose type nothing fixes is refused at a binding — and one rule for both is
what makes `var f = Double` and `var f = (n) => …` read the same refusal.

---

❓ **Q6 — The arrow's codomain and a union.** Measured: with the codomain a `type_expr`,
`fn(int) -> int | :nothing` carries one shift/reduce that shifts, so the union is the result. The
alternative measured conflict-free — codomain a `type_prim` — turns out to be unusable, because in
type position a parenthesised single type is a **1-tuple** (`bs_parser.yrl:192`, unlike the
pattern and expression positions, which collapse it), so `fn(int) -> (int | :nothing)` would
return a one-element tuple. There is no grouping parenthesis in the type grammar.

```csharp
type Lookup = fn(atom) -> int | :nothing        // an arrow returning option<int>
type Handler = fn(Event) -> Event | :skip       // an arrow returning either

type Rule = fn(int) -> int
type Maybe = Rule | :nothing                    // an arrow or nothing: the alias is the grouping
```

➡️ **The codomain extends as far as it can; the alias groups.** The shift is the reading every
example above means, the union-of-arrows case is spelled through a named arrow, and the type
grammar gains no parenthesis.

---

❓ **Q7 — How ENG-321's inliner takes a fun.** Today a reserved operation is one walker per module
per operation, shared by every site (`reserved_form`, `bs_emit.erl:1536`), with no type in it.
`List.Map(xs, (n) => n * 2)` can lower two ways:

```erlang
%% (i) the fun is an argument; one walker per module
'Twice'(Xs) -> 'List.Map/2'(Xs, fun(N) -> N * 2 end).
'List.Map/2'([], _F)      -> [];
'List.Map/2'([H | T], F)  -> [F(H) | 'List.Map/2'(T, F)].

%% (ii) the body is substituted; one walker per site
'Twice'(Xs) -> 'List.Map@7'(Xs).
'List.Map@7'([])      -> [];
'List.Map@7'([H | T]) -> [H * 2 | 'List.Map@7'(T)].
```

(ii) is [17](17-pipeline-and-comprehension.md) §2's precision argument at its strongest and it
cannot be the only lowering: `List.Map(xs, f)` where `f` is a parameter of arrow type has no body
to substitute, so (i) must exist regardless. Under (i) the walker's success typing is parametric
(`fun((A) -> B), [A] -> [B]`) and the enclosing function's declared `-spec` is what the boundary
publishes either way; the fun costs one allocation per call.

➡️ **(i), one lowering.** The walker takes the fun, every site emits its lambda as an Erlang fun
or its name as `fun 'Double'/1`, and there is one `List.Map` per module as there is one
`List.Sum`. (ii) is an optimisation `erlc` is free to make and this compiler does not, until an
exemplar measures the difference.

**Answered 2026-09-12 (David): Q4 to Q7, all as recommended.** The frontier is empty: the arrow,
the lambda, the name, the call through a name, the parameters, the codomain and the lowering are
decided, and the guard, `ValidateAs<T>` and the spec were fixed by 11 and 18. Resolved.

## Corrected on resolution

- [Ticket 67](67-stdlib-shape-as-a-principle.md)'s *"no function values survives intact"* is
  struck and marked overruled in place, that sentence and nothing else.
- `CONTEXT.md`'s *Pipe* entry loses *"a function value is not a form this language has"*; the
  pipe's rule stands on its own ground, a rewrite of a call. *Arrow*, *Lambda* and *Name in value
  position* are added, terms only.
- `LANGUAGE.md`'s pipe section gives the same corrected reason, and its *Polymorphic function
  signatures — next* block now says the function value is decided and unbuilt rather than open.

## Decisions entry

<!-- This ticket's entry. Read whole, here; the map (ENG-165) carries one line. -->

```decisions-entry
- [A function as a value](issues/75-a-function-as-a-value.md) — **a function is a value: the arrow
  `fn(T) -> U` is a type of the language, a lambda is an expression in C#'s spelling, and a name
  in value position is that function.** Raised 2026-09-12 by ticket 37's ordering round and
  resolved the same day in two rounds, seven questions, every recommendation taken. **The record
  held both answers to the gating question**: ticket 67 had kept *"no function values"* nine days
  earlier, in a list of what it did not reopen, reasoning about `List`'s shape; 67 is overruled on
  that sentence and nothing else. The arrow is a **seventh part of the partition**, a union of
  arrows with pairwise subtyping — domain contravariant, codomain covariant, 11's measured rule,
  kept pairwise by 08's one arrow per arity — and an **all-or-nothing `subtract`**, the same
  over-approximation the map domain takes. A lambda `(a, b) => e` is **one clause with one
  expression for a body** (the switch arm's lookahead reason, verbatim); its **parameters are
  patterns checked irrefutable against the expected arrow's domain**, 33 §5's rule for the
  destructuring bind, the residual as the refusal; it closes over every name in scope and its
  parameters bind under 34, no shadowing. **A lambda's signature is the arrow its site expects;
  where nothing fixes it, it is refused**, and so is a bare name whose arity nothing fixes —
  `Double` reads its arity from the expected type, `Double/1` is legal everywhere and required
  where two arities meet no expectation. **Calling through a bound name, `rule(cents)`, is a call
  form** — the fourth form the ticket had not listed. The codomain extends as far as it can, so
  `fn(atom) -> int | :nothing` returns an option, and a named arrow is how a union of arrows is
  grouped, because a parenthesised type is a 1-tuple. **The pipe does not move**: `xs |> Sum`
  stays a syntax error, `xs |> Sum()` is the spelling. ENG-321's walkers take the fun as an
  argument, one per module per operation; substituting a lambda's body is an optimisation the
  compiler does not make. **Measured, not inferred** — yecc on eleven candidate productions: C#'s
  lambda is conflict-free as an argument and collides with a switch arm's guard as an expression
  (`x when (n > 3) => :high` becomes a syntax error, and no guard in the corpus or the spec is
  written so); the pattern-shaped head is 21 reduce/reduce, so parameters parse as an expression
  list and lower; `Double/1` and the keyword lambda are conflict-free everywhere. Fixed earlier and
  unchanged: `ValidateAs<T>` refuses arrows and the top arrow `fn(none) -> term` is uncallable
  (11); a clause head dispatches on an arrow's arity alone, so two arrows of one arity in a union
  are 70's container, legal and undispatchable. **Unbuilt** — the polymorphic signature (27 §(c),
  ENG-295) lands first inside this increment, then the arrow, ENG-365.
```

> **Amended 2026-09-13, [ticket 76](76-the-bare-name-lambda-and-the-arrows-extent.md).** The
> measured sentence above — *C#'s lambda collides with a switch arm's guard as an expression,
> `x when (n > 3) => :high` becomes a syntax error* — undercounted what the shift reaches (every
> guard ending in a name, F46's finding) and overpriced what it costs: C# has the same collision
> and parses the arm's `when` clause at the tier below the lambda, and the same two-tier grammar
> in yecc measured at the four intended shifts. So both spellings are general expressions as Q2
> answered, no guard shape is a syntax error, and F46's narrowing of `n => e` to an argument is
> reversed. Built by [ENG-368](https://linear.app/davewil/issue/ENG-368).
