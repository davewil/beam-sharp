# 16 — Ad-hoc polymorphism: what replaces interfaces and extension methods?

Type: grilling
Status: resolved 2026-08-12
Blocked by: 09, 27 — both resolved

## Question

Ticket 05 dropped both of C#'s ad-hoc polymorphism mechanisms — **extension members** and
**static abstract interface members** — as load-bearing on OOP and the CLR, and flagged the
consequence explicitly: the language currently has **no ad-hoc polymorphism story at all**.

That is a hole, not a simplification. Without one there is no way to write a function that
works over "anything that can be compared", "anything that can be serialised", or "anything
with a length" — and every BEAM language has had to answer this somehow.

Decide the mechanism. Candidates, each with a real precedent:

- **Type classes** — PureScript/purerl and Haskell. Powerful, principled, needs dictionary
  passing at runtime and interacts non-trivially with set-theoretic subtyping.
- **Protocols** — Elixir's runtime dispatch on term shape. Idiomatic on the BEAM and cheap
  to implement, but dispatch is dynamic, which sits awkwardly against enforced exhaustiveness.
- **Structural dispatch** — since types are (probably) structural after ticket 09, dispatch
  on shape directly, with no nominal declaration at all. Fits the type system, but overloads
  the same mechanism the headline feature already uses.
- **Nothing** — no ad-hoc polymorphism; callers pass functions explicitly. Honest and small.
  Gleam largely takes this line. State the ergonomic cost if chosen.

Whatever is chosen must answer: how does it interact with **multi-clause head dispatch**,
which is already a dispatch mechanism? Two dispatch systems in one language need a clear
story about which fires when.

## The central constraint, from ticket 09 — resolved 2026-08-12

The "(probably)" in the structural-dispatch candidate above is now settled, and it is a harder
constraint than that bullet suggests.

**With no nominal identity anywhere in the language, dispatch cannot key on a name.** Ticket 09
made types structural and open, made naming pure aliasing, and left the language with *no*
nominal construct — so two names over the same set are the same type. That removes the thing
every dictionary-passing scheme resolves against:

- **Type classes are not simply "powerful but costly" here — their resolution key is gone.**
  PureScript, Haskell and Rust all select an instance by the *nominal head* of a type. With
  aliasing, `instance Show OrderId` and `instance Show CustomerId` are instances for the same
  type, and the language cannot tell which was meant. Adopting classes would require
  reintroducing nominal identity for exactly this purpose — which is a reversal of ticket 09,
  not an extension of it, and would need to answer ticket 09 §5's finding that nominal identity
  is unenforceable across the Erlang boundary.
- **Structural dispatch is the candidate that survives unchanged**, and it now has machinery
  waiting for it: ticket 09 §4 requires the compiler to synthesise a **BEAM guard expression**
  deciding membership for each member of a union, and rejects unions where it cannot. That
  synthesiser is a structural discriminator — the same thing structural dispatch needs.
- ~~**Elixir-style protocols sit between the two** and inherit the problem in a weaker form:
  protocol dispatch keys on term shape, which is structural, so it survives — but the
  *registration* step is nominal in Elixir and would need a structural replacement.~~
  **Wrong, corrected 2026-08-12 — see the next section. Nothing about Elixir's mechanism is
  nominal, and no replacement is needed.**
- **"Nothing" (explicit function passing) is unaffected**, and its cost is unchanged.

## Correction — Elixir's structs and protocols, verified

**Raised by David, 2026-08-12: "Elixir solves dispatch by using structs and protocols."**
Correct, and the bullet struck through above got the reason wrong. Verified locally on Elixir
1.19.5 / OTP 28 — [`prototypes/16a_elixir_protocol_dispatch.exs`](../prototypes/16a_elixir_protocol_dispatch.exs),
runnable:

| Observed | Result |
|---|---|
| What a struct is | `%{name: "d", __struct__: User, age: 1}` — a plain map carrying an **atom** |
| Two structs with identical field sets | Dispatch differently; the tag is the whole discriminator |
| How the impl is found | `Describe.impl_for(u)` → `Describe.User` — a module named from the tag |
| **Hand-built plain map with `__struct__: Admin`** | **Dispatches as an Admin; `is_struct/2` returns `true`** |

**There is no nominal type identity anywhere in this mechanism.** Elixir has no static types at
all. `defimpl ... for: User` names a module at compile time, but what dispatch *reads* is an atom
sitting in the term. **The name is data.** So this is not a counter-example to the constraint —
it is the worked demonstration of ticket 09 §5's remedy, at ecosystem scale, in map form rather
than tuple form.

### The constraint, restated precisely

Not *"dispatch cannot key on a name"* but: **dispatch cannot key on a name that is not in the
term.** Elixir's answer is to put the name in the term. beam-sharp can do exactly that, and
ticket 09 already commits it to the mechanism — a tag makes two otherwise-identical field sets
genuinely distinct *sets*.

What still does not work is unchanged: **type-class resolution keyed on a compile-time name with
no runtime witness.** `instance Show OrderId` where `type OrderId = string` has nothing in the
term to dispatch on, and `OrderId` and `CustomerId` are the same type. That option stays dead.

### What this makes newly available, and it is better than Elixir's version

The ticket body complains that protocol dispatch "is dynamic, which sits awkwardly against
enforced exhaustiveness". **Under ticket 09 that complaint mostly dissolves**, because the tag is
part of the *type*, not merely of the value:

- The compiler knows the tag **statically** from the declared type, so an impl can be **resolved
  at compile time** rather than by a runtime `impl_for` lookup.
- **Impl coverage becomes an exhaustiveness question the type system already answers** — the set
  of tags in a union is exactly the set of impls required, computed by the same subtraction
  ticket 04 specified. A missing impl is a residual, not a runtime `Protocol.UndefinedError`.
- Elixir needs **protocol consolidation** as a Mix build step precisely because it cannot know
  any of this statically. beam-sharp would get consolidation by construction.

**Consequence for framing this ticket**: "protocols" and "structural dispatch" are not two of the
four candidates — they are the same candidate, and the protocol version is what it looks like once
you give the dispatch table a name. The live question is narrower than the ticket's list suggests:
whether that mechanism earns a language construct, and how it relates to multi-clause head
dispatch, which keys on the same tags. **Still open; still HITL. This section sharpens the
options, it does not choose between them.**

### One caution carried forward

Result 4 above — the forged tag — is also **independent local evidence for ticket 09 §5's derived
claim** that the BEAM has no construction discipline. Even Elixir's nominal-*looking* dispatch is
defeated by a hand-built term. So whatever dispatch mechanism this ticket picks, it inherits
[ticket 18](18-boundary-defence.md)'s problem: a tag arriving from raw Erlang is an assertion, not
a guarantee.

The interaction question this ticket already asks — how the mechanism relates to multi-clause
head dispatch — gets sharper rather than easier: if dispatch keys on structure, then it and
clause-head matching are **the same kind of operation**, and the story about which fires when is
now mandatory rather than tidy-minded.

Related: the newtype gap ticket 09 §5 leaves open (`Meters` and `Feet` are one type; tag them
to distinguish) is the *same* gap in a different place. If ticket 20 answers it with refinement
types, that answer may also supply a dispatch key — worth checking before deciding here.

## Notes

HITL. Surfaced by ticket 05's inventory, which named the gap rather than papering over it.
Blocked by 09 (nominal vs structural changes what dispatch can even key on) and 11 (whether
the type system supports constraints).

## Constraints from ticket 27 — resolved 2026-08-12

**This ticket is unblocked, and 27 handed it both a boundary and a debt.**

**The boundary, which is this ticket's own framing in one line**: *a type variable is a slot for
values you carry; a union is a slot for values you examine.* Parametric polymorphism is now the
pass-through mechanism and it is deliberately incapable of dispatch — 27 §2 makes type variables
**opaque in clause heads and guards**, so no clause may test a value whose declared type is a bare
variable. Whatever this ticket chooses, it cannot be "let a generic function look at its argument";
that door is closed by decision, not by omission.

**The debt: bounds are yours.** 27 §3 made type variables **unbounded**, explicitly deferring
capability constraints here, on the reasoning that a bound is almost always *"this type must
support some operation"* — which is ad-hoc polymorphism wearing a bracket. If this ticket wants
`where TSource <: ...`, four requirements were captured with the deferral:

1. A syntax that collides with neither `when` (guards) nor `type X = ...` (aliases).
2. A decision on whether a bound may mention **another variable** (`TA <: TB`) — the line between
   a finite check and general constraint solving.
3. **A cost measurement at showcase clause counts.** This is the serious one. 27 §1 accepted
   generics on the argument that instantiation is *matching*, not solving, because beam-sharp has
   no inference (04), no intersection arrows (08), no bounds and no row variables. **Bounds are the
   feature that breaks that argument**, so they cannot be adopted on taste — they need the number.
4. A rule for what a bound publishes to the Erlang world, given that 27 §6 measured emitted
   polymorphic specs to be inert.

**What is available without bounds, and may make them unnecessary** — 27 §3 records all three:
monomorphic functions per type (`MaxInt`/`MaxFloat`), a **union parameter** (which is dispatchable,
unlike a variable), and **passing the capability as an argument** —
`TSource Max<TSource>(TSource, TSource, fn(TSource, TSource) -> bool)` needs no bound at all,
because the capability arrives as a value. That third one is the same move ticket 14 made when it
put the message type on the client API function rather than on the pid, and it is worth weighing
seriously before reaching for constraints.

**Ticket 09's mechanism is unchanged and still the front-runner**: dispatch on an atom *in the
data* (Elixir's `__struct__`, resolvable statically here where Elixir needs a consolidation pass).
27 confirms this was never in tension with generics — `Enumerable` involves no type parameters
anywhere, which was the correct half of David's input.

**One new fact from 27 §6 to weigh**: an emitted polymorphic `-spec` is **not enforced** by
Dialyzer, measured. If this ticket's mechanism produces polymorphic signatures, they defend nothing
at the Erlang boundary.

---

## Answer — resolved 2026-08-12

**The language gets no ad-hoc polymorphism construct, and the hole ticket 05 flagged was half
imaginary.**

The three motivating capabilities — "anything comparable", "anything with a length", "anything
serialisable" — were *measured* before being designed for, and they land in three different
buckets, none of which is dispatch. A capability the type determines becomes a **codegen
obligation**, which the compiler writes. A capability over a set of types known at the definition
is a **union parameter** with a clause each. A capability over a set that is not known is **passed
as an argument**, an ordinary value. The bucket is chosen by what the capability *is*, not by
preference, and that is what stops the first one growing by taste.

Type classes stay dead on [ticket 09](09-union-representation.md): resolution keys on a nominal
head and there are no nominal heads. **Protocols died on [ticket 13](13-compilation-target-decision.md),
not on taste** — open extension needs whole-program consolidation, which fights 13 §3's
coincidence of the consistency unit and the deployment unit, *the same argument
[ticket 27](27-parametric-polymorphism.md) used against monomorphisation*. **Hot loading is a
consequence of that coincidence, not a second ground** (re-derived 2026-08-27, below). And the
static-closed variant is bucket 2 with ceremony, which **corrects this ticket's earlier
"consolidation by construction" line**.

Measured: the BEAM's term order is **total across every type** — `1 < :ok` is `true` — so "anything
comparable" needs no mechanism at all. `<` is nonetheless restricted to **same-type operands**, with
the universal order kept as a *named* prelude escape for the cases that genuinely need it
(`ordered_set` tables, sorting a mixed-key list). **`==` means `=:=`**, decided on internal
agreement rather than on familiarity: Erlang's coercing `==` runs through tuples, lists and map
*values* and then **stops dead at map keys**, while the clause head and `maps:get` do not coerce at
all — so the exact spelling agrees with two constructs and disagrees with none.

The generation rule is that **the type determines the result, either inherently or by published
decree**. Serialisation qualifies by decree, and the measurement is why the decree is worth paying
for: `json:encode/1` **fails on tuples at any depth, at runtime**, and the tuple is this language's
workhorse (09's newtype remedy, 15's `(:error, E)`). Generation moves that failure to compile time,
naming the member with no encoding, which a runtime protocol could never do. **Only the encode
direction is new** — decoding is already `ValidateAs<T>` after a parse.

`<` and `==` work on **bare type variables** — total, non-dispatching, and unable to fail — so
`Sort<T>` and `Max<T>` cost nothing. **Bounds are refused outright**, not deferred: both routes to
discharging one are closed, monomorphisation by 27 and a runtime dictionary by 09, so a bound would
be documentation with a colon in it. **This retires ticket 27's cost measurement**, the requirement
27 §3 called "the serious one".

Finally, **ticket 05 miscategorised extension methods** (David, 2026-08-12) — one debt, not two.
The call-syntax half was always [ticket 17](17-pipeline-and-comprehension.md)'s and the overloading
half was always [ticket 08](08-head-and-guard-syntax.md)'s, which leaves *static abstract interface
members* as the whole of the real hole — and **a codegen obligation is exactly that with the
compiler writing the implementation**.

**Amended 2026-08-14** — one of the two reasons for refusing protocols was invalidated by
[ticket 26](26-data-modelling.md) and nobody went back. David, stating 26's intent: *"Exactly
records, that's why they were introduced alongside `type` — for protocol dispatch."* This ticket
refused protocols because dispatch cannot key on a name that is not in the term (09 §5) *and*
because open extension needs whole-program consolidation. **26 §1 put the name in the term** — a
minted tag, as data — so the first reason is gone and only the second stands. **The refusal narrows
from "no protocols" to "no *open* protocols".** What this ticket wrote up as "bucket 2 with
ceremony" **is** protocol dispatch once the tag is in the term, checked exhaustive at the
definition, and it needs no construct because the language's headline feature already *is* the
dispatch construct. The headline survives and reads stronger: the capability arrives *without* an
ad-hoc polymorphism construct. For the record — **26 was not a data-modelling decision that
happened to help here; records were introduced for this**, and 26's own entry does not say so.

**Amended 2026-08-27** — this ticket and ticket 27 both cite a constraint ticket 13 does not
contain. Prompted by David asking whether not needing hot code loading changes the open-extension
answer: **it does not, and the design is unchanged** — what changes is why. Ticket 13 discusses
unions, protocols and whole-program compilation nowhere; "aggregate granularity and hot loading"
was this ticket's own characterisation of 13 §§2–3, written on 2026-08-14 and never checked against
13. Re-derived: **13 §2 is not available**, because the obligation forbids *in-process compiler
state* so that `.abstr` plus `erlc` always works, not a build-time pass over sources — and `bsc`
already threads a `World` across the transitive `using` closure (`bsc.erl:278`), with `rebar_mix`
consolidating 14 `Jason.Encoder` implementations measured working on this platform (51 §119).
**13 §3 is available, and hot loading is not why**: consolidation makes A's `.beam` depend on B's
source, breaking *"the consistency unit and the deployment unit coincide"*, so the ground survives
with hot loading removed entirely. **A stronger ground exists that this ticket never had** —
`bs_api.erl:22`, *"a type name does not cross the module boundary"*, so B cannot name A's union at
all. That is architectural, and **it should lead the refusal**. research/07's "permitted set at the
declaration, not by scanning" is **suggestive only**, since it carries the LDM's own caution that it
be measured. **The refusal is a deferral with an inherited, checkable trigger** — 01d §129-131 and
`13:202`: *open extension becomes available if and only if the operation replaces the aggregate as
the unit of deployment*, with 01d ruling observability out itself because `dbg:tpl` already traces a
single function. Note the coupling: that trigger is reachable **only while hot loading is
retained**, so dropping hot loading turns the deferral into a plain rejection. Ticket 27 survives
intact, losing one leg of one sub-argument to the same miscitation and keeping it on a fact its
prose never stated — knowing every module in the `using` closure is not knowing every instantiation.

The sharpest downstream consequence is that **[ticket 18](18-boundary-defence.md) gains a
consumer**: a generated encoder trusts a declared type the boundary does not enforce, and crashes
inside code no one reviewed.

**The language gets no ad-hoc polymorphism construct, and the hole ticket 05 flagged turns
out to be smaller than it recorded — because half of it was never a hole.**

The ticket's three motivating capabilities — "anything comparable", "anything with a length",
"anything serialisable" — were measured before being designed for, and they land in three
*different* buckets. None of the three wants a dispatch mechanism. Evidence:
[`prototypes/16b_which_capabilities_are_already_primitive.erl`](../prototypes/16b_which_capabilities_are_already_primitive.erl)
and [`prototypes/16c_two_equalities_and_who_agrees.erl`](../prototypes/16c_two_equalities_and_who_agrees.erl),
both runnable, both `local` on OTP 28 / erts 16.4.

## 1. No construct. Three buckets, keyed on a property of the capability

| The capability is… | Mechanism | Open to third parties? |
|---|---|---|
| determined by the type | a **codegen obligation** — the compiler writes it | yes: every type has it, nothing registers |
| not determined, set of types known at the definition | a **union parameter** with a clause each | no |
| not determined, set of types not known | **passed as an argument**, an ordinary value | yes, at the call site's cost |

The bucket is chosen by what the capability *is*, not by preference. That matters because it
is what stops bucket 1 from growing by taste — see §4.

**What was ruled out, and why each is dead rather than merely costly:**

- **Type classes** — dead on ticket 09, unchanged. Resolution keys on a nominal head; there
  are no nominal heads. `instance Show OrderId` and `instance Show CustomerId` are instances
  for the same type. This was already established in the section above and is not revisited.
- **Protocols with open extension, Elixir's shape** — dead on ticket 13. Open extension needs
  every impl collected, which is either a whole-program consolidation pass or a runtime
  lookup. Consolidation fights aggregate-granularity compilation and has no story for hot code
  loading — **the same argument ticket 27 used to reject monomorphising per call site**, and it
  fails in the same place: at a shared library type that lives outside the aggregate.
- **Protocols resolved at runtime, unconsolidated** — dead on the headline claim. It accepts
  `Protocol.UndefinedError` as a live failure mode in a language whose pitch is that every case
  has a clause.
- **Static protocols over a closed set** — not dead, but empty. Static resolution needs the tag
  set known at the definition; a known tag set is a closed union; a closed union with a clause
  each is bucket 2 with extra ceremony. **This corrects a line in the section above**: "beam-sharp
  would get consolidation by construction" is true *only over a closed union*, at which point
  there is nothing left to consolidate.

**The cost, stated plainly.** A third party cannot teach *your* function about *their* type for a
capability the compiler cannot derive. They must change your code, or you must have taken the
capability as a parameter. This is the expression problem and this answer picks a side of it.

## 2. Comparison is same-type only, with the platform's order kept as a named escape

**Measured**: the BEAM's term order is **total across every type** — `1 < :ok`, `#{a => 1} < []`,
`ok < {1}` all evaluate to `true` with nothing declared anywhere. "Anything comparable" therefore
needs *no mechanism at all*; it is the one motivating capability the runtime hands over free.

The decision is that beam-sharp does not pass that on unchanged. **`<`, `>`, `<=`, `>=` require
both operands to be the same type**, so `1 < :ok` does not compile. Tier-1 borrow: C# defines
comparison per type and refuses unrelated operands, and a comparison across unrelated types is
overwhelmingly a bug the compiler was in a position to catch.

The universal order is **not** thrown away — it is reachable as a **named prelude function**
rather than an operator. It is genuinely needed: it is what `ordered_set` ETS tables sort by,
and it is what lets a heterogeneous list sort without a hand-written comparator. Naming it
rather than spelling it `<` means using it is a visible act. The spelling is a spec-drafting
detail; what is decided is that it exists, is named, and is not the operator.

## 3. `==` is exact — one equality, and it agrees with the clause head

Erlang ships two equalities. beam-sharp ships one, and it is `=:=`. **`1 == 1.0` is `false`
where it is reachable at all.**

The reason is not fidelity to Erlang and not the C#/TS reader's expectation — it is internal
agreement, and it was measured. Erlang's coercing `==` is **not consistently coercing**:

| | `==` | `=:=` |
|---|---|---|
| `1` vs `1.0` | true | false |
| `{1}` vs `{1.0}` | true | false |
| `#{a => 1}` vs `#{a => 1.0}` (map **value**) | true | false |
| `#{1 => a}` vs `#{1.0 => a}` (map **key**) | **false** | false |

The coercion runs deep through tuples, lists and map values, then stops dead at map keys. And
the two constructs this language is built on do not coerce at all:

- **A clause head does not.** `f(1)` does not fire for `1.0`; it falls through. Pattern matching
  is `=:=`, so *the headline feature already picked a side*.
- **A map key lookup does not.** `maps:get(1.0, #{1 => x})` is `{badkey, 1.0}`.

So a coercing `==` would put the guard in disagreement with the clause head directly above it —
two different answers to "is this value 1" on adjacent lines. Choosing `=:=` agrees with two
constructs and disagrees with none.

**A third disagreement worth recording**: in the *order*, `1` and `1.0` tie — neither `1 < 1.0`
nor `1.0 < 1` holds — while `=:=` says they differ. Under §2's same-type rule this is unreachable
in ordinary code (`int` and `float` are distinct types), so it bites only for a union containing
both and for a bare `term`. Those are exactly the boundary cases where a quiet wrong answer costs
the most, which is the argument for closing it rather than leaving it to the platform.

## 4. The generation rule: the type determines the result — inherently, or by decree

Bucket 1 needs a boundary or it becomes a grab-bag. The rule:

> A capability becomes a **codegen obligation** when the type determines the result uniquely —
> either **inherently**, or because **the language publishes the mapping** that fills the gap.

The four existing obligations (`ValidateAs<T>`, `ParseAtom<T>`, `ToExistingAtom`, the foreign
wrapper) qualify inherently: there is exactly one correct answer to "does this term inhabit `T`",
and the compiler holds information the author does not.

**Serialisation qualifies by decree, and the measurement is why it is worth the decree.**
`json:encode/1` (OTP 27+) **fails on tuples, at any depth, and only at runtime**:

```
#{a => 1}                  => <<"{\"a\":1}">>
ok                         => <<"\"ok\"">>
{a, b}                     => {failed, {unsupported_type, {a,b}}}
#{k => {1, 2}}             => {failed, {unsupported_type, {1,2}}}
#{lines => [{sku, …, 2}]}  => {failed, {unsupported_type, {sku,<<"A">>,2}}}
```

**The tuple is beam-sharp's own workhorse** — ticket 09's remedy for the newtype gap is a tagged
tuple, and ticket 15's `result<T, E> = T | (:error, E)` is a tuple. So a large share of declared
types are un-encodable by the platform's own encoder, and the platform says so in production.

A generated `ToJson<T>` reads the *declared* type and refuses at compile time, naming the member
that has no encoding. **A runtime protocol could never do this** — that is the argument for
generation over dispatch, measured rather than asserted. The price is that the language now
carries an opinion about a wire format; the escape is bucket 3, where a different shape is a
function you write and pass.

**Only the encode direction is new.** Decoding is already built: parse to a `term`, then
`ValidateAs<T>`. The decree adds one obligation, not two.

## 5. Type variables are comparable, and bounds are refused outright

**`<` and `==` work on two values of the same bare type variable.** `Sort<T>(list<T>)`,
`Max<T>(T, T)` and `Min<T>` need nothing at all. Ticket 27 §2's opacity rule does not block this,
and the distinction is clean: opacity exists so a generic function cannot **dispatch** on its
`T` — which is what would make reachability unanswerable at the definition. Ordering is not
dispatch. It returns a bool, reveals nothing about `T`'s shape, and **cannot fail**, because the
order measured in §2 is total over every term. It is also *defined* identically at every
instantiation.

**Bounds (`where T : …`) are refused.** Not deferred, not deprioritised — they have **no
implementable meaning here**, and ticket 27's four requirements are discharged rather than
carried:

1. A bound is only worth writing if the body can **call** the bounded capability.
2. Calling a generated capability on `T` inside a generic function requires either **one copy per
   instantiation** — monomorphisation, which ticket 27 rejected because it fights ticket 13's
   aggregate granularity — or a **runtime dictionary**, which needs the nominal resolution key
   ticket 09 removed.
3. Both routes are closed, so a bound would be undischargeable: documentation with a colon in it.
4. And the capability case is already served — take it as an argument:
   `TSource Max<TSource>(TSource, TSource, fn(TSource, TSource) -> bool)`. This is ticket 27 §3's
   own third option, and the same move ticket 14 made putting the message type on the client API
   function rather than on the pid.

**This retires ticket 27's cost measurement.** 27 §3 requirement 3 made bounds conditional on
measuring constraint-solving cost at showcase clause counts, and named it "the serious one".
That measurement is now moot: the feature it gated is refused for a structural reason, so the
walking skeleton no longer owes it. **Instantiation stays matching, not solving** — the property
27 §1 accepted generics on — and it is now protected by four refusals rather than three.

## 6. Ticket 05 miscategorised extension methods — one debt, not two

**Raised by David, 2026-08-12: extension methods are for extending class types in C#, and this
is functional, so they do not really make sense here.** Correct, and it corrects a closed ticket.

Ticket 05 recorded: *"dropping extension methods **and** static abstract interface members leaves
no ad-hoc polymorphism story."* That is **one** debt written as two. C# needs extension methods
because a type's methods are sealed inside its declaration — you cannot add to `string`.
beam-sharp has no methods on types at all; every operation is already a free function taking the
value, so "extend a type you do not own" is not a feature, it is the default.

The two genuine halves of C#'s extension methods split, and **neither is ad-hoc polymorphism**:

- **Call syntax** — `xs.Where(f)` reading left to right. Ticket 05 itself already found this is a
  static rewrite `C.M(expr, args)` and *is* the pipeline, so → **[ticket 17](17-pipeline-and-comprehension.md)**,
  which has owned it all along. Nothing new is handed over.
- **Overloading** — several same-named extensions on different types, resolved by static type.
  → **[ticket 08](08-head-and-guard-syntax.md)**, already settled: one arrow per arity, union
  parameters, no overload signatures.

**Static abstract interface members were the whole of the real hole**, and §1's bucket 1 fills it.
The C#-audience framing worth putting in the spec: **a codegen obligation *is* a static abstract
interface member with the compiler writing the implementation.** `ValidateAs<T>` is `T.TryParse`
where no type had to declare it.

**One leftover that is not polymorphism**: C# lets you put your function in *someone else's
namespace* so it appears on their type without an import. That is name resolution, and it has no
beam-sharp answer yet → the map's **imports and cross-module scope** fog.

## 7. There is one dispatch mechanism — stated, not decided

The ticket demanded a story about which of two dispatch systems fires when. There is one:
**the clause head**.

- Generated capabilities do not dispatch — the type argument resolves them at compile time, and
  ticket 27 requires it to be **ground**.
- Passed capabilities do not dispatch — the caller already chose.
- Union parameters **are** clause heads.

Ticket 09's "put the name in the term" tag is likewise not a dispatch registry: it is how union
members stay **discriminable**, which 09 settled. This ticket does not promote it into a
mechanism.

## 8. Consequences forced elsewhere

- **[Ticket 05](05-csharp-functional-inventory.md)** — corrected: one debt, not two. See §6.
- **[Ticket 08](08-head-and-guard-syntax.md)** — inherits nothing new; named as the owner of the
  overloading half of §6, which it already settled.
- **[Ticket 17](17-pipeline-and-comprehension.md)** — inherits nothing new either, but the
  constraint is now explicit: whatever it picks for `.` versus `|>`, it is a **static rewrite with
  no dispatch in it**. §6 removes the temptation to read the dot as a polymorphism feature.
- **[Ticket 18](18-boundary-defence.md)** — gains a case. A generated `ToJson<T>` **trusts its
  input**: it is emitted from the declared type, so a term arriving from raw Erlang that does not
  actually inhabit `T` is encoded against the wrong shape, or crashes inside generated code the
  author never wrote. That is 18's silent-unsoundness problem at a new site, and the generated
  code is *harder* to reason about than a hand-written encoder because nobody read it.
- **[Ticket 20](20-untheorised-term-shapes.md)** — the newtype gap keeps its status. §1 does not
  supply a dispatch key, so if 20 answers with refinement types, that answer is still free to
  supply one; nothing here forecloses it. Row polymorphism remains 27's refusal, not revisited.
- **[Ticket 27](27-parametric-polymorphism.md)** — **debt discharged.** §3's deferral of capability
  constraints is answered "refused", with the reason and all four requirements addressed in §5.
- **Prelude strata fog** — `ToJson<T>` is a fifth codegen obligation, joining stratum 2. It does
  **not** settle the open criterion but it does discriminate: it satisfies ticket 27's candidate
  ("requires a ground type argument") *and* ticket 15's third candidate ("what the compiler draws
  inferences from"), while `foreign_error` still satisfies only the latter. **So 15's third
  candidate survives another test and 27's does not** — the fog patch narrows by one.
- **Imports and cross-module scope fog** — gains the name-resolution leftover from §6.
- **Walking skeleton fog** — **loses a precondition.** Ticket 27's bounded-type-variable cost
  measurement is retired by §5.

## AMENDED 2026-08-14 — one of this ticket's two reasons for refusing protocols has been invalidated

**David, stating the intent behind ticket 26**: *"Exactly records, that's why they were introduced
alongside `type` — for protocol dispatch."*

This ticket refused protocols on **two** grounds, and [ticket 26](26-data-modelling.md) removed one
of them without either ticket noticing.

| This ticket's reason | Status |
|---|---|
| Dispatch cannot key on a name that is not in the term ([09](09-union-representation.md) §5, cited here as making type classes *unresolvable*, not merely costly) | **Invalidated.** 26 §1 mints a record's discriminating tag from its qualified type name and puts it **in the term as data** — the same move this ticket credited Elixir's `__struct__` with, and 26 states beam-sharp resolves it *statically* where Elixir needs a consolidation pass. |
| Open extension needs a whole-program consolidation pass, which fights [13](13-compilation-target-decision.md)'s aggregate granularity and hot loading | **The conclusion stands; this citation does not.** Ticket 13 holds no such constraint — re-derived 2026-08-27, below. |

**So the refusal narrows from "no protocols" to "no *open* protocols".** What this ticket called
"bucket 2 with ceremony" — a capability over a set known at the definition, spelled as a union
parameter with a clause each — is not a consolation prize for a missing feature. **With 26's tag in
the term it *is* protocol dispatch**, checked exhaustive at the definition:

```csharp
module Shapes;

record Circle { Radius: float }
record Rect   { W: float, H: float }

type Shape = Circle | Rect;

float Area(Shape s);

Area(Circle c) -> 3.14159 * c.Radius * c.Radius;
Area(Rect r)   -> r.W * r.H;
```

That is a protocol in everything but the keyword, and it needs no dispatch construct because the
language's headline feature already *is* the dispatch construct. This ticket's §1 three-bucket
finding survives intact; what changes is that bucket 2 was written up as a workaround and is in fact
the answer.

**What remains genuinely refused is open extension** — a second aggregate adding `Triangle` without
editing `Shapes`. This amendment attributed that to ticket 13 and said 13 "is the ticket that would
have to give". **Ticket 13 does not contain it**; the grounds were re-derived on 2026-08-27, below.
The refusal holds. The citation did not.

**Consequence for the record**: this ticket's headline — *"the language gets no ad-hoc polymorphism
construct"* — is still true and now reads as a stronger result rather than a gap, because the
capability arrives without one. And **26 was not a data-modelling decision that happened to help
here; records were introduced for this**, which the map's entry for 26 does not say.

## AMENDED 2026-08-27 — the open-extension refusal re-derived; the ground cited above is not in ticket 13

**The defect.** The table row and the paragraph above attribute the surviving refusal to
[ticket 13](13-compilation-target-decision.md). Ticket 13 discusses unions, protocols and
whole-program compilation **nowhere**. "Aggregate granularity and hot loading" is *this ticket's*
characterisation of 13 §§2–3, written in the 2026-08-14 amendment and never checked against 13's
text. Ticket 27 carries the same defect in its monomorphisation rejection; corrected there the same
day.

**What put it to the test.** David, 2026-08-27: *"I don't need hot loading — does that change the
decision?"* Grilled to a frontier. **Answer: no design change** — open extension stays refused and
hot code loading stays exactly as 13 §3 left it. Only the reasoning is corrected.

**1. Ticket 13 §2 is not available as a ground.** The obligation is that *"the frontend must never
depend on in-process compiler state"* so that `.abstr` + `erlc +from_abstr` always works
(`13:177-179`), and its named failure mode is drift into *"parse transforms, shared PLT state and
incremental term reuse"* (`13:186-188`). A build-time pass that reads sources and emits
self-contained forms breaches none of that — and `bsc` **already** threads a `World` across the
transitive `using` closure (`bsc.erl:162-215`; `close_over/3` at `:278` pulls in modules never named
on the command line) without anyone calling that a breach. Build-time consolidation is also measured
working on this platform: `rebar_mix` consolidating 14 `Jason.Encoder` implementations
(`51:119`, 2026-08-21).

**2. Ticket 13 §3 *is* available — and hot loading is not why.** Consolidation makes aggregate A's
emitted `.beam` depend on aggregate B's *source*, because B is where the added case lives. That
breaks §3's actual claim that *"the consistency unit and the deployment unit coincide"*
(`13:304-306`): deploying B would require redeploying A. The `relup` clause is a **consequence** of
that coincidence, not the reason for it — so **this ground survives with hot code loading removed
entirely**, which is exactly why David's stated indifference to it moved nothing. The 2026-08-14 row
stated one ground as two.

**3. A stronger ground exists that this ticket never had.** `bs_api.erl:22-28`: **"A TYPE NAME DOES
NOT CROSS THE MODULE BOUNDARY."** `exports_of/1` hands a dependent the *resolved* type, not the name
the author wrote, and `import_env/3` builds no table of types at all. Module B cannot **name** module
A's union, so extension has no surface to express it. This is architectural, independent of build
topology, and post-dates this ticket (it arrived with F17). **It should lead the refusal.**

**4. The unconsolidated variant remains dead** on this ticket's own third bullet: it accepts a
runtime no-clause failure in a language whose pitch is that every case has a clause.

**5. One ground is weaker than it reads.** `research/07:927-929` — exhaustiveness needing *"the
permitted set written at the declaration, not discovered by scanning"* — is the `allows.md` argument
**plus the LDM's own counter-caution that it should be measured rather than assumed**. Cite it as
suggestive, never as load-bearing.

**This is a deferral, not a rejection, and the trigger is inherited.** Prototype 01d already named
it (`01d:129-131`): wanting the **operation** to be the unit of deployment *or* observability — and
01d rules observability out itself, since `dbg:tpl(Mod, Fun, Arity, …)` already traces a single
function without it being a module. `13:202-203` carries it forward verbatim. So:

> **Open extension becomes available if and only if the operation replaces the aggregate as the unit
> of deployment.**

Checkable, and the answer today is no.

**A coupling worth recording.** That trigger is reachable *only while hot code loading is retained*.
Drop it and deployment granularity below the aggregate has nothing left to mean — 01d's own
falsifier becomes unreachable and this deferral converts to a plain **rejection**. Three of 01d's
four grounds are independent of hot loading anyway, and 01d had already corrected the fourth down
from correctness to ergonomics itself (`01d:46-58`, *"That argument is weaker than it looks, and it
should not be used"*, because `code:atomic_load/1` exists).

**A seam this ticket does not cover.** The refusal bites at the **clause set, not the type**. Module
B can hand-spell a wider union — quoted atoms lex (`bs_lexer.xrl:161`), `kind_field_is_minted`
(`bs_check.erl:796-798`) refuses only the `record` form, and `26:229` holds that a hand-written
`type` with the same tag *is* the same type. What B cannot do is add a clause to A's function, whose
clause set lives in one aggregate's source. Filed separately; an implementer reading "no open
extension" would not predict that the type side is reachable.

## Not decided here

- The **spelling** of the universal-order escape function (§2) and of the JSON mapping's
  published rules (§4). Both are spec-drafting details with the decision above already binding.
- Whether **`ToJson<T>` ships at all** is stdlib *breadth*, which ticket 00 put out of scope.
  What is decided is the **rule** that admits it (§4) and that serialisation is the worked case
  the rule was tested against.
- Whether a user may **add** to prelude stratum 2. Unchanged and still open; §8 narrows the
  criterion question without answering it.

## Decisions entry

<!-- This ticket's entry. wayfinder/decisions.md is GENERATED from blocks like this
     one and carries only the first sentence; the whole entry is read here. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [Ad-hoc polymorphism](issues/16-ad-hoc-polymorphism.md) — **the language gets no ad-hoc
  polymorphism construct, and the hole ticket 05 flagged was half imaginary.** The three
  motivating capabilities were *measured* before being designed for and land in three different
  buckets, none of which is dispatch: a capability the type determines becomes a **codegen
  obligation**; a capability over a set known at the definition is a **union parameter** with a
  clause each; a capability over an unknown set is **passed as an argument**. Protocols died on
  ticket 13, not on taste — open extension needs whole-program consolidation, which fights
  13 §3's coincidence of consistency unit and deployment unit, *the same argument 27 used against
  monomorphisation*; **hot loading is a consequence of that coincidence, not a second ground**
  (re-derived 2026-08-27) —
  and the static-closed variant is bucket 2 with ceremony, which **corrects this ticket's earlier
  "consolidation by construction"** line. Measured: the BEAM's term order is **total across every
  type** (`1 < :ok` is `true`), so "anything comparable" needs no mechanism — but `<` is
  restricted to **same-type operands** with the universal order kept as a *named* prelude escape
  (`ordered_set`, mixed-key sorting). **`==` means `=:=`**, decided on internal agreement rather
  than familiarity: Erlang's `==` coerces through tuples, lists and map *values* then **stops at
  map keys**, while the clause head and `maps:get` do not coerce at all — so the exact spelling
  agrees with two constructs and disagrees with none. The generation rule is **the type determines
  the result, inherently or by published decree**; serialisation qualifies by decree because
  `json:encode/1` **fails on tuples at any depth, at runtime**, and tuples are this language's
  workhorse (09's newtype remedy, 15's `(:error, E)`) — generation moves that to compile time, and
  **only the encode direction is new** since decode is `ValidateAs<T>` after a parse. `<` and `==`
  work on **bare type variables** (total, non-dispatching, cannot fail), so `Sort<T>` and `Max<T>`
  are free — and **bounds are refused outright**, not deferred: both routes to discharging one are
  closed by 09 and 27, which **retires 27's cost measurement**. Finally, **ticket 05 miscategorised
  extension methods** (David) — one debt, not two; the call-syntax half was always 17's and the
  overloading half was always 08's, leaving *static abstract interface members* as the whole real
  hole, and **a codegen obligation is exactly that with the compiler writing the implementation**.
  Sharpest downstream consequence: **ticket 18 gains a consumer** — a generated encoder trusts a
  declared type the boundary does not enforce, and crashes inside code no one reviewed.
```

```decisions-entry
- **AMENDMENT 2026-08-14 to [ticket 16](issues/16-ad-hoc-polymorphism.md)** — one of its two reasons
  for refusing protocols was invalidated by ticket 26 and nobody went back. David, stating 26's
  intent: *"Exactly records, that's why they were introduced alongside `type` — for protocol
  dispatch."* 16 refused protocols because **dispatch cannot key on a name that is not in the term**
  (09 §5) *and* because open extension needs whole-program consolidation (13). **26 §1 put the name
  in the term** — a minted tag, as data — so the first reason is gone and only the second stands.
  **The refusal narrows from "no protocols" to "no *open* protocols".** What 16 wrote up as "bucket 2
  with ceremony" — a union parameter with a clause each — **is** protocol dispatch once the tag is in
  the term, checked exhaustive at the definition, and needs no construct because the language's
  headline feature already is the dispatch construct. What remains refused is a second aggregate
  adding a case without editing the first — attributed here to **13's constraint**, which
  **ticket 13 does not contain**; corrected 2026-08-27, next entry. 16's headline survives and reads stronger: the capability arrives *without* an
  ad-hoc polymorphism construct. Note for the record — **26 was not a data-modelling decision that
  happened to help here; records were introduced for this**, and 26's own entry does not say so.
```

```decisions-entry
- **AMENDMENT 2026-08-27 to [16](issues/16-ad-hoc-polymorphism.md) and
  [27](issues/27-parametric-polymorphism.md)** — both cite a constraint ticket 13 does not contain.
  Prompted by David asking whether not needing hot code loading changes the open-extension answer.
  **It does not, and the design is unchanged** — what changes is why. Ticket 13 discusses unions,
  protocols and whole-program compilation nowhere; "aggregate granularity and hot loading" was 16's
  own characterisation of 13 §§2–3, written 2026-08-14 and never checked against 13. Re-derived:
  **13 §2 is not available** — the obligation forbids *in-process compiler state* so `.abstr` +
  `erlc` always works, not a build-time pass over sources, and `bsc` already threads a `World` across
  the transitive `using` closure (`bsc.erl:278`), with `rebar_mix` consolidating 14 `Jason.Encoder`
  impls measured working on this platform (51 §119). **13 §3 is available, and hot loading is not
  why** — consolidation makes A's `.beam` depend on B's source, breaking *"the consistency unit and
  the deployment unit coincide"*, so the ground survives with hot loading removed entirely.
  **A stronger ground exists that 16 never had**: `bs_api.erl:22` — *"a type name does not cross the
  module boundary"* — so B cannot name A's union at all; architectural, and it should lead.
  research/07's "permitted set at the declaration, not by scanning" is **suggestive only** — it
  carries the LDM's own caution that it be measured. **The refusal is a deferral with an inherited,
  checkable trigger**: 01d §129-131 and `13:202` — *open extension becomes available iff the
  operation replaces the aggregate as the unit of deployment*; 01d rules observability out itself
  (`dbg:tpl` traces a function). Note the coupling — that trigger is reachable **only while hot
  loading is retained**; drop it and the deferral becomes a plain rejection. 27 survives intact,
  losing one leg of one sub-argument to the same miscitation and keeping it on a fact its prose never
  stated: knowing every module in the `using` closure is not knowing every instantiation.
```
