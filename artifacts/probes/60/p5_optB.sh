#!/bin/bash
# P5: Option B (third marker `internal` on the signature; unit = the callee module's own subtree). Patched vs unpatched bsc.
. "$(dirname "$0")/lib60.sh"
R=$(mktemp -d); tree_b $R
run() { local ebin=$1; shift; for m in "$@"; do
  printf '%-22s ' $m; out=$(BSC_EBIN=$ebin cc $R $m | grep -v 'Warning: function' | cut -c1-200); [ -z "$out" ] && echo accepted || { echo REFUSED; echo "$out" | sed 's/^/      | /' | head -4; }; done; }
M="Acme/Orders Acme/Orders/Tests Acme/Billing_unq Acme/Billing_qual Acme/Billing_pub Acme/Billing_fun"
echo "=== UNPATCHED bsc (baseline: 'internal' is not a keyword; the callee file itself is a syntax error)"; run /tmp/bsbuild/ebin Acme/Orders
echo "=== PATCHED bsc, Option B"; run /tmp/bsb_60_b/ebin $M
echo "=== run the hand-out bypass and the allowed descendant (patched)"
BSC_EBIN=/tmp/bsb_60_b/ebin cc $R Acme/Billing_fun Due 5 | grep -v Warning
BSC_EBIN=/tmp/bsb_60_b/ebin cc $R Acme/Orders/Tests Check 5 | grep -v Warning
echo "=== runtime: is the internal function in the .beam export list, and callable from Erlang?"
BSC_EBIN=/tmp/bsb_60_b/ebin cc $R Acme/Orders >/dev/null
cat > $R/rt.erl <<'ERL'
-module(rt).
-export([main/0]).
main() ->
    M = list_to_atom("Acme.Orders"),
    io:format("exports: ~p~n", [[E || E = {N,_} <- M:module_info(exports), N =/= module_info]]),
    io:format("erlang:apply(Acme.Orders,Recompute,[5]) -> ~p~n", [erlang:apply(M, list_to_atom("Recompute"), [5])]).
ERL
(cd $R && erlc rt.erl && erl -noshell -pa . -eval 'rt:main(), halt().')
rm -rf $R
