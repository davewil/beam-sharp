#!/usr/bin/env bash
# timing.sh : 5 rounds x 4 builds, interleaved, 40 timed runs each (>=30 asked). Needs the patched ebins (see README).
S=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad
source $S/env.sh
here=$(cd "$(dirname "$0")" && pwd)
erlc -o $S/57 $here/timing.erl
for round in 1 2 3 4 5; do
  for v in base A B Barith; do
    echo "## round=$round build=$v"
    (cd $S/57 && erl -noshell -pa $S/57/ebin-$v -pa $S/57 -eval 'timing:main(40),halt().' | grep -E "median|synthetic")
  done
done
