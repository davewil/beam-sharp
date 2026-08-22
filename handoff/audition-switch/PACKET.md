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

**A list pattern is a prefix, and a rest marker is optional.** `[a, b]` is exactly two; `[a, b, ..]`
is two or more and discards the tail; `[a, b, ..t]` is two or more and binds it. The marker is a
marker and not a pattern — `..` or `..name`, nothing else — so a list pattern says how long the list
is and what is in the positions it names, and nothing about the rest. **shipped**
<!-- ticket 08 as amended by ticket 54; ticket 53 found the closed form and
     ticket 54 replaced its spelling; the four-language survey is in 54 -->

`[a, b]` means exactly two in Erlang, Elixir, C# and Gleam alike. That is the one place this
language's two reference families agree, so refusing it was the divergence rather than admitting it
— and the refusal used to advise `[a, b, ..t]`, which means something else.

<!-- check:
public atom Dispatch(list<string> path)
-->
```csharp
Dispatch(["orders"])     -> :index
Dispatch(["orders", id]) -> :show
Dispatch(_)              -> :not_found
```

That is how a route table distinguishes `/orders` from `/orders/42` without a length guard, and
`/orders/42/lines` reaches the catch-all rather than being swallowed by the second clause.

**The checker sees the length, and it does so without ever measuring one.** A non-empty list is a
product of an element and a tail, subtracted by the same rule that already subtracts tuples exactly,
so length falls out of the recursion rather than being carried beside it. The residual is then a
clause you can paste: `[]` beside `[a, b, ..]` leaves `[int]` — exactly-one — where a language with
an O(1) length would say `{ Length: 1 }` and this one has no `length` to say it with. Depth is
bounded by the longest prefix any clause writes, per nesting level, which is what makes the
recursion terminate. **shipped**
<!-- ticket 54, built as F20; the repro it deletes is four lines and is in that ticket -->

A consequence worth stating: a closed residual over a list forbids a catch-all exactly as any other
closed residual does, so a `list<bool>` missing its two length-one cases is an error naming
`[true]` and `[false]` rather than a `_`. That bites only where the element type is closed — over
`list<int>` the element is unbounded, the residual stays open, and `_` remains legal.

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

Exhaustive with **no catch-all**, and the compiler agrees. An arm takes the clause head's pattern
grammar whole, so it may carry a guard, or be a relational pattern:

```csharp
public atom Classify(int n)

Classify(n) -> n switch {
    m when m < 5 => :retried,
    >= 5         => :exhausted
}
```

**The name a guarded arm introduces must be fresh** — `m` above, not `n`. §2's rule reaches here:
a bare name in a pattern *introduces* a name, so an arm written `n when n < 5` where `n` is already
the parameter is `rebinding`, not a match against it. **The guard is not what makes it an error.**
A bare `n` as an arm pattern is rejected with no guard present at all; `m when m < 5` and a plain
`< 5` are both accepted. To match the value `n` already holds, §2's spelling is `== n`.
<!-- ticket 45 owns `== name`; ticket 34 owns rebinding. This paragraph exists because §5 used to
     illustrate the guard with `n when n < 5` beside a parameter named `n` — a program the compiler
     rejects — in loose prose that no fence gated. Three clean-room candidates read the packet, had
     §2's rule in front of them, and all three reproduced the illustration rather than the rule:
     handoff/audition-switch, round 1, 2026-08-22. An example outranks a stated rule when the two
     disagree. -->

Nested inside a record pattern, `{ Deliveries: > 5 }` is not
built: a relational pattern goes where a whole argument goes.

**shipped** — F7.

`else` is absent because it is what a *binary unnamed* conditional needs; every fall-through here is
a pattern. `cond` is **open** — deliberately unpaid-for until the shape is shown to occur. Measured
so far: a four-wide tuple reads fine.

---
