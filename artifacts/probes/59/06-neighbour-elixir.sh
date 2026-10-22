#!/usr/bin/env bash
# Probe 06 — Elixir 1.14 (OTP 24-compiled): def vs defp, and what the compiler inserts. (Elixir .ex sources are not installed; this is behavioural.)
H="$(cd "$(dirname "$0")" && pwd)"; cd "$(mktemp -d)" || exit 1
elixirc --version 2>/dev/null | tail -1
elixir "$H/neighbours-elixir.exs" 2>&1
