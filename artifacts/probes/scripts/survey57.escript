#!/usr/bin/env escript
%% survey57: how Erlang's own front end represents a negative literal in a guard, and whether the compiler folds it
main(_) ->
  {ok,T,_}=erl_scan:string("f(N) when N >= -5 -> ok.  g(N) when N >= 2+3 -> ok."),
  [F1,F2]=split(T),
  {ok,A1}=erl_parse:parse_form(F1), {ok,A2}=erl_parse:parse_form(F2),
  io:format("erl_parse  -5   : ~p~n",[guard(A1)]),
  io:format("erl_parse  2+3  : ~p~n",[guard(A2)]),
  Src="-module(m57). -export([f/1,g/1]). f(N) when N >= -5 -> ok; f(_) -> no. g(N) when N >= 2+3 -> ok; g(_) -> no.",
  {ok,m57,Core}=compile:forms(forms(Src),[binary,to_core]),
  Txt=lists:flatten(core_pp:format(Core)),
  Lines=[L||L<-string:split(Txt,"\n",all), (string:find(L,"-5")=/=nomatch) orelse (string:find(L,", 5)")=/=nomatch)],
  io:format("core guards after sys_core_fold:~n~s~n",[string:join(Lines,"\n")]).
split(T) -> split(T,[],[]).
split([],[],Acc)->lists:reverse(Acc);
split([{dot,_}=D|R],Cur,Acc)-> split(R,[],[lists:reverse([D|Cur])|Acc]);
split([X|R],Cur,Acc)-> split(R,[X|Cur],Acc).
guard({function,_,_,_,[{clause,_,_,[[G]],_}]}) -> G.
forms(Src)->{ok,T,_}=erl_scan:string(Src), [begin {ok,F}=erl_parse:parse_form(X), F end||X<-split(T)].
