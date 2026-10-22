-module(shadow_integer).
-export([f/1]).
-type integer() :: foo | bar.
-spec f(integer()) -> ok.
f(_) -> ok.
