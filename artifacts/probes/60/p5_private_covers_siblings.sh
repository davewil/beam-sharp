#!/usr/bin/env bash
# Probe 5 - is ticket 24's `RecomputeTotal` (the consumer ticket 60 cites) still unclassifiable after F12?
# Run: p5_private_covers_siblings.sh BSC_DIR
here=$(cd "$(dirname "$0")" && pwd); bsc=$1/bsc; t=$here/tree_orders
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
echo "5a Apply (public) calls RecomputeTotal (private, sibling file):"; $bsc --src-root $t -o $out $t/Shop/Orders Apply 40 2 2>&1 | grep -v Warning
echo "5b exports of the emitted module (RecomputeTotal absent = the client API is exactly the public set):"
erl -noshell -pa $out -eval "io:format(\"~p~n\", [[E || {N,_}=E <- 'Shop.Orders':module_info(exports), N =/= module_info, N =/= 'bs@type_atoms']]), halt()."
