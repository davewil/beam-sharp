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
- **A nominal closed model needs a wrapping layer at every interop boundary**, converting
  raw terms into declared cases and back — cost paid on every call in and out.
- **But nominal-closed is what the C# audience is about to learn**, and closed sets are what
  make C#'s exhaustive `switch` with no `default` arm work.
- **Set-theoretic types, already committed to in ticket 00, are the structural family.**
  Choosing nominal would mean the type system and the union surface disagree about what a
  type is.

Decide, and state explicitly what the losing side costs. A hybrid — structural underneath,
with optional nominal declarations as a convenience — is a legitimate answer but must be
specified precisely enough that exhaustiveness checking still has one story, not two.

## Notes

HITL. Probably the sharpest design tension in the map: the headline feature pulls
structural, the syntax goal pulls nominal. Surfaced during charting.
