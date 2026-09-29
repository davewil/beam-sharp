#!/usr/bin/env escript
%% Probe 2c: can the application be DERIVED from a module name on this machine, with nothing declared in the source?
%% EXPECTED (before run), ERL_LIBS=/usr/lib/elixir/lib:
%%  - application:get_application('Elixir.Enum') -> undefined before application:load(elixir) (needs the app loaded), {ok,elixir} after.
%%  - the beam path .../elixir/ebin/Elixir.Enum.beam gives app dir basename "elixir" (two dirname steps), agreeing with lib_dir(elixir)'s dir.
%%  - for OTP's own lists: path .../stdlib-4.3.1.3/ebin/lists.beam -> "stdlib-4.3.1.3" (vsn suffix is in the DIRECTORY name, so
%%    name and version are both recoverable from the path, but only by convention).
main(_) ->
    io:format("get_application before load: ~p~n", [application:get_application('Elixir.Enum')]),
    _ = application:load(elixir),
    io:format("get_application after load : ~p~n", [application:get_application('Elixir.Enum')]),
    [begin P = code:which(M),
           AppDir = filename:basename(filename:dirname(filename:dirname(P))),
           io:format("~-16w ~s  -> app dir ~s~n", [M, P, AppDir]) end || M <- ['Elixir.Enum', lists]],
    io:format("lib_dir(elixir) = ~s~n", [code:lib_dir(elixir)]),
    {ok, [{application, elixir, Kv}]} = file:consult(filename:join([code:lib_dir(elixir), "ebin", "elixir.app"])),
    io:format("elixir.app vsn ~p, applications ~p~n", [proplists:get_value(vsn, Kv), proplists:get_value(applications, Kv)]).
