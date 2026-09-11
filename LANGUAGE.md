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

A decided construct carries one, so a paragraph can be traced to the ticket that decided it
without a ticket number appearing in the prose — the comment is the only place one may appear.
Nothing checks that every construct has one.

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

using Shop.Collections.Ints
using Shop.Collections

public int Restate(int n)
Restate(n) -> Sum([n, n, n], 0)

public int Counted(int n)
Counted(n) -> Ints.Length([n, n])

public int Fully(int n)
Fully(n) -> Shop.Collections.Ints.Sum([n], 0)
```

`using Shop.Collections.Ints` brings that module's names in **unqualified** — TypeScript's
named-import semantics exactly. `using Shop.Collections` names a **namespace** and brings its modules
in short-qualified (`Ints.Length(...)`). A namespace is a path other modules sit under; it is erased
entirely, with no atom and nothing emitted. A fully qualified call is always legal regardless of what
is in scope, which is why every **diagnostic** prints that form and never has to know the call site's
scope. **shipped**
<!-- decided by ticket 41 §1/§2/§5; built by F11 -->

Resolution is by name **and arity**, and it happens at compile time: an unqualified call to an
imported name emits a *remote* call, so nothing is resolved at run time. A name reachable from two
sources is an error at the call site printing the qualified candidates. An import that brings in a
name the module **also declares** is not an error: the local wins, because resolution is *local, then
imports*, so the bare name has one meaning rather than two. A qualified call to a module with no
`using` is an error too — a file's `using` lines are its dependency list, and a call that skipped
them would make that list wrong. **shipped**

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

**A guard cannot call your functions.** The BEAM admits only its own guard functions in a guard,
never a user-defined one, and this language inherits that rather than hiding it. A call to one of
your own functions, to a sibling module, or to a foreign function that is not one of the BEAM's
guard functions is refused at the guard, in this language's words and naming the callee as you
wrote it. A foreign call to a guard function, `:erlang.byte_size(b) > 2`, is legal. The repair is a
switch on the call's answer in the body, where it is typed and checked for exhaustiveness.
**shipped** — F41
<!-- decided by ticket 63 Q4, which left the restriction inherited; F41 owns the voice -->

<!-- diagnoses: call_in_guard -->
```csharp
module Access

public atom IsAdmin(int u)
IsAdmin(1) -> :yes
IsAdmin(_) -> :no

public atom Check(int u)
Check(u) when IsAdmin(u) == :yes -> :admin
Check(_)                         -> :ordinary
```

— *`Check` calls `IsAdmin` in a guard; a guard asks a question about the values a clause already
matched, it cannot call a function. Move the call into the body and switch on its answer.*

**One spelling, in every position** — guard, pattern and refinement predicate. There is no `&&` and
no `||`; they were removed rather than kept as synonyms. This language puts patterns in the
*parameter* position, so a pattern and a guard sit on the same line in every non-trivial function.
C# separates its pattern `and` from its expression `&&` deliberately, and can afford to because
patterns and expressions rarely touch there; here they always do.

**There is no `not`, and no `!`.** Negation is not an operator in this language. The comparisons a
guard admits already come in opposite pairs — `<=` against `>`, `>=` against `<`, `!=` against `==`
— so the complement of any guard the checker can read is a guard you can already write, and a `not`
would compile to exactly that. Where the checker *cannot* read a predicate, negating it buys nothing
either: such a clause credits nothing towards exhaustiveness, and a refinement that cannot be
translated is a hard error rather than a silent widening. Which case a clause takes is the head's
job, not an operator's. Typing either spelling is met by a diagnostic naming the comparison to use
instead. **shipped**
<!-- decided by ticket 63; `not` remains a legal identifier, which is ticket 65's question.
     Its two re-open triggers live in ticket 63 and in F27, NOT here: `build-packet.py`
     strips a ticket citation from the audition packet and keeps every other comment, so a
     note about this project's process would reach a clean-room reader as if it were spec. -->

A construct all four neighbouring languages have is refused here, so it is worth saying why it is
not a divergence in practice. Every negation in a guard across OTP 28's `stdlib` and `kernel` — 16
of them — wraps a type test or `is_map_key`. Type tests are absent from this language by design and
`is_map_key` is a pattern, so the category those languages reach for `not` to negate is the category
this one moved into the clause head.

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

**A list pattern is a prefix, and a rest marker is optional.** `[a, b]` is exactly two; `[a, b, ..]`
is two or more and discards the tail; `[a, b, ..t]` is two or more and binds it. The marker is a
marker and not a pattern — `..` or `..name`, nothing else — so a list pattern says how long the list
is and what is in the positions it names, and nothing about the rest. **shipped**
<!-- ticket 08 as amended by ticket 54; ticket 53 found the closed form and
     ticket 54 replaced its spelling; the four-language survey is in 54 -->

`[a, b]` means exactly two in Erlang, Elixir, C# and Gleam alike. That is the one place this
language's two reference families agree, so refusing it was the divergence rather than admitting it
— and the refusal used to advise `[a, b, ..t]`, which means something else.

<!-- check:
public atom Dispatch(list<string> path)
-->
```csharp
Dispatch(["orders"])     -> :index
Dispatch(["orders", id]) -> :show
Dispatch(_)              -> :not_found
```

That is how a route table distinguishes `/orders` from `/orders/42` without a length guard, and
`/orders/42/lines` reaches the catch-all rather than being swallowed by the second clause.

**The checker sees the length, and it does so without ever measuring one.** A non-empty list is a
product of an element and a tail, subtracted by the same rule that already subtracts tuples exactly,
so length falls out of the recursion rather than being carried beside it. The residual is then a
clause you can paste: `[]` beside `[a, b, ..]` leaves `[int]` — exactly-one — where a language with
an O(1) length would say `{ Length: 1 }` and this one has no `length` to say it with. Depth is
bounded by the longest prefix any clause writes, per nesting level, which is what makes the
recursion terminate. **shipped**
<!-- ticket 54, built as F20; the repro it deletes is four lines and is in that ticket -->

A consequence worth stating: a closed residual over a list forbids a catch-all exactly as any other
closed residual does, so a `list<bool>` missing its two length-one cases is an error naming
`[true]` and `[false]` rather than a `_`. That bites only where the element type is closed — over
`list<int>` the element is unbounded, the residual stays open, and `_` remains legal.

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

<!-- expect-after: delete Classify((:ok, n)) -> :negative -->
```csharp
type Verdict = :positive | :zero | :negative | :unknown
type Reading = (:ok, int) | (:error, atom)

public Verdict Classify(Reading r)

Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n))            -> :negative
Classify((:error, e))         -> :unknown
```

Delete the third clause and the compiler answers:

```
error: Classify is not exhaustive
  no clause matches:
    Classify((:ok, n)) when n <= -1 -> ...
```

The error is the **missing clause**, not a complaint — the residual is computed exactly and printed
as a head you can paste in. Where it is wide, the **printed** form stops after three cases and says
how many it left; the residual itself is never summarised, and `--diagnostics term` carries
every head in `heads.pasteable`.
**shipped**, and the truncation **decided**

A **catch-all is legal only where the residual is open** — over a `term`, or any type with an
unbounded part. Where the compiler knows the remaining case names, `_` is an error: it would put
the language's headline guarantee one character from being switched off invisibly. **shipped** —
and the diagnostic names the discarded cases as a head to write instead.
<!-- decided by ticket 12 §2; enforced since F2 (2026-08-16). This paragraph said "decided" —
     unbuilt — until 2026-08-24, when exemplar 25d's surface probe re-measured the rule and
     found it firing; the correction trail is on ticket 25 -->

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

**Because the name is only an alias, a union can be written where it is used.** The declaration buys
a name and nothing else, so `Named` and `Inline` below are the same function: the same clause heads
discriminate them, the same exhaustiveness check proves them, and deleting a clause from either
produces the same residual. A union is writable in a **parameter**, in a **return position** and in
a **foreign signature** — every position that takes a type, rather than only the nested ones.

```csharp
type Reading = (:ok, int) | (:error, atom)

public int Named(Reading r)

Named((:ok, n))    -> n
Named((:error, _)) -> 0

public int Inline((:ok, int) | (:error, atom) r)

Inline((:ok, n))    -> n
Inline((:error, _)) -> 0

public :ok | :error Pick(int n)

Pick(n) when n > 0  -> :ok
Pick(n) when n <= 0 -> :error
```

**shipped** — ENG-331.
<!-- decided by ticket 68 Q7 -->
<!-- see compiler/examples/Aliasing/aliasing.bs -->



**An atom is `:name`, and nothing declares one.** The universe of atoms is open; a type naming some
of them is a union like any other, which is why `Verdict` above needs no special form.
<!-- decided by ticket 10 -->

| Type | Notes | Status |
|---|---|---|
| `int` | arbitrary precision; carries real intervals in the checker | **shipped** |
| `atom` | open universe, cofinite top | **shipped** |
| `:ok` | a singleton atom type | **shipped** |
| `(A, B)` | tuple | **shipped** |
| `list<T>` | `[]` and `[h, ..t]` partition it, and a longer prefix narrows it: the cons cell decomposes, so length falls out without the type carrying one | **shipped** |
| `term` | the top type — everything | **shipped** |
| `none` | the bottom type — `raise` has it, and every exhaustive function's residual is it. First-class: writable in a signature, so a function that never returns can be declared. Not to be confused with `:nothing`, which is a value, nor with C#'s `void`, which returns — see §7 | **shipped** |
| `float` | | **open** |
| `binary` | the top, and it stays the top — sizes are not in the type language | **shipped** |
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
built: any string **operation**, which waits on the module system. **Binary patterns** and string
literals in **pattern** position shipped with F13 and are below.

The check looks inside the declared type, so a `string` anywhere in a foreign return is refused:
a list element, a tuple member, a `map<K, V>`'s key or value. A database driver that returns a row
keyed by column name:

<!-- diagnoses: foreign_ret_beyond_one_guard -->
```csharp
module Analytics

using :analytics_db {
    map<string, term> latest_row(binary site)
}

public map<string, term> LatestRow(binary site)

LatestRow(site) -> :analytics_db.latest_row(site)
```

— *`:analytics_db.latest_row` returns `map<string, term>`, which one guard cannot decide*. The
map is what is named, before the `string` inside it: `binary` in place of the `string` would need
every key inspected too, and §11's rule refuses any `map<K, V>` narrower than `map<term, term>`.
The edit is the route — *declare it `map<term, term>`, then `ValidateAs<map<string, term>>` where
it is used*. What crosses is the map no guard has to look inside:

```csharp
module Analytics

using :analytics_db {
    map<term, term> latest_row(binary site)
}

public map<term, term> LatestRow(binary site)

LatestRow(site) -> :analytics_db.latest_row(site)
```

and the walk the guard may not do is the validator's, at the site that uses the value:

```csharp
module Analytics

type ViewCounts = map<string, int>

using :analytics_db {
    map<term, term> latest_row(binary site)
}

public result<ViewCounts, ValidationError> PageViews(binary site)

PageViews(site) -> ValidateAs<ViewCounts>(:analytics_db.latest_row(site))
```

**shipped** — F43. The validator walks the entries in key order and checks each key against
`string` and each value against `int`, stopping at the first that fails. Handed a map holding
`"views"` against `:many` it returns `(:error, (["["views"]"], "int"))`: the path names the entry
by its key, spelled as the key is written, and the expected type is the value's. Handed `:views`
against `3` it returns `(:error, (["[:views]"], "string"))` — the key itself was wrong. A key
the language has no literal for — a tuple, a binary that is not text — is not spelled: the path
stops at the map, `(:error, ([], "map<string, int>"))`, and the expected type is the map's.

A `string` one guard reaches — a tuple member, an alias — gets the edit: *write `binary` where it
says `string`*. **shipped** — ENG-351; and since ENG-354 (F40) the `string` check is one slice of
the whole of §11's rule, under one diagnostic: a foreign `list<int>` or `map<binary, int>` is
refused the same way.


### Arithmetic on `int`

`+`, `-` and `*` are the operator table, and they are all of it. **shipped**

```csharp
module Arith

public int Net(int gross, int tax)

Net(gross, tax) -> gross + 1 - tax * 2
```

**`/` on two `int`s is truncated integer division, and `%` is the remainder it leaves, taking the
sign of the dividend.** So `-7 / 2` is `-3` and `-7 % 2` is `-1` — C#'s meaning, TypeScript's
meaning, and exactly Erlang's `div` and `rem`. It is *not* Erlang's `/`, which is float division
and would make the same expression `-3.5`. The rule is stated over the operand types rather than
over the operator, so a later `float / float` stays available.

Call it a **remainder**, never a modulus: they differ exactly on negative operands, and Python's
`-7 % 2 = 1` is the modulus this is not.

**`/` carries no precondition.** A divisor needs no proof that it is non-zero, so `/` stays total
over its declared operand types like every other operator. The compiler refuses only a divisor it
can prove *is* zero; one that merely might be crashes at run time with `badarith`. **shipped** — F26.
<!-- decided by ticket 38; §2(b), a proof obligation on every divisor, was refused on cost to the caller -->

`int` is arbitrary precision on the BEAM — not 32- or 64-bit — and division keeps it that way:
`2^100 / 7` is exact, and the quotient and remainder still reconstruct the dividend.

```csharp
module Fuel

public int Fuel(int mass)

Fuel(mass) -> mass / 3 - 2
```

### Binary patterns
<!-- ticket 30 -->

**A binary gets no structure in the type language, and there is no sized binary type.** `binary<32>`
and `type Header = <<_:32>>` are not coming. What a segment gives you instead is a **refinement on
the value it binds**: `t:8` binds an integer known to be `0..255`, which is an `Octet` without
anyone declaring one. **shipped** — F13.

<!-- check:
type Octet = int where value >= 0 and value <= 255
type Frame = (:method, int) | (:header, int) | :heartbeat | (:error, atom)
private Frame Classify(Octet t, int ch, binary payload)
Classify(1, ch, p) -> (:method, ch)
Classify(2, ch, p) -> (:header, ch)
Classify(8, ch, p) -> :heartbeat
Classify(>= 9, ch, p) -> (:error, :unknown_frame_type)
Classify(<= 0, ch, p) -> (:error, :unknown_frame_type)
Classify(>= 3 and <= 7, ch, p) -> (:error, :unknown_frame_type)
-->
```csharp
public (Frame, binary) DecodeFrame(binary b)

DecodeFrame(<<t:8, ch:16, size:32, payload:size, 0xCE:8, rest>>)
    -> (Classify(t, ch, payload), rest)
DecodeFrame(_) -> ((:error, :incomplete), "")
```

A segment's width is written after a colon and is a number of **bits**, so sub-byte fields are
ordinary: RFC 6455's header is `<<fin:1, 0:3, op:4, 1:1, len:7>>`. A segment with **no** width is
the remainder and must come last — a divergence from Erlang, where a bare `<<A, B>>` is two *bytes*.
Integer literals may be written in hex (`0xCE`), anywhere in the language and not only here.

`payload:size` is a segment sized by a variable bound earlier in the same pattern. It runs, and the
size is **erased** — `payload` is a `binary` and nothing downstream knows its length. Relating two
fields of one pattern is not a thing this language does, and no language on the BEAM does it either.

A `_` over a binary is **always** legal, because a binary can always be truncated. So the binary
pattern is for **shape**, and value dispatch belongs in a function head, where the residual is
computed and exhaustiveness bites:

<!-- check:
type Octet = int where value >= 0 and value <= 255
-->
<!-- expect-after: delete Classify(>= 9); delete Classify(0); delete Classify(>= 3 and <= 7) -->
```csharp
private atom Classify(Octet t)

Classify(1) -> :method
Classify(2) -> :header
Classify(8) -> :heartbeat
Classify(>= 9) -> :reserved
Classify(0) -> :reserved
Classify(>= 3 and <= 7) -> :reserved

public atom Read(binary b)
Read(<<t:8, rest>>) -> Classify(t)
Read(_) -> :incomplete
```

Omit the three `:reserved` clauses and the compiler answers:

```
error: Classify is not exhaustive
  no clause matches:
    Classify(0) -> ...
    Classify(>= 3 and <= 7) -> ...
    Classify(>= 9 and <= 255) -> ...
```

**Write the tag dispatch inline in the binary patterns instead and the checking is silently lost** —
the catch-all you needed for truncation also swallows every wire value you forgot, and no diagnostic
will tell you. That is the one sharp edge of this design, and it is deliberate: seeing through it
would mean splitting the residual per segment.

### String literals in pattern position
<!-- ticket 30 -->

Admitted. A `string`'s residual is **always open**, so a catch-all is required and legal, and a set
of string literals is never exhaustive on its own. **shipped** — F13.

```csharp
public atom Greet(string s)

Greet("hello") -> :hi
Greet(s)       -> :other
```

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
name it — **shipped**, at a switch arm and at a clause head alike.
<!-- enforced by F2 (2026-08-16). This sentence read "decided and is not yet enforced" for eight
     days after F2 landed; corrected 2026-08-24 when exemplar 25d's probe re-measured it -->

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

Exhaustive with **no catch-all**, and the compiler agrees. An arm takes the clause head's pattern
grammar whole, so it may carry a guard, or be a relational pattern:

```csharp
public atom Classify(int n)

Classify(n) -> n switch {
    m when m < 5 => :retried,
    >= 5         => :exhausted
}
```

**The name a guarded arm introduces must be fresh** — `m` above, not `n`. §2's rule reaches here:
a bare name in a pattern *introduces* a name, so an arm written `n when n < 5` where `n` is already
the parameter is `rebinding`, not a match against it. **The guard is not what makes it an error.**
A bare `n` as an arm pattern is rejected with no guard present at all; `m when m < 5` and a plain
`< 5` are both accepted. To match the value `n` already holds, §2's spelling is `== n`.
<!-- ticket 45 owns `== name`; ticket 34 owns rebinding. This paragraph exists because §5 used to
     illustrate the guard with `n when n < 5` beside a parameter named `n` — a program the compiler
     rejects — in loose prose that no fence gated. Three clean-room candidates read the packet, had
     §2's rule in front of them, and all three reproduced the illustration rather than the rule:
     handoff/audition-switch, round 1, 2026-08-22. An example outranks a stated rule when the two
     disagree. -->

Nested inside a record pattern, `{ Deliveries: > 5 }` is not
built: a relational pattern goes where a whole argument goes.

**shipped** — F7.

`else` is absent because it is what a *binary unnamed* conditional needs; every fall-through here is
a pattern. `cond` is **open** — deliberately unpaid-for until the shape is shown to occur. Measured
so far: a four-wide tuple reads fine.

### What the compiler says about a switch

A `switch` is **checked**, not merely compiled, and there are nine things it can be told. Every
one names the file, the line and the enclosing function, and hands back the material needed to fix
it rather than only reporting that something was wrong.

Five of these are about the arms as a set, three are about what an arm's body does, and one is
about where a `switch` may appear at all.

**A switch must cover its subject.** If some value of the subject's type matches no arm, that is
`switch_inexhaustive`, and the message hands back the arm you have not written:

<!-- diagnoses: switch_inexhaustive -->
```csharp
public atom Ready(bool b)

Ready(b) -> b switch {
    true => :yes
}
```

— *this switch in `Ready` is not exhaustive; no arm matches: `false => ...`*. The residual is the
missing case, so what makes the error legitimate is the same thing that answers it.

**An arm every earlier arm already covers is dead.** That is `unreachable_arm`, and it is a
**warning** rather than an error: the program still compiles, because the arm changes nothing.
The message counts arms from one:

<!-- diagnoses: unreachable_arm -->
```csharp
public atom Which(atom a)

Which(a) -> a switch {
    _  => :any,
    :x => :ex
}
```

— *arm 2 of this switch in `Which` is unreachable; every value it matches is matched by an earlier
arm.* Note that the catch-all is legal here, by the rule at the top of this section: `a` is an
`atom`, so the residual is open.

**An arm may also be dead without any earlier arm covering it**, and the two are not the same
mistake. If the arm's pattern is not a member of the subject's type at all, no value can reach it
no matter what the other arms do — so it is `vacuous_arm`, and the message names the type rather
than sending you to look for an earlier arm there is no reason to expect:

<!-- diagnoses: vacuous_arm -->
```csharp
type Verdict = :pass | :fail

public int Score(Verdict v)

Score(v) -> v switch {
    (:pass, n) => n,
    :pass      => 1,
    :fail      => 0
}
```

— *arm 1 of this switch in `Score` matches no value; the subject's type is `:pass | :fail`, and
this arm's pattern is not a member of it.* This is the shape the tagged unions of other languages
teach you to write. A `Verdict` is `:pass | :fail`, so `(:pass, n)` is a two-tuple that no
`Verdict` ever is — and the same reading error is what makes `(:some, s)` the first thing most
people try on an `option<T>`, which is `T | :nothing` and **untagged**. The type is the half you
do not have when you make it, so the message is the half that hands it over.

**And an arm can be dead because of its guard rather than its pattern.** Then the pattern is a
perfectly good member of the subject's type and the guard admits nothing, which is
`unsatisfiable_arm_guard` — a third repair, and a message that deliberately does *not* name the
type, because the type is not what is wrong:

<!-- diagnoses: unsatisfiable_arm_guard -->
```csharp
public int Grade(int n)

Grade(n) -> n switch {
    x when x > 5 and x < 3 => 0,
    x                      => 1
}
```

— *arm 1 of this switch in `Grade` has an unsatisfiable guard; the pattern is a member of the
subject's type, it is the guard that admits nothing.* A guard the compiler **cannot read** — one
comparing two variables, say — is not this, and is never reported: an arm is judged on its pattern
alone there, rather than the compiler announcing its own ignorance as your mistake.

**A name in an arm pattern is introduced, never matched against.** An arm whose pattern is a bare
name already in scope is `rebinding` — the rule §2 states for clause heads, reaching arms
unchanged, and the paragraph above gives it in full:

<!-- diagnoses: rebinding -->
```csharp
public atom Pick(int n, term e)

Pick(n, e) -> e switch {
    n => :same,
    _ => :other
}
```

— *`Pick` binds `n` twice; a name means one thing in a clause. There is no mutation to assign
with, so rename the second one.* Renaming is one way out; the paragraph above gives the other, for
when you meant to match the value `n` already holds rather than introduce a new name: `== n`.

**An arm's bindings are its own.** A name bound by one arm's pattern is not in scope in another
arm's body; each arm is a separate branch, and only one of them runs. Reaching for a neighbour's
name is `unbound_variable`:

<!-- diagnoses: unbound_variable -->
```csharp
public term Bad(term e)

Bad(e) -> e switch {
    (:ok, v) => w,
    (:no, w) => w
}
```

— *`Bad` uses `w`, which nothing binds; a name comes from a clause head or a binding above it.*
The second arm is well-formed: `w` is bound by its own pattern and used in its own body.

**Every arm returns a value the signature declares.** The declared return type covers the whole
`switch`, not each arm separately, so a single arm returning something outside it is
`return_not_declared`:

<!-- diagnoses: return_not_declared -->
```csharp
public atom Verdict(bool b)

Verdict(b) -> b switch {
    true  => :yes,
    false => 0
}
```

— *`Verdict` returns a value its signature does not declare; not covered by the declared return
type: `0`.* Where the clauses justify a wider signature, the message also offers the one they
support, so the fix can be to the declaration rather than to the body.

**An arm's body is checked against what it calls.** A value that reaches an arm still has to
satisfy the functions that arm hands it to; if it does not, that is `arg_not_accepted`, reported
against the *caller*:

<!-- diagnoses: arg_not_accepted -->
```csharp
public bool Big(int n)
Big(n) -> n > 100

public atom Tag(atom a)
Tag(a) -> :seen

public atom Check(int n)
Check(n) -> n switch {
    m when m > 100 => Tag(m),
    _             => :small
}
```

— *`Check` hands `Tag` an argument it does not accept; argument 1 is not covered by `Tag`'s
declared type: `int`.* The proposed edit is always to the function being checked, never to the
callee: the fix is `Check`'s to make.

**A guard may not branch.** A guard asks a question about values a clause has already matched, so a
`switch` inside one is `switch_in_guard` — a parse the expression grammar allows and the checker
refuses:

<!-- diagnoses: switch_in_guard -->
```csharp
public atom F(atom x)

F(x) when x switch { :a => true, _ => false } -> :yes
F(x) -> :no
```

— *`F` has a switch in a guard; a guard asks a question about the values a clause already matched,
it cannot branch. Move the switch into the body.*

<!-- Every example above is compiled by `check-language.sh`, which asserts the block provokes that
     diagnostic and no other. ENG-248: `unbound_variable`, `arg_not_accepted` and `switch_in_guard`
     were emitted by the compiler and named nowhere in this file, so a clean-room reader could not
     have known they existed. The audition report that found the first two counted six diagnostics
     and there were seven — `switch_in_guard` is asserted as a bare atom in `switch_tests.erl`,
     where a survey looking for `{tag, ...}` payloads does not see it. `check-switch-diagnostics.sh`
     re-reads that suite on every run rather than trusting a list here.

     THE COUNT IS NOT WRITTEN DOWN HERE, AND THAT IS THE POINT. It was seven on 2026-08-27 and nine
     on 2026-08-28, when `vacuous_arm` and `unsatisfiable_arm_guard` arrived with the valve work in
     `c7c99be`. The number seven then survived in this comment, in the audition README and in
     ENG-248 for eleven days, because each was re-read rather than re-measured — the same failure as
     the miscount above, one rediscovery later. Ask the gate; it has been right throughout. -->

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

`with` is **width-preserving**: it updates fields that are already there and is an **error at
compile time** on one that is not, so a record cannot grow through it. There is no spread — a
widened record would carry a minted tag while not being that record, and no signature could be
written against it.

A field assignment is also checked against the type the record declaration wrote down, and that
holds at **both** spellings — `Order{ Total = :oops }` and `o with { Total = :oops }` are the same
error, because they meet the same declaration.

The **subject** is checked before the fields are. `with` updates a record, so a value that may not
carry the field — an `int`, a bare `term`, a union with one member short of it — is refused, and
what is handed back is the member that lacks the field, the same residual the dot hands back when
it projects one:

<!-- diagnoses: field_absent -->
```csharp
public int Bump(int n)
Bump(n) -> n with { Total = 1 }
```

**shipped**, with two things worth knowing:

- **The pattern spelling is the type prefix, and the property pattern beneath it is still legal.**
  Dispatch is written `Area(Circle c)` — the form below. `Area({ Kind: :'Shapes.Circle' })` also
  compiles, because the tag is an ordinary field and no record-specific pattern form is *needed* —
  but it hand-writes a **compiler-minted, fully-qualified tag atom** to say "this is a Circle", which
  is the one place the surface makes an erasure detail load-bearing. It is the escape hatch, not the
  idiom, and nothing the language ships is written in it.
- **A construction site is not checked.** A record's field set is exact in the type algebra and
  unpoliced where it is built, so a body can produce a map wearing an `Order` tag without
  `Order`'s fields. The compiler checks five sites in a body, and a construction is not one of
  them.

<!-- decided by ticket 55; the grammar-opinion question the record section used to leave open -->

**A record pattern may name its type, and any pattern may take a trailing binder.** The name stands
in for the tag, so an erasure detail stops being something you type. The binder binds the whole
value beside whatever the pattern takes apart. All four forms are **shipped**:

<!-- check:
record Circle { Radius: int }
record Square { Side: int }
type Shape = Circle | Square
-->
```csharp
public atom Which(Shape)
Which(Circle { Radius: 1 } c) -> :unit_circle
Which(Circle c)               -> :circle
Which(Square { Side: 1 })     -> :unit_square
Which({ Side: 2 } s)          -> :two_square
Which(Square s)               -> :square
```

The last two lines are the halves separately: a bare property pattern with a binder is still legal,
and `Circle c` — a type and a name, no fields — is the shape a *parameter* already has in a
signature. The binder is a bare trailing name with no keyword: `as` is spoken for by the checked
conversion, and `=` introduces a binding in a body.

A named type narrows exactly as far as writing its tag by hand does, so a clause per member of a
union is exhaustive and one short of that is not. **`Kind` cannot be named beside a type prefix** —
it is minted, never written, and the prefix is what replaces writing it.

---

## 7. Errors

There is no global error-model preference: **write the honest value your return type admits**, and
`raise` only where it admits none.

```csharp not-yet
type option<T> = T | :nothing
type result<T, E> = T | (:error, E)
```

Both are **in the compiler**, and the block above stays planned surface for one reason: they are
**declared entries** and that namespace is lowercase, while `type` declares a PascalCase name.
So this is what the standard environment holds, not something you can type. What you can type is
the use:

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

### A failure channel that does not survive normalisation is refused

**Shipped.** A union is normalised before the checker sees it, so a failure member the success type
already contains simply disappears — and the declared type becomes the success type alone, with no
failure clause left for a caller to write. That is an **error at the declaration**, not a warning
and not a diagnostic at the match site, because the declaration is where the fix is:

    public option<atom> Lookup(int id)
    // error: `:nothing` is absorbed by `atom`
    //   the failure channel does not survive normalisation, so the type
    //   declared here IS `atom`. No caller can write the failure clause,
    //   because no failure member is left to match.
    //   hint: tag it - (:some, atom) | :nothing

The rule is one equation — reject when `T | <failure member>` is `T` — rather than a list of cases,
and that matters because the cases do not all involve an atom top. `option<option<int>>` is
`option<int>`, so "key absent" and "key present, value absent" would be the same value.
`result<(atom, binary), binary>` collapses on a **tuple shape**: `(:error, binary)` is already a
`(atom, binary)`. Both are refused, and neither has a cofinite atom anywhere in it.

It is keyed on the type, never on the spelling. `type M = atom | :nothing` is refused exactly as
`option<atom>` is, because §9 makes them one type rather than two that agree. The check runs at
every declaration that carries a written type: a signature's return and parameters, a `foreign`
signature's, a record field, a type alias body, a refinement's base — and inside a tuple or a
generic argument, since a dead channel one level down is just as dead.

`option<int>`, `option<bool>` and `result<int, binary>` are unaffected; so is `(:ok, T) | :absent`,
which is why a map lookup is spelled that way.

`raise` takes any term. **There is no `try`** — a foreign call that can throw gets a wrapper the
compiler writes from your declared return type, and process failure is `monitor` plus `receive`,
which yields a better reason than `try` does.

**Shipped**, both halves: the producing half below, and the wrapper in §11.

### Any absorbed member is refused, not only the failure channel

**Shipped.** The rule above is one case of a general one: **a member you wrote that is not in the
type is an error where you wrote it.** Any member `M` of a union where `M` is already contained by
the union of the others is refused, because the type you declared is not the type you wrote and the
difference is invisible at every later site.

<!-- diagnoses: absorbed_member -->
```csharp
module Ledger

type Label = binary | string

public int Go(int id)
Go(id) -> id
```

`string` is `binary` refined by UTF-8, so `Label` **is** `binary` and the second member is not in
it. The repair is offered as a **fork** — delete the absorbed member, or narrow the one absorbing
it — because the compiler knows the type and cannot know the intent. Someone writing
`binary | string` wanted either-or; the mechanical repair, `type Label = binary`, is the one thing
they almost certainly did not mean.

The failure channel keeps its own hint, because *"no caller can write the failure clause"* is a
sharper sentence than the general one and its repair is specific. It is the same rule and the same
error, reported with a hint that knows more.

The cost is deliberate and worth stating: `type Envelope = term | int` is refused, so a union that
is only ever passed through can no longer be written un-named. The repair is free, because the
normalised type *is* the repair and the compiler prints it.

### A union no clause head can take apart is refused

**Shipped.** A union earns its keep by being taken apart. If two of its members can be neither
**reached** by a pattern nor **separated** by a guard, the declaration is refused where it is
written:

<!-- diagnoses: indiscriminable_union -->
```csharp
module Slots

type Slot = map<string, int> | map<string, binary>

public int Go(int id)
Go(id) -> id
```

Both members survive normalisation, so the rule above does not fire: neither contains the other.
What is missing is a way to *reach* them. `map<K, V>` ships with no pattern form (§9), and `is_map`
cannot tell a `map<string, int>` from a `map<string, binary>`, so `Slot` can be declared, passed
and returned and never matched on.

**This refusal is temporary by construction, and says so.** It names the pattern grammar as its
reason, because the day a map pattern form ships, `Slot` becomes legal with no change to this rule.

The criterion is a **clause head**, not a BEAM guard, and the difference decides a real case.
`type Xs = list<int> | list<binary>` is **legal**. A guard-only criterion would refuse it, because
no BEAM guard reaches *inside* a list — `is_list` is true of both members. A **pattern** does reach
inside: `[x, ..rest]` binds the element, and here `is_integer` on that binding decides which member
the value came from. **Reaching is the criterion, and deciding is not**: the guard settles this
example, but the rule asks only that a pattern reach the member — see the container note below,
where reaching and deciding come apart. `atom | int` is legal for the other half of the criterion: neither member has a pattern
of its own, and `is_atom` tells them apart without one.

So the two halves are asked in order — *is there a pattern that reaches this member*, and failing
that, *is there a guard that separates it from the others* — and `Slot` above is the shape that
answers no to both. The question is asked of the type **after** normalisation, so
`type C = A | B` over two unions is judged on what `C` actually is, not on the two names written.

**The check does not recur into a container, and that is decided rather than pending.**
`list<map<string, int>> | list<map<string, binary>>` is **legal**, though it holds one level in
exactly the members `Slot` is refused for: the list spine is a pattern that *reaches* both members
without *separating* them, and the criterion asks only the first.

**That is decided, and decided toward accepting.** A union of that shape
names a real set of values — every one can be built, passed and returned — so the objection belongs
to the advice given when you try to dispatch on it, not to the declaration. The repair is to tag
the two members, which is what a discriminated union looks like when its members are not
self-discriminating. The compiler's job is to say so: it does not recommend a signature it would
refuse, and it does not validate a foreign term into a union whose members it cannot report having
told apart.

<!-- ticket 70, resolved 2026-09-09: the criterion stays reachability; the two owed diagnostics
     are the F25 corrected signature and ValidateAs<T>'s target. -->

### A deliberate crash is spelled `raise`

`raise` is a **keyword**, so it cannot also be a name: a parameter called `raise` is a syntax
error, exactly as one called `and` is. A crash could have been an ordinary function returning
`none` and needing no grammar at all; the keyword was chosen on read cost, because a function is
lexically identical to a call, keeps its signature in another file, and leaves no single token
that finds every crash site.

Its type is `none`, the bottom — a type no value inhabits and therefore a subtype of every other.
That is what lets a raising clause stand beside one that returns a value without widening the
declared return type: the crash contributes nothing to the type the clauses justify.

<!-- check:
type Fetched = int | (:error, atom)
-->
```csharp
public int Unwrap(Fetched r)
Unwrap((:error, e)) -> raise e
Unwrap(v)           -> v
```

`Unwrap` returns `int` and means it. The reason travels in the argument position rather than as an
effect on the signature, so there is **no checked-exception surface**: what a function raises is
data it was handed, and nothing in a caller's type has to account for it.

A function whose every path crashes **says so by being declared `none`**, because the bottom is
first-class rather than checker-internal. The reason it is writable is an asymmetry rather than a
use case: `none` already appears in compiler output — every exhaustive function's residual is it —
so a reader meets the name whether or not the language lets them write it, and `term`, the other
end of the same lattice, has always been writable.

```csharp
public none Reject(term reason)
Reject(reason) -> raise (:rejected, reason)
```

What that buys is a **named, greppable, type-checked crash site** obtained from the lattice rather
than from a propagating constraint: `raise` is the primitive, and this is the function. A body that
*returns a value* under a `none` return is refused, since no value inhabits the empty type — which
is the whole content of the declaration.

**`none` and `:nothing` are opposites, not synonyms.** `none` is a *type* no value inhabits, so
`-> none` means **does not return**. `:nothing` is a *value* meaning absence, the one `option<T>`
carries. A function returning `:nothing` returns normally and hands back a value; a function
returning `none` never hands anything back at all. They read as near-synonyms and nothing else in
the language is as easy to swap by accident.

**And `none` is not C#'s `void`** — the same warning, read from the other side. `void` says a
method **does** return and hands back nothing worth binding; `none` says it **does not return** at
all. C# needs `void` because a method can complete without producing a value. B# never needs it,
because on the BEAM every call that returns, returns something — so "no useful result" is spelled
`:nothing` or `:ok`, as a *value*. **`:nothing` is what `void` translates to here; `none` is not.**

C#'s own way of saying never-returns is the `[DoesNotReturn]` attribute — an annotation the flow
analysis reads, sitting beside a return type rather than being one. Here it *is* the return type,
and the checker uses it as one: a raising clause contributes nothing to the type its clauses
justify, which is why `Unwrap` above can declare `int` and mean it.

That is also why escalating from
the `result` channel to a crash is an ordinary clause and needs no `?` and no `unwrap` primitive —
a raised reason and a carried reason are the same kind of thing, and share their vocabulary with
`result`'s `E`.

**The exception class is the BEAM's `error`** — the one that kills processes and that
`function_clause` belongs to. It is not `throw`. The BEAM's `throw` is the *catchable* non-local
return, so spelling this `throw` as C# does would read as recoverable where the language means
fatal. `throw` and `exit` have no producing spelling at all: clause heads and the `result` channel
replace the first, and stopping yourself is a return value under §14's `(:stop, Reason, State)`.

Any term is a legal reason; an atom or a tagged tuple is the recommendation.

A guard is not a place a program may crash on purpose, and a guard shares the whole expression
grammar — so this parses and is refused:

<!-- diagnoses: raise_in_guard -->
```csharp
public int F(int x)
F(x) when raise :boom -> x
F(_)                  -> 0
```

— *`F` raises in a guard; a guard chooses which clause runs, it cannot crash. Move the raise into
the body of the clause it should fail.*

### What a wrapped foreign call fails with

`foreign_error` is the type the compiler-written wrapper produces. It is a **declared entry** the
compiler ships rather than something you write, and it stays in the planned-surface block for the
same reason `option` and `result` do — that namespace is lowercase and `type` declares a PascalCase
name:

```csharp not-yet
type foreign_error = (:error, term) | (:throw, term) | (:exit, term)
```

**The exception class is carried, not flattened**, and that is the whole reason the type has three
members instead of one payload. `{noproc, ...}` needs its `:exit` tag to read as *the callee is
dead* rather than as a value the callee returned, and those are different repairs. So recognising a
foreign failure is an ordinary clause head, exhaustive with no catch-all over the classes:

<!-- check:
type Parsed = result<int, foreign_error>
-->
```csharp
public atom Diagnose(Parsed p)

Diagnose((:error, (:error, _))) -> :not_a_number
Diagnose((:error, (:throw, _))) -> :library_signalled
Diagnose((:error, (:exit, _)))  -> :callee_is_down
Diagnose(n)                     -> :parsed
```

The doubled `:error` is not a slip: the outer one is `result<T, E>`'s own failure tag and the inner
one is the exception class.

**Naming `foreign_error` is what asks for the wrapper**, and it is the only payload that does. It
names an exception *class*, which no other type spells, so writing it says *this function throws and
I want the throw as a value*. Write a mapping clause if you want a domain reason.

**A payload that is not `foreign_error` is an ordinary union, not an error.** Most of OTP returns its
failures as values rather than throwing — `file:read_file/1` gives back `{ok, Binary} | {error,
Reason}` and never raises — so that shape is declared by writing it, and the compiler emits no
wrapper because there is nothing to catch:

<!-- check:
type Contents = (:ok, binary) | (:error, atom)
-->
```csharp
public atom Report(Contents c)

Report((:ok, _))    -> :read
Report((:error, e)) -> e
```

The two channels compose in one declaration when a function does both — an `(:error, foreign_error)`
member beside an `(:error, atom)` member gets the wrapper for the throw while the value arm stays an
ordinary value.

<!-- ticket 56, built as F23; it reversed F19 §2, and the measurement that decided it is
     in that ticket -->
**shipped** — and it reverses the *"`E` is fixed for a foreign declaration"* rule this
section used to state.

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

`|?>` is the **valve**: it stops on the first `(:error, _)` or `:nothing`, runs no further stage,
and returns that value unchanged.

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
handed. A `|?>` over a type carrying **neither** member is an error rather than a dead
branch — the compiler says to write `|>` instead.

The second member is why the operator exists at all. `:nothing` is absence, and a chain of lookups
that may find nothing is the shape the valve was borrowed for:

```csharp
module Absent

type Maybe = int | :nothing

public Maybe Load(int id)
Load(id) -> Fetch(id) |?> Double()

private Maybe Fetch(int id)
Fetch(0) -> :nothing
Fetch(n) -> n

private Maybe Double(int v)
Double(v) -> v * 2
```

`Load(4)` is `8` and `Load(0)` is `:nothing`, with `Double` never entered. `Double` is declared over
`int`: the stage sees the subject with **both** members subtracted, so absence never reaches it.

The set is fixed at those two and is not open to a type of your own. A short-circuit on any other
member would need the stage's declared parameter type to decide where the flow stops, and a
narrowing stage would then make an infallible subject appear fallible — so `binary |?> Decode()`,
where `Decode` takes a `string`, stays an error.

The escape hatch is the operator's **absence**. Write `|>` and match `(:error, _)` in your own
clause when a stage wants to inspect the failure; that is also the only way to turn one error into
another.

**The valve is how a request pipeline composes.** A chain of stages, each free to halt by producing
a finished response, is the shape every serious web framework on this platform is built from —
routing is one stage near the end rather than the whole program.

```csharp
module Web

record Request  { Path: atom, User: atom, Hits: int }
record Response { Code: int, Body: atom }

type Conn = Request | (:error, Response)

public (:error, Response) Handle(Request req)
Handle(req) -> Auth(req) |?> Quota() |?> Dispatch()

private Conn Auth(Request r)
Auth({ User: :anonymous }) -> (:error, Response{ Code = 401, Body = :unauthorized })
Auth(r)                    -> r

private Conn Quota(Request r)
Quota(r) when r.Hits > 100 -> (:error, Response{ Code = 429, Body = :too_many })
Quota(r)                   -> r

private (:error, Response) Dispatch(Request r)
Dispatch(r) when r.Path == :orders -> (:error, Response{ Code = 200, Body = :orders })
Dispatch(r)                        -> (:error, Response{ Code = 404, Body = :not_found })

public Response Serve(Request req)
Serve(req) -> Unwrap(Handle(req))

private Response Unwrap((:error, Response) halted)
Unwrap((:error, resp)) -> resp
```

**The terminal stage never passes through**, so it is declared `(:error, Response)` — a `200 OK`
from the router is also a halt. That is what makes `Handle`'s return type say the pipeline *always*
produces a response, and it is why `Unwrap` is **one clause** the compiler proves is enough. A
signature stating that a stage always halts is something neither of the neighbouring frameworks can
express, because in both a halted value and a live value have the same type.

The cost is the word. A router that cannot fail is declared `(:error, Response)`, and that atom
reaches the emitted `-spec` and the crash report. And a stage that has to run on *both* outcomes, a
logger being the obvious one, is **not a stage**: it takes `|>` and wraps the chain from outside,
because skipping the stage is precisely what the valve is for.
<!-- decided by ticket 31, measured against Plug and ASP.NET Core; the atom is ticket 49's question -->

Both operators are built, and so are the collection operations they are usually shown with.
*Corrected 2026-09-04: this paragraph said those operations were "**not** built", which was true
when written and stopped being true when the reserved qualifiers below shipped.* What remains unbuilt is
the function
*value* that `f` and `g` stand for below, which this language was measured not to have — so the
operations that take one wait with it:

```csharp not-yet
xs |> List.Map(f) |> List.Filter(g)
```

There is **no comprehension syntax**. The compiler inlines its own collection operations, which
recovers precise emitted types that a call to a generic function loses.

**decided**

### Reserved qualifiers — `List`, `Term` and `Map`

**A collection operation is a rule in the compiler, not a module that ships.** Every operation
under a reserved qualifier is **inlined at the site that uses it**, with that site's ground element
type. No `List.beam` is produced, a compiled program's only runtime dependency is the BEAM, and
**no `using` line is ever written** for one:

```csharp
module Totals

public int Total(list<int> xs)
Total(xs) -> List.Sum(xs)

public int Count(list<int> xs)
Count(xs) -> xs |> List.Length()

public list<int> Newest(list<int> xs)
Newest(xs) -> List.Reverse(xs)

public atom Before(int a, int b)
Before(a, b) -> Term.Compare(a, b)
```

`Term.Compare` returns `:lt | :eq | :gt` — the universal-order escape, and an ordinary union a
`switch` must cover. `List.Sum`, `List.Length` and `List.Reverse` are the operations the corpus
writes; which others exist is breadth, deliberately out of scope.

**Three names are reserved: `List`, `Map` and `Term`.** `Map`'s operations are not built yet, and
the name is taken anyway — reserving it later would mean taking it away from a program that had
already used it.

The reservation burns the **bare name only**. `module List` is refused; `module Shop.Collections.List`
is perfectly legal, and so is any other path with `List` as a segment. What is refused is the one
place the two could be confused — a call whose qualifier means both:

```csharp illustrative
using Shop.Collections      // this namespace holds a module called List

Counted(n) -> List.Length([n, n])   // error: `List` means two things here
```

The import itself is fine; only the call is refused, and the diagnostic names both claimants and
prints the module's full path as the fix. Nothing is burned and nothing is silent — the quiet
resolution other languages take here is exactly what is being refused. **shipped**
<!-- decided by ticket 67 (and 48 for `Map`); built by F32 -->

---

---

## 9. Generics

Real parametric polymorphism, in its smallest working form. **Two halves, and only the first is
built**, and the split is the generics design's own: *"the costs are asymmetric and they do not
chain."*

### Parametric types — shipped

Ground applications and parametric aliases. `list<T>`, `option<T>` and `result<T, E>` come from the
standard environment; your own take a parameter at the declaration and are PascalCase like any
other user type.

```csharp
type Pair<T> = (T, T)

public int Sum(Pair<int> p)
Sum((a, b)) -> a + b
```

**The variable is gone before the type algebra sees anything.** `Pair<int>` is the tuple, and
`option<int>` and a hand-written `int | :nothing` are not two types that agree — they are one type.
So a bracket costs no new node in the checker and nothing in the emitted code: what is published is
the expanded ground `-spec`.

A recursive type is **expanded, not refused**. Recursion is **equirecursive** — two spellings of the
same set are one type, with no conversion between them — and must be **contractive**. Subtyping over
one is decided coinductively, so a definition that unfolds an extra level is interchangeable with the
one it unfolds.

A definition whose recursion passes through a **constructor** — a tuple, a `list<T>`, or a record
field — describes a real set of values, and the checker sees through it well enough to prove a
two-clause function exhaustive **with no catch-all**:

```csharp
type Tree = :leaf | (:node, Tree, Tree)

public int Size(Tree t)
Size(:leaf)         -> 0
Size((:node, l, r)) -> 1 + Size(l) + Size(r)
```

**shipped** — `:leaf` and the node tuple partition `Tree`, so the pair is total and a `_` would be
refused as unreachable. Delete either clause and the residual names the shape that is missing rather
than unfolding forever. The emitted `-spec` is a recursive Erlang `-type`, not `any()`, and
`ValidateAs<Tree>` generates a validator that calls itself: handed `(:node, :leaf, 7)` it returns
`(:error, (["(3)"], "Tree"))` — the position inside the tree and the type expected there.

A definition whose recursion passes through nothing but unions and aliases describes no value at
all, and no amount of implementation will change that. A union is a **Boolean connective, not a
constructor**, so this stays an error now that the one above is not:

```csharp not-yet
type X = X | int
```

The compiler says which of the two it has found. That distinction is the whole reason it is written
down here: an author who wrote the first should wait for a feature, and an author who wrote the
second should rewrite their type, and one diagnostic cannot tell them apart.

### Dictionaries — `map<K, V>`

A record fixes its field names in the source. A `map<K, V>` does not: the keys arrive at runtime and
there can be unboundedly many, which is what a dictionary is. Both are maps on the runtime; they are
told apart by whether the set of keys is written down.

```csharp
type Assigns = map<atom, term>

public Assigns Passthrough(Assigns a)
Passthrough(a) -> a
```

**shipped** — the type can be declared, passed, stored in a record field and returned. It is
**covariant in its value**, so a `map<atom, int>` goes where a `map<atom, term>` is asked for and not
the other way round.

A record is **not** a `map<K, V>`. A declared record carries a minted `Kind` tag, and this type
excludes exactly that — so `Order` will not pass where `map<atom, term>` is expected, and a brace map
with no tag will.

**Matching one in a clause head is not built.** That is deliberate rather than pending: a pattern
over an unbounded key set cannot be proved exhaustive, because no finite set of clauses ever closes
the residual — and cross-clause exhaustiveness is the guarantee every other head in this language
keeps. So the compiler refuses the head and says which half it has:

```csharp not-yet
public term Read(map<atom, term> a)
Read({ Status: s }) -> s
```

Reading a value out therefore needs `Map.Get`, which is not built either — the qualifier `Map` is
reserved for it. Until it lands this type is for values that pass **through** a program: a foreign
struct handed to an Erlang or Elixir call, which today would be a `list<(atom, term)>` with no
checking at all. Coming **in**, it is checked: a map from outside crosses as `map<term, term>`
and `ValidateAs<map<K, V>>` walks its entries (§4, §10) — **shipped**, F43.

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
`"(2)"` for a tuple component, `"[\"views\"]"` or `"[:views]"` or `"[7]"` for a map entry, by its
key. An empty path means the term itself was wrong. A map entry whose key has no literal — a
tuple, a binary that is not text — is not named: the blame stops at the map.

The bracket is admitted after **exactly three** compiler-known names — `ValidateAs<T>`,
`ParseAtom<T>` and `ToExistingAtom` — and after nothing else, which is what keeps `<` a comparison
everywhere in the language. Two of the three are built; `ToExistingAtom` is refused by name.
<!-- decided by tickets 11 §2, 15 §2, 27 §8 and 28; built as F18 and F39 -->

### `ParseAtom<T>` — a string to a member of a named set

The second obligation reads a **finite atom union** and generates a match from each member's
printed name to that member. A string naming no member is `:nothing`, so the result is
`T | :nothing`:

```csharp
type Outcome = :ok | :error
type Parsed = :ok | :error | :nothing

public Parsed Parse(string s)

Parse(s) -> ParseAtom<Outcome>(s)
```

**shipped** — `Parse("ok")` is `:ok`, `Parse("nope")` is `:nothing`.

**It never touches the atom table**, which is the whole reason it exists rather than a
general string-to-atom function. The generated match returns compile-time-known literals:

```erlang
case S of
    <<"ok">>    -> ok;
    <<"error">> -> error;
    _           -> nothing
end
```

So a runtime-built string cannot grow the atom table through this path, and — the second
effect, and the one the ticket did not anticipate — `T`'s members are forced into value
position, which interns them by construction. A union whose members appear only in a type is
not otherwise guaranteed to be in the emitted module's atom chunk at all.

**A cofinite `T` is an error at the call**, and so is any `T` that is not exclusively atoms.
There is no finite member list to enumerate, so there is nothing to generate — the refusal is
about generation rather than about taste. `ParseAtom<atom>(s)` and `ParseAtom<:a | int>(s)` are
both refused; the second is the one worth stating, since its atom part *is* finite and only the
whole type tells you the parse could never produce the `int` half.

`ToExistingAtom` is the remaining name, and it is **owed rather than merely unbuilt**: it asks
the atom table by construction, so it returns bare `atom` and cannot make the promise above.
<!-- decided by ticket 10 §4; built as F39 -->

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
    int sum(list<int> xs)
}

using :ets {
    list<term> lookup(atom tab, term key)
}

using :erlang {
    int system_time(atom unit)
}

public int Total(list<int> xs)

Total(xs) -> :lists.sum(xs)
```

**shipped** — `bsc examples/Interop/interop.bs Total "[1, 2, 3, 4]"` prints `10`.
<!-- until F40 this block declared `list<int> reverse(list<int> xs)`, which the rule three bullets
     down refuses, and which `List.Reverse` does natively anyway (ENG-351 grill, Q6) -->

The declaration **attaches types to the name Erlang already has**. It does not introduce a B# name,
which is why the language needs no snake_case ⇄ PascalCase mapping anywhere — and why the parts of
OTP no mapping could reach (`'PKCS-1'`, `'OTP-PKIX'`) cost nothing.

Three dot-forms coexist, told apart by the **token class** of the left side rather than by any
casing convention:

| Form | Left side | Means |
|---|---|---|
| `o.Status` | a variable | field projection |
| `List.Map(x)` | a reserved qualifier, or a B# module | qualified call |
| `:ets.lookup(x)` | an atom | foreign call |
<!-- ticket 67: `Map`, `List` and `Term` are reserved qualifiers whose operations are compiler-known and
     inlined; a user's own module reads the same way and is called. This row said "a B# module" alone
     until 2026-09-03, while §5 above said compiler-known — the ticket was that contradiction. -->

- **Exactly one arity per declaration.** Foreign arity families are not defaults — `inet_udp:send/2`
  and `/4` exist with no `/3`.
- **Elixir is the same construct**, `using :"Elixir.Enum"`. Its *macros* are unreachable: they are
  exported as `MACRO-`-prefixed functions and are not callable from another language, so
  `use GenServer` cannot cross. **decided** — quoted atoms are not lexed yet.
- A foreign declaration may promise only what one BEAM guard decides in O(1). `list<Order>` is an
  error at the declaration; it crosses as `list<term>` plus `ValidateAs<T>`. **shipped** — F40,
  below.

### A foreign return may promise only what one guard decides

A **parameter** may be as narrow as you like: the value handed out is already established by the
signature that produced it. A **return** arrives from code this compiler never checked, and the
declared type is a claim about it. The claim may be anything one BEAM guard decides in O(1) — an
`int`, an `atom`, a `binary`, a tuple of those, a union of those, `list<term>`, `map<term, term>`,
an inline map type `{ Method: binary, Path: binary }` (one `map_get` test per field) — and nothing
a walk would be needed for: a `list<T>` or `map<K, V>` narrower than `term`, a `string`, a
recursive type, or a named record, whose `Kind` is a key this compiler mints and Erlang never
writes. The rule's own example, a table of orders:
<!-- ticket 18 §2's, verbatim but for the syntax it was written in -->

<!-- diagnoses: foreign_ret_beyond_one_guard -->
```csharp
module Orders

record Order { Id: int, Total: int }

using :ets {
    list<Order> lookup(atom tab, term key)
}

public list<Order> Find(int id)

Find(id) -> :ets.lookup(:orders, id)
```

— *`:ets.lookup` returns `list<Order>`, which one guard cannot decide; every element of this list
would need inspecting. Declare it `list<term>`, then `ValidateAs<list<Order>>` where it is used.*
The crossing is one visible line, and its type forces the failure arm:

```csharp
module Orders

record Order { Id: int, Total: int }

using :ets {
    list<term> lookup(atom tab, term key)
}

public result<list<Order>, ValidationError> Find(int id)

Find(id) -> ValidateAs<list<Order>>(:ets.lookup(:orders, id))
```

The validator wants the `Kind` a B# record carries, so this is the route for a table B# filled
itself. A row a foreign producer wrote is declared by its fields — `{ Id: int, Total: int }` is
admissible as a return, and its guard is `is_map` plus one value test per field — and that is also
what the refusal of a named record recommends. **shipped** — F40, ENG-354. One diagnostic covers
the rule; the edit line varies by what was found. What the guard itself checks at run time is §10's,
and it is emitted — **shipped**, F42, below.

### Declaring the failure channel is what emits the wrapper

A foreign call throws in **your** process — `binary_to_integer` on anything that is not a number is
the canonical case — and that is the one failure `monitor` plus `receive` cannot reach, because
there is no second process to observe it across. Declare the return type as
`result<T, foreign_error>` and the compiler wraps the call; declare anything else and it does not.
That second half is what makes a value-returned error declarable (§7).
<!-- the second half is ticket 56 / F23; before it, anything else was refused -->

```csharp
using :erlang {
    result<int, foreign_error> binary_to_integer(binary b)
    int byte_size(binary b)
}

public result<int, foreign_error> Parse(binary b)

Parse(b) -> :erlang.binary_to_integer(b)

public int Size(binary b)

Size(b) -> :erlang.byte_size(b)
```

**shipped** — `bsc examples/Foreign Parse '<<"abc">>'` prints `(:error, (:error, :badarg))`, and
`bsc examples/Foreign Size ':nope'` dies with `error:badarg`.

**The asymmetry is the decision, not an omission.** `Parse` declared a channel, so its failure is a
value. `Size` declared none, so the throw propagates and the caller dies for its supervisor to
restart. Which one you chose is readable in the type, and there is no third option: **there is no
`try` in the surface**, and the wrapper is the only one this language has.

All three exception classes are caught — `error`, `throw` and a locally raised `exit`. An exit
*signal* from another process is a different mechanism sharing a keyword and is not catchable at
all, so no supervision decision can be swallowed by a wrapper.

### The value coming back is checked against the type you declared

A foreign declaration may promise only what one guard decides, and the compiler emits that guard
at every call whose declaration names no failure channel. The type *is* the guard: `int` is
`is_integer`, `:up | :down` is one equality per member, `(:ok, int)` is the arity and one test per
component, and a fixed field set `{ Method: binary, Path: binary }` is `is_map` plus one value test
per field and **no** size test — extra keys pass, which is what a request map from another library
carries. A value the guard refuses crashes the way an unmatched `switch` does, with the BEAM's own
`case_clause` and the value in it:

```csharp
module Guard

using :erlang {
    int float(int x)
}

public int Widen(int x)

Widen(x) -> :erlang.float(x)
```

**shipped** — F42. `bsc Guard.bs Widen 3` prints `crashed: case_clause 3.0` and exits 1. Until
2026-09-11 it printed `3.0`: a float from a function declared `int`, the outcome §10's guarantee
exists to rule out, at every foreign declaration. A `term` return gets no guard at all, since nothing
it says can be false.

**Owed:** the guard on a call whose declaration names the channel. Declaring
`result<binary, foreign_error>` over `file:read_file/1` compiles and runs, and hands back
`(:ok, <<...>>)` — a value inhabiting neither arm of the type its author declared — because the
wrapper catches a throw that never comes and nothing inspects the value that does. A wrong channel
is a wrong declaration like any other. What the guard does on that call is an open question:
`foreign_error` is three exception classes, and a wrong-typed value is not an exception, so whether
the refusal crashes or arrives through the channel is not yet decided, and the guard is built once
it is.
<!-- the open question is ticket 74, wayfinder/issues/74-a-failed-guard-under-a-declared-channel.md -->
<!-- the unchannelled guard is F42, ENG-357 -->

## 12. Being called from Erlang and Elixir

Section 11 is one direction. This is the other, and **the two are not symmetric: calling *into*
beam-sharp needs no declaration at all.** Erlang and Elixir are dynamic and a beam-sharp module is
an ordinary `.beam`, so there is nothing on their side to declare. The whole FFI burden sits on the
typed side.

What a caller does need is the contract below. Parts of it are load-bearing, and none of it is
guessable from the source.

### The module atom is the dotted path, with no prefix

`module Shop` emits the atom `'Shop'`; `module Shop.Reports` emits `'Shop.Reports'`. There is no
language-wide prefix. Elixir has `Elixir.` because it resolves bare capitalised aliases to atoms and
needs an encoding for that; beam-sharp has no such indirection, because the module declaration
already *is* the atom.

### Function names are exported PascalCase, exactly as written

This costs Erlang nothing and costs Elixir its call syntax:

```erlang
'Shop':'New'(1).                  %% fine — Erlang quotes atoms freely
```

```elixir
:Shop.New(1)               # SyntaxError: Elixir reads .Capitalized as an alias
apply(:Shop, :New, [1])    # the way in
```

No module naming scheme changes this — the blocker is the *function* name, and prefixing the module
does not reach it.

<!-- ticket 62 holds the open decision on the casing; ENG-252 -->

### What each type erases to

Read off the `-spec` the compiler emits for every function whose type is known:

| beam-sharp | Erlang |
|---|---|
| `int` | `integer()` |
| `binary`, `string` | `binary()` |
| `bool` | `false \| true` |
| `atom` | `atom()` |
| `list<T>` | `[T]` |
| `(A, B)` | `{A, B}` |
| `option<T>` | `T \| nothing` |
| `result<T, E>` | `T \| {error, E}` |
| a record | a map carrying `'Kind'` — see below |

**Two of those will surprise a BEAM caller, and both follow from the standard environment rather
than from codegen:**

- **`result<T, E>` success is the bare value.** There is no `{ok, _}` wrapper, because the type is
  `T | (:error, E)` — the tag is a consequence of carrying a reason, so only the failure arm has
  one. A caller writing `{ok, V}` will not match.
- **`option<T>` absence is the atom `nothing`.** Not `nil`, not `undefined`, and not `{error, _}`.

### The `Kind` contract

A record erases to a map carrying **exactly one key beyond its declared fields**:

- the key is the atom `'Kind'`;
- the value is the atom `'<module>.<TypeName>'` — the module's full dotted path, then the record's
  own name.

```csharp
record Point { X: int, Y: int }
```

Declared in `module Abi`, that is emitted as, and accepted as:

```erlang
#{'Kind' := 'Abi.Point', 'X' := integer(), 'Y' := integer()}
```

and in a module `Deep.Inner` a record `Thing` mints `'Deep.Inner.Thing'` — the path is the whole
path, not the last segment.

**A caller constructing a value to hand to beam-sharp must supply `Kind`, and must spell it
exactly.** It is matched, not ignored:

```elixir
apply(:Shop, :Which, [%{Kind: :"Shop.Order", Id: 9, Total: 5}])   # => :order
apply(:Shop, :Which, [%{Kind: :"MyApp.Order", Id: 9, Total: 5}])  # => FunctionClauseError
apply(:Shop, :Which, [%MyApp.Order{Id: 9, Total: 5}])             # => FunctionClauseError
```

The third line is the one worth dwelling on: an Elixir **struct** with the right fields is still
refused, because it carries `__struct__` and not `'Kind'`. The two tag conventions do not know about
each other, and neither is wrong — they simply do not meet.

**Note the asymmetry, because it is the reason this section exists.** Inside beam-sharp, `Kind` is
the one key a construction may **not** name (section 6) — minting it is what makes aggregate
identity the compiler's to guarantee rather than the author's to maintain. Outside beam-sharp, every
caller **must** name it. The tag is private and public at once, so it is part of the published
interface whether or not anyone intended that.

### Reading the contract for a module you did not write

Two spellings of the same answer:

```
bsc --api Abi          # in beam-sharp's types, tags included
```

```
{ Kind: :'Abi.Point', X: int, Y: int } MakePoint(int)
:nothing | int MaybeInt(:false | :true)
int | (:error, atom) Res(:false | :true)
```

and the emitted `-spec` in the `.beam`, which says the same thing in Erlang's types and is what
Dialyzer will read.

**shipped** — the emission is what the compiler has always done. Writing it down as an *interface*
is new, and what remains open is the function-name casing, not the tag.

---

## 13. Processes

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

## 14. Refinements

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

## 15. What is deliberately absent

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

## 16. How it compiles

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

## 17. Using the compiler

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

## 18. What is actually built

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
| the boundary guard on an exported **refined `int`** parameter — the kind test and the range bounds the clause has not already proved | **shipped** — F24, F37 |
| exact field sets at a construction site | **shipped** |
| call arguments, projections and clause returns checked in a body | **shipped** |
| refinements + interval patterns | **shipped** — F2 |
| `switch`, including a tuple subject and a guard on an arm | **shipped** |
| `string` and `binary` as values — the literal, the refinement, the boundary rule | **shipped** — F9 |
| binary patterns `<<...>>`, string literals in pattern position, hex literals | **shipped** — F13 |
| a spelling for a **sized binary type** | not coming — a width refines the value it binds, so no type form arises |
| the UTF-8 entry check (`binary` → `string`) | not started — the sixth codegen obligation |
| pipe and valve | **shipped** — F14 |
| parametric types — `result<T, E>`, `option<T>`, `type Pair<T>`, nesting | **shipped** |
| polymorphic function signatures (`Map<T, U>`) | not started — needs an arrow type |
| modules, imports, `using` — both tiers, and arity overloading | **shipped** — F11 |
| a module is a **directory**, `index.bs`, and the two path checks | **shipped** — F15 |
| `public` / `private` on every signature | **shipped** — F12 |
| `ValidateAs<T>` — the generated deep validator, and its pathed error | **shipped** — F18 |
| foreign calls (`using :lists {...}`) | **shipped**, with the boundary guard on every return that declares no channel — F42; a channelled return is not guarded yet, pending a decision |
| the foreign `try` wrapper and `foreign_error`, from the declared return type | **shipped** — F19 |
| the diagnostic as a term (`--diagnostics term`) | **shipped** — F16 |
| the query mode (`--api`) | **shipped** — F17 |
| reserved qualifiers — `List.Sum` / `Length` / `Reverse` and `Term.Compare`, inlined at the site | **shipped** — F32 |
| `Map.Get` and the `map<K, V>` type, under the reserved `Map` | not started — the name is reserved, the operations are not |
| `behaviour GenServer` — the attribute, callback names, and mandatory-callback presence | **shipped** — F10 |
| behaviour contract checked as a **type** | not started — Dialyzer does it at the boundary today |

### Known inconsistencies

- ~~**Bare clause heads.** The exemplars elide the function name (`(body) -> ...`); the compiler
  requires it (`CreateOrder(body) -> ...`). One of the two is wrong and it has not been settled.~~
  **CLOSED — there was never a fork, and this bullet had it backwards.** A clause repeats its
  function name; the compiler, the decision and its own worked example always agreed. What was
  true was that the extracted exemplar files had been written in an older dialect that dropped
  the name, and the 2026-08-15 rewrite fixed them. Measured across the exemplars on 2026-08-26:
  **0 nameless clause heads, 76 named.** The exemplar write-up recorded this closed on
  2026-08-18 and this bullet went on asserting the opposite for eight days — a clean-room
  implementer following it would have built the wrong parser.
  <!-- corrected 2026-08-26 by ENG-245; the exemplar side was fixed 2026-08-18 and this side was missed -->

- **Map literals.** `#{ error = "invalid" }` appears in an exemplar and is specified nowhere.
- **`float`** has no decided literal syntax, which matters because `1..5` only lexes as a range
  while the float rule demands digits either side of its dot.

---

## 19. Open questions

- The language's **name**. <!-- tracked by ENG-280 -->
- ~~**Module and namespace system**~~ — **built**. What remains open is only whether `using` gains
  an **alias** (`using Orders = Shop.Orders`). <!-- tracked by ENG-219 -->
- ~~**Stdlib shape**~~ — **decided and built**: the standard environment is the builtin type names,
  the declared aliases, the codegen obligations, and compiler-known operations inlined under the
  reserved qualifiers `Map`, `List` and `Term`; nothing unqualified is a function, and `raise` is a
  keyword. *Corrected 2026-09-04: this said "Unbuilt, and the build is its own issue" until that
  build shipped.* `Map`'s own operations remain unbuilt, and ~~`raise` is still owed~~ — **`raise`
  shipped 2026-09-05 (F34)**; ~~what the error model still owes is a **writable `none`**~~ —
  **the writable bottom shipped 2026-09-08 (ENG-328)**, so `none` can now be declared as a return
  and §7 demonstrates it. *Corrected 2026-09-05: this also said `map<K, V>` remains unbuilt, which
  had shipped the day before it was written.*
  <!-- tracked by ENG-281 --> <!-- built by F32, F33, F34 and F38; ENG-324 remains -->
- **`cond`**, or whatever serves a long ladder of unrelated conditions. <!-- tracked by ENG-282 -->
- **Laziness** and `stream<T>` — deferred, not refused. <!-- tracked by ENG-283 -->
- **Bootstrapping** — how much of B# is written in B#. The front end likely stays Erlang, as
  Elixir's did; the OTP layer is the valuable target. <!-- tracked by ENG-284 -->

---

*Rationale for every decision above, and the measurements behind them, are in `wayfinder/`. This
document is the language; that directory is why.*
