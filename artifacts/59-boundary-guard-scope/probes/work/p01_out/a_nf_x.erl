-module(a_nf_x).
-export([f/1]).
f(O) -> erlang:map_get(total, O).
