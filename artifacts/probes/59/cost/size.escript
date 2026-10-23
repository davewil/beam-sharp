#!/usr/bin/env escript
%% usage: size.escript FILE.beam  -> prints "code=<Code chunk bytes> file=<bytes> stripped=<bytes>"
main([F]) ->
    {ok, {_, [{"Code", C}]}} = beam_lib:chunks(F, ["Code"]),
    {ok, B} = file:read_file(F),
    {ok, {_, Stripped}} = beam_lib:strip(B),
    io:format("~p ~p ~p~n", [byte_size(C), byte_size(B), byte_size(Stripped)]).
