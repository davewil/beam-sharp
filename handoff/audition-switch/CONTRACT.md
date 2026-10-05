# What an audition orchestrator has to do

The audition hands a worker a packet, lets it build one program blind, and marks
that program against the reference compiler. Any tool that starts the workers
and collects their results can run it. The author used `ringer.py`; it is one
orchestrator that meets the terms below, and nothing here depends on it.

The harness that implements these terms is three shell scripts beside the
audition's README in the repository: `stage.sh`, `run.sh` and `check.sh`. They
do not ship in the handoff package. This file does, so that a recipient can
build their own.

Each term is here because the audition was run once without it and produced a
number that meant something else.

## Staging

- **One working directory per candidate, holding the packet and the visible
  cases and nothing else.** `PACKET.md` and `cases/`.
- **Neither answer set is reachable from it.** There are two: `expected/`, the
  tags the reference compiler gives for every case, and `heldout/`, the cases
  the worker never sees. Check this on disk after staging. A staged `heldout/`
  does not look like a leak in the results; the worker simply scores well.
- **A fresh root for every run.** A fixed path shared between runs lets a re-run
  read what a killed one left behind.
- **The marking is bound to the tree that staged.** Whatever names the check for
  each candidate must point at the copy of the harness the sandboxes were staged
  from. On 2026-08-22 it pointed at a checkout four commits older, and a worker
  was sent three held-out answers.
- **Count the staged cases.** A tree behind the current one stages fewer cases
  than the answer key holds, and every worker is then marked on diagnostics its
  packet told it not to print.

## Running

- **The worker's standard input is closed.** With it attached, agent CLIs wait
  on a prompt that never comes: nothing fails and the run never ends.
- **Every candidate has a deadline, and the whole process group is killed at
  it.** Some CLIs write their deliverable and then never exit. The author's runs
  allow 1800 seconds.
- **The worker gets the packet's own instructions and no more**: work only in
  its directory, alone, with no network and no package installs.

## The deliverable

An executable named `switchcheck` in the candidate's working directory, run as

    ./switchcheck <path-to-.bs-file>

It prints one lowercase diagnostic tag per line on standard output and nothing
else, and prints nothing for a well-formed program. The packet lists the tags it
may print.

## Marking

- **The set of tags is compared, case by case, with what the reference compiler
  says.** A missing tag and an invented one both fail, and so does any output
  for a clean program.
- **The visible cases and the held-out cases are scored separately and reported
  separately.** The path of a visible case names the case, so a lookup table
  scores full marks on the visible set. Only the held-out score says the
  specification was implemented.
- **The verdict is the exit status**: zero when every case in both sets agrees.
- **Held-out detail is withheld from the default output.** It reports how many
  held-out cases disagreed and not which. The full detail is for a person
  reading the results afterwards, behind an explicit flag (`--reveal` in the
  author's harness).
- **A retry prompt carries only the default output.** An orchestrator that
  retries a failed candidate with the check's output in the prompt must never
  pass the revealed form.

## Attempts

**Attempt 1 is the clean-room score.** A retry that quotes the check's output has
been told which visible cases it got wrong, so its score measures the retry and
not the packet. Record both and report attempt 1.

## Evidence

Keep, for each candidate in each round:

- the orchestrator's record: the verdict, the number of attempts, tokens,
  elapsed time, and the end of the check's output;
- the worker's log, complete, including any retry prompt;
- the `switchcheck` it delivered.

A zero from a candidate that never ran, on a usage limit or a provider error, is
the same number as a zero from one that ran badly. Only the log tells them
apart, so it is kept.

## The author's orchestrator

`ringer.py` reads a manifest of tasks, one per candidate, each with the worker's
prompt, the check command, the files expected and the deadline. `stage.sh`
writes that manifest bound to the staged tree. `ENGINES.md`, beside the README,
is the configuration that connects Ringer to one more agent CLI. It belongs to
that orchestrator and is not a step in running the audition.
