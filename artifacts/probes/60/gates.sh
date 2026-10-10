#!/usr/bin/env bash
# Slow (about 10 minutes per tree). Reruns the existing suite and the diagnostics gate on
# unpatched HEAD and on each prototype, from clean clones. Observed results are in gates-output.txt.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(cd "$HERE/../../.." && pwd)
source /tmp/claude-0/env.sh
S=$(mktemp -d /tmp/claude-0/gates60.XXXXXX)
for v in base position written; do
  git clone -q "$REPO" "$S/$v"; [ $v != base ] && (cd "$S/$v" && git apply "$HERE/patch-$v.diff")
  ( cd "$S/$v/compiler" && rebar3 escriptize >/dev/null 2>&1
    echo "=== $v: rebar3 eunit"; ( time rebar3 eunit ) 2>&1 | grep -E 'tests passed|Failed:|cancelled|^real'
    echo "=== $v: bin/check-diagnostics.sh"; ./bin/check-diagnostics.sh 2>&1 | tail -n 1 )
done
