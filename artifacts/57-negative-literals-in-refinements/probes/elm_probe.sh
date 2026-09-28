#!/usr/bin/env bash
# PREDICTION: `elm repl` needs the package registry even for `x >= -5`; offline (proxy 403) it cannot run,
# so NO Elm claim is made beyond the version. If it does run, its output is recorded as-is.
export ELM_HOME=$(mktemp -d); cd "$(mktemp -d)"
printf -- '-5\n:exit\n' | timeout 60 elm repl --no-colors 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | head -14
