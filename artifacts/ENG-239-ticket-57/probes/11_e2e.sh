#!/bin/bash
# H: A1 and B3 make a signed domain USABLE end to end (checker accepts, real bs_emit forms compile, the beam runs right):
#    P1 negative literal returned as NonPos + negative-literal guards; P3 a Delta clamp.
#    And baseline's `n / -0` (F26 refuses `n / 0`) passes the checker and dies at run time with badarith.
# FALSIFIED if: a build accepts and returns a wrong value, or A1/B3 accept `n / -0`.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
for V in baseline A1 A2 B2 B3; do
  E=$W/v_$V/ebin; [ $V = baseline ] && E=$W/ebin
  erlc -o $E $D/drv.erl $D/e2e.erl
  echo "=========== $V"; erl -noshell -pa $E -eval 'e2e:main(), halt().' 2>&1 | head -12
done
