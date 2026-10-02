#!/usr/bin/env bash
# P8: the BEAM's own dependency vocabulary. Across every installed .app (OTP 25 +
# Elixir 1.14) is `applications` ever anything but a list of bare names?
# FALSIFIED (exit 1) if any entry carries a version.
ERL_LIBS=/usr/lib/elixir/lib erl -noshell -eval '
Files = [F || D <- filelib:wildcard("/usr/lib/erlang/lib/*") ++ filelib:wildcard("/usr/lib/elixir/lib/*"),
              F <- filelib:wildcard(filename:join([D,"ebin","*.app"]))],
Es = [{A,K,E} || F <- Files, {ok,[{application,A,Ps}]} <- [file:consult(F)],
                 K <- [applications,included_applications,optional_applications],
                 E <- proplists:get_value(K,Ps,[])],
NonAtom = [X || {_,_,E}=X <- Es, not is_atom(E)],
Keys = lists:usort([K || F <- Files, {ok,[{application,_,Ps}]} <- [file:consult(F)], {K,_} <- Ps]),
io:format(".app files=~p dependency entries=~p non-atom entries=~p~n",[length(Files),length(Es),length(NonAtom)]),
io:format("keys used across all .app files: ~p~n",[Keys]),
{ok,[{application,_,Lp}]} = file:consult("/usr/lib/elixir/lib/logger/ebin/logger.app"),
io:format("logger.app applications=~p optional=~p~n",[proplists:get_value(applications,Lp),proplists:get_value(optional_applications,Lp,none)]),
{ok,[{application,_,Sp}]} = file:consult("/usr/lib/erlang/lib/ssl-10.9.1.3/ebin/ssl.app"),
io:format("ssl.app runtime_dependencies (OTP-only, version-carrying, advisory): ~p~n",[proplists:get_value(runtime_dependencies,Sp)]),
Rd = length([F || F <- Files, {ok,[{application,_,P}]} <- [file:consult(F)], proplists:is_defined(runtime_dependencies,P)]),
io:format(".app files carrying runtime_dependencies: ~p of ~p (Elixir apps: none)~n",[Rd,length(Files)]),
halt(case NonAtom of [] -> 0; _ -> 1 end).'
