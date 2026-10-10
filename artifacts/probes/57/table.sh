#!/usr/bin/env bash
# Usage: table.sh BSC  -- runs the ticket's repro table plus controls, one refinement per probe.
# Each row compiles `type T = int where <pred>` and a function taking a T; prints OK or first error line.
BSC=${1:?bsc path}
W=$(mktemp -d)
row() { # label pred
  local d=$W/P; rm -rf "$d"; mkdir -p "$d"
  printf 'module P\n\ntype T = int where %s\n\npublic atom F(T x)\n\nF(x) -> :ok\n' "$2" > "$d/p.bs"
  out=$(cd "$W" && "$BSC" -o "$W/out" P 2>&1); rc=$?
  first=$(printf '%s\n' "$out" | head -1 | cut -c1-110)
  printf '%-6s rc=%s  %-42s %s\n' "$1" "$rc" "$2" "$first"
}
row T1  'value >= -5'
row T2  'value >= -5 and value <= 5'
row T3  'value >= 1 or value <= -1'
row T4  'value <= 3 or value >= 10'
row T5  'value != 0'
row C1  'value >= n'
row C2  'value >= 2 + 3'
row C3  'value >= -(5)'
row C4  'value >= --5'
row C5  'value + 1 >= 3'
row C6  'value >= 0 - 5'
row C7  '-5 <= value'
row C8  'value >= - 5'
row C9  'value >= -0'
row C10 'value == -3'
row C11 'value != -3'
row C12 'value > -1 and value < 1'
row C13 'value >= -5 and value <= -10'
row C14 'value >= -(2 + 3)'
row C15 'value >= -5 + 0'
row C16 'value >= 5 * 2'
row C17 'value >= -x'
row D   'value >= -100 and value <= 100'
rm -rf "$W"
