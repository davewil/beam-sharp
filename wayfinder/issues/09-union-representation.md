# 09 — Union representation: nominal-closed or structural-open?

Type: grilling
Status: resolved
Blocked by: 04, 07

## Answer — structural and open; naming is aliasing

**Unions are structural and open. There is no nominal union type in beam-sharp, and no union
declaration form.**

The fork the ticket was built on did not survive contact with the closed tickets, and was
closed at the top of the session rather than re-argued. Four findings already in the map all
point the same way, and the decisive one is ticket 01's: rewriting the transition table
produced `{ Status: not :shipped }` — **negation in pattern position**, which a nominal model
can express only by enumerating every constructor but one, or by a catch-all, and the
catch-all is precisely what destroys the exhaustiveness guarantee ticket 00 committed to.
Ticket 07 removed a *cost* from the nominal side; it gave it no *capability*.

### 1. Naming is aliasing

`type X = ...` introduces a name **equivalent to its right-hand side**. The name is a display
and diagnostic device and never participates in the type algebra. Two names over the same set
are the same type.

```
type PaymentResult = { :ok, string } | { :error, string };

// identical to writing the union inline — same arrow, same check
Handle(PaymentResult r) -> ...
Handle({ :ok, string } | { :error, string } r) -> ...

// negation still works against the name, because the name IS the set
Retry(PaymentResult and not { :ok, _ } r) -> ...
```

The prior art is the `role NamedAOrB : (A | B);` sketch from the C# discriminated-unions
working group (ticket 07 §2.7) — a name over a structural union with equivalency to the
underlying type. Two sentences in a 2022 minute, never developed because C# roles were
shelved. It is a precedent that the shape occurred to competent language designers, not a
design that was adopted from anywhere.

**The compiler still knows the alias even though the algebra does not**, so diagnostics print
the name. This is what makes the decision cost-free for readability: `missing case:
PaymentResult.Timeout` rather than a wall of shapes. Ticket 04's finding that the
exhaustiveness residual *is* the missing case depends on this, since the residual is consumed
by an agent in a loop.

### 2. One construct, not two

`type` names records, tuples and scalars as well; a union is simply one thing that can appear
on the right-hand side.

```
type OrderId = string;
type Point   = { X: float, Y: float };
type Distance = { :meters, float } | { :feet, float };
```

**So the language has no syntax that declares a union — only syntax that names a type.** That
is the decision restated as grammar, and it removes the possibility of two exhaustiveness
stories by construction rather than by rule.

**On the spelling.** `union` was rejected on the borrow heuristic's own terms: C#'s `union`
has the wrong *semantics* — nominal, closed, load-bearing — and borrowing the spelling would
promise closedness to exactly the audience primed by C# 15 to expect it. Tier 1 of the
heuristic is satisfied twice over by constructs that *do* match: C#'s `using X = Y;` and
TypeScript's `type X = A | B` are both non-load-bearing aliases creating no new type
identity. `type` wins between them on read cost — `using` will be wanted for imports (C#'s own
double duty), and burying domain declarations in the block a reviewer scans as dependencies is
a defect that carries full weight under the standing constraint, while a TS reader parses
`using` as an import outright. Nothing in C# collides with `type`, so it teaches rather than
misleads.

### 3. Recursion is equirecursive, and definitions must be contractive

The one case where an alias cannot be substituted away: expansion never terminates.

```
type Json = null | bool | float | string
          | list<Json>
          | map<string, Json>;

type X = X | int;   // ✗ rejected: not contractive
```

A recursive name is a **μ-binder**. A type and its unfolding are **identical**, with equality
and subtyping decided **coinductively** — `Json` requires no fold, unfold or conversion
anywhere. Isorecursive was rejected because it makes the name a real boundary, which is the
load-bearing name §1 rejects, and because that boundary would be unenforceable against a raw
Erlang caller for the same reason nominal identity is (§5).

**Well-formedness rule**: recursion must pass through a type constructor. Degenerate cycles are
rejected at the declaration.

This is the paved path of the theory ticket 00 already committed to — semantic subtyping is
*defined* over regular recursive types, and CDuce decides them. The cost is a checker carrying
a memo table of in-progress subtyping goals, which is where the checker gets slower. That cost
lands on ticket 11 and on the walking skeleton's measurement job, which ticket 04 already
flagged: Etylizer's pathological inputs are matches with 40+ branches, precisely what this
language advertises.

### 4. Indiscriminable unions are rejected where they are written

The obligation purerl's `Erl.Untagged.Union` puts on any structural union over an untagged
runtime (ticket 03 called it the most advanced worked solution in this space). **Two phenomena
get called ambiguity and only one is a defect:**

- **Overlap** — `list<int> | list<string>` share the value `[]`. Set-theoretically correct;
  both members genuinely contain it, and clause order decides which fires. This is ticket 04's
  redundancy question, **not an error.**
- **Indiscriminability** — `fun<int> | fun<string>` gives the runtime nothing to test, since
  `is_function(F, 1)` is all that can be asked. No clause ordering helps, because there is no
  test to run. **This is an error.**

Two rules make it precise:

- **Normalise first, then check pairwise on the normalised members.** `:ok | atom` *is* `atom`
   — the subset is absorbed by the algebra before discriminability is ever asked, which
  removes a whole class of false positives.
- **A member is discriminable iff the compiler can synthesise a BEAM guard expression that
  decides it** — `is_integer`, `is_binary`, `is_atom`, `is_tuple` plus arity,
  `binary_to_existing_atom` for literal atoms. That is what purerl builds, and it is the same
  guard vocabulary ticket 08 already committed to. No new mechanism, and the rule gets a
  precise boundary instead of a judgement call.

```
type Handler = fun<int> | fun<string>;
// ✗ error at the declaration: members not discriminable
//   is_function/2 cannot distinguish return types
//   hint: tag them

type Handler = { :int_handler, fun<int> } | { :string_handler, fun<string> };   // ✓
type Xs      = list<int> | list<string>;   // ✓ overlap at [], not a defect
```

**Rejected at the declaration, not at the match site**, so the diagnostic lands where the fix
is — an error surfacing three modules later, in a different agent session, is the expensive
kind. The cost is honest: this forbids a union that is only ever *passed through* and never
matched, which would otherwise be a working program. The workaround is a tuple tag, which is
free, idiomatic and better to read. An opt-out marker was considered and rejected — ticket 21
established that escape hatches are the hard thing to keep sound, and this one would buy a rare
case that already has a free remedy.

**It is an error, never a warning.** Ticket 03 found Caramel let Warning 8 through into shipped
output; ticket 12 exists partly because of it.

### 5. What the losing side costs

**No newtypes.** `Meters` and `Feet` over `float` are one type; `OrderId` and `CustomerId` over
`string` are one type. A reader cannot use the name alone to infer intent, and the compiler
will not catch passing one where the other is meant.

The remedy is the BEAM's free structural tag — `{ :meters, float }` and `{ :feet, float }` are
genuinely distinct *sets*, so the distinction is bought back with a tuple rather than with type
identity. That is tier 2 of the borrow heuristic, it is idiomatic Erlang, and the tag is
usually what the reader wanted anyway. **Refinement types are the other possible answer and
belong to ticket 20.**

Everything else the nominal side offered turned out to be either unavailable here or already
free:

- **Nominal identity is unenforceable across the Erlang boundary.** Nominality means
  "constructed as a `PaymentResult`", and the BEAM has no construction discipline — `erl` hands
  you whatever term it likes, and ticket 06 established an untyped caller does **not** reliably
  crash. A nominal union would be compile-time-true and runtime-false, reintroducing ticket
  06's third outcome — *silent unsoundness* — by design. Either you pay for a runtime witness
  (the wrapper ticket 07 §2.9 established nothing forces here) or the nominality is a lie the
  moment a term arrives from outside.
- **Union closure and negation are lost outright under a load-bearing name.** Nested named
  unions do not merge — C#'s "an `Animal` is never directly a `Cat`, but it might be a `Pet`
  that is a `Cat`" is a direct consequence — and `not PaymentResult.Ok` needs hand enumeration.
  The language's own showcase pattern would not work against its own declaration form.
- **Two cases with the same payload need a tag**, the one C# finding that transfers — and the
  leading atom in a tuple already is one.

### 6. This answers ticket 07 §5.0

The question that file left open was: **can nominality be compile-time-only on a BEAM target?**

**Yes — and it buys nothing.** Erased nominality *is* an alias, which is what §1 chose. The
premise that a nominal model needs a wrapping layer at every interop boundary was indeed a CLR
artefact rather than a property of nominality, exactly as §5.0 suspected. But removing that
cost did not rescue the nominal side, because the cost was never the argument that mattered —
the capability gap was. Ticket 09's original framing ("nominal costs a wrapping layer,
structural does not") does dissolve; the decision does not change, and the reason it does not
change is worth more than the dissolved premise.

**~~The premise struck through in the Question below is therefore retired, not resolved in
nominal's favour.~~**

### 7. Consequences for other tickets

- **[Ticket 11](11-type-system-shape.md)** inherits equirecursive types, coinductive subtyping
  with a memo table, and the contractiveness rule — with the checker cost that goes with them.
  It also inherits `type` as the single naming construct.
- **[Ticket 16](16-ad-hoc-polymorphism.md)** gets a sharp new constraint: **with no nominal
  identity, dispatch cannot key on a name.** Typeclass- and interface-style resolution as C#,
  Rust and PureScript know it is unavailable; dispatch must key on structure. This is the
  central constraint on that ticket now, and it should not be discovered late.
- **[Ticket 18](18-boundary-defence.md)**: the discriminator synthesiser of §4 **is** the
  emitted-check machinery ticket 21 concluded was the only mechanism reaching all eight
  violation channels. Same mechanism, two uses — do not build it twice, and note that §4 gives
  it a precise vocabulary (BEAM guards) it did not have before.
- **[Ticket 20](20-untheorised-term-shapes.md)**: the newtype gap is now explicit and named.
  Tags cover it today; refinement types are the alternative and belong there.
- **[Ticket 04](04-crossclause-exhaustiveness.md)** is confirmed rather than changed. It bound
  exhaustiveness to a *declared input type*, and ticket 08 settled that same-arity dispatch is
  a union parameter — so **the function signature is the declaration site for the permitted
  set**. That answers ticket 07 §5.1(5)'s warning (the permitted set must be written at the
  declaration, not discovered by scanning) without named unions needing to do that job.

## Question

Are unions **nominal and closed** like C# 15's `union` — declared up front with a fixed set
of case types — or **structural and open** like TypeScript's and set-theoretic types
generally, formed ad hoc from any types and closed under union, intersection and negation?

The tension, stated plainly:

- **The BEAM is structural.** Erlang values carry no nominal identity. You match `{ok, X}`
  against a raw tuple; `:error` is an atom belonging to no declared type; any function may
  return a shape nobody declared. A structural model describes what is already there.
- ~~**A nominal closed model needs a wrapping layer at every interop boundary**, converting
  raw terms into declared cases and back — cost paid on every call in and out.~~
  **This premise is contested — see §5.0 of the ticket 07 research file.** The evidence
  suggests the wrapper is a **CLR constraint, not a property of nominality**. C#'s rejected
  runtime-union design was *named yet wrapper-free* ("represented at runtime as a simple
  object reference"); it lost on back-compat, CLR change cost and timelines, not on
  nominality. So **compile-time-only nominality at zero boundary cost may be available on the
  BEAM**, which would partly dissolve the tension this ticket is built on. Establish whether
  it is actually available before treating nominal-versus-structural as a real fork.
- **But nominal-closed is what the C# audience is about to learn**, and closed sets are what
  make C#'s exhaustive `switch` with no `default` arm work.
- **Set-theoretic types, already committed to in ticket 00, are the structural family.**
  Choosing nominal would mean the type system and the union surface disagree about what a
  type is.

Decide, and state explicitly what the losing side costs. A hybrid — structural underneath,
with optional nominal declarations as a convenience — is a legitimate answer but must be
specified precisely enough that exhaustiveness checking still has one story, not two.

## Reframing from ticket 07 — read before deciding

**The question is probably not "do we follow C#?" but "we can have what C# wanted and
couldn't."** C# considered two structural, TypeScript-shaped union designs — runtime type
unions (anonymous `(int or string)`, erased to an object reference) and ad-hoc erased unions
(order-insensitive, structural) — and killed both on **CLR artefacts**: reified generic type
arguments make `o is T` lie, and nominal identity makes a non-erased wrapper order-sensitive.
**Neither constraint exists on the BEAM.** The rejected designs deserve more weight here than
the chosen one.

Two further facts that bear on this decision:

- **C# unions are preview, not shipped**, and the design is live. They first appeared in .NET 11
  Preview 5 (9 June 2026), gated on `LangVersion=preview`, with Roslyn's feature-status table
  still listing them *In Progress*. Preview 7 changed pattern-matching semantics to Try-Both,
  and the LDM agenda schedules "Revisit Union Pattern Matching after issues with 'try-both'"
  for 12 August 2026. Committing to match C#'s surface means committing to a moving target.
  (Note: .NET 11 GA is 10 November 2026 — nothing commits *unions* to that date.)
  Their exhaustiveness check also only suppresses a *warning*, is module-bounded, and is
  unsettled for switch statements and `void` methods — so it is a weaker guarantee than this
  language has already committed to.
- **A hybrid already exists in the corpus, undeveloped**: `role NamedAOrB : (A | B);` — a name
  over a structural union, equivalent to the underlying type. That is the shape this ticket
  names as a legitimate answer, sketched and abandoned by someone at Microsoft. Worth reading
  before reinventing it.

The one C# finding that transfers cleanly: **two cases with the same payload need a tag**, and
the BEAM provides tagged tuples for free.

## Evidence from ticket 01's prototype

Rewriting a nine-clause transition table with its conditions as patterns rather than guards
produced `{ Status: not :shipped }` — **a negation type in pattern position**. It is checkable
only because set-theoretic types are closed under negation by construction.

Neither candidate on the nominal side can express it. A nominal ADT gives you constructors, so
"every constructor but one" must be enumerated by hand or fall to a catch-all — and a catch-all
is precisely what destroys the exhaustiveness guarantee. C# 15's closed unions are in the same
position.

This is **direct evidence for the structural side of this decision**, and it is stronger than the
interop argument the ticket was originally built on, because it bears on how much of an ordinary
program the compiler can check rather than on boundary cost. Weigh it against the ticket 07
finding that nominality may be available at zero boundary cost — that finding removes a cost of
nominal, but it does not give nominal negation.

## Prior art to consult first (from ticket 03)

**purerl's `Erl.Untagged.Union` rejects at compile time any union whose members cannot be
discriminated at runtime.** This is the mechanism that makes structural unions safe on an
untagged runtime, and it is a direct precedent for the structural side of this decision — a
structural union of two shapes that erase to the same BEAM term is not checkable, and the
compiler can say so up front rather than failing at a match site. Read it before deciding.

## Notes

HITL. Probably the sharpest design tension in the map: the headline feature pulls
structural, the syntax goal pulls nominal. Surfaced during charting.
