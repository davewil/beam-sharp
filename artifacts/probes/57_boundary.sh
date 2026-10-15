#!/usr/bin/env bash
# 57_boundary -- claim: once `-100` is writable, a refined signed parameter is checked at the exported
# boundary with the right negative bounds (F37), and the residual advice names signed ranges.
# REFUTED by: Id(-100)/Id(100) not returning, or Id(-101)/Id(101) returning instead of failing, or the
# beam's guard not containing -100.
# usage: V57=<dir> 57_boundary.sh   (runs on gramA and chk; stock cannot compile it)
. "$(dirname "$0")/env.sh"; : "${V57:?}"
w=$(mktemp -d "${TMPDIR:-/tmp}/p57b.XXXXXX"); mkdir -p "$w/M"
cat > "$w/M/a.bs" <<'B'
module M
type Delta = int where value >= -100 and value <= 100
public Delta Id(Delta d)
Id(d) -> d
public atom Sign(Delta d)
Sign(<= -1) -> :neg
Sign(0) -> :zero
Sign(>= 1) -> :pos
B
for v in stock gramA chk; do
  b=$V57/$v/_build/default/bin/bsc; echo "== $v"
  if ! "$b" "$w/M" >/dev/null 2>&1; then echo "  compile: REFUSED ($("$b" "$w/M" 2>&1 | head -1 | sed 's/^[^ ]* //'))"; continue; fi
  for a in -101 -100 -1 0 100 101; do printf '  Id(%s) -> %s\n' $a "$("$b" "$w/M" Id $a 2>&1 | head -2 | tr '\n' ' ' | cut -c1-110)"; done
  for a in -100 0 100; do printf '  Sign(%s) -> %s\n' $a "$("$b" "$w/M" Sign $a 2>&1 | tail -1)"; done
done
