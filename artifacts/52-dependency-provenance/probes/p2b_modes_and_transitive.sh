#!/usr/bin/env bash
# Run: ./p2b_modes_and_transitive.sh
H="$(cd "$(dirname "$0")" && pwd)"; FX="$H/fixtures/_fx"
[ -d "$FX/libA" ] || "$H/fixtures/build-fixtures.sh" >/dev/null
source /tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/env.sh
ELIXLIB=/tmp/claude-0/-home-user-beam-sharp/6af6839d-c1ca-5cc4-85ca-6a6c1f350905/scratchpad/mm/root/envs/tc/lib/elixir/lib
echo "### interactive VM (what bsc is): "
ERL_LIBS="$FX/libA:$ELIXLIB" escript "$H/p2b_modes_and_transitive.escript"
echo; echo "### embedded-mode VM (what a release is), same ERL_LIBS, plain erl -eval (the escript runs in interactive mode, so use erl directly)"
ERL_LIBS="$FX/libA:$ELIXLIB" erl -noshell -mode embedded -eval '
  io:format("mode=~p~n",[init:get_argument(mode)]),
  io:format("lib_dir(exdep)=~p~n",[code:lib_dir(exdep)]),
  io:format("which=~p~n",[code:which(list_to_atom("Elixir.ExDep"))]),
  io:format("ensure_loaded=~p~n",[code:ensure_loaded(list_to_atom("Elixir.ExDep"))]),
  halt().' 2>&1 | sed 's#'"$FX"'#FX#g'
echo; echo "### embedded-mode VM, NEGATIVE CONTROL: -pa the ebin explicitly (embedded mode honours -pa? it should then find it)"
ERL_LIBS="$FX/libB" erl -noshell -mode embedded -pa "$FX/libA/exdep/ebin" -eval '
  io:format("which=~p~n",[code:which(list_to_atom("Elixir.ExDep"))]),
  io:format("ensure_loaded=~p~n",[code:ensure_loaded(list_to_atom("Elixir.ExDep"))]),
  halt().' 2>&1 | sed 's#'"$FX"'#FX#g'
echo; echo "### transitive: exdep.app declares applications; are they present on machine 3 (no Elixir)?"
ERL_LIBS="$FX/libA" erl -noshell -eval '
  application:load(exdep),
  {ok, Deps} = application:get_key(exdep, applications),
  [io:format("  ~w -> lib_dir ~p~n",[D, case code:lib_dir(D) of {error,E}->E; P->filename:basename(P) end]) || D <- Deps],
  halt().' 2>&1
echo; echo "### version: is it READABLE at compile time without fetching anything? (the ticket calls any version constraint 'resolution')"
ERL_LIBS="$FX/libA:$ELIXLIB" erl -noshell -eval '
  Vsn = fun(App) ->
     case code:where_is_file(atom_to_list(App) ++ ".app") of
        non_existing -> absent;
        F -> {ok,[{application,App,Props}]} = file:consult(F), proplists:get_value(vsn, Props)
     end end,
  [io:format("  ~w -> ~p~n",[A, Vsn(A)]) || A <- [exdep, erldep, elixir, stdlib, nosuchapp]],
  {T, _} = timer:tc(fun() -> [Vsn(exdep) || _ <- lists:seq(1,1000)] end),
  io:format("  cost: ~.1f us per vsn read (file:consult of the .app, 1000 calls)~n",[T/1000]),
  io:format("  dir names carry the version? lib_dir(exdep)=~s  lib_dir(stdlib)=~s~n",[filename:basename(code:lib_dir(exdep)), filename:basename(code:lib_dir(stdlib))]),
  halt().' 2>&1 | sed "s#$FX#FX#g"
