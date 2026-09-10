# Round 4 — 2026-09-10, the mid-tier question is still open

Run `bsharp-cleanroom-audition-20260909T234620Z-p12664`, eight lanes, same
twenty-five-case instrument as round 3 (`9596e35`, unchanged from `30e3e54` in
`cases/`, `heldout/` and `expected/`).

**The round was run to ask one question and did not answer it.** Round 3's two
passes were each lab's frontier model, so "the specification transfers" meant
"transfers to the best model available", which is not the claim the handoff needs.
`gpt-5.6-sol`, `gpt-5.6-terra` and `gpt-5.6-luna` were added to ask where the
specification stops being implementable.

## The three mid-tier lanes are NO MEASUREMENT

```
ERROR: You've hit your usage limit. … or try again at 4:38 AM.
```

All three, on both attempts. `codex-terra` and `codex-luna` exited in 8 and 7
seconds; `codex-sol` in 108. None produced a `switchcheck` and none read a line of
`PACKET.md`. **This says nothing whatever about GPT-5.6's ability to implement the
specification.**

**The cause is the round's design, not the models.** Four codex lanes were put in
one run against one ChatGPT plan. `codex` (`gpt-6-astra`) went first, ran for 647
seconds, and the plan was exhausted by the time the mid-tier lanes started. A
capability question was asked in a way that made a billing answer inevitable.

**The mid-tier lanes need their own round**, after the quota resets, and ideally
not sharing a run with `astra` at all — the frontier lane is the one that spends
the budget and it has already answered its question twice.

This is the third time an audition lane has recorded a zero that was not a model
result: `free-deepseek` in rounds 1 and 3 (provider error, and again here), and
now three codex lanes on quota. A zero from a lane that never ran and a zero from
a lane that ran badly are the same number and different facts, and only the log
tells them apart.

## What round 4 did measure

| lane | model | attempt 1 visible | attempt 1 held-out | final visible | final held-out |
|---|---|---|---|---|---|
| `codex` | `gpt-6-astra` | 12/13 | 11/12 | **13/13** | **12/12** |
| `grok` | `grok-4.6` | 12/13 | 11/12 | **13/13** | **12/12** |
| `copilot-sonnet5` | Claude Sonnet 5 | 13/13 | 11/12 | 13/13 | 11/12 |
| `copilot-haiku45` | Claude Haiku 4.5 | 13/13 | 9/12 | 13/13 | 9/12 |
| `codex-sol` | `gpt-5.6-sol` | — | — | — | — |
| `codex-terra` | `gpt-5.6-terra` | — | — | — | — |
| `codex-luna` | `gpt-5.6-luna` | — | — | — | — |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | — | — | — | — |

Elapsed: codex 647s, grok 2296s, copilot-sonnet5 867s, copilot-haiku45 1156s.

**`astra` and `grok-4.6` reproduced round 3 exactly** — 12/13 and 11/12 on attempt
1, 25/25 after. Two identical results a day apart on the same instrument is worth
more than either alone.

**Both copilot lanes improved, on an unchanged instrument.** Sonnet went 10/12 →
11/12 held-out, Haiku 7/12 → 9/12. Same models, same packet, same cases, one day
apart. That is run-to-run variance and it is large — two held-out cases for Haiku.
It is the answer to round 3's open question about whether `copilot-sonnet5`
failing `h04` was variance or drift: **variance is real and this size**, so no
single round should be read as a model's record.

## `h04` and `h11` recur, which strengthens ticket 71

| case | round 3 | round 4 |
|---|---|---|
| `h04-matched-name` | sonnet `clean`, haiku `clean` | sonnet `switch_inexhaustive unreachable_arm` |
| `h11-vacuous-arm` | sonnet `clean`, haiku `clean` | haiku `clean` |
| `h05-catchall-over-closed` | haiku `switch_inexhaustive` | haiku `clean` |
| `h02-interval-gap` | haiku `clean` | haiku `clean` |

**`h11` has now been missed in two rounds by two different models**, always the
same way — `clean` where the compiler says `vacuous_arm`. That is
[ticket 71](../../../../wayfinder/issues/71-a-worked-example-narrower-than-its-rule.md)'s
evidence, now doubled.

**`h04` failed for sonnet in both rounds and differently each time** — `clean`
first, then a superset naming a diagnostic the compiler does not emit. A case a
model gets wrong two different ways is not a model that guessed; it is a case the
packet does not decide. §2's rule is quoted in the audition README as deciding it;
this is the second round in which that rule did not reach a reader. It deserves
its own ticket alongside 71.

`h05` is already annotated as a case whose packet sentence invites a worker to
expect silence, and both rounds' answers are consistent with that reading.

## Provenance

* Panel widened and staged from the main checkout at `9596e35`, not a worktree —
  round 3's near-miss was staging from a tree behind `master`.
* Each sandbox verified before the run: 13 cases, 9-tag vocabulary, `expected/`
  and `heldout/` unreachable. `ringer.py lint` clean at 8 tasks.
* The four codex lanes carry four distinct `-m` flags, confirmed by `--dry-run`
  before spending. `~/.config/ringer/config.toml` had to gain `{model_args}`
  first; without it Ringer refused the manifest rather than running one model
  under four labels.
