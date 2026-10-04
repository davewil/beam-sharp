#!/bin/bash
# eunit on the PROTOTYPE copy (/tmp/c60a = HEAD sources + 03_prototype_within.patch + 17_within_tests.erl).
# The full run takes ~8 minutes; this script only re-runs the recipe, the .out holds what was captured:
#   run 1: full suite on the copy, ambient locale (not UTF-8), no ../aoc next to the copy
#   run 2: the four failing modules + within_tests, LANG=C.UTF-8 and /tmp/aoc -> repo aoc
#   run 3: the SAME four modules on the UNPATCHED HEAD copy (/tmp/c60), ambient locale, no aoc
export PATH=/opt/otp28/bin:$PATH
cd /tmp/c60a
/tmp/tc/rebar3 eunit                                           # run 1  (writes /tmp/c60a_eunit.log)
ln -s /home/user/beam-sharp/aoc /tmp/aoc; cp /home/user/beam-sharp/artifacts/60-which-modules-may-name-this-one/probes/17_within_tests.erl test/within_tests.erl
LANG=C.UTF-8 LC_ALL=C.UTF-8 /tmp/tc/rebar3 eunit --module=within_tests,cli_tests,diagnostic_json_tests,non_numeric_operand_tests,body_check_tests   # run 2
rm /tmp/aoc; cd /tmp/c60 && /tmp/tc/rebar3 eunit --module=cli_tests,diagnostic_json_tests,non_numeric_operand_tests,body_check_tests          # run 3
