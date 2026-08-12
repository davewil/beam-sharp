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
