%%% Scenarios: compiler/features/F20-list-length.md
-module(lists_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% --- Lists ---

series_src() ->
    %% `FibL` avoids overwriting the reload fixture's `Fib` bytecode and module.
    "module FibL\n"
    "public list<int> Fib(int n)\n"
    "Fib(n) when n <= 0 -> []\n"
    "Fib(n) when n > 0  -> Series(n, 0, 1, [])\n"
    "public list<int> Series(int n, int a, int b, list<int> acc)\n"
    "Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])\n"
    "Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])\n"
    "public list<int> Reverse(list<int> xs, list<int> acc)\n"
    "Reverse([], acc)          -> acc\n"
    "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n".

a_list_function_computes_test() ->
    M = build_and_load(series_src(), 'FibL'),
    ?assertEqual([], M:'Fib'(0)),
    ?assertEqual([0], M:'Fib'(1)),
    ?assertEqual([0, 1, 1, 2, 3], M:'Fib'(5)),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

nil_and_cons_partition_a_list_test() ->
    {ok, _} = compile(series_src()),
    {ok, Toks, _} = bs_lexer:string(series_src()),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, _, Diags} = bs_check:check(Decls),
    ?assertEqual([], [D || D <- Diags, element(1, D) =:= error]).

missing_nil_clause_is_caught_test() ->
    Src = "module L\npublic list<int> Rev(list<int> xs, list<int> acc)\n"
          "Rev([x, ..rest], acc) -> Rev(rest, [x, ..acc])\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {error, Diags} = bs_check:check(Decls),
    [{error, _, 'Rev', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    ?assert(string:find(bs_types:to_string(Residual), "[]") =/= nomatch).

%% Inspect bytecode: source recursion alone does not prove tail-call emission.
recursion_is_a_tail_call_test() ->
    {ok, _} = compile(series_src()),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(?OUT ++ "/FibL.beam"),
    Bad = [{Name, Op}
           || {function, Name, _A, _E, Is} <- Fns,
              Name =/= module_info,
              {Op} <- [{element(1, I)} || I <- Is, is_tuple(I)],
              Op =:= call orelse Op =:= call_ext],
    ?assertEqual([], Bad).

%% This depth exposes stack growth from body recursion.
tail_calls_do_not_grow_the_stack_test() ->
    M = build_and_load(series_src(), 'FibL'),
    Self = self(),
    Pid = spawn(fun() ->
                    _ = M:'Fib'(50000),
                    {stack_size, S} = erlang:process_info(self(), stack_size),
                    Self ! {stack, S}
                end),
    receive {stack, S} -> ?assert(S < 100)
    after 60000 -> exit({timeout, Pid}) end.

%%% F20 — list patterns distinguish exact and minimum lengths.

diags(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    case bs_check:check(Decls) of
        {ok, _, Ds} -> Ds;
        {error, Ds} -> Ds
    end.

errors(Src) -> [D || D <- diags(Src), element(1, D) =:= error].

shape_src(Clauses) ->
    "module Sh\npublic atom Shape(list<int> xs)\n" ++ Clauses.

a_two_element_prefix_does_not_cover_a_one_element_list_test() ->
    Src = shape_src("Shape([]) -> :empty\nShape([a, b, ..]) -> :many\n"),
    [{error, _, 'Shape', {inexhaustive, Residual, _}}] = errors(Src),
    %% Parentheses enclose the argument list; `[int]` means exactly one element.
    ?assertEqual("([int])", bs_types:to_string(Residual)).

closed_and_open_prefixes_compose_to_every_list_test() ->
    Src = shape_src("Shape([]) -> :empty\n"
                    "Shape([a]) -> :one\n"
                    "Shape([a, b, ..]) -> :many\n"),
    ?assertEqual([], errors(Src)).

%% After empty and two-or-more, the final clause still matches one element.
a_clause_that_matches_is_not_called_unreachable_test() ->
    Src = shape_src("Shape([]) -> :empty\n"
                    "Shape([a, b, ..]) -> :many\n"
                    "Shape([a, ..]) -> :one\n"),
    ?assertEqual([], [D || D <- diags(Src), element(1, D) =:= warning]).

a_closed_list_pattern_means_exactly_that_length_test() ->
    Src = "module Cl\n"
          "public atom Shape(list<int> xs)\n"
          "Shape([]) -> :empty\n"
          "Shape([a]) -> :one\n"
          "Shape([a, b]) -> :two\n"
          "Shape([a, b, c, ..]) -> :many\n",
    M = build_and_load(Src, 'Cl'),
    ?assertEqual(empty, M:'Shape'([])),
    ?assertEqual(one,   M:'Shape'([7])),
    ?assertEqual(two,   M:'Shape'([7, 8])),
    ?assertEqual(many,  M:'Shape'([7, 8, 9])),
    ?assertEqual(many,  M:'Shape'([7, 8, 9, 10])).

a_route_table_dispatches_on_path_length_test() ->
    Src = "module Rt\n"
          "public atom Route(list<string> path)\n"
          "Route([\"orders\"]) -> :index\n"
          "Route([\"orders\", id]) -> :show\n"
          "Route(_) -> :not_found\n",
    M = build_and_load(Src, 'Rt'),
    ?assertEqual(index,     M:'Route'([<<"orders">>])),
    ?assertEqual(show,      M:'Route'([<<"orders">>, <<"42">>])),
    ?assertEqual(not_found, M:'Route'([<<"orders">>, <<"42">>, <<"lines">>])),
    ?assertEqual(not_found, M:'Route'([])).

a_closed_rest_is_retired_and_names_the_fix_test() ->
    Src = shape_src("Shape([a, ..[]]) -> :one\nShape(_) -> :o\n"),
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Msg}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Msg), "`..[]` is retired") =/= nomatch).

a_nested_rest_pattern_is_retired_and_names_the_fix_test() ->
    Src = shape_src("Shape([a, ..[b, ..t]]) -> :two\nShape(_) -> :o\n"),
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Msg}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Msg), "a rest is `..` or `..name`")
            =/= nomatch).

%% A finite residual forbids a catch-all; unbounded integers are the control.
a_catch_all_over_a_closed_list_residual_is_refused_test() ->
    Src = "module Cb\npublic atom F(list<bool> xs)\n"
          "F([]) -> :e\nF([a, b, ..]) -> :m\nF(_) -> :o\n",
    ?assertMatch([{error, _, 'F', {catch_all_over_closed, _, _}}], errors(Src)).

a_catch_all_over_an_open_list_residual_is_still_legal_test() ->
    Src = shape_src("Shape([]) -> :empty\nShape([a, b, ..]) -> :many\n"
                    "Shape(_) -> :o\n"),
    ?assertEqual([], errors(Src)).

%%% F20 — switch arms check list lengths too.

switch_src(Arms) ->
    "module Sw\npublic atom Shape(list<int> xs)\nShape(xs) -> xs switch {\n"
        ++ Arms ++ "\n}\n".

a_switch_arm_sees_list_length_too_test() ->
    Src = switch_src("    [] => :empty,\n"
                     "    [a, b, ..] => :many"),
    [{error, _, 'Shape', {switch_inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("[int]", bs_types:to_string(Residual)).

a_switch_over_every_length_needs_no_catch_all_test() ->
    Src = switch_src("    [] => :empty,\n"
                     "    [a] => :one,\n"
                     "    [a, b, ..] => :many"),
    ?assertEqual([], errors(Src)).

a_residual_over_a_union_element_does_not_enumerate_products_test() ->
    Src = "module Cap\ntype Q = :a | :b | :c | :d\n"
          "public atom F(list<Q> xs)\n"
          "F([]) -> :e\nF([x, y, z, ..]) -> :m\n",
    [{error, _, 'F', {inexhaustive, Residual, _}}] = errors(Src),
    %% Each position retains its union instead of enumerating value products.
    ?assertEqual("([:a | :b | :c | :d] | [:a | :b | :c | :d, :a | :b | :c | :d])",
                 bs_types:to_string(Residual)).

a_refutable_closed_bind_names_the_complement_test() ->
    Src = "module Bd\npublic int F(list<int> xs)\n"
          "F(xs) ->\n    var [a, b] = xs\n    a + b\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("[] | [int] | [int, int, int, ..]",
                 bs_types:to_string(Residual)).
