#!/bin/bash
# generates 4 modules: gtag (tag guard, exported), gint (is_integer guard), u1/u2 (identical unguarded, noise control)
set -e
cd "$(dirname "$0")"; mkdir -p ebin
mk() { # name, head-guard, body, loopcall
cat > $1.erl <<EOT
-module($1).
-export([total/1, loop_local/3, loop_remote/3]).
total($4) $2 -> $3.
loop_local(0, _, Acc) -> Acc;
loop_local(N, O, Acc) -> loop_local(N-1, O, Acc + total(O)).
loop_remote(0, _, Acc) -> Acc;
loop_remote(N, O, Acc) -> loop_remote(N-1, O, Acc + $1:total(O)).
EOT
}
mk u1   ""                                           "map_get(f1, O)" O
mk u2   ""                                           "map_get(f1, O)" O
mk gtag "when map_get('Kind', O) == 'M.Order'"       "map_get(f1, O)" O
# int family: arithmetic body
mk i1   ""                                           "O + 1" O
mk i2   ""                                           "O + 1" O
mk gint "when is_integer(O)"                         "O + 1" O
erlc -o ebin *.erl
