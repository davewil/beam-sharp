# Decision briefs for the five oldest open decision tickets (2026-10-14)

Written by an unattended scheduled run. **No ticket was resolved**; every decision is open for David.

| Brief | Ticket | Linear | Recommends |
|---|---|---|---|
| [57](decision-brief-57-negative-literals-in-refinements.md) | A refinement cannot say `-5` | ENG-239 | fold a negated int literal in `negate/2` (1 line) |
| [59](decision-brief-59-boundary-guard-scope.md) | Boundary guard scope asymmetry | ENG-241 | guard what is reachable: exported or escaping as a value |
| [60](decision-brief-60-which-modules-may-name-this-one.md) | Which modules may name this one | ENG-242 | callee-declared list of subtrees; budget the diagnostics first |
| [52](decision-brief-52-dependency-provenance.md) | Dependency provenance | ENG-234 | name the application on the `using` block, check it, record it |
| [39](decision-brief-39-emitted-code-quality.md) | Instruction-identical code 20% slower | ENG-211 | rerun on OTP 28 / arm64 before deciding; **gap did not reproduce here** |

**Selection.** Oldest by Linear creation date among open, numbered map tickets: ENG-191 (25), ENG-211 (39), ENG-234 (52), ENG-239 (57), ENG-241 (59). Ticket 25
(exemplar programs) is a standing resource with no decision in it ("not a single session's work"), so I skipped it and took the next, ENG-242 (60). Reverse this if you wanted 25 counted.
The briefs lead with one gating question as code, per `CLAUDE.md`'s ban on option menus, then list options because the task asked for them.

## Reproduce

`artifacts/probes/run-all.sh [WORKDIR]` rebuilds the compiler from `compiler/src` (never edits it), applies each patch in `probes/patches/` as a separate variant, runs every probe and writes `probes/results/*.txt` (override with `RESULTS=dir`). About 6 minutes; `ONLY="57 60"` runs just those sections (57, 59, 60, 52, 39, regression). Needs `erlang`, `elixir`, `erlang-eunit`, `python3`.

## Limits you should know before trusting any number

- **OTP 25.3 on x86-64, Elixir 1.14.** The repo targets OTP 28. apt had nothing newer and the egress proxy refused hex.pm, builds.hex.pm and GitHub releases.
  `bs_lexer.xrl` needs a newer `leex` (`TokenLoc`, column support), so the scratch build shims locations to `{Line,1}`. That touches the lexer only; the checker and emitter probed are the repo's.
- **eunit baseline is red: 583 of 1,448 fail** here (`maps:iterator/2` is OTP 26+, and no escript is built). So "no regression" means *the failing set is identical to baseline* (`probes/results/regression-diff-vs-baseline.txt`), not "green". `bin/verify.sh` and the shell gates were **not run**.
- **Gleam and Elm are not installed** and could not be fetched. No claim is made about them. The installed Erlang and Elixir packages ship `ebin` only, so there are no neighbour source files to cite by line; neighbour evidence is executed output, and repo citations are to this repo.
- Timings are single-machine and noisy (null-control spread about 3%); ranges are quoted.
- Patches are prototypes in a scratch copy for measurement. They are not proposed commits.
- Each brief was re-run by an independent verifier subagent; reports are in `verification/`. All five returned CONFIRMED WITH CORRECTIONS and the briefs above incorporate the corrections. The stored `52-no-diagnostic-today.txt` prints `compile exit=` of `head`, not of `bsc`; the verifier checked the real exit (0).
- Tickets are untouched in Linear apart from one comment each; none was claimed or resolved.
