#!/usr/bin/env bash
# PROBE 60g -- ticket 60 (ENG-242) sub-question 4: what does the check cost the checker?
# Method: generate N modules Gen.M0..Gen.M(N-1) (one dir each, one public function each); module Mi
# `using` the previous K modules (K edges each) and calls one; a top module `Gen.Top` uses the last.
# Compile the whole closure with (a) pristine bsc, (b) patched bsc with NO visible_to anywhere
# (cost of the extra World field + per-edge lookup), (c) patched bsc with `visible_to Gen` on EVERY
# module (the per-edge predicate runs a prefix test on every edge).
# Each variant: R runs, wall time of a fresh `erl` per run (includes VM boot, so deltas are what matter).
# Reports min and median in ms. Usage: PRISTINE=.. PATCHED=.. [N=200] [K=3] [R=9] ./60g_checker_cost.sh
set -uo pipefail
: "${PRISTINE:?}" ; : "${PATCHED:?}"
N="${N:-200}"; K="${K:-3}"; R="${R:-9}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
gen() { # <srcdir> <with_visible_to 0|1>
  local d="$1" v="$2"
  for ((i=0;i<N;i++)); do
    mkdir -p "$d/Gen/M$i"; f="$d/Gen/M$i/M$i.bs"
    { echo "module Gen.M$i"
      [ "$v" = 1 ] && echo "visible_to Gen"
      for ((j=1;j<=K && i-j>=0;j++)); do echo "using Gen.M$((i-j))"; done
      echo "public int F$i(int n)"
      if [ $i -ge 1 ]; then echo "F$i(n) -> F$((i-1))(n) + 1"; else echo "F$i(n) -> n"; fi
    } > "$f"
  done
  mkdir -p "$d/Gen/Top"; printf 'module Gen.Top\nusing Gen.M%d\npublic int Top(int n)\nTop(n) -> F%d(n)\n' $((N-1)) $((N-1)) > "$d/Gen/Top/Top.bs"
}
gen "$W/plain" 0; gen "$W/vis" 1
edges=$(grep -rh "^using" "$W/vis" | wc -l)
echo "modules=$((N+1)) using-edges=$edges (K=$K) runs=$R"
timeit() { # <ebin parent> <srcroot> -> prints ms
  local o; o="$(mktemp -d)"; local s e
  s=$(date +%s%N)
  erl -noshell -pa "$1/ebin" -eval 'bsc:main(init:get_plain_arguments())' -extra --src-root "$2" -o "$o" "$2/Gen/Top" >"$o.log" 2>&1; rc=$?
  e=$(date +%s%N); rm -rf "$o"
  [ $rc -eq 0 ] || { echo "COMPILE FAILED rc=$rc: $(head -3 "$o.log")" >&2; echo -1; return; }
  echo $(( (e-s)/1000000 )); }
stat() { sort -n | awk '{a[NR]=$1} END{printf "min=%d median=%d max=%d ms\n", a[1], a[int((NR+1)/2)], a[NR]}'; }
run() { for ((r=0;r<R;r++)); do timeit "$2" "$3"; done | stat | sed "s/^/$1: /"; }
run "(a) pristine, no visible_to      " "$PRISTINE" "$W/plain"
run "(b) patched,  no visible_to      " "$PATCHED"  "$W/plain"
run "(c) patched,  visible_to on all  " "$PATCHED"  "$W/vis"
run "(a') pristine again (noise floor) " "$PRISTINE" "$W/plain"
