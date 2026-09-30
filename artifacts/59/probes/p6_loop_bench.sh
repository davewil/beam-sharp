#!/usr/bin/env bash
# P6: what does the widened (variant B) guard cost where erlc cannot prove it away?
# Base and B are built from the same P6 source; they run in separate VMs, alternated 3 times.
source "$(dirname "$0")/env.sh"
for v in base B; do
  D=/tmp/bs59-build/p6-$v; rm -rf $D; mkdir -p $D/P6; cp "$PROBES/src/p6_loop.bs" $D/P6/p6.bs
  bsc_in /tmp/bs59-build/ebin-$v $D --src-root $D $D/P6 >/dev/null 2>&1 </dev/null
  "$PROBES/dump.escript" $D/P6.beam | grep -A1 "Step\|Loop" | sed "s/^/[$v] /"
  echo -n "[$v] surviving is_integer tests: "; "$PROBES/disasm_count.escript" $D | sed 's/.*: //'
done
for round in 1 2 3; do for v in base B; do echo -n "round $round [$v] "; "$PROBES/bench.escript" /tmp/bs59-build/p6-$v P6 Total 1000000 40; done; done
