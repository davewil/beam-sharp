#!/usr/bin/env escript
%% usage: size.escript File.beam -- prints: file bytes, stripped file bytes, Code-chunk bytes
main([F]) ->
    {ok, Bin} = file:read_file(F),
    {ok, {_, Stripped}} = beam_lib:strip(Bin),
    {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(Bin, ["Code"]),
    io:format("~p ~p ~p~n", [byte_size(Bin), byte_size(Stripped), byte_size(Code)]).
