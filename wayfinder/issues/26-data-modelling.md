# 26 — Data modelling: records, and what named types erase to

Type: grilling
Status: resolved 2026-08-13
Blocked by: 09

## Question

Graduated from the map's **Not yet specified** on 2026-08-12, when
[ticket 09](09-union-representation.md) removed the entanglement that kept it fog. The fog
entry read *"records, structs, `with` expressions, and how they relate to Erlang maps and
tuples — entangled with the union-representation decision"*. That decision is made, and it
settles more of this than expected:

- Types are **structural and open**; there is no nominal construct in the language.
- **`type X = ...` is the single naming construct**, and a record type is one more thing that
  can appear on its right-hand side. There is no `record` keyword to design.
- Naming is **aliasing**, so a record type is its field set. Two records with the same fields
  are the same type, whatever they are called.
- **Members of a union must be discriminable by a synthesised BEAM guard**, checked at the
  declaration.

What is left is the part ticket 09 does not answer: **what does a record value actually erase
to on the BEAM, and what is the surface syntax for building and updating one?**

Decide:

- **The erasure.** A map (`#{x => 1, y => 2}`), a tagged tuple (`{point, 1, 2}`), or an Erlang
  record (which is a tagged tuple with compile-time field names)? Each has different costs:
  maps are self-describing and extensible but larger and slower to match; tuples are compact and
  fast but positional, so field order becomes part of the wire format.
  - **This interacts directly with the discriminability rule.** Two record types with the same
    field names but different value types must be distinguishable by a guard if they are ever to
    appear in the same union. Under a map erasure that needs value inspection; under a tagged
    tuple the tag settles it for free. Work an example before choosing.
  - It also interacts with **interop** (ticket 06): Elixir structs are maps with a `__struct__`
    key, and Erlang records are tuples. Whichever is chosen, say what an Elixir struct looks like
    coming in.
- **Construction and update syntax.** `with` is C#-only; a TypeScript reader reaches for spread
  (`{...o, balance: x}`). **This is the question parked in the map's Notes under the audience
  decision** — decide whether both spellings exist, or one wins. Ticket 05 found `with` becomes
  *more* central here than in C#, since there is no mutation at all.
- **Field access.** Dotted (`o.Balance`), pattern-only, or both? Ticket 01 settled that property
  patterns work in the parameter position, so destructuring is already available; this asks
  whether ordinary projection exists alongside it.
- **Optional and absent fields.** Does a record type say a field *may* be absent, and is an
  absent field distinguishable from one present with a nothing-ish value? The BEAM term model
  makes this concrete rather than philosophical — a missing map key and a key mapped to an atom
  are different terms.

## Scope boundary — what belongs to other tickets

- **Row polymorphism** (typing maps structurally *with extensibility*) is listed on
  [ticket 20](20-untheorised-term-shapes.md) as untheorised. This ticket should decide the
  concrete surface and erasure and hand the extensibility question there rather than absorbing
  it.
- **Whether a record can carry a refinement** — the newtype gap ticket 09 left open — is also
  ticket 20's. Note what this ticket would need from that answer rather than pre-empting it.
- **Generic syntax** for parametric record types is [ticket 11](11-type-system-shape.md)'s.

## Notes

HITL. The map's fog entry is retired by this ticket; do not re-add it. Consult
[ticket 05](05-csharp-functional-inventory.md) on `with` and on what was dropped from C#'s
record machinery (`init`/`readonly`, nullable reference types), and
[ticket 06](06-interop-surface.md) on the term-model traps — a binary *is* a bitstring, and map
key order is the opposite of term order for integers versus floats.

## Constraints from ticket 11 — resolved 2026-08-12

- **The top type is spelled `term`**, chosen over `unknown`/`object`/`any` as a deliberate
  override of the borrow heuristic. Any modelling syntax here must use that word.
- **Parametric aliases are NOT this ticket's to decide.** Ticket 11 spun the generics half out to
  [ticket 27](27-parametric-polymorphism.md), which owns whether `type option<T> = T | :nothing;`
  is even well-formed. Do not settle it here.
- **`with` versus spread is still this ticket's**, unchanged.

## Constraints from ticket 14 — resolved 2026-08-12

**The prelude has two strata, and this ticket's records-and-aliases story must accommodate the
second.** Ticket 14 §6 settled that the prelude is stratified in the manner of Elixir's
`Kernel.SpecialForms`:

- **Ordinary aliases** a user could have written — `type bool = true | false;`,
  `type option<T> = T | :nothing;`.
- **A compiler-known stratum** they could not: `ParseAtom<T>` and `ToExistingAtom` (ticket 10),
  `ValidateAs<T>` (ticket 11), and now OTP's system-message shapes (`Down`, `Exit`, `Timeout`).
  These are compiler-implemented and win resolution — verified locally on Elixir 1.19.5, where a
  module defining its own `receive/1` macro still gets the special form at the call site.

So "what a named type erases to" now has a second answer for the second stratum: a compiler-known
type is not merely an alias whose name vanishes, because the compiler draws inferences from it —
ticket 14 §6 makes calling `Monitor` with no `Down` handler in the compilation unit an error. That
is a name doing work, in a language where ticket 09 settled that names never enter the algebra.
**The reconciliation is that the inference is about the *call*, not the type**, but this ticket
should say so explicitly, because it looks like nominality and is not.

## Constraints from ticket 27 — resolved 2026-08-12

**Two things settled elsewhere that this ticket must not re-decide, and one it now owns more of.**

**Parametric aliases exist and are 27's, not yours.** 27 confirmed `type option<T> = T | :nothing;`
denotes a real type-level function, with variables **declared** and named by C#'s `T` convention
(`TSource`, `TKey`, `TValue`) — forced, because beam-sharp's builtins are lowercase, so
lowercase-implicit variables would be ambiguous where Gleam's are not. This ticket writes record
types against that spelling; it does not choose it.

**Row polymorphism is ruled out — and the reason lands squarely here.** 27 §7 declined row
variables, and the load-bearing argument is about *this ticket's* construct: **record update is
`with` / spread, which is syntax**, so it types structurally against a concrete record type with no
variable involved. That is
[`prototypes/27a`](../prototypes/27a_comprehension_vs_hof_typing.erl) generalised — measured on OTP
28.5, an analysis with *no* type variables preserves `[integer()] -> [binary()]` through a
comprehension while the same computation through an opaque fun argument collapses to `[any()]`.

**So this ticket now carries the weight of that argument.** If `with`/spread turns out *not* to be
the answer to record update — if it is dropped, or if the C#-`with`-versus-TS-spread question
resolves toward something that is not compiler-visible syntax — then 27 §7's justification for
declining row polymorphism weakens, and 27 must be told rather than left to rot. 27 recorded the
deferred-option requirements: a spelling distinct from `T`-style variables (row variables range
over field sets, not types), a rule for whether a row variable may appear in a clause head (§2
would answer no), and a resolution to the completeness gap the literature records ([86], *"an open
problem we are working on"*).

**What is not expressible, so this ticket should not design around it**: a shared function over
unrelated record types that happen to share a field. That is a capability constraint → ticket 16.

## Constraints from ticket 15 — resolved 2026-08-12

**Two, one of which narrows this ticket's construction-syntax question.**

- **`with` is spoken for.** Ticket 15 needed a sequencing construct for fallible steps and could not
  use Elixir's `with`, because this ticket owns `with` as record update and ticket 05 found it
  becomes *more* central here than in C#, there being no mutation at all. The sequencing spelling
  went to ticket 17 instead. **So this ticket's `with`-versus-spread question is now free of that
  collision** — but it should decide knowing that `with` has been reserved on its behalf, and that
  reserving it is what pushed a construct onto another ticket.
- **`ValidationError` is a record candidate.** Ticket 15 fixed `ValidateAs<T>`'s reason as a path
  into the offending term plus the type expected there, spelled as a tuple *because this ticket has
  not settled what a record is*. If a record form lands, this is the first compiler-generated value
  that would plausibly become one — and it is generated, not written, so it is also a test of
  whether the record surface is something codegen can emit cleanly.

## Constraint from ticket 17 — resolved 2026-08-13

**This ticket now owns the whole of the dot, and gains back one construct it was told it already
had.**

[Ticket 17](17-pipeline-and-comprehension.md) §1 refused dot-*chaining*: `xs.Filter(f)` requires
type-directed resolution of an unqualified name, which ticket 08 closed (one arrow per arity, no
overload set) and ticket 16 closed again (one dispatch mechanism, the clause head). The chaining
form is `|>` with qualified names.

**What that settles for this ticket, and what it does not.**

- **Settled: the dot is never a call.** Nothing is dispatched by writing one. This removes the
  ambiguity the field-access sub-question was carrying — whether `o.Total` and `o.Apply(e)` were the
  same mechanism. They are not, and only the first is still a candidate.
- **Still this ticket's: whether the dot projects at all.** `o.Total` as ordinary field access
  remains open exactly as before. Ticket 01 settled that property patterns work in the parameter
  position, so destructuring already exists; this ticket asks whether projection does too.
- **`with` is confirmed free.** 17 never needed it — the valve `|?>` handles fallible sequencing and
  requires no borrowed keyword — so the constraint 17 inherited from ticket 15 (*"`with` is
  unavailable, it is 26's record update"*) is discharged without cost. If this ticket wants `with`
  for record update, nothing now competes for it.

**One thing to weigh that 17 could not.** 17 §1's failure case for the dot was a *second collection
type*: with `list<T>` and a deferred `stream<T>`, `xs.Filter(f)` has no rule to break the tie. The
same argument does not obviously apply to projection — `o.Total` names a field, not a function, and
a record type's fields are known from its declaration. So the refusal of dot-call does **not** carry
over automatically, and this ticket should decide projection on its own merits rather than treat it
as already settled.

## Constraint from ticket 18 — resolved 2026-08-13

**The erasure choice now has a boundary cost, and it is measured.**

Ticket 18 §1 settled that the compiler emits a guard wherever an exported function's own body would
not object, and §1(c) makes that *unconditional* for any value feeding a codegen obligation — 16 §4's
generated encoder above all, which is a record encoder. **Guards test shape, and a record's shape on
the BEAM is this ticket's open question.**

- **Tagged tuple** — the discriminator is one tag test plus arity. 18 §2 notes this is the form that
  makes union discriminability free.
- **Map** — the discriminator needs key presence *and* value tests, since two record types with the
  same field names differ only in their values.

Measured, OTP 28.5 ([`prototypes/18a_guard_cost.md`](../prototypes/18a_guard_cost.md) §1): the tuple
discriminator `is_tuple(X), tuple_size(X) =:= 3, element(1,X) =:= order` costs **+13 bytes (+17.8%)
of the `Code` chunk** — the most expensive case in that measurement set, and it is the *cheap*
erasure. A map erasure's discriminator is strictly larger. Against that, the tuple case is the only
one in the set that *shrinks* the `.beam` file (−4 bytes), because the tag literal displaces
import-table entries.

**Ticket 18 does not settle erasure and explicitly declines to.** What it hands over is that the
choice is no longer only about matching speed and wire format: it also sets the size of every
emitted boundary guard on every exported function taking a record, which after §1(c) includes every
function whose value reaches a generated encoder.

One thing 18 *does* remove from this ticket's field of worry: 18 §4 makes the analysis
**function-local**, so the guard emitted for a record parameter depends only on that function, never
on what some other file in the aggregate does with the value.

---

# Answer — in progress, 2026-08-13

> Grilling session of 2026-08-13. Sub-questions are settled one at a time and recorded here as
> they land. Brief: [`beam-sharp-eng-192.html`](../beam-sharp-eng-192.html).
> Evidence: [`26a`](../prototypes/26a_record_erasure_cost.erl) (Erlang, erasure cost),
> [`26b`](../prototypes/26b_struct_field_set.exs) and
> [`26c`](../prototypes/26c_descr.exs) (Elixir, struct discipline and type representation).

## 1. The erasure is a MAP, and a record is sugar for a minted tag — SETTLED (David)

**A record erases to a map. `type X = { ... }` remains a structural alias exactly as ticket 09
says. A second declaration form — provisionally `record` — desugars to a `type` whose field set
carries a minted discriminating tag.**

```csharp
record Order { Id: string, Total: Money }

// desugars to, and is interchangeable with:
type Order = { Kind: :order, Id: string, Total: Money };
```

**Everything stays structural. `record` mints a discriminator; it does not create an identity.**
The name enters the *term*, as data, never the *type algebra*. The test that proves it is not
nominality: a hand-written `type` with the same tag **is** the same type, and passing one where a
`record`-declared `Order` is expected compiles. Ticket 09's rule survives verbatim on the
construct 09 was written about.

### Why a map and not a tuple

Two refusals, both ticket 09's, reached from opposite directions:

- **A bare tuple loses the field *set*.** Measured (26a §4.4): `{order,1,2} =/= {order,2,1}` while
  `#{b=>1,a=>2} =:= #{a=>2,b=>1}`. Ticket 09 says a record type *is* its field set, and a set has
  no order — so a tuple erasure must invent a canonical ordering and put it in the wire format.
- **A tag derived from the name gains a nominal *identity*.** That is the thing 09 ruled out, and
  it is why the minting is *sugar over a writable field* rather than a property of the type.

Two corroborations that cost nothing: `json:encode/1` takes a map directly and refuses a tuple at
any depth (26a §5, re-verifying ticket 16 §4), and an Elixir struct arrives as a map with one
extra key rather than needing conversion (ticket 06).

### The cost, measured — the number ticket 18 owed

Ticket 18 asserted without measuring that a map discriminator would be "strictly larger" than the
tuple's +13 bytes. It is, but the shape is friendlier than assumed, and **the tagged map lands
within one byte of the tuple** (26a §1–2, OTP 28.5, noise floor 0):

| discriminator | 3 fields | 8 fields | slope | instrs |
|---|---|---|---|---|
| tuple — tag + arity | +13 B | +13 B | flat | +4 |
| map — exact field set | +29 B | +34 B | +1 B/field | +5 |
| map — exact set + 2 value tests | +44 B | — | — | +8 |
| **tagged map — one `map_get`** | **+14 B** | **+14 B** | **flat** | **+3** |

Two mechanisms explain it. The exact-set check emits **one** `has_map_fields` instruction carrying
the whole key list, so the +1 B/field is operand growth rather than a test per field. And
**`map_get/2` on an absent key fails a guard silently rather than raising** (26a §4.3, measured
with a runtime-built key so the compiler could not fold it) — which is why a single test is a
complete discriminator: no `is_map`, no `map_size`, no per-field presence check.

Projection time, 3-field record, best of three at 2M reps: tuple 2.17 ns unguarded, **7.04 ns
guarded**; map 8.76 ns guarded; tagged map 8.78 ns. The 4× gap is between the *unguarded* forms;
ticket 18 emits a guard on every exported function taking a record, so the comparison that ships
is 7.04 vs 8.78 — the tag itself costs nothing measurable.

**So the DDD requirement and the cheapest possible ticket-18 boundary guard want the same thing**,
and it is not a coincidence: both ask "is this term the aggregate it claims to be", and a tag
answers in one instruction.

### What forced the tag: DDD identity (David)

The ticket was heading for "the author writes a discriminating field by hand" until David named
the requirement it fails: *in DDD it is very important that `Order` and `Invoice` are not the same
type — `Update(Order o)` called with an `Invoice` must be an error.* Under ticket 09 as written,
two records with identical field sets **are** one type, so that call compiles, and `Order | Invoice`
is not even a union of two things. A hand-written tag fixes it — but it is *omittable*, and an
omitted tag silently unifies two aggregates with no diagnostic, which is precisely the
plausible-looking structural drift the standing constraint names as agent authorship's
characteristic failure.

Rejected alongside:

- **Author-written tag only.** 09 intact, but correct-only-if-remembered, and the failure is silent.
- **Mint a tag for every record type.** Correct by default, but removes the choice: `Point` and
  `Vector` over the same fields become different types with no way to spell that they are one, and
  ticket 27 §7 already declined row polymorphism, so there is no escape hatch to loosen it again.

### Elixir is this design, and that is measured rather than argued

`Module.Types.Descr` types a struct as an **open map whose tag is an atom singleton** — no nominal
construct anywhere (26c):

```
%{map: {:open, %{id: %{bitmap: 4}, __struct__: %{atom: {:union, %{Order => []}}}}}}
```

Two struct types with identical fields and different tags are **disjoint**; strip the tags and they
are **equal**. Elixir fails the nominality test in exactly the place this design does, for exactly
the same reason — which makes it ecosystem-scale evidence that the shape carries a domain-modelling
codebase, and retires the worry that this is a middle ground nobody has shipped. `defstruct` is
also the precedent that the minting can be blessed syntax rather than ceremony in every literal.

**This amends ticket 09's inventory, not its reasoning.** 09's line *"there is no `record` keyword
to design"* becomes *"there is one, and it is sugar for a minted discriminator field, not a second
kind of type"*. All four capabilities 09 refused nominality to keep are intact: union closure
(`Order | Invoice` is an ordinary discriminable union), negation (`not Order` is set subtraction),
the boundary (the tag is *in the term*, so one guard decides it — where nominal identity would be
09 §5's compile-time-true and runtime-false), and exhaustiveness (ticket 04's residual is
arithmetic over sets). Codegen needs the hand-written door left open too: ticket 15's
`ValidationError` is compiler-generated, ticket 18's foreign declarations name shapes without
minting, and `ValidateAs<T>` constructs one — under real nominality each needs a privileged back
door into the constructor, and under this design the compiler writes what a user could.

### One constraint this imposes on the module-naming fog

If the tag is minted from the **short** name, `Shop.Orders.Order` and `Billing.Invoices.Order`
both mint `:order` and two aggregates from different bounded contexts silently unify — the exact
failure the minting exists to prevent, at a different scale and invisible. **So the tag must be
minted from the qualified name**, which hands the map's *Module and namespace system* fog patch a
requirement it did not have: whatever atom a module identifier lowers to must be unique enough to
carry aggregate identity, not only to avoid Erlang module collisions. Recorded here because it
constrains that patch rather than blocking this ticket.

### What the boundary guard actually contains — derived from ticket 18, not amending it

The cheap tag test and the exact-set test are not competing options; they answer different
questions, and **ticket 18 §1's existing rule already allocates them** without needing a new one.

- **The tag test is always emitted** on a record parameter. It establishes *which record this
  claims to be*, and no function body ever checks that — a body projects fields, so it cannot
  object to a term wearing the wrong identity. That is 18 §1's "the body would not object" clause
  applying to a check no body performs. One `map_get`, +14 bytes, flat in field count.
- **Field presence and value tests follow 18 §1 unchanged**, function by function. A body that
  computes with a field (`o.Total + o.Paid`) already crashes on a wrong type — outcome 2, free,
  no guard needed. A body that only *compares* (`o.Status == :draft`) silently yields false on a
  wrong type, which is ticket 06's outcome 3, and 18 already emits there.
- **The exact-set test is emitted only where a codegen obligation consumes the record**, per
  18 §1(c), which is unconditional. Ticket 16 §4's generated encoder is the case that forces it:
  extra fields are harmless to projection and to exhaustiveness, but the encoder would
  *serialise* them, publishing fields no type declares.

So the erasure decision costs +14 bytes at the ordinary boundary and the full +29 only where
generated code reads the whole record — which is the same two-tier shape ticket 17 §2 established
for emitted precision, arrived at independently.

### Owed by this section

- **The spelling is not settled** — `record X { ... }` versus a modifier on `type`. The semantics
  are decided; the surface follows, and it touches ticket 22's deferred question about which
  opinions live in the grammar.

## 2. Construction and update — SETTLED (David)

**`with` alone. Spread is not in the language. Construction names the type. The separator is `=`.**

```csharp
Order o    = Order { Id = "A-1", Status = :draft, Lines = [], Paid = 0 };
Order paid = o with { Status = :paid, Paid = 500 };
```

### `with`, and why spread is refused

**This pays ticket 27 §7's debt rather than reopening it.** 27 declined row polymorphism, and its
load-bearing argument was about *this* construct: record update is `with`/spread, which is
**syntax**, so it types structurally against a concrete record type with no variable involved. 27
recorded that if update turned out not to be compiler-visible syntax, its justification weakened
and it must be told. It is syntax, and it is width-preserving. **27 §7 stands as written.**

Spread is refused because **its defining capability is the one thing the type system closed**.
`{ ...o, Extra = true }` widens, and under exact field sets that is a different type — one that
carries a minted `:order` tag while not being an `Order`, and which no signature can be written
against, because typing "an `Order` plus whatever else" is precisely the row variable 27 declined.
Remove the widening and `{ ...o, Status = :paid }` is `with` with a second spelling — the
redundancy ticket 17 refused when it killed `else` and ticket 16 refused when it settled on one
dispatch mechanism.

Three supports beyond that. `with` is a tier-1 borrow for the C# half of the audience and, for the
TypeScript half, a new spelling of semantics they already have — a **write** cost, which the
standing constraint says carries little weight, against ambiguity, which carries full weight.
Ticket 05 found `with` becomes *more* central here than in C# because there is no mutation at all,
so it earns a keyword on frequency. And **ticket 15 was pushed off `with` onto ticket 17
explicitly to reserve it for this ticket** — declining it would have meant 15 gave up a construct
for nothing.

### Construction names the type, and target-typing is refused

The tag has to enter the term somewhere, so something must name the type at the construction site.
The alternative was target-typed construction (`Order o = { Id = "A-1", ... }`, C# 9's `new()`
inference filling the tag from the expected type). Refused on **read cost**, not soundness:

```csharp
var draft = Order { Id = "A-1", Status = :draft, Lines = [], Paid = 0 };   // always an Order
var draft = { Id = "A-1", Status = :draft, Lines = [], Paid = 0 };         // untagged, anonymous
```

Mandatory signatures (ticket 04) mean most positions *do* carry an expected type, which is what
makes the exception nasty — it would work almost everywhere, so the case where it does not is the
surprising one, and the diagnostic lands at the use rather than at the literal. Ticket 08's
*narrowing is always written, never inferred* is the nearest precedent; it is an analogy rather
than the same rule, since construction is not narrowing, but it points the same way and ticket 17
§7 closed the fully-implicit option for the valve on the same instinct.

`new` is dropped: it has no job here, there being no allocation or reference semantics to
distinguish — which is also why Elixir writes `%Order{}` rather than a constructor call. The result
mirrors the declaration: `record Order { ... }` declares, `Order { ... }` constructs.

### The separator is `=`, and the atom sigil forces it

Declarations and patterns use `:` (`Sku: string`, ticket 01's property pattern `{ Balance: 0 }`);
construction and update use `=`. That is **C#'s own split — colon for matching, equals for
assigning** — and prototype 01b already wrote it that way (`o with { Status = :placed }`) without
the question being decided.

It is also forced independently: atoms are spelled `:placed`, so a colon separator yields
`Status: :placed`, two colons adjacent, where `Status = :placed` reads clean. *A three-way
agreement between declaration, pattern and construction was proposed during the session and was
wrong* — C# distinguishes the two deliberately, and the atom sigil means this language must too.

## 3. Field access — SETTLED (David)

**The dot projects. Disambiguation from module qualification is lexical. Projection over a union
is legal where every member carries the field.**

```csharp
o.Status            // lowercase receiver  -> value projection
List.Map(f, xs)     // PascalCase receiver -> module qualification
Total(o)            // PascalCase, no receiver -> function call
```

**Ticket 17's refusal does not reach this, and the reason is mechanical.** `xs.Filter(f)` needs
type-directed resolution of an *unqualified name* against a candidate set — closed by ticket 08
(one arrow per arity, no overload set) and ticket 16 (one dispatch mechanism). `o.Total` resolves
against one record type's declared field set, known from the signature, with no candidate set and
nothing to dispatch on. 17 explicitly handed this over rather than settling it, and prototype 01b's
transition table — the passage ticket 01 called the reason the language exists — had been using
`o.Status` and `o.Lines` all along.

**The disambiguation is decided before types exist**, which matters: a type-directed one would drag
back exactly what 17 refused. Values are lowercase and modules and functions PascalCase throughout,
so the parser settles it. A consequence worth stating in the spec: a record field `Total` and a
module function `Total` coexist without collision, distinguished by syntax rather than resolution.

**Union projection is legal where every member carries the field**, and it is free. It is decidable
at compile time from the declared union with no dispatch — the same shape as ticket 16 allowing `<`
and `==` on bare type variables because they are total and non-dispatching. **§1's map erasure is
what makes it one instruction**: `map_get(total, X)` regardless of which member arrived. Under the
tuple erasure §1 rejected, the field sits at a different offset per member and this would have
required real dispatch — so §1 paid for this without knowing it. Where a member lacks the field it
is an error, and the fix is to discriminate on the tag first, which is the language's own idiom.

## 4. Optional and absent fields — SETTLED (David)

**There are no absent fields. Every declared field is always present in the term; optionality is a
value, spelled `option<T>`. There is no `?` field modifier.**

```csharp
record Profile { Id: string, Notes: option<string> }   // kept
record Profile { Id: string, Notes?: string }          // refused
```

### Why, in the order the arguments actually weigh

**The exponential is the argument that decides it.** With every field always present, a record's
field set is fixed and the exact-set check is one `has_map_fields` plus `map_size`. With *k*
optional fields the type denotes **2^k shapes** and the discriminator becomes a disjunction over
all of them — `{Id}`, `{Id,Notes}`, `{Id,Phone}`, `{Id,Notes,Phone}` for k=2. Ticket 18 emits that
guard on every exported function taking a record and unconditionally wherever the value feeds a
codegen obligation. An exponential in the declaration is not a cost this language can absorb.

**Two spellings for absence would collide.** `Notes?: option<string>` has three states — key
absent, key present holding `:nothing`, key present holding a string — two of which mean the same
thing with nothing to say which one a given function produces. TypeScript ships this hazard and
grew a compiler flag for it (`exactOptionalPropertyTypes`), which is the audience half most likely
to reach for `?` having its own toolchain reach back.

**It needs no new rule for ticket 15's collapse landmine.** `option<string>` is `string | :nothing`
and discriminates fine; only `option<atom>` collapses, because 09's normalisation absorbs a
singleton into a cofinite top — and ticket 15 already makes that an error at the declaration. So
record fields inherit an existing rule rather than acquiring a special case.

**The wire distinction does not disappear, it moves to the boundary** — where this map already puts
everything else. `ValidateAs<T>` maps an absent JSON key to `:nothing` for an `option<T>` field,
which is the anti-corruption layer doing its job rather than the type system carrying two notions
of absence.

**Measured, not argued**: Elixir has no absent fields either (26b §5) — every struct key is always
present and "unset" is spelled `nil`. The largest shipped instance of this erasure declined the
distinction.

### The modelling consequence, which is the point rather than a consolation

An optional field is usually **two record types wearing one name**, and §1 just made that cheap to
fix: tagged records discriminate in one instruction, so `record Draft {...} | record Placed {...}`
costs what an optional field would have cost and makes the illegal states unrepresentable. Refusing
`?` pushes toward the modelling the language exists to support rather than costing expressiveness —
the same instinct that made `Order` and `Invoice` distinct in §1.

### Owed by this section

- **The encoder must pick.** An `option<T>` holding `:nothing` — does ticket 16 §4's generated
  encoder emit `"notes": null` or omit the key? The type model no longer distinguishes them, so
  the encoder decides, and it is a published-mapping question belonging with 16's owed
  serialisation debt rather than with the record surface.

## 5. Consequences for other tickets

- **[Ticket 27](27-parametric-polymorphism.md) — its §7 debt is PAID, not merely unbroken.** 27
  declined row polymorphism on the assumption that record update would be compiler-visible,
  width-preserving syntax, and asked to be told if that changed. §2 confirms it: `with` is syntax,
  spread is refused *because* it widens. 27 §7 needs no amendment and its deferred-option
  requirements stay filed.
- **[Ticket 09](09-union-representation.md) — its inventory is amended, its reasoning is not.**
  *"There is no `record` keyword to design"* becomes *"there is one, and it is sugar for a minted
  discriminator field, not a second kind of type"*. All four capabilities 09 refused nominality to
  keep are intact (§1).
- **[Ticket 18](18-boundary-defence.md) — gains a two-tier guard, derived from its own rule.** The
  tag test always; presence and value tests per 18 §1 unchanged; the exact-set test only where a
  codegen obligation consumes the record (§1). 18's asserted "strictly larger" is now measured, and
  is +14 rather than the +29 it feared.
- **[Ticket 16](16-ad-hoc-polymorphism.md) — owed the null-versus-omit decision** for an
  `option<T>` field in the generated encoder (§4), on top of the binaries debt it already carries.
- **[Ticket 15](15-error-model.md) — `ValidationError` can now be a record**, which 15 spelled as a
  tuple only because this ticket had not settled what a record was. It is also the test 15 named:
  a compiler-*generated* record value, which §1's design supports without a privileged constructor
  because the desugaring is writable.
- **[Ticket 25](25-exemplar-programs.md) — unblocked in practice.** Four of its six exemplars
  construct or destructure records, and every construct they need now exists.
- **[Ticket 22](22-how-opinionated.md)** — the *spelling* of the minting form is a grammar-opinion
  question and lands in 22's territory even though the semantics are settled here.
- **The map's module-and-namespace fog** gains a hard requirement: **the tag must mint from the
  qualified name**, or `Shop.Orders.Order` and `Billing.Invoices.Order` both mint `:order` and two
  bounded contexts silently unify (§1).
- **The map's DDD-invariants fog narrows again.** §1 gives aggregate *identity* — an `Invoice`
  cannot be passed where an `Order` is wanted. It does not give construction-time *invariants*:
  the language guarantees shape, never provenance (09 §5, ticket 21, re-verified in 26b §6). What
  still has nowhere to live is the invariant enforced at construction, which stays with ticket 15's
  `result<T, E>` and ticket 18's boundary guards.
- **Extensibility is closed rather than handed on.** The ticket's scope boundary said to hand
  record extensibility to ticket 20. With 27 §7's exact field sets, §2's width-preserving update
  and §4's absence of optional fields, there is nothing left to hand over — a wider record is
  simply a different type.

