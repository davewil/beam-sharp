-module(shop).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([mk/0, foreign_new/1]).
-export_type([ev/0]).

-type ev() :: {h_t_t_p_get, binary()} | i_pv4_addr | {o_auth_tok, integer()} | plain.

-file("src/shop.gleam", 2).
-spec mk() -> list(ev()).
mk() ->
    [{h_t_t_p_get, ~"x"}, i_pv4_addr, {o_auth_tok, 1}, plain].

-file("src/shop.gleam", 4).
-spec foreign_new(integer()) -> any().
foreign_new(Id) ->
    'Shop':'New'(Id).

