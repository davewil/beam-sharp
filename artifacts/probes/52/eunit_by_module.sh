#!/usr/bin/env bash
# Run each eunit test module in its own VM, retrying a module up to 3 times when eunit cancels it with
# "timed out" (the box is shared and eunit's per-test default is 5 s). Prints one line per module and a total.
# usage: eunit_by_module.sh COMPILER_DIR   (after `rebar3 eunit` once, so _build/test exists)
cd "${1:?compiler dir}" || exit 1
tp=0; tf=0; tc=0
for t in test/*_tests.erl; do
  m=$(basename "$t" .erl); try=0
  while :; do
    try=$((try+1))
    out=$(erl -noshell -pa _build/test/lib/bsc/ebin -pa _build/test/lib/bsc/test -pa _build/test/lib/*/ebin \
          -eval "R = eunit:test($m, []), io:format(\"RESULT ~p~n\",[R]), halt()." 2>&1)
    if echo "$out" | grep -q "cancelled" && [ $try -lt 3 ]; then continue; fi
    break
  done
  p=$(echo "$out" | grep -oE "Passed: [0-9]+|All [0-9]+ tests passed|Test passed|[0-9]+ tests passed" | grep -oE "[0-9]+" | head -1); p=${p:-1}
  f=$(echo "$out" | grep -oE "Failed: [0-9]+" | grep -oE "[0-9]+" | head -1); f=${f:-0}
  c=$(echo "$out" | grep -c "cancelled")
  echo "$m passed=$p failed=$f cancelled=$c tries=$try"
  if [ "$f" != 0 ] || [ "$c" != 0 ]; then echo "$out" | grep -E "^[a-z_]+_tests:|\*failed\*|foreign_module|error:" | head -12 | sed 's/^/    /'; fi
  tp=$((tp+p)); tf=$((tf+f)); tc=$((tc+c))
done
echo "TOTAL passed=$tp failed=$tf modules-cancelled=$tc"
