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
3. **Priority, then the agent label.** High before Medium before Low before No-priority.
   Within a band, `ready-for-agent` before unlabelled. `ready-for-human` is David's, not
   yours: name it in the report and move on. Every numbered map ticket is No-priority, so
   age never gets to decide against a prioritised issue.
4. **Quick fixes before the frontier.** Within a band, `quick-fix` first: each closes a
   documented falsehood or a gate that cannot see one, and stops the record drifting while the
   frontier moves.
5. **Unblocking value.** An issue that `blocks` others outranks one that blocks none. A gate
   that guards a register (`ENG-291` for `debt`) outranks the entries it guards.
6. **Build before decide.** A feature file marked `not started`, or a row in the features
   README's *decided, unbuilt* table, outranks a map design ticket. Decisions keep; an unbuilt
   decision compounds. Take a design ticket only when both lists are blocked or when a feature
   raises a question it may not answer itself.
7. **Self-disqualification.** Read the Notes and the Status line of anything that looks
   takeable. A ticket that names its own precondition, calls itself "not urgent", or declares
   itself a standing resource has ranked itself last. A feature whose `ready-for-agent` is
   deliberately off (F30) is David's read first.
8. **Age, last,** and only within a band.

Done when: one issue is chosen and the sentence naming the rule that chose it is written.

## 4. Check the pick against the traps

- Feature status comes from the F-file's own `**Status**` line, never from the README's narrative.
- **There is no ticket-number formula. Query Linear for the id, every time.** `ENG-(166+NN)`
  held for tickets 00–32 and has broken repeatedly since, because the compiler's features raise
  issues in the same team. Before using a number, check what the issue actually is — two
  different questions were both called "ticket 48" for four days, one in Linear only and one
  in the repo only.
- A map ticket with a file and an issue may have no map entry at all. Absence from `map.md`
  is not absence.
- A defect is a Linear issue with no ticket number; a decision is a map ticket with both a
  file and an issue. Filing the wrong kind is a red gate or a lost number.
- Before writing "this is not decided", grep `wayfinder/decisions.md`.

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
