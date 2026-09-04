# beam-sharp

A design effort for a BEAM-targeting programming language with C#-family brace syntax,
whose defining feature is Erlang-style **multi-clause function heads with pattern
destructuring**, statically checked by a **set-theoretic type system that proves clause
exhaustiveness**.

`beam-sharp` is a working name. Naming is unresolved.

## Where things live

**Canonicality is split, deliberately.** Linear owns *state*, because it renders the frontier
visually through native blocking relations that a `Blocked by:` line in markdown never will.
This repo owns *content*, because research files and prototypes do not belong in issue
descriptions, and duplicating them would create a second source of truth for text already under
version control.

| What | Where | Canonical for |
|---|---|---|
| Tickets | `wayfinder/issues/NN-<slug>.md` | **Linear**: status, blocking, assignment, frontier. **Repo**: the question, the answer (its `## Decisions entry` section), all cross-references |
| Research findings | `wayfinder/research/NN-<slug>.md` | Repo only (~380KB; issues link to them) |
| Prototypes | `wayfinder/prototypes/` | Repo only |
| Features | `compiler/features/FNN-<slug>.md` | Repo. Build status comes from the F-file's own `**Status**` line, never the README's narrative |
| Glossary | `CONTEXT.md` | Repo only. **Terms only** — what a word *means*, never why it was chosen. A term appears once it is settled; the reasoning stays in the ticket that settled it |

Project: <https://linear.app/davewil/project/beam-sharp-design-map-bfc1fc086d36>
(the map, [ENG-165](https://linear.app/davewil/issue/ENG-165), is its index issue).

**There is no index file, digest, or glossary of decisions in the repo, on purpose.** Until
2026-09-05 there were four (`map.md`, `fog.md`, `scope.md`, a generated `decisions.md`) plus seven
gates and nine detectors keeping them in shape, and in the five days before the cut that layer took
fourteen commits against the compiler's eleven. The tickets are the record. Anything cut that turns
out to be needed is in git history before `96fc0b2`, and can be rederived from the tickets.

## Starting a session

Read this file and `compiler/features/README.md`. Do not read every ticket; zoom in on demand.

**To find whether something is decided, grep the tickets**: `grep -ln 'records'
wayfinder/issues/*.md`, open the hit, and read its `## Decisions entry` section. Every resolved
ticket carries one. A hit in `research/` or `prototypes/` is evidence, not a decision.

**To choose what to work on, run `/frontier`.** It ranks the open work, claims the pick in both
trackers, and carries the traps that ranking walks into. The ranking exists because sorting by
age picked wrong three times.

## Working rules

- Trunk-based on `master`. No PRs, no long-lived branches.
- **Tickets decide; features build.** A ticket produces a decision, not a deliverable. Capability
  lands through `compiler/features/`, and **a feature that needs a decision raises a ticket
  rather than making one** — that seam is what keeps the two working consistently.
- Claim work before starting it: Linear `In Progress`, and `Status: claimed` in the ticket file.
- **Never write "this is not decided" without grepping `wayfinder/issues/` first.** A session
  once filed as *"a gap rather than a decision"* something a ticket had settled six days earlier.
  The same rule reaches `CONTEXT.md` before coining or redefining a term.
- **A gate guards the language or the handoff, never the tracking layer** (David, 2026-09-05).
  The gates that guarded the tickets' shape, the index, and the gates themselves were removed that
  day because the layer had started generating its own commits. A new check on tickets, the
  glossary, or the checks themselves needs a *second* occurrence of the failure it names; one
  occurrence gets a sentence in this file.
- **A design question is B# code plus the compiler delta, and nothing else.** Write the realistic
  program, show what it compiles to, and state what the compiler must gain as concrete work — a
  symbol-table entry, an emitted function, a pass. Option menus with labelled trade-offs are the
  banned shape, and a matrix of coupled options is that same ban in a new costume: where one
  question gates another, **ask the gating one alone** and let the second follow. David decides by
  reading code and judging whether it is pleasant, then asking what it costs — a four-way matrix
  written in compiler vocabulary was rejected outright, and the same decision took four words once
  it was a program that compiles under one answer and is refused under the other.
  <!-- established ticket 32, 2026-08-14; reconfirmed ticket 47 / ENG-219, 2026-08-31 -->
- **A round of questions is not asked until it is in the repo.** Put the round in the ticket file
  in the same turn it goes to David, never in the chat alone — a round that lived only in
  conversation silently collided its question numbers with an earlier round's.
- **When resolving a ticket**: write the answer in the repo file, commit, then set the Linear
  issue's state and paste the gist into its description. Both, not one — and the issue id comes
  from Linear, never from arithmetic on the ticket number.

## The failing test and the gate come first (David, 2026-08-18)

**When a feature is asked for, write the failing test AND the gate before the implementation.**
Not after it, and not alongside it. The order is the point: a check written after the code is
written to agree with it.

**Nothing is done until the gates pass twice from a clean checkout.** `./bin/verify.sh` is the
whole suite and isolates each run itself; README's *Verifying* section has the procedure and why
each of the two halves catches a fault the other cannot see.

**Once per unit of work, at the final SHA — not once per commit** (David, 2026-09-02). A pair is
~13 minutes, and restarting it every time `HEAD` moves burns them for nothing. Batch first,
verify last. **A docs-or-ticket change gets only the gates that read it** — `check-links.sh`,
and `check-tour.sh` / `check-language.sh` if those files moved; a ticket-only change gets none. A docs-only
commit landing on an already-verified SHA does not restart the standing pair.

**A gate is believed only once it has been seen to fail.** Every gate carries a `--self-test`
that builds the defect it names, requires a red, and requires a green on the correct form
standing beside it. Both halves: a check that fires on everything passes the first half and is
worthless.
