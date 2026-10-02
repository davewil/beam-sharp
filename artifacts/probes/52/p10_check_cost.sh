#!/usr/bin/env bash
# P10: wall-clock cost of the two shapes of compile-time check, on this machine's
# real code path (OTP 25 + Elixir libs on ERL_LIBS; ~30 application dirs).
ERL_LIBS=/usr/lib/elixir/lib erl -noshell -eval '
io:format("code path entries: ~p~n",[length(code:get_path())]),
Scan=fun() -> [{A,proplists:get_value(modules,Ps,[])} || P <- code:get_path(), filename:basename(P)=:="ebin",
              F <- filelib:wildcard(filename:join(P,"*.app")), {ok,[{application,A,Ps}]} <- [file:consult(F)]] end,
{Us,Map}=timer:tc(Scan),
io:format("scan every .app on the path ONCE (module->app map, ~p apps): ~.1f ms~n",[length(Map),Us/1000]),
{Ws,_}=timer:tc(fun()->[code:which(list_to_atom("Elixir.Nope"++integer_to_list(I)))||I<-lists:seq(1,100)] end),
io:format("code:which(absent module), per call: ~p us (100 calls)~n",[round(Ws/100)]),
{Ls,_}=timer:tc(fun()->[code:lib_dir(nope)||_<-lists:seq(1,100)] end),
io:format("code:lib_dir(absent app), per call: ~p us~n",[round(Ls/100)]),
halt().'
