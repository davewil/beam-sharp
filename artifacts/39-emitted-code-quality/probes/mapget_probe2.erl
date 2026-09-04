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

%% SPIKE for sub-investigation #3: an alternative Core-Erlang-reachable
%% lowering for `o.Field` that bs_emit's {e_proj,...} clause could target
%% instead of `erlang:map_get/2` -- a `case` with ONE map-pattern clause,
%% which is the same Abstract Format shape a `#{Field := V} = M` pattern
%% match itself lowers through, and is expressible from a plain expression
%% position (no guard needed), so it does not require projection's
%% guard-safety property to change: `case M of #{'R' := V} -> V end` is
%% itself guard-safe by construction, just like `map_get/2` is documented
%% to be in bs_emit.erl.
via_case(N) -> loop_case(N, 0).
loop_case(0, Acc) -> Acc;
loop_case(N, Acc) ->
    M = mapget_helper:mk(N),
    R = case M of #{'R' := V} -> V end,
    loop_case(N - 1, Acc + R).
