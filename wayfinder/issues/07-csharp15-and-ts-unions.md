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
[#9662](https://github.com/dotnet/csharplang/issues/9662), not #8928; `union` is a **preview**
feature needing `<LangVersion>preview</LangVersion>` (Roslyn still lists it *In Progress*), not
shipped; and no primary source supports "GA November 2026". The design is live — pattern
targeting changed semantics in Preview 7 and the LDM revisits it again on 12 Aug 2026.

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

**For ticket 09**: the corpus contains a two-sentence, never-developed hybrid —
`role NamedAOrB : (A | B);`, a name over a structural union with equivalency to the underlying
type — which is the shape ticket 09 names as a legitimate answer.

## Notes

AFK. Feeds ticket 09 directly. Added during charting after the C# 15 union feature turned
out to be much further along than assumed.
