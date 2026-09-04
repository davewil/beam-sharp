-module(gleam_probe).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).

-export([classify/1, sign/1, main/0]).

-file("src/gleam_probe.gleam", 1).
-spec classify(float()) -> binary().
classify(X) ->
    case X of
        _ when X >= -5.0 ->
            <<"hi"/utf8>>;

        _ ->
            <<"lo"/utf8>>
    end.

-file("src/gleam_probe.gleam", 8).
-spec sign(integer()) -> binary().
sign(N) ->
    case N of
        -1 ->
            <<"neg_one"/utf8>>;

        0 ->
            <<"zero"/utf8>>;

        _ ->
            <<"other"/utf8>>
    end.

-file("src/gleam_probe.gleam", 16).
-spec main() -> binary().
main() ->
    classify(-5.0),
    classify(-6.0),
    sign(-1).
