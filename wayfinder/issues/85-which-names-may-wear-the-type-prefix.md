# 85 — Which names may wear the type prefix, now that a part may?

Type: grilling
Status: open — [ENG-395](https://linear.app/davewil/issue/ENG-395). Raised 2026-09-19 by the F53 build
([ENG-394](https://linear.app/davewil/issue/ENG-394)), which
[ticket 84](84-dispatching-the-parts-of-a-numeric-union.md) instructed to raise rather than
decide
Blocked by: —

## Why this is raised

[Ticket 84](84-dispatching-the-parts-of-a-numeric-union.md) decided the type prefix over a
**part** — `Post(float a)` — and named two things it would not decide: whether a **refinement**
may wear the prefix, and what `term x` means. F53 shipped the form and both are still open, but
the build changed the shape of the first one, which is why this is a ticket and not a footnote.

**The refinement question cannot currently be spelled.** A refinement is a *named* type and type
names are PascalCase:

```csharp
type Meters = int where value >= 0
```

so `Far(Meters m)` is a `uident` prefix and goes down [ticket 55](55-destructure-and-bind.md)'s
**record** path, where only a minted tag is accepted. Measured at F53's build:

```
error: Meters is not a record, so it cannot name a pattern
  only a `record` declaration mints the tag a type prefix matches on.
  a part is named by the part: `Post(int n)` beside `Post(float f)`,
  one clause each.
  to constrain fields without naming a type, write `{ Field: ... }`.
```

The part prefix F53 added is **lowercase-only** and reaches no named type at all. So the language
did not widen toward refinements by accident, and the question is not "should the rule admit
`Meters`" — the rule already would, since `is_integer(M) andalso M >= 0` is one test and
[ticket 46](46-refined-parameter-at-the-boundary.md) already emits exactly that guard at a
boundary. The question is whether the **name** may wear the prefix, which is one question about
three kinds of name at once.

## Q1 — May a named type wear the type prefix, and which names?

Three kinds of name, one grammar position. Each compiles or is refused under a different answer,
and the third is the one that decides whether this is one question or two:

```csharp
// (a) an alias to a part union — what an author writes once the parts are named
type Amount = int | float

public Side Post(Amount a)
```

```csharp
// (b) a refinement — one test, and ticket 46 already emits it
type Meters = int where value >= 0

public int Far(Meters | float d)

Far(Meters m) -> m
Far(float f)  -> 0
```

```csharp
// (c) a union of records — ticket 66's question, ASKED THERE AND NOT RE-ASKED HERE
type C = A | B

public atom Handle(C c)
```

(c) is [ticket 66](66-a-union-name-in-pattern-position.md) ([ENG-309](https://linear.app/davewil/issue/ENG-309)),
open since 2026-09-02 and unchanged by F53 except in the wording of the diagnostic quoted in its
exemplar 3, which gained a line. This ticket does not re-ask it; if the answer here is a rule
about names in general, 66 is inside that rule and should be resolved with it.

What bears on the answer and does not settle it:

- **Naming is aliasing** ([ticket 09](09-union-representation.md) §1). If `Amount` is the same
  thing as `int | float`, then `Post(Amount a)` is asking the prefix to match a whole union,
  which no single test decides — so (a) is refused under the criterion already shipped, and it
  is refused for a reason, not because it is a name.
- **A refinement is decided by one test**, so (b) is admitted by the letter of ticket 84's rule.
  What ticket 84 flagged is that admitting it makes refinements *dispatchable in a clause head*,
  which is a widening nobody asked for: a refined parameter's test is
  [ticket 46](46-refined-parameter-at-the-boundary.md)'s boundary obligation today, emitted at
  one site, and a prefix would make it a dispatch an author writes anywhere.
- **The part prefix's refusal already tells the author what to write**, so the cost of leaving
  every name refused is one line of diagnostic, not a form nobody can express. That is the cheap
  answer and it may be the right one.

## Q2 — What is `term x`?

`term` spans every part, so the prefix would test nothing. F53 refuses it, with the sentence it
uses for every type that spans more than one part:

```
error: `term` cannot name a pattern
  `term` spans more than one part and a prefix tests one:
  name a part, in a clause of its own.
```

That is a refusal by side effect of the criterion rather than a decision. The two candidates:

- a **legal no-op**, binding the value and testing nothing, which is what a bare `x` already
  does — so it would be a second spelling for an existing pattern, and the language has refused
  those before ([ticket 45](45-match-token.md) kept `=` out of pattern position for less).
- a **refused vacuity**, which is what ships today, and whose only cost is that an author who
  writes it gets a sentence that is true but slightly beside the point.

Nothing in the corpus, `LANGUAGE.md` or `TOUR.md` writes it.

<!-- Round 1, asked 2026-09-19. -->

## Not decided here

- **A union of records in pattern position** — [ticket 66](66-a-union-name-in-pattern-position.md),
  open and asked there.
- **What a refined parameter's test is for**, which
  [ticket 46](46-refined-parameter-at-the-boundary.md) settled at the boundary: this ticket asks
  only whether a refinement's NAME may sit in the prefix position the part now occupies.
- **Whether a float may be refined**, which
  [ticket 58](58-refined-int-admits-a-float.md) is the neighbourhood of and which nothing here
  moves.
