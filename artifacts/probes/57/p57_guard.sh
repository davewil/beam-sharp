#!/usr/bin/env bash
# Ticket 57. The same literal in a PATTERN, in a GUARD, and in a REFINEMENT; and does a guard with -5 earn coverage?
. "$(dirname "$0")/../env.sh"
W=$(mktemp -d); mkdir -p "$W/M"
run() { printf 'module M\n\n%s\n' "$2" > "$W/M/m.bs"; out=$(bsc -o "$W/out" "$W/M" 2>&1); printf '== %s: rc=%s\n%s\n' "$1" $? "$(echo "$out" | head -${3:-6})"; }
run 'pattern relational -5 (covering pair)' 'public atom S(int n)

S(>= -5) -> :a
S(< -5)  -> :b'
run 'guard -5 (covering pair)' 'public atom S(int n)

S(n) when n >= -5 -> :a
S(n) when n < -5  -> :b'
run 'guard 0 (control: same shape, non-negative)' 'public atom S(int n)

S(n) when n >= 0 -> :a
S(n) when n < 0  -> :b'
