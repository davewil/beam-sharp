#!/usr/bin/env bash
# Cost/benefit of lowering a known interval to a guard: plain (return type any) vs is_integer-only (what ticket 18 emits at an FFI boundary)
# vs is_integer + 0..99 range guard. 2M iterations per call, 60 interleaved rounds, x3.
. "$(dirname "$0")/env.sh"
V=$W/p09; rm -rf $V; mkdir -p $V; erlc -o $V $A/probes/src/lib08.erl $A/probes/src/loop09.erl
for i in 1 2 3; do erl -noshell -pa $V -eval 'loop09:bench(2000000, 60), halt().'; echo; done
