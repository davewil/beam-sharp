%%% Scenarios: compiler/features/F4-local-bindings.md
%%% Scenarios: compiler/features/F8-bind-and-match.md
-module(bindings_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, count/2,
                          errors/1, escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% Local bindings

bind_src() ->
    "module Bind\n"
    "record Order { Id: int, Total: int }\n"
    "public int Squared(Order o)\n"
    "Squared(o) ->\n"
    "    var t = o.Total\n"
    "    t * t\n"
    "public int Steps(int a, int b)\n"
    "Steps(a, b) ->\n"
    "    var x = a + b\n"
    "    var y = x * 2\n"
    "    y + 1\n"
    "public Order Bump(Order o)\n"
    "Bump(o) ->\n"
    "    var next = o.Total + 1\n"
    "    o with { Total = next }\n".

an_order_of(Total) -> #{'Kind' => 'Bind.Order', 'Id' => 1, 'Total' => Total}.

a_binding_names_a_value_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(49, M:'Squared'(an_order_of(7))).

several_bindings_run_in_order_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(15, M:'Steps'(3, 4)).

a_binding_reads_a_projection_once_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(an_order_of(42), M:'Bump'(an_order_of(41))),
    [Bump] = [F || F = {function, _, 'Bump', 1, _} <- forms_of('Bind')],
    %% One read belongs to the boundary guard and one to the binding.
    ?assertEqual(2, count(Bump, map_get)).

forms_of(Mod) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam", [abstract_code]),
    Forms.

a_binding_before_a_self_call_stays_a_tail_call_test() ->
    Src = "module Loop\n"
          "public int Down(int n, int acc)\n"
          "Down(n, acc) when n <= 0 -> acc\n"
          "Down(n, acc) when n > 0 ->\n"
          "    var next = acc + n\n"
          "    Down(n - 1, next)\n",
    M = build_and_load(Src, 'Loop'),
    ?assertEqual(500500, M:'Down'(1000, 0)).

rebinding_a_name_is_an_error_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    var t = 1\n    var t = 2\n    t\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, t}}],
                 [D || D <- Diags, element(1, D) =:= error]).

a_binding_may_not_shadow_a_parameter_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    var a = 1\n    a\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, a}}],
                 [D || D <- Diags, element(1, D) =:= error]).

an_unbound_name_is_caught_before_erlc_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    total * 2\n",
    {error, Diags} = check_only(Src),
    %% The final expression has no line of its own; the clause supplies it.
    ?assertMatch([{error, {3, _}, 'F', {unbound_variable, total}}],
                 [D || D <- Diags, element(1, D) =:= error]).

an_unused_binding_compiles_without_a_warning_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Src = "module U\npublic int F(int a)\nF(a) ->\n    var unused = a + 1\n    a\n",
            with_src("u.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "Warning"))
            end)
    end.

%%% Binding and matching

%% F8.3 — a bare binding is refused with a suggestion to use var.
a_bare_binding_refuses_and_names_var_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    t = 1\n    t\n",
    ?assertMatch({error, {_, bs_parser, _}}, catch_parse(Src)),
    ?assert(string:find(parse_message(Src), "var t = ") =/= nomatch).

a_bare_destructuring_bind_refuses_test() ->
    Src = "module E\npublic int F((int, int) p)\nF(p) ->\n    (a, b) = p\n    a + b\n",
    ?assert(string:find(parse_message(Src), "var a = ") =/= nomatch).

%% F8.4 — a bare match introduces no names and must be unable to fail.
a_bare_match_that_introduces_nothing_still_works_test() ->
    M = build_and_load("module Ok\npublic int F(int a)\nF(a) ->\n    1 = 1\n    a\n", 'Ok'),
    ?assertEqual(5, M:'F'(5)).

%% F8.2 — var permits map destructuring.
var_makes_map_destructuring_reachable_test() ->
    Src = "module MD\n"
          "record Order { Id: int, Total: int }\n"
          "public int Total(Order o)\n"
          "Total(o) ->\n"
          "    var { Total: t } = o\n"
          "    t\n",
    M = build_and_load(Src, 'MD'),
    ?assertEqual(500, M:'Total'(#{'Kind' => 'MD.Order', 'Id' => 1, 'Total' => 500})).

%% F8.5 — a marked name matches its bound value.
a_marked_name_matches_the_value_it_holds_test() ->
    Src = "module RL\n"
          "public int Run(int head, list<int> xs)\n"
          "Run(head, [])                -> 0\n"
          "Run(head, [== head, ..rest]) -> 1 + Run(head, rest)\n"
          "Run(head, [_, ..rest])       -> 0\n",
    M = build_and_load(Src, 'RL'),
    ?assertEqual(3, M:'Run'(3, [3, 3, 3, 9, 3])),
    ?assertEqual(0, M:'Run'(9, [3, 3, 3])),
    ?assertEqual(0, M:'Run'(1, [])).

%% Abstract code distinguishes a repeated variable from a comparison guard;
%% either lowering would pass the runtime test.
a_marked_name_emits_no_guard_test() ->
    Src = "module RG\n"
          "public int Run(int head, list<int> xs)\n"
          "Run(head, [])                -> 0\n"
          "Run(head, [== head, ..rest]) -> 1\n"
          "Run(head, [_, ..rest])       -> 0\n",
    _ = build_and_load(Src, 'RG'),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/RG.beam", [abstract_code]),
    [{function, _, 'Run', 2, Clauses}] =
        [F || F = {function, _, 'Run', 2, _} <- Forms],
    %% Type guards are allowed; the marker must emit no comparison.
    Guards = [G || {clause, _, _, G, _} <- Clauses],
    ?assertEqual(3, length(Guards)),
    ?assertEqual([], [Op || G <- Guards, Op <- lists:flatten(G),
                            element(1, Op) =:= op]),
    %% The repeated variable performs the equality test.
    [_, {clause, _, [{var, _, V}, {cons, _, {var, _, V}, _}], _, _}, _] = Clauses,
    ?assertEqual('Head', V).

%% F8.7 — a matched name preserves its neighbours' declared types.
%% The calls require head to be int and its sibling rest to be list<int>.
a_matched_name_does_not_widen_its_neighbours_test() ->
    Src = "module N7\n"
          "public int Twice(int n)\n"
          "Twice(n) -> n * 2\n"
          "public int Sum(int head, list<int> xs)\n"
          "Sum(head, [])                -> 0\n"
          "Sum(head, [== head, ..rest]) -> Twice(head) + Sum(head, rest)\n"
          "Sum(head, [_, ..rest])       -> 0\n",
    M = build_and_load(Src, 'N7'),
    ?assertEqual(12, M:'Sum'(3, [3, 3, 9])),
    ?assertEqual(0, M:'Sum'(3, [])),
    %% No match means neither call site runs.
    ?assertEqual(0, M:'Sum'(1, [3, 3])).

%% F8.6 — matching a bound name earns no exhaustiveness credit.
a_marked_name_credits_nothing_to_certain_test() ->
    Src = "module NC\npublic atom F(int acc, int m)\nF(acc, == acc) -> :same\n",
    ?assertMatch([{error, _, 'F', {inexhaustive, _, _}}], errors(Src)).

%% F8.10 — a repeated bare name in a head is refused.
a_repeated_bare_name_in_a_head_is_an_error_test() ->
    Src = "module RB\npublic atom F(int a, int b)\nF(acc, acc) -> :same\nF(_, _) -> :diff\n",
    ?assertMatch([{error, _, 'F', {repeated_in_head, acc}}],
                 [D || D <- errors(Src), element(1, D) =:= error]).

a_repeated_bare_name_inside_a_pattern_is_an_error_test() ->
    Src = "module RN\npublic atom F((int, int) p)\nF((acc, acc)) -> :same\nF(_) -> :diff\n",
    ?assertMatch([{error, _, 'F', {repeated_in_head, acc}}],
                 [D || D <- errors(Src), element(1, D) =:= error]).

%% Check membership because the clause is also inexhaustive.
a_marked_name_that_is_not_bound_is_an_error_test() ->
    Src = "module UB\npublic atom F(int m)\nF(== acc) -> :same\n",
    Errs = [D || D <- errors(Src), element(1, D) =:= error],
    %% Match the reported line without fixing the column.
    ?assert([] =/= [E || E = {error, {3, _}, 'F', {unbound_variable, acc}}
                             <- Errs]).

%% --- helpers ----------------------------------------------------------------

catch_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    bs_parser:parse(Toks).

parse_message(Src) ->
    case catch_parse(Src) of
        {error, {_, bs_parser, Msg}} -> lists:flatten(Msg);
        Other -> lists:flatten(io_lib:format("~p", [Other]))
    end.
