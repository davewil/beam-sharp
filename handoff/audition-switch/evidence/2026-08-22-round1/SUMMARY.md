# 2026-08-22-round1

Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or
the lane's `RECORD` and run it again.

**Attempt 1 is the clean-room score.** The final score is what the orchestrator
recorded, after any retry. A lane whose `attempts` is 2 was retried with
attempt 1's check output in its prompt.

| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |
|---|---|---|---|---|---|---|---|
| `codex` | `codex` | no deliverable | no deliverable, FAIL | 2 | not reported | 12.1s | codex/run.json `tasks[0]` |
| `copilot-haiku45` | `github-copilot/claude-haiku-4.5` | no deliverable | 7/8 visible, 3/7 held-out, FAIL | 2 | 59881 | 218.2s | ../../../../../../../../../Volumes/Personal/Users/davidwilliams/dev/misc/beam-sharp/.claude/worktrees/apparatus-lane/handoff/audition-switch/evidence/2026-08-22-round1/copilot-sonnet5/run.json `tasks[1]`; read [`RECORD`](copilot-haiku45/RECORD) |
| `copilot-haiku45-LEAKED` | `github-copilot/claude-haiku-4.5` | 7/8 visible, 4/7 held-out | 8/8 visible, 4/7 held-out, FAIL | 2 | 156797 | 633.9s | copilot-haiku45-LEAKED/run.json `tasks[0]` |
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | no deliverable | 7/8 visible, 7/7 held-out, FAIL | 2 | 174959 | 754.0s | copilot-sonnet5/run.json `tasks[0]` |
| `free-deepseek` | `opencode/deepseek-v4-flash-free` | no deliverable | no deliverable, FAIL | 2 | not reported | 3.7s | free-deepseek/run.json `tasks[0]` |
| `grok` | `grok-4.6` | 7/8 visible, 7/7 held-out | 8/8 visible, 7/7 held-out, PASS | 2 | 1452444 | 936.1s | grok/run.json `tasks[0]`; read [`RECORD`](grok/RECORD) |
