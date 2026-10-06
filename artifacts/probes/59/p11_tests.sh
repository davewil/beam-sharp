#!/usr/bin/env bash
# p11 -- which existing eunit tests encode the CURRENT scope?  Run the repo's own suite (copied) under
# base / a / b / c; a test that goes red under an option is a place the current scope was asserted.
# REFUTES "nothing asserts the asymmetry" if every variant is green.  (base must be green or the rest is moot.)
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p11"; rm -rf "$O"; mkdir -p "$O"
# Under host load the full suite's 5 s per-test timeouts cancel the run (seen: 306 of 1312 ran, then
# "One or more tests were cancelled"). So by default run the modules that exercise the boundary guards, record
# tags, visibility and the corpus; FULL=1 runs everything (needs a quiet host; base was green: 1312 tests).
MODS=${MODS:-boundary_kind_tests,boundary_range_tests,records_tests,record_pattern_tests,aggregate_tests,visibility_tests,open_field_set_tests,absent_option_tests,foreign_guard_tests,api_tests,float_tests,guard_kind_tests,validation_error_record_tests}
for v in base a b c; do
  if [ -n "$FULL" ]; then ARGS=""; else ARGS="--module=$MODS"; fi
  ( cd "$W/$v/compiler" && rebar3 eunit $ARGS > "$O/$v.log" 2>&1 ); echo "exit=$?" >> "$O/$v.log"
  echo "== $v: $(grep -E 'tests passed|Failed:|Passed:|cancelled|test passed' "$O/$v.log" | tail -2 | tr '\n' ' ')"
  grep -E "^\s+[a-z_]+_tests:[a-z_0-9]+.*(failed|\*failed\*)|\*failed\*" "$O/$v.log" | sed 's/^ *//' | sort -u > "$O/$v.failed.txt"
  echo "   failing: $(wc -l < "$O/$v.failed.txt")"; head -30 "$O/$v.failed.txt"
done
