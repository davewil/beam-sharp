#!/usr/bin/env escript
%% Print the instructions of one function from a .beam, to see whether the
%% boundary guard (F24) is emitted at an exported function and not at a local one.
main([File, Fun]) ->
    {beam_file, _M, Exports, _Attrs, _CI, Code} = beam_disasm:file(File),
    io:format("exports: ~p~n", [[{N, A} || {N, A, _} <- Exports]]),
    [begin io:format("~p/~p:~n", [N, A]), [io:format("    ~p~n", [I]) || I <- Is] end
     || {function, N, A, _, Is} <- Code, atom_to_list(N) =:= Fun].
