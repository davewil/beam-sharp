#!/usr/bin/env bash
# gen_heavy.sh DIR KIND N -- a refinement-heavy module of N types + N functions.
# KIND=pos  every literal non-negative (compiles on the baseline: the control)
# KIND=neg  the same shapes with negative bounds (needs a fix to compile)
dir=$1; kind=$2; n=${3:-80}
mkdir -p "$dir"; f=$dir/a.bs; : > "$f"
mod=$(basename "$dir"); echo "module $mod" >> "$f"
for i in $(seq 0 $((n-1))); do
  if [ "$kind" = neg ]; then lo=-$((100+i)); mid=-$((i%40)); else lo=$((i%7)); mid=$((50+i%40)); fi
  hi=$((200+i))
  case $((i%4)) in
   0) pred="value >= $lo and value <= $hi" ;;
   1) pred="value >= $lo and value <= $hi and value != $mid" ;;
   2) pred="value <= $lo or value >= $((hi))" ;;
   3) pred="value != $mid" ;;
  esac
  { echo "type R$i = int where $pred"
    echo "public atom F$i(R$i d)"
    echo "F$i(d) when d > $mid -> :hi"
    echo "F$i(d) when d <= $mid -> :lo"; } >> "$f"
done
