%% Hand-written control: same as loop_case, but reads via erlang:map_get/2
%% directly -- what bs_emit.erl:793-795 always emits. This isolates "does
%% map_get vs get_map_elements matter" from "does beam-sharp's specific
%% codegen shape (extra call, tuple boundary, etc.) matter" by holding
%% everything else identical to loop_case.erl.
-module(loop_mapget).
-export([sum/3]).

sum(_, 0, Acc) -> Acc;
sum(R, N, Acc) ->
    Total = erlang:map_get('Total', R),
    sum(R, N - 1, Acc + Total).
