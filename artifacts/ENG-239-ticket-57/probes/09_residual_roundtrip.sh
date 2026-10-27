#!/bin/bash
# H: once the refinement `value >= -10 and value <= 10` is writable, the residual of a function that handles only 0 is
#    `-10..-1 | 1..10`, and pasting those two intervals back as relational patterns is accepted (so ticket 38's
#    "residual the surface cannot accept" is a REFINEMENT-site gap only, because patterns already take `-N`).
# FALSIFIED if: the residual differs from -10..-1 | 1..10, or the pasted program is refused.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
for V in baseline A1 B2; do
  E=$W/v_$V/ebin; [ $V = baseline ] && E=$W/ebin
  erlc -o $E $D/drv.erl $D/guards.erl $D/roundtrip.erl
  echo "=========== $V"; erl -noshell -pa $E -eval 'roundtrip:main(), halt().' 2>&1 | head -30
done
