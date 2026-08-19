# Audition packet — the exhaustiveness checker

You are implementing one piece of a programming language toolchain FROM ITS
SPECIFICATION ALONE. This is a clean-room exercise: a reference implementation
exists, and you must not look at it.

## Hard rules

- **Do not read, search for, or open any file outside this packet directory.**
  A reference implementation of this language exists elsewhere on this machine,
  as does a directory of design notes. Both are off limits. If you find
  yourself looking for either, stop.
- Do not modify anything under `cases/`.
- Work only inside your own working directory.
- Work autonomously. There is nobody to answer questions.

## What you are building

A command-line program that decides whether a `switch` is well-formed and
reports the problems it finds.

Deliverable: an executable file named `switchcheck` in your working directory:

    ./switchcheck <path-to-.bs-file>

Any language available on the machine is fine, provided `./switchcheck` runs
directly via a shebang. No network access, no package installs.

## Output contract

For the file it is given, `switchcheck` prints **one lowercase tag per line** on
stdout and nothing else — no prose, no filenames, no line numbers. A well-formed
program prints **nothing at all**.

These are the only tags you may print:

    switch_inexhaustive
    unreachable_arm
    rebinding
    return_not_declared

**What each of those means is for you to determine from the specification
below.** The names are listed so that your output can be compared
mechanically — they are a vocabulary, not a definition of the rules.

Exit code is ignored. Order does not matter and duplicates are ignored; only
the set of tags is compared.

## How you are marked

Your `switchcheck` is run over the files in `cases/` and the tags it prints are
compared against the tags the reference compiler produces for the same file.
**Every case must match exactly.**

Some of the files are well-formed and must produce no output at all. Printing a
diagnostic for a correct program fails exactly as hard as missing one, so do not
guess defensively: a checker that reports a problem whenever it is unsure fails
on the first case. Test against `cases/` before you finish.

## The specification

What follows is the relevant part of the language reference, verbatim. It is all
you get, and it is meant to be enough. Where it is not enough, prefer the
reading the text best supports rather than inventing a rule.

---

## 2. Multi-clause heads

The one structural move the language rests on: C#'s pattern grammar moves out of `switch` arms and
into the **parameter position**, and N declarations are allowed where C# allows one.

<!-- check:
type Verdict = :positive | :zero | :negative | :unknown
-->
```csharp
type Reading = (:ok, int) | (:error, atom)

public Verdict Classify(Reading r)

Classify((:ok, n)) when n > 0 -> :positive
Classify((:ok, 0))            -> :zero
Classify((:ok, n))            -> :negative
Classify((:error, e))         -> :unknown
```

Five clauses in, five native Erlang clause heads out. **shipped**

**The signature is mandatory.** Exhaustiveness is only a well-posed question against a *declared*
input type — a language that infers the function type from its own clauses can never ask it,
because the answer is always yes. **shipped**

**Guards** use `when`, with `and` and `or`. A guard the checker can read as a type operation
refines the clause; one it cannot read credits nothing. **shipped**

```csharp
Classify(n) when n < 10              -> :low
Classify(n) when n >= 10 and n < 100 -> :mid
Classify(n) when n >= 100            -> :high
```

That is exhaustive over `int`, with no catch-all, because the checker carries real integer
intervals.

**One spelling, in every position** — guard, pattern and refinement predicate. There is no `&&` and
no `||`; they were removed rather than kept as synonyms. This language puts patterns in the
*parameter* position, so a pattern and a guard sit on the same line in every non-trivial function.
C# separates its pattern `and` from its expression `&&` deliberately, and can afford to because
patterns and expressions rarely touch there; here they always do.

**A span of integers is a relational pattern.** `4..7` was refused: C#'s `..` builds a half-open
slice over *indices*, is not enumerable, and in pattern position already means "the rest" — which
this language uses for lists. **shipped**

<!-- check:
public atom Classify(int n)
-->
```csharp
Classify(>= 4 and <= 7) -> :reserved
Classify(<= -1)         -> :negative
Classify(>= 0 and <= 3) -> :low
Classify(>= 8)          -> :high
```

Those four clauses are **exhaustive over `int`** with no catch-all, which is the property worth
looking at: a span is a set the checker subtracts, not a test it takes on trust. It goes where a
whole argument goes — inside a record pattern, a tuple or a list, write the comparison as a guard.

The rule this produced, which governs future borrowings: **borrow the construct, or don't borrow
the glyph.** Where C# has the symbol but not the construct, taking the symbol buys no familiarity
and costs a false friend.

**To match against a value a name already holds, write `== name`.** A bare name in a pattern
introduces a name; `== name` matches the value that name is bound to. **shipped**

So a head that repeats a bare name — `F(acc, acc)` — is an **error**, not an equality constraint:
both are introductions, and the second rebinds what the first bound, which §1 forbids. `F(acc, ==
acc)` is how you ask for the constraint. This is the whole reason the marker exists; without it the
language has no way to say *the same value again*.

```csharp
public int RunLength(int head, list<int> xs)

RunLength(head, [])                -> 0
RunLength(head, [== head, ..rest]) -> 1 + RunLength(head, rest)
RunLength(head, [_, ..rest])       -> 0
```

It is the **equality member of the relational family above**, so a reader who has met `>= 4` in a
head reads `== acc` on sight. The family divides cleanly — **relational operators take a literal,
`==` takes a name** — so `>= acc` is not a span bounded by a runtime value, and `== 4` is not a
second spelling for the literal pattern `4`. Neither is admitted.

The space is not significant: `==acc` and `== acc` are one program. Written with the space, to match
`>= 4`.

This is the one capability with no C# equivalent at all — C# patterns cannot match a runtime value,
and push you to `when v == expected`. Here that workaround is worse than it looks, because it moves
a pattern concern into a guard, and the checker reads `var == literal` but not `var == var`: the
guard would credit nothing and the arm would subtract nothing from the residual. **A matched name
credits nothing to the certain set either.** Its value is unknown at compile time, so it may narrow
what is *possible* and never counts as coverage — a `switch` whose only non-catch-all arm matches a
name is inexhaustive over the whole subject type.

---

---

## 3. Exhaustiveness

**A function that does not cover its declared input does not compile.** No opt-out, no flag. The
**residual is the missing case**, which is why the diagnostic below hands you a clause to paste
rather than a complaint to interpret.

```
readings.bs:4: error: Classify is not exhaustive
  no clause matches:
    Classify((:ok, int <= 0)) -> ...
```

The error is the **missing clause**, not a complaint — the residual is computed exactly and printed
as a head you can paste in. Where it is wide, the **printed** form stops after three cases and says
how many it left; the residual itself is never summarised, and the full one is a query away.
**shipped**, and the truncation **decided**

A **catch-all is legal only where the residual is open** — over a `term`, or any type with an
unbounded part. Where the compiler knows the remaining case names, `_` is an error: it would put
the language's headline guarantee one character from being switched off invisibly. **decided**

---

---

## 5. Control flow

**`switch` is the only branching construct.** There is no `if`, no `else`, no ternary.
<!-- decided by ticket 17, which also settled `|>` and `|?>` -->

<!-- check:
type Verdict = :new | :gone | :unknown
record Order { Id: int, Status: atom }
-->
```csharp
public Verdict Describe(Order o)

Describe(o) -> o.Status switch {
    :placed  => :new,
    :shipped => :gone,
    _        => :unknown
}
```

The `_` here is legal because `Status` is an `atom` and the atom universe is open, so the residual
cannot be enumerated — which is the only shape a catch-all is admitted over. Over a *closed*
residual, where the compiler knows the missing case by name, §2 makes `_` an error telling you to
name it. **That rule is decided and is not yet enforced**, at a switch arm or at a clause head.

For compound conditions, the subject is a **tuple** — which is the clause head's own shape, one
level down:

<!-- check:
type Disposition = :ack | :dead_letter | :requeue
-->
```csharp
public Disposition Decide(bool ok, bool permanent, bool redelivered)

Decide(o, p, r) -> (o, p, r) switch {
    (true,  _,     _)     => :ack,
    (false, true,  _)     => :dead_letter,
    (false, false, false) => :requeue,
    (false, false, true)  => :requeue
}
```

Exhaustive with **no catch-all**, and the compiler agrees. An arm may also carry a guard —
`n when n < 5 => :retried` — or a relational pattern, `>= 5 => :exhausted`, since an arm takes the
clause head's pattern grammar whole. Nested inside a record pattern, `{ Deliveries: > 5 }` is not
built: a relational pattern goes where a whole argument goes.

**shipped** — F7.

`else` is absent because it is what a *binary unnamed* conditional needs; every fall-through here is
a pattern. `cond` is **open** — deliberately unpaid-for until the shape is shown to occur. Measured
so far: a four-wide tuple reads fine.

---
