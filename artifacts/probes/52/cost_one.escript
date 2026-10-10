#!/usr/bin/env escript
%% One fresh VM: time each check ONCE, cold, in microseconds; then 1000 warm calls each.
%% Output: one line  name cold_us warm_median_us
main(_) ->
    Checks = [{which_present,   fun() -> code:which('Elixir.Fakeel') end},
              {which_missing,   fun() -> code:which(no_such_mod) end},
              {lib_dir_present, fun() -> code:lib_dir(fakeel) end},
              {lib_dir_missing, fun() -> code:lib_dir(no_such_app) end},
              {app_load_present,fun() -> application:load(fakeel) end},
              {app_load_missing,fun() -> application:load(no_such_app) end},
              {ensure_present,  fun() -> code:ensure_loaded('Elixir.Fakeel') end},
              {ensure_missing,  fun() -> code:ensure_loaded(no_such_mod) end}],
    io:format("pathlen ~p~n", [length(code:get_path())]),
    [begin
         {Cold, _} = timer:tc(F),
         Ws = [element(1, timer:tc(F)) || _ <- lists:seq(1, 200)],
         io:format("~p ~p ~p~n", [N, Cold, lists:nth(100, lists:sort(Ws))])
     end || {N, F} <- Checks].
