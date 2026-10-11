#!/usr/bin/env bash
# options_program.sh : ONE realistic program, compiled by the reference and each patched build; prints every diagnostic head line.
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
mkdir -p $W/src/Thermo
cat > $W/src/Thermo/a.bs <<'X'
module Thermo
type Delta = int where value >= -100 and value <= 100

public Delta Floor()
Floor() -> -100

public atom Trend(int d)
Trend(d) when d <= -1 -> :falling
Trend(d) when d >= 1 -> :rising
Trend(0) -> :flat

public int PerStep(int total)
PerStep(total) -> total / -0
X
for spec in reference:$S/bsc-ebin A:$S/57/ebin-A B:$S/57/ebin-B Barith:$S/57/ebin-Barith; do
  n=${spec%%:*}; e=${spec#*:}; mkdir -p $W/o$n
  echo "== $n"
  (cd $W/o$n && erl -noshell -pa $e -run bsc main $W/src/Thermo/a.bs -run init stop 2>&1 | sed "s#$W/src/##" | grep -E "error|warning" | cut -c1-110)
done
