# Clean-room audition — the exhaustiveness checker

An audition for the question the handoff turns on: **which models can implement
B# from the specification alone, and at what cost?**

The slice is `switch`. It was chosen on evidence rather than taste — §5 is 54
lines of specification carrying 19 tests, the densest gate-per-spec-line ratio
in the language. Pipelines, the runner-up, is 64 lines with 13 tests and two
tags. Switch is also the feature that exercises what B# exists for: proven
clause exhaustiveness.

**Four diagnostic tags, not six.** This paragraph claimed six —
`switch_inexhaustive`, `unreachable_arm`, `rebinding`, `return_not_declared`,
plus `unbound_variable` and `arg_not_accepted`. Checked 2026-08-20: the last two
appear **nowhere in `LANGUAGE.md`**, and so nowhere in the packet, which lists
only four. They are real and they are switch-specific — `switch_tests.erl:175`
has `arg_not_accepted` on an arm that calls a function with a refined value, and
`switch_tests.erl:221` has `unbound_variable` on an arm referencing a name bound
in a *different* arm — but the compiler emits them and the specification never
names them.

That gap is the deliverable's problem, not the audition's: **two of the six
diagnostics a clean-room implementer must reproduce are unspecified**, and no
reader of the spec could know they exist. They are deliberately kept out of the
cases, because a case whose answer the packet does not imply measures the
specification's holes rather than the worker's. They belong in **Findings**
below, and they are owed a paragraph in §5 before the spec ships.

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

**Two sets are marked, and only one is staged.** `cases/` goes into the worker's
sandbox; `heldout/` never leaves this directory and is not mentioned in the
packet. Both are scored, and the scores are printed separately:

```
visible  8/8
held-out 2/7
```

The split exists because the tag-set rule above, on its own, still could not
tell knowing from guessing. `check.sh` invokes the worker with the case's own
path — `cases/c03-inexhaustive/Missing/in.bs` — so the case's **identity is in
argv[1]**, and those directory names are sitting in the worker's sandbox.
Measured 2026-08-20: a stub that never opens the file and merely switches on
that name scores a perfect 8/8. It is now the third control in
`check.sh --self-test`, and it is caught by a held-out case or not at all.

The same measurement on a real submission is in `evidence/`: 8/8 visible, 2/7
held-out — the identical held-out score as the stub that parses nothing. **The
visible set alone would have called it a clean sweep.** Held-out cases are held
to a stricter standard than visible ones: each must be derivable from the
packet, or it measures the specification rather than the worker.

## Running it

```sh
./oracle.sh                      # record expectations for cases/ AND heldout/
./check.sh --self-test           # prove the check can fail before trusting it
./check.sh <dir>                 # score one submission: visible, then held-out
./stage.sh /tmp/bsharp-audition  # one sandbox per candidate; neither answer set
ringer.py lint  manifest.json
ringer.py run   manifest.json --identity <who-you-are>
```

`stage.sh` copies `PACKET.md` and `cases/` into each worker's directory and
verifies that **neither `expected/` nor `heldout/`** is reachable from it. The
boundary is enforced by what is on disk, not by asking politely — though the
spec states the rule too, because a worker that goes looking is itself a
finding.

There are two secrets, and the leak check names both. Staging `heldout/` would
not look like a leak from the results — the worker would simply score well — so
it has to be caught on disk rather than noticed in a number.

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

## The held-out set

Seven cases, none staged, every expectation recorded by `oracle.sh` rather than
typed. Each is derivable from the packet — the third column names the sentence
that decides it — and each is structurally unlike anything in `cases/`, because
a held-out case that rhymes with a visible one tests nothing new.

| case | compiler says | derivable from |
|---|---|---|
| `h01-interval-exhaustive` | *clean* | §2: three integer intervals are exhaustive "with no catch-all, because the checker carries real integer intervals" |
| `h02-interval-gap` | `switch_inexhaustive` | the same rule, with 10 through 99 left uncovered |
| `h03-span-exhaustive` | *clean* | §2's own worked span example, `>= 4 and <= 7` and the rest |
| `h04-matched-name` | `switch_inexhaustive` | §2: "a `switch` whose only non-catch-all arm matches a name is inexhaustive over the whole subject type" |
| `h05-catchall-over-closed` | `unreachable_arm` | §5's `_` rule, reached from the other side — both arms of a closed type are covered, so `_` matches nothing |
| `h06-tuple-mixed` | `switch_inexhaustive` | §5's tuple subject, with a closed type on one axis rather than two `bool`s |
| `h07-atom-return` | `return_not_declared` | §2's mandatory signature, with an `int` arm under an `atom` return |

**`h05` deserves a note.** §5 says the catch-all-over-closed rule "is decided and
is **not yet enforced**", which invites a worker to expect silence. The compiler
rejects the program anyway, as `unreachable_arm` — a different rule arriving at
the same place. The answer stays derivable, so the case is fair, but the packet
sentence is closer to misleading than it reads, and it is worth revisiting when
§5 is next edited.

## Findings

Recorded 2026-08-20, before any candidate has been marked under this harness.
Numbers 1 and 2 are about the audition; 3 and 4 are about the specification,
which is the actual deliverable.

1. **The visible cases could not tell an implementation from a lookup table.**
   `check.sh` passes the case's identity in `argv[1]`, and the case directory
   names sit in every worker's sandbox. A stub that parses nothing scored 8/8.
   Fixed by `heldout/`, and the stub is now a permanent control in the
   self-test — delete the held-out set and the self-test goes red.

2. **The one real submission that survives scored 8/8 visible and 2/7 held-out**
   — the same held-out score as that stub. See `evidence/`. It never
   implemented integer intervals, though §2 works them through twice. Its
   provenance is unrecoverable because the sandboxes were reaped; **keep the
   logs on the next run**, not least because its own source claims a suppression
   rule the packet never states.

3. **Two of the six switch diagnostics are unspecified.** `unbound_variable` and
   `arg_not_accepted` are emitted by the compiler for `switch` programs and
   appear nowhere in `LANGUAGE.md`. No clean-room implementer can produce a
   diagnostic the specification does not mention. Owed: a paragraph in §5.

4. **`c07-guarded` remains unresolved and unchanged**, for the reason given
   above — and the audition still cannot say whether a candidate that fails it
   read the spec badly or read it correctly. That was always the design; it is
   restated here because finding 2 shows the answer can also be arrived at
   without reasoning at all.

**No candidate has been run under this harness.** The four lanes cost real
allowance on finite plans, and `run.sh`'s own comments record a lane returning
`402 Payment Required` mid-run. Everything above was measured against the
recovered submission and against synthetic stubs; a fresh run is a separate
decision.
