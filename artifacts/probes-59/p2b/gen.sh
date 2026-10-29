#!/bin/bash
cd "$(dirname "$0")"; mkdir -p ebin
mk() { # module, pub guard, priv guard
cat > $1.erl <<EOT
-module($1).
-export([pub/1, loop/3]).
pub(O) $2 -> priv(O).
priv(O) $3 -> map_get(f1, O).
loop(0, _, Acc) -> Acc;
loop(N, O, Acc) -> loop(N-1, O, Acc + pub(O)).
EOT
}
T="when map_get('Kind', O) == 'M.Order'"
mk ex_only  "$T" ""     # exported-only: pub guarded, priv not
mk every_fn "$T" "$T"   # every function: both guarded
mk none_a   ""   ""     # no guards (control A)
mk none_b   ""   ""     # identical to none_a (noise control)
erlc -o ebin *.erl
