#!/usr/bin/env bash
# Ticket 57: does folding `-5` change what is emitted or what the program does? base vs both prototypes.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
for v in base v57a v57b; do echo "== $v"
  BSC_EBIN=$PROBE_HOME/variants/$v/ebin escript $root/artifacts/probes/bsh.escript $root/artifacts/probes/src57/neg_emit.bs Ng "{'Ng':'F'(1), 'Ng':'G'()}." dump:F dump:G 2>&1 | grep -v '^$'
done
