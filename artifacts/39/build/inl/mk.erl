-module(mk).
-export([main/1]).
main([In, Out, Dir]) ->
    {ok, [_Mod | Rest]} = file:consult(In),
    Fs = [{attribute,0,module,'Day01_attr'}, {attribute,0,compile,inline} | Rest],
    ok = file:write_file(Out, [io_lib:format("~p.~n", [X]) || X <- Fs]),
    io:format("compile: ~p~n", [compile:file(Out, [from_abstr, debug_info, {outdir, Dir}])]),
    {beam_file,_,_,_,_,Bf} = beam_disasm:file(filename:join(Dir, "Day01_attr.beam")),
    [{function,_,_,_,C}] = [F || {function,N,4,_,_} = F <- Bf, N =:= 'Spin'],
    io:format("Spin/4 after attribute-inline: ~p instrs, ~p local calls~n",
              [length(C), length([X || X <- C, is_tuple(X), lists:member(element(1,X), [call,call_last,call_only])])]),
    halt().
