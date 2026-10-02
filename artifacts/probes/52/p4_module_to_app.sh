#!/usr/bin/env bash
# P4: can a stranger (or a compiler with no dependency on disk) recover the
# APPLICATION from a MODULE name? Measured over every app installed here
# (OTP 25 + Elixir 1.14 stdlib apps). The .app `modules` list is ground truth.
set -u
ERL_LIBS=/usr/lib/elixir/lib erl -noshell -eval '
Apps = [begin {ok,[{application,A,Ps}]}=file:consult(F), {A,proplists:get_value(modules,Ps,[]),proplists:get_value(applications,Ps,[])}
        end || D <- filelib:wildcard("/usr/lib/erlang/lib/*") ++ filelib:wildcard("/usr/lib/elixir/lib/*"),
               F <- filelib:wildcard(filename:join([D,"ebin","*.app"]))],
Pairs = [{M,A} || {A,Ms,_} <- Apps, M <- Ms],
Total = length(Pairs),
Same = length([x || {M,A} <- Pairs, M =:= A]),
Lower = fun(M) -> S = atom_to_list(M),
   case lists:prefix("Elixir.", S) of
     true -> [H|_] = string:split(lists:nthtail(7,S),".",all), string:lowercase(H);
     false -> S end end,
Guess = length([x || {M,A} <- Pairs, list_to_atom(Lower(M)) =:= A]),
io:format("apps=~p modules=~p~n",[length(Apps),Total]),
io:format("module name == app name:                    ~p of ~p (~.1f%)~n",[Same,Total,100*Same/Total]),
io:format("rule: lowercase(first Elixir segment)==app: ~p of ~p (~.1f%)~n",[Guess,Total,100*Guess/Total]),
ElxPairs = [{M,A} || {M,A} <- Pairs, lists:prefix("Elixir.",atom_to_list(M))],
ElxOk = length([x || {M,A} <- ElxPairs, list_to_atom(Lower(M)) =:= A]),
io:format("  restricted to Elixir.* modules:           ~p of ~p~n",[ElxOk,length(ElxPairs)]),
Bad = [{M,A} || {M,A} <- ElxPairs, list_to_atom(Lower(M)) =/= A],
io:format("  Elixir.* modules the rule gets WRONG, first 8: ~p~n",[lists:sublist(Bad,8)]),
io:format("  apps owning Elixir.* modules whose name matches no module segment: ~p~n",
   [lists:usort([A || {M,A} <- Bad])]),
%% erlang-side: common modules and the app that really owns them
io:format("owner(gen_server)=~p owner(ets)=~p owner(file)=~p owner(json)=~p owner(Elixir.Logger)=~p owner(Elixir.String)=~p~n",
  [[A||{M,A}<-Pairs,M=:=gen_server],[A||{M,A}<-Pairs,M=:=ets],[A||{M,A}<-Pairs,M=:=file],[A||{M,A}<-Pairs,M=:=json],
   [A||{M,A}<-Pairs,M=:=list_to_atom("Elixir.Logger")],[A||{M,A}<-Pairs,M=:=list_to_atom("Elixir.String")]]),
halt(case 10*Same < Total of true -> 0; false -> 1 end).'  # FALSIFIED if >=10% of module names equal their app name
