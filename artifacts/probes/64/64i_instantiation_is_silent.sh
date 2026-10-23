#!/usr/bin/env bash
# PROBE 64i — is the absorption refusal also applied when T is INFERRED as `term` at a call?
# Treatment: polymorphic Head<T>/First<T> returning option<T>/result<T,atom>, called on list<term>.
# Controls:  the same functions called on list<int> (nothing absorbed), and the written form `option<term>`
#            (refused — see 64a O2). A stored sentinel value is the discriminating input.
set -uo pipefail
: "${BSC:?source env.sh first}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P="$HERE/64i/Poly/Poly.bs"
echo "== bsc --api (any refusal would be printed here) =="; "$BSC" --api "$P"
run() { printf '  %-12s %-22s => ' "$1" "$2"; "$BSC" "$P" "$1" "$2" 2>&1 | tail -1; }
echo "== option side: Empty(list<term>) must say :nonempty for a one-element list =="
run Empty '[:nothing]'     # BUG if :empty: element is a stored :nothing
run Empty '[]'
run Empty '[5]'
run EmptyInts '[3]'        # control
run EmptyInts '[]'         # control
echo "== result side: Outcome(list<term>) must say :ok for a one-element list =="
run Outcome '[(:error, :boom)]'   # BUG if :failed: element is a stored (:error, _)
run Outcome '[]'
run Outcome '[5]'
run OutcomeInts '[3]'      # control
run OutcomeInts '[]'       # control
