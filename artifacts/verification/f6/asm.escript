#!/usr/bin/env escript
main(_) ->
  Mk = fun(G) -> Gd = case G of true -> " when is_integer(O) andalso O >= 0 andalso O =< 255"; false -> "" end,
     "-module(m).\n-export([loop/3]).\nf1(O)"++Gd++" -> O.\nloop(0,_,Acc)->Acc;\nloop(N,O,Acc)->loop(N-1,O,Acc + f1(O)).\n" end,
  [begin {ok,T,_}=erl_scan:string(Mk(G)), Fs=parse(T,[]), {ok,_,Asm}=compile:forms(Fs,['S',binary]), io:format("=== guarded=~p~n",[G]),
         {_,_,_,Funs,_}=Asm, [io:format("~p~n",[F]) || F<-Funs, element(2,F)=/=module_info] end || G<-[false,true]].
parse([],A)->lists:reverse(A);
parse(T,A)->{F,R}=lists:splitwith(fun(X)->element(1,X)=/=dot end,T),{ok,Fm}=erl_parse:parse_form(F++[hd(R)]),parse(tl(R),[Fm|A]).
