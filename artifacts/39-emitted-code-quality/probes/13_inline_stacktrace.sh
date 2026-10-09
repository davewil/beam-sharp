#!/usr/bin/env bash
# Counter-argument probe: does module-wide inlining change what a crash reports?  (ticket 13 sells legible stack traces)
. "$(dirname "$0")/env.sh"; V=$W/p13; rm -rf $V; mkdir -p $V
for m in plain inline; do mkdir -p $V/$m; o=""; [ $m = inline ] && o="+inline"; erlc $o -o $V/$m $A/probes/src/trace13.erl; done
for m in plain inline; do echo "--- $m"; erl -noshell -pa $V/$m -eval 'try trace13:run(0) catch error:R:St -> io:format("~p~n~p~n",[R,St]) end, halt().'; done
