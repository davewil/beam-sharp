# F3 — Records: a tagged map, `with`, and the dot

**Status**      not started
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

## Scenarios

### F3.1 — a record is declared and constructed, and the term is a tagged map

```csharp
module Shop;

record Order { Id: int, Total: int }

Order Draft();
Draft() -> Order { Id = 1, Total = 0 };
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
module Shop;

record Order { Id: int, Total: int }
type Spelled = { Kind: :'Shop.Order', Id: int, Total: int };

Order Pass(Spelled s);
Pass(s) -> s;
```

Expect: compiles, exit `0`. **This is §1's own stated test that the minting is not nominality** —
*"a hand-written `type` with the same tag **is** the same type, and passing one where a
`record`-declared `Order` is expected compiles."* Ticket 09's rule surviving verbatim on the
construct 09 was written about, checked by a compiler rather than asserted.

### F3.3 — two records over identical field sets are distinct

```csharp
record Order   { Id: int, Total: int }
record Invoice { Id: int, Total: int }

int Total(Order o);
Total(o) -> o.Total;
```

called with an `Invoice`. Expect: **error**, exit non-zero. This is the DDD requirement that forced
the tag — *"in DDD it is very important that `Order` and `Invoice` are not the same type"* — and
under ticket 09 as written, before the minting, this call compiled.

### F3.4 — a union of two records is exhaustive on the tag, and the residual names the missing one

```csharp
type Doc = Order | Invoice;

atom Which(Doc);
Which({ Kind: :'Shop.Order' })   -> :order;
```

Expect: **error**, exit non-zero, and the diagnostic synthesises the clause the author must write —
`Which({ Kind: :'Shop.Invoice' }) -> ...` — exactly as F1.2 does for atoms. Adding that clause
compiles clean. This is ticket 04's guarantee and ticket 23's synthesised head reaching the
construct ticket 26 §5 says four of six exemplars are built from.

### F3.5 — `with` is width-preserving, and the tag survives it

```csharp
Order Pay(Order o);
Pay(o) -> o with { Total = 500 };
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

Projecting a field only one member carries is an **error** naming the member that lacks it, and the
fix the diagnostic points at is discriminating on the tag first.

### F3.9 — an exported function taking a record emits the tag test and nothing more

Expect, read from the emitted abstract code at the same seam F1 reads clause counts from: the guard
on an exported record parameter contains **one `map_get` tag test** and **no exact-set test**.

This is §1's two-tier allocation derived from ticket 18 §1 rather than a new rule. The tag test is
unconditional because *"no body ever checks which record this claims to be"* — a body projects
fields, so it cannot object. The exact-set test is emitted **only where a codegen obligation
consumes the record** per 18 §1(c), and no codegen obligation exists yet, which is why its absence
here is the correct observation and not a gap. Cost, measured in 26a: **+14 bytes, flat in field
count**, against the +29 ticket 18 feared.

### F3.10 — construction supplies exactly the declared field set

A missing field and an extra field are both **errors** at the construction site, exit non-zero.
Exact field sets are what §4's argument rests on and what makes the discriminator one
`has_map_fields` rather than a disjunction.

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
a callable `.beam`; the emitted term is a map carrying a tag minted from the qualified name; a union
of two records is checked exhaustively and its residual synthesises the missing head; an exported
record parameter's guard is one `map_get` and no more; the emitted `-spec` is a precise map type and
survives `bin/spec-check.sh`'s deliberate corruption; `rebar3 eunit` is green with the new cases at
the same boundary the existing suite uses; and `examples/` has a third file that compiles and runs.
