# Round 3 — 2026-09-09, the first run against nine marked diagnostics

Run `bsharp-cleanroom-audition-20260909T223753Z-p59971`, orchestrated by Ringer,
five lanes, `max_parallel` 4. The instrument is the twenty-five-case one that
landed the same evening in `30e3e54`: thirteen visible, twelve held-out, and a
marking vocabulary of **nine** tags where rounds 1 and 2 marked four.

**Rounds 1 and 2 are not a baseline for these numbers.** They measured fifteen
cases and four tags against a packet that has since been rebuilt twice. The
panel is deliberately unchanged so that the *models* remain comparable even
though the exam does not.

## Scores

Attempt 1 is the clean-room measurement. Attempt 2 is run with the check's
failure output injected into the prompt — but **only the visible detail**: the
check withholds *which* held-out cases failed and leaks only the count, so an
attempt-2 held-out score still measures generalisation from a worker that was
coached on the visible set alone.

| lane | model | attempt 1 visible | attempt 1 held-out | final visible | final held-out |
|---|---|---|---|---|---|
| `codex` | `gpt-6-astra`, high effort | 12/13 | 11/12 | **13/13** | **12/12** |
| `grok` | `grok-4.6` | 12/13 | 11/12 | **13/13** | **12/12** |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | 13/13 | 10/12 | 13/13 | 10/12 |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | 13/13 | 7/12 | 13/13 | 7/12 |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | no deliverable | — | no deliverable | — |

`free-deepseek` was the exploration slot and produced no `switchcheck` at all,
exiting in four seconds. Its log is kept; it is a lane that cannot attempt this
task rather than one that attempted it badly.

Elapsed: codex 714s, grok 2153s, copilot-sonnet5 850s, copilot-haiku45 1419s.

## The specification transfers, and that now covers all nine diagnostics

Two independent engines, from different labs, implemented every one of the nine
diagnostics from the packet alone and agreed with the reference compiler on all
twenty-five cases. **This is the first evidence that `vacuous_arm`,**
**`unsatisfiable_arm_guard`, `arg_not_accepted`, `switch_in_guard` and**
**`unbound_variable` are derivable from what the packet ships** — they were
specified on 2026-08-27 and 08-28 and had never been auditioned.

## The visible set could not have shown it, twice in one run

Both copilot lanes scored a **perfect 13/13 on the visible set** and still failed
held-out cases. That is the split's whole purpose, and it is the second time this
audition has demonstrated it live — the first being the 2026-08-20 stub that
scored 8/8 by switching on the directory name in `argv[1]`.

Revealed after the run, when no retry prompt could be built from it:

```
copilot-sonnet5
  h04-matched-name    compiler says [switch_inexhaustive] — this says [clean]
  h11-vacuous-arm     compiler says [vacuous_arm]         — this says [clean]

copilot-haiku45
  h02-interval-gap          compiler says [switch_inexhaustive]     — this says [clean]
  h04-matched-name          compiler says [switch_inexhaustive]     — this says [clean]
  h05-catchall-over-closed  compiler says [unreachable_arm]         — this says [switch_inexhaustive]
  h11-vacuous-arm           compiler says [vacuous_arm]             — this says [clean]
  h12-unsatisfiable-guard   compiler says [unsatisfiable_arm_guard] — this says [clean]
```

## Finding: `h04` and `h11` were missed by both, which points at the packet

Per this harness's own rule, one worker missing a clause is a weak worker and
several workers missing the **same** clause is a hole in the specification. Two
of two failing lanes missed exactly these:

**`h11-vacuous-arm` is the sharper of the two, and it is new tonight.** Both said
*clean* where the compiler says `vacuous_arm`. §5 teaches vacuity through
`(:pass, n)` — a **tuple** pattern against a **declared** atom union, where the
type is written in the file three lines above. `h11` is `:small` against a
primitive `int` subject, where nothing in the file enumerates the subject's
members. The rule as stated covers it — "the arm's pattern is not a member of the
subject's type at all" — but the worked example may not carry a reader to the
primitive case, and a worked example has already outranked a stated rule once in
this audition (round 1, `c07`). **This is the same shape as that finding and
should be read as a candidate specification defect, not as two weak models.**

**`h04-matched-name` is not new**, and `copilot-sonnet5` passed it 7/7 in round 2
on 2026-08-22. The same model missing it now is either run-to-run variance or a
consequence of a packet that has been rebuilt twice since. One observation is not
a trend; recorded here so a third data point has something to land against.

`h05` is already annotated in the audition README as a case whose packet sentence
reads as an invitation to expect silence. `copilot-haiku45` answered
`switch_inexhaustive` where the compiler says `unreachable_arm` — a different
rule arriving at the same place, which is exactly what that note predicted.

## What this does not close

**ENG-248's criterion 5 remains open.** It requires a clean-room audition passing
all visible and held-out cases **on first attempt**, and no lane did: the best
first attempts were 12/13 and 11/12. It is no longer open for want of a run.

## Provenance

* Workdir `~/.ringer/audition-2026-09-09-round3`, per-run and durable — not the
  manifest's hardcoded `/tmp/bsharp-audition`.
* Manifest bound by `stage.sh`, which rewrote the workdir and every `check` to
  this harness. `ringer.py lint` clean, 5 tasks.
* **The first staging attempt was discarded.** It copied eight cases, because the
  main checkout was still two commits behind `origin/master` and did not yet hold
  `c09`–`c13`. Every worker would have been marked on diagnostics its packet
  forbade it from printing. Caught by counting staged cases before the run; the
  checkout was fast-forwarded to `bc4bd64` and the sandboxes rebuilt. This is the
  defect class `build-run-manifest.py` exists for, one level further out.
* Each sandbox verified to hold 13 cases and the 9-tag vocabulary, with
  `expected/` and `heldout/` unreachable.
* `run.json` here is the whole run record rather than a per-lane slice, which is
  where rounds 1 and 2 put theirs.
