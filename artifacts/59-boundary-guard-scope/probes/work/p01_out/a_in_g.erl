-module(a_in_g).
-export([f/1]).
f(O) when erlang:is_integer(O) -> O + 1.
