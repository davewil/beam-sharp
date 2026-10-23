#!/usr/bin/env bash
# PROBE 62m — compile-time cost of the alias pass. Whole examples tree (23 modules; one is refused in every mode),
# 15 interleaved rounds per mode, wall-clock ms per round. CONTROL: 'off' measured twice (off, off2) -> noise floor.
# bsc is an escript, so VM start-up is in every number; the question is whether the alias modes separate from off/off2.
set -uo pipefail
: "${ALIASBSC:?}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
run() { local m="$1"; rm -rf "$W/o"; mkdir "$W/o"; local s=$(date +%s%N)
  for d in "$REPO"/compiler/examples/*/; do BS_ALIAS=$m "$ALIASBSC" --src-root "$REPO/compiler/examples" -o "$W/o" "$d" >/dev/null 2>&1; done
  echo $(( ($(date +%s%N) - s) / 1000000 )); }
declare -A T
for r in $(seq 1 15); do for m in off deleg dup off2; do
  mode=$m; [ "$m" = off2 ] && mode=off
  T[$m]+="$(run $mode) "; done; done
for m in off off2 deleg dup; do
  echo "${T[$m]}" | tr ' ' '\n' | grep . | sort -n | awk -v m=$m '{a[NR]=$1} END{printf "%-6s median %d ms  min %d  max %d  (n=%d)\n", m, a[int((NR+1)/2)], a[1], a[NR], NR}'
done
