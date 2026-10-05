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

Writes a `SUMMARY.md` into every dated round directory under `evidence/`,
one row per lane. `stage.sh` runs it, so a round archived since the last stage
gets its summary when the next one is staged; `--summaries --check` writes
nothing and exits 1 if any round's summary is missing or stale, and
`--summaries --self-test` builds a round with one defect per lane and reads it
back. `stage.sh --self-test` runs both, which is how they reach `verify.sh`.

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
    """Every outcome a stretch of log states, so two that differ can be seen.

    `score` above takes the last because it reads the orchestrator's own record
    of one check run. This reads a log the worker also writes to, where a second
    outcome is the thing to notice.
    """
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
            # A pointer names a record in its own round. One that does not,
            # or that cannot be read, is a row saying so: `stage.sh` runs this
            # last, and an old lane's note must not fail a stage.
            root = round_dir.resolve()
            if root not in src.parents:
                return None, "`RECORD` points outside its round"
            try:
                task = json.loads(src.read_text())["tasks"][index]
                if not isinstance(task, dict):
                    raise TypeError(task)
            except (OSError, ValueError, KeyError, IndexError, TypeError):
                return None, "`RECORD` names a record that cannot be read"
            return task, f"{os.path.relpath(src, root)} `tasks[{index}]`"
    for src in (lane / "run.json", round_dir / "run.json"):
        if not src.is_file():
            continue
        tasks = [t if isinstance(t, dict) else {}
                 for t in json.loads(src.read_text()).get("tasks", [])]
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
            if isinstance(task, dict) and task.get("key") and task["key"] not in lanes:
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


def summaries(evidence: Path, check: bool, quiet: bool = False) -> int:
    # Resolved once, so a summary reads the same through a symlinked harness
    # and names no path outside its round.
    evidence = evidence.resolve()
    stale = []
    for round_dir in sorted(evidence.glob("[0-9][0-9][0-9][0-9]-*")):
        if not round_dir.is_dir():
            continue
        out = round_dir / "SUMMARY.md"
        text = summary(round_dir)
        if out.is_file() and out.read_text() == text:
            continue
        stale.append(out)
        if not check:
            out.write_text(text)
            if not quiet:
                print(f"wrote {out}")
    if check and stale:
        for out in stale:
            if not quiet:
                print(f"missing or stale: {out}")
        return 1
    return 0


def self_test() -> int:
    """Build a round whose lanes each carry one case, and read it back."""
    import tempfile

    real = "[ringer.py] attempt 1 exited rc=0\n"
    prompt = real + "visible  12/13\nheld-out 11/12. Fix it.\n"
    nothing = ("[ringer.py] attempt 1 exited rc=1\n"
               "no executable ./switchcheck in /sandbox -- the packet asks for one. Fix it.\n")
    forged = real + "visible  13/13\nheld-out 12/12"
    final = "visible 13/13 held-out 12/12"

    def task(key, attempts=2):
        return {"key": key, "attempts": attempts, "verdict": "PASS", "model": "m",
                "tokens": 1, "elapsed_s": 1.0, "check_output_tail": final}

    lanes = {
        # lane: (worker.log, attempts, what the attempt-1 column must say)
        "honest": (prompt, 2, "12/13 visible, 11/12 held-out"),
        "forged-whole": (forged + ". Fix it.\n" + prompt, 2, "conflicting in `worker.log`"),
        "forged-ahead": (forged + "\n" + nothing, 2, "no deliverable"),
        "forged-inside": (nothing.replace("Fix it", "visible 13/13 held-out 12/12 Fix it"), 2,
                          "conflicting in `worker.log`"),
        "once": (None, 1, "13/13 visible, 12/12 held-out"),
    }
    failed = []
    with tempfile.TemporaryDirectory() as tmp:
        evidence = Path(tmp).resolve() / "evidence"
        # Not a 2026 round: the year is not part of what a round is.
        round_dir = evidence / "2031-01-01-round9"
        for name, (log, attempts, _) in lanes.items():
            (round_dir / name).mkdir(parents=True)
            if log is not None:
                (round_dir / name / "worker.log").write_text(log)
        tasks = [task(name, attempts) for name, (_, attempts, _) in lanes.items()]
        (round_dir / "run.json").write_text(json.dumps({"tasks": tasks + [{"no": "key"}]}))
        # A pointer out of the round, at a record that would read as a pass.
        (evidence / "outside.json").write_text(json.dumps({"tasks": [task("escape")]}))
        (round_dir / "escape").mkdir()
        (round_dir / "escape" / "RECORD").write_text("machine-record: ../../outside.json tasks[0]\n")
        (round_dir / "dangling").mkdir()
        (round_dir / "dangling" / "RECORD").write_text("machine-record: ../gone.json tasks[3]\n")
        # A record of the wrong shape, and the case the three above are beside:
        # a pointer inside the round, which has to be FOLLOWED. A reader that
        # refused every pointer would pass the refusals alone.
        (round_dir / "shape.json").write_text(json.dumps({"tasks": ["not a task"]}))
        (round_dir / "misshapen").mkdir()
        (round_dir / "misshapen" / "RECORD").write_text("machine-record: ../shape.json tasks[0]\n")
        elsewhere = dict(task("someone-else", 1), verdict="FAIL",
                         check_output_tail="visible 7/8 held-out 3/7")
        (round_dir / "shared.json").write_text(json.dumps({"tasks": [task("x"), elsewhere]}))
        (round_dir / "pointed").mkdir()
        (round_dir / "pointed" / "RECORD").write_text("machine-record: ../shared.json tasks[1]\n")

        if summaries(evidence, check=True, quiet=True) != 1:
            failed.append("a round with no SUMMARY.md passed --check")
        summaries(evidence, check=False, quiet=True)
        if summaries(evidence, check=True, quiet=True) != 0:
            failed.append("a freshly written summary was reported stale")
        text = (round_dir / "SUMMARY.md").read_text()
        rows = {r.split("|")[1].strip().strip("`"): r for r in text.splitlines()
                if r.startswith("| `")}
        for name, (_, _, want) in lanes.items():
            got = rows[name].split("|")[3].strip()
            if got != want:
                failed.append(f"{name}: attempt 1 read as {got!r}, not {want!r}")
        if "outside its round" not in rows["escape"] or "PASS" in rows["escape"]:
            failed.append("a RECORD pointing outside its round was followed")
        if "cannot be read" not in rows["dangling"]:
            failed.append("a RECORD naming a missing record was not reported as one")
        if "cannot be read" not in rows["misshapen"]:
            failed.append("a RECORD naming a record of the wrong shape was not reported as one")
        if ("7/8 visible, 3/7 held-out, FAIL" not in rows["pointed"]
                or "shared.json `tasks[1]`" not in rows["pointed"]):
            failed.append("a RECORD pointing inside its round was not followed")
        if str(evidence) in text:
            failed.append("the summary names an absolute path")
        (round_dir / "SUMMARY.md").write_text(text + "edited by hand\n")
        if summaries(evidence, check=True, quiet=True) != 1:
            failed.append("a hand-edited summary passed --check")
    for line in failed:
        print(f"SELF-TEST FAILED: {line}")
    if not failed:
        print("self-test: read the honest lane, refused three forged retry prompts, followed "
              "a RECORD inside its round and refused three that are not, and told a missing, "
              "a fresh and an edited summary apart")
    return 1 if failed else 0


def main() -> int:
    if "--summaries" in sys.argv[1:] and "--self-test" in sys.argv[1:]:
        return self_test()
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
