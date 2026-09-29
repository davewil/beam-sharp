-module(gnames).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gnames.gleam").
-export([get_x/1, http_get/1, all/0]).
-export_type([t/0]).

-type t() :: ok2 |
    {my_variant, integer()} |
    get_x |
    {parse2_ints, integer()} |
    h_t_t_p_get |
    {h_t_t_p_get2, integer()} |
    a_b_c |
    abc_def |
    x1_y.

-file("src/gnames.gleam", 23).
-spec get_x(integer()) -> integer().
get_x(X) ->
    X + 1.

-file("src/gnames.gleam", 24).
-spec http_get(integer()) -> t().
http_get(X) ->
    {h_t_t_p_get2, X}.

-file("src/gnames.gleam", 25).
-spec all() -> list(t()).
all() ->
    [ok2,
        {my_variant, 1},
        get_x,
        {parse2_ints, 2},
        h_t_t_p_get,
        {h_t_t_p_get2, 3},
        a_b_c,
        abc_def,
        x1_y].
