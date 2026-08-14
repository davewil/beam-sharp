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

## The harness the features are driven through

**Not a numbered feature** — it decides nothing and implements no ticket — but every feature below
is verified through it: `bsc FILE.bs [FUNCTION] [ARG...]` compiles and runs a program, and
`ibs -S FILE.bs` opens a REPL over it with `:reload`. Added 2026-08-14 on David's *"I want to drive
this compiler development by actually runnable code."* See the compiler README. A feature is done
when you can see it run, not only when its scenarios pass.

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
| [F2 — interval refinements and interval patterns](F2-interval-refinements.md) | **blocked** — two decisions owed | 25b, 25c wire dispatch |
| [F3 — records](F3-records.md) | not started — **build next** | the record half of all three |
| F4 — angle brackets and parametric types | not started | all three exemplars |
| F5 — `switch` | not started | all three exemplars |
| F6 — binaries | not started | 25b, 25c |
| F7 — pipe and valve | not started | 25b, 25c |

F4 onward are named but not written — deliberately. The map's own fog-of-war rule applies: don't
chart what you can't yet see.

**F3 was written ahead of F2, and F2 is why.** F2's own file says in bold that it must not be
implemented until the spelling of an interval pattern and the summarised form of a wide residual are
answered, and both are *"a decision, not a feature"*. The ordering rule then decides the rest:
records block all three exemplars where refinements block two, and ticket 26 closed on 2026-08-13
with four sections settled. The claim that *"F2's outcome will change what F3 should say"* was an
expectation with no probe behind it; F3 records it as an assumption and states where it would break.
