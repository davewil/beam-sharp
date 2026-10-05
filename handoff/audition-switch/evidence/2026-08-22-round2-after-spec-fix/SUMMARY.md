# 2026-08-22-round2-after-spec-fix

Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or
the lane's `RECORD` and run it again.

**Attempt 1 is the clean-room score.** The final score is what the orchestrator
recorded, after any retry. A lane whose `attempts` is 2 was retried with
attempt 1's check output in its prompt.

| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |
|---|---|---|---|---|---|---|---|
| `copilot-sonnet5` | `github-copilot/claude-sonnet-5` | 8/8 visible, 7/7 held-out | 8/8 visible, 7/7 held-out, PASS | 1 | 156648 | 849.0s | copilot-sonnet5/run.json `tasks[0]` |
