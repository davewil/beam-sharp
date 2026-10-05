#!/usr/bin/env escript
%% usage: bench_load.escript BEAMFILE REPS
%% Times, in microseconds, (a) erlang:prepare_loading/2 (parse + validate + allocate; scales with module size)
%% and (b) erlang:finish_loading/1 (install: export table etc.). code:delete + code:purge run OUTSIDE the timed region.
%% Prints median / min / p90 of each.
main([F, RS]) ->
    {ok, Bin} = file:read_file(F),
    R = list_to_integer(RS),
    M = list_to_atom(filename:basename(F, ".beam")),
    One = fun() ->
        code:delete(M),
        code:purge(M),
        {U1, P} = timer:tc(erlang, prepare_loading, [M, Bin]),
        {U2, ok} = timer:tc(erlang, finish_loading, [[P]]),
        {U1, U2}
    end,
    _ = [One() || _ <- lists:seq(1, 30)],
    Rs = [One() || _ <- lists:seq(1, R)],
    St = fun(L) -> S = lists:sort(L), {lists:nth((R + 1) div 2, S), hd(S), lists:nth(R * 9 div 10, S)} end,
    {Pm, Pn, P9} = St([A || {A, _} <- Rs]),
    {Fm, Fn, F9} = St([B || {_, B} <- Rs]),
    io:format("prep_median=~p prep_min=~p prep_p90=~p fin_median=~p fin_min=~p fin_p90=~p~n",
              [Pm, Pn, P9, Fm, Fn, F9]).
