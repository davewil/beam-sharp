#!/usr/bin/env bash
# P1: ticket 52's premise. A module naming a foreign module that is NOT on the code path
# compiles clean and fails at the call site with error:undef.
# Control: the same shape against a module that IS present (lists) runs.
. "$(dirname "$0")/../lib.sh"
D=$(mktemp -d); cd "$D"
mkdir Missing Present
cat > Missing/a.bs <<'B'
module Missing
using :'Elixir.Nope.Absent' {
    term new(list<(atom, term)> opts)
}
public term Go(list<(atom, term)> o)
Go(o) -> :'Elixir.Nope.Absent'.new(o)
B
cat > Present/a.bs <<'B'
module Present
using :lists {
    int sum(list<int> xs)
}
public int Go(list<int> o)
Go(o) -> :lists.sum(o)
B
echo "--- compile Missing (expect: silent, exit 0)"
bsc -o out Missing/a.bs; echo "exit=$?"
echo "--- run Missing (expect: crashed error:undef)"
bsc Missing/a.bs Go '[]' 2>&1; echo "exit=$?"
echo "--- control: run Present (expect 6)"
bsc Present/a.bs Go '[1,2,3]' 2>&1; echo "exit=$?"
