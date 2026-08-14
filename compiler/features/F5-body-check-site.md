# F5 — The body check site: a body is typed, and five places check

**Status**      **done 2026-08-14**
**Implements**  [ticket 33](../../wayfinder/issues/33-body-check-site.md) — decides nothing; 33
                carries the compiler delta stated against the shipped source
**Unblocks**    [F3](F3-records.md).3's call-site enforcement, F3.8's projection error, F3.10;
                [ticket 34](../../wayfinder/issues/34-local-bindings.md)'s deferred destructuring
                bind; and the check site [F2](F2-interval-refinements.md)'s opaque refinements
                need to exist at all
**Depends on**  F1, F3, F4

## Why this one now

Because three scenarios are already written down with their ids reserved and no place to run, and
because the language has **decided rules the compiler cannot enforce** — which is a different and
worse thing than an unbuilt feature. F3's own file says a build claiming them "has stopped
checking".

It takes the F5 slot ahead of angle brackets on the ordering rule's own terms: `option<T>` fields
multiply construction sites, and construction is the hole F3 shipped with. A body today can build
a map wearing an `Order` tag without `Order`'s fields, call `Update(Order o)` with an `Invoice`,
and return `:oops` from a function declared `int`. All three compile.

## What ticket 33 decided, in one paragraph

A body **is** typed. Synthesis is total over the twelve expression forms and there was never a
cheaper option — typing an arbitrary argument *is* typing an arbitrary expression, because the
argument position is not a smaller grammar. Checking is plain containment at **five sites, every
one of them a place a type was already declared**, and the residual survives at four of the five.
Nothing new in `bs_types`; nothing changes in the emitted code.

| # | Site | B# | Relation |
|---|---|---|---|
| 1 | Call argument | `Update(d)` | `type_of(d) ⊆ Order` |
| 2 | Construction | `Order{ Id = 1 }` | supplied field set **=** declared field set |
| 3 | Projection | `d.Total` | every member of `type_of(d)` carries `Total` |
| 4 | Clause return | `Order Update(...)` | `type_of(body) ⊆ Order` |
| 5 | Destructuring bind | `(a, b) = pair` | `type_of(pair) \ type_of(pattern)` is empty |

**There is no sixth site because there is no sixth place a type is written.** `e_op`, `e_tuple`,
`e_list` and `e_block` declare nothing, so they synthesise and never check.

## The two things this must not get backwards

Both are ticket 33 §5, and both are load-bearing rather than fussy.

**A body variable's type comes from the clause's refined domain, not from its pattern.**
`pattern_type({p_var, …})` is `term`, correct for a pattern and useless for a body: `term ⊄ Order`
would fail every call site in the corpus. The domain `walk/5` already computes and discards is the
value the body needs.

**The intersection uses `Possible`, never `Certain`.** An untranslatable guard makes `Certain`
`none`, and typing a running body's variable as a value that cannot exist does not produce false
errors — it silently produces **no** errors, because `none` is a subtype of everything. The trap is
a hole in the check, not a broken build, which is exactly the kind that ships. F5.7 pins it.

## The one thing ticket 33 did not find

**List-pattern variables have no path, and three functions in `examples/fib.bs` depend on one.**

```csharp
list<int> Reverse(list<int> xs, list<int> acc)
Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])
```

`binding/1` records `#{V => no_path}` for a list element, because `refine_at/3` cannot address one
and crediting a guard over it would be unsound. Read that back for the body and `rest : term`, so
`Reverse(rest, …)` fails site 1 — **a shipped example rejected by a checker that is working
correctly on wrong information**. This is precisely the README's hard-won rule arriving through the
back door: *a capability that closes a residual without supplying a way to name the cases makes
previously-valid programs invalid.*

The fix is to record real paths (`{elem}`, `{tail}`) and keep the **guard** side exactly as
conservative as it is today, by treating any path through a list step as unrefinable at the point
`refine_all/3` already treats `no_path` that way. Reading a component and refining one are
different capabilities over the same address, and the list part of the algebra supports the first
and not the second.

**Which is why the corpus gate comes first, not last.** F5 adds four new ways for a program to be
rejected. Every `.bs` file in `examples/`, every compiled block in `LANGUAGE.md` and all 79 tests
must survive it before a single rejection test is written, or a regression hides behind a green new
test.

## Scenarios

Each runs through the harness the README describes: `bsc FILE.bs [FUNCTION] [ARG...]`.

### F5.1 — a clause's body must produce the declared return type

```csharp
module M
int Answer(int n)
Answer(n) -> :oops
```

`bsc m.bs` → **error**, exit non-zero, naming `:oops` against the declared `int`. Site 4 is not in
ticket 33's table of what was waiting; it is forced by [ticket 18](../../wayfinder/issues/18-boundary-defence.md)'s
own criticism of Gleam. 13 emits a `-spec` for every function, and without this check beam-sharp
publishes the same unverified claim 18 measured Gleam publishing — from its own bodies rather than
from an FFI declaration.

### F5.2 — a call argument must be accepted by the callee — **discharges F3.3's call-site half**

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }

Order Update(Order o)
Update(o) -> o with { Total = 0 }

Order Wrong(Invoice i)
Wrong(i) -> Update(i)
```

`bsc shop.bs` → **error**, exit non-zero. This is how ticket 26 §1 phrases the requirement David
named, and the thing F3 could not deliver because there was no call site to reject it at.

### F5.3 — the call-site residual is the clause head the **caller** must write

F5.2's program read for its diagnostic rather than its exit code — the same split F1 makes between
rejecting an inexhaustive function and naming the case it missed.

Expect `Wrong({ Kind: :'Shop.Invoice' }) -> ...`, from the same printer that formats an
exhaustiveness residual. **It proposes an edit to the function being checked, never to the callee**,
which is [ticket 18](../../wayfinder/issues/18-boundary-defence.md) §4's function-local rule
showing up in a diagnostic: nothing here suggests you widen `Update`.

### F5.4 — construction supplies exactly the declared field set — **discharges F3.10**

```csharp
record Order { Id: int, Total: int }
Order Make(int n)
Make(n) -> Order{ Id = n }
```

`bsc` → **error** naming `Total` as missing; the mirror program supplying a field `Order` does not
declare errors naming it as extra.

**This is the one site where the residual is names rather than a type**, and saying so plainly is
better than pretending one operation covers five sites. `Order{Id} \ Order` is `{ Kind:
:'Shop.Order' }` — correct, and worthless, because two closed maps over different key sets are
simply disjoint and the algebra has no way to say *"this, but short a field"*. Containment still
**catches** it in both directions, so F5.4 closes on soundness either way; what needs `field_delta`
is the sentence, not the rejection.

### F5.5 — projection names the member that lacks the field — **discharges F3.8's deferred half**

```csharp
record Order { Id: int, Total: int }
record Note  { Id: int }
type Doc = Order | Note

int Amount(Doc d)
Amount(d) -> d.Total
```

`bsc` → **error** whose residual **is** `{ Kind: :'Shop.Note' }` — the member lacking the field,
which is the tag to discriminate on. F3.8 deferred exactly this sentence and it needs no new
machinery: `subtract(Doc, { Total: term })` already answers it.

### F5.6 — an earlier clause narrows a later body

```csharp
type Flag = :on | :off
atom Only(:on f)
Only(f) -> :ok

atom Run(Flag f)
Run(:off) -> :no
Run(f)    -> Only(f)
```

Compiles clean and runs. `f` in clause 2 is `Flag \ :off`, from the **residual** — clause 1 already
took `:off`. Delete clause 1 and the same body is an error, which is the control: the narrowing is
the residual's contribution and not the pattern's.

This is ticket 08's *narrowing is always written, never inferred* falling out with nothing written
— **the earlier clause head is the narrowing** — and it is why the body check is not a second pass
over the AST.

### F5.7 — an untranslatable guard leaves the body's domain intact

```csharp
atom Weird(int n)
Weird(n) -> :yes

atom Classify(int n)
Classify(n) when Weird(n) -> n.Total
```

`bsc` → **error**: `n` is an `int` and has no fields. Built against `Certain` this compiles clean,
because `Certain` is `none` and every check over `none` passes vacuously. The scenario asserts an
error that a wrong build **omits**, which is the only way to test this direction.

### F5.8 — a foreign callee is checked like any other

```csharp
using :lists { int sum(list<int> xs) }
int Bad(atom a)
Bad(a) -> :lists.sum(a)
```

`bsc` → **error**. [Ticket 32](../../wayfinder/issues/32-ffi-surface.md) made a foreign declaration
a signature attached to the name Erlang already has, so site 1 applies verbatim and this is not a
special case — the second question 32 dissolved before it was asked. The one real delta is that
`collect/1` **deliberately excludes** foreign declarations, which is right for clause checking and
wrong for a callee environment: the callee env is built from `{signature, …}` **and**
`{foreign, …}` both.

How far the declared return is trusted was decided by 18 §2 and is not re-opened here.

### F5.9 — a binding carries its synthesised type into the rest of the body

```csharp
int Squared(Order o)
Squared(o) ->
    t = o.Total
    t * t
```

Already in `examples/shop.bs` and already compiling; F5 must not break it, and `t : int` has to come
from somewhere it did not before. A binding declares no type, so it is **synthesis only** — there is
no sixth site here.

### F5.10 — a destructuring bind that cannot fail compiles; one that can is an error

```csharp
int First((int, int) pair)
First(pair) ->
    (a, b) = pair
    a
```

Runs. Against `(int, int) | atom` it is an **error** carrying the residual — provably irrefutable
⇔ `subtract(type_of(rhs), type_of(pattern))` is empty, which is the mechanism ticket 34 named and
routed to 33 rather than refusing.

**The grammar cost, measured rather than feared.** `binding -> pattern '=' expr` reports **12
reduce/reduce conflicts**: yecc has one token of lookahead and every pattern form shares its first
token with an expression form. Parsing the wider language and narrowing in the action is the
standard escape — it is what Erlang itself does, where `=` is an expression — and
`binding -> expr '=' expr` plus a precedence declaration for `=` reports **zero**. `x = 1` still
produces the `{bind, …}` node F4 shipped, so nothing downstream of the parser learns a new shape
for the case that already worked.

### F5.11 — `_` is a pattern, not a value

`(a, _) = pair` must work, so `_` becomes an expression form the parser accepts. `F(n) -> _` is
then syntactically legal and must be **rejected by `bsc`** — not by `erlc` against an emitted
`.abstr` the author did not write, which is F4.7's rule applied to a hole F5's own grammar opens.

### F5.12 — a call to a name nothing declares is caught by `bsc`

Same lookup as site 1, and the same reason as F5.11: without it the author meets
`function 'G'/1 undefined` against a file they did not write. Wrong arity likewise.

### F5.13 — the corpus is unchanged

Every `.bs` in `examples/` compiles clean, every compiled block in `LANGUAGE.md` still compiles,
and the emitted forms are the ones F1–F4 already pinned. **Ticket 33 §7: the body check adds no
emission and removes none.** It is the first checking capability in the language that is purely a
frontend concern, and that is worth a scenario because every previous one arrived as a codegen
obligation.

## Out of scope

- **Interval arithmetic on `e_op`.** `1 + 2` synthesises `int`, not `range(3,3)`. That is
  [F2](F2-interval-refinements.md)'s business and pulling it in here would be F2 leaking into a
  feature that does not wait on F2's two owed decisions.
- **Checking `e_op`'s operands.** `:a + 1` synthesises `int` and is not rejected. `e_op` declares
  no type, so it is not a site; the BEAM raises `badarith` and ticket 33 enumerated the sites
  rather than collecting plausible checks.
- **`with`'s assigned values.** `o with { Total = :oops }` is unchecked — `with` is
  width-preserving, so it synthesises the base's type unchanged (26 §2). This is ticket 33's answer
  and not an oversight; a check here would be a sixth site and needs the decision that admits it.
- **Refining a guard over a list element.** F5 gives list variables a readable path; the guard side
  stays exactly as conservative as it is today. Reading a component and refining one are different
  capabilities.
- **Map and record patterns on the left of `=`.** `{ Kind: :x } = d` does not parse: a bare `{…}`
  is not an expression, so the F5.10 escape does not reach it. A tuple, a literal, a list and `_`
  do.
- **The value assigned to a field, at either construction or `with`.**
  `Order{ Id = :oops, Total = 1 }` type-checks. Ticket 33's site 2 is the field **set**, and §4
  elaborates only the name delta — so checking the values is a rule the ticket did not decide, and
  a feature does not decide rules. → [ticket 36](../../wayfinder/issues/36-field-value-obligations.md).
- **Opaque refinements** (F2, tickets 20 §5 and 29). F5 builds the site their obligation hangs on;
  the obligation itself is F2's, and F2 is blocked on two decisions.

## Done when

`examples/` still compiles and runs, `LANGUAGE.md`'s blocks still compile, and the three scenarios
F3 deferred with their ids reserved are asserted by tests rather than reserved: a call site rejects
the wrong record, a projection names the member lacking the field, and a construction naming the
wrong field set is an error that says which field. A destructuring bind runs when it cannot fail
and is rejected with a residual when it can. `rebar3 eunit` is green, and every new diagnostic
hands back something to write.

---

## Built 2026-08-14

**All thirteen scenarios pass and the three F3 deferred with their ids reserved are now asserted by
tests.** 106 tests, up from 79. Every example still compiles and runs, and `LANGUAGE.md` went from
18 verified blocks to 19 — the extra one is the destructuring bind, which the reference had said
was *"not in the language"*.

### The corpus gate was the right first move, and it caught the thing the ticket missed

Run before any rejection test existed, exactly as planned. It failed on `examples/fib.bs` for the
reason §"The one thing ticket 33 did not find" predicted, and **the fix is measured rather than
argued**: reverting list paths to `no_path` and re-running turns **7 of 106 tests red**. Ticket 33
enumerated the sites correctly and could not have found this, because it is not about where a check
runs — it is about whether the checker can *address* the value it is checking.

### Two traps confirmed by mutation rather than by a passing test

A green suite proves nothing about a check that fails by going quiet, so both of ticket 33 §5's
warnings were tested by breaking the build on purpose:

| Mutation | Result |
|---|---|
| `Domain = intersect(Residual, Certain)` | **1 test red** — `Classify(n) when Weird(n) -> n.Total` compiles clean, because every containment over `none` passes |
| `binding/1` returns `no_path` again | **7 tests red** — the corpus, via `Reverse(rest, …)` |

The first is the one worth keeping: it is a hole that ships, not a build that breaks. The only way
to test it is to assert an error that a wrong build **omits**.

### What the build added that the ticket did not name

- **A cascade rule.** An expression that has already produced a diagnostic synthesises `none`, so
  every site above it passes vacuously. Without it, `Amount(d) -> d.Total` reported *both* the
  absent field and a return-type failure naming a type nobody wrote — one mistake, two errors, the
  second one nonsense.
- **`unknown_callee` and `arity_mismatch`.** Same lookup as site 1, and without them the author
  meets `function 'Nope'/1 undefined` against an emitted file — the exact complaint F4.7 exists to
  answer.
- **`wildcard_as_value`.** A hole F5's own grammar opened, closed in the same feature.

### The grammar cost, and what it bought

`binding -> pattern '=' expr`: **12 reduce/reduce conflicts**. `binding -> expr '=' expr` plus
`Nonassoc 50 '='`: **zero** — and `_` as an expression form adds none. Ticket 34's `{bind, …}` node
survives untouched for `x = e`, so the emitter, the scope pass and the REPL learned nothing new for
the case that already worked.

### What it ships without, named rather than discovered

- **Field values are unchecked**, at construction and at `with` alike — → ticket 36, above. This is
  F5's F3.10: a hole stated in the file rather than found by whoever builds next.
- **A guard over a list element still credits nothing**, so `Sign([x, ..r]) when x > 0` plus its
  complement reports inexhaustive. F5 gives the element a readable address and deliberately does not
  give it a refinable one: the list part is `{HasNil, elem()}`, one element type shared by every
  position, so narrowing `x` would narrow `r` too and credit coverage nobody proved. Making it
  refinable means turning the list part into a head/tail product — ticket 09's equirecursive
  machinery arriving for real, which is a decision and not a feature. Pinned by a test so that
  changing it is a choice.
- **`bin/spec-check.sh` is still red** on `counter.bs`'s undefined GenServer callbacks. Pre-existing,
  recorded by F3, untouched here and not F5's to close.
