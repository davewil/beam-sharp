-module(a_tg_g).
-export([f/1]).
f(O) when erlang:map_get('Kind', O) =:= 'Order' -> erlang:map_get(total, O).
