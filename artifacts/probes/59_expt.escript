#!/usr/bin/env escript
%% 59_expt.escript BEAM -- print the export table as stored in the file: function/arity -> entry label
%% (beam_disasm reads the ExpT chunk).
main([Beam]) ->
    {beam_file, _, Exports, _, _, _} = beam_disasm:file(Beam),
    [io:format("    ~p/~p -> label ~p~n", [F, A, L]) || {F, A, L} <- Exports, F =/= module_info].
