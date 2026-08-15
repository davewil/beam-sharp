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
| Map (index) | [ENG-165](https://linear.app/davewil/issue/ENG-165) · `wayfinder/map.md` | Linear: status. Repo: destination, working notes, and a tagged index of every entry |
| Map (bodies) | `wayfinder/decisions.md`, `fog.md`, `scope.md` | Repo only. Split out 2026-08-15 when the map hit 1,564 lines; the index links to each |
| Tickets | ENG-166 … ENG-194 · `wayfinder/issues/NN-<slug>.md` | **Linear**: status, blocking, assignment, frontier. **Repo**: the question, the answer, all cross-references |
| Research findings | `wayfinder/research/NN-<slug>.md` | Repo only (~380KB; issues link to them) |
| Prototypes | `wayfinder/prototypes/` | Repo only |
| Glossary | `CONTEXT.md` | Repo only. **Terms only** — what a word *means*, never why it was chosen |

`CONTEXT.md` is a glossary and nothing else: no decisions, no rationale, no implementation detail.
A term appears there only once it is settled, and the reasoning stays in the ticket that settled
it. It exists because the vocabulary outgrew what a reader could reconstruct from the decision
trail, and it is expected to be lifted into the spec's terminology section when the spec is drafted.

**Ticket NN maps to ENG-(166+NN)** — ticket 00 is ENG-166, ticket 28 is ENG-194. Verify the
mapping still holds when creating a ticket; it depends on nothing else being created in the
Engineering team between them.

Linear is canonical for state because it renders the frontier *visually* through native blocking
relations, which a `Blocked by:` line in markdown never will. The repo is canonical for content
because research files and prototypes do not belong in issue descriptions, and duplicating them
would create a second source of truth for text already under version control.

**When resolving a ticket**: write the answer in the repo file, commit, then update the Linear
issue's state and paste the gist into its description. Both, not one.

Project: <https://linear.app/davewil/project/beam-sharp-design-map-bfc1fc086d36>

Start every session by reading `wayfinder/map.md` — it is the low-resolution view of the
whole effort, and since 2026-08-15 it is **only** that: ~280 lines of destination, working notes
and a tagged index. Do not read every ticket; zoom in on demand.

**Zooming in has two steps now.** Each index entry carries its ticket number and topic tags, so
grep the map first (`grep -n 'records' wayfinder/map.md`), then grep the body file the entry names
(`grep -n 'Data modelling' wayfinder/decisions.md`), and only then open the ticket in `issues/`.
Reading a whole body file is almost never necessary and costs 400–800 lines.

## Working rules

- Trunk-based on `master`. No PRs, no long-lived branches.
- **Planning by default.** Tickets produce decisions, not deliverables. Execution is
  sanctioned for the walking skeleton only — see the map's Notes.
- One ticket resolved per session, except research tickets which may run in parallel.
- Claim a ticket (`Status: claimed`) before doing any work on it.
