#!/usr/bin/env escript
%% usage: cmp_beams.escript DirA DirB
%% For every .beam in DirA: compare all chunks with DirB's except CInf
%% (compile_info carries the wall-clock compile time and out dir, so it differs
%% between two runs of the SAME compiler). Prints counts, exits 0 iff all equal.
main([A, B]) ->
    Fs = filelib:wildcard("*.beam", A),
    Bad = [F || F <- Fs, not same(filename:join(A, F), filename:join(B, F))],
    Extra = length(filelib:wildcard("*.beam", B)) - length(Fs),
    io:format("files=~p differing_excluding_CInf=~p extra_in_B=~p~n", [length(Fs), length(Bad), Extra]),
    halt(case Bad =:= [] andalso Extra =:= 0 of true -> 0; false -> 1 end).
same(X, Y) ->
    {ok, _, CX} = beam_lib:all_chunks(X), {ok, _, CY} = beam_lib:all_chunks(Y),
    strip(CX) =:= strip(CY).
strip(Cs) -> [C || {N, _} = C <- Cs, N =/= "CInf"].
