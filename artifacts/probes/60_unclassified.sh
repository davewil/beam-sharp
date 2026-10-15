#!/usr/bin/env bash
# CLAIM (ticket 24 s2): "every function in an aggregate is exported today ... RecomputeTotal/1 is neither client API nor
#   callback and lands `unclassified`, which agents will target in tests." Tested at HEAD: (a) is there any runnable
#   classifier (boundary/callbacks/unclassified manifest)? (b) with F12's private default, is a helper in its own file
#   exported at all?
# REFUTED IF: (a) a classifier exists (grep hit outside a diagnostic tag), or (b) RecomputeTotal appears in `--api` / beam exports
#   / is callable from Erlang. CONTROL: public Apply IS in all three.
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"; cd "$REPO"
echo "=== (a) any test-boundary classifier in the compiler? (hits other than the diagnostic tag 'unclassified' in bs_diag/bs_api/bsc are a refutation)"
grep -rniE 'unclassified|boundary manifest|callbacks:' compiler/src | grep -v 'tag *=> *unclassified\|tag := unclassified\|`unclassified`\|bsc.erl:.*unhandled\|bs_diag\|bs_api.erl:2[0-9][0-9]' ; echo "(end grep)"
S=$(mktemp -d /tmp/probe60orders.XXXXXX); mkdir $S/out
echo "=== (b) a helper in its own file, F12 default"
$BSC --api "$D/60_orders/Orders"
$BSC -o $S/out --src-root "$D/60_orders" "$D/60_orders/Orders" && echo "compiled; Apply 3 ->" && $BSC --src-root "$D/60_orders" "$D/60_orders/Orders" Apply "[1,2,3]"
erl -noshell -pa $S/out -eval 'io:format("beam exports: ~p~n",['"'"'Orders'"'"':module_info(exports)]), io:format("Erlang call of private RecomputeTotal: ~p~n",[element(1,catch '"'"'Orders'"'"':'"'"'RecomputeTotal'"'"'([1],0))]), io:format("CONTROL Erlang call of public Apply: ~p~n",[catch '"'"'Orders'"'"':'"'"'Apply'"'"'([1,2])]), halt().'
