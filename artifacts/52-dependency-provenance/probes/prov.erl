%% Compile-time provenance primitives under test. Nothing here is bsc code; it
%% is the candidate check written as plain OTP calls so each can be measured.
-module(prov).
-export([check/2, app_of/1, app_modules/1, row/2, bench/3]).

%% The candidate diagnostic's decision procedure, in the order it would run.
check(App, Mod) ->
    case code:lib_dir(App) of
        {error, bad_name} -> {app_missing, App};
        Dir ->
            case code:which(Mod) of
                non_existing -> {module_missing, App, Dir};
                _            -> ok
            end
    end.

%% Module -> application by PATH SHAPE: <lib>/<app>[-<vsn>]/ebin/<mod>.beam.
app_of(Mod) ->
    case code:which(Mod) of
        non_existing -> non_existing;
        cover_compiled -> cover_compiled;
        preloaded -> preloaded;
        File when is_list(File) ->
            case lists:reverse(filename:split(File)) of
                [_Beam, "ebin", AppDir | _] -> {path_shape, app_name(AppDir)};
                [_Beam | _]                 -> {no_app_dir, filename:dirname(File)}
            end
    end.

app_name(Dir) ->
    case string:split(Dir, "-", trailing) of
        [N, V] -> case re:run(V, "^[0-9]") of {match, _} -> N; nomatch -> Dir end;
        [N]    -> N
    end.

%% Module -> application by the .app `modules` list (the authoritative table).
app_modules(App) ->
    case code:lib_dir(App) of
        {error, E} -> {error, E};
        Dir ->
            F = filename:join([Dir, "ebin", atom_to_list(App) ++ ".app"]),
            case file:consult(F) of
                {ok, [{application, App, Props}]} ->
                    {ok, proplists:get_value(modules, Props),
                         proplists:get_value(applications, Props),
                         proplists:get_value(vsn, Props)};
                Other -> {error, Other}
            end
    end.

row(App, Mod) ->
    io:format("  ~-12s ~-24s -> ~p~n", [App, Mod, check(App, Mod)]).

%% Median and min of N runs of F, in microseconds (fresh closure each call).
bench(Name, N, F) ->
    Ts = [begin T0 = erlang:monotonic_time(nanosecond), F(),
                (erlang:monotonic_time(nanosecond) - T0) / 1000 end
          || _ <- lists:seq(1, N)],
    S = lists:sort(Ts),
    io:format("  ~-44s first=~8.1f us  median=~8.1f us  min=~8.1f us  (n=~p)~n",
              [Name, hd(Ts), lists:nth(N div 2 + 1, S), hd(S), N]).
