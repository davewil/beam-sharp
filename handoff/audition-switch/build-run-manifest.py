#!/usr/bin/env python3
"""Bind a run manifest's `check` commands to the harness that generated it.

WHY THIS EXISTS (2026-08-22)

`manifest.json` carried an absolute path to `check.sh`. It named the main
checkout, which on the day was four commits behind the worktree where the
harness was being developed -- so the run scored against a `check.sh` that
lacked the held-out redaction, and `copilot-haiku45` received three held-out
case names and their expected tags in its retry prompt. The redaction was
committed and correct. It simply was not where the run read from.

`build-packet.py` had already written the rule this file obeys: the packet is
built rather than maintained because "a hand-edited copy of the specification
drifts from the specification". An absolute path is a copy too, and drifts the
same way.

WHAT IT GUARANTEES, AND WHAT IT DOES NOT

Guaranteed: every `check` in the emitted manifest invokes the `check.sh` sitting
beside THIS script, and scores the sandbox under the workdir that was just
staged. Staging from a tree therefore scores with that tree's harness -- the
divergence above becomes unrepresentable rather than merely unlikely.

Not guaranteed: that the harness is itself correct, current, or committed. That
is what `check.sh --self-test` and the stamp it prints are for. This closes one
channel; it is not a general staleness check.

Environment: HARNESS (this directory), WORKDIR (staged root), OUT (destination).

THE SECOND MODE: `--summaries [EVIDENCE_DIR]` (2026-10-05)

Writes a `SUMMARY.md` into every `2026-*` round directory under `evidence/`,
one row per lane. `stage.sh` runs it, so a round archived since the last stage
gets its summary when the next one is staged; `--summaries --check` writes
nothing and exits 1 if any round's summary is missing or stale.

A lane's machine record is found in this order: a `RECORD` file in the lane
whose `machine-record:` line names a `run.json` and a task index; the lane's own
`run.json`; the round's `run.json`. The orchestrator's record holds only the
LAST attempt, and attempt 1 is the clean-room measurement, so that score is read
from the lane's `worker.log`, where the retry prompt quotes attempt 1's check
output between `attempt 1 exited` and `Fix it`. A lane with one attempt has no
retry prompt and its record is the clean-room score. The log also holds the
worker's own output, so a log quoting two different scores is reported as
conflicting and neither is chosen.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SCORE = re.compile(r"visible\s+(\d+/\d+)\s+held-out\s+(\d+/\d+)")
# A quoted retry prompt runs from the marker to `Fix it` and crosses no other
# marker, so a forged marker printed ahead of the real one is cut off by it
# and cannot lend its score to the real prompt's span.
RETRY = re.compile(
    r"\[ringer\.py\] attempt 1 exited rc=-?\d+\n"
    r"((?:(?!\[ringer\.py\] attempt \d+ exited).)*?)Fix it", re.S)
NO_DELIVERABLE = "no executable ./switchcheck"
POINTER = re.compile(r"^machine-record:\s*(\S+)\s+tasks\[(\d+)\]", re.M)


def score(text: str) -> str:
    found = SCORE.findall(text)
    if found:
        return f"{found[-1][0]} visible, {found[-1][1]} held-out"
    if NO_DELIVERABLE in text:
        return "no deliverable"
    return "not in the record"


def readings(text: str) -> set:
    """Every outcome a stretch of log states, so two that differ can be seen."""
    found = {f"{v} visible, {h} held-out" for v, h in SCORE.findall(text)}
    if NO_DELIVERABLE in text:
        found.add("no deliverable")
    return found


def machine_record(lane: Path, name: str, round_dir: Path):
    """The task dict for a lane, and where it was read from."""
    note = lane / "RECORD"
    if note.is_file():
        pointer = POINTER.search(note.read_text())
        if pointer:
            src = (lane / pointer.group(1)).resolve()
            index = int(pointer.group(2))
            where = f"{os.path.relpath(src, round_dir)} `tasks[{index}]`"
            return json.loads(src.read_text())["tasks"][index], where
    for src in (lane / "run.json", round_dir / "run.json"):
        if not src.is_file():
            continue
        tasks = json.loads(src.read_text()).get("tasks", [])
        keyed = [(i, t) for i, t in enumerate(tasks) if t.get("key") == name]
        if not keyed and src.parent == lane and len(tasks) == 1:
            keyed = [(0, tasks[0])]
        if keyed:
            index, task = keyed[0]
            return task, f"{os.path.relpath(src, round_dir)} `tasks[{index}]`"
    return None, "none"


def first_attempt(lane: Path, task) -> str:
    if task and task.get("attempts") == 1:
        return score(task.get("check_output_tail") or "")
    log = lane / "worker.log"
    if not log.is_file():
        return "no `worker.log` archived"
    # The worker's own output is in this file too, so a worker can print a
    # retry prompt of its own. The real one is always there beside it, and two
    # different outcomes are reported as a conflict, never resolved by position:
    # not between prompts, and not within one.
    quoted = set()
    for prompt in RETRY.findall(log.read_text(errors="replace")):
        quoted |= readings(prompt)
    if not quoted:
        return "not in `worker.log`"
    return quoted.pop() if len(quoted) == 1 else "conflicting in `worker.log`"


def summary(round_dir: Path) -> str:
    lanes = sorted(p.name for p in round_dir.iterdir() if p.is_dir())
    shared = round_dir / "run.json"
    if shared.is_file():
        for task in json.loads(shared.read_text()).get("tasks", []):
            if task.get("key") not in lanes:
                lanes.append(task["key"])
    rows = []
    for name in lanes:
        lane = round_dir / name
        task, where = machine_record(lane, name, round_dir)
        if (lane / "RECORD").is_file():
            where += f"; read [`RECORD`]({name}/RECORD)"
        if task is None:
            rows.append(f"| `{name}` | | {first_attempt(lane, None)} | no machine record "
                        f"| | | | {where} |")
            continue
        tokens = task.get("tokens")
        rows.append(
            f"| `{name}` | `{task.get('model') or task.get('engine')}` "
            f"| {first_attempt(lane, task)} "
            f"| {score(task.get('check_output_tail') or '')}, {task.get('verdict')} "
            f"| {task.get('attempts')} "
            f"| {tokens if tokens is not None else 'not reported'} "
            f"| {task.get('elapsed_s')}s | {where} |")
    return "\n".join([
        f"# {round_dir.name}",
        "",
        "Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or",
        "the lane's `RECORD` and run it again.",
        "",
        "**Attempt 1 is the clean-room score.** The final score is what the orchestrator",
        "recorded, after any retry. A lane whose `attempts` is 2 was retried with",
        "attempt 1's check output in its prompt. That prompt is quoted in the lane's",
        "`worker.log`, which is where the attempt 1 column is read from. The worker's",
        "own output is in that log as well, so the column is the log's word and not",
        "the orchestrator's: two different quoted scores are shown as conflicting.",
        "",
        "| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |",
        "|---|---|---|---|---|---|---|---|",
        *rows,
        "",
    ])


def summaries(evidence: Path, check: bool) -> int:
    # Resolved once, so a summary reads the same through a symlinked harness
    # and names no path outside its round.
    evidence = evidence.resolve()
    stale = []
    for round_dir in sorted(evidence.glob("2026-*")):
        if not round_dir.is_dir():
            continue
        out = round_dir / "SUMMARY.md"
        text = summary(round_dir)
        if out.is_file() and out.read_text() == text:
            continue
        stale.append(out)
        if not check:
            out.write_text(text)
            print(f"wrote {out}")
    if check and stale:
        for out in stale:
            print(f"missing or stale: {out}")
        return 1
    return 0


def main() -> int:
    if "--summaries" in sys.argv[1:]:
        paths = [a for a in sys.argv[1:] if not a.startswith("--")]
        evidence = Path(paths[0]) if paths else Path(__file__).resolve().parent / "evidence"
        return summaries(evidence, "--check" in sys.argv[1:])
    try:
        src = Path(sys.argv[1])
        harness = Path(os.environ["HARNESS"]).resolve()
        workdir = Path(os.environ["WORKDIR"])
        out = Path(os.environ["OUT"])
    except (IndexError, KeyError) as exc:
        print(f"usage: HARNESS=... WORKDIR=... OUT=... {sys.argv[0]} <manifest.json>")
        print(f"  missing: {exc}")
        return 2

    check_sh = harness / "check.sh"
    if not os.access(check_sh, os.X_OK):
        print(f"no executable check.sh beside this script ({check_sh})")
        return 1

    manifest = json.loads(src.read_text())

    # The workdir is rewritten too. A manifest whose `check` pointed at this
    # harness but whose sandbox path pointed at a workdir nobody staged would
    # score an empty or stale directory -- the same class of defect one level
    # along, and it costs one line to close.
    manifest["workdir"] = str(workdir)
    for task in manifest.get("tasks", []):
        task["check"] = f'{check_sh} {workdir / task["key"]}'

    out.write_text(json.dumps(manifest, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
