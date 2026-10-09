# Decision briefs: where they are (2026-10-09 run)

Every one of the five oldest open decision tickets already has an independently verified brief from earlier
scheduled runs. Each earlier run left its work on its own unmerged `claude/wizardly-meitner-*` branch. This
run gathered the latest of each here and changed none of them.

| Ticket | Linear | Brief | Source branch |
|---|---|---|---|
| 39 emitted-code quality | ENG-211 | `39-emitted-code-quality/brief.md` (+ `verification.md`) | `y5lj0m` |
| 52 dependency provenance | ENG-234 | `52-dependency-provenance-brief.md` | `2iscw5` |
| 57 negative literals in refinements | ENG-239 | `57-negative-literals-in-refinements-brief.md` | `2iscw5` |
| 59 boundary guard scope | ENG-241 | `59-boundary-guard-scope-brief.md` | `2iscw5` |
| 60 who may name this module | ENG-242 | `60-which-modules-may-name-this-one-brief.md` | `2iscw5` |

Ticket 25 (exemplar programs) is a standing resource, not a decision, and was skipped.

## Freshness check run today
The compiler moved 25 commits since the 2iscw5 briefs (F68 string-literal types, F69-F71 FromJson;
none touch refinement literals, the boundary guard, or module visibility). Ticket 57's probe matrix
was rebuilt and re-run on `524704f`: base refuses `value >= -5`; variant A (parser folds `-<int>`)
accepts it and `Id(-5)`; B and C still refuse `Id(-5)`. Identical to the brief.
Toolchain here: OTP 25.3, Elixir 1.14, Gleam 1.12 (now installable); repo pins OTP 28.5, so gates were not run.
