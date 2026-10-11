#!/usr/bin/env bash
# Probe (i): which existing eunit tests pin each scope? Runs every compiler/test module, EACH IN ITS OWN VM
# (the shared-VM run is polluted: see README), against the base / notag / widen scratch compilers.
# No rebar3: erlc + eunit directly.   Needs ./build-variants.sh.   ~5 min.
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
W=${W:-/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/variants}
T=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/59/tests
mkdir -p $T && cd /home/user/beam-sharp/compiler && erlc -o $T +debug_info test/*.erl 2>&1 | grep -v Warning | head -3
run_one() { v=$1; m=$2
  erl -noshell -pa $W/$v/ebin -pa $T -eval "R = eunit:test($m, []), halt(case R of ok -> 0; _ -> 1 end)." 2>&1 \
    | grep -E "\*failed\*|^\s+[a-z_]+_test.*(failed)" | sed "s/^/[$v] /"
}
export -f run_one; export W T
# Only modules that are green on BASE are compared (validate_as, float, intervals, clause_block, body_check have 5-13 failures on base itself in this scratch layout: no rebar3 escript, OTP 29).
# So: run the guard-touching modules that pass on base, one VM each.
MODS="boundary_kind_tests boundary_range_tests guard_kind_tests records_tests record_pattern_tests tagged_union_tests binary_tests map_validate_tests absent_option_tests switch_tests"
for v in ${VARIANTS:-base notag widen}; do
  echo "=== $v"
  for m in $MODS; do
    out=$(erl -noshell -pa $W/$v/ebin -pa $T -eval "R = eunit:test($m, []), halt(case R of ok -> 0; _ -> 1 end)." 2>&1)
    n=$(echo "$out" | grep -c '\*failed\*')
    echo "  $m: failed=$n  $(echo "$out" | grep -E 'passed|Failed:' | head -1)"
    echo "$out" | grep '\*failed\*' | sed 's/^/      /' | head -8
  done
done
