#!/usr/bin/env bash
# compile.erl:77-83 says inlining turns function_clause into case_clause. Matters for ticket 18's promise
# ("a foreign term that breaks your types will crash ... function_clause at the call site") and for tests asserting it.
. "$(dirname "$0")/env.sh"; V=$W/p17; rm -rf $V; mkdir -p $V
for m in plain inline; do mkdir -p $V/$m; o=""; [ $m = inline ] && o="+inline"; erlc $o -o $V/$m $A/probes/src/fc17.erl; done
for m in plain inline; do for f in run run_exported_callee; do
 echo -n "$m $f(3): "; erl -noshell -pa $V/$m -eval 'try fc17:'$f'(3) catch error:R:St -> io:format("~p  top frame: ~p~n",[R, hd(St)]) end, halt().'; done; done
echo; echo "does the compiler's own test-suite assert function_clause?"; grep -rln "function_clause" $REPO/compiler/test $REPO/compiler/src 2>/dev/null | head; grep -rn "function_clause" $REPO/compiler/test 2>/dev/null | wc -l
