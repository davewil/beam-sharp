#!/usr/bin/env escript
%% p11: is a bare atom ever ambiguous between an APPLICATION name and a MODULE name?
%% (Matters for any spelling that puts an application atom where a module atom already goes, e.g. `using :req`.)
%% Counts applications on this machine's code path whose name is also the name of a module in that application.
main(_) ->
    Libs = [D || D <- code:get_path(), filename:basename(D) =:= "ebin"],
    Rows = lists:append([ [{filename:basename(filename:dirname(E)), App, Mods}
                           || A <- filelib:wildcard(filename:join(E, "*.app")),
                              {ok, [{application, App, Props}]} <- [file:consult(A)],
                              Mods <- [proplists:get_value(modules, Props, [])]]
                         || E <- Libs]),
    Same = [App || {_, App, Mods} <- Rows, lists:member(App, Mods)],
    io:format("applications on the path: ~p~n", [length(Rows)]),
    io:format("applications that own a module of the SAME NAME: ~p~n  ~p~n", [length(Same), lists:sort(Same)]),
    %% and the Elixir convention, which maps module -> app by lower-casing: where does it fail?
    [io:format("module ~p lives in app ~p~n", [M, App])
     || {_, App, Mods} <- Rows, App =:= elixir, M <- [ 'Elixir.String', 'Elixir.Enum' ], lists:member(M, Mods)].
