# Round 5 — 2026-09-10, a mid-tier model implemented the specification

Run `bsharp-cleanroom-audition-20260910T105749Z-p29171`, three lanes, codex only,
the twenty-five-case instrument unchanged since `30e3e54`.

**This round exists because round 3's two passes were each lab's frontier model,
and round 4 failed to ask the question** — four codex lanes shared one ChatGPT
plan and `astra` exhausted it. Here the plan goes to nothing but the lanes being
measured.

## `gpt-5.6-sol` passed

| lane | model | attempt 1 visible | attempt 1 held-out | final visible | final held-out |
|---|---|---|---|---|---|
| `codex-sol` | `gpt-5.6-sol` | 12/13 | 9/12 | **13/13** | **12/12** |
| `codex-terra` | `gpt-5.6-terra` | 13/13 | 11/12 | 13/13 | 11/12 |
| `codex-luna` | `gpt-5.6-luna` | 12/13 | 8/12 | 13/13 | 9/12 |

Elapsed: sol 3592s, terra 1197s, luna 1268s.

**A model one rung below the frontier read §2, §3 and §5 and agreed with the
reference compiler on all twenty-five cases, including all nine diagnostics.**
That is a stronger result for the handoff than round 3's `astra` and `grok-4.6`
passes, because the package is aimed at a stranger *or a fleet*, and a fleet does
its typing on lanes like this one. The specification does not require a frontier
reader.

It cost the most wall time of any lane in any round — 3592s against `astra`'s 647s
for the same work — which is the shape one expects: the same answer, more turns to
reach it.

**All three scored 13/13 visible.** The visible set has now failed to distinguish
an implementation from a lookup table in every round it has been marked in.

## `h11-vacuous-arm` fails in a third consecutive round, and the failure mode is new

| round | model | answer on `h11` |
|---|---|---|
| 3 | Claude Sonnet 5 | `clean` |
| 3 | Claude Haiku 4.5 | `clean` |
| 4 | Claude Haiku 4.5 | `clean` |
| **5** | **`gpt-5.6-terra`** | **`unreachable_arm vacuous_arm`** |

`terra` is the first worker to *find* the vacuous arm — and it emitted a spurious
`unreachable_arm` beside it. It is the only held-out case it missed.

**That sharpens [ticket 71](../../../../wayfinder/issues/71-a-worked-example-narrower-than-its-rule.md)
rather than merely confirming it.** The earlier failures were readers who never
reached the rule at all over a primitive subject. This is a reader who reached it
and could not tell the three dead-arm diagnostics apart: §5 gives
`unreachable_arm`, `vacuous_arm` and `unsatisfiable_arm_guard` one worked example
each, states that they are different mistakes with different repairs, and a
capable reader still emitted two of them for one arm. So the ticket's question —
*one worked example per rule, or per type-shape it can fire over?* — now has a
second axis: the three sibling rules may need contrasting demonstrations, not just
more of them.

Worth recording: a paragraph explaining the three dead-arm rules was drafted for
`PACKET.md`'s brief on 2026-09-09 and deliberately **cut**, because §5 already
draws the distinction and coaching in the brief makes rounds non-comparable. That
decision stands — but this result is what it was cut against, and a future round
that adds it would be measuring the coaching rather than the specification.

## New finding: `luna` fails the entire interval cluster, twice by false positive

```
h01-interval-exhaustive   compiler says [clean]                — luna says [unreachable_arm]
h02-interval-gap          compiler says [switch_inexhaustive]  — luna says [clean]
h03-span-exhaustive       compiler says [clean]                — luna says [unreachable_arm]
```

All three of `luna`'s misses are §2's integer-interval rule, and **two are false
positives on programs that are correct** — it reports a dead arm in an exhaustive
interval switch. `h02`, the one genuine gap, it calls clean. So it has the rule
inverted rather than absent.

This is a different cluster from `h11` and it is the first time the interval cases
have failed at all: round 1's report singles them out as the cases *nothing*
disagreed on. One model failing all three is a weak reader on one rule, not yet a
specification hole — **a second model failing the same cluster would make it one**,
and that is the thing to watch in the next round.

## Provenance

* Checkout verified at `fd9da82` before staging; each sandbox verified to hold 13
  cases and the 9-tag vocabulary with `expected/` and `heldout/` unreachable.
* Quota confirmed live with a single trivial prompt before the run, because round
  4's failure was invisible until the lanes died and the CLI's own status readout
  was stale.
* The run manifest was filtered to the three lanes after `stage.sh` bound the
  checks, so every `check` still names this harness and this workdir.
* `ringer.py lint` clean at 3 tasks; `--dry-run` confirmed three distinct `-m`
  flags before spending.
