-module(scope).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([pub_amount/1, pub_double/1, total_of/1, use_double/1, doc_total/1]).
-export_type([order/0, doc/0]).

-type order() :: {order, integer(), integer()}.

-type doc() :: {invoice, integer(), integer()} | {receipt, integer(), integer()}.

-file("src/scope.gleam", 10).
-spec pub_amount(order()) -> integer().
pub_amount(O) ->
    erlang:element(3, O).

-file("src/scope.gleam", 14).
-spec priv_amount(order()) -> integer().
priv_amount(O) ->
    erlang:element(3, O).

-file("src/scope.gleam", 18).
-spec pub_double(integer()) -> integer().
pub_double(N) ->
    N * 2.

-file("src/scope.gleam", 22).
-spec priv_double(integer()) -> integer().
priv_double(N) ->
    N * 2.

-file("src/scope.gleam", 30).
-spec sum(list(order()), integer()) -> integer().
sum(Xs, Acc) ->
    case Xs of
        [] ->
            Acc;

        [X | Rest] ->
            sum(Rest, Acc + priv_amount(X))
    end.

-file("src/scope.gleam", 26).
-spec total_of(list(order())) -> integer().
total_of(Xs) ->
    sum(Xs, 0).

-file("src/scope.gleam", 37).
-spec use_double(integer()) -> integer().
use_double(N) ->
    priv_double(N).

-file("src/scope.gleam", 42).
-spec priv_doc(doc()) -> integer().
priv_doc(D) ->
    case D of
        {invoice, _, T} ->
            T;

        {receipt, _, T@1} ->
            T@1
    end.

-file("src/scope.gleam", 49).
-spec doc_total(doc()) -> integer().
doc_total(D) ->
    priv_doc(D).

