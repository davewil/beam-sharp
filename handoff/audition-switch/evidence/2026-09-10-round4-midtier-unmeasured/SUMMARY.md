# 2026-09-10-round4-midtier-unmeasured

Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or
the lane's `RECORD` and run it again.

**Attempt 1 is the clean-room score.** The final score is what the orchestrator
recorded, after any retry. A lane whose `attempts` is 2 was retried with
attempt 1's check output in its prompt.

| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |
|---|---|---|---|---|---|---|---|
| `codex` | `gpt-6-astra` | 12/13 visible, 11/12 held-out | 13/13 visible, 12/12 held-out, PASS | 2 | not reported | 647.0s | run.json `tasks[0]` |
| `codex-luna` | `gpt-5.6-luna` | no deliverable | no deliverable, FAIL | 2 | not reported | 7.0s | run.json `tasks[7]` |
| `codex-sol` | `gpt-5.6-sol` | no deliverable | no deliverable, FAIL | 2 | not reported | 108.2s | run.json `tasks[5]` |
| `codex-terra` | `gpt-5.6-terra` | no deliverable | no deliverable, FAIL | 2 | not reported | 7.6s | run.json `tasks[6]` |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | 13/13 visible, 8/12 held-out | 13/13 visible, 9/12 held-out, FAIL | 2 | 99034 | 1156.1s | run.json `tasks[3]` |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | 12/13 visible, 10/12 held-out | 13/13 visible, 11/12 held-out, FAIL | 2 | 204422 | 867.1s | run.json `tasks[2]` |
| `grok` | `grok-4.6` | 12/13 visible, 11/12 held-out | 13/13 visible, 12/12 held-out, PASS | 2 | 3984436 | 2295.9s | run.json `tasks[1]` |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | no `worker.log` archived | no deliverable, FAIL | 2 | not reported | 3.7s | run.json `tasks[4]` |
