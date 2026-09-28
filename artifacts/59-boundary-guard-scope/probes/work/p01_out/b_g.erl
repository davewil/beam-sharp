-module(b_g).
-export([c/1]).
p(O) when erlang:is_integer(O) andalso O >= 0 andalso O =< 255 -> O + 1.
c(X) when erlang:is_integer(X) andalso X >= 0 andalso X =< 255 -> p(X).
