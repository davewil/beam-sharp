%% Hand-written control: identical semantics to Loop:'Sum'/3, but the field
%% read goes through a map PATTERN (get_map_elements) instead of
%% erlang:map_get/2.
-module(loop_case).
-export([sum/3]).

sum(_, 0, Acc) -> Acc;
sum(R, N, Acc) ->
    case R of
        #{'Total' := Total} -> sum(R, N - 1, Acc + Total)
    end.
