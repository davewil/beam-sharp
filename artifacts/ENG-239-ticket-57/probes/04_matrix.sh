#!/bin/bash
# Runs table / guards / more against baseline and the four scratch variants. Same inputs, only the build differs.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
erlc -o $W/ebin $D/drv.erl $D/guards.erl $D/table.erl $D/more.erl
for V in baseline A1 A2 B1 B2 B3; do
  E=$W/v_$V/ebin; [ $V = baseline ] && E=$W/ebin
  echo "=================== $V ==================="
  erl -noshell -pa $E -eval 'io:format("--- refinement table ---~n"), table:main(), io:format("--- guards/arms ---~n"), guards:main(), more:main(), halt().' 2>&1
done
