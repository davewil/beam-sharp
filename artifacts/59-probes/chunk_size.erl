-module(chunk_size).
-export([main/1]).

main([Beam]) ->
    {ok, _, Chunks} = beam_lib:all_chunks(Beam),
    lists:foreach(fun({Name, Data}) ->
        io:format("~-8s ~6B bytes~n", [Name, byte_size(Data)])
    end, Chunks),
    Total = filelib:file_size(Beam),
    io:format("TOTAL FILE ~6B bytes~n", [Total]).
