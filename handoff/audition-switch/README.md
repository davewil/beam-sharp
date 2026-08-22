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

| key | model | lane | round 1 (2026-08-22) |
|---|---|---|---|
| `codex` | Codex CLI default | ChatGPT plan | **no measurement** — usage limit, retry 25 Aug |
| `grok` | `grok-4.6` | SuperGrok / X Premium | **7/8 visible, 7/7 held-out first try** |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | Copilot subscription | not yet run |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | Copilot subscription | not yet run |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | free | not yet run |

Four of the five cost nothing per token beyond subscriptions already held. The
last is the exploration slot: an untested free model on a task with a strong
executed check, which is where a cheap experiment belongs.

**`grok` joined on 2026-08-22** because `codex` could not bill (finding 5) and a
lane that cannot bill is not a weak candidate — it is no measurement at all. Its
model id had to be corrected too: the engine block named
`grok-composer-2.5-fast`, which `grok models` no longer offers.

`opencode` must be wired as an engine first — see `ENGINES.md`, whose block was
itself wrong until finding 6.

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

~~**No candidate has been run under this harness.**~~ **Candidates began running
2026-08-22** (David: *"run the four audition candidates and keep the logs"*).
Findings 5 and 6 are what the first two lanes produced, and neither is about the
language.

5. **Two of the four lanes could not bill or could not launch, and the harness
   correctly refused to score either as a result.** `codex` returned *"You've hit
   your usage limit … try again at Aug 25th, 2026 1:44 PM"* on both attempts and
   exited in 12.1s having never opened `PACKET.md`; `grok` was substituted for it
   on David's call, and failed twice more in 4.0s on *"unknown model id"* — the
   engine block's `grok-composer-2.5-fast` and `grok-build` are both retired, and
   `grok models` now offers only `grok-4.6` and `grok-4.5`. **The check reported
   `missing expected files: switchcheck` rather than 0/8**, which is the
   difference between a billing event and a capability measurement; a harness
   that scored the empty sandbox would have entered a *model* verdict in the
   scoreboard for something no model ever saw. `run.sh`'s comment about a lane
   returning `402` was not a historical note.

6. **`ENGINES.md`'s wiring block had never been run, and was wrong three ways**
   — a schema Ringer does not have, `--cwd` for what `opencode run --help` calls
   `--dir`, and a `timeout_s` that belongs on the task. Corrected in place, with
   the reasoning kept beside it. It is the audition's own setup notes failing the
   test the audition administers: **an instruction is believed only once it has
   been seen to run.** The three `opencode` lanes stayed blocked until the
   corrected block was pasted, because `~/.config/ringer/config.toml` is the
   human's file by design and this document says so.

7. **The specification IS implementable from the packet alone — measured, not
   hoped.** `grok-4.6` scored **7/8 visible and 7/7 held-out on its FIRST
   attempt**, and the single miss was `c07-guarded`. That is the case finding 4
   is about: §5 offers `n when n < 5 => :retried` as an illustration of a guarded
   arm, the compiler answers `rebinding`, and the specification never says so.
   **The one thing a clean-room worker got wrong is the one thing the
   specification teaches wrongly.** Nothing else in fifteen cases disagreed —
   including all three interval cases (`h01`–`h03`), which is precisely what the
   earlier recovered submission never implemented despite §2 working them twice.

   Read against finding 2 this reverses the picture. 2/7 held-out was not
   evidence that the packet is unimplementable; it was evidence about one
   worker. **Two submissions on the identical packet now disagree by five
   held-out cases**, which is the spread the audition was built to expose and the
   reason it insists on several models rather than one.

   It passed on attempt 2 (8/8) — but that number is worth less, because Ringer
   injects the check's failure output into the retry prompt, so attempt 2 had
   been *told* c07's answer. **Attempt 1 is the clean-room measurement; attempt 2
   is a measurement of the retry loop.** Evidence, including both attempts, the
   1,711-line submission and the run record:
   [`evidence/2026-08-22-round1/`](evidence/2026-08-22-round1/).

8. **The marker could read the exam out to the worker, and nobody had drawn that
   channel.** Since the retry prompt is built from `check.sh`'s failure output,
   and `compare` prints `<case> compiler says [<tag>]`, a worker that fails a
   **held-out** case on attempt 1 is handed that case's name and its answer for
   attempt 2. It is self-selecting: the workers who trip it are exactly the ones
   the held-out set exists to catch.

   **It did not fire this round** — grok failed only a visible case, and no `h0*`
   string appears anywhere in its worker log — which is the only reason finding
   7's numbers stand. Fixed: held-out detail is withheld by default and the count
   still prints, so the visible/held-out gap survives; `--reveal` restores it for
   a human reading results afterwards, where the output goes to a person rather
   than into a prompt. Control 6 in `--self-test` proves both halves.

   This is finding 1 in the mirror direction — that one leaked case identity
   *into* the sandbox through argv, this leaked identity and answer *out* through
   the marker. Both were channels nobody drew, which is now twice.
