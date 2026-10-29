%% p3c: failure cases for module->app mapping, using fixtures from mkfix.sh
-module(p3c_fixtures).
-export([main/0, apps_declaring/1]).
main() ->
  io:format("ERL_LIBS=~p~n", [os:getenv("ERL_LIBS")]),
  [io:format("~-8w which=.../~s get_application=~w app_by_path_parse=~s~n",
             [M, string:join(lists:nthtail(length(filename:split(code:which(M)))-3, filename:split(code:which(M))),"/"), application:get_application(M), path_app(M)])
   || M <- [dup, orph, unlisted]],
  io:format("--- candidate algorithm B: scan every .app on the path and ask who DECLARES the module~n"),
  [io:format("apps_declaring(~w) = ~w~n", [M, apps_declaring(M)]) || M <- [dup, orph, unlisted, lists, 'Elixir.Mix.Task', erlang]],
  io:format("--- does load order decide which dup wins?~n"),
  io:format("code:which(dup) = ~p~n", [code:which(dup)]).
path_app(M) -> case code:which(M) of P when is_list(P) -> hd(tl(lists:reverse(filename:split(filename:dirname(P))))) ; X -> X end.
apps_declaring(M) ->
  lists:usort(lists:append([
    case file:consult(AppF) of
      {ok,[{application,A,Props}]} -> case lists:member(M, proplists:get_value(modules,Props,[])) of true -> [A]; false -> [] end;
      _ -> [] end
    || D <- code:get_path(), AppF <- filelib:wildcard(filename:join(D,"*.app"))])).
