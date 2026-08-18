# B# — language reference

A BEAM language with C#-family syntax, Erlang-style multi-clause function heads, and a
set-theoretic type system that **proves every function covers its declared input**.

This is the reference: what the language *is*. It carries no decision history, and **the prose you
read carries no ticket numbers** — those live in `wayfinder/`, and you should not need them to read
this. That rule is load-bearing rather than tidy: the eventual clean-room handoff gives an
implementer this document and **no access to `wayfinder/`**, so a ticket number in the running text
is a pointer to something they do not have.

Traceability still exists, in HTML comments the reader never sees:

```
<!-- decided by ticket 44, amending ticket 08 -->
```

`bin/check-surface.sh` requires one for every decision the map tags `syntax` or `patterns`, so a
construct cannot be decided without this document being opened at the paragraph that describes it.
**A handful of older paragraphs still name tickets inline** — they predate the convention and are
the exception this note is written against.

Every construct is marked with its status:

| | |
|---|---|
| **shipped** | the compiler in `compiler/` does this today |
| **decided** | settled, not yet built |
| **open** | not decided |

---

## 1. The shape of a program

<!-- check:
private list<int> Series(int n, int a, int b, list<int> acc)
Series(n, a, b, acc) when n <= 0 -> acc
Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])
-->
```csharp
module Fib

public list<int> Fib(int n)

Fib(n) when n <= 0 -> []
Fib(n) when n > 0  -> Series(n, 0, 1, [])
```

A **signature** declares the type. **Clauses** follow it, one per case, each repeating the
function name. The clause arrow is `->`. **There is no `;`** — a declaration ends where the next
one begins. **shipped**
<!-- decided by ticket 01 (Variant A: signature names the function once, clauses are bare) -->

**A function is private unless its signature says `public`.** A `public` function is exported from
its module; everything else can be called only from inside it. `Series` above is private — `Fib`
calls it, nothing else can — which is why the example shows a call to a function the module does not
offer anyone. A private function is otherwise ordinary: it is compiled, it carries a type, and a
crash names it. **shipped**
<!-- decided by ticket 40 §3; built by F12 -->

**`private` may be written and adds nothing**, saying explicitly what the absence already says. Use
it where a reader benefits from being told the omission was deliberate.

A module's surface is therefore the list of things somebody wrote `public` in front of. Three
consequences follow. A function that a behaviour declares as a callback **must** be `public`, since
a behaviour is dispatched through the export list and nothing else — leaving one private is refused
at the declaration rather than left to fail when the process starts. Visibility is per **name and
arity**, so `Length(list<int> xs)` may be public while `Length(list<int> xs, int acc)` beside it is
not. And a module with no `public` at all exports nothing and cannot be run, which the compiler says
in those words rather than offering an empty list of choices.

**A body is zero or more bindings followed by one expression**, and the body's value is that last
expression — so a body is still an expression, with names in front of it.
<!-- decided by ticket 34 -->

<!-- check:
record Order { Id: int, Total: int }
-->
```csharp
public int Squared(Order o)

Squared(o) ->
    var t = o.Total
    t * t
```

**A binding says it is one.** `var` introduces a name; a bare `=` **matches** and may introduce
nothing. Unmarked, `x = 1` reads to a C# eye as an assignment to an existing variable, which is the
one thing this language cannot do — and `var` is literally correct here, where every type is
inferred. **shipped**
<!-- decided by ticket 34; `var` marker added by F8, token by ticket 45 -->

So `x = 1` is an **error** — it introduces `x`, and a bare `=` may not — while `1 = x` is fine,
because it asserts and introduces nothing. The diagnostic names `var x = 1` as the fix.

**Bindings do not shadow.** A name means one thing in a clause: rebinding is an error, including
rebinding what the head bound, because there is no mutation to assign with. **shipped**

A **destructuring** bind is in the language, and only where it **cannot fail**:

<!-- check:
-->
```csharp
public int Sum((int, int) pair)

Sum(pair) ->
    var (a, b) = pair
    a + b
```

The compiler proves it by subtraction — the bind is legal exactly when nothing the right-hand side
can be is left over after the pattern — so a bind is never a branch exhaustiveness would not see.
Where it can fail, the residual comes back as the case to match in a clause head instead. `_` may
stand anywhere in the pattern and nowhere else: it is a pattern, not a value. **shipped**

`=>` is the lambda arrow and a `switch` arm, never a clause. Two arrows, two jobs.

A **module** declares a dotted path, and that path *is* its atom: `module Shop.Orders` emits
`'Shop.Orders'` and therefore `Shop.Orders.beam`. This is forced rather than chosen — a record's tag
mints from the qualified name, so a nested module lowering to its leaf would let two bounded contexts
mint the same tag. **shipped**
<!-- decided by ticket 40 §1; built by F11 -->

This block is `illustrative` rather than checked, and the reason is structural: the gate compiles
each block as **one isolated file**, and the whole subject here is what happens across two. It is
executed instead as `compiler/examples/Shop/`, which the example gate runs —
`bsc --src-root examples examples/Shop/Reports Restate 3` prints `9`.

```csharp illustrative
module Shop.Reports

using Shop.Collections.List
using Shop.Collections

public int Restate(int n)
Restate(n) -> Sum([n, n, n], 0)

public int Counted(int n)
Counted(n) -> List.Length([n, n])

public int Fully(int n)
Fully(n) -> Shop.Collections.List.Sum([n], 0)
```

`using Shop.Collections.List` brings that module's names in **unqualified** — TypeScript's
named-import semantics exactly. `using Shop.Collections` names a **namespace** and brings its modules
in short-qualified (`List.Length(...)`). A namespace is a path other modules sit under; it is erased
entirely, with no atom and nothing emitted. A fully qualified call is always legal regardless of what
is in scope, which is why every **diagnostic** prints that form and never has to know the call site's
scope. **shipped**
<!-- decided by ticket 41 §1/§2/§5; built by F11 -->

Resolution is by name **and arity**, and it happens at compile time: an unqualified call to an
imported name emits a *remote* call, so nothing is resolved at run time. A name reachable from two
sources is an error at the call site printing the qualified candidates; an import that would shadow a
local name is an error at the `using` line. A qualified call to a module with no `using` is an error
too — a file's `using` lines are its dependency list, and a call that skipped them would make that
list wrong. **shipped**

A function name may carry **more than one arity** — the BEAM's own identity rule, unmodified — so
`Fib/1` and `Fib/2` are two functions. Two signatures of the *same* arity are one function declared
twice, and an error. **shipped**
<!-- decided by ticket 40 §2; built by F11 -->

**The compiler owns the dependency graph.** `using` is resolved to source, that source is checked
first, and its signatures are kept in the environment its dependents are checked against — so there
is no signature artefact and nothing that can go stale. A dependency need not be named on the command
line; a build tool's job is *which files* and *where the source root is*, never *in what order*. Two
modules importing each other are refused by name. **shipped**
<!-- decided by ticket 41 §3; built by F11 -->

**A module is a directory.** Every `.bs` file in it compiles into one `.beam`; `index.bs` holds the
shared declarations — `using`, `type`, `record`, `behaviour` — and never a function; a file with no
`module` line inherits the directory's; and a directory holding only directories is a **namespace**,
which is erased entirely and emits no atom, no beam and no attribute. A file's `module` declaration
must match its directory path, relative to a source root that defaults to the module directory's own
parent and is named with `--src-root` otherwise. **shipped**
<!-- decided by tickets 13 §3 and 41 §4/§5; built by F15 -->

Sub-modules are **source-only** and a crash still names the file its clause is written in, not the
aggregate — the `.beam` carries a `file` attribute per source file, so one module's stack traces
point at `Total.bs` and `Apply.bs` separately. **shipped**
<!-- decided by ticket 13 §3; built by F15 -->

---

## 2. Multi-clause heads

The one structural move the language rests on: C#'s pattern grammar moves out of `switch` arms and
into the **parameter position**, and N declarations are allowed where C# allows one.

<!-- check:
type Verdict = :positive | :zero | :negative | :unknown
-->
```csharp
type Reading = (:ok, int) | (:error, atom)

public Verdict Classify(Reading r)

Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n))            -> :negative
Classify((:error, e))         -> :unknown
```

Five clauses in, five native Erlang clause heads out. **shipped**

**The signature is mandatory.** Exhaustiveness is only a well-posed question against a *declared*
input type — a language that infers the function type from its own clauses can never ask it,
because the answer is always yes. **shipped**

**Guards** use `when`, with `and` and `or`. A guard the checker can read as a type operation
refines the clause; one it cannot read credits nothing. **shipped**
<!-- decided by ticket 44, amending ticket 08 -->

```csharp
Classify(n) when n < 10              -> :low
Classify(n) when n >= 10 and n < 100 -> :mid
Classify(n) when n >= 100            -> :high
```

That is exhaustive over `int`, with no catch-all, because the checker carries real integer
intervals.

**One spelling, in every position** — guard, pattern and refinement predicate. There is no `&&` and
no `||`; they were removed rather than kept as synonyms. This language puts patterns in the
*parameter* position, so a pattern and a guard sit on the same line in every non-trivial function.
C# separates its pattern `and` from its expression `&&` deliberately, and can afford to because
patterns and expressions rarely touch there; here they always do.

**A span of integers is a relational pattern.** `4..7` was refused: C#'s `..` builds a half-open
slice over *indices*, is not enumerable, and in pattern position already means "the rest" — which
this language uses for lists. **shipped**
<!-- decided by ticket 42 -->

<!-- check:
public atom Classify(int n)
-->
```csharp
Classify(>= 4 and <= 7) -> :reserved
Classify(<= -1)         -> :negative
Classify(>= 0 and <= 3) -> :low
Classify(>= 8)          -> :high
```

Those four clauses are **exhaustive over `int`** with no catch-all, which is the property worth
looking at: a span is a set the checker subtracts, not a test it takes on trust. It goes where a
whole argument goes — inside a record pattern, a tuple or a list, write the comparison as a guard.

The rule this produced, which governs future borrowings: **borrow the construct, or don't borrow
the glyph.** Where C# has the symbol but not the construct, taking the symbol buys no familiarity
and costs a false friend.

**To match against a value a name already holds, write `== name`.** A bare name in a pattern
introduces a name; `== name` matches the value that name is bound to. **shipped**
<!-- decided by ticket 45 -->

So a head that repeats a bare name — `F(acc, acc)` — is an **error**, not an equality constraint:
both are introductions, and the second rebinds what the first bound, which §1 forbids. `F(acc, ==
acc)` is how you ask for the constraint. This is the whole reason the marker exists; without it the
language has no way to say *the same value again*.

```csharp
public int RunLength(int head, list<int> xs)

RunLength(head, [])                -> 0
RunLength(head, [== head, ..rest]) -> 1 + RunLength(head, rest)
RunLength(head, [_, ..rest])       -> 0
```

It is the **equality member of the relational family above**, so a reader who has met `>= 4` in a
head reads `== acc` on sight. The family divides cleanly — **relational operators take a literal,
`==` takes a name** — so `>= acc` is not a span bounded by a runtime value, and `== 4` is not a
second spelling for the literal pattern `4`. Neither is admitted.

The space is not significant: `==acc` and `== acc` are one program. Written with the space, to match
`>= 4`.

This is the one capability with no C# equivalent at all — C# patterns cannot match a runtime value,
and push you to `when v == expected`. Here that workaround is worse than it looks, because it moves
a pattern concern into a guard, and the checker reads `var == literal` but not `var == var`: the
guard would credit nothing and the arm would subtract nothing from the residual. **A matched name
credits nothing to the certain set either.** Its value is unknown at compile time, so it may narrow
what is *possible* and never counts as coverage — a `switch` whose only non-catch-all arm matches a
name is inexhaustive over the whole subject type.

---

## 3. Exhaustiveness

**A function that does not cover its declared input does not compile.** No opt-out, no flag. The
**residual is the missing case**, which is why the diagnostic below hands you a clause to paste
rather than a complaint to interpret.
<!-- decided by ticket 04 -->

```
readings.bs:4: error: Classify is not exhaustive
  no clause matches:
    Classify((:ok, int <= 0)) -> ...
```

The error is the **missing clause**, not a complaint — the residual is computed exactly and printed
as a head you can paste in. Where it is wide, the **printed** form stops after three cases and says
how many it left; the residual itself is never summarised, and the full one is a query away.
**shipped**, and the truncation **decided**

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

**An atom is `:name`, and nothing declares one.** The universe of atoms is open; a type naming some
of them is a union like any other, which is why `Verdict` above needs no special form.
<!-- decided by ticket 10 -->

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
| `binary` | the top; `<<_:M, _:_*N>>` sizes still **decided**, unbuilt | **shipped** (top only) |
| `string` | `binary` refined by valid UTF-8; a literal is one by construction | **shipped** |
| records | see §6 | **decided** |

**Unions are exact.** Nothing widens: `<<_:32>> | <<_:64>>` stays two members rather than
collapsing into a range admitting 96 bits. This is the property the whole guarantee rests on — a
checker that must prove a residual empty cannot afford an optimistic join.

**`string` is not a second type beside `binary`** — it is `binary` refined by valid UTF-8, so it is
a *subset*. A `string` goes wherever a `binary` is declared and nothing converts between them.
A literal is a `string` **by construction**: the compiler sees the bytes and checks UTF-8 at compile
time, so no literal pays a runtime validation. An invalid one is a **compile-time error**, which is
a deliberate divergence — C# and TypeScript both substitute U+FFFD instead, and a silent
replacement manufactures exactly the invalid string the check exists to prevent. **shipped** — F9.

The other direction has no spelling, and that is the honest edge of what shipped. Turning a
`binary` into a `string` means establishing the property at run time — the O(n) entry check that
is the sixth of the compiler's standing codegen obligations — so a **foreign declaration may not
return `string`**,
and says so with the fix in the message. `binary` is admissible there, because the whole
`<<_:M, _:_*N>>` grammar reduces to `byte_size` and `bit_size rem N`, both O(1) guard BIFs. Not
built: **binary patterns**, a spelling for a **sized** binary type, string literals in **pattern**
position, and any string **operation** — the first three wait on a decision about binaries as a
parsing grammar, the last on the module system.

**Atoms:** the universe is open, nothing declares an atom, `:foo` mints one by writing it.
`true` and `false` are the only keyword atoms, `bool` is an ordinary alias, and **there is no
truthiness**. **shipped**

> **CORRECTED 2026-08-15, F7.** This paragraph said **shipped** and the keyword-atom half was not.
> The lexer had `:true` and `:false` and no bare rule, so `true` in a pattern was an ordinary
> lowercase identifier — a **variable**, matching everything. `Decide(true, p) -> :ack` /
> `Decide(false, p) -> :requeue` compiled, and returned `:ack` for `false`. Found by running the
> tuple-subject `switch` example in §5. `bin/check-language.sh` could not have caught it: the claim is
> prose, not a fenced block, and the defect is a program that compiles and means something else
> rather than one that fails.

---

## 5. Control flow

**`switch` is the only branching construct.** There is no `if`, no `else`, no ternary.
<!-- decided by ticket 17, which also settled `|>` and `|?>` -->

<!-- check:
type Verdict = :new | :gone | :unknown
record Order { Id: int, Status: atom }
-->
```csharp
public Verdict Describe(Order o)

Describe(o) -> o.Status switch {
    :placed  => :new,
    :shipped => :gone,
    _        => :unknown
}
```

The `_` here is legal because `Status` is an `atom` and the atom universe is open, so the residual
cannot be enumerated — which is the only shape a catch-all is admitted over. Over a *closed*
residual, where the compiler knows the missing case by name, §2 makes `_` an error telling you to
name it. **That rule is decided and is not yet enforced**, at a switch arm or at a clause head.

For compound conditions, the subject is a **tuple** — which is the clause head's own shape, one
level down:

<!-- check:
type Disposition = :ack | :dead_letter | :requeue
-->
```csharp
public Disposition Decide(bool ok, bool permanent, bool redelivered)

Decide(o, p, r) -> (o, p, r) switch {
    (true,  _,     _)     => :ack,
    (false, true,  _)     => :dead_letter,
    (false, false, false) => :requeue,
    (false, false, true)  => :requeue
}
```

Exhaustive with **no catch-all**, and the compiler agrees. An arm may also carry a guard —
`n when n < 5 => :retried` — or a relational pattern, `>= 5 => :exhausted`, since an arm takes the
clause head's pattern grammar whole. Nested inside a record pattern, `{ Deliveries: > 5 }` is not
built: a relational pattern goes where a whole argument goes.

**shipped** — F7.

`else` is absent because it is what a *binary unnamed* conditional needs; every fall-through here is
a pattern. `cond` is **open** — deliberately unpaid-for until the shape is shown to occur. Measured
so far: a four-wide tuple reads fine.

---

## 6. Records

```csharp
record Order { Id: string, Total: int, Lines: list<Line> }
record Line  { Sku: string, Qty: int }
```

**shipped** — records with F3, and the `string` fields with F9. This block was tagged `not-yet`
after F3 shipped records, because `string` was still an `unknown_builtin` and the block therefore
still failed to compile — which is the bidirectional gate earning its keep in the direction that
rots quietly: nobody had to notice, CI named the line.

A record **erases to a map** carrying a tag minted from its qualified type name. Everything stays
structural — a hand-written `type` with the same tag *is* the same type — but the tag means
`Order` and `Invoice` over identical fields are two types, so `Update(Order o)` will not take an
`Invoice`.

**Records exist for dispatch.** The tag is in the term, so a union of records is dispatched by an
ordinary clause head and checked exhaustive:

```csharp not-yet
type Shape = Circle | Rect

public float Area(Shape s)

Area(Circle c) -> 3.14159 * c.Radius * c.Radius
Area(Rect r)   -> r.W * r.H
```

That is a protocol without a protocol construct. What it does **not** give you is *open* extension —
another module cannot add `Triangle` without editing `Shape`.

Construction names the type; the dot projects; `with` updates. **There are no local
bindings** — see §1 — so each of these is a function, and that is what the language looks
like:

```csharp not-yet
public Order Draft()
Draft() -> Order { Id = "A-1", Total = 500, Lines = [] }

public Order Pay(Order o)
Pay(o) -> o with { Total = 600 }

public int Amount(Order o)
Amount(o) -> o.Total
```

Note `:` in declarations and patterns, `=` in construction and update. **No optional fields** —
every declared field is always present, and absence is `option<T>`.

`with` is **width-preserving**: it updates fields that are already there and raises on one that is
not, so a record cannot grow through it. There is no spread — a widened record would carry a
minted tag while not being that record, and no signature could be written against it.

**shipped**, with two things worth knowing:

- **The pattern spelling is the property pattern.** Dispatch is written
  `Area({ Kind: :'Shapes.Circle' })`, not `Area(Circle c)`. The tag is an ordinary field, so no
  record-specific pattern form is needed; whether a sugar mirroring construction is added is a
  grammar-opinion question that is still open. The `Circle c` form above is illustrative and does
  **not** compile today.
- **A construction site is not checked.** A record's field set is exact in the type algebra and
  unpoliced where it is built, so a body can produce a map wearing an `Order` tag without
  `Order`'s fields. The compiler checks five sites in a body, and a construction is not one of
  them.

---

## 7. Errors

There is no global error-model preference: **write the honest value your return type admits**, and
`raise` only where it admits none.

```csharp not-yet
type option<T> = T | :nothing
type result<T, E> = T | (:error, E)
```

Both are **in the compiler**, and the block above stays planned surface for one reason: they are
**prelude** entries and the prelude namespace is lowercase, while `type` declares a PascalCase name.
So this is what the prelude holds, not something you can type. What you can type is the use:

<!-- check:
type Weighed = result<int, atom>
-->
```csharp
public atom Grade(Weighed w)
Grade((:error, e))     -> e
Grade(n) when n > 1000 -> :heavy
Grade(n)               -> :light
```

Exhaustive, and nothing in those clause heads knows about a bracket: `result<int, atom>` is
`int | (:error, atom)` before the checker sees it.

**Absence carries nothing; failure carries a reason.** The tag is a consequence of the payload, not
a style choice: `atom | :error` collapses (`:error` is absorbed into the atom top) while
`atom | (:error, binary)` does not.

`raise` takes any term. **There is no `try`** — a foreign call that can throw gets a wrapper the
compiler writes from your declared return type, and process failure is `monitor` plus `receive`,
which yields a better reason than `try` does.

**decided**

---

## 8. Pipelines

The **pipe** `|>` passes the value on its left in as the **first argument** of the call on its
right. It is a rewrite and nothing else — `xs |> Sum(0)` *is* `Sum(xs, 0)`, so exhaustiveness, the
five check sites and the emitted `-spec` all see an ordinary call.

```csharp
public int Restated(list<int> xs)
Restated(xs) -> xs |> Sum(0)

private int Sum(list<int> xs, int acc)
Sum([], acc)          -> acc
Sum([x, ..rest], acc) -> Sum(rest, acc + x)
```

The right operand is a **call**, never a bare name: `xs |> Sum` is a *syntax* error rather than a
type error, because a function value is not a thing this language has.

Names are **qualified** — `List.Sum`, not `xs.Sum(0)`. Method-call syntax would need type-directed
resolution of an unqualified name, which the language has deliberately closed off. The pipe is what
survived that argument rather than a second spelling beside it.

`|?>` is the **valve**: it stops on the first `(:error, _)`, runs no further stage, and returns
that error unchanged.

```csharp
type Res = int | (:error, atom)

public Res Place(int n)
Place(n) -> Validate(n) |?> Charge()

private Res Validate(int n)
Validate(n) when n > 0  -> n
Validate(n) when n <= 0 -> (:error, :bad_request)

private Res Charge(int v)
Charge(v) -> v * 2
```

`Charge` is declared over `int` and **not** over `Res`, which is the payoff rather than an
oversight: the valve has already subtracted the error member, so what reaches a stage is the
narrowed type, and naming the whole union there would claim a case the function can never be
handed. A `|?>` over a type with **no** `(:error, _)` member is an error rather than a dead branch —
the compiler says to write `|>` instead.

The escape hatch is the operator's **absence**. Write `|>` and match `(:error, _)` in your own
clause when a stage wants to inspect the failure; that is also the only way to turn one error into
another.

Both operators are built. What is **not** built is the collection prelude they are usually shown
with — `List.Map` and friends as compiler-known functions — nor the function *value* that `f` and
`g` stand for here, which this language was measured not to have:

```csharp not-yet
xs |> List.Map(f) |> List.Filter(g)
```

There is **no comprehension syntax**. The compiler inlines its own collection operations, which
recovers precise emitted types that a call to a generic function loses.

**decided**

---

## 9. Generics

Real parametric polymorphism, in its smallest working form. **Two halves, and only the first is
built**, and the split is the generics design's own: *"the costs are asymmetric and they do not
chain."*

### Parametric types — shipped

Ground applications and parametric aliases. `list<T>`, `option<T>` and `result<T, E>` come from the
prelude; your own take a parameter at the declaration and are PascalCase like any other user type.

```csharp
type Pair<T> = (T, T)

public int Sum(Pair<int> p)
Sum((a, b)) -> a + b
```

**The variable is gone before the type algebra sees anything.** `Pair<int>` is the tuple, and
`option<int>` and a hand-written `int | :nothing` are not two types that agree — they are one type.
So a bracket costs no new node in the checker and nothing in the emitted code: what is published is
the expanded ground `-spec`.

A recursive type is **refused by name** rather than expanded. Recursion is decided — equirecursive
and **contractive** — and the algebra cannot hold one yet, so every recursive definition is an error
today. But there are **two** refusals, and they are not the same thing.

A definition whose recursion passes through a **constructor** — a tuple, a `list<T>`, or a record
field — describes a real set of values. It is well formed, and the refusal is a gap in the compiler:

```csharp not-yet
type Tree = :leaf | (:node, Tree, Tree)
```

A definition whose recursion passes through nothing but unions and aliases describes no value at
all, and no amount of implementation will change that. A union is a **Boolean connective, not a
constructor**:

```csharp not-yet
type X = X | int
```

The compiler says which of the two it has found. That distinction is the whole reason it is written
down here: an author who wrote the first should wait for a feature, and an author who wrote the
second should rewrite their type, and one diagnostic cannot tell them apart.

### Polymorphic function signatures — next

```csharp not-yet
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

**Why this half is not built yet, plainly.** `Map` above needs `fn(T) -> U` in a signature and a
lambda to pass to it, and the language has neither — there is no arrow in the type algebra. And
matching a variable that sits **inside a union** (`int Unwrap<T>(option<T> o)` asks for
`int | :nothing` against `T | :nothing`) is a question about subtraction that nothing has decided.
The first half needed neither.

**User code never writes a type argument.** Only three compiler-known names take an explicit one:
`ValidateAs<T>`, `ParseAtom<T>`, `ToExistingAtom`. So `<` opens a bracket after one of those names
and is comparison everywhere else — a lexer rule on a closed set, with no lookahead and no turbofish.
<!-- decided by ticket 28, measured against four grammar variants; same ticket cleared `..` for list rest -->

**decided**

---

## 10. The boundary

**Every value from outside is a `term` until you match it.** There is no `dynamic`, no cast, and no
second weaker subtyping relation.

The **clause head is the decoder**, and the exhaustiveness residual is the case you failed to
handle:

```csharp not-yet
public Verdict Handle(term msg)

Handle((:ok, n)) when is_int(n) -> :fine
Handle(_)                       -> :unknown
```

Patterns over a `term` may only ask what one BEAM guard decides in **O(1)**. Deep validation is an
explicit call to a generated `ValidateAs<T>`, which returns `result<T, ValidationError>` — because
a dispatch construct must not do unbounded work whose size a foreign sender chooses.

<!-- check:
record Reading { Sensor: string, Value: int }
-->
```csharp
public result<list<Reading>, ValidationError> Decode(term t)

Decode(t) -> ValidateAs<list<Reading>>(t)
```

**shipped** — `examples/Intake` runs it. Handed a list holding one reading whose `Value` is
`:warm`, `Decode` returns `(:error, (["[0]", ".Value"], "int"))`; handed a well-formed one it
returns the list unchanged.

`ValidateAs<T>` is a **codegen obligation, not a call**. The compiler reads the type argument,
generates a traversal for that one concrete type, and lowers the call site to a local call of it —
so `<T>` never becomes a runtime value and no type variable survives into the algebra. `T` must be
**ground**: a codegen obligation cannot be generated for a type nobody has chosen yet, which is why
`ValidateAs<TSource>` inside a polymorphic function is an error rather than a generic call.

**`ValidationError` is a path into the term plus the type expected there** — a `(list<string>,
string)` today, and a candidate to become a record if one is ever introduced for it. A path segment
is spelled the way you would reach that place: `".Value"` for a field, `"[0]"` for a list element,
`"(2)"` for a tuple component. An empty path means the term itself was wrong.

The bracket is admitted after **exactly three** compiler-known names — `ValidateAs<T>`,
`ParseAtom<T>` and `ToExistingAtom` — and after nothing else, which is what keeps `<` a comparison
everywhere in the language. Of the three, only `ValidateAs<T>` is built; the other two are refused
by name.
<!-- decided by tickets 11 §2, 15 §2, 27 §8 and 28; built as F18 -->

**Validating against `term` is an error.** `result<term, ValidationError>` normalises straight back
to `term`, so the failure channel does not survive and no caller could write the failure clause.
The rule is general — an instantiation whose union with its own failure member is the type it
started from is refused — and `term` is the only one that trips it.
<!-- the general rule is ticket 15 §1's, met at an instantiation rather than at a declaration -->


**A declared type at an entry is checked.** Where generated code consumes a value, a guard is
emitted, always, with no opt-out. The guarantee is:

> **A foreign term that breaks your types will crash — not always where it entered, but never
> silently.**

This is a deliberate divergence from *both* audiences: C#'s `extern` and Gleam's `@external` are
both unchecked, and both will hand you a `float` from a function declared to return an `Int`.

**decided**

---

## 11. Calling Erlang and Elixir

**A module is an atom, because on the BEAM a module *is* an atom.** So the call site is Elixir's,
and nothing is renamed:

```csharp
using :lists {
    int       sum(list<int> xs)
    list<int> reverse(list<int> xs)
}

using :erlang {
    int system_time(atom unit)
}

public int Total(list<int> xs)

Total(xs) -> :lists.sum(xs)
```

**shipped** — `bsc examples/Interop/interop.bs Total "[1, 2, 3, 4]"` prints `10`.

The declaration **attaches types to the name Erlang already has**. It does not introduce a B# name,
which is why the language needs no snake_case ⇄ PascalCase mapping anywhere — and why the parts of
OTP no mapping could reach (`'PKCS-1'`, `'OTP-PKIX'`) cost nothing.

Three dot-forms coexist, told apart by the **token class** of the left side rather than by any
casing convention:

| Form | Left side | Means |
|---|---|---|
| `o.Status` | a variable | field projection |
| `List.Map(x)` | a B# module | qualified call |
| `:ets.lookup(x)` | an atom | foreign call |

- **Exactly one arity per declaration.** Foreign arity families are not defaults — `inet_udp:send/2`
  and `/4` exist with no `/3`.
- **Elixir is the same construct**, `using :"Elixir.Enum"`. Its *macros* are unreachable: they are
  exported as `MACRO-`-prefixed functions and are not callable from another language, so
  `use GenServer` cannot cross. **decided** — quoted atoms are not lexed yet.
- A foreign declaration may promise only what one BEAM guard decides in O(1). `list<Order>` is an
  error at the declaration; it crosses as `list<term>` plus `ValidateAs<T>`. **decided**

**Owed:** the compiler-written wrapper and the boundary guard of §10 are *not* emitted yet — a
foreign call currently compiles to a bare remote call, so a foreign term that breaks your types is
not yet caught at the boundary. That is the gap between §10's guarantee and what runs today.

## 12. Processes

The concurrency vocabulary is OTP's, and **nothing in it is parameterised by a message type**.

```csharp
module Counter

behaviour GenServer

type Request = :get | (:add, int)
type Reply   = (:reply, int, int)

public (:ok, int) Init(int seed)

Init(seed) -> (:ok, seed)

public Reply HandleCall(Request request, term from, int state)

HandleCall(:get, from, state)      -> (:reply, state, state)
HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)

public (:noreply, int) HandleCast(term msg, int state)

HandleCast(msg, state) -> (:noreply, state)
```

**shipped** — `behaviour GenServer` emits `-behaviour(gen_server)`, and the two `HandleCall` clauses
are proved to cover `Request` with no catch-all.

**All three callbacks are here because all three are mandatory**, and declaring the behaviour
without them is now an **error at the `behaviour` line**. This block previously showed `HandleCall`
alone; the emitted module then declared a contract it could not satisfy, and `bin/spec-check.sh` was
red on `master` for a day because of it.

**A callback lowers to its OTP name** — `HandleCall` emits `handle_call`, which is what `gen_server`
actually calls. That is a **compiler-known table, not a rule**: a snake_case⇄PascalCase mapping was
measured unable to spell `'PKCS-1'` or a quarter of Elixir's function names, so the language has
none. The table is **contract-scoped and keyed by name *and* arity** — `HandleCall`
in a module declaring no behaviour, or declaring `Supervisor`, stays `'HandleCall'`.

**`uses`, not `using`.** `using GenServer` is the same three tokens as a single-segment import, and
only a symbol table could tell them apart — the type-directed resolution the language refuses
everywhere else. `uses` reads as a fact about the module and is one letter from Elixir's
`use GenServer`, which is this exact construct.

A behaviour **names a contract the compiler knows as a type**: you write a narrower signature and
the compiler checks containment. **partly shipped** — the compiler knows the callback set and
enforces **presence**, so a missing mandatory callback is an error naming what to write. The
**type** half is not the compiler's yet, and measurement says it is largely free: Dialyzer checks a
callback's spec against OTP's own `-callback` at the boundary, accepts the narrower signature this
paragraph promises, and still reports a wrong one as `Invalid type specification`.

There is no typed `Pid<T>` — a process identifier is a `pid`, and the message type belongs on the
client API function's signature, where you were going to write it anyway.

**No `async`, `await` or `Task`.** `async` colours functions, which is a second effect system.

`receive` is a **filter**, exempt from exhaustiveness — unmatched messages stay in the mailbox,
which is what `gen_server:call`'s own reply correlation runs on. **decided**

## 13. Refinements

```csharp
type Octet = int where value >= 0 and value <= 255
```

Where the predicate is a **single BEAM guard**, a refinement is reasoned about by the checker and
may appear in a clause head and at a foreign boundary. The predicate takes the same `and` / `or` as
guards and patterns — one conjunction everywhere. **shipped**

`value` names the value being refined. It is an ordinary name and not a keyword, so a parameter may
still be called `value`; the word means the subject only inside a `where`.

A refinement is a **subset of its base**, not a type beside it, so `Octet` is an `int` everywhere an
`int` is wanted and the emitted `-spec` says `0..255` rather than `integer()`. A predicate the
checker cannot read is an **error** rather than a silent widening — otherwise a refinement that
narrowed nothing would look exactly like one that worked.

**Refinements and interval patterns must land together.** Today a parameter
declared `int` has an **open** residual, so a dispatch over it gets its `_` for free. The moment a
refinement bounds the type, that residual **closes** — and a catch-all over a closed residual is an
error. So a refinement without a way to name a span turns working programs into rejected ones,
which is why the span pattern above is part of the same change rather than a later convenience.
<!-- decided by ticket 12 §2; the coupling is F2's -->

An **opaque** refinement — `binary where valid_utf8`, O(n) — may be declared, but is **barred from
clause heads and foreign declarations**. Inside, the caller is known and the obligation is
dischargeable; at the boundary the caller is unknown and it is unbounded cost with nothing to
discharge it against.

**shipped** — and the pairing held: interval *patterns* landed with interval *refinements*, in one
change, because either alone breaks wire parsing. A parameter declared `int` leaves every byte-wide
dispatch open; a refinement without a span pattern closes it with nothing to answer in.

---

## 14. What is deliberately absent

Most of this table is an inventory of C#'s functional surface, sorted into what ports and what is
**subsumed** by moving patterns into the parameter position. A construct is absent here because
something else already covers it, not because it was disliked.
<!-- decided by ticket 05 -->

| Absent | Because |
|---|---|
| `if` / `else` / ternary | `switch` is the only branching construct; every fall-through is a pattern |
| `;` | the grammar needs no terminator |
| macros | a large semantic surface that interacts hard with a type system; today the compiler generates code and users do not. **Absent, not refused** — see the map's amendment of 2026-08-15: out of *this map's* scope, and open should a use case arrive that nothing else serves (a DDD/resource surface of Ash's kind is the named candidate) |
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
| records — declaration, construction, `with`, the dot, tag dispatch | **shipped** |
| local bindings in a body, with rebinding and unbound names rejected | **shipped** |
| destructuring binds (`(a, b) = pair`), where they cannot fail | **shipped** |
| the boundary tag guard on an exported record parameter | **shipped** |
| exact field sets at a construction site | **shipped** |
| call arguments, projections and clause returns checked in a body | **shipped** |
| refinements + interval patterns | blocked on two spellings |
| `switch`, including a tuple subject and a guard on an arm | **shipped** |
| `string` and `binary` as values — the literal, the refinement, the boundary rule | **shipped** — F9 |
| binary patterns `<<...>>`, and a spelling for a sized binary type | not started — the binaries decision is open |
| the UTF-8 entry check (`binary` → `string`) | not started — the sixth codegen obligation |
| pipe and valve | not started |
| parametric types — `result<T, E>`, `option<T>`, `type Pair<T>`, nesting | **shipped** |
| polymorphic function signatures (`Map<T, U>`) | not started — needs an arrow type |
| modules, imports, `using` | not started |
| foreign calls (`using :lists {...}`) | **shipped**, without the boundary guard |
| `behaviour GenServer` — the attribute, callback names, and mandatory-callback presence | **shipped** — F10 |
| behaviour contract checked as a **type** | not started — Dialyzer does it at the boundary today |

### Known inconsistencies

- **Bare clause heads.** The exemplars elide the function name (`(body) -> ...`); the compiler
  requires it (`CreateOrder(body) -> ...`). One of the two is wrong and it has not been settled.
- **Map literals.** `#{ error = "invalid" }` appears in an exemplar and is specified nowhere.
- **`float`** has no decided literal syntax, which matters because `1..5` only lexes as a range
  while the float rule demands digits either side of its dot.

---

## 18. Open questions

- The language's **name**.
- ~~**Module and namespace system**~~ — **built**. What remains open is only whether `using` gains
  an **alias** (`using Orders = Shop.Orders`).
- **Stdlib shape** — what is in the prelude versus a module you import.
- **`cond`**, or whatever serves a long ladder of unrelated conditions.
- **Laziness** and `stream<T>` — deferred, not refused.
- **Bootstrapping** — how much of B# is written in B#. The front end likely stays Erlang, as
  Elixir's did; the OTP layer is the valuable target.

---

*Rationale for every decision above, and the measurements behind them, are in `wayfinder/`. This
document is the language; that directory is why.*
