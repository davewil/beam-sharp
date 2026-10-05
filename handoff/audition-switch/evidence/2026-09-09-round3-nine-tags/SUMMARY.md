# 2026-09-09-round3-nine-tags

Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or
the lane's `RECORD` and run it again.

**Attempt 1 is the clean-room score.** The final score is what the orchestrator
recorded, after any retry. A lane whose `attempts` is 2 was retried with
attempt 1's check output in its prompt.

| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |
|---|---|---|---|---|---|---|---|
| `codex` | `codex` | 12/13 visible, 11/12 held-out | 13/13 visible, 12/12 held-out, PASS | 2 | not reported | 714.1s | run.json `tasks[0]` |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | 13/13 visible, 7/12 held-out | 13/13 visible, 7/12 held-out, FAIL | 2 | 177433 | 1419.3s | run.json `tasks[3]` |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | 13/13 visible, 10/12 held-out | 13/13 visible, 10/12 held-out, FAIL | 2 | 209228 | 850.2s | run.json `tasks[2]` |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | no deliverable | no deliverable, FAIL | 2 | not reported | 4.0s | run.json `tasks[4]` |
| `grok` | `grok-4.6` | 12/13 visible, 11/12 held-out | 13/13 visible, 12/12 held-out, PASS | 2 | 2508407 | 2153.3s | run.json `tasks[1]` |
