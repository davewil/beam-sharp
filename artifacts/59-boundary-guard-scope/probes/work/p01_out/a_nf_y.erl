-module(a_nf_y).
-export([f/1]).
f(O) -> erlang:map_get(total, O).
