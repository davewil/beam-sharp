#!/usr/bin/env bash
# P8: cost of the guard at an ESCAPE (variant C wrapper) and of widening (variant B) on a private
# function applied per element through a fun. Base / B / C, alternated, separate VMs.
source "$(dirname "$0")/env.sh"
for v in base B C; do
  D=/tmp/bs59-build/p8-$v; rm -rf $D; mkdir -p $D/P8; cp "$PROBES/src/p8_map_private.bs" $D/P8/p8.bs
  bsc_in /tmp/bs59-build/ebin-$v $D --src-root $D $D/P8 >/dev/null 2>&1 </dev/null
  echo -n "[$v] surviving is_integer tests in bytecode: "; "$PROBES/disasm_count.escript" $D | sed 's/.*: //'
done
for round in 1 2 3; do for v in base B C; do echo -n "round $round [$v] "; "$PROBES/bench.escript" /tmp/bs59-build/p8-$v P8 Doubled 1000000 40; done; done
