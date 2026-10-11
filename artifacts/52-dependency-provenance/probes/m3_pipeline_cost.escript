#!/usr/bin/env escript
%% (d) cost of the check relative to a whole bsc compile, measured in one VM (prototype build on the path).
main([Ebin, Src, OutBase]) ->
  true = code:add_patha(Ebin),
  Reqs = [{requires, {4,1}, [{external,elixir},{app,exdep}], 'Elixir.ExDep'},
          {requires, {8,1}, [{external,erlang},{app,erldep}], erldep},
          {requires, {12,1}, [{external,elixir},{app,elixir}], 'Elixir.String'}],
  Foreign = [{{4,1},'Elixir.ExDep'}, {{8,1},erldep}, {{12,1},'Elixir.String'}],
  %% (1) the check alone: first call in this VM (cold), then 30 warm calls
  {Cold, R0} = timer:tc(fun() -> bs_deps_proto:check(Reqs, Foreign) end),
  io:format("check result (deps present): ~p~n", [R0]),
  Ws = lists:sort([element(1, timer:tc(fun() -> bs_deps_proto:check(Reqs, Foreign) end)) || _ <- lists:seq(1,2000)]),
  io:format("check, 3 declarations: first call ~w us (cold: includes first code:where_is_file/which); warm median ~w us, min ~w, p95 ~w (n=2000)~n",
            [Cold, lists:nth(1000, Ws), hd(Ws), lists:nth(1900, Ws)]),
  %% where does the time go? the three ingredients of the prototype's check, warm, 2000 calls each
  W = code:which('Elixir.ExDep'),
  T = fun(Name, F) ->
        L = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1,2000)]),
        io:format("  ~-60s median ~w us (min ~w)~n", [Name, lists:nth(1000,L), hd(L)]) end,
  io:format("components (warm):~n"),
  T("code:where_is_file(\"exdep.app\")  [is the app on the path]", fun() -> code:where_is_file("exdep.app") end),
  T("code:which(Mod)                     [is the module on the path]", fun() -> code:which('Elixir.ExDep') end),
  T("filelib:wildcard(dirname(Beam)/*.app) [who owns the module: lists a directory]", fun() -> filelib:wildcard(filename:join(filename:dirname(W), "*.app")) end),
  T("basename(dirname(dirname(Beam)))      [owner by DIRECTORY name; no listing]", fun() -> filename:basename(filename:dirname(filename:dirname(W))) end),
  %% negative control: the check must be able to FAIL and the harness see it
  {_, R1} = timer:tc(fun() -> bs_deps_proto:check([{requires,{1,1},[{app,nosuchapp}],erldep}], [{{1,1},erldep}]) end),
  io:format("negative control (absent app) -> ~p~n", [R1]),
  %% (2) a whole compile of the same module through the prototype, 20 runs; the .bs file declares the same 3 deps
  Run = fun(I) ->
      Dir = OutBase ++ integer_to_list(I),
      {US, _} = timer:tc(fun() -> catch bsc:file_to_dir(Src, Dir) end), US
  end,
  Ts = lists:sort([Run(I) || I <- lists:seq(1, 20)]),
  io:format("whole bsc:file_to_dir on DeclA (parse+check+emit+erlc, with the check inside), 20 runs: median ~w us, min ~w, max ~w~n",
            [lists:nth(10,Ts), hd(Ts), lists:last(Ts)]).
