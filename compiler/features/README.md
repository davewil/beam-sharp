# Features — how `bsc` gets built out

A **feature-driven** working style, influenced by
[magic-lisp](https://github.com/andrealaforgia/magic-lisp/tree/main/features): numbered capability
files, the walking skeleton as F1, concrete scenarios that assert on **exact output and exit
codes**, and a traceability id per scenario.

**Not Gherkin.** No `Given`/`When`/`Then`, no step definitions, no runner to install. The value
being borrowed is the *shape* — one file per capability, ordered, each naming what "done" means
before the work starts — not the syntax. A scenario here is a command, an input and an expected
result, in a table an agent can read and a human can check.

## Why this rather than a ticket

The wayfinder map produces **decisions**; it is explicitly plan-only except for the walking
skeleton. Features are the other half: they say *what the compiler does next*, in terms of
observable behaviour, against decisions the map has already closed. A feature file cites the
tickets it implements and never re-opens them — if a feature needs a decision, that is a ticket,
not a feature.

## The ordering rule

**Build what unblocks the most exemplars first.** `examples/exemplars/` holds ticket 25's three
exemplars, none of which parse today, and its README carries the table of what each is waiting for.
That table is the backlog; these files are its front end.

One rule learned the hard way and recorded in 25c: **interval patterns and interval refinements
must land in the same feature.** A capability that closes a residual without supplying a way to
name the cases makes previously-valid programs invalid.

## Anatomy of a feature file

```
# F<n> — <capability>

**Status**        not started | in progress | done
**Implements**    tickets it draws on — never decides
**Unblocks**      which exemplars/files stop failing
**Depends on**    other features

## Why this one now
## Scenarios          — F<n>.<m>, each with input, command, expected output, exit code
## Out of scope       — what this feature deliberately does not do
## Done when          — the observable condition
```

Scenario ids are stable and are what a commit message cites (`F2.3`), so the trail from a line of
Erlang back to the decision that required it is one grep.

## The files

| Feature | Status | Unblocks |
|---|---|---|
| [F1 — walking skeleton](F1-walking-skeleton.md) | **done** | the baseline; `examples/*.bs` |
| [F2 — interval refinements and interval patterns](F2-interval-refinements.md) | not started | 25b, 25c wire dispatch |
| F3 — records | not started | all three exemplars |
| F4 — angle brackets and parametric types | not started | all three exemplars |
| F5 — `switch` | not started | all three exemplars |
| F6 — binaries | not started | 25b, 25c |
| F7 — pipe and valve | not started | 25b, 25c |

F3 onward are named but not written — deliberately. The map's own fog-of-war rule applies: don't
chart what you can't yet see, and F2's outcome will change what F3 should say.
