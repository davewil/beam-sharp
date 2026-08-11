# beam-sharp

A design effort for a BEAM-targeting programming language with C#-family brace syntax,
whose defining feature is Erlang-style **multi-clause function heads with pattern
destructuring**, statically checked by a **set-theoretic type system that proves clause
exhaustiveness**.

`beam-sharp` is a working name. Naming is unresolved.

## Wayfinder map — read this first

This repo's issue tracker is local markdown, but **not at the default `.scratch/` path**:

| What | Where |
|---|---|
| The map | `wayfinder/map.md` |
| Tickets | `wayfinder/issues/NN-<slug>.md` |
| Research findings | `wayfinder/research/NN-<slug>.md` |
| Prototypes | `wayfinder/prototypes/` |

Start every session by reading `wayfinder/map.md` — it is the low-resolution view of the
whole effort. Do not read every ticket; zoom into individual tickets on demand.

## Working rules

- Trunk-based on `master`. No PRs, no long-lived branches.
- **Planning by default.** Tickets produce decisions, not deliverables. Execution is
  sanctioned for the walking skeleton only — see the map's Notes.
- One ticket resolved per session, except research tickets which may run in parallel.
- Claim a ticket (`Status: claimed`) before doing any work on it.
