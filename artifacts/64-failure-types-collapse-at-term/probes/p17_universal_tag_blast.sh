#!/usr/bin/env bash
# P17: MODIFIED COMPILER #3 (scratch; delta3_tagged_option.diff = prelude `option<T>` becomes (:some,T)|:nothing at bs_check.erl:1351, nothing else).
# For each repo .bs source that mentions option< or :nothing: compile with stock bsc and with delta3; count `error:` lines.
. "$(dirname "$0")/lib.sh"
D3=$S/64/delta3/bsc
cd "$HERE/../../.."
tot_s=0; tot_d=0; broke=0; n=0
for f in $(grep -rl 'option<\|:nothing' --include=*.bs . | grep -v '^./artifacts\|_build' | sort); do
  d=$(dirname $f); n=$((n+1))
  es=$($BSC "$d" 2>&1 | grep -c ': error:'); ed=$($D3 "$d" 2>&1 | grep -c ': error:')
  [ "$ed" -gt "$es" ] && broke=$((broke+1))
  tot_s=$((tot_s+es)); tot_d=$((tot_d+ed))
  printf '%-75s stock=%-3s tagged-option=%s\n' "$d" "$es" "$ed"
done
echo "modules compiled: $n ; modules with MORE errors under tagged option<T>: $broke ; errors stock=$tot_s tagged=$tot_d"
