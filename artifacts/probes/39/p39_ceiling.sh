#!/usr/bin/env bash
# Ticket 39 §3.3. Where does the ceiling sit?  erl_inline (Erlang source, +inline) / bs_I2 (real emitter, private-only inline)
# / oracle (HAND-WRITTEN upper bound, see oracle/oracle.erl — NOT an emitter output).
. "$(dirname "$0")/../env.sh"; H="$(dirname "$0")"; ROOT="$H/../../.."; V=$SCRATCH/bench39/var3; IN=$ROOT/aoc/2025/Day01/input.txt
for r in 1 2 3 4 5 6; do for v in erl_inline:bench_erl:part_two bs_I2:Day01:PartTwo oracle:oracle:part_two; do IFS=: read d m f <<< "$v"; echo "$d $("$H/time_one.escript" $V/$d $m $f "$IN")"; done; done | python3 -I -c '
import sys,collections,statistics
d=collections.defaultdict(list)
for l in sys.stdin:
    v,a,mn,md=l.split(); d[v].append(float(mn)); assert a=="6770",a
for v,x in d.items(): print("%-12s min-of-min %.2f median-of-min %.2f"%(v,min(x),statistics.median(x)))'
