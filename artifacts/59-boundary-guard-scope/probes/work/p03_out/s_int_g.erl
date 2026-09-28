-module(s_int_g).
-export([f/1]).
f(N) when erlang:is_integer(N) -> N + 1.
