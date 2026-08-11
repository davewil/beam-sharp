# 05 — C# functional feature inventory: what survives without OOP and the CLR

Research for [ticket 05](../issues/05-csharp-functional-inventory.md) · 2026-08-11
Covers C# through **C# 14** (shipped with .NET 10, November 2025), with C# 15 (.NET 11,
in preview as of August 2026) flagged separately wherever it changes the picture.

---

## 0. The target, and the rule that decides the verdicts

Everything below is judged against a specific target, not against "a functional language"
in general. The target is the language of [ticket 00](../issues/00-charting-decisions.md):

- **No object model.** No classes-as-instances, no inheritance, no virtual dispatch, no
  interfaces, no `this`. Functions live in modules.
- **No CLR.** No reified generics, no boxing, no `System.*` types, no attributes-as-metadata,
  no `Span<T>`, no pointers.
- **Immutable.** No variable is ever rebound in place; every "update" allocates a new value
  with structural sharing.
- **Strict.** Every expression is evaluated when reached. There is no thunk unless one is
  built explicitly.
- **Structural data.** Values are integers, atoms, binaries, tuples, lists, maps and funs.
  They carry no nominal type identity — a three-tuple is a three-tuple, whatever it was
  declared as.
- **Functions are identified by name *and arity*.** `foo/2` and `foo/3` are different
  functions, not overloads of one.
- **Multi-clause heads with pattern destructuring**, checked for exhaustiveness by a
  set-theoretic type system.

### The verdict rule

The three verdicts are about whether the **language feature** survives, not whether a
library could reproduce the effect. Almost anything can be reproduced by a library; that
test would mark everything portable and tell us nothing.

| Verdict | Means |
|---|---|
| **portable** | The feature carries over as a language feature with its meaning intact. Syntax may change; the thing it *is* does not. |
| **portable-altered** | The surface survives and is still worth having, but the mechanism underneath must be re-grounded in something the BEAM has. The row says what alters. |
| **droppable** | The feature exists to solve a problem this language does not have — it is load-bearing on the object model, the CLR, mutation, or laziness. Dropping it leaves no gap. |

### The "depends on" flags

Read these as *what the feature is grounded in*, so downstream tickets can filter rows:

`OOP` object model · `CLR` .NET runtime or BCL types · `MUT` mutation ·
`LAZY` lazy evaluation · `IFACE` interface dispatch · `NOM` nominal type identity ·
`PB` pattern-based/syntactic (the compiler binds by *name*, not by interface) ·
`—` none of these

`PB` is the most consequential flag in the document. A surprising number of C# features
that *look* like they need the type system need only a **name**. Those are the portable ones.

---

## 1. LINQ, decomposed

The brief asks how much of LINQ is really about `IEnumerable<T>` and extension-method
resolution, and what is left if both are removed. This is also the map's open fog
("whether anything LINQ-shaped survives"). The answer is that LINQ is **three separable
things**, and only one of them is a language feature at all.

### Axis (a) — Query syntax is a purely syntactic rewrite. It needs no interface.

The C# standard is explicit, and stronger than most write-ups suggest:

> "The C# language does not specify the execution semantics of query expressions. Rather,
> query expressions are translated into invocations of methods that adhere to the
> query-expression pattern. Specifically, query expressions are translated into invocations
> of methods named `Where`, `Select`, `SelectMany`, `Join`, `GroupJoin`, `OrderBy`,
> `OrderByDescending`, `ThenBy`, `ThenByDescending`, `GroupBy`, and `Cast`. […] These methods
> may be instance methods of the object being queried or extension methods that are external
> to the object."
> — [ECMA-334 §12.22.3.1](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12223-query-expression-translation)

> "**The translation from query expressions to method invocations is a syntactic mapping that
> occurs before any type binding or overload resolution has been performed.**"
> — [ECMA-334 §12.22.3.1](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12223-query-expression-translation)

And `IEnumerable<T>` appears in the specification of the query-expression pattern only in a
**note**, describing what a *library* happens to provide:

> "*Note*: The `System.Linq` namespace provides an implementation of the query-expression
> pattern for any type that implements the `System.Collections.Generic.IEnumerable<T>`
> interface. *end note*"
> — [ECMA-334 §12.22.4](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12224-the-query-expression-pattern)

**Consequence for this language.** `from … where … select …` is a macro over eleven method
names. It requires no interface, no dispatch, no type class, and no runtime support. It
requires exactly one thing this language must supply anyway: **a rule for resolving eleven
names in the current scope**. Query comprehension is therefore *portable*, and it is the
part of LINQ most worth keeping — it is the only part that is a language feature.

### Axis (b) — `IEnumerable<T>` is interface dispatch, and it is not doing the work you think

`IEnumerable<T>` never dispatched the query. Extension-method invocation is a **static
rewrite**: `expr.M(args)` becomes `C.M(expr, args)`, where `C` is found by walking enclosing
namespaces and `using` directives — a purely lexical search
([§12.8.10.3](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#128103-extension-method-invocations)).
The receiver is just the first argument; the spec even notes that a `null` receiver throws
nothing, because no dispatch occurs. `IEnumerable<T>` is only the *constraint* that selects
which set of static functions is applicable.

**Consequence.** Removing `IEnumerable<T>` removes a constraint, not a mechanism. The
mechanism that remains — receiver becomes first argument, name resolved lexically — is
**already a pipeline**. `xs.Where(f).Select(g)` and `xs |> where(f) |> select(g)` are the
same rewrite with different punctuation. This is the sharpest available input to the map's
pipelines fog and to [ticket 08](../issues/08-head-and-guard-syntax.md).

### Axis (c) — Deferred execution belongs to the *implementations*, not the language

Nothing in the query-expression specification mentions laziness. Deferral is a property of
what `System.Linq.Enumerable`'s methods return:

> "Those methods that return a singleton value (such as `Average` and `Sum`) execute
> immediately. Methods that return a sequence defer the query execution and return an
> enumerable object."
> — [Standard query operators overview](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/)

Microsoft's own collection-expressions documentation draws the contrast explicitly:

> "A collection expression always creates a collection that includes all elements in the
> collection expression […] This behavior is distinct from LINQ, where a sequence might not
> be instantiated until it is enumerated. You can't use collection expressions to generate an
> infinite sequence that won't be enumerated."
> — [Collection expressions](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/collection-expressions)

**Consequence.** On a strict runtime, laziness must be *explicit*, exactly as Elixir splits
`Enum` (eager) from `Stream` (lazy). This is a stdlib-shape decision, not a language one, and
it is the one place where a naive LINQ port would silently change performance
characteristics: an eager `where |> map |> take(5)` over a large list does all the work.

### What is left when both are removed

| Removed | What dies | What survives |
|---|---|---|
| `IEnumerable<T>` | the applicability constraint; the illusion of dispatch | the whole comprehension surface |
| Extension methods | the receiver-first *syntax* | the receiver-first *semantics* — i.e. a pipe operator |
| Deferred execution | infinite sequences; free short-circuiting | everything else, at eager cost |

What is left is **a comprehension syntax over a named set of functions** — which is to say,
Erlang list comprehensions with an SQL-ish surface and a `group by`/`join` that Erlang
lacks. That is a real feature and a genuinely differentiated one. It is not "LINQ", and
calling it LINQ would import expectations about laziness that the runtime cannot meet.

---

## 2. Inventory

### A. Query and sequences

| Feature | What it is | Depends on | Verdict | BEAM equivalent or obstacle |
|---|---|---|---|---|
| LINQ query syntax | `from/where/select/group/join/orderby/let` comprehension | `PB` | **portable** | Syntactic rewrite to 11 names, resolved before type binding. Needs only a name-resolution rule. Nearest kin: Erlang list comprehensions; `join`/`group by` have no Erlang equivalent and would be new. |
| LINQ method syntax | `xs.Where(f).Select(g)` fluent chain | `PB`, `IFACE` (by convention only) | **portable-altered** | The chain *is* the pipeline. Becomes `\|>` or UFCS. What alters: the dot no longer implies a member, so the reader loses the "is this mine or an extension?" ambiguity — an improvement. |
| `IEnumerable<T>` | the sequence interface every operator is constrained to | `IFACE`, `CLR` | **droppable** | No interface dispatch on the BEAM. Replace with a set-theoretic constraint on the receiver type, or nothing at all — the syntactic rewrite never needed it. |
| Deferred execution | operators return an unevaluated enumerable | `LAZY`, `MUT` | **portable-altered** | Strict runtime. Requires an explicit stream type (Elixir's `Stream`), or accept eagerness. Cannot be the default and cannot be invisible. |
| Extension methods (`this` param) | static method callable as instance method | `PB`, `OOP` (cosmetically) | **portable-altered** | Already a static rewrite `C.M(expr, args)` resolved by `using` directives, not dispatch. Survives as a pipe operator; the `this` modifier and the "must be in a non-generic non-nested static class" rule are pure OO scaffolding. |
| Extension members / extension blocks (C# 14) | `extension(T x) { … }` adding properties, static members, operators | `OOP` | **droppable** | Exists so a static helper can *look like* an instance member. With no instance members, there is nothing to imitate. Extension **indexers** (C# 15 preview) likewise. |
| Iterators / `yield return` | function that produces a sequence lazily | `MUT`, `LAZY`, `CLR`, `IFACE` | **droppable** in this form | Compiles to a **mutable state machine**: an enumerator object with four states (*before*, *running*, *suspended*, *after*) advanced by `MoveNext`. Nothing on the BEAM suspends a stack frame in place. Equivalents: a generator **process** with `receive`, or `Stream.resource/3`-style unfolds. Both are different features with different costs. |
| `foreach` | iteration statement | `PB` | **portable-altered** | Already pattern-based: member lookup for `GetEnumerator`, interface only as fallback. Becomes recursion, comprehension, or `Enum.each`. Loses nothing. |

### B. Data and immutability

| Feature | What it is | Depends on | Verdict | BEAM equivalent or obstacle |
|---|---|---|---|---|
| `record` (positional) | data declaration with synthesized members | `NOM`, partly `OOP` | **portable-altered** | The *declaration* is portable and wanted. The synthesized machinery mostly evaporates: value equality, `ToString`, and `Deconstruct` are already how BEAM terms behave. What must go: the clone method, the copy constructor, `EqualityContract`, and record inheritance ("a record can inherit from another record"). Cross-link [09](../issues/09-union-representation.md) — records lean on nominal runtime identity. |
| `with` expressions | non-destructive mutation | `—` | **portable, and *more* central** | Direct hit: Erlang `M#{k := V}` / Elixir `%{s \| k: v}`. C#'s version is a *shallow copy* via a synthesized clone method plus init-property assignment; on the BEAM shallow copy with structural sharing is the only kind there is, so the feature stops being an optimization concern and becomes the ordinary way to write. The asymmetry is worth stating: `with` is the one place C# reached toward this language, not away from it. |
| Primary constructors | parameters on the type declaration | `OOP` | **droppable** as a *constructor*; the **positional-record shape** survives as a data declaration. There is no object to construct, only a term to build. |
| `init` accessors | settable during initialization only | `MUT` (as a defence against it) | **droppable — vacuous** | Exists to carve immutability out of a mutable default. Immutable-by-default has nothing to carve. |
| `readonly` | field/struct immutability | `MUT` (as a defence) | **droppable — vacuous** | Same. |
| `required` members | caller must initialize | `OOP` | **droppable** | Becomes ordinary type checking on a data literal. |
| Nullable reference types | `string` vs `string?` + warnings | `CLR`, `PB` | **droppable as-is, mechanism worth stealing** | "The runtime behavior of your program is unchanged. Nullable reference types are entirely a compile-time feature." There is no `null` here to defend against. **But** *null-state analysis* — a two-state (`not-null` / `maybe-null`) flow analysis narrowed by assignments and null checks — is occurrence typing, and it is precisely the narrowing machinery a set-theoretic system provides natively and more generally. Cross-link [11](../issues/11-type-system-shape.md). |
| Tuples and deconstruction | `(a, b)` values; `var (x, y) = p` | `PB` | **portable** — closest 1:1 in the document | BEAM tuples are a primitive. Deconstruction in C# is pattern-based (unique instance or extension `Deconstruct` with ≥2 `out` params); here it is structural and needs no hook at all. Named tuple elements map to maps or to a record-ish tagged tuple. |

### C. Matching and dispatch

| Feature | What it is | Depends on | Verdict | BEAM equivalent or obstacle |
|---|---|---|---|---|
| Constant pattern | `1 =>`, `"a" =>`, `null =>` | `—` | **portable** | Literal patterns are native. |
| Relational patterns | `< -4.0`, `>= 10` | `—` | **portable-altered** | Erlang has no relational *patterns*; these become **guards** (`when X < -4.0`). Fine, but note the surface merges two C# concepts into one BEAM one. |
| Logical patterns `and`/`or`/`not` | pattern combinators | `—` | **portable, and a strength** | `and`/`or` map to guard `,`/`;`. `not` is the interesting one: pattern negation is exactly set complement, which a set-theoretic type system computes natively — this is a case where the chosen type machinery is *better* suited than C#'s own. |
| Property pattern | `{ Year: 2020, Month: 5 }`, incl. extended `{ Start.Y: 0 }` | `—` | **portable** | Direct hit: Erlang map patterns `#{year := 2020}`. Note C#'s property pattern requires non-null and reads *properties*; here it reads map keys, which is simpler and total. |
| Positional pattern | `(0, 0)`, `Point(> 0, > 0)` | `PB`, `NOM` | **portable-altered** | C# needs a `Deconstruct` method — "The code generated for the positional pattern calls the `Deconstruct` method." Here, tuple destructuring is structural and hook-free. What alters: the *type name* prefix (`Point2D (…)`) has no structural meaning; it becomes a tag atom. Cross-link [09](../issues/09-union-representation.md), [10](../issues/10-atoms-in-a-csharp-skin.md). |
| Type / declaration pattern | `is string s`, `Car =>` | `NOM`, `OOP`, `CLR` | **portable-altered, with real loss** | C# matches the *runtime nominal type*, including "derives from `T`, implements interface `T`". BEAM terms have no nominal identity. Becomes a guard on a structural predicate (`is_integer/1`, `is_map/1`) or a tag-atom match. Everything about inheritance and interface-implementation matching is gone. This is the single largest semantic gap in the matching section. |
| List patterns + slice `..` | `[1, 2, ..]`, `[.., > 0, > 0]` | `PB` | **portable, with one sharp obstacle** | Strongest rows in the document: cons patterns `[H\|T]` and binary patterns `<<A, Rest/binary>>` are native and go beyond C#. C#'s version needs a type that is *countable* (`Length`/`Count`) and *indexable*/*sliceable*. **Obstacle**: a slice in the *middle* or at the *end* (`[.., 2, 4]`, `['a', .. var s, 'a']`) is not expressible against cons cells or binaries in one pass — BEAM prefix-matches only. Suffix and interior slices need a length computation or a reversal, so either the compiler generates that (and hides an O(n)) or the syntax is restricted to prefixes. Decide deliberately. |
| `var` / discard patterns | `var (x, y)`, `_` | `—` | **portable** | Native. |
| `switch` expression | expression-position multi-way match | `—` | **portable — but partly subsumed** | The headline feature moves matching into the argument position. A `switch` expression is still wanted for matching things that are *not* parameters. Note C#'s non-exhaustive switch throws at runtime and only *warns* at compile time; this language enforces exhaustiveness, so the semantics differ at the point that matters most. Cross-link [04](../issues/04-crossclause-exhaustiveness.md), [12](../issues/12-totality-vs-let-it-crash.md). |
| `when` guards | arbitrary boolean guard on a match arm | `—` | **portable-altered — flag this** | C# permits **any** expression in `when`. Erlang guards are restricted to a whitelist of guard-safe BIFs (no user function calls, no side effects). If guards compile to BEAM guards, C#'s freedom is lost; if they compile to a body-level test, clause selection semantics change. Direct input to [ticket 08](../issues/08-head-and-guard-syntax.md). |
| `switch` statement | statement-position match with fallthrough | `OOP`-era C, `MUT` | **droppable** | Superseded by the expression form. |
| Operator overloading | `public static T operator +(T, T)` | `NOM`, `OOP` | **portable-altered** | Operators are `static`, declared *inside the type*, and resolved by compile-time overload resolution — a nominal hook. With structural data there is no type to hang them on. Options: fixed built-in operators only (Erlang's position), or compile-time resolution against a set-theoretic type. |
| User-defined compound assignment (C# 14) | `public void operator +=(int x)` mutating in place | `MUT` | **droppable — the purest mutation row** | Its stated purpose: "Allow user types to customize behavior of compound assignment operators in a way that the target of the assignment is modified **in-place**." Motivated entirely by avoiding allocation for `BigInteger`/tensor-sized data. An immutable runtime cannot express it and does not want to. |
| Static abstract interface members (C# 11) | `static abstract T operator ++(T)` in an interface | `IFACE`, `CLR`, `NOM` | **droppable — but it leaves a debt** | This is C#'s type-class mechanism, used for generic math: constrain `T : INumber<T>`, call `T.CreateChecked(2)`, and "the compiler resolves the correct implementation at compile time based on the type argument". It is dispatch-by-type-argument, not dispatch-by-instance. Dropping it is right — **but** if extension methods also go, this language has *no* ad-hoc polymorphism story at all. Name that gap rather than letting it fall between rows. |
| `closed` hierarchies (C# 15, **preview**) | `closed class` fixing direct descendants for exhaustive `switch` | `OOP`, `NOM` | **droppable** as a class hierarchy — **its purpose is the whole point of this project** | C# is reaching for exhaustive matching over a fixed set of alternatives *via inheritance*, because inheritance is what it has. Here, that is what the type system is for. Read as evidence, not as a feature to port. |
| `union` types (C# 15, **preview**) | `public union Pet(Cat, Dog, Bird);` | `NOM`, `CLR` | **portable-altered — the central tension** | Nominal and closed: a declared, fixed list of case types, compiled to a `struct` with `[Union]`, `IUnion`, and an `object?` `Value`, boxing value-type cases. Set-theoretic unions are structural and open. Patterns *unwrap* the union transparently, which is a good ergonomic to steal. Fully deferred to [ticket 09](../issues/09-union-representation.md) / [07](../issues/07-csharp15-and-ts-unions.md). |

### D. Functions and effects

| Feature | What it is | Depends on | Verdict | BEAM equivalent or obstacle |
|---|---|---|---|---|
| Lambdas | `x => x + 1` | `—` | **portable** | `fun(X) -> X + 1 end`. Direct. |
| Delegates | named function types (`Func<T,R>`, `delegate bool TryParse<T>(…)`) | `NOM`, `CLR` | **portable-altered** | BEAM funs are structural: a `fun` of arity 2 is a `fun` of arity 2. Keep the arrow type, drop the nominal name and the multicast/event machinery. |
| Local functions | named functions declared inside a body | `—` | **portable** | Erlang has named funs (`fun F(X) -> … F(Y) … end`), so recursion works. C#'s canonical use — separating eager argument validation from a lazy iterator body — disappears with iterators. |
| Method overloads | same name, different parameter types | `NOM`, `OOP` | **portable-altered — this is the whole project** | C# dispatches on *static* types; the BEAM dispatches on *values and structure*. [Ticket 00](../issues/00-charting-decisions.md) already records that the visual shape is reusable while the semantics invert. |
| `params` | variadic final parameter (any collection type since C# 13) | `CLR` | **portable-altered — and it collides with function identity** | BEAM identifies functions by name **and arity**. A variadic parameter makes arity indeterminate. Either it lowers to a single list-taking function of fixed arity (losing call-site ergonomics), or the compiler emits a family of arities (and the exported surface multiplies). Surfaced, not resolved — map fog. |
| Optional / default parameters | `void M(int x = 0)` | `—` | **portable-altered — same collision** | Same name/arity problem; Elixir's `\\` default-argument syntax solves it by generating one function *per arity*, which is a proven precedent worth copying. |
| `async`/`await` + `Task` | asynchronous methods | `MUT`, `CLR`, `PB` | **droppable — biggest runtime-shaped row** | An async method compiles to a **state machine** driven by an `AsyncMethodBuilder`, advanced by repeated `MoveNext()` calls; `await` is pattern-based on `GetAwaiter`/`IsCompleted`/`GetResult`/`INotifyCompletion`. The BEAM's answer is prior and different: a process blocking in `receive` costs almost nothing, so there is nothing to avoid blocking *for*. `async`/`await` exists because blocking an OS thread is expensive; that premise is false here. Cross-link [14](../issues/14-concurrency-and-otp-model.md). |
| Ranges and indices `^` / `..` | `xs[^1]`, `xs[1..3]` | `CLR`, `PB` | **portable-altered, mostly droppable for lists** | Produces `System.Index`/`System.Range` and requires a *countable* type — "an `int` property named either `Count` or `Length` with an accessible `get` accessor" — plus an indexer or `Slice`. Cons lists have neither: `Length` is O(n) and indexing is O(n). Plausible for **binaries** (`binary:part/3`) and **tuples** (`element/2`); a bad fit for lists, which is what most code holds. |
| Exceptions / `try`-`catch` | structured exception handling | `CLR` | out of scope here | See [ticket 15](../issues/15-error-model.md); interacts with let-it-crash ([12](../issues/12-totality-vs-let-it-crash.md)). |

### E. Types, generics and literals

| Feature | What it is | Depends on | Verdict | BEAM equivalent or obstacle |
|---|---|---|---|---|
| Generics | `List<T>`, `M<T>(T x)` | `CLR`, `NOM` | **portable-altered** | CLR generics are *reified*: type arguments survive to runtime and drive JIT specialization. Set-theoretic parametric polymorphism is compile-time only and erases. Type *parameters* survive; runtime type-argument reflection does not. |
| Generic constraints (`where`) | `where T : class`, `struct`, `new()`, `IFoo`, `allows ref struct` | `CLR`, `IFACE`, `OOP` | **mostly droppable** | `class`/`struct`/`new()`/`allows ref struct` are all CLR memory-model artifacts. Interface constraints are interface dispatch. What survives is the *idea* of bounding a type variable — expressed as a set-theoretic subtyping constraint, which is strictly more expressive. |
| Collection expressions `[…]` | `int[] xs = [1, 2, 3];` target-typed literal | `PB`, `CLR` | **portable** | List/map/tuple literals are native. C#'s target-typing machinery (`CollectionBuilderAttribute`, `Add` methods, `IEnumerable`) collapses to a small fixed set of literal forms. Notably C#'s version is **eager**, which matches the BEAM exactly. |
| Spread `..` in collection expressions | `[.. vowels, .. consonants, "y"]` | `PB` | **portable** | `++` / `lists:append`, or Elixir's `[h \| t]` and `%{m \| …}`. Direct. Note `..` is overloaded in C# for range, slice-pattern and spread; three meanings for one token is a syntax trap worth avoiding. |
| Collection expression arguments (C# 15, **preview**) | `[with(capacity: 8), .. xs]` | `CLR` | **droppable** | `capacity` and `IEqualityComparer` are .NET collection-implementation concerns. No analogue. |
| `field` keyword (C# 14) | access the synthesized property backing field | `OOP`, `MUT` | **droppable** | Property backing fields presuppose properties presuppose objects. |
| Null-conditional assignment (C# 14) | `customer?.Order = …` | `MUT`, `CLR` | **droppable** | Assignment plus null, neither of which exists. |
| Implicit span conversions (C# 14) | first-class `Span<T>`/`ReadOnlySpan<T>` | `CLR`, `MUT` | **droppable** | Spans are windows into mutable contiguous memory. The nearest BEAM idea, sub-binaries, is already free and invisible. |
| Labeled `break`/`continue` (C# 15, **preview**) | `continue outer;` | `MUT` | **droppable** | Presupposes loops; there are none. |
| Memory-safety / pointer relaxations (C# 15, **preview**) | `unsafe` tied to access rather than pointer types | `CLR` | **droppable** | No unmanaged memory. |

---

## 3. Features that exist principally *because* C# is object-oriented

These have no reason to exist in this language. Listing them together makes the shape of the
subtraction visible.

1. **Extension methods and extension members** — the only reason a static function needs to
   masquerade as an instance member is that C# made the dot the primary call syntax. A pipe
   operator gets the same composition with none of the resolution rules.
2. **`init`, `readonly`, `required`** — three separate mechanisms for restoring properties an
   immutable language has by default. All vacuous here.
3. **Primary constructors** — objects need constructing; terms do not.
4. **The `field` keyword and property backing fields** — encapsulation machinery for mutable
   instance state.
5. **`closed` hierarchies (C# 15)** — exhaustive matching, routed through inheritance because
   inheritance is the tool C# has. Evidence that C# wants what this language starts with.
6. **Static abstract interface members** — ad-hoc polymorphism routed through interfaces for
   the same reason.
7. **Record inheritance, `EqualityContract`, the synthesized clone method and copy
   constructor** — the parts of `record` that exist to make value semantics survive a class
   hierarchy.
8. **User-defined compound assignment and instance increment operators (C# 14)** — in-place
   mutation of an instance, by design.
9. **Delegates as *named* types**, multicast delegates, events, `partial` events — a nominal,
   OO wrapper over a function value.
10. **`switch` statements, labeled `break`/`continue`** — imperative control flow.

---

## 4. Where C# 15 changes the picture

C# 15 is in **preview** as of August 2026 (.NET 11 preview SDK; GA expected November 2026).
Nothing below has shipped, and the union documentation itself notes that "some features from
the proposal specification aren't yet implemented".

- **Union types** (`public union Pet(Cat, Dog, Bird);`) — the headline. Compiler-checked
  exhaustive `switch` with no `default` arm, implicit conversions from each case type, and
  patterns that transparently unwrap the union. Nominal and closed; compiled to a `struct`
  with `[Union]`/`IUnion` and an `object?` `Value` that boxes value-type cases. This confirms
  the tension already recorded in ticket 00 rather than resolving it. → [09](../issues/09-union-representation.md)
- **`closed` hierarchies** — a second, inheritance-based route to the same exhaustiveness
  goal, with a subtlety worth noting for [ticket 04](../issues/04-crossclause-exhaustiveness.md):
  exhaustiveness is computed only over **direct** descendants, and only over those *visible
  at the switch site*, so the same switch can be exhaustive in one assembly and not in
  another. A visibility-dependent exhaustiveness check is a trap to avoid.
- **Extension indexers** — extends the C# 14 extension-block feature; droppable for the same
  reasons.
- **Collection expression arguments**, **labeled `break`/`continue`**, **memory-safety /
  pointer relaxations** — all droppable.

Net effect: C# 15 moves C# *toward* this language's semantics (sum types, exhaustiveness) by
routes this language does not need. It changes no verdict in section 2, and it strengthens
the case that the differentiator is the *combination* — structural unions plus multi-clause
heads — rather than sum types alone.

---

## 5. Feeds into other tickets

| Finding | Ticket |
|---|---|
| Query syntax is a syntactic rewrite needing only name resolution; the extension-method rewrite *is* a pipeline | map fog "pipelines", "whether anything LINQ-shaped survives"; [08](../issues/08-head-and-guard-syntax.md) |
| Erlang guards are a restricted whitelist; C#'s `when` is unrestricted | [08](../issues/08-head-and-guard-syntax.md) |
| `params` and optional parameters vs name+arity identity (Elixir's per-arity generation is the precedent) | map fog "module and namespace system, and function identity" |
| Type patterns, records and unions all lean on nominal runtime identity | [09](../issues/09-union-representation.md), [10](../issues/10-atoms-in-a-csharp-skin.md) |
| Null-state analysis is occurrence typing — the same narrowing a set-theoretic system provides | [11](../issues/11-type-system-shape.md) |
| C# exhaustiveness only *warns* and throws at runtime; `closed` exhaustiveness is visibility-dependent | [04](../issues/04-crossclause-exhaustiveness.md), [12](../issues/12-totality-vs-let-it-crash.md) |
| `async`/`await` and iterators are both compiled mutable state machines with no BEAM analogue | [14](../issues/14-concurrency-and-otp-model.md) |
| Dropping both extension methods and static abstract interface members leaves no ad-hoc polymorphism story | open — worth its own ticket |
| Interior/suffix slice patterns are not one-pass expressible over cons cells | [08](../issues/08-head-and-guard-syntax.md) |
| `with` maps directly onto BEAM map update and becomes *more* central than in C# | map fog "data modelling" |

---

## 6. Claim → source

| # | Claim | Source |
|---|---|---|
| 1 | Query expressions are translated into invocations of 11 named methods (`Where`, `Select`, `SelectMany`, `Join`, `GroupJoin`, `OrderBy`, `OrderByDescending`, `ThenBy`, `ThenByDescending`, `GroupBy`, `Cast`), which may be instance *or* extension methods | [ECMA-334 §12.22.3.1](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12223-query-expression-translation) |
| 2 | The query translation "is a syntactic mapping that occurs before any type binding or overload resolution has been performed" | [ECMA-334 §12.22.3.1](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12223-query-expression-translation) |
| 3 | `IEnumerable<T>` appears in the query-expression pattern only as a *note* about what `System.Linq` provides — it is not a language requirement | [ECMA-334 §12.22.4](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#12224-the-query-expression-pattern) |
| 4 | Extension-method invocation is rewritten to a static call `C.M(expr, args)`; `C` is found by searching enclosing namespaces and `using` directives; a `null` receiver throws nothing because no dispatch occurs | [ECMA-334 §12.8.10.3](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#128103-extension-method-invocations) |
| 5 | Extension methods must be declared in non-generic, non-nested static classes, with `this` on the first parameter | [ECMA-334 §15.6.10](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/classes.md#15610-extension-methods) |
| 6 | Query operators returning a singleton execute immediately; those returning a sequence defer execution — a property of the operator implementations | [Standard query operators overview](https://learn.microsoft.com/en-us/dotnet/csharp/linq/standard-query-operators/) |
| 7 | A collection expression always creates a collection containing all elements, explicitly "distinct from LINQ, where a sequence might not be instantiated until it is enumerated" | [Collection expressions](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/collection-expressions) |
| 8 | Collection expressions are target-typed; types opt in via `CollectionBuilderAttribute` and a `Create` method, or via `IEnumerable<T>` + `Add`; spread `..` requires a `foreach`-enumerable expression | [Collection expressions](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/collection-expressions) |
| 9 | An iterator returns an *enumerator object* with four states (before/running/suspended/after), advanced by `MoveNext`; the body does not execute on call | [ECMA-334 §15.15.5](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/classes.md#15155-enumerator-objects) |
| 10 | An async function compiles to a state machine driven by a task builder via repeated `MoveNext()` calls | [ECMA-334 §15.14](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/classes.md#1514-async-functions) |
| 11 | `await` is pattern-based: any `t` with an accessible `GetAwaiter` returning a type with `IsCompleted`, `GetResult` and `INotifyCompletion` is awaitable | [ECMA-334 §12.9.9.2](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#1299-await-expressions) |
| 12 | `foreach` is pattern-based: member lookup for `GetEnumerator` first, enumerable interfaces only as a fallback | [ECMA-334 §13.9.5](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/statements.md#1395-the-foreach-statement) |
| 13 | Deconstruction requires a unique instance *or extension* `Deconstruct` method with ≥2 `out` parameters (or a tuple type) | [ECMA-334 §12.7](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/expressions.md#127-deconstruction) |
| 14 | Local functions are declared by `local_function_declaration` inside a block; their canonical use is separating validation from iterator/async bodies | [ECMA-334 §13.6.4](https://github.com/dotnet/csharpstandard/blob/draft-v8/standard/statements.md#1364-local-function-declarations) |
| 15 | Positional records synthesize init-only properties, a primary constructor, and a `Deconstruct` method; `record class` positional properties are immutable, `record struct` ones are mutable | [Records](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record) |
| 16 | A `with` expression produces a **shallow copy**; the compiler synthesizes a clone method and copy constructor, calls the clone, then sets the listed properties | [Records](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record) |
| 17 | Records support inheritance and synthesize an `EqualityContract` property so equality compares runtime types; a record can't inherit from a class | [Records](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record) |
| 18 | Init-only properties have *shallow immutability* — referenced data can still change | [Records](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record) |
| 19 | Positional patterns call the type's `Deconstruct` method, and member order must match parameter order | [Patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns) |
| 20 | Declaration/type patterns match on runtime type, including derivation, interface implementation, boxing/unboxing and nullable-value-type unwrapping | [Patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns) |
| 21 | Relational patterns compare against a *constant*; logical patterns bind `not` then `and` then `or` | [Patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns) |
| 22 | A non-exhaustive `switch` expression only *warns* at compile time and throws at run time | [Patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns) |
| 23 | List patterns require a *countable* and *indexable* type (accessible `Index` indexer or `int` indexer); slice subpatterns require *sliceable* (a `Range` indexer or a `Slice(int,int)` method) | [List patterns proposal](https://github.com/dotnet/csharplang/blob/main/proposals/csharp-11.0/list-patterns.md) |
| 24 | Index `^` and range `..` require a *countable* type — "an `int` property named either `Count` or `Length` with an accessible `get` accessor" — and produce `System.Index` / `System.Range` | [Member access operators](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/member-access-operators) |
| 25 | Nullable reference types are entirely compile-time: "The runtime behavior of your program is unchanged"; `string` and `string?` are both `System.String` | [Nullable reference types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/null-safety/nullable-reference-types) |
| 26 | Null-state analysis tracks two states, *not-null* and *maybe-null*, updated by assignments and null checks, and flows through `if`, pattern matching and loops; it doesn't trace into method bodies | [Nullable reference types](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/null-safety/nullable-reference-types) |
| 27 | Static abstract/virtual interface members exist chiefly for generic math; the call goes through a type parameter constrained to the interface and "the compiler resolves the correct implementation at compile time based on the type argument" | [Static virtual interface members](https://learn.microsoft.com/en-us/dotnet/csharp/advanced-topics/interface-implementation/static-virtual-interface-members) |
| 28 | C# 13 generalized `params` beyond arrays to spans and any `IEnumerable<T>`-with-`Add` type, and to five collection interfaces | [What's new in C# 13](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-13) |
| 29 | C# 14 shipped: extension members (extension blocks with extension properties, static extension members and static extension operators), `field`, null-conditional assignment, unbound-generic `nameof`, implicit span conversions, lambda parameter modifiers, partial constructors and events, user-defined compound assignment | [What's new in C# 14](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14) |
| 30 | User-defined compound assignment exists to let "the target of the assignment be modified in-place"; the operator is a non-static, `void`-returning instance method motivated by avoiding allocation for large data (`BigInteger`, tensors) | [User-defined compound assignment spec](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/proposals/csharp-14.0/user-defined-compound-assignment) |
| 31 | C# 15 is a **preview** release on the .NET 11 preview SDK; its features are collection expression arguments, union types, closed hierarchies, extension indexers, labeled `break`/`continue`, and memory safety | [What's new in C# 15](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-15) |
| 32 | A `union` declares a closed, nominal set of case types; the compiler generates a `struct` with `[Union]`, `IUnion` and an `object?` `Value`, boxing value-type cases; patterns unwrap to `Value` (except `_`, `var`, `not`); `switch` is exhaustive when all case types are handled | [Union types](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union) |
| 33 | `UnionAttribute` and `IUnion` ship in the runtime from .NET 11 Preview 5; some proposal features are not yet implemented | [What's new in C# 15](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-15), [Union types](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/union) |
| 34 | A `closed` class fixes its direct descendants to its declaring assembly; exhaustiveness covers only *direct* descendants and only those visible at the switch site, so a switch exhaustive in one assembly may not be in another | [Patterns — closed hierarchy patterns](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns), [What's new in C# 15](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-15) |
| 35 | Gleam does not support multiple function heads — the gap this language exists to fill | [Gleam for Erlang users](https://gleam.run/cheatsheets/gleam-for-erlang-users/) (via [ticket 00](../issues/00-charting-decisions.md)) |

### BEAM-side claims (the obstacles)

| # | Claim | Source |
|---|---|---|
| 36 | Erlang guards are a restricted subset: "The set of valid *guard expressions* is a subset of the set of valid Erlang expressions", because "evaluation of a guard expression must be guaranteed to be free of side effects". Only listed BIFs are permitted; **user-defined function calls are not allowed in guards** | [Erlang Reference Manual — Expressions, *Guard Sequences*](https://www.erlang.org/doc/system/expressions.html) |
| 37 | Erlang has **named funs**, so an anonymous function can recurse: `fun Fact(1) -> 1; Fact(X) when X > 1 -> X * Fact(X - 1) end` — and note this shape is itself multi-clause | [Erlang Reference Manual — Expressions, *Fun Expressions*](https://www.erlang.org/doc/system/expressions.html) |
| 38 | Erlang map update: `M#{K := V}` updates an **existing** key and raises `badkey` if `K` is absent; `M#{K => V}` adds or overwrites. This is the direct analogue of `with` | [Erlang Reference Manual — Expressions, *Updating Maps*](https://www.erlang.org/doc/system/expressions.html) |
| 39 | Erlang list comprehensions are a native language construct — the existing nearest kin to LINQ query syntax (with no `join` or `group by` equivalent) | [Erlang — List Comprehensions](https://www.erlang.org/doc/system/list_comprehensions.html) |
| 40 | Elixir splits eager from lazy at the module boundary: "the functions in `Stream` are *lazy* and the functions in `Enum` are *eager*"; `Stream` "creates a recipe of computations that are executed at a later moment". This is the precedent for making deferred execution explicit on a strict runtime | [Elixir — `Stream`](https://elixir.hexdocs.pm/Stream.html) |
| 41 | Elixir default arguments (`\\`) resolve the arity collision by generation: "The compiler translates this into multiple functions with different arities"; with multiple clauses "you must write a function head that declares the defaults" | [Elixir — `Kernel.def/2`](https://elixir.hexdocs.pm/Kernel.html#def/2) |
| 42 | Tuple element access is `element/2` and tuple size is `tuple_size/1` — O(1); list length is `length/1` — O(n) with no stored count. This is why C#'s *countable* requirement (`Count`/`Length` as a property) does not hold for cons lists | [Erlang — `erlang` module (erts)](https://www.erlang.org/doc/apps/erts/erlang.html) |
| 43 | Binary subranges are library calls (`binary:part/3`, `binary:split/2,3`), not an index/range operator; binary *patterns* match a prefix plus a `Rest/binary` tail, which is why interior and suffix slice patterns need extra work | [Erlang — `binary` module (stdlib)](https://www.erlang.org/doc/apps/stdlib/binary.html), [Expressions — *Bit Syntax Expressions*](https://www.erlang.org/doc/system/expressions.html) |

**Note on the specification used.** ECMA-334 citations are to the
[dotnet/csharpstandard `draft-v8` branch](https://github.com/dotnet/csharpstandard/tree/draft-v8/standard),
the most recent standardized text. Features introduced after C# 8 (records, list patterns,
collection expressions, static abstract interface members, extension members, unions) are not
yet in the standard and are cited to Microsoft Learn language reference pages or to
`dotnet/csharplang` feature specifications, which are the owning primary sources for those.
