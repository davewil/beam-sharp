# 2026-09-10-round5-midtier-passes

Written by `build-run-manifest.py --summaries`. Do not edit: fix the record or
the lane's `RECORD` and run it again.

**Attempt 1 is the clean-room score.** The final score is what the orchestrator
recorded, after any retry. A lane whose `attempts` is 2 was retried with
attempt 1's check output in its prompt. That prompt is quoted in the lane's
`worker.log`, which is where the attempt 1 column is read from. The worker's
own output is in that log as well, so the column is the log's word and not
the orchestrator's: two different quoted scores are shown as conflicting.

| lane | model | attempt 1 | final | attempts | tokens | elapsed | machine record |
|---|---|---|---|---|---|---|---|
| `codex-luna` | `gpt-5.6-luna` | 12/13 visible, 8/12 held-out | 13/13 visible, 9/12 held-out, FAIL | 2 | not reported | 1268.0s | run.json `tasks[2]` |
| `codex-sol` | `gpt-5.6-sol` | 12/13 visible, 9/12 held-out | 13/13 visible, 12/12 held-out, PASS | 2 | not reported | 3591.9s | run.json `tasks[0]` |
| `codex-terra` | `gpt-5.6-terra` | 13/13 visible, 11/12 held-out | 13/13 visible, 11/12 held-out, FAIL | 2 | not reported | 1197.0s | run.json `tasks[1]` |
