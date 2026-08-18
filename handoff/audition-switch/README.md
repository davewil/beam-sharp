# Clean-room audition — the exhaustiveness checker

An audition for the question the handoff turns on: **which models can implement
B# from the specification alone, and at what cost?**

The slice is `switch`. It was chosen on evidence rather than taste — §5 is 54
lines of specification carrying 19 tests and six distinct diagnostic tags
(`switch_inexhaustive`, `unreachable_arm`, `rebinding`, `unbound_variable`,
`arg_not_accepted`, `return_not_declared`), the densest gate-per-spec-line ratio
in the language. Pipelines, the runner-up, is 64 lines with 13 tests and two
tags. Switch is also the feature that exercises what B# exists for: proven
clause exhaustiveness.

## What a worker is asked to do

Build `./switchcheck <file.bs>`, printing one diagnostic tag per line and
nothing for a well-formed program. It receives `PACKET.md` — §2, §3 and §5 of
`LANGUAGE.md` verbatim — and `cases/`. It does not receive the reference
compiler, the design notes, or the answers.

## How it is marked

`check.sh` runs the worker's implementation over every case and compares TAG
SETS against `expected/`, which `oracle.sh` recorded by running the real `bsc`
with `--diagnostics term`.

**The expectations are generated, never typed.** A hand-written fixture measures
the author's beliefs about the language; a recorded one measures the language.
If behaviour changes, re-running `oracle.sh` shows it as a diff.

**Comparison is on the tag set, not on pass/fail.** A checker that shouted
`switch_inexhaustive` at everything would agree with the compiler on every
rejecting case and be worthless. Requiring the set means an invented diagnostic
fails as hard as a missing one. Same reasoning as
`compiler/bin/check-helper-agrees.sh`.

## Running it

```sh
./oracle.sh                      # record expectations from the compiler
./check.sh --self-test           # prove the check can fail before trusting it
./stage.sh /tmp/bsharp-audition  # one sandbox per candidate, without expected/
ringer.py lint  manifest.json
ringer.py run   manifest.json --identity <who-you-are>
```

`stage.sh` copies `PACKET.md` and `cases/` into each worker's directory and
verifies `expected/` is absent. The boundary is enforced by what is on disk, not
by asking politely — though the spec states the rule too, because a worker that
goes looking is itself a finding.

## The candidates, and why these four

Chosen to span billing lanes rather than capability tiers, because the question
is cost-effectiveness:

| key | model | lane |
|---|---|---|
| `codex` | Codex CLI default | ChatGPT plan |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | Copilot subscription |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | Copilot subscription |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | free |

Three of the four cost nothing per token beyond subscriptions already held. The
fourth is the exploration slot: an untested free model on a task with a strong
executed check, which is where a cheap experiment belongs.

`opencode` must be wired as an engine first — see `ENGINES.md`.

## What a failure means, and why several models run the same packet

Deliberately ambiguous, and that is the design. One worker missing a clause is a
weak worker. **Several workers missing the SAME clause is a hole in the
specification** — and the specification is the actual deliverable. Running one
model would leave the two indistinguishable.

This already paid before any model ran. Case `c07-guarded` was written straight
from §5's own example of a guarded arm, `n when n < 5 => :retried`. The compiler
answers `rebinding`: with `n` already bound as the parameter, the arm may not
rebind it. The specification offers that line as an illustration and never says
so. A clean-room implementer would write what was written here and be wrong, and
the packet is unchanged so that the audition records how many candidates hit it.
