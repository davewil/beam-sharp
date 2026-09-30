#!/usr/bin/env bash
# P9: run the repo's eunit suite against base and variants A/B/C and print which tests change.
# CAVEAT: rebar3 and OTP 28 are absent, so ~450 of 1303 tests fail on BASE for toolchain reasons
# (no `json` module, `maps:iterator/2`, tests that shell out to the escript). Only the DELTA against
# base is meaningful, and only over the tests that can pass here.
source "$(dirname "$0")/env.sh"
W=/tmp/bs59-build; R=$W/repo
rm -rf $R $W/testebin; mkdir -p $R $W/testebin
(cd $REPO && tar --exclude=.git --exclude=artifacts --exclude=wayfinder/prototypes -cf - .) | (cd $R && tar xf -)
(cd $R/compiler && erlc -o $W/testebin test/*.erl 2>&1 | grep -v '^$')
MODS=$(ls $W/testebin/*.beam | xargs -n1 basename | sed 's/.beam//' | grep "_tests$" | grep -v bs_test_support | tr '\n' ' ')
for v in base A B C; do
  ( cd $R/compiler && timeout 900 erl -noshell -pa $W/ebin-$v -pa $W/testebin \
      -eval "R = eunit:test([$(echo $MODS | sed 's/ /,/g;s/,$//')], [verbose]), halt()." > $W/tests-full-$v.log 2>&1 </dev/null ) &
done; wait
for v in base A B C; do
  grep -E "\*failed\*|\*timed out\*" $W/tests-full-$v.log | sed 's/\.\.\.\[[0-9.]* s\]//; s/\.\.\.\*/ */; s/ *$//' | sort > $W/fails-$v.txt
  echo "[$v] $(grep -E 'Failed: [0-9]+' $W/tests-full-$v.log | tail -1)"
done
for v in A B C; do
  echo "== tests failing under $v that pass on base:"; comm -13 $W/fails-base.txt $W/fails-$v.txt | sed 's/^/   /'
  echo "== tests failing on base that pass under $v:"; comm -23 $W/fails-base.txt $W/fails-$v.txt | sed 's/^/   /'
done
