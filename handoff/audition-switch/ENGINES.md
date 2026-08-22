# Wiring `opencode` as a Ringer engine

Ringer currently has two engines wired — `codex` and `grok`. Three of the five
agent CLIs on this machine and all 424 models `opencode` can reach are therefore
invisible to the scoreboard, which is why it holds 16 rows.

**Do not write this block. Ringer already ships it**, commented out in
`~/.config/ringer/config.toml` itself — look for the `OpenCode + OpenRouter`
comment. Uncomment it and set `bin` to an absolute path:

```toml
[engines.opencode]
bin = "/absolute/path/to/ringer/engines/opencode-sandboxed.sh"
model_default = "openrouter/z-ai/glm-5.2"
args_template = [
  "{taskdir}",
  "{access_args}",
  "run",
  "-m",
  "{model}",
  "--dangerously-skip-permissions",
  "--format",
  "json",
  "{engine_args}",
  "--dir",
  "{taskdir}",
  "{spec}",
]
sandbox_args = []
full_access_args = ["--no-sandbox"]
token_regex = '"tokens":\{"total":([0-9]+)'
```

`model_default` never applies to this audition — `manifest.json` names a model
per task — so leave it. Auth for the metered lane goes wherever your OpenCode
version expects an OpenRouter key, commonly
`~/.local/share/opencode/auth.json`; the `github-copilot/*` lanes ride the
Copilot OAuth that `opencode providers` already reports.

**Why `bin` is a wrapper and not `opencode`.** OpenCode has no OS sandbox of its
own, and `--dangerously-skip-permissions` — which a headless run needs, since
stdin is closed and an approval prompt would hang forever — turns off every
approval it has. `engines/opencode-sandboxed.sh` supplies the containment
instead: macOS Seatbelt, network and reads open, **writes confined to the task
dir** plus a scratch dir and OpenCode's own state. It takes `{taskdir}` as its
first argument, which is why the template opens with it and names it again after
`--dir`.

> **CORRECTED TWICE, 2026-08-22, and the second correction is worse than the
> first.**
>
> The original block here had never been run and was wrong three ways: a
> **schema Ringer does not have** (`cmd` / `args` / `model_flag` / `cwd_flag`,
> against the real `bin` and `args_template`); `--cwd` where `opencode run
> --help` says **`--dir`**; and a `timeout_s` belonging to the task. Each would
> have failed as *"opencode doesn't work"* rather than *"the instructions are
> wrong"*.
>
> Its replacement — written the same day from `opencode run --help` — fixed the
> flags and introduced two new faults, because it was **written rather than
> looked up**. It used `--auto` with `bin = "opencode"`, so the worker ran with
> **no OS sandbox at all**; and it omitted `token_regex`, so every opencode lane
> would have reported **zero tokens** — in an audition whose stated question is
> *"which models can implement B# from the specification alone, and at what
> cost?"* That is half the question, discarded silently, by a block that looked
> correct and would have run fine.
>
> The right block was sitting twenty lines further down the same config file
> that was already open. **Reading `--help` is not reading the documentation**,
> and the failure repeated because the first correction treated "the flags are
> now verified" as "the block is now right".
>
> The rule stands and now has two witnesses: **a gate is believed only once it
> has been seen to fail, and an instruction only once it has been seen to run.**
> Neither of these blocks had.

**This is not applied automatically.** Engine choice belongs to you, and
`~/.config/ringer/config.toml` is your file. Validate with a trivial one-task
manifest before pointing a batch at it, per the playbook's rule about
auditioning a new model on something small first.

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
  block. **The sketch here is `agy -p "<prompt>" --model <model>`, and it is a
  sketch, not a block** — checked against `agy --help` on 2026-08-22: `-p` and
  `--model` are right, but a headless engine also needs
  `--dangerously-skip-permissions` (nothing can answer a prompt with stdin
  closed), and **there is no working-directory flag at all** — only
  `--add-dir`, which adds to a workspace rather than setting one, so a wrapper
  would have to `cd` the way `opencode-sandboxed.sh` does. Written down because
  this file has now twice shipped an unrun block that read like a working one.
- The free tier — `opencode/deepseek-v4-flash-free`, `hy3-free`,
  `mimo-v2.5-free`, `nemotron-3.5-lightning-free` — costs nothing to try and is
  the right home for the exploration slot the playbook asks for.
