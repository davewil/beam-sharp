-module(g).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/g.gleam").
-export([pat/1, expr/0, two/0]).

-file("src/g.gleam", 1).
-spec pat(integer()) -> binary().
pat(X) ->
    case X of
        -5 ->
            <<"neg5"/utf8>>;

        N when N >= -5 ->
            <<"ge"/utf8>>;

        _ ->
            <<"other"/utf8>>
    end.

-file("src/g.gleam", 8).
-spec expr() -> integer().
expr() ->
    -5.

-file("src/g.gleam", 9).
-spec two() -> integer().
two() ->
    - -5.
