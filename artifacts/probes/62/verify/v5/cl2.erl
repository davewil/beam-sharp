-module(cl2).
-export([run/0]).
d(0,_) -> ok; d(N,X) -> 'N100':'GetItem5'(X), d(N-1,X).
a(0,_) -> ok; a(N,X) -> 'N100':get_item5(X), a(N-1,X).
e(0,_) -> ok; e(N,X) -> erlang:abs(X), e(N-1,X).
run() ->
  {ok,B}=file:read_file(os:getenv("ALIASBEAM")), {module,'N100'}=code:load_binary('N100',"x",B),
  N=10000000,
  R=[begin {Td,_}=timer:tc(fun() -> d(N,3) end), {Ta,_}=timer:tc(fun() -> a(N,3) end), {Te,_}=timer:tc(fun() -> e(N,3) end), {Td*1000/N,Ta*1000/N,Te*1000/N} end || _ <- lists:seq(1,8)],
  [io:format("direct ~.2f alias ~.2f empty ~.2f ns~n",[D,A,E]) || {D,A,E} <- tl(R)],
  Ds=lists:sort([D||{D,_,_}<-tl(R)]), As=lists:sort([A||{_,A,_}<-tl(R)]),
  io:format("median direct ~.2f alias ~.2f~n",[lists:nth(4,Ds), lists:nth(4,As)]).
