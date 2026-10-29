-module(neg).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/neg.gleam").
-export([g/1, h/1, p/1, x/1]).

-file("src/neg.gleam", 1).
-spec g(integer()) -> binary().
g(N) ->
    case N of
        N@1 when (N@1 >= -5) andalso (N@1 =< 5) ->
            <<"in"/utf8>>;

        _ ->
            <<"out"/utf8>>
    end.

-file("src/neg.gleam", 7).
-spec h(integer()) -> binary().
h(N) ->
    case N of
        N@1 when N@1 >= (2 - 7) ->
            <<"ok"/utf8>>;

        _ ->
            <<"no"/utf8>>
    end.

-file("src/neg.gleam", 13).
-spec p(integer()) -> binary().
p(N) ->
    case N of
        -5 ->
            <<"m5"/utf8>>;

        _ ->
            <<"o"/utf8>>
    end.

-file("src/neg.gleam", 19).
-spec x(integer()) -> integer().
x(N) ->
    Y = - N,
    Y.
