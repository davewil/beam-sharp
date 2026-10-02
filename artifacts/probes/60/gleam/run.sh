#!/bin/bash
# Probe 60/gleam: internal_modules (module-level) and @internal (item-level), from OUTSIDE the
# package (path dependency, no network). Gleam 1.12.0 binary; set GLEAM=/path/to/gleam.
GLEAM=${GLEAM:-/tmp/claude-0/-home-user-beam-sharp/a3310f8a-c503-5acc-8cf0-37e76fb5554b/scratchpad/tc/gleam}
cd "$(dirname "$0")"; W=$(mktemp -d); cp -r lib app $W; cd $W/app
$GLEAM --version
echo "--- control: app imports the public API of lib"
$GLEAM build 2>&1 | tail -4 || true
[ -f build/dev/erlang/app/ebin/app_ok.beam ] || { echo "control did not build"; exit 1; }
echo "--- (1) importing lib/internal/secret from another package"
cp src/app_bad_module.gleam.txt src/app_bad.gleam
$GLEAM build > o1 2>&1; rc1=$?; cat o1; rm src/app_bad.gleam
echo "rc=$rc1"
# ORIGINAL EXPECTATION (from the brief's hint): refused. MEASURED: accepted. We assert the measurement.
[ $rc1 -eq 0 ] || { echo "Gleam now REFUSES an internal import: rewrite the brief"; exit 1; }
echo "--- (2) calling an @internal pub fn of lib's public module"
cp src/app_bad_fn.gleam.txt src/app_bad.gleam
$GLEAM build > o2 2>&1; rc2=$?; cat o2; rm src/app_bad.gleam
echo "rc=$rc2"; [ $rc2 -eq 0 ] || { echo "Gleam now REFUSES @internal calls: rewrite the brief"; exit 1; }
echo "--- (2b) what internal DOES in 1.12: hidden from the published package interface"
( cd ../lib && $GLEAM export package-interface --out $W/pi.json >/dev/null 2>&1 )
python3 -c "
import json,sys
d=json.load(open('$W/pi.json'))
print('modules in interface:',sorted(d['modules']))
print('functions of lib:',sorted(d['modules']['lib']['functions']))
sys.exit(0 if sorted(d['modules'])==['lib','lib/other'] and sorted(d['modules']['lib']['functions'])==['total'] else 1)"
echo "--- (3) inside lib itself: lib/internal/secret IS importable from lib's own modules"
cd ../lib && $GLEAM build 2>&1 | tail -2; [ -f build/dev/erlang/lib/ebin/lib.beam ] || exit 1
echo "--- (4) BEAM after the fact: internal module is a plain exported function"
erl -noshell -pa build/dev/erlang/lib/ebin -eval 'io:format("~p~n",[lib@internal@secret:recompute(21)]),halt().' | tee o4
grep -q 42 o4 && echo OK
