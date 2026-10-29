-module(gtag).
-export([total/1, loop_local/3, loop_remote/3]).
total(O) when map_get('Kind', O) == 'M.Order' -> map_get(f1, O).
loop_local(0, _, Acc) -> Acc;
loop_local(N, O, Acc) -> loop_local(N-1, O, Acc + total(O)).
loop_remote(0, _, Acc) -> Acc;
loop_remote(N, O, Acc) -> loop_remote(N-1, O, Acc + gtag:total(O)).
