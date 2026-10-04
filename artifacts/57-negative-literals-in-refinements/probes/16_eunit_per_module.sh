#!/usr/bin/env bash
# Run the compiler's own eunit suite on a prototype copy, ONE MODULE PER rebar3 invocation, retrying a failing
# module up to 4 times. Reason: the machine is shared (load avg ~15 on 4 vCPU; eunit/bsc processes from OTHER
# sessions were running: /tmp/p59, /tmp/c60a) and eunit's 5s per-test timeout CANCELS the rest of a run, so one
# `rebar3 eunit` aborted after ~230-300 tests on every variant including the unpatched one (eunit_whole_suite_*.log).
# A module that fails 4/4 is a real failure; one that passes on a retry is load noise.
# usage: bash 16_eunit_per_module.sh VARIANT
v=$1
PROTO=${PROTO:-/tmp/claude-0/-home-user-beam-sharp/4180a786-23e5-53e3-b71e-94fb1d89eea9/scratchpad/proto}
export PATH=/opt/otp28/bin:$PATH; export LC_ALL=C.UTF-8 LANG=C.UTF-8
cd $PROTO/$v/compiler || exit 2
/tmp/tc/rebar3 escriptize >/dev/null 2>&1
for f in test/*_tests.erl; do
  m=$(basename $f .erl)
  for try in 1 2 3 4; do
    out=$(/tmp/tc/rebar3 eunit --module=$m 2>&1); rc=$?
    [ $rc -eq 0 ] && break
  done
  summ=$(printf '%s\n' "$out" | grep -E "tests passed|Passed: [0-9]+|Failed: [0-9]+" | tail -1)
  if [ $rc -eq 0 ]; then st="PASS(try $try)"; else st="FAIL(4/4)"; printf '%s\n' "$out" > /tmp/eunit_fail_${v}_$m.log; fi
  printf '%-34s %-13s %s\n' "$m" "$st" "$summ"
done
