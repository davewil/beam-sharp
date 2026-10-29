-module(probe).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/probe.gleam").
-export([pub_total/1, pub_secret/1, pub_int/1, first/1]).
-export_type([order/0, secret/0]).

-type order() :: {order, integer(), integer()}.

-opaque secret() :: {secret, integer()}.

-file("src/probe.gleam", 13).
-spec priv_total(order()) -> integer().
priv_total(O) ->
    erlang:element(3, O).

-file("src/probe.gleam", 9).
-spec pub_total(order()) -> integer().
pub_total(O) ->
    priv_total(O).

-file("src/probe.gleam", 21).
-spec priv_secret(secret()) -> integer().
priv_secret(S) ->
    erlang:element(2, S).

-file("src/probe.gleam", 17).
-spec pub_secret(secret()) -> integer().
pub_secret(S) ->
    priv_secret(S).

-file("src/probe.gleam", 29).
-spec priv_int(integer()) -> integer().
priv_int(N) ->
    N + 1.

-file("src/probe.gleam", 25).
-spec pub_int(integer()) -> integer().
pub_int(N) ->
    priv_int(N).

-file("src/probe.gleam", 33).
-spec first(list(order())) -> integer().
first(Os) ->
    case Os of
        [H | _] ->
            priv_total(H);

        [] ->
            0
    end.
