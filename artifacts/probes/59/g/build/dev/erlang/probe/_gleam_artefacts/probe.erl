-module(probe).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([make_token/1, pub_amount/1, via_cart/1, pub_inc/1, via_n/1, token_value/1, via_match/1]).
-export_type([order/0, invoice/0, cart/0, token/0]).

-type order() :: {order, integer(), integer()}.

-type invoice() :: {invoice, integer(), integer()}.

-type cart() :: {cart, order(), integer()}.

-opaque token() :: {token, integer()}.

-file("src/probe.gleam", 19).
-spec make_token(integer()) -> token().
make_token(V) ->
    {token, V}.

-file("src/probe.gleam", 23).
-spec pub_amount(order()) -> integer().
pub_amount(O) ->
    erlang:element(3, O).

-file("src/probe.gleam", 27).
-spec priv_amount(order()) -> integer().
priv_amount(O) ->
    erlang:element(3, O).

-file("src/probe.gleam", 31).
-spec via_cart(cart()) -> integer().
via_cart(C) ->
    priv_amount(erlang:element(2, C)).

-file("src/probe.gleam", 35).
-spec pub_inc(integer()) -> integer().
pub_inc(N) ->
    N + 1.

-file("src/probe.gleam", 39).
-spec priv_inc(integer()) -> integer().
priv_inc(N) ->
    N + 1.

-file("src/probe.gleam", 43).
-spec via_n(cart()) -> integer().
via_n(C) ->
    priv_inc(erlang:element(3, C)).

-file("src/probe.gleam", 47).
-spec token_value(token()) -> integer().
token_value(T) ->
    erlang:element(2, T).

-file("src/probe.gleam", 52).
-spec priv_match(order()) -> integer().
priv_match(O) ->
    {order, _, T} = O,
    T.

-file("src/probe.gleam", 57).
-spec via_match(order()) -> integer().
via_match(O) ->
    priv_match(O).

