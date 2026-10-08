#!/usr/bin/env bash
# Probe 59j: which existing eunit tests pin the current scope? Run three test modules against each emitter.
# (rebar3 is unavailable; compile the tests by hand, eunit directly.)  base/A/B differ ONLY in bs_emit.beam.
here=$(cd "$(dirname "$0")" && pwd); T=/home/user/beam-sharp/compiler/test
mkdir -p "$here/t"; erlc -o "$here/t" -I /home/user/beam-sharp/compiler/include $T/bs_test_support.erl $T/records_tests.erl $T/boundary_kind_tests.erl $T/boundary_range_tests.erl 2>&1 | grep -v -i warn | grep -v '^%' | head
cd /home/user/beam-sharp/compiler
for v in base:/tmp/bsbuild/ebin A:/tmp/bsb_59_a/ebin B:/tmp/bsb_59_b/ebin E:/tmp/bsb_59_e/ebin; do
  echo "=== emitter ${v%%:*}"
  erl -noshell -pa "${v#*:}" -pa "$here/t" -eval 'R = eunit:test([records_tests, boundary_kind_tests, boundary_range_tests], []), io:format("result: ~p~n",[R]), halt().' 2>&1 | grep -v "^$" | tail -25
done
