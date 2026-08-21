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

**There is no ticket-number formula. Query Linear for the id, every time.** `ENG-(166+NN)` held for
tickets 00–32 and has broken repeatedly since, because the compiler's **features** raise issues in
the same team; measured offsets so far are `+166`, `+167`, `+168`, `+170`, `+172` and `+182`. Before
using a number, check what the issue actually is — on 2026-08-22 two different questions were both
called "ticket 48", one in Linear only and one in the repo only, for four days.

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

## The failing test and the gate come first (David, 2026-08-18)

**When a feature is asked for, write the failing test AND the gate before the
implementation.** Not after it, and not alongside it. The order is the point: a check
written after the code is written to agree with it.

**Nothing is done until the gates pass twice from a clean checkout.** Twice, and clean
both times — not two runs in the same tree. `spec-check.sh` caches a PLT under
`$TMPDIR` and `fixture_root/0` seeds off the OS pid, so a second run in a warm tree is
not an independent measurement of the first. Set `SPEC_CHECK_DIR` per run.

**A gate is believed only once it has been seen to fail.** Every gate carries a
`--self-test` that builds the defect it names, requires a red, and requires a green on
the correct form standing beside it. Both halves: a check that fires on everything
passes the first half and is worthless. This is `spec-check.sh`'s rule from ticket 15,
which lost a session to a harness that supplied the protection it was measuring.

The self-tests earn this. `check-shell.sh` was first written at severity `warning`,
where the tree was already clean — and its own self-test failed, because SC2086, the
word-splitting check it exists for, is classified `info`. It would have passed forever
while unable to see the class it was written for.
