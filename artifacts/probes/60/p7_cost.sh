#!/bin/bash
# P7: whole-process compile wall time (ms) of a synthetic N-module tree, baseline vs each patched compiler. Runs interleaved round-robin, RUNS per config.
RUNS=${RUNS:-15}
T=$(mktemp -d)
SCR=$(dirname "$(readlink -f "$0")")
for n in 50 200; do for m in base baseB B C; do "$SCR/gen_tree.sh" $m $n $T/$m$n; done; done
dirs() { (cd $1 && find . -name a.bs | xargs -n1 dirname | sed 's#^\./##' | sort | tr '\n' ' '); }
declare -A DIRS
now() { date +%s%N; }
once() { # tree ebin
  local s e; s=$(now)
  (cd $1 && erl -noshell -pa $2 -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra --src-root . $3 >/dev/null 2>&1)
  e=$(now); echo $(( (e-s)/1000000 )); }
# config label | tree | ebin
CFG=("baseline-on-A-shaped|base|/tmp/bsbuild/ebin" "A|base|/tmp/bsb_60_a/ebin" "baseline-on-B-shaped|baseB|/tmp/bsbuild/ebin" "B|B|/tmp/bsb_60_b/ebin" "baseline-on-C-shaped|base|/tmp/bsbuild/ebin" "C|C|/tmp/bsb_60_c/ebin")
for n in 50 200; do
  echo "### N=$n modules"
  declare -A samples; samples=()
  # bare VM boot (control: what the timing cannot see below)
  for ((r=0;r<RUNS;r++)); do s=$(now); erl -noshell -eval 'halt(0).' >/dev/null; e=$(now); samples[boot]+="$(( (e-s)/1000000 )) "; done
  for ((r=0;r<RUNS;r++)); do
    for c in "${CFG[@]}"; do IFS='|' read lab tree eb <<<"$c"
      d=$T/$tree$n; [ -z "${DIRS[$d]}" ] && DIRS[$d]=$(dirs $d)
      samples[$lab]+="$(once $d $eb "${DIRS[$d]}") "; done; done
  for k in boot "${CFG[@]%%|*}"; do python3 -I - "$k" ${samples[$k]} <<'PY'
import sys,statistics as s
k=sys.argv[1]; v=sorted(map(int,sys.argv[2:]))
print(f"{k:24s} n={len(v)} median={s.median(v):.0f}ms min={v[0]} max={v[-1]} IQR={v[len(v)*3//4]-v[len(v)//4]}")
PY
  done
done
rm -rf $T
