# B# — language reference

A BEAM language with C#-family syntax, Erlang-style multi-clause function heads, and a
set-theoretic type system that **proves every function covers its declared input**.

This is the reference: what the language *is*. It carries no decision history and no ticket
numbers — those live in `wayfinder/`, and you should not need them to read this.

Every construct is marked with its status:

| | |
|---|---|
| **shipped** | the compiler in `compiler/` does this today |
| **decided** | settled, not yet built |
| **open** | not decided |

---

## 1. The shape of a program

```csharp
module Fib

list<int> Fib(int n)

Fib(n) when n <= 0 -> []
Fib(n) when n > 0  -> Series(n, 0, 1, [])
```

A **signature** declares the type. **Clauses** follow it, one per case, each repeating the
function name. The clause arrow is `->`. **There is no `;`** — a declaration ends where the next
one begins. **shipped**

`=>` is the lambda arrow and a `switch` arm, never a clause. Two arrows, two jobs.

A **module** is a directory; one function per file; `index.bs` holds the declarations shared across
it. Sub-modules are source-only — the whole directory compiles to one `.beam`. **decided** (the
compiler currently takes one file at a time)

---

## 2. Multi-clause heads

The one structural move the language rests on: C#'s pattern grammar moves out of `switch` arms and
into the **parameter position**, and N declarations are allowed where C# allows one.

```csharp
type Reading = (:ok, int) | (:error, atom)

Verdict Classify(Reading r)

Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n))            -> :negative
Classify((:error, e))         -> :unknown
```

Five clauses in, five native Erlang clause heads out. **shipped**

**The signature is mandatory.** Exhaustiveness is only a well-posed question against a *declared*
input type — a language that infers the function type from its own clauses can never ask it,
because the answer is always yes. **shipped**

**Guards** use `when`, with `&&` and `||`. A guard the checker can read as a type operation
refines the clause; one it cannot read credits nothing. **shipped**

```csharp
Classify(n) when n < 10             -> :low
Classify(n) when n >= 10 && n < 100 -> :mid
Classify(n) when n >= 100           -> :high
```

That is exhaustive over `int`, with no catch-all, because the checker carries real integer
intervals.

---

## 3. Exhaustiveness

**A function that does not cover its declared input does not compile.** No opt-out, no flag.

```
readings.bs:4: error: Classify is not exhaustive
  no clause matches:
    Classify((:ok, int <= 0)) -> ...
```

The error is the **missing clause**, not a complaint — the residual is computed exactly and printed
as a head you can paste in. **shipped**

A **catch-all is legal only where the residual is open** — over a `term`, or any type with an
unbounded part. Where the compiler knows the remaining case names, `_` is an error: it would put
the language's headline guarantee one character from being switched off invisibly. **decided**

---

## 4. Types

**Structural, set-theoretic, open.** Two types with the same shape are the same type. There is no
nominal type and no union declaration form.

```csharp
type Verdict = :positive | :zero | :negative | :unknown
type Reading = (:ok, int) | (:error, atom)
type Band    = :low | :mid | :high
```

`type X = ...` is the **single naming construct** — for unions, tuples, scalars, records alike. The
name never enters the algebra; it is an alias. **shipped**

| Type | Notes | Status |
|---|---|---|
| `int` | arbitrary precision; carries real intervals in the checker | **shipped** |
| `atom` | open universe, cofinite top | **shipped** |
| `:ok` | a singleton atom type | **shipped** |
| `(A, B)` | tuple | **shipped** |
| `list<T>` | `[]` and `[h, ..t]` partition it | **shipped** |
| `term` | the top type — everything | **shipped** |
| `none` | the bottom type, first-class | **shipped** |
| `float` | | **open** |
| `binary` | `<<_:M, _:_*N>>` grammar with exact unions | **decided** |
| `string` | `binary` refined by valid UTF-8 | **decided** |
| records | see §6 | **decided** |

**Unions are exact.** Nothing widens: `<<_:32>> | <<_:64>>` stays two members rather than
collapsing into a range admitting 96 bits. This is the property the whole guarantee rests on — a
checker that must prove a residual empty cannot afford an optimistic join.

**Atoms:** the universe is open, nothing declares an atom, `:foo` mints one by writing it.
`true` and `false` are the only keyword atoms, `bool` is an ordinary alias, and **there is no
truthiness**. **shipped**

---

## 5. Control flow

**`switch` is the only branching construct.** There is no `if`, no `else`, no ternary.

```csharp
Verdict Describe(Order o)

Describe(o) -> o.Status switch {
    :placed  => :new,
    :shipped => :gone,
    _        => :unknown
}
```

For compound conditions, the subject is a **tuple** — which is the clause head's own shape, one
level down:

```csharp
Disposition Decide(bool ok, bool permanent, bool redelivered)

Decide(o, p, r) -> (o, p, r) switch {
    (true,  _,     _)     => :ack,
    (false, true,  _)     => :dead_letter,
    (false, false, false) => :requeue,
    (false, false, true)  => :requeue
}
```

**decided** — the compiler does not parse `switch` yet.

`else` is absent because it is what a *binary unnamed* conditional needs; every fall-through here is
a pattern. `cond` is **open** — deliberately unpaid-for until the shape is shown to occur. Measured
so far: a four-wide tuple reads fine.

---

## 6. Records

```csharp
record Order { Id: string, Total: int, Lines: list<Line> }
record Line  { Sku: string, Qty: int }
```

A record **erases to a map** carrying a tag minted from its qualified type name. Everything stays
structural — a hand-written `type` with the same tag *is* the same type — but the tag means
`Order` and `Invoice` over identical fields are two types, so `Update(Order o)` will not take an
`Invoice`.

**Records exist for dispatch.** The tag is in the term, so a union of records is dispatched by an
ordinary clause head and checked exhaustive:

```csharp
type Shape = Circle | Rect

float Area(Shape s)

Area(Circle c) -> 3.14159 * c.Radius * c.Radius
Area(Rect r)   -> r.W * r.H
```

That is a protocol without a protocol construct. What it does **not** give you is *open* extension —
another module cannot add `Triangle` without editing `Shape`.

Construction names the type; the dot projects; `with` updates:

```csharp
Order o  = Order { Id = "A-1", Total = 500, Lines = [] }
Order o2 = o with { Total = 600 }
```

Note `:` in declarations and patterns, `=` in construction and update. **No optional fields** —
every declared field is always present, and absence is `option<T>`.

**decided** — this is the next feature to build.

---

## 7. Errors

There is no global error-model preference: **write the honest value your return type admits**, and
`raise` only where it admits none.

```csharp
type option<T> = T | :nothing
type result<T, E> = T | (:error, E)
```

**Absence carries nothing; failure carries a reason.** The tag is a consequence of the payload, not
a style choice: `atom | :error` collapses (`:error` is absorbed into the atom top) while
`atom | (:error, binary)` does not.

`raise` takes any term. **There is no `try`** — a foreign call that can throw gets a wrapper the
compiler writes from your declared return type, and process failure is `monitor` plus `receive`,
which yields a better reason than `try` does.

**decided**

---

## 8. Pipelines

```csharp
xs |> List.Map(f) |> List.Filter(g)
```

Names are **qualified** — `List.Map`, not `xs.Map(f)`. Method-call syntax would need type-directed
resolution of an unqualified name, which the language has deliberately closed off.

`|?>` is the **valve**: it stops on the first `(:error, _)` and runs no further stage.

```csharp
Load(id) -> Users.Fetch(id) |?> Accounts.For()
```

There is **no comprehension syntax**. The compiler inlines its own collection operations, which
recovers precise emitted types that a call to a generic function loses.

**decided**

---

## 9. Generics

Real parametric polymorphism, in its smallest working form.

```csharp
list<U> Map<T, U>(list<T> xs, fn(T) -> U f)
```

- **Declared**, C#'s `T` convention. Builtins are lowercase, so an implicit lowercase convention
  would be ambiguous.
- **Unbounded.** No constraints, no `where T : ...`.
- **Opaque in clause heads** — a bare type variable admits exactly one clause, so bind it. Structure
  *around* it matches freely, which is why `Map`'s `[]` / `[h, ..t]` pair is exhaustive for every
  instantiation.
- **Variance is not a concept**, there being no nominality to annotate.

Instantiation is matching, not constraint solving — which is what keeps the cost sane, and why the
three bullets above are load-bearing rather than preferences.

**User code never writes a type argument.** Only three compiler-known names take an explicit one:
`ValidateAs<T>`, `ParseAtom<T>`, `ToExistingAtom`. So `<` opens a bracket after one of those names
and is comparison everywhere else — a lexer rule on a closed set, with no lookahead and no turbofish.

**decided**

---

## 10. The boundary

**Every value from outside is a `term` until you match it.** There is no `dynamic`, no cast, and no
second weaker subtyping relation.

The **clause head is the decoder**, and the exhaustiveness residual is the case you failed to
handle:

```csharp
Verdict Handle(term msg)

Handle((:ok, n)) when is_int(n) -> :fine
Handle(_)                       -> :unknown
```

Patterns over a `term` may only ask what one BEAM guard decides in **O(1)**. Deep validation is an
explicit call to a generated `ValidateAs<T>`, which returns `result<T, ValidationError>` — because
a dispatch construct must not do unbounded work whose size a foreign sender chooses.

**A declared type at an entry is checked.** Where generated code consumes a value, a guard is
emitted, always, with no opt-out. The guarantee is:

> **A foreign term that breaks your types will crash — not always where it entered, but never
> silently.**

This is a deliberate divergence from *both* audiences: C#'s `extern` and Gleam's `@external` are
both unchecked, and both will hand you a `float` from a function declared to return an `Int`.

**decided**

---

## 11. Calling Erlang and Elixir

```csharp
[external: erlang, "ets"]
module Ets {
    list<term> Lookup(atom table, term key)
    true       Insert(atom table, term row)
}

[external: erlang, "erlang"]
module Erlang {
    int SystemTime(atom unit)
}
```

Then `Ets.Lookup(table, id)` is an ordinary call.

- **The declaration binds the module**; each function carries its own signature and **exactly one
  arity**. Foreign arity families are not defaults — `inet_udp:send/2` and `/4` exist with no `/3`.
- **Both spellings are written**, the Erlang atom in quotes and the B# name in the declaration.
  There is no snake_case ⇄ PascalCase rule anywhere in the language.
- **Elixir is the same construct**, `[external: elixir, "Enum"]`. Its *macros* are unreachable —
  they are exported as `MACRO-`-prefixed functions and are not callable from another language, so
  `use GenServer` cannot cross.
- A foreign declaration may promise only what one BEAM guard decides in O(1). `list<Order>` is an
  error at the declaration; it crosses as `list<term>` plus `ValidateAs<T>`.

**decided**

---

## 12. Processes

The concurrency vocabulary is OTP's, and **nothing in it is parameterised by a message type**.

```csharp
[module: GenServer]
```

names a contract the compiler knows as a type; you write a narrower signature and the compiler
checks containment. There is no typed `Pid<T>` — a process identifier is a `pid`, and the message
type belongs on the client API function's signature, where you were going to write it anyway.

**No `async`, `await` or `Task`.** `async` colours functions, which is a second effect system.

`receive` is a **filter**, exempt from exhaustiveness — unmatched messages stay in the mailbox,
which is what `gen_server:call`'s own reply correlation runs on.

**decided**

---

## 13. Refinements

```csharp
type Octet = int where value >= 0 && value <= 255
```

Where the predicate is a **single BEAM guard**, a refinement is reasoned about by the checker and
may appear in a clause head and at a foreign boundary.

An **opaque** refinement — `binary where valid_utf8`, O(n) — may be declared, but is **barred from
clause heads and foreign declarations**. Inside, the caller is known and the obligation is
dischargeable; at the boundary the caller is unknown and it is unbounded cost with nothing to
discharge it against.

**decided** — and the pairing matters: interval *patterns* must land with interval *refinements*,
or wire parsing breaks. A parameter declared `int` leaves every byte-wide dispatch open.

---

## 14. What is deliberately absent

| Absent | Because |
|---|---|
| `if` / `else` / ternary | `switch` is the only branching construct; every fall-through is a pattern |
| `;` | the grammar needs no terminator |
| macros | a large semantic surface that interacts hard with a type system; the compiler generates code, users do not |
| `async` / `await` | function colouring is a second effect system |
| `try` | a compiler-written wrapper and `monitor`/`receive` cover it, checked |
| method-call syntax (`xs.Map(f)`) | needs type-directed resolution of an unqualified name |
| LINQ query syntax | same reason — its translation emits unqualified names |
| comprehensions | inlining recovers better emitted types |
| type classes / protocols | dispatch cannot key on a name that is not in the term; records put it there instead |
| bounded type variables | both routes to discharging a bound are closed |
| nominal types | structural throughout; records tag the *term*, not the type |
| `dynamic` | outside values are `term`; the clause head is the decoder |
| spread (`{...o}`) | its defining capability is widening; `with` covers the rest |
| optional record fields | *k* optional fields denote 2^k shapes for a guard emitted everywhere |
| JS/WASM backends | doubles the codegen surface and forces semantic compromises |

---

## 15. How it compiles

```
.bs → lex → parse → exhaustiveness check → Erlang abstract format → erlc +from_abstr → .beam
```

The **Erlang Abstract Format** is the target, and the reason is that the choice is a one-way door
rather than a rung on a ladder: `.abstr → Core` is free (`erlc +from_abstr +to_core`), while
`.core → abstract forms` is unrecoverable. A function *is* a clause list in the Abstract Format, so
multi-clause heads are expressed natively.

The compiler is written in **Erlang**, because `leex` and `yecc` ship with OTP and `merl`'s
quasi-quoting rides on a parse transform Elixir cannot use. Nothing requires this — the emission
contract is a sequence of abstract-format forms and `erlc +from_abstr` builds from serialised text
with no `.erl` on disk.

**A `-spec` is emitted for every function whose type is known**, widened to the nearest Erlang
spelling where a set-theoretic type has none:

```erlang
-spec 'Classify'({ok, integer()} | {error, atom()}) ->
          negative | positive | unknown | zero.
```

The **failure arm is always emitted**, so an unmatched value dies with `function_clause` naming the
offending argument rather than returning something wrong.

**shipped**

---

## 16. Using the compiler

```
$ bsc fib.bs 5
[0, 1, 1, 2, 3]

$ ibs -S fib.bs
bs> Fib(10)
[0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
bs> :reload
```

`bsc FILE.bs [FUNCTION] [ARG...]` compiles and runs. The function name is optional because under
one function per file the file names the function. Arguments and results are in B# notation, and
the parser accepts back exactly what the printer emits. **shipped**

---

## 17. What is actually built

| Area | State |
|---|---|
| multi-clause heads under a mandatory signature | **shipped** |
| exhaustiveness, with the residual as the missing clause | **shipped** |
| atoms, structural unions, tuples | **shipped** |
| integer intervals in the checker | **shipped** |
| `list<T>`, `[]` / `[h, ..t]`, tail calls | **shipped** |
| abstract-format emission with `-spec` and the failure arm | **shipped** |
| `bsc` run mode and the `ibs` REPL | **shipped** |
| records | **next** |
| refinements + interval patterns | blocked on two spellings |
| `switch` | not started |
| binaries | not started |
| pipe and valve | not started |
| generics | not started |
| modules, imports, `using` | not started |
| FFI | decided, not started |
| OTP behaviours | decided, not started |

### Known inconsistencies

- **Bare clause heads.** The exemplars elide the function name (`(body) -> ...`); the compiler
  requires it (`CreateOrder(body) -> ...`). One of the two is wrong and it has not been settled.
- **Map literals.** `#{ error = "invalid" }` appears in an exemplar and is specified nowhere.
- **`float`** has no decided literal syntax, which matters because `1..5` only lexes as a range
  while the float rule demands digits either side of its dot.

---

## 18. Open questions

- The language's **name**.
- **Module and namespace system** — what atom a module emits, and what `using` brings into scope.
- **Stdlib shape** — what is in the prelude versus a module you import.
- **`cond`**, or whatever serves a long ladder of unrelated conditions.
- **Laziness** and `stream<T>` — deferred, not refused.
- **Bootstrapping** — how much of B# is written in B#. The front end likely stays Erlang, as
  Elixir's did; the OTP layer is the valuable target.

---

*Rationale for every decision above, and the measurements behind them, are in `wayfinder/`. This
document is the language; that directory is why.*
