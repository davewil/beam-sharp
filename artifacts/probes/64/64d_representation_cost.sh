#!/usr/bin/env bash
# PROBE 64d — heap words, serialized bytes, run time and BEAM asm: bare vs always-tagged option<int>.
# Control inside the probe: both shapes compute the same sum (the match is the only difference).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cp "$HERE/repr.erl" "$W/"
( cd "$W" && erlc +no_inline repr.erl && erl -noshell -s repr run -s init stop )
echo
echo "== timing repeated in 7 fresh VMs (each: 25 reps x 1e6 elements). Columns: bare min/med/max | tagged min/med/max | min-ratio med-ratio | overlap? =="
for i in 1 2 3 4 5 6 7; do
  ( cd "$W" && erl -noshell -s repr run -s init stop ) | awk -v run=$i '
    /^== consume/ {m="consume"} /^== produce/ {m="produce"}
    /^  bare    min=/ && m!="" {split($0,a,/[= ]+/); bmin[m]=a[4]; bmed[m]=a[6]; bmax[m]=a[8]}
    /^  tagged  min=/ && m!="" {split($0,a,/[= ]+/); tmin[m]=a[4]; tmed[m]=a[6]; tmax[m]=a[8];
        printf "run %d %-8s bare %6d/%6d/%6d | tagged %6d/%6d/%6d | min x%.2f med x%.2f | %s\n", run, m, bmin[m],bmed[m],bmax[m], tmin[m],tmed[m],tmax[m], tmin[m]/bmin[m], tmed[m]/bmed[m], (tmin[m] <= bmax[m] ? "RANGES OVERLAP" : "disjoint")}'
done
echo
echo "== BEAM asm for the two consumers (erlc -S): the first clause body that matches an element =="
( cd "$W" && erlc -S repr.erl && awk '/^{function, bare_sum, 2/,/^{function, tagged_sum, 1/' repr.S | sed -n 1,40p
  echo "-- tagged --"
  awk '/^{function, tagged_sum, 2/,/^{function, bare_mk, 1/' repr.S | sed -n 1,48p )
