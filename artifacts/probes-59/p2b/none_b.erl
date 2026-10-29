-module(none_b).
-export([pub/1, loop/3]).
pub(O)  -> priv(O).
priv(O)  -> map_get(f1, O).
loop(0, _, Acc) -> Acc;
loop(N, O, Acc) -> loop(N-1, O, Acc + pub(O)).
