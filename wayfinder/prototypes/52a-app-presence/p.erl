-module(p).
-export([main/0]).
main() ->
  io:format("otp ~s~n",[erlang:system_info(otp_release)]),
  io:format("call:      ~p~n",[catch 'Elixir.Req':new([])]),
  io:format("lib_dir:   ~p~n",[code:lib_dir(req)]),
  io:format("which:     ~p~n",[code:which('Elixir.Req')]),
  io:format("ensure:    ~p~n",[code:ensure_loaded('Elixir.Req')]).
