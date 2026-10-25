#!/usr/bin/env bash
# Ticket 39. The REAL emitter, three builds of it (base / I1 module-wide inline / I2 inline for private functions only),
# each compiling the same Day01 .bs; timed one VM per sample, interleaved. usage: p39_emitter.sh VARDIR INPUT [ROUNDS]
. "$(dirname "$0")/../env.sh"; V=$1; IN=$2; R=${3:-8}; H="$(dirname "$0")"
for r in $(seq $R); do for v in base I1 I2; do echo "$v $("$H/time_one.escript" "$V/$v" Day01 PartTwo "$IN")"; done; done | python3 -I -c '
import sys,collections,statistics
d=collections.defaultdict(list)
for l in sys.stdin:
    v,a,mn,md=l.split(); d[v].append(float(mn)); assert a=="6770"
b=statistics.median(d["base"])
for v in ["base","I1","I2"]:
    x=d[v]; print("%-5s min-of-min %.2f median-of-min %.2f spread %.2f  vs base %+.1f%%"%(v,min(x),statistics.median(x),max(x)-min(x),100*(statistics.median(x)/b-1)))'
