%%% mapget_probe.erl's first attempt was invalid: `via_pattern`'s map
%%% round-trip (construct then immediately pattern-match the SAME key) was
%%% eliminated entirely by beam_ssa_opt (verified via beam_disasm: no
%%% put_map_assoc, no get_map_elements survive -- the loop degenerates to
%%% pure integer arithmetic). That is not a fair comparison.
%%%
%%% This version forces the map through an opaque cross-module call
%%% (mapget_helper:mk/1, compiled separately) so beam_ssa_opt cannot see
%%% through the construction and fold the read away. Verified via disasm
%%% below that put_map_assoc / get_map_elements / map_get all survive on
%%% both sides.
-module(mapget_probe2).
-export([via_pattern/1, via_bif/1, via_case/1]).

via_pattern(N) -> loop_pat(N, 0).
loop_pat(0, Acc) -> Acc;
loop_pat(N, Acc) ->
    M = mapget_helper:mk(N),
    #{'R' := R} = M,
    loop_pat(N - 1, Acc + R).

via_bif(N) -> loop_bif(N, 0).
loop_bif(0, Acc) -> Acc;
loop_bif(N, Acc) ->
    M = mapget_helper:mk(N),
    R = erlang:map_get('R', M),
    loop_bif(N - 1, Acc + R).
