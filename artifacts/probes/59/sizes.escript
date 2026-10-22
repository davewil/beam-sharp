#!/usr/bin/env escript
%% Usage: sizes.escript T.beam  — file bytes, Code-chunk bytes, and the instructions of Inner/Bump from the disassembly.
main([F]) ->
    {ok, Bin} = file:read_file(F),
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    Code = proplists:get_value("Code", Chunks),
    io:format("beam file bytes: ~p   Code chunk bytes: ~p~n", [byte_size(Bin), byte_size(Code)]),
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(F),
    [begin
         Ops = [element(1, I) || I <- Is, is_tuple(I)] ,
         io:format("~-10s instrs=~p  guard/type ops: ~p~n", [atom_to_list(N), length(Is),
              [element(1,I) || I <- Is, is_tuple(I), lists:member(element(1,I),
                   [test, select_val, get_map_element, is_integer, is_float, is_map, is_tuple_of_arity, is_ge, is_lt, is_eq_exact])]]),
         _ = Ops
     end || {function, N, _, _, Is} <- Fs, lists:member(N, ['Inner', 'Bump', 'Outer', 'OuterI', 'Score'])].
