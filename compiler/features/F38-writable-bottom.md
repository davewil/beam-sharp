# F38 — the bottom is writable: `none` in a signature

**Status**      **done 2026-09-08** — 6 new tests, 695 in the suite, up from 689.
                No new gate. `check-corrected-signature.sh` gained a fifth probe
                and a fifth `--self-test` stub, because the defect this feature
                surfaced is one that gate already exists to prevent — a line
                that looks pasteable and is not — reached through a type instead
                of through a mint tag. `./bin/verify.sh` green **twice from a
                clean clone**, 38/38 stages both times
**Implements**  [ticket 12](../../wayfinder/issues/12-totality-vs-let-it-crash.md)
                §4, the half F34 left, and through it §5's `Partial` benefit
**Closes**      [ENG-328](https://linear.app/davewil/issue/ENG-328)
**Decides**     nothing about the language. 12 §4 settled the spelling, the
                first-class stance and the reason for both. **One implementation
                choice is named here** because no ticket reached it: the
                corrected-signature printer omits the declared return entirely
                when it is the bottom, rather than unioning through the algebra
                (§F38.3)
**Depends on**  F34, which made `raise` an expression of type `none` and left
                this; F25, whose corrected-signature line is the thing that had
                to move with it; F36, whose absorbed-member refusal is what makes
                the naive line illegal rather than merely verbose

## The measurement

`bs_check:builtin/1` carried `int`, `atom`, `term`, `bool`, `binary` and
`string`. There was no `none`, so the type ticket 12 §4 declared first-class was
refused at every declaration site:

```
public none Reject(term r)
Reject(r) -> raise (:rejected, r)
```

```
error: none is not a builtin type
  this slice has `int`, `atom`, `term`, `bool`, `binary`,
  `string` and `list<T>`.
```

A clean refusal with a good message rather than a crash, which is why this was
debt and not a bug. After, the program compiles, and the one that returns a
value under the same signature is refused.

## What shipped

`builtin(none) -> bs_types:none()`, and `unknown_builtin`'s message — which
enumerates the slice by hand — moved in the same commit.

That is the whole of the surface. Nothing else was needed, and the reason is
worth keeping: `raise` already type-checked against any declared return before
this feature, because `is_subtype(A, B)` is `is_none(subtract(A, B))` and
subtracting anything from the empty set leaves it empty. The containment held by
the algebra with no rule added. What was missing was only the *name*.

### F38.1 — why a type nobody can construct is worth writing

The argument in 12 §4 is an asymmetry rather than a use case, and it is the part
worth not re-deriving. `bs_types:to_string/1` already prints `none` into every
exhaustive function's residual, so a reader meets the name in compiler output
whether or not the language lets them write it. A type readable in a diagnostic
and unwritable in a signature is gratuitous, and `term` — the other end of the
same lattice — was always writable.

What it buys, per 12 §5, is a **named, greppable, type-checked crash site**
obtained from the lattice rather than from a propagating constraint. `raise` is
the primitive; `none Reject(Reason)` is the function. Before this, every crash
site had to be a literal `raise` at the point of failure.

### F38.2 — the test that separates `none` from `term`

Most of the six new tests pass under a build that resolved `none` to the
**top**: a raising body satisfies `term` too, the declaration parses either way,
the emitted function runs either way, and the spec block compiles either way.
Only a body that **returns a value** separates the two readings — against `none` it must be refused, since no value
inhabits the empty type, and against `term` it is the most ordinary program
there is.

A second control stands beside it: a returning clause *next to* a raising one is
still refused. An implementation that checked the first clause and stopped would
compile a function declared never to return whose second clause returns an `int`,
and the declaration would be a lie.

### F38.3 — the finding: a writable bottom breaks F25's printer, through F36

**This was not in the ticket, and it is the reason this feature is more than one
line.** F25 builds the corrected signature by concatenating the declared return's
**source text** with the rendered residual:

```erlang
lists:flatten([vis_source(Vis), RetSrc, " | ", Rendered, ...])
```

The concatenation rather than a `bs_types:union/2` is deliberate — it keeps the
author's own alias name instead of the algebra's expansion of it. And it is safe
for every type but one, for a reason that has never had to be stated: **a
residual is the complement of what was declared, so it cannot absorb it.** An
`int` return against a `term` body prints

```
public int | atom | tuple | list<term> | map | binary Grow(term r)
```

— never `int | term`. The complement reconstitutes the top without ever naming
it.

`none` is the exception, and the only one. Its complement is everything, so the
residual is the whole of `term` and the line read:

```
public none | term Reject(term r)
```

**Ticket 68, built as F36 the day before, refuses an absorbed member at a
declaration.** So the compiler was printing, as the line to paste, a program it
rejects. Measured by doing exactly that — pasting the recommendation back:

```
error: `none` is absorbed by `term`
  every value of `none` is already a `term`, so the type declared here
  IS `term` and the member you wrote is not in it.
```

That is ticket 23 §2's failure mode — *a line that looks pasteable and is not is
worse than no line* — reached through a type rather than through the mint tag
probe 3 was written for. Hence a fifth probe on the same gate rather than a new
one.

**The fix is not a union through the algebra.** Running `bs_types:union/2` would
lose the author's alias name in every other case, which is the property the
concatenation exists to preserve. `declared_member/2` instead drops the declared
term when it is the bottom, which is exact rather than a special case: `none | X`
*is* `X`, so the residual alone is both the correct answer and the pasteable one.

### F38.4 — two features that only collide through a third

F34 (`raise`, 2026-09-05) and F36 (the absorbed-member refusal, 2026-09-07) do
not touch each other. Neither does this feature touch F36. The collision runs
through F25's printer, which is a *diagnostic* surface — so nothing in the type
checker, the emitter or the grammar would have caught it, and the whole test
suite stayed green while the compiler recommended an illegal program.

What found it was running the compiler's own recommendation back through the
compiler. That is cheap and is not a habit anything in the repository currently
enforces; it is the only reason this shipped correct.

## What this leaves

### F38.5 — the other type positions, measured and not decided

`builtin/1` is consulted wherever a type is named, so `none` became writable in
**every** position at once, not only in a return. Measured after the change, and
recorded here rather than frozen in a test, because **nothing decided any of
it** — it falls out of the algebra, and a test would certify as intended what
no ticket has chosen:

| written | what happens today |
| --- | --- |
| `public Never Reject(term r)` where `type Never = none` | works, and the corrected signature resolves through the alias — this one *is* tested, being the control that says the repair keys on the resolved type and not on the source text |
| `public int F(none n)` | compiles with a **warning**: *"clause 1 of F matches no value of its input … no call can reach this clause"*. Correct and already-existing behaviour for a vacuous clause; whether declaring an uncallable function should instead be refused is undecided |
| `public int F(list<none> xs)` | compiles silently. `list<none>` is the empty list and nothing else, which is arguably the right answer and is nobody's decision yet |

If any of these should be refused rather than allowed, that is a ticket, not a
build — per CLAUDE.md, *a feature that needs a decision raises a ticket rather
than making one*.

### F38.6 — the builtin slice is enumerated twice, by hand

`bs_check:builtin/1` has one clause per builtin and `bs_diag`'s
`unknown_builtin` message lists them in prose; adding `none` meant editing both,
and nothing holds them together. ENG-328 named this — *"the refusal message's
list of builtins updated in step — it enumerates the slice by hand"* — and asked
only for the update, so deriving the message from the clause list was left
alone. It is the obvious next tidy-up and would need a `builtins/0` the message
and the resolver share.

### F38.7 — the roster

`none` is not in `corpus_tests:demonstrated_surface/0`. That roster names
capabilities that owe a corpus example, and no builtin **type name** has a row —
`int`, `term` and the rest are demonstrated through the programs that use them,
not enumerated. Adding one would force both a corpus example and a `TOUR.md`
appendix row. **Whether the bottom is different enough to earn a row — being a
capability ("a function that never returns") and not only a name — is David's
call, and it is open.**
