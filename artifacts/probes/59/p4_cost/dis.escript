#!/usr/bin/env escript
main([F|Names]) ->
    {beam_file,_,_,_,_,Fs} = beam_disasm:file(F),
    [io:format("~p~n",[X]) || {function,N,_,_,_}=X <- Fs, lists:member(atom_to_list(N), Names)].
