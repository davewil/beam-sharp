#!/usr/bin/env escript
%% bytes_one.escript FILE.beam : prints "code=<bytes> file=<bytes> funs=<n>"
main([F]) ->
    {ok, _, Chunks} = beam_lib:all_chunks(F),
    {_, Code} = lists:keyfind("Code", 1, Chunks),
    {ok, Bin} = file:read_file(F),
    io:format("code=~p file=~p~n", [byte_size(Code), byte_size(Bin)]).
