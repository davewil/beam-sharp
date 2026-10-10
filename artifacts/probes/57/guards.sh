#!/usr/bin/env bash
# Does a guard (and a pattern) accept the same literals a refinement refuses, and does the guard CREDIT coverage?
# G rows: two-clause function over int; exhaustive only if the guards are READ (a closed split of int).
BSC=${1:?bsc path}
W=$(mktemp -d)
prog() { # label body
  local d=$W/P; rm -rf "$d"; mkdir -p "$d"
  printf 'module P\n\npublic atom F(int x)\n\n%s\n' "$2" > "$d/p.bs"
  out=$(cd "$W" && "$BSC" -o "$W/out" P 2>&1); rc=$?
  printf '== %s rc=%s\n%s\n' "$1" "$rc" "$(printf '%s\n' "$out" | head -${3:-6})"
}
prog 'G0 CONTROL guard 5 positive, both clauses read (must compile)' 'F(x) when x >= 5 -> :a
F(x) when x < 5 -> :b'
prog 'G1 guard -5, both clauses read (expect compile = guards credit coverage)' 'F(x) when x >= -5 -> :a
F(x) when x < -5 -> :b'
prog 'G2 guard 0 - 5 (arith node; expect clause not credited -> inexhaustive)' 'F(x) when x >= 0 - 5 -> :a
F(x) when x < 0 - 5 -> :b'
prog 'G3 guard 2+3 (arith node)' 'F(x) when x >= 2 + 3 -> :a
F(x) when x < 2 + 3 -> :b'
prog 'G4 guard -(5)' 'F(x) when x >= -(5) -> :a
F(x) when x < -(5) -> :b'
prog 'G5 guard with unreadable comparand: control, must NOT be credited' 'F(x) when x >= 5 -> :a
F(x) when x < 5 + 0 -> :b'
prog 'P1 pattern (>= -5) | (< -5)' 'F(>= -5) -> :a
F(< -5) -> :b'
prog 'P2 pattern -5 literal and rest' 'F(-5) -> :a
F(>= -4) -> :b
F(<= -6) -> :c'
prog 'G6 guard -5 plus a wildcard-ish tail: compiles because last clause is open (guard accepted, not credited)' 'F(x) when x >= -5 -> :a
F(x) -> :b'
