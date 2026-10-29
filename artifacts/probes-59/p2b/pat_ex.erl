-module(pat_ex).
-export([pub/1, loop/3]).
pub(#{'Kind' := 'M.Order'} = O) -> priv(O).
priv(O) -> map_get(f1, O).
loop(0, _, Acc) -> Acc;
loop(N, O, Acc) -> loop(N-1, O, Acc + pub(O)).
