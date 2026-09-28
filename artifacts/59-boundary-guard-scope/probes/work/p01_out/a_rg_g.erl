-module(a_rg_g).
-export([f/1]).
f(O) when erlang:is_integer(O) andalso O >= 0 andalso O =< 255 -> O + 1.
