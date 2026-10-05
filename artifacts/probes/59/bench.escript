#!/usr/bin/env escript
%% bench.escript BEAMROOT Reps Calls Len Pair1 Pair2 ... 
%%   Each Pair is  Label=ModuleName ; modules are the SAME B# source compiled by different bsc variants
%%   (module name differs only so they can be loaded together). Interleaved reps; first rep dropped.
%%   Prints per variant: min / median ns per ELEMENT visited, for SumTotals and SumWeights.
main([Root, RepsS, CallsS, LenS | Pairs]) ->
    Reps = list_to_integer(RepsS), Calls = list_to_integer(CallsS), Len = list_to_integer(LenS),
    Vs = [begin [L, M] = string:split(P, "="), {L, list_to_atom(M)} end || P <- Pairs],
    [begin
         true = code:add_patha(filename:join(Root, M)),
         {module, _} = code:load_file(Mod)
     end || {M, Mod} <- [{atom_to_list(Mod), Mod} || {_, Mod} <- Vs]],
    Orders = fun(Mod) ->
                     Tag = list_to_atom(atom_to_list(Mod) ++ ".Order"),
                     [#{'Kind' => Tag, 'Id' => I, 'Total' => I rem 7} || I <- lists:seq(1, Len)] end,
    Octs = [I rem 256 || I <- lists:seq(1, Len)],
    Bench = fun(Fun, Mod, Arg) ->
                    T0 = erlang:monotonic_time(nanosecond),
                    loop(Calls, Mod, Fun, Arg),
                    (erlang:monotonic_time(nanosecond) - T0) / (Calls * Len)
            end,
    lists:foreach(
      fun(Fun) ->
          Res = lists:foldl(
                  fun(_Rep, Acc) ->
                          lists:foldl(fun({L, Mod}, A) ->
                                              Arg = case Fun of 'SumTotals' -> Orders(Mod); _ -> Octs end,
                                              A#{L := [Bench(Fun, Mod, Arg) | maps:get(L, A)]}
                                      end, Acc, Vs)
                  end, maps:from_list([{L, []} || {L, _} <- Vs]), lists:seq(0, Reps)),
          io:format("~n~p  (ns per element, ~p reps after 1 warm-up, ~p calls x ~p elements)~n", [Fun, Reps, Calls, Len]),
          [begin
               Xs = lists:reverse(maps:get(L, Res)), Rs = tl(Xs), S = lists:sort(Rs),
               io:format("  ~-8s min=~.4f  median=~.4f  max=~.4f   raw=~s~n",
                         [L, hd(S), lists:nth((length(S) + 1) div 2, S), lists:last(S),
                          string:join([io_lib:format("~.3f", [X]) || X <- Rs], " ")])
           end || {L, _} <- Vs]
      end, ['SumTotals', 'SumWeights']).
loop(0, _, _, _) -> ok;
loop(N, Mod, Fun, Arg) -> _ = Mod:Fun(Arg), loop(N - 1, Mod, Fun, Arg).
