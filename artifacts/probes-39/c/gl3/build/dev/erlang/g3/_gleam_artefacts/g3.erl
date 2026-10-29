-module(g3).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/g3.gleam").
-export([lit/1, var/2, dv/2, bounded/1]).

-file("src/g3.gleam", 1).
-spec lit(integer()) -> integer().
lit(N) ->
    N rem 100.

-file("src/g3.gleam", 2).
-spec var(integer(), integer()) -> integer().
var(N, D) ->
    case D of
        0 -> 0;
        Gleam@denominator -> N rem Gleam@denominator
    end.

-file("src/g3.gleam", 3).
-spec dv(integer(), integer()) -> integer().
dv(N, D) ->
    case D of
        0 -> 0;
        Gleam@denominator -> N div Gleam@denominator
    end.

-file("src/g3.gleam", 4).
-spec bounded(integer()) -> integer().
bounded(N) ->
    case (N >= 0) andalso (N =< 99) of
        true ->
            N + 1;

        false ->
            0
    end.
