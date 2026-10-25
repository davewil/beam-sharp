#!/usr/bin/env escript
%% usage: time_one.escript BEAMDIR MODULE FUNCTION INPUT  — one VM, one variant: answer, min and median of 25 runs (ms).
main([Dir, Mod, Fun, Input]) ->
    true = code:add_patha(Dir),
    {ok, Bin} = file:read_file(Input),
    Ds = [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    M = list_to_atom(Mod), F = list_to_atom(Fun),
    Ans = M:F(Ds),
    Ts = lists:sort([begin {T, _} = timer:tc(M, F, [Ds]), T end || _ <- lists:seq(1, 25)]),
    io:format("~p ~.3f ~.3f~n", [Ans, hd(Ts)/1000, lists:nth(13, Ts)/1000]).
parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
