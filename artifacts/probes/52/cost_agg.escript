#!/usr/bin/env escript
%% stdin: concatenated outputs of cost_one; print median/min/max of cold and warm per check.
main(_) ->
    L = read([]),
    Names = lists:usort([N || {N, _, _} <- L]),
    io:format("~-18s ~8s ~8s ~8s ~10s  (microseconds; n=~p fresh VMs)~n", [check, cold_med, cold_min, cold_max, warm_med, length(L) div 8]),
    [begin
         Cs = lists:sort([C || {N2, C, _} <- L, N2 =:= N]), Ws = lists:sort([W || {N2, _, W} <- L, N2 =:= N]),
         io:format("~-18s ~8w ~8w ~8w ~10w~n", [N, med(Cs), hd(Cs), lists:last(Cs), med(Ws)])
     end || N <- Names].
med(L) -> lists:nth((length(L) + 1) div 2, L).
read(Acc) ->
    case io:get_line("") of
        eof -> Acc;
        Line -> case string:tokens(string:trim(Line), " ") of
                    [N, C, W] when N =/= "pathlen" -> read([{list_to_atom(N), list_to_integer(C), list_to_integer(W)} | Acc]);
                    _ -> read(Acc) end
    end.
