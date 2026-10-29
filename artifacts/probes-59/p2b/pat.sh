#!/bin/bash
# variant: tag test as a head pattern (get_map_elements) rather than guard map_get, to see if the shape explains the cost
cd "$(dirname "$0")"
cat > pat_ex.erl <<'EOT'
-module(pat_ex).
-export([pub/1, loop/3]).
pub(#{'Kind' := 'M.Order'} = O) -> priv(O).
priv(O) -> map_get(f1, O).
loop(0, _, Acc) -> Acc;
loop(N, O, Acc) -> loop(N-1, O, Acc + pub(O)).
EOT
erlc -o ebin pat_ex.erl
sed -i 's/\[none_a, none_b, ex_only, every_fn\]/[none_a, none_b, ex_only, pat_ex]/' bench.escript
escript bench.escript
sed -i 's/\[none_a, none_b, ex_only, pat_ex\]/[none_a, none_b, ex_only, every_fn]/' bench.escript
