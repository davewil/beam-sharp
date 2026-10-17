%% Interleaved timing of module variants on one workload.
%% usage: erl -noshell -pa DIRS -run time main M1 M2 ... (each exports part_two/1,
%% or 'PartTwo'/1 for the beam-sharp variants named bs*).
%% 673k-click workload: 4732 pseudo-random rotations (fixed seed), the same
%% order of magnitude as the AoC input the ticket used (the real input is
%% not in the repo). Runs are INTERLEAVED round-robin so drift hits every
%% variant equally; reports min and median of RUNS rounds. A variant listed
%% twice under different names (e0 and e0b) is the noise floor.
-module(time).
-export([main/1]).
-define(RUNS, 41).

main(Args) ->
    Mods = [list_to_atom(A) || A <- Args],
    Ds = deltas(),
    Clicks = lists:sum([abs(D) || D <- Ds]),
    io:format("OTP ~s, ~p rotations, ~p clicks~n", [erlang:system_info(otp_release), length(Ds), Clicks]),
    Fs = [{M, fun_of(M)} || M <- Mods],
    Answers = [{M, F(Ds)} || {M, F} <- Fs],
    io:format("answers: ~p~n", [Answers]),
    1 = length(lists:usort([A || {_, A} <- Answers])),
    erlang:garbage_collect(),
    Times = lists:foldl(fun(_, Acc) ->
        lists:foldl(fun({M, F}, A2) ->
            erlang:garbage_collect(),
            {T, _} = timer:tc(F, [Ds]),
            maps:update_with(M, fun(L) -> [T | L] end, [T], A2)
        end, Acc, Fs)
    end, #{}, lists:seq(1, ?RUNS)),
    Base = lists:min([lists:min(L) || L <- maps:values(Times)]),
    [begin
         S = lists:sort(maps:get(M, Times)),
         io:format("~-6s min ~7.3f ms  med ~7.3f ms  rel(min) ~.3f~n",
                   [M, hd(S) / 1000, lists:nth(?RUNS div 2 + 1, S) / 1000, hd(S) / Base])
     end || M <- Mods],
    halt().

fun_of(M) ->
    {module, M} = code:ensure_loaded(M),
    case erlang:function_exported(M, part_two, 1) of
        true -> fun M:part_two/1;
        false -> fun M:'PartTwo'/1
    end.

deltas() ->
    _ = rand:seed(exsss, {39, 39, 39}),
    [begin R = rand:uniform(283) - 1, case rand:uniform(2) of 1 -> R; 2 -> -R end end
     || _ <- lists:seq(1, 4732)].
