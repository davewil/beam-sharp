-module(b_u).
-export([c/1, p/1]).
p(O) -> erlang:map_get(total, O).
c(W) when erlang:map_get('Kind', W) =:= 'Wrapper' -> p(erlang:map_get(order, W)).
