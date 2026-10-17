#!/usr/bin/env bash
# P1: what does a `using` of an absent module do today, at compile and at run time?
set -u; . "$(dirname "$0")/common.sh"
mkfake $WORK/lib
mkdir -p $WORK/Dep; cat > $WORK/Dep/dep.bs <<'EOF'
module Dep

using :fakereq {
    term new(list<(atom, term)> opts)
}

public term Make(int n)

Make(n) -> :fakereq.new([(:n, n)])
EOF
echo "--- control: ERL_LIBS unset (module absent)"
(cd $WORK && env -u ERL_LIBS $BSC Dep Make 1 2>&1 | head -5)
echo "--- ERL_LIBS=fake lib (module present)"
(cd $WORK && ERL_LIBS=$WORK/lib $BSC Dep Make 1 2>&1 | head -5)
echo "--- compile only, ERL_LIBS unset: does bsc accept the module at all?"
(cd $WORK && env -u ERL_LIBS $BSC Dep; echo "compile-only exit=$?")
