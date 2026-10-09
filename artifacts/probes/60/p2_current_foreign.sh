#!/bin/bash
# P2: can B# source itself get past a caller-side check at add_module_import? (unpatched bsc)
#  (a) name B's PascalCase function in a foreign `using :'B' { ... }` declaration; (b) go through :erlang.apply with quoted atoms.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d)
mk $R B 'module B

public int Pub(int n)
Pub(n) -> n + 1

private int Priv(int n)
Priv(n) -> n + 2'
mk $R A_foreign 'module A_foreign
using :'"'"'B'"'"' {
    int Pub(int n)
}
public int Go(int n)
Go(n) -> Pub(n)'
mk $R A_dyn_pub 'module A_dyn_pub
using :erlang {
    term apply(atom m, atom f, list<term> args)
}
public term Go(int n)
Go(n) -> :erlang.apply(:'"'"'B'"'"', :'"'"'Pub'"'"', [n])'
mk $R A_dyn_priv 'module A_dyn_priv
using :erlang {
    term apply(atom m, atom f, list<term> args)
}
public term Go(int n)
Go(n) -> :erlang.apply(:'"'"'B'"'"', :'"'"'Priv'"'"', [n])'
echo "--- (a) foreign declaration naming B's PascalCase function (no B# 'using B'):"; cc $R A_foreign | head -3
echo "--- (b) :erlang.apply(:'B', :'Pub', [5]) from B# source, B# 'using B' absent. Compile+run:"; cc $R B >/dev/null 2>&1; cc $R A_dyn_pub Go 5 2>&1 | grep -v Warning | head -4
echo "--- (b') same against the PRIVATE function (control: the BEAM's export list is the only enforcement left):"; cc $R A_dyn_priv Go 5 2>&1 | grep -v Warning | head -4 | cut -c1-200
rm -rf $R
