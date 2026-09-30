-module(probe59).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/probe59.gleam").
-export([new/1, pub_total/1, use_it/1, pub_inv/1, pub_int/1, use_int/1]).
-export_type([order/0, invoice/0]).

-opaque order() :: {order, integer(), integer()}.

-type invoice() :: {invoice, integer(), integer()}.

-file("src/probe59.gleam", 10).
-spec new(integer()) -> order().
new(Id) ->
    {order, Id, 0}.

-file("src/probe59.gleam", 14).
-spec pub_total(order()) -> integer().
pub_total(O) ->
    erlang:element(3, O).

-file("src/probe59.gleam", 18).
-spec priv_total(order()) -> integer().
priv_total(O) ->
    erlang:element(3, O).

-file("src/probe59.gleam", 22).
-spec use_it(order()) -> integer().
use_it(O) ->
    priv_total(O).

-file("src/probe59.gleam", 26).
-spec pub_inv(invoice()) -> integer().
pub_inv(I) ->
    erlang:element(3, I).

-file("src/probe59.gleam", 30).
-spec pub_int(integer()) -> integer().
pub_int(N) ->
    N + 1.

-file("src/probe59.gleam", 34).
-spec priv_int(integer()) -> integer().
priv_int(N) ->
    N + 1.

-file("src/probe59.gleam", 38).
-spec use_int(integer()) -> integer().
use_int(N) ->
    priv_int(N).
