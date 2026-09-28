-module(s_tag_u).
-export([f/1]).
f(O) -> erlang:map_get(total, O).
