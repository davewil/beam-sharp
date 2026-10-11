#!/usr/bin/env bash
# Probe (d, Elixir): does a guard on a defp still run? Does elixirc elide it? Run from this dir.
cd "$(dirname "$0")"
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
elixir --version | tail -1
elixir priv.exs
