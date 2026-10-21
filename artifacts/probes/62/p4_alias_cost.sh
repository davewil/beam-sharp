#!/bin/sh
D=$(cd "$(dirname "$0")" && pwd); W=${PROBE_TMP:-$(mktemp -d)}
"$D/../compile_corpus.sh" "$W" 2>&1 | tail -3 && "$D/p4_alias_cost.escript" "$W"
