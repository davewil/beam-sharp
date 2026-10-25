#!/usr/bin/env escript
%% P11: BEAM cost of bare-value vs tagged-{ok,V} lookup results.
%% per-term words (erts_debug:flat_size/size), external size, and a 1M-lookup loop: time + minor GCs + words allocated.
main(_) ->
    Vals = [{"small int 7", 7}, {"big int 1 bsl 70", 1 bsl 70}, {"atom", foo}, {"float", 1.5},
            {"short binary <64B (heap)", <<"hello">>}, {"binary 100B (refc)", binary:copy(<<"x">>, 100)},
            {"2-tuple {1,2}", {1,2}}, {"list of 3", [1,2,3]}, {"small map #{a=>1}", #{a=>1}}],
    io:format("~-28s ~10s ~10s ~8s ~10s ~10s~n", ["value","bare words","tag words","delta","bare ext B","tag ext B"]),
    [begin
         B = erts_debug:flat_size(V), T = erts_debug:flat_size({ok, V}), BE = byte_size(term_to_binary(V)), TE = byte_size(term_to_binary({ok, V})),
         io:format("~-28s ~10w ~10w ~8w ~10w ~10w~n", [N, B, T, T-B, BE, TE])
     end || {N, V} <- Vals],
    io:format("absent atom :nothing words=~w ; tagged absent :absent words=~w~n", [erts_debug:flat_size(nothing), erts_debug:flat_size(absent)]),
    io:format("control: {some, V} == {ok,V} words: ~w vs ~w~n", [erts_debug:flat_size({some,7}), erts_debug:flat_size({ok,7})]),
    %% loop: N lookups against a 1000-key map, 50% hits.
    N = 1000000,
    M = maps:from_list([{I, I*2} || I <- lists:seq(1, 1000, 2)]),   %% odd keys present
    BareF = fun(K) -> case M of #{K := V} -> V; _ -> nothing end end,
    TagF  = fun(K) -> case M of #{K := V} -> {ok, V}; _ -> absent end end,
    BareL = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case BareF(I rem 1000) of nothing -> Acc; V -> Acc + V end) end,
    TagL  = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case TagF(I rem 1000) of absent -> Acc; {ok, V} -> Acc + V end) end,
    io:format("~nloop N=~w, 1000-key map, 50% hit; 7 runs each (us), spread min/median/max, minor GCs, words allocated (heap_size delta not meaningful)~n", [N]),
    [report(Name, L) || {Name, L} <- [{"bare value", BareL}, {"tagged {ok,V}", TagL}]],
    %% the same with a 'big' value (heap-allocated list of 3 each) to see tagging on top of allocation
    BigM = maps:from_list([{I, [I,I,I]} || I <- lists:seq(1, 1000, 2)]),
    BareB = fun(K) -> case BigM of #{K := V} -> V; _ -> nothing end end,
    TagB  = fun(K) -> case BigM of #{K := V} -> {ok, V}; _ -> absent end end,
    BareBL = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case BareB(I rem 1000) of nothing -> Acc; [V|_] -> Acc + V end) end,
    TagBL  = fun L(I, Acc) when I > N -> Acc; L(I, Acc) -> L(I+1, case TagB(I rem 1000) of absent -> Acc; {ok, [V|_]} -> Acc + V end) end,
    io:format("~nsame, stored value is an existing 3-element list (no new alloc for bare)~n", []),
    [report(Name, L) || {Name, L} <- [{"bare list value", BareBL}, {"tagged {ok,list}", TagBL}]].

report(Name, L) ->
    Runs = [begin
                erlang:garbage_collect(),
                {G0,_,_} = erlang:statistics(garbage_collection),
                {T, R} = timer:tc(fun() -> L(1, 0) end),
                {G1,_,_} = erlang:statistics(garbage_collection),
                {T, G1-G0, R}
            end || _ <- lists:seq(1,7)],
    Ts = lists:sort([T || {T,_,_} <- Runs]),
    [{_,Gc,R}|_] = Runs,
    io:format("  ~-18s min ~7w  med ~7w  max ~7w us   minorGC/run ~w   result ~w~n", [Name, hd(Ts), lists:nth(4,Ts), lists:last(Ts), Gc, R]).
