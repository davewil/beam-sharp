-module(every_fn).
-export([pub/1, loop/3]).
pub(O) when map_get('Kind', O) == 'M.Order' -> priv(O).
priv(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
loop(0, _, Acc) -> Acc;
loop(N, O, Acc) -> loop(N-1, O, Acc + pub(O)).
