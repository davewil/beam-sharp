#!/usr/bin/env bash
# 57-03 INCIDENTAL (not this ticket): a singleton refinement ends in an internal "bad range type".
root=$(cd "$(dirname "$0")/../../.." && pwd)
bsc="$root/compiler/_build/default/bin/bsc"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
# bsc writes <Module>.beam/.abstr into the CWD, so always run it from the scratch dir.
probe () { local n=$1 src=$2; mkdir -p "$work/$n"; printf 'module %s\n%s\n' "$n" "$src" > "$work/$n/a.bs"
  out=$(cd "$work" && "$bsc" "$work/$n/a.bs" 2>&1); if [ -z "$out" ]; then echo "$n: accepted"; else echo "$n: refused"; echo "$out" | head -${3:-3} | sed "s#$work/##;s/^/    /"; fi; }
probe Single 'type Five = int where value >= 5 and value <= 5
public Five F()
F() -> 5'
probe SingleEq 'type Five = int where value == 5
public Five F()
F() -> 5'
probe Pair 'type P = int where value >= 5 and value <= 6
public P F()
F() -> 5'
