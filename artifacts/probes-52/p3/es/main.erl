-module(main). -export([main/1]).
main(_) ->
  io:format("embedded emb: which=~p~n", [code:which(emb)]),
  io:format("get_application(emb)=~p~n", [application:get_application(emb)]),
  io:format("lib_dir by name emb: ~p~n", [code:lib_dir(emb)]),
  io:format("code:get_path has escript entry: ~p~n", [[P || P <- code:get_path(), string:find(P,"emb.es") =/= nomatch]]),
  io:format("is_loaded: ~p ensure_loaded: ~p~n", [code:is_loaded(emb), code:ensure_loaded(emb)]),
  io:format("escript:script_name ~p~n", [escript:script_name()]).
