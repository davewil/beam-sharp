#!/usr/bin/env escript
main(Files) ->
    [begin
        {ok,_,Chunks} = beam_lib:all_chunks(F),
        io:format("~-40s file=~p Code=~p~n", [F, filelib:file_size(F), byte_size(proplists:get_value("Code", Chunks))])
     end || F <- Files].
