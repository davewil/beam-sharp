#!/bin/sh
# 59 / probe 3 — census of boundary guards over every module bsc builds from compiler/examples.
D=$(cd "$(dirname "$0")" && pwd); W=${PROBE_TMP:-$(mktemp -d)}
"$D/../compile_corpus.sh" "$W" 2>&1 | tail -3 && "$D/p3_guard_census.escript" "$W"
