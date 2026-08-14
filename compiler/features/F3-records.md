# F3 — Records: a tagged map, `with`, and the dot

**Status**      **done 2026-08-14** — see [Built](#built-2026-08-14) at the end for what
                landed, what was measured, and the three scenarios that stayed deferred
**Implements**  ticket 26 §§1–4, and 18 §1's guard rule applied to them — decides nothing
**Unblocks**    the record half of all three exemplars; a third `examples/*.bs`
**Depends on**  F1
**Linear**      [ENG-199](https://linear.app/davewil/issue/ENG-199/f3-feature-not-a-map-ticket-records-a-tagged-map-with-and-the-dot) — the spec in PRD form, and where status lives. **Not** a wayfinder ticket and not in the `NN → ENG-(166+NN)` mapping.

## Why this one now, and not F2

The features README's ordering rule is **build what unblocks the most exemplars first**, and
`examples/exemplars/README.md`'s table puts records at the top: they block all three, where interval
refinements block two. That alone would order F3 ahead of F2. What settles it is that **F2 says of
itself, in bold, that it must not be built yet** — the spelling of an interval pattern and the
summarised form of a wide residual are *"a decision, not a feature"*, and both are unanswered.

Ticket 26 closed on 2026-08-13 with four sections marked **SETTLED**, so the semantics here are
whole. Records were listed *"out"* in the skeleton's scope table only because 26 was open when that
slice was cut; that entry is **stale rather than open**, and this feature is the one that catches it
up.

### The one soft claim being overridden, stated as an assumption

The features README says F3 onward are unwritten *"deliberately… F2's outcome will change what F3
should say."* That is an expectation, not a measured coupling — there is no probe behind it of the
kind `25c_residual_probe.sh` is behind F2's own internal coupling. **Assumption: intervals and
records are independent.** The one place they could meet is the residual over a union of records,
which discriminates on an atom tag (§1) and never on an integer interval. If that proves wrong,
this file is what gets amended.

## The asymmetry that makes F3's open decisions non-blocking

Four things below are genuinely undecided, which invites the obvious objection: F2 was disqualified
for having two. The difference is **what an unanswered spelling can do to a program that already
compiles.**

- **F2's is a correctness blocker.** A refinement closes a residual that is open today, so wire
  dispatch loses its free catch-all and ticket 12 §2 makes that an error. Shipping half of F2 turns
  **currently-valid programs into rejected ones**.
- **F3's are ergonomic.** Records are entirely new surface. Nothing that parses today contains a
  record, so no spelling chosen later can invalidate anything written earlier. Each open item below
  has a working — if verbose — form available *now*, because ticket 26 §1 makes the desugaring
  **writable**: *"the compiler writes what a user could."*

So F3 is built against the settled desugaring, and every sugar is a front end over it.

### The four, with the default each is built against

1. **The declaration spelling** — `record X { ... }` versus a modifier on `type`. §1 marks this
   *owed* and hands the surface question to ticket 22; the semantics are settled. Built against
   §1's own provisional `record`.
2. **The record *pattern* spelling.** §1 gives construction (`Order { ... }`) and §2 update
   (`o with { ... }`), but no section states the pattern form. Ticket 01's property pattern
   (`{ Balance: 0 }`) already works in the parameter position and the tag is an ordinary field, so
   `{ Kind: :'Shop.Order', Status: :draft }` is writable today. Whether a sugar `Order { Status:
   :draft }` mirrors construction is a grammar-opinion question — **ticket 22, and worth raising.**
   Built against the bare property pattern.
3. **The tag field's name, and what happens when a user declares it.** §1's desugaring names it
   `Kind`. A record declaring its own `Kind` field would collide with the minted one. Built against:
   **`Kind`, and minting over a declared `Kind` field is an error at the declaration** — the same
   instinct as ticket 15's collapse rule, which also errors at the declaration rather than at a use.
4. **What a qualified name lowers to as an atom.** §1 makes it a hard requirement that the tag mint
   from the **qualified** name — otherwise `Shop.Orders.Order` and `Billing.Invoices.Order` both
   mint `:order` and two bounded contexts silently unify — while recording that the lowering itself
   belongs to the map's module-and-namespace fog. Imports and multi-file modules are out of scope
   here, so a compilation unit is one module and the qualified name is unambiguous. Built against
   the dotted spelling `:'Shop.Order'`, **confined to a single emission point** so the fog patch can
   change it without touching anything else.

## New compiler capability this feature requires

Two things `bsc` does not have. Both were **checked against the source rather than assumed**, and the
second changes what this feature is allowed to claim.

### 1. A fourth constructor in the algebra — the largest item here

> **CORRECTED 2026-08-14 while building: it is the FIFTH, not the fourth.** `bs_types` had
> gained a `lists` partition — and `nil/0, cons/1, list/1` alongside the exports listed
> below — after this file was written. Nothing in the reasoning changes, and the list part
> turned out to be the second-nearest prior art after tuples: it is where the honesty rule
> for an inexpressible subtraction is already written down. Recorded rather than silently
> fixed, because this file is read as canonical and a stale premise in it is exactly what
> the map has twice caught itself acting on.

`bs_types` holds a type as a disjunctive normal form **partitioned by constructor**, and the
partitions are `atoms`, `ints`, `tuples`. There is no map. Union, intersection and subtraction are
componentwise across those three, and the module exports exactly
`none/0, term/0, atom_lit/1, atom_top/0, int/0, range/2, tuple/1`.

**So records are new algebra, not new surface.** A record needs a fourth partition with exact union,
intersection and subtraction — exact in ticket 20's sense, since nothing in this module widens — and
a residual that ticket 23 can synthesise a clause head from. The field product decomposes the way
the tuple part already does, which is the nearest prior art in the module and should be read before
the map part is written.

The map anticipated this without connecting it to a feature. The benchmark note says the checker's
measured linearity is worth re-measuring *"when the algebra gains records and binaries, since both
widen the product decomposition."* **F3 is the event that note is waiting for**, so re-running
`bench/bs_bench.erl` at the advertised clause counts is part of this feature and not a follow-up.

### 2. There is no body checking — and it is why two scenarios below are deferred

`bs_check` never visits `e_call`. It gathers signatures, checks clause-head exhaustiveness against
the parameter product, and translates guards — the only expression forms it reads are `e_op`,
`e_var`, `e_int` and `e_atom`, and it reads them **inside guards only**. `bs_emit` lowers `e_call`
straight to an Erlang call with nothing checked in between. **A function body is emitted, not
typed.**

This is not a defect of this feature, and F3 should not fix it. It is **the same absence F2 already
ran into from the other side**: F2 bars opaque refinements from clause heads and foreign
declarations because they *"need a check site the surface does not yet have"*. Two features have now
independently hit one missing check site, which is worth a ticket rather than an ad-hoc pass bolted
onto whichever feature notices it second.

The consequence for F3 is precise, and it is the reason the scenarios below are shaped the way they
are: **every claim is routed through exhaustiveness**, which is the one place the checker decides
anything, and any error that would have to be raised *in a body* is deferred with its id reserved.

## Scenarios

### F3.1 — a record is declared and constructed, and the term is a tagged map

```csharp
module Shop

record Order { Id: int, Total: int }

Order Draft()
Draft() -> Order { Id = 1, Total = 0 }
```

Expect: compiles, exit `0`, and from Erlang

```erlang
'Shop':'Draft'()  %% => #{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 0}
```

The map erasure of §1, observable as a term. Note the separator: `=` in construction, `:` in the
declaration — §2's *"C#'s own split — colon for matching, equals for assigning"*, forced anyway by
the atom sigil, since `Status: :placed` puts two colons together.

### F3.2 — the hand-written `type` with the same tag is the same type

```csharp
module Shop

record Order { Id: int, Total: int }
type Spelled = { Kind: :'Shop.Order', Id: int, Total: int }
type Either  = Order | Spelled

atom Which(Either)
Which({ Kind: :'Shop.Order' }) -> :order
```

Expect: exhaustive, exit `0`, **from one clause**. This is §1's own stated test that the minting is
not nominality — *"a hand-written `type` with the same tag **is** the same type"* — and ticket 09's
rule surviving verbatim on the construct 09 was written about.

**Routed through exhaustiveness deliberately**, per §2 above. The obvious phrasing is a signature
taking `Spelled` and returning `Order`, but a body is emitted rather than typed, so that program
compiles whether or not the two are one type and the scenario would assert nothing. Here the
checker has to decide: if the minting created an *identity*, `Either` is a union of two things and
one clause leaves a residual.

### F3.3 — two records over identical field sets are two types

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }
type Doc = Order | Invoice

atom Which(Doc)
Which({ Kind: :'Shop.Order' }) -> :order
```

Expect: **error**, exit non-zero. Identical field sets, different tags, and the checker treats them
as two — which under ticket 09 before the minting it would not have, because `Doc` would be a union
of one thing and the single clause would be exhaustive. Paired with F3.2 this is the whole of the
tag's job: F3.2 shows the same tag unifies, F3.3 shows a different tag separates.

**What this scenario cannot do is reject `Update(Order o)` called with an `Invoice`**, which is how
ticket 26 §1 phrases the requirement David named. There is no call site to reject it at — see §2.
**F3 establishes aggregate identity in the algebra; enforcing it at a call site waits on the missing
check site.** That is a real reduction in what this feature delivers against the ticket, and it is
recorded here rather than discovered by whoever builds it.

### F3.4 — the residual over a record union synthesises the head you must write

F3.3's program, read for its **diagnostic** rather than its exit code — the same split F1 makes
between rejecting an inexhaustive function and naming the case it missed, which the existing suite
already carries as two separate tests.

Expect the message to synthesise `Which({ Kind: :'Shop.Invoice' }) -> ...`, and adding that clause
to compile clean. This is ticket 04's guarantee and ticket 23's synthesised head reaching the
construct ticket 26 §5 says four of six exemplars are built from — and it is the scenario that
proves the fourth algebra partition produces a residual a human can act on, not merely an empty-set
answer.

### F3.5 — `with` is width-preserving, and the tag survives it

```csharp
Order Pay(Order o)
Pay(o) -> o with { Total = 500 }
```

Expect: compiles, exit `0`; the result is `#{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 500}`.
The field set is unchanged and the tag is not re-minted — §2's *"it is syntax, and it is
width-preserving"*, which is the sentence that **pays ticket 27 §7's debt** rather than reopening
row polymorphism.

### F3.6 — spread is not in the language

`o with { ... }` compiles (F3.5); `{ ...o, Extra = true }` is a **parse error**, exit non-zero.

Worth a scenario rather than an omission, because §2 refuses spread on a specific ground —
*"its defining capability is the one thing the type system closed"*. A widened record carries a
minted `:'Shop.Order'` tag while not being an `Order`, and no signature can be written against it
without the row variable ticket 27 declined. The refusal is load-bearing, so it gets a test.

### F3.7 — the dot projects, and the disambiguation is lexical

```csharp
o.Total          // lowercase receiver  -> value projection
List.Map(f, xs)  // PascalCase receiver -> module qualification
```

Expect: `o.Total` compiles and emits one `map_get`. **The disambiguation happens before types
exist** — values are lowercase, modules and functions PascalCase — which is what keeps ticket 17's
refusal of `xs.Filter(f)` from reaching this. 17 declined *dot-chaining* because it needs
type-directed resolution against a candidate set; `o.Total` resolves against one declared field set
with nothing to dispatch on, and 17 handed it over explicitly.

A consequence to assert directly: **a record field `Total` and a module function `Total` coexist**,
distinguished by syntax rather than by resolution.

### F3.8 — union projection is legal where every member carries the field

`o.Total` over `Order | Invoice`, both of which declare `Total`, compiles and emits **one**
`map_get` regardless of which member arrived — §3, and the place *"§1's map erasure paid for this
without knowing it"*, since under the tuple erasure §1 rejected, the field sits at a different
offset per member and this needs real dispatch.

**Deferred, id reserved:** projecting a field only one member carries should be an error naming the
member that lacks it, with the fix being to discriminate on the tag first. The projection sits in a
body, so there is nowhere to raise it — §2. It lands with the check site, not here.

### F3.9 — an exported function taking a record emits the tag test and nothing more

Expect, read from the emitted abstract code at the same seam F1 reads clause counts from: the guard
on an exported record parameter contains **one `map_get` tag test** and **no exact-set test**.

This is §1's two-tier allocation derived from ticket 18 §1 rather than a new rule. The tag test is
unconditional because *"no body ever checks which record this claims to be"* — a body projects
fields, so it cannot object. The exact-set test is emitted **only where a codegen obligation
consumes the record** per 18 §1(c), and no codegen obligation exists yet, which is why its absence
here is the correct observation and not a gap. Cost, measured in 26a: **+14 bytes, flat in field
count**, against the +29 ticket 18 feared.

### F3.10 — construction supplies exactly the declared field set — **DEFERRED, id reserved**

A missing field and an extra field should both be **errors** at the construction site. Exact field
sets are what §4's argument rests on and what makes the discriminator one `has_map_fields` rather
than a disjunction, so this matters — but a construction expression sits in a body, and §2 says
there is no check site for it.

**The honest consequence: in F3, a record's field set is exact in the type algebra and unpoliced at
the construction site.** A body can build a map that wears an `Order` tag and does not have
`Order`'s fields, and nothing rejects it. That is the single largest hole this feature ships with,
and it closes with the check site rather than with more record surface.

### F3.11 — there is no `?` field modifier

```csharp
record Profile { Id: int, Notes?: int }
```

Expect: **error**, exit non-zero. §4: *"There are no absent fields."*

**Only half of §4 is observable in this feature.** The kept form is `Notes: option<int>`, and
`option<T>` is angle brackets — F4. So F3 asserts the refusal; the replacement it points at cannot
be written until F4 lands, and the diagnostic should say so rather than naming a spelling that does
not yet parse.

### F3.12 — the emitted `-spec` is a map type, and it is precise

`Draft/0` emits `#{'Kind' := 'Shop.Order', 'Id' := integer(), 'Total' := integer()}` rather than
`map()` or `any()`. Extends F1.4 and is checked the same way — by `bin/spec-check.sh`, which
corrupts a real emitted `.abstr` in exactly one respect and requires Dialyzer to catch it, because
a clean run proves nothing unless a wrong spec would fail it.

## Out of scope

- **The body check site itself** — §2. F3 needs it, F2 needs it, and neither should grow it as a
  side effect. **Raise it as a ticket**: whether a function body is typed at all, where the check
  runs, and what it does with a call whose callee is foreign. Until it exists, F3.3's call-site
  enforcement, F3.8's projection error and F3.10 are deferred with their ids reserved.
- **`option<T>` fields**, and therefore the affirmative half of §4 — angle brackets are F4.
  Ticket 27's parametric record types go with them.
- **The exact-set guard tier and the generated encoder.** §1 emits it only where a codegen
  obligation consumes the record, and ticket 16 §4's encoder does not exist. The null-versus-omit
  question §4 leaves owed is ticket 16's, not this feature's.
- **`switch` over records** (F5), **binaries** (F6), **pipe and valve** (F7), **interval
  refinements** (F2), **`string`, list and map literals** — the grammar's builtins are `int`,
  `atom` and `term`, and every scenario above is written inside that.
- **The bare-head clause form.** Every exemplar writes `((:ok, n)) when n > 0 -> …` under a
  signature, while the grammar has one clause production that repeats the function name. The
  exemplars README calls this out: *"the skeleton implements the form the map did not choose."*
  It is a real fork and → tickets 01, 08 — **not this feature**, and the reason F3 does not claim
  the exemplars compile.
- **Imports and multi-file modules**, which is what lets the qualified name be assumed unambiguous.
- **Record extensibility and row polymorphism** — closed rather than deferred by §5: with exact
  field sets, width-preserving update and no optional fields, *"a wider record is simply a different
  type."*

## What this does *not* unblock, stated plainly

**The exemplars still will not compile.** Ticket 26 §5 says ticket 25 is *"unblocked in practice"*
and that is true of the record constructs specifically — it is not a claim that `25a/`, `25b/` or
`25c/` parse. Each of them additionally needs angle brackets, `switch`, binaries, pipes, string and
map literals, imports and the bare-head form. F3's honest claim is that **the record half of all
three stops being the blocker**, and the observable proof of that is a new passing file in
`examples/`, not a green exemplar.

## Done when

A `.bs` file declaring, constructing, updating, projecting and dispatching over records compiles to
a callable `.beam`; the emitted term is a map carrying a tag minted from the qualified name; **the
algebra has a fourth constructor partition** whose union, intersection and subtraction are exact;
two records with one tag are one type and two records with two tags are two, both decided through
exhaustiveness; the residual over a record union synthesises the missing head; an exported record
parameter's guard is one `map_get` and no more; the emitted `-spec` is a precise map type and
survives `bin/spec-check.sh`'s deliberate corruption; **`bench/bs_bench.erl` has been re-run at the
advertised clause counts**, since this is the widening of the product decomposition the skeleton's
benchmark note said to re-measure at; `rebar3 eunit` is green with the new cases at the same
boundary the existing suite uses; and `examples/` has a third file that compiles and runs.

**Not in "done": F3.3's call-site enforcement, F3.8's projection error, and F3.10.** All three wait
on the check site, and a build that claims them without one has not found a way around §2 — it has
stopped checking.

---

## Built 2026-08-14

**All nine live scenarios pass and the three deferred ones stayed deferred.** 64 tests, up from
39, and `examples/shop.bs` compiles, runs, and exercises every construct from the CLI.

### The shape the algebra took

A record is **not a node in the algebra**. It desugars to the anonymous map type a user could
have written, which is what makes F3.2 a real test rather than a tautology. Members carry
`closed` (a declared type fixes its domain) or `open` (a property pattern constrains the fields
it names and no others) — a distinction the feature file did not anticipate and which turns out
to be the load-bearing one: **every subtraction the checker performs is closed-minus-open**, and
that is precisely what lets one clause cover a whole record by naming only its tag.

The asymmetry with tuples is worth keeping: two tuples of different arity are disjoint, full
stop; two maps of different field sets are disjoint only if **both** fix their domain.

### Three things found by building that reading would not have

**1. The residual's *type* and the head you *write* are different strings.** Printing the full
field set gives `Which({ Kind: :'Shop.Invoice', Id: int, Total: int })`, which is a correct
description and a broken clause head — pasted in, `int` is a lowercase name in pattern position,
so it binds a variable, twice. `to_pattern/1` now synthesises the **discriminator alone**, which
is exactly what this file's F3.4 specifies and what ticket 26 §1 put the tag in the term for.
The same rule made atoms quote (`:'Shop.Invoice'`, not `:Shop.Invoice`) in the residual, in the
runner's output, and in the runner's argument parser — a record's minted tag is the first atom
in the language the bare sigil cannot spell.

**2. Map-pattern bindings had to carry real field paths.** The obvious implementation is to treat
a field as unaddressable the way a list element is. That is not conservative in a harmless
direction: `refine_all/3` turns an unknown path into `none_marker`, so a clause with both a
record pattern **and** a guard credits *nothing*, and the function reports inexhaustive. Pinned
by `a_guard_over_a_record_field_still_credits_the_clause_test`.

**3. The benchmark had been broken on master since the terminator was dropped** — it generates
`;`, so it failed at the lexer, and the numbers in the map's skeleton entry were not
re-measurable. Fixed; the atom ladder reproduces them.

### The measurement this feature owed

The skeleton's benchmark note said to re-measure *"when the algebra gains records and binaries,
since both widen the product decomposition."* It widens, and the first run was bad:

| clauses | atoms | records, first run | records, after |
|---|---|---|---|
| 5 | 9.3 µs | 91 µs | 25.6 µs |
| 20 | 32.5 µs | 1.08 ms | 287 µs |
| 40 | 69.3 µs | 6.07 ms | 963 µs |
| 80 | 165 µs | 46.7 ms | 3.18 ms |

The first column is linear through the advertised shape. The second was **cubic** — the first
place in this compiler where ticket 04's "no complexity bound" is visible rather than argued.

The cause is absorption: it runs after every subtraction, is quadratic in the number of members,
and does a `subtract` per field inside. The fix is **ticket 09's discriminability rule turned
into an index** — absorption can only ever succeed between members that agree on their tag, since
containment requires the contained member's tag to subtract away against the container's and two
distinct singletons never do. Grouping by tag is 15× at 80 clauses and takes the growth back to
roughly quadratic. It changes which pairs are *considered*, never what containment means.

**Still an open worry, and it belongs to whoever lands F6.** Records at 40 clauses cost 14× what
atoms do. Binaries are the other widening the note names, and they will stack on this.

### What is NOT claimed

- **`bin/spec-check.sh` is red, and was red before this feature.** `counter.bs` declares
  `behaviour GenServer` without defining its callbacks, so Dialyzer reports three undefined
  callbacks and the gate fails. Verified by removing `shop.bs` and re-running: identical failure.
  Dialyzer emits **nothing** about `Shop`, so F3.12's emitted map specs are clean — but the
  *gate* cannot be claimed green and is not F3's to fix.
- **F3.3's call-site enforcement, F3.8's projection error, F3.10** — deferred as written, ids
  reserved, no test asserts them. → [ticket 33](../../wayfinder/issues/33-body-check-site.md).
  **All three closed on 2026-08-14 in [F5](F5-body-check-site.md)**, at sites 1, 3 and 2, and each
  is now asserted by a test. Two of the three needed no new machinery beyond a place to run:
  `subtract/2` and `to_pattern/1` already answered them, and the projection residual **is** the
  member lacking the field — the exact sentence F3.8 deferred. F3.10 needed the one thing the
  algebra could not say, a difference of field **names** rather than of values.
- **F3.9 is narrower than "an exported record parameter"** in two ways, both pinned by tests so
  that widening either is a decision rather than a surprise: no tag test on a **union** parameter
  (a disjunction over tags is a different shape), and none where the clause head already
  constrains `Kind` (the head performs the identical test).
