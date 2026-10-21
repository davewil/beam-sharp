#!/usr/bin/env bash
# Ticket 52: nothing in a .bs file records what it needs. Reproduce on today's compiler with a stand-in
# dependency laid out as rebar3/mix lay one out: <libs>/mydep-1.0.0/ebin/{mydep.app,mydep.beam}.
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
mkdir -p $d/libs/mydep-1.0.0/ebin $d/Dep
printf -- '-module(mydep).\n-export([answer/0]).\nanswer() -> 42.\n' > $d/mydep.erl
erlc -o $d/libs/mydep-1.0.0/ebin $d/mydep.erl
printf '{application,mydep,[{vsn,"1.0.0"},{modules,[mydep]},{registered,[]},{applications,[kernel,stdlib]}]}.\n' > $d/libs/mydep-1.0.0/ebin/mydep.app
cp "$root/artifacts/probes/src52/Dep.bs" $d/Dep/dep.bs
BSC_EBIN=${BSC_EBIN:-$PROBE_HOME/variants/base/ebin}
echo "-- 1. compile + run WITHOUT the dependency on the path (the other machine)"
env -u ERL_LIBS BSC_EBIN=$BSC_EBIN $BSC $d/Dep Ask 2>&1 | head -6; echo "exit: ${PIPESTATUS[0]}"
echo "-- 2. same source WITH ERL_LIBS pointing at it (the author's machine)"
ERL_LIBS=$d/libs BSC_EBIN=$BSC_EBIN $BSC $d/Dep Ask 2>&1 | head -6; echo "exit: ${PIPESTATUS[0]}"
