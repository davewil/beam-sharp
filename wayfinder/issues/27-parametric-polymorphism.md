# 27 — Parametric polymorphism: does the language have generics at all?

Type: grilling
Status: resolved
Blocked by: 09 — resolved

## Question

Split out of [ticket 11](11-type-system-shape.md) on 2026-08-12, which was the keystone and held
at least six decisions. Ticket 11 kept the `dynamic` boundary, the subtyping relation and the
guarantee; this ticket takes the generics half.

Decide:

- **Does the language have parametric polymorphism at all?** Ticket 09 made types structural and
  open, and set-theoretic unions express a great deal without type variables. Ticket 11 removed
  `dynamic` entirely, so the usual "generic or dynamic" pressure valve is gone in both
  directions. Establish whether type variables are needed before deciding how they are spelled.
- **Generic syntax**, if so. C# angle brackets are the obvious tier-1 borrow and TypeScript
  spells them identically, so this is likely cheap — but confirm it against the parser
  consequences (`<` is also a comparison operator, and ticket 08 settled `&&`/`||` guards).
- **Parametric aliases.** This is the concrete debt. Ticket 10 §5 put
  `type option<T> = T | :nothing;` in the prelude, which assumes the single naming construct
  from ticket 09 admits type parameters — that is, that an alias may be a **type-level
  function**. Ticket 09 already writes `list<Json>` and `map<string, Json>`. Decide whether
  parametric aliases exist, and if so whether they may be recursive.
- **Variance**, if type variables exist. Arrow subtyping is already contravariant in the
  argument (verified in ticket 11: `subtype?(fn(int)->int, fn(none)->term) = true` but
  `subtype?(fn(int)->int, fn(term)->term) = false`). Whether variance must ever be *stated* by
  the user is the open part.

## Binding constraints

- **`ParseAtom<T>` and `ValidateAs<T>` are not evidence that generics exist.** Both are
  type-directed **codegen obligations** — ticket 10 established the first, ticket 11 the second.
  `<T>` there is a compile-time argument driving generation, monomorphic at every use site, with
  no type variable surviving into the runtime or the type algebra. If this ticket decides the
  language has no parametric polymorphism, both mechanisms still stand unchanged.
- **Recursive *and* parametric together is the dangerous combination.** Ticket 11's §"Constraints
  from ticket 09" records that Elixir's roadmap calls this the combination that is unfeasible to
  get wrong, and ticket 09 already committed the language to the recursive half (equirecursive,
  contractive, subtyping decided coinductively). So the cost of saying yes here is not the cost
  of generics in isolation.
- **Tallying is the relevant algorithm**, not unification — ticket 04 found no complexity bound
  for it exists in the literature at all.

## Notes

HITL. This ticket is **ticket 16's blocker in place of ticket 11** — ad-hoc polymorphism cannot
be settled without knowing whether type variables exist. It also owns the parametric-alias
question outright, so [ticket 26](26-data-modelling.md) should not decide it.

## Constraints from ticket 13 — resolved 2026-08-12

**Ticket 13 §6 supplies the publication half of the codegen-obligation story.**

`ParseAtom<T>` and `ValidateAs<T>` are monomorphic at every use and are *generated*, not written —
this ticket exists partly to keep them from being mistaken for evidence of generics. Ticket 13 rules
that the compiler emits a `-spec` for every function whose beam-sharp type is known, **widening to
the nearest expressible supertype** where a set-theoretic type has no Erlang spelling (Erlang's spec
grammar has no negation, and expresses intersection only as an overloaded spec).

So what a codegen obligation publishes to the Erlang world is a **widened monomorphic spec**, never
a generic one — which is consistent with, and further evidence for, the position this ticket is
likely to take. Worth confirming rather than assuming when this ticket is resolved.

## Constraints from ticket 14 — resolved 2026-08-12

**A motivating case has been removed.** Ticket 03 recommended `Pid[τ]` — a process identifier
parameterised by the message type it accepts — and it was one of the clearest demands in the map
for a genuine type parameter. Ticket 14 §1 **declines it**, on three grounds:

1. It is not expressible. Ticket 09 makes types sets of values with no nominality, so
   `pid<Order.Msg>` and `pid<Payment.Msg>` denote the same set and are therefore the same type.
   Gleam can carry the phantom parameter only because its type system is nominal — `subject(τ)`
   lowers to `{subject, Pid, Ref}` with τ erased.
2. It is not needed. The message type belongs on the client API function's signature, which is
   where it was going to be written anyway.
3. It would not buy soundness, since ticket 21 rules out ruling out foreign senders.

So this ticket decides generics on the remaining evidence — `option<T>`, `ParseAtom<T>`,
`ValidateAs<T>` — which ticket 11 already flagged as **type-directed codegen rather than
generics**. With `Pid[τ]` gone, there may be no surviving case that demands parametric
polymorphism proper, which materially changes this ticket's default answer.

**A phantom-parameter carve-out was considered and rejected** in §1, so if this ticket revisits
phantom types it is reopening 14's first decision, not deciding fresh ground. The recorded
alternative there is a *tagged handle* `(:order_msg, pid)` — an atom singleton per ticket 10
making the two handles genuinely different sets — which is the non-generic way to get the same
distinction and remains available.

## Input from David — 2026-08-12

> "Generics in Elixir are modelled via protocols and behaviours. I don't think generics are
> particularly required on BEAM, think `Enum`, `Stream` etc."

**Half of this is already banked, and the other half is contradicted by `Enum`'s own spec.**
Both measured locally (Elixir 1.19.5, Gleam 1.18.1, OTP 28).

**Ad-hoc polymorphism — agreed, and ticket 09 settled the mechanism.** `Enumerable` is a genuine
protocol with four callbacks (`count/1`, `member?/2`, `reduce/3`, `slice/1`), dispatching on
`__struct__` — an atom *in the data*, which is precisely ticket 09's remedy and ticket 16's
resolution key. No type parameters are involved anywhere in it.

**Parametric polymorphism — `Enum` is evidence the other way.** Its real spec, read from the beam:

```
Enum.map/2 :: map(t(), (element() -> any())) :: list()
              element() :: any()
              t()       :: Enumerable.t()
```

Elixir does not *avoid* the type parameter; it **discards the information**. `map` cannot relate
the output list's element type to the input's, so it says `list()` and stops. That is free in a
dynamically typed language because there was no static element type to lose. Gleam — the
statically typed BEAM neighbour — keeps it, and the parameter survives into the emitted Erlang:

```gleam
pub fn map(list: List(a), with fun: fn(a) -> b) -> List(b)
```
```erlang
-spec map(list(ACJ), fun((ACJ) -> ACL)) -> list(ACL).
```

So the split is **static versus dynamic, not BEAM versus not**, and beam-sharp is on Gleam's side
of it.

**Why the cost lands harder here than elsewhere.** Without type variables, `Map` is
`(list<term>, term -> term) -> list<term>` — and ticket 11 makes a `term` the thing you must
narrow with a clause head before use. Mapping over a list of orders would return something the
caller has to re-validate. The tax falls on the commonest operation in the language, not on an
exotic corner.

**The real argument in the neighbourhood, which this ticket should weigh.** Polymorphic
set-theoretic types are exactly where **tallying** is required, and ticket 04 found tallying has
**no complexity bound in the literature**. So parametric polymorphism may be the feature that makes
checker cost unpredictable — a cost argument, not a platform one.

**And the middle path**, already gestured at by ticket 11 when it called `ParseAtom<T>` and
`ValidateAs<T>` "type-directed codegen, not generics": **monomorphise per call site**. That
preserves element types without asking the checker to solve for a variable. Note the prelude's
`option<T>` (ticket 10) is already parametric *syntax* — whether it denotes real polymorphism or
expansion is exactly what this ticket decides.

**Do not re-derive**: ticket 14 already removed `Pid[τ]`, the map's clearest demand for a genuine
type parameter. Collections are now the strongest surviving case, so this ticket largely turns on
what the type of `Map` is.

---

## Answer — resolved 2026-08-12

**The language has real parametric polymorphism, and it is the smallest version of it that
works.**

The ticket's question was three questions wearing one coat, and only one was live: parameterised
*constructors* (`list<int>`) were already forced by tickets 09 and 11 and are not polymorphism at
all, parametric *aliases* (`option<T>`) arrived near-settled from ticket 10, and only
**polymorphic function signatures** were open. Yes to those — on a cost argument the map must now
protect: the frightening results attach to *inference* and to *intersection-typed* functions, and
**beam-sharp had already refused both for unrelated reasons** (04 made signatures mandatory; 08
settled one arrow per arity with union parameters, so a function type is `(A|B) -> (C|D)`, never
`(A->C) & (B->D)`). Instantiation is therefore **matching, not solving** — and §3's unboundedness
and §7's refusal of row polymorphism are what keep that true, not independent preferences.

**Four rules.** Type variables are **opaque in clause heads and guards** — a bare variable admits
exactly one clause, so bind it; structure *around* it matches freely, which is why `Map`'s `[]`
and `[h, ..t]` are exhaustive at the definition for every instantiation. They are **unbounded**,
with capability constraints deferred to ticket 16, because a bound is *ad-hoc* polymorphism
wearing a bracket. They are **declared, on C#'s `T` convention** — forced rather than chosen,
because beam-sharp's builtins are lowercase, so lowercase-implicit is ambiguous here where
Gleam's is not. And **variance is not a concept**, since ticket 09's abolition of nominality
leaves nothing to annotate and nothing to infer.

**Rejected: monomorphise per call site.** It fights ticket 13's aggregate granularity, and works
*inside* an aggregate while failing exactly where a shared `List.Map` lives. That leg originally
cited ticket 13's standing obligation that the frontend never depend on in-process compiler
state; **the citation was wrong and is corrected 2026-08-27** — the obligation forbids in-process
state, not a build-time pass over sources — and the leg survives on a different fact the prose
never stated: **knowing every module in the transitive `using` closure is not knowing every
instantiation**, since a caller may sit outside it. See §1 above and ticket 16's amendment of the
same date.

**Two measurements.** An emitted polymorphic `-spec` is **documentation, not enforcement** —
Dialyzer reads the variables as `any()` and stays silent where the monomorphic control fires — so
**choosing generics made the boundary strictly weaker → ticket 18**. And **syntax recovers an
element-type relation with zero polymorphism**: `roundtrip` preserves `[integer()] -> [binary()]`
where the same computation through an opaque fun collapses to `[any()]`, which is why row
polymorphism was declined — `with`/spread already covers the case that would demand a row
variable.

**Forced consequences.** **Codegen obligations require a ground type argument**, so
`ValidateAs<TSource>` is rejected inside a polymorphic function; and **polymorphic recursion is
permitted**, because ticket 04 already paid for mandatory signatures — the undecidability is about
inference. **Ticket 16 is unblocked**, and inherits the rule that names its own boundary: *a type
variable is a slot for values you carry; a union is a slot for values you examine.*

**The language has real parametric polymorphism, and it is the smallest version of it that
works.** Type variables are declared, opaque, unbounded, and never annotated for variance.
Seven decisions.

The ticket's own question — *"does the language have generics at all?"* — turned out to be three
questions wearing one coat, and only the third was live. Do not re-derive the split.

- **(a) Parameterised type constructors** — `list<int>`, `map<string, Json>`, `list<term>`.
  **Already forced**, and not polymorphism: `list<int>` is a ground type with no variable in it.
  Ticket 09 writes both in the `Json` example; ticket 11 makes `list<term>` versus `list<int>`
  the guard-decidability boundary. A "no generics" answer would have required re-spelling three
  closed tickets.
- **(b) Parametric aliases** — `type option<T> = T | :nothing;` (ticket 10 §5). A variable at the
  declaration only; `option<int>` expands to `int | :nothing` and the variable is gone before the
  algebra sees it. Consistent with ticket 09's "the name never enters the algebra". **Near-settled
  on arrival**, and confirmed here.
- **(c) Polymorphic function signatures** — a variable quantified in a *value*-level signature,
  instantiated at each call site. **This was the live question**, and the answer is yes.

The costs are asymmetric and they do not chain: declining (c) would have left (a) and (b)
untouched. What (c) buys is exactly one thing — the ability to relate a function's output type to
its input type — and that one thing is the shared container library.

## 1. Yes to prenex parametric polymorphism, on a cost argument the other decisions must protect

The literature's frightening results attach to **inference** (type reconstruction is undecidable,
[79]) and to **intersection-typed functions** (where tallying instances get large). beam-sharp has
neither, and not by luck:

- **Ticket 04 made signatures mandatory** for multi-clause functions — inference is not being
  asked for.
- **Ticket 08 settled one arrow per arity**, dispatching on a *union parameter* rather than
  overload signatures. So a beam-sharp function type is `(A|B) -> (C|D)`, never
  `(A->C) & (B->D)`. The intersection arrow, which is where tallying gets nasty, was already
  refused for unrelated reasons.

What remains is instantiating a *declared* prenex polymorphic arrow at a call site: match
`list<Order>` against `list<TSource>`, read off `TSource = Order`. Structural, cheap, unique
answer.

**This is the premise the rest of the ticket exists to protect.** Decisions 3 (unbounded) and 7
(no row polymorphism) are not independent preferences — each is the thing that keeps instantiation
a matching problem rather than a constraint-solving one. Reopening either reopens this.

**The cost of saying no, for the record, since it is why the answer is yes.** Without (c), `Map` is
`(list<term>, fn(term) -> term) -> list<term>`, and ticket 11 makes a `term` something you must
narrow with a clause head before use. Recovering `list<Money>` needs `ValidateAs<list<Money>>` — an
**O(n) traversal of data that never left the program**. Declining (c) does not cost ergonomics; it
turns an internal operation into a boundary crossing.

**Rejected: monomorphise per call site.** The ticket named this as the middle path and it does not
survive contact with ticket 13. A specialisation has to be emitted somewhere. In the *caller's*
aggregate: `List` no longer owns its own code, a fix to `Map` requires recompiling every caller,
and hot-loading `List` updates nothing — against ticket 13 §3, which chose the aggregate as **the
consistency unit** for hot code loading, deliberately. In `List`'s *own* aggregate: you must know
every instantiation when `List` is compiled, which is whole-program compilation. This originally
read "against ticket 13's standing obligation that the frontend never depend on in-process compiler
state"; **that citation was wrong and is corrected 2026-08-27** — the obligation forbids in-process
state, not a build-time pass over sources, and `bsc` already walks the transitive `using` closure
(`bsc.erl:278`). The leg survives on a different fact the prose never stated: **knowing every module
in that closure is not knowing every instantiation**, since a caller may sit outside it. See ticket
16's 2026-08-27 amendment for the full re-derivation. Monomorphisation
is a whole-program technique (Rust, C++, MLton); the BEAM is separately compiled and hot-swappable
per module. **It works inside an aggregate and fails at exactly the boundary where a shared
`List.Map` lives.**

## 2. Type variables are opaque in clause heads and guards

**A bare type-variable parameter admits exactly one clause: bind it.** No pattern test, no guard.
Structure *around* a variable matches freely.

```csharp
list<TResult> Map<TSource, TResult>(list<TSource>, fn(TSource) -> TResult);

([], _)       -> [];
([h, ..t], f) -> [f(h), ..Map(t, f)];
```

Exhaustive **at the definition**, for every instantiation, because `list<TSource>` is
`[] | [TSource, ..list<TSource>]` regardless of what `TSource` is. `h` has type `TSource`: bound,
handed to `f`, never inspected.

```csharp
option<TSource> First<TSource>(list<TSource>);
([])      -> :nothing;
([h, ..]) -> h;

TSource Identity<TSource>(TSource);
(x) -> x;                              // the only clause a bare variable admits
```

Rejected:

```csharp
TSource Pick<TSource>(TSource, TSource);
(x, _) when is_integer(x) -> x;        // ✗
(_, y)                    -> y;
```

```
error: guard inspects a value whose type is the variable `TSource`
  is_integer/1 tests a runtime shape, and `TSource` has no shape until a caller chooses one
  hint: to dispatch on shape, take a union parameter instead of a type variable
```

**Two reasons, and the second is the one that generalises.**

*The signature stops being a promise.* `TSource Pick<TSource>(TSource, TSource)` tells a reviewer
the whole story only if the variable is opaque: it returns one of its arguments, and which one
cannot depend on the type. Allow the test and `Pick(1, 2)` returns `2` while `Pick("a", "b")`
returns `"a"` — from a **character-for-character identical signature**. Under a standing constraint
that puts full weight on review cost, that is a signature that lies to its reviewer.

*Reachability stops being answerable where the function is defined.* Given

```csharp
string Describe<TSource>(TSource);
(x) when is_integer(x) -> "a number";
(x)                    -> "something else";
```

clause 2 is dead under `Describe<int>` and clause 1 is dead under `Describe<string>`. The compiler
checks the function once, at its definition, where it knows neither. Its three options are all bad:
say nothing (lose the check for every polymorphic function), warn about both (each is dead
*sometimes*), or defer to call sites (the warning lands in a different file from the code it is
about). **This is ticket 04's distinction biting**: exhaustiveness is absolute and answerable at
the definition; redundancy is relative. Type variables push redundancy out of reach of the only
place it can usefully be reported — and ticket 04's finding that the residual *is* the missing
clause is worth nothing to an agent if the reachability warning beside it is true half the time.

**This is a tier-3 divergence and is recorded as one.** C# permits `if (x is int i)` on a `T`;
TypeScript narrows a generic with `typeof`. Both audiences will expect the permissive rule and must
be told. The reason it is affordable here and not there: the check must run at the *definition*,
which is a constraint the map imposed on itself with ticket 04, not one Castagna imposed.

**The rule in one line, which ticket 16 inherits**: *a type variable is a slot for values you
carry; a union is a slot for values you examine.* Parametric and ad-hoc polymorphism get separate
spellings that cannot be confused.

## 3. Variables are unbounded — capability constraints are ticket 16's

No `where TSource <: ...`. A variable ranges over all types.

A bound is almost always "this type must support some operation" — comparison, arithmetic,
printing. **That is ad-hoc polymorphism wearing a bracket**, and ticket 09 already handed ticket 16
its mechanism (dispatch on an atom in the data, Elixir's `__struct__` pattern, resolvable
statically here where Elixir needs a consolidation pass). Adding bounds in 27 would pre-decide 16
badly — routing capability constraints through type-variable syntax before 16 has chosen how
capabilities are expressed at all.

It is also what keeps §1's cost argument true. Bounds turn each call site into an accumulated
constraint set to be solved; unbounded variables keep instantiation a matching problem.

**The cost is honest**: no generic `Max` or `Sum` until 16 resolves. Available in the meantime —
`MaxInt`/`MaxFloat`, a union parameter, or **passing the capability as an argument**:
`TSource Max<TSource>(TSource, TSource, fn(TSource, TSource) -> bool)` needs no bound, because the
capability arrives as a value. That is the same move ticket 14 made putting the message type on the
client API function rather than on the pid.

**Deferred-option requirements** — what bounds would need if ticket 16 wants them:

1. A syntax that does not collide with `when` (guards) or with `type X = ...` (aliases).
2. A decision on whether a bound may mention another variable (`TA <: TB`), which is what
   separates a finite check from general constraint solving.
3. A cost measurement at showcase clause counts, since bounds are the feature that makes
   instantiation a solving problem — this joins the walking skeleton's measurement list.
4. A rule for what a bound publishes to the Erlang world, given §6 below.

## 4. Variables are declared, and named with C#'s `T` convention

```csharp
list<TResult> Map<TSource, TResult>(list<TSource>, fn(TSource) -> TResult);
```

**Declaration is forced, not chosen**, by a fact about this language that neither neighbour shares:
**beam-sharp's builtin type names are lowercase** — `int`, `float`, `string`, `atom`, `term`,
`none`, `bool`, `list`, `map` — while user types are PascalCase.

- **Lowercase-implicit** (Gleam, ML) is ambiguous here: in `list<a>`, is `a` a variable or a
  builtin you have not met? Gleam escapes this only because *its* builtins are `Int` and `Float`.
- **Uppercase-implicit** (Erlang's own specs, `-spec map([A], fun((A) -> B)) -> [B]`) is worse:
  `Order` in a signature would become a fresh variable rather than your type.

So variables must be declared — which is also what C# and TS both require, so no divergence is
spent. **Naming follows C#'s convention** (`T`, `TSource`, `TKey`, `TValue`), matching what tickets
10 and 11 already wrote on the page: `option<T>`, `ValidateAs<T>`, `ParseAtom<T>`. Naming is
**convention, not a language rule**, consistent with ticket 08's stance on short-name collisions.

Rejected: lowercase-declared (`Map<a, b>`), which reads more lightly inside a dense signature but
costs consistency with three already-written prelude entries; and single uppercase letters
(`Map<T, U>`), which read as type names in a language where `Order` is a type — the ambiguity C#'s
`T`-prefix convention exists to avoid.

## 5. Variance is not a concept in the language

No `in`/`out`, and nothing inferred either — **there is nothing to infer.**

C# needs variance annotations because its interfaces are **nominal**: the compiler is *told* that
`IEnumerable<Order>` is usable as `IEnumerable<term>`. Ticket 09 abolished nominality — a type *is*
the set of its values and subtyping is plain set containment, decided coinductively. So
`list<Order> ≤ list<term>` holds because every value in the first set is in the second, not because
`list` was declared covariant. Ticket 11's measured arrow contravariance
(`subtype?(fn(int)->int, fn(none)->term) = true`, `subtype?(fn(int)->int, fn(term)->term) = false`)
is the same phenomenon: nobody declared it and nobody could have declared it otherwise.

Variance is emergent *description*, like "integers are ordered" — not machinery. The only thing
that would need an annotation is a type whose body the compiler cannot see, and ticket 09 abolished
those too.

**Carries one obligation**: when a containment check fails for a variance-shaped reason, the
diagnostic must **name the position that went the wrong way**, not print two type expressions and
leave an agent to diff them. Standing constraint, applied.

## 6. An emitted polymorphic `-spec` is documentation, not enforcement — measured

The ticket asked to *confirm rather than assume* what a polymorphic function publishes to the
Erlang world under ticket 13 §6. Measured on OTP 28.5 with `dialyzer` against a PLT of
erts/kernel/stdlib — [`prototypes/27b_polymorphic_spec_enforcement.erl`](../prototypes/27b_polymorphic_spec_enforcement.erl),
control at [`27c`](../prototypes/27c_polymorphic_spec_control.erl):

```erlang
-spec map([A], fun((A) -> B)) -> [B].              %% Ys is [binary()]; hd(Ys) + 1  ->  SILENT
-spec map_mono([integer()], fun((integer()) -> binary())) -> [binary()].
                                                   %% hd(Ys) + 1  ->  CAUGHT
```

The control fires, so the probe is sensitive and the negative result is real. **Erlang's spec
grammar accepts type variables; Dialyzer does not enforce the relation across them** — it reads `A`
and `B` as `any()`.

Three consequences:

1. **Not a widening problem.** Ticket 13 §6 obliges widening where a set-theoretic type has no
   Erlang spelling; parametric types *have* one (Gleam emits `-spec map(list(ACJ), fun((ACJ) ->
   ACL)) -> list(ACL)`). The spec is emitted faithfully and is simply inert as a check.
2. **A ninth face of ticket 06's silent unsoundness, and it is a regression.** A raw Erlang caller
   of a *monomorphic* beam-sharp function at least gets a Dialyzer warning if it runs Dialyzer; a
   caller of a polymorphic one gets nothing. **Choosing generics made the boundary strictly weaker,
   not neutral.** → ticket 18 must not count the emitted spec as a defence for polymorphic
   functions.
3. **Not an argument against the decision.** Dialyzer is opt-in, and ticket 06 already established
   that neither Gleam nor purerl defends against any of the eight channels.

## 7. No row polymorphism — and the reason is a measurement, not a retreat

No row variables. A function generic over *any record containing at least these fields* is not
expressible.

Decisions 3 and 2 already close the two doors it could arrive through — it cannot come as a bound,
and it cannot come by inspection — so it would need to be a **second kind of variable**
(`{ Total: Money | r }`), which is new machinery rather than an extension of anything decided.

Ticket 04's research flagged this as sitting directly on beam-sharp's path: *"an open problem we
are working on"*, with tallying completeness achieved only for restricted solution shapes, and the
note **"every OTP state map wants it"** ([86]). That worry is weaker here than it looks, for the
same reason `Map` turned out to be:

- A gen_server's state type is **concrete per module** (ticket 14), so nothing generic types it.
- Record update is `with` / spread — **syntax**, which types structurally against a known record
  type with no variable involved.

That second point is [`prototypes/27a`](../prototypes/27a_comprehension_vs_hof_typing.erl)'s
finding generalised, and it is why 27a remains load-bearing even though the ticket chose generics:
*syntax recovers an element-type relation with zero polymorphism*, measured — `roundtrip` preserves
`[integer()] -> [binary()]` under an analysis with no type variables at all, while the same
computation through an opaque fun argument collapses to `[any()]`. **The operation you would reach
for a row variable to express is already covered by a construct the compiler writes the typing rule
for.**

What genuinely is not expressible: a shared function over unrelated record types that happen to
share a field. That is "this type must support something" — decision 3's territory, → ticket 16.

**Deferred-option requirements**: row variables would need a spelling distinct from `T`-style
variables (they range over field sets, not types); a rule for whether a row variable may appear in
a clause head, which §2 would answer no; and a resolution to the completeness gap the literature
records. → also flagged to ticket 26.

## 8. Consequences that are forced rather than chosen

**Codegen obligations require a ground type argument.** `ValidateAs<T>` and `ParseAtom<T>` now look
exactly like generic calls and are not — they are type-directed codegen, monomorphic at every use.
You cannot generate a structural check for a type nobody has chosen yet, so
`ValidateAs<TSource>` inside a polymorphic function is **rejected at compile time**. This joins
ticket 11's existing rule that `ValidateAs<T>` rejects arrows, and it is a *good* error: it catches
a real misconception at the point it is made. Ticket 11's caution that neither mechanism is evidence
of generics survives the decision intact — generics exist, and these are still not it.

**Polymorphic recursion is permitted, and `Map` is not an instance of it.** Distinguish carefully:

```csharp
([h, ..t], f) -> [f(h), ..Map(t, f)];       // ordinary recursion AT THE SAME variables
```

`Map` calls itself at the `TSource`/`TResult` currently bound — monomorphic recursion inside a
polymorphic function. *Polymorphic* recursion is calling yourself at **different** variables
(`f<T>` invoking `f<list<T>>`). Ticket 04's research records that **inferring** it is long known
undecidable ([88]) — but ticket 04 also made signatures mandatory, and the undecidability is about
inference. A declared polymorphic signature makes a polymorphically-recursive function
straightforwardly *checkable*. **The map gets this for free because it already paid for mandatory
signatures.**

**Exhaustiveness is unharmed; redundancy is protected by §2.** Exhaustiveness over parametric
structure is provable once, at the definition, for all instantiations — `list<TSource>` decomposes
identically whatever `TSource` is. Redundancy stays well-posed only because variables are opaque.

## Surface syntax used above — provenance

- Signature carries **types only, no parameter names**; clauses **do not repeat the function
  name** — ticket 08, settled table and used consistently across its examples
  (`(n) when n > 0 -> ...`, `() -> GenServer.StartLink(...)`).
- Clause arrow is `->`, not ticket 01's `=>` — map Notes, under the widened C#/TS audience.
- `..` spread is a borrowed C# collection expression — map Notes.
- **Provisional**: the *pattern* spelling `[h, ..t]` for prefix-plus-rest. Ticket 08 settles the
  restriction but pins no spelling; `[h, ..t]` follows C#'s `[first, ..rest]` and should be
  confirmed when the grammar is written.

## Not decided here

- **Whether `List.Map` and friends are prelude stratum 1 or 2** (ticket 14 §6). With generics, they
  are now definitions a user *could* have written, which moves them toward stratum 1 and changes
  the fog's prelude question. Not this ticket's call.
- **Bounds** (§3) and **row polymorphism** (§7) — deferred with requirements captured above.
- **Inference of type arguments at call sites**, and **the parser consequence this ticket listed
  and did not answer** — `<` is also a comparison operator, and ticket 08 settled `&&`/`||` guards
  with comparisons, so `F(a < b, c > d)` is ambiguous. Every example above writes type arguments
  nowhere and relies on them being recovered by matching; the rule for when a call site must
  *write* `Map<Order, Money>(...)` explicitly is unstated, and may decide how large the parsing
  problem is. → **[ticket 28](28-generic-bracket-parsing.md)**, raised here, which also inherits
  the provisional `[h, ..t]` spelling.

## Debt discharged by ticket 16 — 2026-08-12

**§3 deferred capability constraints to [ticket 16](16-ad-hoc-polymorphism.md). The answer is
"refused", and all four requirements are addressed rather than carried.**

Bounds have **no implementable meaning** in this language. A bound is only worth writing if the
body can *call* the bounded capability; calling a generated capability on `T` inside a polymorphic
function needs either one copy per instantiation — the monomorphisation §1 already rejected against
ticket 13's aggregate granularity — or a runtime dictionary, which needs the nominal resolution key
ticket 09 removed. Both routes closed, so a bound would be undischargeable.

**Requirement 3 — the cost measurement at showcase clause counts — is retired.** §3 called it "the
serious one" and made bounds conditional on it. The feature it gated is refused for a structural
reason, so the walking skeleton no longer owes that number. **Instantiation stays matching, not
solving**, now protected by four refusals rather than three.

**§2's opacity rule gains a stated limit.** Ticket 16 §5 permits `<`, `>`, `<=`, `>=` and `==` on
two values of the same bare type variable, so `Sort<T>` and `Max<T>` need no constraint at all.
This is not a hole in opacity: opacity exists so a generic function cannot **dispatch** on its `T`,
and ordering is not dispatch — it returns a bool, reveals nothing about the shape, and cannot fail,
because the BEAM's term order is total over every term (measured:
[`prototypes/16b_which_capabilities_are_already_primitive.erl`](../prototypes/16b_which_capabilities_are_already_primitive.erl)).

**§6's finding is amplified, not softened.** The inert polymorphic `-spec` now has a second
consumer: ticket 16's generated encoder trusts a declared type the Erlang boundary does not
enforce → [ticket 18](18-boundary-defence.md).

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Parametric polymorphism](issues/27-parametric-polymorphism.md) — **the language has real
  parametric polymorphism, and it is the smallest version of it that works.** The ticket's question
  was three questions wearing one coat, and only one was live: parameterised *constructors*
  (`list<int>`) were already forced by 09/11 and are not polymorphism at all, parametric *aliases*
  (`option<T>`) arrived near-settled from 10, and only **polymorphic function signatures** were
  open. Yes — on a cost argument the map must now protect: the frightening results attach to
  *inference* and to *intersection-typed* functions, and **beam-sharp had already refused both for
  unrelated reasons** (04 made signatures mandatory; 08 settled one arrow per arity with union
  parameters, so a function type is `(A|B) -> (C|D)`, never `(A->C) & (B->D)`). Instantiation is
  therefore matching, not solving — and **§3 unbounded and §7 no-row-polymorphism are what keep
  that true**, not independent preferences. Four rules: variables are **opaque in clause heads and
  guards** (a bare variable admits exactly one clause — bind it; structure *around* it matches
  freely, so `Map`'s `[]`/`[h, ..t]` are exhaustive at the definition for every instantiation);
  **unbounded**, with capability constraints deferred to ticket 16 because a bound is *ad-hoc*
  polymorphism wearing a bracket; **declared, C# `T`-convention** — forced, because beam-sharp's
  builtins are lowercase, so lowercase-implicit is ambiguous where Gleam's is not; and **variance
  is not a concept**, since 09's abolition of nominality leaves nothing to annotate or infer.
  *Rejected: monomorphise per call site* — it fights ticket 13's aggregate granularity, and works
  *inside* an aggregate while failing exactly where a shared `List.Map` lives. <!-- the "and hot
  loading / separate compilation" half of this line cited 13's standing obligation; corrected
  2026-08-27, see 27's leg B and 16's amendment of that date --> Two measurements: **an emitted polymorphic `-spec` is documentation, not
  enforcement** (Dialyzer reads the variables as `any()`; the monomorphic control fires), so
  **choosing generics made the boundary strictly weaker → ticket 18**; and **syntax recovers an
  element-type relation with zero polymorphism** (`roundtrip` preserves `[integer()] -> [binary()]`
  where the same computation through an opaque fun collapses to `[any()]`), which is why row
  polymorphism was declined — `with`/spread already covers the case that would demand a row
  variable. Forced consequences: **codegen obligations require a ground type argument**, so
  `ValidateAs<TSource>` is rejected inside a polymorphic function; and **polymorphic recursion is
  permitted** because 04 already paid for mandatory signatures — the undecidability is about
  inference. **Ticket 16 is unblocked**, and inherits the rule that names its own boundary: *a type
  variable is a slot for values you carry; a union is a slot for values you examine.*
```
