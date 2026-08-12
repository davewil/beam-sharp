# 26 — Data modelling: records, and what named types erase to

Type: grilling
Status: open
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
