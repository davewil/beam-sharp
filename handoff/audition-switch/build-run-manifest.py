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
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
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
