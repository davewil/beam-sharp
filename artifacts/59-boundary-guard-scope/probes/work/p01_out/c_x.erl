-module(c_x).
-export([esc/0]).
p(O) when erlang:is_integer(O) -> O + 1.
esc() -> fun p/1.

