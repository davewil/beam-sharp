-module(a_tg_u).
-export([f/1]).
f(O) -> erlang:map_get(total, O).
