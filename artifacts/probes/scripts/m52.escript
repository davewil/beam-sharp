#!/usr/bin/env escript
%% m52: cost and shape of the two compile-time checks ticket 52 could add; plus attribute size
main(_) ->
  code:add_pathz("/usr/lib/elixir/lib/elixir/ebin"),
  T = fun(Label, F) -> {US,_} = timer:tc(fun() -> [F() || _ <- lists:seq(1,10000)] end), io:format("~-44s ~.2f us/call~n",[Label, US/10000]) end,
  io:format("lib_dir(crypto)        = ~p~n",[code:lib_dir(crypto)]),
  io:format("lib_dir(req)           = ~p~n",[code:lib_dir(req)]),
  io:format("which(crypto)          = ~p~n",[code:which(crypto)]),
  io:format("which('Elixir.Enum')   = ~p~n",[code:which('Elixir.Enum')]),
  io:format("which('Elixir.Req')    = ~p~n",[code:which('Elixir.Req')]),
  io:format("app of loaded module   = ~p~n",[application:get_application(crypto)]),
  T("code:lib_dir(crypto)  (app present)", fun() -> code:lib_dir(crypto) end),
  T("code:lib_dir(req)     (app absent)", fun() -> code:lib_dir(req) end),
  T("code:which(crypto)    (module present)", fun() -> code:which(crypto) end),
  T("code:which('Elixir.Req') (module absent)", fun() -> code:which('Elixir.Req') end),
  Base=[{attribute,1,module,m},{attribute,1,export,[{f,0}]},{function,1,f,0,[{clause,1,[],[],[{atom,1,ok}]}]}],
  Size=fun(Fs)-> {ok,m,B}=compile:forms(Fs,[binary,debug_info]), byte_size(B) end,
  S0=Size(Base),
  S1=Size([hd(Base),{attribute,1,requires,[req]}|tl(Base)]),
  S2=Size([hd(Base),{attribute,1,requires,[req,jason,telemetry]}|tl(Base)]),
  io:format("beam bytes: none ~p | -requires([req]) ~p (+~p) | 3 apps ~p (+~p)~n",[S0,S1,S1-S0,S2,S2-S0]).
