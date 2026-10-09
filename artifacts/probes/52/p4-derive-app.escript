#!/usr/bin/env escript
%% P4: can the compiler DERIVE module -> (application, vsn) from the code path, with no source declaration?
%% Positive: lists, 'Elixir.Enum', ssl modules.  Control (must differ): a module in a flat -pa dir (no app dir / no .app),
%% and a module that is not on the path.  Also: the naive API application:get_application/1.
main(_) ->
    %% a flat directory with a compiled module, the way `bsc -o DIR` leaves things
    Flat = "/tmp/p4flat", ok = filelib:ensure_dir(Flat ++ "/x"),
    file:write_file(Flat ++ "/flatmod.erl", "-module(flatmod).\n-export([f/0]).\nf()->1.\n"),
    {ok, flatmod} = compile:file(Flat ++ "/flatmod", [{outdir, Flat}]),
    true = code:add_patha(Flat),
    true = code:add_patha("/usr/lib/elixir/lib/elixir/ebin"),
    [probe(M) || M <- [lists, ssl, 'Elixir.Enum', flatmod, 'Elixir.Nope.Absent']].

probe(M) ->
    Naive = application:get_application(M),
    case code:which(M) of
        non_existing -> io:format("~-22w which=non_existing  get_application=~p  derived=NONE (absent)~n", [M, Naive]);
        Beam ->
            Ebin = filename:dirname(Beam),
            AppDir = filename:dirname(Ebin),
            Base = filename:basename(AppDir),
            AppFiles = filelib:wildcard(filename:join(Ebin, "*.app")),
            Derived = case AppFiles of
                [F] -> {ok, [{application, A, Props}]} = file:consult(F),
                       {A, proplists:get_value(vsn, Props)};
                _   -> none_no_app_file
            end,
            io:format("~-22w dir=~s get_application=~p derived=~p~n", [M, Base, Naive, Derived])
    end.
