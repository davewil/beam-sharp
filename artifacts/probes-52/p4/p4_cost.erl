%% p4: microsecond cost of candidate compile-time checks. Each is run N times, 7 repeats; min and median reported.
-module(p4_cost).
-export([main/0]).
-define(N, 200).
main() ->
  [code:add_pathz(D) || D <- filelib:wildcard("/usr/lib/elixir/lib/*/ebin")],
  io:format("code path entries: ~p~n", [length(code:get_path())]),
  io:format("erlang ~s, schedulers online ~p~n", [erlang:system_info(otp_release), erlang:system_info(schedulers_online)]),
  bench("code:which(existing mod, hot)",              fun() -> code:which(lists) end),
  bench("code:which(existing Elixir mod)",            fun() -> code:which('Elixir.Mix.Task') end),
  bench("code:which(MISSING mod: scans whole path)",  fun() -> code:which('Elixir.Req') end),
  bench("code:lib_dir(ssl) (app-name check, present)",fun() -> code:lib_dir(ssl) end),
  bench("code:lib_dir(req) (app-name check, missing)",fun() -> code:lib_dir(req) end),
  bench("lib_dir + filelib:is_file(<app>.app) present",fun() -> L = code:lib_dir(ssl), filelib:is_file(filename:join([L,"ebin","ssl.app"])) end),
  bench("code:where_is_file(\"ssl.app\") present",      fun() -> code:where_is_file("ssl.app") end),
  bench("code:where_is_file(\"req.app\") missing",      fun() -> code:where_is_file("req.app") end),
  bench("path-parse module->app (which + split)",     fun() -> case code:which('Elixir.Mix.Task') of P -> lists:nth(3,lists:reverse(filename:split(P))) end end),
  bench("algo B: read every .app on path (consult)",  fun() -> scan() end, 5),
  bench("algo B2: read ONE .app (consult ssl.app)",   fun() -> file:consult(filename:join(code:lib_dir(ssl),"ebin/ssl.app")) end),
  ok.
bench(L, F) -> bench(L, F, ?N).
bench(L, F, N) ->
  Ts = [begin {T,_} = timer:tc(fun() -> [F() || _ <- lists:seq(1,N)] end), T/N end || _ <- lists:seq(1,7)],
  S = lists:sort(Ts),
  io:format("~-52s min ~9.2f us   median ~9.2f us~n", [L, hd(S), lists:nth(4,S)]).
scan() ->
  [file:consult(AppF) || D <- code:get_path(), AppF <- filelib:wildcard(filename:join(D,"*.app"))].
