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
| [F3 — records](F3-records.md) | **done 2026-08-14** | the record half of all three; `examples/shop.bs` |
| [F4 — local bindings](F4-local-bindings.md) | **done 2026-08-14** | nothing — it removes a papercut |
| F5 — the body check site | not started — **build next** | F3.3, F3.8, F3.10; 34's destructuring binds |
| F6 — angle brackets and parametric types | not started | all three exemplars |
| F7 — `switch` | not started | all three exemplars |
| F8 — binaries | not started | 25b, 25c |
| F9 — pipe and valve | not started | 25b, 25c |

**F4 was built out of order and the rule was not bent quietly.** No exemplar is blocked on
bindings — the three that exist contain zero. It was built because David reached for one in the
first minute of using the compiler, which is a different ground from the ordering rule and is
stated as such in the file: *the first thing a fluent reader reaches for should not be absent by
accident.* The placeholders below it shifted by one; none had a file.

**F3 raised the map's first ticket from a feature**:
[ticket 33](../../wayfinder/issues/33-body-check-site.md) — *is a function body typed at all, and
where does the check run?* F2 and F3 hit the missing seam from opposite directions, and three of
F3's scenarios were deferred on it with their ids reserved. **RESOLVED 2026-08-14**, and F5 is now
what implements it: a body is typed, checking is containment at five sites (call argument,
construction, projection, clause return, destructuring bind), and the residual survives at four of
them — `subtract/2` + `to_pattern/1` hand a call site the clause head the *caller* must write, and
hand a projection the union member that lacks the field. **It takes the F5 slot ahead of angle
brackets**, since `option<T>` fields multiply construction sites and F3.10 is the hole F3 shipped
with; the placeholders below it shifted by one, and none had a file. The ticket carries the
compiler delta stated against the shipped source, so F5 has nothing to design.

**Two things the ticket found that F5 must not get backwards.** A body variable's type is read off
the clause's **refined domain** at the path `pattern_type/3` already records — a bare `p_var` is
`term`, so typing a body from its patterns fails every call site — and the intersection must use
**`Possible`, never `Certain`**, since an untranslatable guard makes `Certain` `none` and would
type a running body's variable as a value that cannot exist. `walk/5` already computes the right
domain and discards it, so the check is not a second pass.

**And a lesson about this seam rather than about this ticket.** Two of 33's premises went stale in
the three hours between raising it and resolving it — F4's scope pass made *"`bs_check` never
visits a function body"* false, and the Question's expression inventory was short by eight forms.
A ticket raised out of a feature is a **timestamped claim about the compiler**, so re-measuring its
Question is the first step of resolving it, not the last.

**Two things F3 found that the next feature inherits.** The **benchmark had been broken on
master** since the `;` terminator was dropped, so the skeleton's recorded numbers were not
re-measurable — fixed, and the atom ladder reproduces them. And **`bin/spec-check.sh` is red**
independently of F3: `counter.bs` declares `behaviour GenServer` without defining its callbacks,
so Dialyzer reports three undefined callbacks. Whoever owns the OTP callbacks should close it; it
is a gate nobody can currently pass.

F4 onward are named but not written — deliberately. The map's own fog-of-war rule applies: don't
chart what you can't yet see.

**F3 was written ahead of F2, and F2 is why.** F2's own file says in bold that it must not be
implemented until the spelling of an interval pattern and the summarised form of a wide residual are
answered, and both are *"a decision, not a feature"*. The ordering rule then decides the rest:
records block all three exemplars where refinements block two, and ticket 26 closed on 2026-08-13
with four sections settled. The claim that *"F2's outcome will change what F3 should say"* was an
expectation with no probe behind it; F3 records it as an assumption and states where it would break.
