#!/usr/bin/env escript
%% disasm.escript File.beam Fun Arity  -> the optimised BEAM instructions of one function (beam_disasm)
main([F, Fn, A]) ->
    {beam_file, _, _, _, _, Fs} = beam_disasm:file(F),
    Name = list_to_atom(Fn), Ar = list_to_integer(A),
    [begin [io:format("  ~w~n", [I]) || I <- Is] end || {function, N, Arity, _, Is} <- Fs, N =:= Name, Arity =:= Ar].
