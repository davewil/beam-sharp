#!/bin/sh
# 59 / probe 1 — the same body exported and private, for the record TAG test and the int KIND+RANGE test: what does bsc emit?
D=$(cd "$(dirname "$0")" && pwd); BSC=${BSC:?set BSC}; W=${PROBE_TMP:-$(mktemp -d)}
"$BSC" -o "$W" "$D/bs/Scope" || exit 2
"$D/../dump_abstr.escript" "$W/Scope.abstr" PubTotal PrivTotal PubOctet PrivOctet Through
