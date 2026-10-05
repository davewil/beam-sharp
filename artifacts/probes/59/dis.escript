#!/usr/bin/env escript
%% dis.escript FILE.beam [Name/Arity ...] : disassemble named functions (beam_disasm), plus Code-chunk byte size.
main([F | Fs]) ->
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    {_, Code} = lists:keyfind("Code", 1, Chunks),
    io:format("CODE_CHUNK_BYTES ~p~n", [byte_size(Code)]),
    {beam_file, _, _, _, _, Funs} = beam_disasm:file(F),
    [begin
         io:format("== ~p/~p~n", [N, A]),
         [io:format("   ~p~n", [I]) || I <- Is]
     end || {function, N, A, _, Is} <- Funs,
            Fs =:= [] orelse lists:member(atom_to_list(N) ++ "/" ++ integer_to_list(A), Fs)].
