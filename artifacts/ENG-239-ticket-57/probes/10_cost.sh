#!/bin/bash
# What each fix costs at compile time, same machine/OTP 25. Numbers are us per call over 3000 calls after a warm-up call.
# A refused program raises inside check/1, so the refused rows print nothing (catch) on builds that cannot read them.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad/w57}
D=$(cd "$(dirname "$0")" && pwd)
for V in baseline A1 B2; do
  E=$W/v_$V/ebin; [ $V = baseline ] && E=$W/ebin
  erlc -o $E $D/drv.erl $D/cost.erl
  echo "=========== $V"; erl -noshell -pa $E -eval 'cost:main(), halt().' 2>&1 | head -12
done
