-module(r_priv_g).
-export([run/2]).
run(N, O) when erlang:map_get('Kind', O) =:= 'Order' -> loop(N, O, 0).
loop(0, O, A) when erlang:map_get('Kind', O) =:= 'Order' -> A;
loop(N, O, A) when erlang:map_get('Kind', O) =:= 'Order' -> loop(N - 1, O, A + erlang:map_get(total, O)).
