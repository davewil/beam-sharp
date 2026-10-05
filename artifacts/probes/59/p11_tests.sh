#!/usr/bin/env bash
# p11 -- which existing eunit tests encode the CURRENT scope?  Run the repo's own suite (copied) under
# base / a / b / c; a test that goes red under an option is a place the current scope was asserted.
# REFUTES "nothing asserts the asymmetry" if every variant is green.  (base must be green or the rest is moot.)
. "$(dirname "$0")/lib.sh"; cd "$HERE"
O="$OUT/p11"; rm -rf "$O"; mkdir -p "$O"
for v in base a b c; do
  ( cd "$W/$v/compiler" && rebar3 eunit > "$O/$v.log" 2>&1 ); echo "exit=$?" >> "$O/$v.log"
  echo "== $v: $(grep -E 'tests passed|Failed:|Passed|failed' "$O/$v.log" | tail -2 | tr '\n' ' ')"
  grep -E "^\s+[a-z_]+_tests:[a-z_0-9]+.*(failed|\*failed\*)|\*failed\*" "$O/$v.log" | sed 's/^ *//' | sort -u > "$O/$v.failed.txt"
  echo "   failing: $(wc -l < "$O/$v.failed.txt")"; head -30 "$O/$v.failed.txt"
done
