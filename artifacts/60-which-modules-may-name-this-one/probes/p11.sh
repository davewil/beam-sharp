#!/usr/bin/env bash
# P11: a parent module and a child directory as two modules (Shop.Orders + Shop.Orders.Internal), unit = narrow subtree.
# Part 1 HEAD compiler with the `within` line stripped (does the layout itself coexist?); part 2 patched compiler.
P=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad
export PATH=$P/beam/bin:$PATH LANG=C.UTF-8
bsc() { erl -noshell -pa $1 -eval 'bsc:main(init:get_plain_arguments()), halt(0).' -extra "${@:2}"; }
cd "$(dirname "$0")/p11"
rm -rf $P/60/p11ctl; cp -r . $P/60/p11ctl; sed -i '/^within /d' $P/60/p11ctl/src/Shop/Orders/Internal/Tax.bs
echo "## HEAD compiler, no within: Shop.Orders (parent) calling child module"; (cd $P/60/p11ctl && bsc $P/bsc-build/ebin --src-root src src/Shop/Orders Total 50); 
echo "## HEAD compiler, no within: Shop.Reports (sibling) calling the child module -> accepted"; (cd $P/60/p11ctl && bsc $P/bsc-build/ebin --src-root src src/Shop/Reports Gross 50)
echo "## patched, within Shop.Orders: parent"; bsc $P/60/proto/ebin --src-root src src/Shop/Orders Total 50
echo "## patched, within Shop.Orders: sibling Reports -> refused"; bsc $P/60/proto/ebin --src-root src src/Shop/Reports Gross 50
