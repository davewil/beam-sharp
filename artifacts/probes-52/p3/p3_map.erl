%% p3: how reliably can module -> application be recovered?
-module(p3_map).
-export([main/0]).
-define(ELX, "/usr/lib/elixir/lib").
main() ->
  %% ELX dirs are <app>/ebin; put them on the path as ERL_LIBS would
  true = lists:all(fun(X) -> X end, [code:add_pathz(D) || D <- filelib:wildcard(?ELX ++ "/*/ebin")]),
  Mods = ['Elixir.Kernel','Elixir.Enum','Elixir.Logger','Elixir.Mix.Task','Elixir.Mix','Elixir.ExUnit.Case','Elixir.EEx.Engine','Elixir.IEx','Elixir.Mix.Tasks.Compile',
          lists, ets, erlang, gen_server, ssl, ssl_cipher, 'OTP-PUB-KEY', pubkey_cert, otp_internal, init, prim_file],
  io:format("~-28s ~-10s ~-10s ~-34s~n", ["module","lib_dir-by-path","get_app","code:which tail"]),
  [row(M) || M <- Mods],
  io:format("--- erts: has an app?~n"),
  io:format("code:lib_dir(erts)=~p  application:load(erts)=~p~n", [code:lib_dir(erts), application:load(erts)]),
  io:format("--- is get_application only for LOADED apps? (logger/mix not loaded yet)~n"),
  io:format("get_application('Elixir.Mix.Task') before load: ~p~n", [application:get_application('Elixir.Mix.Task')]),
  ok.
row(M) ->
  W = code:which(M),
  LD = case W of
         W1 when is_list(W1) -> app_from_path(W1);
         W2 -> W2 end,
  GA = application:get_application(M),
  io:format("~-26w ~-18s ~-24w ~s~n", [M, fmt(LD), GA, string:join(tail(W),"/")]).
tail(W) when is_list(W) -> lists:reverse(lists:sublist(lists:reverse(filename:split(W)),1,3));
tail(W) -> [atom_to_list(W)].
app_from_path(P) ->
  %% .../<app>[-vsn]/ebin/<mod>.beam
  Parts = lists:reverse(filename:split(P)),
  case Parts of [_, "ebin", AppDir | _] -> AppDir; _ -> {no_ebin_layout, P} end.
fmt(X) when is_list(X) -> X;
fmt(X) -> io_lib:format("~w",[X]).
