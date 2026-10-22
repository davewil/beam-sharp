-module(shadow_map).
-export([f/1]).
-type map() :: {my_map, term()}.
-spec f(map()) -> ok.
f(_) -> ok.
