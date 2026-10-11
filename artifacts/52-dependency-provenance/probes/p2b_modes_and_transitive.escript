#!/usr/bin/env escript
%% Probe (b) continued: (1) does the answer depend on interactive vs embedded code loading?
%% (2) does a name-only check see a dependency's own dependencies? (3) does the presence test LOAD code?
main([]) ->
  io:format("mode=~p~n", [init:get_argument(mode)]),
  io:format("lib_dir(exdep)=~p~n", [short(code:lib_dir(exdep))]),
  io:format("code:which('Elixir.ExDep')=~p~n", [short(code:which('Elixir.ExDep'))]),
  io:format("is_loaded before ensure_loaded=~p~n", [code:is_loaded('Elixir.ExDep')]),
  R = code:ensure_loaded('Elixir.ExDep'),
  io:format("ensure_loaded=~p  is_loaded after=~p~n", [R, element(1, code:is_loaded('Elixir.ExDep'))]),
  ok.
short(P) when is_list(P) -> filename:basename(P);
short(X) -> X.
