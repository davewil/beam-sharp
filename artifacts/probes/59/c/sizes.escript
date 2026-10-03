#!/usr/bin/env escript
%% usage: sizes.escript FILE.beam  -> prints: file_bytes stripped_bytes code_chunk_bytes
main([F]) ->
    {ok, Bin} = file:read_file(F),
    {ok, {_, Stripped}} = beam_lib:strip(Bin),
    {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(Bin, ["Code"]),
    io:format("~w ~w ~w~n", [byte_size(Bin), byte_size(Stripped), byte_size(Code)]).
