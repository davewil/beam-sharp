-module(v4).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/v4.gleam").
-export([f/0, g/0]).
-export_type([q/0]).

-type q() :: {hi, integer()} | h_t_t_p_server_error | x_m_l_http | i_o_error2.

-file("src/v4.gleam", 2).
-spec f() -> list(q()).
f() ->
    [h_t_t_p_server_error, x_m_l_http, i_o_error2].

-file("src/v4.gleam", 3).
-spec g() -> q().
g() ->
    {hi, 1}.
