#!/usr/bin/env bash
# P10: does the extra check at the `using` site cost anything measurable? 15 runs each of the same
# compile (Shop.Billing2 against fx6), stock build vs Option B build, wall-clock ms, sorted.
cd "$(dirname "$0")"
[ -d /tmp/bsc-build-60b/ebin ] || ./p5_option_b_prototype.sh >/dev/null 2>&1
for build in /tmp/bsc-build-60/ebin /tmp/bsc-build-60b/ebin; do
  ts=()
  for i in $(seq 15); do
    s=$(date +%s%N); BSC_EBIN=$build ./_bsc.sh --src-root fx6 -o /tmp/p10out fx6/Shop/Billing2 >/dev/null 2>&1; e=$(date +%s%N)
    ts+=($(( (e - s) / 1000000 )))
  done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n))
  echo "$build  min=${sorted[0]}ms median=${sorted[7]}ms max=${sorted[14]}ms"
done
