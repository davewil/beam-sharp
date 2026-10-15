#!/usr/bin/env escript
%% 59_size.escript BEAM... -- per beam: file bytes, Code-chunk bytes, instruction count.
main(Beams) ->
    [begin
         {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(B, ["Code"]),
         {beam_file, _, _, _, _, Fs} = beam_disasm:file(B),
         N = lists:sum([length(Is) || {function, _, _, _, Is} <- Fs]),
         io:format("~s file=~p code=~p instrs=~p~n", [filename:basename(filename:dirname(B)), filelib:file_size(B), byte_size(Code), N])
     end || B <- Beams].
