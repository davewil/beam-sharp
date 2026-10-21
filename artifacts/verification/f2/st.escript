#!/usr/bin/env escript
main([Dir]) ->
  code:add_patha(Dir),
  WK = #{'Kind'=>'Other.Order','Id'=>1,'Total'=>999},
  T = fun(Name, Args) -> R = (catch apply('Nested', Name, Args)),
     case R of {'EXIT',{Why,[{M,F,A,_}|_]=St}} -> io:format("~s: ~p in ~p:~p/~p~n", [Name,Why,M,F,case is_list(A) of true->length(A);false->A end]), [io:format("     ~p~n",[X]) || X<-lists:sublist(St,3)];
       V -> io:format("~s: returned ~p~n",[Name,V]) end end,
  T('Direct',[WK]), T('ViaTuple',[{WK,1}]), T('ViaList',[[WK]]), T('Inline',[{WK,1}]),
  T('OctetDirect',[100.5]), T('OctetViaTuple',[{100.5,1}]), T('OctetDirect',[300]), T('OctetViaTuple',[{300,1}]),
  T('Direct',[#{'Kind'=>'Nested.Order','Id'=>1}]), T('ViaTuple',[{#{'Kind'=>'Nested.Order','Id'=>1},1}]), T('Inline',[{#{'Kind'=>'Nested.Order','Id'=>1},1}]).
