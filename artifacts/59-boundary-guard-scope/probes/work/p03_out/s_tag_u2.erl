-module(s_tag_u2).
-export([f/1]).
f(O) -> erlang:map_get(total, O).
