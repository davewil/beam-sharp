#!/usr/bin/env escript
main([F|Names]) ->
    {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(F,[abstract_code]),
    [io:format("~s~n",[erl_pp:function(Fn)]) || {function,_,N,_,_}=Fn <- Forms, lists:member(atom_to_list(N),Names)].
