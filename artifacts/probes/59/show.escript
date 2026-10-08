#!/usr/bin/env escript
%% usage: show.escript File.beam  -> prints the abstract code of every function as Erlang source
main([F]) ->
    {ok,{_,[{abstract_code,{raw_abstract_v1,AC}}]}} = beam_lib:chunks(F,[abstract_code]),
    [io:format("~s~n",[erl_pp:form(Form)]) || Form <- AC, element(1,Form)=:=function orelse element(1,Form)=:=attribute].
