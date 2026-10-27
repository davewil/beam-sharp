#!/usr/bin/env bash
# H7: under variant B (kind test on private too) the guard on private Big/1 SURVIVES into the .beam
#     in P59 -- its argument is an untested list element, so erlc cannot prove it -- and under B
#     SumBig([100.5]) is refused. Under A it is accepted (p2). Falsifier: guard dropped, or 100.5 accepted.
# Command: ./p7_nested_survives.sh
S=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad
cd "$(dirname "$0")/bs" || exit 2
for v in "" B; do
  O=$(mktemp -d); echo "== variant ${v:-A}"
  "$S/bsc$v/_build/default/bin/bsc" -o "$O" --src-root . P59 SumBig "[100.5]" 2>&1 | head -2
  "$S/bsc$v/_build/default/bin/bsc" -o "$O" --src-root . P59 SumBig "[300]"   2>&1 | head -2
  escript ../count_beam_tests.escript "$O"
done
