# 07 — C# 15 `union` and TypeScript discriminated unions

Type: research
Status: open

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

## Notes

AFK. Feeds ticket 09 directly. Added during charting after the C# 15 union feature turned
out to be much further along than assumed.
