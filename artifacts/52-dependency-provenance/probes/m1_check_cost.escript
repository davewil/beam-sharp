#!/usr/bin/env escript
%% (d) cost of the presence check. Prints one line of key=value per call: ns for the FIRST call (cold) in this VM.
%% usage: m1_check_cost.escript cold | warm
main(["cold"]) ->
  T = fun(F) -> S = erlang:monotonic_time(nanosecond), F(), erlang:monotonic_time(nanosecond) - S end,
  %% first call in a fresh VM, each mechanism in its own VM is arranged by the driver (arg 2); here: all four in a fixed order
  L = T(fun() -> code:lib_dir(exdep) end),
  W = T(fun() -> code:which('Elixir.ExDep') end),
  A = T(fun() -> code:where_is_file("exdep.app") end),
  P = T(fun() -> application:load(exdep) end),
  io:format("lib_dir=~w which=~w where_is_app=~w app_load=~w~n", [L, W, A, P]);
main(["warm"]) ->
  N = 200000,
  Bench = fun(Name, F) ->
      {US, _} = timer:tc(fun() -> loop(N, F) end),
      io:format("~-34s ~8.1f ns/call  (~w calls, ~w us total)~n", [Name, US*1000/N, N, US])
  end,
  Bench("lib_dir(present app)",        fun() -> code:lib_dir(exdep) end),
  Bench("lib_dir(absent app)",         fun() -> code:lib_dir(nosuchapp) end),
  Bench("which(present, unloaded mod)",fun() -> code:which('Elixir.ExDep') end),
  Bench("which(absent mod)",           fun() -> code:which(nosuchmod) end),
  Bench("where_is_file(\"exdep.app\")",fun() -> code:where_is_file("exdep.app") end),
  Bench("where_is_file(absent .app)",  fun() -> code:where_is_file("nosuch.app") end),
  Bench("application:load (already)",  fun() -> application:load(exdep) end),
  Bench("code:is_loaded(loaded mod)",  fun() -> code:is_loaded(lists) end),
  Bench("(baseline) erlang:now-ish: erlang:monotonic_time()", fun() -> erlang:monotonic_time() end),
  ok.
loop(0, _) -> ok;
loop(N, F) -> F(), loop(N-1, F).
