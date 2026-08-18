# Wiring `opencode` as a Ringer engine

Ringer currently has two engines wired — `codex` and `grok`. Three of the five
agent CLIs on this machine and all 424 models `opencode` can reach are therefore
invisible to the scoreboard, which is why it holds 16 rows.

**This block is not applied automatically.** Engine choice belongs to you, and
`~/.config/ringer/config.toml` is your file. Paste it if you want the lane.

```toml
[engines.opencode]
cmd = "opencode"
args = ["run", "{prompt}"]
model_flag = "--model"
model_default = "github-copilot/claude-sonnet-5"
cwd_flag = "--cwd"
timeout_s = 1800
```

Check the flag names against `opencode run --help` before trusting it — this is
written from `opencode --help` at v0.146-era and the argument shape for `run`
was not verified end to end. Validate with a trivial one-task manifest before
pointing a batch at it, per the playbook's rule about auditioning a new model on
something small first.

## Why this lane matters for cost

`opencode providers` reports four authed credentials here: GitHub Copilot
(oauth), Anthropic (oauth), Google (oauth), OpenRouter (api). Only the last is
metered per token. So `github-copilot/*` and `anthropic/*` models run against
subscriptions already paid for, and 24 of the 424 models are free outright.

The practical consequence for the clean-room effort: the implementation work —
bulk generation against a precise spec with an executed check and automatic
retry — can run almost entirely on plan-billed and free lanes. Metered spend
belongs to the orchestrator seat, which reads results and writes specs, not to
the workers doing the typing.

## Models worth auditioning beyond the first four

- `github-copilot/claude-sonnet-4.6`, `github-copilot/gemini-3.1-pro-preview` —
  same subscription, different lab.
- `agy` reaches Gemini 3.6 Flash, Gemini 3.1 Pro, Claude Sonnet 4.6, Claude
  Opus 4.6 and GPT-OSS 120B, but is not a Ringer engine; it would need its own
  block (`agy -p "<prompt>" --model <model>`).
- The free tier — `opencode/deepseek-v4-flash-free`, `hy3-free`,
  `mimo-v2.5-free`, `nemotron-3.5-lightning-free` — costs nothing to try and is
  the right home for the exploration slot the playbook asks for.
