#!/usr/bin/env escript
main(_) ->
    {ok,T,_}=erl_scan:string("N >= -5."), {ok,[E]}=erl_parse:parse_exprs(T), io:format("guard   ~p~n",[E]),
    {ok,T2,_}=erl_scan:string("f(-5) -> a."), {ok,{function,_,_,_,[{clause,_,P,_,_}]}}=erl_parse:parse_form(T2), io:format("pattern ~p~n",[P]),
    {ok,T3,_}=erl_scan:string("-type t() :: -5..5."), {ok,{attribute,_,type,{t,R,_}}}=erl_parse:parse_form(T3), io:format("range   ~p~n",[R]),
    {op,_,'-',{integer,_,5}} = hd(P),                      %% falsifier: a folded {integer,_,-5}
    io:format("flat_size words: {op,1,'-',{integer,1,5}} ~p   {integer,1,-5} ~p~n",
              [erts_debug:flat_size({op,1,'-',{integer,1,5}}), erts_debug:flat_size({integer,1,-5})]).
