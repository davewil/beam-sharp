# 60 — Which modules may name this one?

Type: grilling
Status: **open 2026-08-23** — Backlog
Split from: [22](22-how-opinionated.md), which proposed exactly this and then resolved without it

<!-- ENG-242 -->


## Question

A module controls **what** it exposes. It has no way to say **who** may name it.

`public`/`private` shipped as F12 on 2026-08-17, deciding ticket 40 §3: a signature carries a
visibility marker and private is the default. That is the *what* half. The *who* half has no
spelling, no checker support and, until now, no owner.

Measured at `0b761f6`: `add_module_import/5` reads only the callee's export set
(`bs_check.erl:407-425`), and there is no `internal`, `friend`, `sealed` or `visible_to` anywhere in
the checker.

## Why it split out

Ticket 22 asked *"is this one decision or two?"* about visibility, and answered **two**. The half it
called useful is this one, and 22 said so in its own words: it *"probably is [worth having
independently], in which case it should be split out rather than held hostage here."* It then
resolved on 2026-08-23 without touching it, so the split is now real rather than proposed.

## What 22 established that constrains this

**Do not borrow C#'s `internal` spelling without its semantics.** C#'s `internal` is
assembly-scoped, and beam-sharp has no assembly. F15 makes a **directory** a module, so the natural
unit here is a subtree of the source root, which is not what `internal` means anywhere else. This is
the borrow heuristic's false-friend rule: survey what each language's word already means, and refuse
a word whose meaning is adjacent but wrong.

**Per-function export control is not cheaply available on the BEAM.** Ticket 18 §5 measured that
elision is exported-versus-local with one entry label per function. So a design that wants to hide a
function from *some* callers and not others cannot lean on the emitter to enforce it; it is a
compile-time check on the caller, or it is nothing.

**There is a consumer waiting.** Ticket 24 §2 made the client API the test boundary and used ticket
14's behaviour contract to classify callbacks and client API. What it cannot place is the remainder
— a helper like `RecomputeTotal/1` is neither, and lands `unclassified`. An agent writing tests in a
loop targets `unclassified` functions because they are the easiest thing in the directory to test,
which is structural drift of exactly the kind agent authorship produces.

## What has to be decided

1. **What is the unit?** A directory subtree, a named group, an explicit list of modules, or
   something else. F15 makes the directory the module, so the subtree is the cheap answer and may be
   the right one.
2. **Which direction does the declaration point** — the callee naming who may call it, or the caller
   declaring what it depends on? The second is closer to what `using` already does.
3. **Is it a third visibility marker or a separate construct?** `public`/`private` are on the
   signature. A rule about modules may not belong on a function at all.
4. **What does it cost the checker?** `add_module_import/5` is the site; today it reads the callee's
   export set and nothing else.

## Notes

Not owed a decision soon. It is recorded so that the question has a home, which it did not have
between F12 shipping the *what* half and 22 resolving without the *who* half.
