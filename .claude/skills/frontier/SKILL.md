---
name: frontier
description: Pick the next piece of beam-sharp work from Linear and the repo, ranked by claim, priority, what it unblocks, and the repo's own rules; claim it in both trackers and route it. It also carries the traps that picking walks into: the ticket-number rule, where feature status comes from, and defect-versus-ticket.
disable-model-invocation: true
---

# Frontier

Choose one piece of work, say which rule chose it, claim it in both trackers, route it. The
**frontier** is the set of open, unblocked, unclaimed issues; this skill finds its top.

## 1. Orient

Run `.claude/skills/frontier/repo-side.sh` from the repo root. It prints `HEAD`, whether master's
CI is green, the `Status:` line of every `wayfinder/issues/` ticket, every feature file whose
Status is not done, and whether the tree is dirty. A red master or a dirty tree is the first
piece of work, before anything below.

## 2. Pull state

Linear owns state. Query with `list_issues`, `project: "beam-sharp design map"` (exact string,
no dash; a wrong name returns nothing and raises no error), `limit: 250`, fields
`title, status, statusType, priority, labels, parentId, updatedAt`. Then `get_issue` with
`includeRelations: true` on every candidate in the top band, because blocking is the one thing
the list view does not show.

Done when: the started and backlog issues are in hand, and every candidate's `blockedBy` is
known.

## 3. Rank

Apply in order; the first rule that separates two candidates decides.

1. **Claimed beats fresh.** An issue that both trackers call in-flight (Linear `In Progress`
   and repo `Status: claimed`, for map tickets) outranks anything unstarted. One tracker alone
   is a stale label, not work. `In Review` is waiting on David, not on a session: skip it.
   A Linear-only issue has one tracker, so its `In Progress` counts on its own, and it counts
   even when no session is holding it and even over a `quick-fix` — David confirmed this on the
   skill's first run (2026-09-01, ENG-263 over ENG-289). Started work finishes before new work
   starts. An issue whose own last note says closing it is David's call is waiting on him: skip
   it the way `In Review` is skipped.
2. **Unblocked only.** An open `blockedBy` removes an issue from the frontier. Where the graph
   is empty, read the acceptance criteria for implicit ordering ("needs the assembled
   artifact" is a blocker with no edge).
3. **A container is not work.** An issue with open children is a place to hang them, not
   something to build: rank its children, never it. No earlier rule removes one, so a session
   that ranks a parent either takes it by mistake or skips it on judgment this skill never
   wrote down. Both of the project's containers sit at High and can never close — `ENG-285`
   (12 open children) and `ENG-244` (6) — so they occupy the top band permanently.
4. **Unblocking value, and it reaches across bands.** An issue that `blocks` others outranks
   one that blocks none; where what it blocks sits in a **higher** priority band, it is ranked
   in that band. Otherwise a blocker is sorted on its own priority and the thing it holds up
   is never reached. Measured 2026-09-07: `ENG-331` — Medium, unlabelled, grammar-only, and
   `yecc`-measured conflict-free — was the sole `blockedBy` of High `ENG-332`, and rule 5's
   label clause separated it from all sixteen `ready-for-agent` issues before this rule was
   consulted. A gate that guards a register (`ENG-291` for `debt`) outranks the entries it
   guards.
5. **Priority, then the agent label.** High before Medium before Low before No-priority.
   Within a band, `ready-for-agent` before unlabelled. `ready-for-human` is David's, not
   yours: name it in the report and move on. Every numbered map ticket is No-priority, so
   age never gets to decide against a prioritised issue. **Know what this clause now selects
   for**: every open `ready-for-agent` issue also carries `apparatus` (16 of 16 on
   2026-09-07), and every open `quick-fix` does too (6 of 6). The label did not start that
   way — `ENG-319`, `ENG-321`, `ENG-297`, `ENG-307` and `ENG-260` were `ready-for-agent`
   features and are all Done. The takeable language work drained and the apparatus did not,
   so the clause promotes apparatus over unlabelled work in every band by attrition.
   Whether `apparatus` should therefore rank last in its band is David's call, open and
   unmade.
6. **Quick fixes before the frontier.** Within a band, `quick-fix` first: each closes a
   documented falsehood or a gate that cannot see one, and stops the record drifting while the
   frontier moves.
7. **Build before decide.** A decision keeps; an unbuilt decision compounds, so an unbuilt
   feature outranks a map design ticket. **Three sources, and the first two were empty when
   this was measured on 2026-09-07** — which is why the rule had stopped reaching anything:
   - a feature file marked `not started` — only `F30`, which rule 8 hands to David;
   - a row in the features README's *decided, unbuilt* table — **zero live rows**, every row
     reading BUILT (F16, F17, F32, F33) and the one exception blocked on ticket 16 §4;
   - **the `debt` label in Linear**, which is where that inventory actually lives (7 open).

   Take a `debt` issue only where its ticket has decided the spelling. `ENG-324` and `ENG-323`
   carry the label and still owe a decision — `ENG-324`'s own text is *"the naming call for the
   assertive form — David's, and it is not free"* — so they are ticket material, not build
   material, and routing one to `/implement` would build what no ticket settled.

   Take a design ticket only when all three sources are blocked or empty, or when a feature
   raises a question it may not answer itself.
8. **Self-disqualification.** Read the Notes and the Status line of anything that looks
   takeable. A ticket that names its own precondition, calls itself "not urgent", or declares
   itself a standing resource has ranked itself last. This fires far more often than its
   position suggests: on 2026-09-07 it disqualified four of the seven High issues — `ENG-204`
   (*"HITL. Not urgent"*), `ENG-279` (F30), `ENG-291` (*"Left in Backlog: the scope call is
   David's"*) and, with rule 1, `ENG-248`. A feature whose `ready-for-agent` is deliberately
   off (F30) is David's read first.
9. **Age, last,** and only within a band.

Done when: one issue is chosen and the sentence naming the rule that chose it is written.

## 4. Check the pick against the traps

- Feature status comes from the F-file's own `**Status**` line, never from the README's narrative.
- **There is no ticket-number formula. Query Linear for the id, every time.** `ENG-(166+NN)`
  held for tickets 00–32 and has broken repeatedly since, because the compiler's features raise
  issues in the same team. Before using a number, check what the issue actually is — two
  different questions were both called "ticket 48" for four days, one in Linear only and one
  in the repo only.
- A defect is a Linear issue with no ticket number; a decision is a map ticket with both a
  file and an issue. Filing the wrong kind is a lost number; no gate sees it.
- Before writing "this is not decided", grep `wayfinder/issues/`.

## 5. Claim and route

Claim in both trackers before any work: Linear state `In Progress`, assignee `me`; for a map
ticket, also `Status: claimed` in its repo file. Then route by kind:

| Kind | Route |
|---|---|
| feature file, `decided, unbuilt` row, defect, `quick-fix` | `/implement`, with the failing test and the gate before the implementation |
| map design ticket | `/wayfinder`, naming the ticket |
| `ready-for-human` | report it to David; do not start it |

Report: a table of the top five with rule, priority, label and what each blocks; then the pick,
the rule, and what it unblocks. Done when the claim is visible in both trackers.

## Why this skill is user-invoked

`disable-model-invocation` is set deliberately. Step 5 writes to two places before any work
happens — a Linear issue's state and assignee, and a `Status:` line in a tracked file — and a
model-invocable skill would reach that step on its own judgment that a session was picking work.

**Headless and multi-session claiming without David's approval is the intended destination**
(David, 2026-09-04), gated behind other workflow refinements first. What it needs before the flag
comes off is [ENG-326](https://linear.app/davewil/issue/ENG-326); the short form is that a claim
has to survive two agents racing for it, has to be reapable when the session holding it dies, and
has to be distinguishable from a claim David made himself.

## Frontier, not backlog

The frontier is the edge of the known: what can be taken now. Everything blocked, in review,
or waiting on David is the backlog behind it. Report the frontier; mention the backlog only
where it explains why a High issue is not on the frontier.

**There is no `/backlog` skill, and the reason is worth keeping** (David asked, 2026-09-07).
The complaint that prompted it — that this skill *"seems to avoid general backlog items"* —
was right about the symptom and wrong about the cause. Every open issue is already in scope
here; none is excluded. What made the useful half unreachable was the ordering, measured that
day at `fd6db43`:

- all seven High issues were unpickable — two containers, one blocked, four self-disqualified
  — so the band that is drained first yielded **nothing**, and no rule said so;
- rule 7's two named inventories were both empty, so *build before decide* reached nothing
  either;
- and rule 5's label clause, which now selects `apparatus` by attrition, sorted the one item
  that would have unblocked a High build behind sixteen documentation chores.

Rules 3, 4 and 7 are the repair. A second picker would have duplicated §1, §2, §4 and §5 of
this skill and differed only in its ranking — which is the thing that was broken.

**What a `/backlog` skill would legitimately be**, if one is ever wanted: not "regular work"
but *the work that is deliberately not progress*. 23 of the 63 open issues carry `apparatus`,
and CLAUDE.md holds that a check, a doc, a hook or a tracker change never counts as progress.
Those items can never win an honest ranking, so either they are never done or they get their
own explicitly-invoked queue that David drains when he decides it is apparatus time. Not
built: one occurrence.
