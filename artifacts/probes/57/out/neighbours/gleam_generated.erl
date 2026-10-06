-module(g57).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([f/1, h/1]).

-file("src/g57.gleam", 2).
-spec f(integer()) -> binary().
f(X) ->
    case X of
        -5 ->
            ~"neg5";

        N when N >= -5 ->
            ~"ge";

        _ ->
            ~"lt"
    end.

-file("src/g57.gleam", 9).
-spec h(integer()) -> integer().
h(X) ->
    (X - -5) + - X.

