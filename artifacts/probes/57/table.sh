#!/usr/bin/env bash
# table.sh EBIN LABEL -- the ticket-57 table (plus extra rows) against the bsc in EBIN.
# For each refinement: (1) is it accepted as `type T = int where <pred>`;
# (2) if accepted, what domain did it denote (read from the non-exhaustive
# residual of a function whose only clause is `F(b) when b == 123456789`, i.e.
# the residual is the domain with one far-away point removed, so the printed
# residual IS the domain).  Output: one line per row.
set -u
ebin=$1; label=$2
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
echo "## $label"
row () {  # row NAME PREDICATE
  local name=$1 pred=$2
  mkdir -p "$work/A$name" "$work/B$name"
  printf 'module A%s\ntype T = int where %s\npublic int Id(T b)\nId(b) -> b\n' "$name" "$pred" > "$work/A$name/a.bs"
  local out; out=$("$here/bsc.sh" "$ebin" "$work/A$name" 2>&1); local rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ]; then
     printf 'module B%s\ntype T = int where %s\npublic atom F(T b)\nF(b) when b == 123456789 -> :a\n' "$name" "$pred" > "$work/B$name/a.bs"
     local dom; dom=$("$here/bsc.sh" "$ebin" "$work/B$name" 2>&1 | grep -E '^ +F\(' | sed 's/^ *F(//; s/) -> \.\.\.//' | paste -sd'|' | sed 's/|/ | /g')
     printf 'ACCEPTED  %-34s domain: %s\n' "$pred" "${dom:-?}"
  else
     local why; why=$(printf '%s' "$out" | head -1 | sed 's/^[^ ]* //')
     printf 'REFUSED   %-34s %s\n' "$pred" "$why"
  fi
}
# --- the ticket's five rows
row 1 'value >= -5'
row 2 'value >= -5 and value <= 5'
row 3 'value >= 1 or value <= -1'
row 4 'value <= 3 or value >= 10'
row 5 'value != 0'
# --- extra rows: how far would a fold go?
row 6 'value != -3'
row 7 'value == -1'
row 8 '-5 <= value'
row 9 'value >= - 5'
row 10 'value >= (-5)'
row 11 'value >= -(5)'
row 12 'value >= 2 + 3'
row 13 'value >= 0 - 5'
row 14 'value >= -5 + 1'
row 15 'value >= --5'
row 16 'value >= -0'
row 17 'value > -1 and value < 1'
row 18 'value >= 5'
row 19 'value >= -n'
row 20 'value >= (2 + 3) * 4'
row 21 'value >= -2147483648 and value <= 2147483647'
# --- rows that already worked or already had a diagnostic: does the fix move them?
row 22 'value >= 0 and value <= 255'
row 23 '(value >= 0) and (value <= 5)'
row 24 'WellFormed(value)'
row 25 'value >= n'
row 26 'value >= 0 and value <= 5 and value != 3'
# --- incidental: singleton domains, no negative literal anywhere (see brief, Limits)
row 27 'value == 5'
row 28 'value > 4 and value < 6'
echo "## pattern + guard sites (same literal)"
sn=0
site () {  # site LABEL SRC
  local name=$1; sn=$((sn+1))
  mkdir -p "$work/S$sn"; printf 'module S%s\n%s\n' "$sn" "$2" > "$work/S$sn/a.bs"
  local out; out=$("$here/bsc.sh" "$ebin" "$work/S$sn" 2>&1); local rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ]; then printf 'ACCEPTED  %-34s\n' "$name"; else printf 'REFUSED   %-34s %s\n' "$name" "$(printf '%s' "$out" | head -3 | tr '\n' '~')"; fi
}
site 'pattern <= -1 / >= 0' 'public atom Sign(int n)
Sign(>= 0) -> :nonneg
Sign(<= -1) -> :neg'
site 'guard n >= 0 / n <= -1' 'public atom Sign(int n)
Sign(n) when n >= 0 -> :nonneg
Sign(n) when n <= -1 -> :neg'
site 'guard n < 0 (no literal -)' 'public atom Sign(int n)
Sign(n) when n >= 0 -> :nonneg
Sign(n) when n < 0 -> :neg'
echo "## guard agreement (the same predicate as a clause guard and as a refinement)"
site 'G1 guard n>=-5 ; n<-5 (both clauses)' 'public atom F(int n)
F(n) when n >= -5 -> :in
F(n) when n < -5 -> :out'
site 'G2 refinement -5, guard n>=-5 only' 'type D = int where value >= -5
public atom F(D n)
F(n) when n >= -5 -> :in'
site 'G3 refinement 0, guard n>=0 only (control)' 'type D = int where value >= 0
public atom F(D n)
F(n) when n >= 0 -> :in'
site 'G4 refinement -5, pattern >= -5 only' 'type D = int where value >= -5
public atom F(D n)
F(>= -5) -> :in'
site 'G5 guard n>=-5 and n<=5 / rest' 'public atom F(int n)
F(n) when n >= -5 and n <= 5 -> :near
F(n) when n < -5 or n > 5 -> :far'
echo "## what the guard credits: residual of a single guard clause"
resid () {  # resid LABEL SRC  -> prints the "no clause matches" lines
  sn=$((sn+1)); mkdir -p "$work/S$sn"; printf 'module S%s\n%s\n' "$sn" "$2" > "$work/S$sn/a.bs"
  printf '%-34s residual: %s\n' "$1" "$("$here/bsc.sh" "$ebin" "$work/S$sn" 2>&1 | grep -E '^ +F\(|exhaustive' | sed 's/^ *//; s/ -> \.\.\.//' | paste -sd'|' | sed 's/|/ | /g')"
}
resid 'guard n >= -5' 'public atom F(int n)
F(n) when n >= -5 -> :in'
resid 'guard n >= 5  (control)' 'public atom F(int n)
F(n) when n >= 5 -> :in'
resid 'pattern >= -5' 'public atom F(int n)
F(>= -5) -> :in'
echo "## run time: the compiled program, for programs that compiled"
runit () {  # runit LABEL SRC ARG
  sn=$((sn+1)); mkdir -p "$work/S$sn"; printf 'module S%s\n%s\n' "$sn" "$2" > "$work/S$sn/a.bs"
  printf '%-34s F(%s) = %s\n' "$1" "$3" "$("$here/bsc.sh" "$ebin" "$work/S$sn" F "$3" 2>&1 | head -2 | tr '\n' ' ')"
}
for a in -5 -6 7; do
runit 'guard n>=-5 ; n<-5' 'public atom F(int n)
F(n) when n >= -5 -> :in
F(n) when n < -5 -> :out' "$a"
done
for a in -5 -6; do
runit 'public Id(D) D=int where >= -5' 'type D = int where value >= -5
public int F(D n)
F(n) -> n' "$a"
done
