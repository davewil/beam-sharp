-module(s_tag0).
-export([f/1]).
f(M) -> map_get('Total', M).
