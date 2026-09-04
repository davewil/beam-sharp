%%% Isolates the ONE mechanism identified as the cause of ShapeBench's 17-19%
%%% gap: bs_emit lowers every `o.Field` projection to `erlang:map_get/2` (a
%%% BIF call), never to `get_map_elements` (the instruction Erlang's own
%%% compiler emits for a `#{Key := V} = Map` pattern match). Both loops
%%% below build the identical map each iteration and read the identical
%%% field; the ONLY difference is how the field is read.
-module(mapget_probe).
-export([via_pattern/1, via_bif/1]).

via_pattern(N) -> loop_pat(N, 0).
loop_pat(0, Acc) -> Acc;
loop_pat(N, Acc) ->
    M = #{'Kind' => circle, 'R' => N},
    #{'R' := R} = M,
    loop_pat(N - 1, Acc + R).

via_bif(N) -> loop_bif(N, 0).
loop_bif(0, Acc) -> Acc;
loop_bif(N, Acc) ->
    M = #{'Kind' => circle, 'R' => N},
    R = erlang:map_get('R', M),
    loop_bif(N - 1, Acc + R).
