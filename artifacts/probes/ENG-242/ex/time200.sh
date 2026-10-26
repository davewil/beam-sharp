#!/usr/bin/env bash
# alternate plain/trace 7 times each; report min and median ms
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; G=$(mktemp -d)/gen
elixir "$HERE/gen200.exs" "$G"
declare -a P T
for i in 1 2 3 4 5 6 7 8; do
  p=$(cd /tmp && elixir "$HERE/driver.exs" plain "$G" | sed -n 's/.*ms=\([0-9]*\).*/\1/p')
  t=$(cd /tmp && elixir "$HERE/driver.exs" trace "$G" | sed -n 's/.*ms=\([0-9]*\).*/\1/p')
  echo "run $i: plain=${p}ms trace=${t}ms"; P+=($p); T+=($t)
done
stat(){ printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{printf "min=%d median=%.1f max=%d\n", a[1], (NR%2?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2), a[NR]}'; }
echo "plain: $(stat "${P[@]}")"; echo "trace: $(stat "${T[@]}")"
