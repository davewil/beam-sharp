#!/usr/bin/env escript
%% usage: guards.escript File.beam  -- prints one line per function: vis name/arity tags ints
main([F]) ->
    {ok,{_,[{abstract_code,{_,Forms}}]}} = beam_lib:chunks(F,[abstract_code]),
    Exp = lists:append([E || {attribute,_,export,E} <- Forms]),
    lists:foreach(fun({function,_,N,A,Cs}) ->
        Txt = lists:flatten([erl_pp:guard(G) || {clause,_,_,G,_} <- Cs, G =/= []]),   %% guards only
        Tag = count(Txt,"map_get('Kind'"),
        Int = count(Txt,"is_integer"),
        Flt = count(Txt,"is_float"),
        io:format("~-8s ~s/~p  tag_tests=~p is_integer=~p is_float=~p~n",
          [case lists:member({N,A},Exp) of true->"exported"; false->"private" end,N,A,Tag,Int,Flt]);
      (_) -> ok end, Forms).
count(S,P) -> length(string:split(S,P,all)) - 1.
