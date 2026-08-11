# 09 — Union representation: nominal-closed or structural-open?

Type: grilling
Status: open
Blocked by: 04, 07

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

## Prior art to consult first (from ticket 03)

**purerl's `Erl.Untagged.Union` rejects at compile time any union whose members cannot be
discriminated at runtime.** This is the mechanism that makes structural unions safe on an
untagged runtime, and it is a direct precedent for the structural side of this decision — a
structural union of two shapes that erase to the same BEAM term is not checkable, and the
compiler can say so up front rather than failing at a match site. Read it before deciding.

## Notes

HITL. Probably the sharpest design tension in the map: the headline feature pulls
structural, the syntax goal pulls nominal. Surfaced during charting.
