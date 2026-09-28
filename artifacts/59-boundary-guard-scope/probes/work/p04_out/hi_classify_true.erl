-module(hi_classify_true).
-export([top/1, nested/1, escape/0, many/1, top_i/1, nested_i/1, escape_i/0, many_i/1, consume/1]).
top(O) when erlang:map_get('Kind', O) =:= 'Order' -> p(O).
nested(W) when erlang:map_get('Kind', W) =:= 'Wrapper' -> p(erlang:map_get(order, W)).
escape() -> fun p/1.
many(L) when erlang:is_list(L) -> lists:map(fun p/1, L).
p(O) when erlang:map_get('Kind', O) =:= 'Order' -> ok.
consume({kept, O}) -> erlang:map_get(total, O).
top_i(N) when erlang:is_integer(N) -> q(N).
nested_i(W) when erlang:map_get('Kind', W) =:= 'Wrapper' -> q(erlang:map_get(count, W)).
escape_i() -> fun q/1.
many_i(L) when erlang:is_list(L) -> lists:map(fun q/1, L).
q(N) when N >= 9 andalso erlang:is_integer(N) -> reserved;
q(N) when erlang:is_integer(N) -> low.
