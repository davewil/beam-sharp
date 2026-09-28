-module(a_fl_g).
-export([f/1]).
f(O) when erlang:is_float(O) -> O * 2.0.
