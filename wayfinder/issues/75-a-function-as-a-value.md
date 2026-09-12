# 75 — A function as a value: the arrow type, the lambda, and a name in value position

Type: grilling
Status: open — [ENG-364](https://linear.app/davewil/issue/ENG-364). Raised 2026-09-12 by
[ticket 37](37-instantiation-by-matching.md)'s ordering round ([ENG-204](https://linear.app/davewil/issue/ENG-204)),
unclaimed.
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

## Round 1

Not yet asked. The grill starts when the ticket is claimed.
