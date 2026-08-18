# F6 — Angle brackets and parametric types: the variable is gone before the algebra sees it

**Status**      **done 2026-08-14**
**Implements**  [ticket 27](../../wayfinder/issues/27-parametric-polymorphism.md) §(a) and §(b),
                [ticket 28](../../wayfinder/issues/28-generic-bracket-parsing.md) §3 and §4 —
                decides nothing
**Unblocks**    the **bracket** in all three exemplars — `result<T, E>`, `option<T>`, `list<Line>`;
                and [F3](F3-records.md)'s `option<T>` field, which
                [F5](F5-body-check-site.md) named as the reason it took the slot ahead of this one
**Depends on**  F1, F3, F5

## Why this one now

The ordering rule: angle brackets are the one remaining capability that appears in **all three**
exemplars, and `result<T, E>` is the return type of every function in 25c.

And a second reason F5 wrote down on its way past: `option<T>` is what a record field spells when a
value may be absent, so 26 §4's *"there are no absent fields"* is a rule the compiler cannot yet let
anyone obey. `Notes: option<int>` does not parse today — `bs_parser.yrl` says so in a comment that
still blames F4.

## What is being built, and what is deliberately not

Ticket 27's answer splits generics into three questions wearing one coat, and says in its own words
that **"the costs are asymmetric and they do not chain: declining (c) would have left (a) and (b)
untouched."** F6 takes the ticket's own cut.

| | | F6 |
|---|---|---|
| **(a)** | Parameterised type constructors — `list<int>`, `result<Delivery, ConsumeError>` | **built** |
| **(b)** | Parametric aliases — `type option<T> = T \| :nothing` | **built** |
| **(c)** | Polymorphic function signatures — `list<U> Map<T, U>(list<T>, fn(T) -> U)` | **not built** |

(a) and (b) are **substitution with ground arguments**. `result<int, atom>` substitutes into
`T | (:error, E)` and hands the algebra a union — 27 §(b)'s *"the variable is gone before the
algebra sees it"*, executable. No new algebra, no new node in `bs_types`.

(c) is **matching**, and it is a different capability with an undecided part. Three reasons it is
not here, in ascending order of how much they should have been obvious:

1. **`Map` cannot be written at all.** `ty()` has an atom part, an integer part, a tuple part, a
   list part and a map part — and no **arrow** part. The canonical example in both 27 §2 and
   `LANGUAGE.md` §9 needs `fn(T) -> U` in a signature and a lambda to pass to it, and the slice has
   neither. A feature whose headline example does not parse is not ready.
2. **No exemplar declares a polymorphic function.** Measured: every angle bracket in
   `examples/exemplars/` is a ground application or `ValidateAs<CreateOrder>`. Building (c) now
   would be inventing the demand.
3. **The matching rule for a variable inside a union is not decided anywhere.** Ticket 28 §1
   settles the *direction* — every type variable must appear in a parameter position, so
   instantiation is recoverable — and it does not give the algorithm. `int Unwrap<T>(option<T> o)`
   asks the checker to match `int | :nothing` against `T | :nothing`, which is a question about the
   algebra's subtraction, not about a bracket. **That is a ticket, not a feature**, and F3→33 is the
   precedent for raising one rather than deciding it in a feature file.

**So F6 discharges the type-position half of ticket 28 and none of the value-position half.** 28 §2's
rule — *`<` opens an instantiation bracket after a compiler-known codegen-obligation name, and is
comparison everywhere else* — is a lexer rule over a **closed set**, and with `ValidateAs`,
`ParseAtom` and `ToExistingAtom` all unbuilt that set is **empty**. So the rule is a no-op today and
F6 does not write it. What F6 does instead is **pin the half that is load-bearing right now**
(F6.9): `<` in value position is still comparison, measured against the real grammar rather than
28a's patched copy of it.

## The prelude, named rather than assumed

`option` and `result` are **lowercase**, which is the builtin namespace, and there is no import
system for a prelude file to arrive through. So F6 seeds them into the type environment as
compiler-held entries **spelled in the language's own alias mechanism** —
`type option<T> = T | :nothing` and `type result<T, E> = T | (:error, E)`, exactly as ticket 10 §5
and `LANGUAGE.md` §7 write them.

**This is an implementation of a decided prelude entry, not an answer to the map's prelude-stratum
fog.** The fog asks what distinguishes stratum 1 from stratum 2 and whether a user may add to
stratum 2; F6 adds nothing user-visible to either question — a user cannot declare a lowercase type
and could not before. A user's *own* parametric alias is PascalCase like every other user type:
`type Pair<T> = (T, T)`.

## The hazard that is not a rejection: a cyclic alias hangs

**Measured on master before a line was changed**: `type A = B` / `type B = A` does not error. It
**hangs** — `bsc` spins until it is killed, because `type_env/1` resolves `t_ref` by looking the
name up and resolving what it finds, and its own comment says *"this slice has no recursive aliases
yet, so a single non-recursive resolution pass is enough."*

That comment was true and F6 makes it false, because a parameter is what makes a recursive alias the
natural thing to write: `type Tree<T> = (T, list<Tree<T>>)` is the first thing anyone tries.

**A hang is invisible to a green suite**, which is F5.7's lesson in a second costume — a wrong build
that goes quiet rather than red. So the guard and its scenario are F6's, not a later feature's.

The guard **rejects**; it does not implement. Ticket 09 made recursion equirecursive and
contractive, and the algebra cannot hold a recursive type — the list part is a pair of flags and a
tuple is a finite product. So `Tree<T>` is refused by name and the refusal says which, rather than
the compiler pretending to have expanded it.

## Scenarios

Each runs through the harness the README describes: `bsc FILE.bs [FUNCTION] [ARG...]`.

### F6.1 — a two-argument bracket parses, resolves, and dispatches

```csharp
module Parcel
type Outcome = result<int, atom>

atom Report(Outcome o)
Report((:error, e)) -> e
Report(n)           -> :ok
```

Compiles and **runs**: `bsc parcel.bs Report 7` → `:ok`, and
`bsc parcel.bs Report '(:error, :timeout)'` → `:timeout`. Exhaustive, because `result<int, atom>` is
`int | (:error, atom)` and the two clauses cover it.

The control is deleting the **first** clause, not the second: the residual is then `Report(int)`,
which is the point — the bracket produces a type the existing residual printer already knows how to
talk about. **Deleting the second proves nothing, and finding that out cost a scenario.** A bare
variable covers the whole union, so `Report(n) -> :ok` alone is exhaustive over `result<int, atom>`
exactly as it is over anything else. A control has to be aimed at the clause that does not cover.

### F6.2 — `option<T>` is a record field, and 26 §4 becomes obeyable

```csharp
record Order { Id: int, Notes: option<int> }
```

The declaration parses and the field's type is `int | :nothing`. This is the sentence
`bs_parser.yrl` has been carrying as a comment — *"the kept form is `Notes: option<int>`, which
needs the angle brackets F4 has not landed"* — and F6 is what makes the diagnostic beside it stop
naming a spelling that cannot parse.

### F6.3 — `option<int>` and `int | :nothing` are the same type

F3.2's test, one level up. A function declared over `option<int>` accepts a value declared
`int | :nothing`, and the clause that covers one covers the other, because 27 §(b) means neither name
reaches the algebra. **This is the scenario that proves expansion rather than a second constructor**:
if `option<int>` were a node the algebra had to know about, these two would be different types and
the call site would reject.

### F6.4 — a user parametric alias, PascalCase

```csharp
type Pair<T> = (T, T)

int Sum(Pair<int> p)
Sum((a, b)) -> a + b
```

Runs. The variable is bound at the declaration, substituted at the use, and never seen by
`bs_types`.

### F6.5 — nesting, and the `>>` that is not a token yet

`list<list<int>>` parses. Ticket 28 §4 established this against a patched copy of the grammar and
**recorded it as owed when binaries land**, because ticket 20's `<<_:M, _:_*N>>` needs `>>` as a
delimiter and nested generics meet it at exactly those two characters. Pinned by a test **now**, so
that F8 trips an existing test instead of discovering the collision.

### F6.6 — the wrong number of arguments is a diagnostic, not a crash

`result<int>` → **error** naming `result` and saying it takes 2 arguments and got 1. `option<int, atom>`
likewise. Today's `resolve/2` has one arm for a bracket it does not know (`unknown_generic`) and
none for a bracket it knows at the wrong arity, so this is a new sibling of an existing message
rather than a new kind of complaint.

### F6.7 — an undeclared variable in an alias body is caught by name

```csharp
type Wrong<T> = (T, U)
```

→ **error**: `U` is not a declared parameter of `Wrong` and no type by that name exists. Falls out of
the existing `unknown_type` lookup and is asserted rather than assumed, because a type variable and a
user type are the **same token class** (`uident`, ticket 27 §4) and nothing but the parameter list
tells them apart.

### F6.8 — a cyclic alias is an error, and it is measured against a hang

`type A = B` / `type B = A` → **error** naming the cycle. So does `type Tree<T> = (T, list<Tree<T>>)`,
with a message that says the algebra cannot hold a recursive type rather than that the name is
unknown.

**The control is not a red test — it is a hang**, so the before/after is recorded in the build note
by timing rather than by a failure. Reverting the guard must make this scenario spin, not fail.

### F6.9 — `<` in value position is still comparison

```csharp
bool Both(int a, int b, int c, int d)
Both(a, b, c, d) -> a < b && c > d
```

Compiles and runs. F6 puts `<` and `>` around a comma-separated list in type position for the first
time, and this is the scenario that says the expression grammar did not learn it: ticket 28's
`F(a < b, c > d)` reads as **two comparisons**, and ticket 08's
`(x, y) when x < y && Total(x) > 0` still parses as a guard. Measured against the real grammar,
where 28a measured a patched copy.

**And the conflict count is not the check.** 28a's own header records that yecc resolves
shift/reduce conflicts **silently** through the precedence table — every one of its four variants
reported zero conflicts, including the variant that read the ambiguous case wrong. So F6 asserts the
parse, not the number.

### F6.10 — the emitted `-spec` is the expanded ground type

`option<int>` publishes `integer() | nothing`, not a parametric spec. Ticket 13 §6 obliges widening
to the nearest expressible supertype, and there is nothing to widen here — the expansion is already
ground, so the spec is exact. This is the scenario that shows (a) and (b) had **no codegen cost**,
which is also why 27 §6's finding (a polymorphic `-spec` is inert under Dialyzer) does not arrive
with them: F6 emits no polymorphic spec because it builds no polymorphic function.

### F6.11 — the corpus is unchanged

Every `.bs` in `examples/` compiles and runs, every compiled block in `LANGUAGE.md` still compiles,
and all 109 tests pass. **F6 edits `resolve/2`, which is the single funnel both the checker and the
emitter go through** — F5 exported it precisely so there would not be two — so this is a change to
shared machinery rather than an added site, and the gate runs **before** the first rejection test.

## Out of scope

- **Polymorphic function signatures** — 27 §(c), reasoned above. → a ticket, raised by this feature.
- **`map<K, V>`.** The algebra's map part is ticket 26's **field-keyed record members**
  (`#{atom() => ty()}`, closed or open). There is no dictionary part, so `map<string, Json>` has no
  representation and the bracket is not what is missing. New algebra, and 09 wrote `map<string, Json>`
  without one.
- **`string` and `binary`.** `builtin/1` knows `int`, `atom`, `term` and `bool`. So
  `Response Route(Method, list<string>, term)` still fails after F6 — on `unknown_builtin`, not on
  the bracket. **The "unblocks" line above is a bracket claim, not a compiles claim**, and the three
  exemplars still wait on binaries, `switch`, pipe, string and map literals, and imports.
- **`ValidateAs<T>`, `ParseAtom<T>`, `ToExistingAtom`.** Type-directed codegen (27 §8), not generics,
  and the reason 28's lexer rule has nothing to act on yet.
- **Recursive types.** F6 refuses them by name; ticket 09 decided them and the algebra cannot hold
  one. Implementing them is 09's equirecursive machinery arriving for real — the same thing F5's
  list-element note routes elsewhere.
- **Variance, bounds, row polymorphism.** Refused outright by 27 §3, §5 and §7. Nothing here
  reopens them.

## Done when

`result<T, E>`, `option<T>` and a user-declared `type Pair<T>` all parse, resolve and run; a record
carries an `option<int>` field; `list<list<int>>` parses; a bracket at the wrong arity and a cyclic
alias are both diagnostics rather than a crash or a hang; `a < b && c > d` still means what it meant.
`rebar3 eunit` is green, `bin/check-language.sh` is green, and every `.bs` in `examples/` still
compiles and runs.

---

## Built 2026-08-14

**All eleven scenarios pass.** 124 tests, up from 109. `LANGUAGE.md` went from 19 verified blocks to
21, and `examples/Parcel/parcel.bs` is new — `result<T, E>` and an `option<int>` record field, runnable:
`bsc examples/Parcel/parcel.bs Grade 1500` → `:heavy`.

### The corpus gate passed on the first run, and the reason is the finding

F5's gate caught a shipped example being rejected. F6's caught nothing, and that is not luck — but
the tempting explanation is wrong and worth correcting here rather than in a later feature file.
**F6 adds four rejection paths**: `cyclic_type`, `generic_arity`, `needs_type_args` and
`not_parametric`. So "it adds none" is false.

The true claim is narrower. §(a) and §(b) are **substitution**, and every expansion happens strictly
*before* the algebra — so **no existing program's type changed**. And all four new rejections are
unreachable from any program already in the corpus, because each targets source that previously
failed to parse or, in the cyclic case, did not terminate. *That* is why the gate was clean, and the
next feature should not read it as evidence the gate is cheap.

### Two mutations, and the first one has no red test to give

| Mutation | Result |
|---|---|
| `seen/2` returns `ok` | the cycle scenario **hangs**. Suite otherwise green |
| arguments resolved in the callee's chain (`[N \| Seen]`) | **1 test red** — `Pair<Pair<int>>` reads as a cycle |

**The first is measured with a clock, because it cannot be measured with a suite.** With the guard,
`type A = B` / `type B = A` errors in **0.093s**; without it, the same file produced no output at
all and had to be killed. A test that never returns is not a failing test — it is a hung CI job, so
the only honest control is the stopwatch and it is recorded here rather than as an assertion.

The second pins a comment that would otherwise be decoration: type arguments are resolved in the
**caller's** chain, because they are siblings of an application and not steps below it. Resolve them
one step down and `Pair<Pair<int>>` — a legal, non-recursive type — is refused as a cycle.

### What the build added that this file did not name

**A bare parametric name reaches the resolver down two different arms**, and only one was covered.
`Pair` written without its bracket is a `{t_ref, …}`; `option` written without its bracket is a
`{t_builtin, …}`, because a lowercase name lexes as a builtin. So the first draft answered

```
error: option is not a builtin type
  this slice has `int`, `atom`, `term`, `bool` and `list<T>`.
```

which is **false in the way that matters** — `option` is not an unknown type, it is a known one
missing an argument, and the message sends the author looking for a declaration to write. Found by
running it rather than by a test, and both arms are now asserted in one test for that reason.

### The scenario that proved nothing, and what it cost

F6.1's control was originally "delete clause 1 and it is inexhaustive". It is not: `Report(n)` is a
bare variable and covers the whole union, so the program compiles clean and the control was
asserting the checker still worked at all. **A control has to be aimed at the clause that does not
cover** — deleting the *other* one gives the residual `Report(int)`. The scenario text now says so,
because the mistake is easy and silent: a green control reads exactly like a passing one.

### The REPL was pointed at it, and for once there was no hole

F4 found a stale diagnostic at the `ibs` prompt and F5 found a destructuring bind that does not work
there. F6 is the third feature in a row to add surface syntax, so `ibs -S examples/Parcel/parcel.bs` was run
before this was written rather than after: `Grade(1500)` → `:heavy`, the `(:error, …)` arm, and a
record carrying an `option<int>` field all answer correctly. Nothing in the REPL knows what an alias
is — it loads compiled code — which is *why* it is clean, and one command is cheaper than the
assumption.

### A workflow trap worth one line

`rebar3 compile` does not rebuild the `bsc` escript. The first scenario appeared to fail on a syntax
error inside `result<int, atom>` with a grammar that was already correct — the binary was stale.
`rebar3 escriptize` after a grammar change, before believing any hand-run result.

### What it ships without, named rather than discovered

- **Polymorphic function signatures** — 27 §(c), → [ticket 37](../../wayfinder/issues/37-instantiation-by-matching.md),
  raised by this feature with the three measurements that decided the cut.
- **Field values are still unchecked**, and **F6 multiplied the sites**.
  [Ticket 36](../../wayfinder/issues/36-field-value-obligations.md) says in its Notes that it was
  *"worth answering before angle brackets, for the same reason 33 was: an `option<T>` field
  multiplies the assignments this question is about."* F6 went ahead of it anyway, on the ordering
  rule — 36 blocks no exemplar and the bracket blocks all three — so `Notes = :oops` on an
  `option<int>` field type-checks today. **Recorded as a cost taken deliberately**, not as an
  oversight, and 36's argument for going first is now stronger rather than weaker.
- **Recursive types are refused by name.** Ticket 09 decided them; the algebra cannot hold one.
  The refusal is an improvement on a hang and is not an implementation.
- **`>>` is pinned but not solved.** `list<list<int>>` parses and has a test. Ticket 28's owed item
  stands: when binaries land and `>>` becomes a delimiter, that test is what trips.
- **A type parameter shadows a type of the same name**, silently. `type Box<Order> = (Order, int)`
  binds `Order` as a variable inside the body even where a `record Order` is declared, and
  `type Pair<T, T>` is accepted with the last binding winning. Unreachable from anything in the
  corpus and stated rather than found: a parameter and a type name are the same token class, so
  telling them apart is a rule someone must choose, not a bug to fix.
- **`string`, `binary` and `map<K, V>`.** Measured, not assumed: `list<string>` fails with
  *"string is not a builtin type"*. So the exemplars gained a bracket and not a compile, and the
  exemplar README now says which.
