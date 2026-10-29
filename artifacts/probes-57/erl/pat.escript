#!/usr/bin/env escript
%% does Erlang allow arithmetic in patterns? compile and show
main(_) ->
  Src = "-module(p). -export([f/1]). f(2-7) -> a; f(_) -> b.",
  {ok,T,_}=erl_scan:string(Src), 
  io:format("scanned ok~n"),
  file:write_file("p.erl", "-module(p).\n-export([f/1]).\nf(2-7) -> a;\nf(- -3) -> c;\nf(_) -> b.\n"),
  R = compile:file("p.erl",[binary,return,'S']),
  io:format("~p~n",[element(1,R)]),
  case R of {ok,_,Asm} -> [io:format("~p~n",[I]) || I <- element(5,hd(tl(element(5,Asm)))), element(1,I)==test orelse true] , ok; _ -> ok end.
