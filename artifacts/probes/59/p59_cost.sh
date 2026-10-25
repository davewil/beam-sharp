#!/usr/bin/env bash
# Ticket 59. Run-time cost of widening the int kind test to PRIVATE functions, on the one hot loop in the repo (aoc Day01:
# Wrap, Hit, Spin, Sign, Size, Clicks are all private and take `int`). Interleaved, one VM per sample.
. "$(dirname "$0")/../env.sh"; V=$1; IN=$2; R=${3:-8}; H="$(dirname "$0")/../39"
for r in $(seq $R); do for v in base G2; do echo "$v $("$H/time_one.escript" "$V/$v" Day01 PartTwo "$IN")"; done; done | python3 -I -c '
import sys,collections,statistics
d=collections.defaultdict(list)
for l in sys.stdin:
    v,a,mn,md=l.split(); d[v].append(float(mn)); assert a=="6770"
b=statistics.median(d["base"])
for v in ("base","G2"):
    x=d[v]; print("%-5s min-of-min %.2f median-of-min %.2f spread %.2f vs base %+.1f%%"%(v,min(x),statistics.median(x),max(x)-min(x),100*(statistics.median(x)/b-1)))'
