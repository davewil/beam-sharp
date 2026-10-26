-module(s_tag1).
-export([f/1]).
f(M) when map_get('Kind', M) == order -> map_get('Total', M).
