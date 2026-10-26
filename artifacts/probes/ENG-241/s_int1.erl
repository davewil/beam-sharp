-module(s_int1).
-export([f/1]).
f(N) when is_integer(N) -> N + 1.
