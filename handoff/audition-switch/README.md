# Clean-room audition — the exhaustiveness checker

An audition for the question the handoff turns on: **which models can implement
B# from the specification alone, and at what cost?**

The slice is `switch`. It was chosen on evidence rather than taste — at the time
of choosing, §5 was 54 lines of specification carrying 19 tests, the densest
gate-per-spec-line ratio in the language. Pipelines, the runner-up, was 64 lines
with 13 tests and two tags. Switch is also the feature that exercises what B#
exists for: proven clause exhaustiveness.

<!-- The 54-line figure is kept as the reason for the CHOICE and is no longer a
     measurement of §5: it was already 78 lines by 2026-08-24 and is 217 after
     ENG-248 added the seven diagnostic examples. Re-measure before reusing it. -->

## What this evidence covers, and what it does not

**This is one slice of nineteen.** `LANGUAGE.md` has 19 numbered sections; the
packet ships **three** of them — §2, §3 and §5 — and the worker is asked for one
program, `switchcheck`, that reads a file and prints diagnostic tags.

A perfect score here is evidence that **the specification of `switch` transfers**.
It is not evidence that the language transfers. Nothing in this exercise touches
records, generics, the boundary, processes, binaries, pipelines, the module
system, or code generation — a worker scoring 15/15 has never emitted a `.beam`
file, and `switchcheck` is an analyser rather than a compiler.

Read a result here as: *a capable model, given three sections and eight worked
cases, reproduces this checker's behaviour on cases it has not seen.* Any
statement broader than that sentence is not supported by what is in this
directory.

The generalisation this is a down payment on — that the whole reference is
sufficient for a clean-room reimplementation — needs slices with a different
shape before it is believable: one that produces running code, and one whose
rules are spread across sections rather than concentrated in one.

**Seven diagnostics reachable, four of them marked.** This paragraph has been
wrong twice, in opposite directions, and both errors are instructive.

It first claimed six tags. Checked 2026-08-20, two of those six —
`unbound_variable` and `arg_not_accepted` — appeared **nowhere in
`LANGUAGE.md`**, and so nowhere in the packet; the count was corrected to four
*marked* against six *reachable*.

**Re-measured 2026-08-27 (ENG-248): there are seven, not six.** `switch_in_guard`
was missed by both earlier counts. It is asserted in the suite as a **bare atom**
— `{error, _, 'F', switch_in_guard}` — where the other six carry a payload —
`{error, _, 'Bad', {unbound_variable, w}}` — so any survey looking for
`{tag, ...}` sees six and reports a clean number. It was as unspecified as the
other two.

All seven are now stated in §5 with a worked example each, and the examples are
compiled on every CI run: `check-language.sh` asserts each block provokes that
diagnostic **and no other**, and `check-switch-diagnostics.sh` re-reads
`switch_tests.erl` to assert every diagnostic a `switch` can provoke has such an
example, inside a section the packet ships. The surface is re-measured rather
than listed, precisely because a list is what carried the miscount for a week.

**The marking still uses four tags**, and deliberately. `cases/` and
`expected/` are the measuring instrument; changing them invalidates the results
already recorded against them without producing replacements. The three
newly-specified diagnostics are now derivable from the packet — which is the
bar this file sets for a held-out case — so cases for them are the obvious next
increment, and they need a fresh engine run to be worth anything.

**The packet changed on 2026-08-27, and the scores below predate it.** §5 is
longer by seven examples, and `build-packet.py` now strips every HTML comment
except the `check:` blocks. Both are improvements to what a worker receives and
neither has been auditioned.

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
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | Copilot subscription | **7/8 visible, 7/7 held-out** — at 1/8 grok's tokens |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | Copilot subscription | **7/8 visible, 3/7 held-out** |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | free | **no measurement** — opencode's free tier errored server-side |

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
answers `rebinding`: `n` is already bound as the parameter, and a bare name in a
pattern *introduces* a name rather than matching one.

**The first two accounts of this — including the one that stood in this file —
were both wrong, and the corrected version is a better finding than either.**

They said the specification "never says so". It does, in §2, *inside the
packet*: *"To match against a value a name already holds, write `== name`. A
bare name in a pattern introduces a name."* And they blamed the **guard**, which
has nothing to do with it. Measured against the compiler on 2026-08-22:

| arm | verdict |
|---|---|
| `m when m < 5` — fresh name, guarded | clean |
| `< 5` — relational, no name | clean |
| `n => …` where `n` is the parameter, **no guard** | `rebinding` |
| `== n => …` | clean |

So the rule is about **bare names, not guards**, and it was stated correctly all
along. What was wrong was §5's *illustration*, which contradicted §2 seventy
lines away — and which sat in loose prose, not a fence, so `check-language.sh`
never compiled it and nothing could catch the drift.

**All three candidates that ran had §2's rule in front of them and reproduced
the illustration instead.** That is the finding: **a worked example outranks a
stated rule when the two disagree.** The audit this implies is *"which examples
contradict rules stated elsewhere"*, which is a different and harder sweep than
*"which rules are missing"*.

~~The packet is unchanged so that the audition records how many candidates hit
it.~~ **It recorded them: three of three, 2026-08-22.** That measurement is
spent, so §5 now carries the correct example in a **gated fence** and states the
rule where the example is. `c07` stays exactly as it was — still a rejected
program, now derivable from the packet rather than contradicted by it.

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
   is about: §5 illustrated a guarded arm with `n when n < 5 => :retried` beside
   a parameter already named `n`, which the compiler answers `rebinding`. The
   rule itself was in the packet all along, in §2 — see the corrected account
   above, and finding 9.
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

9. **Three lanes, one shared failure — and the visible set carried no
   information at all.** Round 1 finished 2026-08-22 with three uncontaminated
   measurements:

   | lane | visible | held-out | tokens | elapsed |
   |---|---|---|---|---|
   | `grok-4.6` | 7/8 | **7/7** | 1,452,444 | 936s |
   | `copilot-sonnet5` | 7/8 | **7/7** | 174,959 | 754s |
   | `copilot-haiku45` | 7/8 | **3/7** | 59,881 | 218s |

   **The visible column is identical across all three, on the same case.** It
   discriminated nothing; it measured the *specification*. The held-out column
   spread 7/7, 7/7, 3/7 and measured the *worker*. Marking only the staged set —
   which is what an audition without a held-out set is — would have reported
   three equivalent models.

   **All three failed `c07-guarded`.** This file's own rule decides what that
   means: one worker missing a clause is a weak worker, several missing the SAME
   clause is a hole in the specification. Three of three, so §5 was fixed — see
   the corrected account above.

   Sonnet-5 matched grok's held-out score at **an eighth of the tokens**, which
   is the cost answer the audition was set up to get. Haiku's four misses run
   one way: it says `clean` where the compiler diagnoses (`h02`, `h04`, `h05`,
   `h06`). Under-reporting rather than crying wolf — the safer direction, and
   still a fitted implementation.

10. **The leak fired on the second lane, from a `check.sh` four commits stale.**
    Finding 8's redaction was committed and correct, and the run never reached
    it: `manifest.json`'s `check` named the **main checkout** by absolute path
    while the harness was being developed in a worktree. `copilot-haiku45` was
    handed `h02`, `h04` and `h05` in its retry prompt, 18–19 mentions across its
    log, and its own closing summary lists them by name. Kept as
    `evidence/2026-08-22-round1/copilot-haiku45-LEAKED/`.

    **Re-run clean, it scored 3/7 held-out where the leaked run scored 4/7.**
    Being told three answers bought one held-out case and took the visible score
    to a perfect 8/8 — a run that looked better on every number a reader would
    check. It also *regressed* `h04`, the case it had just been told about, and
    newly broke `h01` and `h03`. **A leaked run is not the same measurement
    flattered; it is a different experiment** — one measuring whether a model can
    patch toward a failing test list, which bears no fixed relation to whether it
    can implement the specification.

    Fixed at the root: `stage.sh` now emits `manifest.run.json` binding every
    `check` to the harness that staged it, so scoring with a different copy is
    unrepresentable rather than merely unlikely. `build-run-manifest.py` states
    the reasoning and cites `build-packet.py`, which had already written the rule
    it obeys — **a hand-edited copy drifts from what it copies.** The path was
    the last hand-edited copy in this directory.

11. **The spec fix was verified, and the prediction was exact.** `§5`'s
    illustration was replaced with a **gated fence** using a fresh name, and the
    rule was stated beside the example rather than seventy lines away in §2.
    `check-language.sh` went from 37 blocks to **38, 37 ok** — the example is
    now compiled on every CI run and cannot rot again in the way it did.

    `copilot-sonnet5` was re-run against the regenerated packet. It had failed
    exactly one case before, so the prediction was falsifiable and stated in
    advance: 8/8 visible, 7/7 held-out.

    | | visible | held-out | attempts |
    |---|---|---|---|
    | before the fix | 7/8 — missed `c07` | 7/7 | 2 |
    | **after the fix** | **8/8** | **7/7** | **1** |

    **Fifteen of fifteen, first attempt, no retry** — so no possibility of the
    finding-8 contamination. Evidence in
    `evidence/2026-08-22-round2-after-spec-fix/`.

    This is the first end-to-end demonstration of what the audition is *for*.
    A defect was found in the deliverable by several workers failing the same
    case; the deliverable was corrected; a worker then reproduced the slice
    exactly. The loop closed, and what it closed on was a **worked example**, not
    a missing rule — the thing three capable models could not reason past even
    with the correct rule in front of them.

## Owed, and now sharper

- **The example audit.** Finding 9's lesson generalises: the sweep worth running
  is *"which examples contradict rules stated elsewhere"*, and the mechanism that
  let this one survive is knowable — it sat in **loose prose rather than a
  fence**, where `check-language.sh` cannot reach. Every ungated code fragment in
  `LANGUAGE.md` is a candidate. 46 of its 84 fences are bare and ungated.
- ~~**`unbound_variable` and `arg_not_accepted`** remain genuinely
  unspecified.~~ **Closed 2026-08-27 (ENG-248)**, along with `switch_in_guard`,
  which this list did not know about. All three are stated in §5 with a compiled
  example, and a gate now asserts the set is complete rather than a reader
  checking it. See the corrected count at the top of this file.
- ~~**`h05`.** §5 says the catch-all-over-closed rule "is decided and is **not
  yet enforced**"; the compiler rejects the program anyway.~~ **Already false
  when this bullet was written.** F2 enforced the rule on 2026-08-16 and the
  sentence was corrected on 2026-08-24 — `LANGUAGE.md:578` now reads "**shipped**,
  at a switch arm and at a clause head alike", and carries a comment recording
  that it had been wrong for eight days. This bullet outlived the defect it
  named by three days, which is the same failure one level up: a finding is only
  closed when the file that records it says so.
