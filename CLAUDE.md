# beam-sharp

A design effort for a BEAM-targeting programming language with C#-family brace syntax,
whose defining feature is Erlang-style **multi-clause function heads with pattern
destructuring**, statically checked by a **set-theoretic type system that proves clause
exhaustiveness**.

`beam-sharp` is a working name. Naming is unresolved.

## Wayfinder map — read this first

**Canonicality is split, deliberately.** Linear owns *state*; this repo owns *content*.

| What | Where | Canonical for |
|---|---|---|
| Map | [ENG-165](https://linear.app/davewil/issue/ENG-165) · `wayfinder/map.md` | Linear: status. Repo: the full body |
| Tickets | ENG-166 … ENG-191 · `wayfinder/issues/NN-<slug>.md` | **Linear**: status, blocking, assignment, frontier. **Repo**: the question, the answer, all cross-references |
| Research findings | `wayfinder/research/NN-<slug>.md` | Repo only (~380KB; issues link to them) |
| Prototypes | `wayfinder/prototypes/` | Repo only |

**Ticket NN maps to ENG-(166+NN)** — ticket 00 is ENG-166, ticket 25 is ENG-191.

Linear is canonical for state because it renders the frontier *visually* through native blocking
relations, which a `Blocked by:` line in markdown never will. The repo is canonical for content
because research files and prototypes do not belong in issue descriptions, and duplicating them
would create a second source of truth for text already under version control.

**When resolving a ticket**: write the answer in the repo file, commit, then update the Linear
issue's state and paste the gist into its description. Both, not one.

Project: <https://linear.app/davewil/project/beam-sharp-design-map-bfc1fc086d36>

Start every session by reading `wayfinder/map.md` — it is the low-resolution view of the
whole effort. Do not read every ticket; zoom into individual tickets on demand.

## Working rules

- Trunk-based on `master`. No PRs, no long-lived branches.
- **Planning by default.** Tickets produce decisions, not deliverables. Execution is
  sanctioned for the walking skeleton only — see the map's Notes.
- One ticket resolved per session, except research tickets which may run in parallel.
- Claim a ticket (`Status: claimed`) before doing any work on it.
