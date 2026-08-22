# Wiring `opencode` as a Ringer engine

Ringer currently has two engines wired — `codex` and `grok`. Three of the five
agent CLIs on this machine and all 424 models `opencode` can reach are therefore
invisible to the scoreboard, which is why it holds 16 rows.

**This block is not applied automatically.** Engine choice belongs to you, and
`~/.config/ringer/config.toml` is your file. Paste it if you want the lane.

```toml
[engines.opencode]
bin = "opencode"
model_default = "github-copilot/claude-sonnet-5"
args_template = [
  "run",
  "--dir",
  "{taskdir}",
  "-m",
  "{model}",
  "{access_args}",
  "{engine_args}",
  "{spec}",
]
sandbox_args = ["--auto"]
full_access_args = ["--auto"]
```

`--auto` is load-bearing. opencode ships no OS sandbox of its own, so isolation
comes from the staged `taskdir` and from `stage.sh` keeping both answer sets off
disk; without auto-approve a headless run blocks forever on a permission prompt
with stdin closed.

> **CORRECTED 2026-08-22, and the correction is the point.** The block above
> replaces one that had never been run. It was wrong three ways at once: it used
> a **schema Ringer does not have** (`cmd` / `args` / `model_flag` / `cwd_flag`,
> where the real fields are `bin` and an `args_template` interpolating
> `{taskdir}`, `{spec}`, `{model}`, `{access_args}` and `{engine_args}`); it
> named the directory flag `--cwd` where `opencode run --help` says **`--dir`**;
> and it carried a `timeout_s` that belongs on the task, not the engine.
>
> Every one of those would have failed as *"opencode doesn't work"* rather than
> *"the wiring instructions are wrong"* — which is the same defect the audition
> exists to find, arriving in the audition's own setup notes. The paragraph that
> used to sit here said *"check the flag names before trusting it… the argument
> shape for `run` was not verified end to end"*, and it was right; nobody did.
> **A gate is believed only once it has been seen to fail, and an instruction is
> believed only once it has been seen to run.**

Validate with a trivial one-task manifest before pointing a batch at it, per the
playbook's rule about auditioning a new model on something small first.

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
