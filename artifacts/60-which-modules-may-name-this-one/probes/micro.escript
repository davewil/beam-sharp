#!/usr/bin/env escript
%% P10b: the cost of the rule itself, per `using` edge, replicating bs_check:namable/4 (World lookup + segment-aware prefix test).
main(_) ->
    World = maps:from_list([{list_to_atom("Gen.M" ++ integer_to_list(I)), #{within => ['Gen']}} || I <- lists:seq(0, 149)]),
    Self = 'Gen.M77', M = 'Gen.M12', N = 1164, Reps = 2000,
    F = fun() ->
        [begin
            W = maps:get(within, maps:get(M, World, #{}), []),
            S = atom_to_list(Self),
            W =:= [] orelse lists:any(fun(P) -> Q = atom_to_list(P), S =:= Q orelse lists:prefix(Q ++ ".", S) end, W)
         end || _ <- lists:seq(1, N)], ok end,
    [begin {T, _} = timer:tc(fun() -> [F() || _ <- lists:seq(1, Reps)] end),
           io:format("run ~p: ~.1f us for ~p edges (~p ns/edge)~n", [R, T / Reps, N, round(T * 1000 / Reps / N)]) end || R <- [1,2,3,4,5]].
