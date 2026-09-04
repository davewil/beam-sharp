# 07 — C# 15 `union` and TypeScript discriminated unions

Type: research
Status: resolved

## Question

Document the syntax, semantics and exhaustiveness rules of the two mainstream union models
this language must choose between or reconcile.

**C# 15 unions** — [csharplang #8928](https://github.com/dotnet/csharplang/issues/8928),
shipping in .NET 11, first preview April 2026, GA expected November 2026:

- Exact declaration syntax and how case types are composed (C# composes existing standalone
  types — classes, structs, records, primitives — rather than using F#-style tag unions).
- Nominal vs structural, open vs closed; whether a union can be formed ad hoc.
- How exhaustiveness is checked when switching, and the rules for omitting `default`.
- Runtime representation, and what it costs.
- The [csharplang working-group union-proposals-overview](https://github.com/dotnet/csharplang/blob/main/meetings/working-groups/discriminated-unions/union-proposals-overview.md)
  — **which alternatives were considered and rejected, and on what grounds**. The rejected
  designs may suit a BEAM target better than the chosen one.

**TypeScript discriminated unions**:

- How unions are formed structurally without declaration, and how discriminant properties
  work.
- Narrowing rules, and how exhaustiveness is achieved (the `never` idiom) rather than
  enforced.
- What breaks at the boundary with code that does not know about the union.

Then state plainly, for each: **how far each model is from set-theoretic types**, which are
structural, open, and closed under union, intersection and negation.

Write findings to `wayfinder/research/07-csharp15-and-ts-unions.md` and link here.

## Answer

Findings: [`wayfinder/research/07-csharp15-and-ts-unions.md`](../research/07-csharp15-and-ts-unions.md).

**Three premises in this ticket were wrong.** The champion issue is now
[#9662](https://github.com/dotnet/csharplang/issues/9662), not #8928. `union` first appeared in
**.NET 11 Preview 5 (9 Jun 2026)**, not April, and is `<LangVersion>preview</LangVersion>`-gated
— Roslyn still lists it *In Progress*. And "GA November 2026" is the right date for the wrong
thing: **10 Nov 2026 is .NET 11's GA**, documented; nothing commits *unions* to it. The design is
live — pattern targeting changed semantics in Preview 7 (released today) and the LDM revisits it
tomorrow, 12 Aug 2026.

**C# unions** compose existing standalone types into a **nominal, closed struct wrapper** —
`union Pet(Cat, Dog)` lowers to `[Union] struct Pet : IUnion` with one `object? Value` field, so
value-type cases box. No `is-a`, no ad-hoc formation, no merging of nested unions, no
intersection, no negation. Exhaustiveness is a real compiler check but only suppresses a
*warning*, is bounded by the module, and is unsettled for switch statements and `void` methods.

**The rejected designs matter more than the chosen one.** Runtime type unions (anonymous
`(int or string)`, erased to an object reference, VM-aware) and ad-hoc erased unions
(order-insensitive, structural, TypeScript-shaped) were both killed on **CLR artefacts** —
reified generic type arguments making `o is T` lie, and nominal identity making a non-erased
wrapper order-sensitive. **Neither rock exists on the BEAM.** The one finding that does
transfer: two cases with the same payload need a tag, and the BEAM already has one for free.

**TypeScript** is structural, open and ad-hoc but stops short of set-theoretic in three places:
intersections are syntactic (`{a:string}&{a:number}` is uninhabited yet is not `never`), there
is no negation (proposal open 11 years, team PR closed unmerged), and exhaustiveness is an
opt-in `never` idiom — a missing case in a `void` switch compiles clean under every
configuration TypeScript offers.

**For ticket 09**, one premise deserves grilling before it is relied on. The ticket assumes a
nominal closed model *needs* a wrapping layer at every interop boundary. In C# the wrapper is
there because the CLR needed a runtime witness and Microsoft refused to change the runtime — the
rejected runtime-union design was **named yet wrapper-free**, "represented at runtime as a simple
object reference". If neither rock that forced C# to a wrapper exists on the BEAM, it is not
obvious what would force one there, and compile-time-only nominality may be available at zero
boundary cost. That would partly dissolve the tension the ticket is built on. The corpus also
contains a two-sentence, never-developed hybrid — `role NamedAOrB : (A | B);`, a name over a
structural union with equivalency to the underlying type — matching the shape ticket 09 names as
a legitimate answer, though it supplies no semantics or exhaustiveness story.

## Notes

AFK. Feeds ticket 09 directly. Added during charting after the C# 15 union feature turned
out to be much further along than assumed.

## Decisions entry

<!-- The body of this ticket's entry in wayfinder/decisions.md, which is GENERATED
     from blocks like this one. Edit it here and run `bin/gen-decisions.py --write`;
     editing decisions.md directly is what bin/check-decisions-derived.sh refuses.
     The `issues/…` link is relative to decisions.md, so it is fenced rather than
     live — from inside issues/ it would point at nothing. -->

```decisions-entry
- [C# 15 `union` and TypeScript discriminated unions](issues/07-csharp15-and-ts-unions.md)
  — C# unions are **preview, not shipped**, and the design is still moving (champion issue is
  #9662, not #8928; no primary source for "GA Nov 2026"). They are nominal, closed struct
  wrappers; exhaustiveness only suppresses a *warning*. **The rejected designs matter more**:
  C# killed both structural/erased union designs on CLR artefacts — reified generics and
  nominal identity — **and neither rock exists on the BEAM**. TypeScript is structural but
  stops short of set-theoretic (syntactic intersections, no negation, opt-in exhaustiveness).
```
