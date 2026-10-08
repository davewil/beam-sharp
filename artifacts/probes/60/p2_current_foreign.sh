#!/bin/bash
# P2: on the CURRENT compiler, can B# name another B# module's exported function with no `using B`,
# via the foreign-call form `using :'B' { ... }`? (A caller-side check at add_module_import would not see this.)
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d)
mk $R B 'module B

public int Pub(int n)
Pub(n) -> n + 1'
mk $R A_foreign 'module A_foreign
using :'"'"'B'"'"' {
    int Pub(int n)
}
public int Go(int n)
Go(n) -> Pub(n)'
echo "--- A_foreign (no B# using; foreign-form declaration of B:Pub/1). B compiled alongside:"
(cd $R && erl -noshell -pa $BSC_EBIN -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra --src-root . B A_foreign Go 5 2>&1 | head -8)
echo "--- control: same, but the module B does not exist/compiled in this invocation"
(cd $R && erl -noshell -pa $BSC_EBIN -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra --src-root . A_foreign Go 5 2>&1 | head -8)
rm -rf $R
