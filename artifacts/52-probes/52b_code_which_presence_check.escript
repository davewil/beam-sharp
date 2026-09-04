#!/usr/bin/env escript
%% Probe: can a compile-time presence check be done directly from the module
%% atom a `using` declaration already names, with NO new annotation syntax?
%% code:which/1 returns a beam path (or `non_existing`/`cover_compiled`/`preloaded`)
%% without ever calling into the module -- so it never risks a real invocation
%% and never needs to know an "application" name, only the module atom the
%% `using` line already carries.
main(_) ->
    io:format("code:which('lists')            = ~p~n", [code:which(lists)]),
    io:format("code:which('Elixir.Req')        = ~p (before adding it to the path)~n",
               [code:which('Elixir.Req')]),
    ReqEbin = "/home/user/beam-sharp/artifacts/scratch/reqebin_stub",
    ok = filelib:ensure_dir(ReqEbin ++ "/x"),
    %% compile a tiny stand-in module named 'Elixir.Req' so we don't need the
    %% real network-fetched Req tree to exercise the mechanism.
    Src = "-module('Elixir.Req').\n-export([stub/0]).\nstub() -> ok.\n",
    SrcFile = ReqEbin ++ "/Elixir.Req.erl",
    ok = file:write_file(SrcFile, Src),
    {ok, 'Elixir.Req'} = compile:file(SrcFile, [{outdir, ReqEbin}, return_errors]),
    true = code:add_patha(ReqEbin),
    io:format("code:which('Elixir.Req')        = ~p (after add_patha, ERL_LIBS-equivalent)~n",
               [code:which('Elixir.Req')]),
    code:del_path(ReqEbin),
    %% Confirm this is genuinely presence-only: does it ever load/run the module?
    io:format("code:is_loaded('Elixir.Req')    = ~p (never loaded by the check itself)~n",
               [code:is_loaded('Elixir.Req')]),
    halt(0).
