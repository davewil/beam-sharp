# Decision briefs, 2026-10-20 batch

Five open map tickets, picked as the oldest unresolved ones that ask for a decision. None is resolved; every decision is left for review.

| ticket | Linear | brief | verifier report |
|---|---|---|---|
| 39 | ENG-211 | `39-emitted-code-quality.md` | `verification/39.md` |
| 52 | ENG-234 | `52-dependency-provenance.md` | `verification/52.md` |
| 57 | ENG-239 | `57-negative-literals-in-refinements.md` | `verification/57.md` |
| 59 | ENG-241 | `59-boundary-guard-scope.md` | `verification/59.md` |
| 60 | ENG-242 | `60-which-modules-may-name-this-one.md` | `verification/60.md` |

Ticket 25 (ENG-191, the exemplar programs) is older than all of these and is also open. I skipped it: it is a prototype ticket assigned to David that collects exemplar programs, and it does not ask for a decision.

## Reproducing

`probes/env.sh` expects a toolchain under `$PROBE_HOME` (default: the scratchpad of the session that wrote this). To rebuild it elsewhere:

```
micromamba create -p $PROBE_HOME/mm/env -c conda-forge "erlang=28" elixir gleam     # OTP 28, Elixir 1.20, Gleam 1.19
npm install elm                                                                      # 0.19.3 (its package registry may be unreachable)
```

Then `probes/mkvariant.sh NAME [PATCH...]` builds the reference compiler from `compiler/src` plus patches from `probes/patches/` into `$PROBE_HOME/variants/NAME/ebin` (no rebar3 needed), and probes pick a build with `BSC_EBIN=$PROBE_HOME/variants/NAME/ebin`. `probes/mkescript.sh NAME` installs a variant as `compiler/_build/default/bin/bsc` so the eunit suite can run.

Verifier reports contain an `-extra.sh` probe the verifier wrote without seeing the author's results.

## What this batch did not do

- The compiler in `compiler/src` is untouched. Every prototype is a patch under `probes/patches/`.
- Ticket files under `wayfinder/issues/` are untouched and no ticket was claimed, so nothing in Linear moved to In Progress.
- Elm could not compile a project here, so Elm contributes no probe results anywhere in these briefs.
- `CLAUDE.md` asks that a design question be put as a program plus the compiler delta and not as an option menu. Each brief offers 2 or 3 alternatives because this task asked for them, and each alternative is written as a program with its compiler work, with the gating question stated alone.
