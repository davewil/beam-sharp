-module(r_priv_u).
-export([run/2]).
run(N, O) when erlang:map_get('Kind', O) =:= 'Order' -> loop(N, O, 0).
loop(0, _O, A) -> A;
loop(N, O, A) -> loop(N - 1, O, A + erlang:map_get(total, O)).
