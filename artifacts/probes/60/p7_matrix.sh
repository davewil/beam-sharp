#!/usr/bin/env bash
# Probe 7 - ONE program, three compilers: the same Reports->Ledger edge is accepted by today's bsc and refused by the
# two prototypes, while the legitimate Billing->Ledger edge stays accepted by all three. A refusal that fires on
# everything would pass half; the green half is what makes the red meaningful.
# Run: p7_matrix.sh BASE_DIR P1_DIR P2_DIR
here=$(cd "$(dirname "$0")" && pwd)
row() { # label bsc tree billing-expect reports-expect
  local b r
  b=$("$2/bsc" --src-root "$3" "$3/Shop/Billing" Charge 5 2 2>&1 | grep -v 'Warning' | head -1)
  r=$("$2/bsc" --src-root "$3" "$3/Shop/Reports" Restate 5 2>&1 | grep -v 'Warning' | head -1)
  printf '%-34s Billing->Ledger: %-8s Reports->Ledger: %s\n' "$1" "$b" "$r"
}
row "today (tree, plain Ledger)"            $1 $here/tree
row "P1 segment (tree_internal)"            $2 $here/tree_internal
row "P2 marker  (tree_marker)"              $3 $here/tree_marker
echo "-- controls: each prototype on the PLAIN tree must change nothing (no regression):"
row "P1 compiler, plain tree"               $2 $here/tree
row "P2 compiler, plain tree"               $3 $here/tree
echo "-- and today's compiler on the prototype trees accepts them (the marker/segment is inert there? P2 needs the keyword):"
row "today's compiler, Internal-segment tree" $1 $here/tree_internal
row "today's compiler, marker tree"         $1 $here/tree_marker
