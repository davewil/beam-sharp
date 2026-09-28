-module(b_g).
-export([c/1]).
p(O) when erlang:is_integer(O) -> O + 1.
c(X) when erlang:is_integer(X) -> p(X).
