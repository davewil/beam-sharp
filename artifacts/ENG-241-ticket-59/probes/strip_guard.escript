#!/usr/bin/env escript
%% usage: strip_guard.escript IN.abstr OUTDIR FunctionName
%% COUNTERFACTUAL: delete the guard of every clause of FunctionName in bsc's real output
%% and compile the rest unchanged, to see what the function does without that guard.
main([In, OutDir, Name]) ->
    {ok, Fs} = file:consult(In),
    N = list_to_atom(Name),
    Fs1 = [case F of
               {function, A, N, Ar, Cl} -> {function, A, N, Ar, [{clause, L, P, [], B} || {clause, L, P, _, B} <- Cl]};
               _ -> F
           end || F <- Fs],
    {ok, M, Bin} = compile:forms(Fs1, [from_abstr, return_errors, binary]),
    ok = file:write_file(filename:join(OutDir, atom_to_list(M) ++ ".beam"), Bin).
