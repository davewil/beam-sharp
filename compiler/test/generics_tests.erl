%%% Scenarios: compiler/features/F6-angle-brackets.md
%%% Scenarios: compiler/features/F28-recursive-types.md
-module(generics_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% F6 — angle brackets and parametric types.

parcel_src() ->
    "module Parcel\n"
    "type Weighed = result<int, atom>\n"
    "public atom Grade(Weighed w)\n"
    "Grade((:error, e))     -> e\n"
    "Grade(n) when n > 1000 -> :heavy\n"
    "Grade(n)               -> :light\n".

%% F6.1 — a two-argument bracket parses, resolves, and dispatches.
a_two_argument_bracket_dispatches_test() ->
    M = build_and_load(parcel_src(), 'Parcel'),
    ?assertEqual(heavy,   M:'Grade'(1500)),
    ?assertEqual(light,   M:'Grade'(3)),
    ?assertEqual(timeout, M:'Grade'({error, timeout})).

%% F6.1 — removing the payload clauses leaves an inexhaustive bracket.
%% Removing only the error clause proves nothing: a bare binder covers both.
the_residual_of_a_bracket_is_its_payload_test() ->
    Src = "module Parcel\n"
          "type Weighed = result<int, atom>\n"
          "public atom Grade(Weighed w)\n"
          "Grade((:error, e)) -> e\n",
    ?assertMatch([{error, _, 'Grade', {inexhaustive, _, _}}], errors(Src)).

%% F6.2 — an option type is accepted in a record field.
an_option_field_is_declarable_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Notes: option<int> }\n"
          "public atom Describe(Order o)\n"
          "Describe({ Notes: :nothing }) -> :bare\n"
          "Describe(o)                   -> :annotated\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.3 — an option and its expanded spelling are the same type.
an_option_and_its_spelling_are_one_type_test() ->
    Src = "module Same\n"
          "type Spelled = int | :nothing\n"
          "public atom Take(option<int> o)\n"
          "Take(:nothing) -> :none\n"
          "Take(n)        -> :some\n"
          "public atom Hand(Spelled s)\n"
          "Hand(s) -> Take(s)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.4 — a user parametric alias runs.
%% User type names use PascalCase; lowercase names belong to the prelude.
a_user_parametric_alias_runs_test() ->
    Src = "module Pairs\n"
          "type Pair<T> = (T, T)\n"
          "public int Sum(Pair<int> p)\n"
          "Sum((a, b)) -> a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

%% F6.5 — nested brackets parse without spaces between closing brackets.
nested_generics_parse_because_there_is_no_shift_operator_test() ->
    Src = "module Nest\n"
          "public int Depth(list<list<int>> xss)\n"
          "Depth([])        -> 0\n"
          "Depth([xs, ..r]) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% The position wildcard isolates the condition; columns_tests covers location.

%% F6.6 — a known bracket at the wrong arity reports an arity error.
a_bracket_at_the_wrong_arity_says_so_test() ->
    ?assertError({at, _, {generic_arity, result, 2, 1}},
                 check_only("module E\ntype B = result<int>\n"
                            "public atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({at, _, {generic_arity, option, 1, 2}},
                 check_only("module E\ntype B = option<int, atom>\n"
                            "public atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({at, _, {generic_arity, list, 1, 2}},
                 check_only("module E\npublic atom F(list<int, atom> xs)\nF(xs) -> :ok\n")).

%% Prelude and user names take separate resolver paths for missing arguments.
a_parametric_name_without_its_bracket_says_so_test() ->
    ?assertError({at, _, {needs_type_args, option, 1}},
                 check_only("module E\npublic atom F(option o)\nF(o) -> :ok\n")),
    ?assertError({at, _, {needs_type_args, 'Pair', 1}},
                 check_only("module E\ntype Pair<T> = (T, T)\n"
                            "public atom F(Pair p)\nF(p) -> :ok\n")).

a_bracket_on_a_ground_type_says_so_test() ->
    ?assertError({at, _, {not_parametric, 'Plain'}},
                 check_only("module E\ntype Plain = int\n"
                            "public atom F(Plain<int> p)\nF(p) -> :ok\n")),
    ?assertError({unknown_generic, stack},
                 check_only("module E\npublic atom F(stack<int> s)\nF(s) -> :ok\n")).

%% F6.7 — an undeclared alias variable is an unknown type.
%% Only the parameter list distinguishes type variables from user type names.
an_undeclared_variable_in_an_alias_body_is_caught_test() ->
    ?assertError({at, _, {unknown_type, 'U'}},
                 check_only("module E\ntype Wrong<T> = (T, U)\n"
                            "public atom F(Wrong<int> w)\nF(w) -> :ok\n")).

%% F6.8 — non-contractive aliases are refused.
a_non_contractive_alias_is_a_permanent_error_test() ->

    ?assertError({at, _, {cyclic_type, 'A'}},
                 check_only("module E\ntype A = B\ntype B = A\n"
                            "public atom F(A a)\nF(a) -> :ok\n")),
    %% A union is not a constructor and cannot make recursion contractive.
    ?assertError({at, _, {cyclic_type, 'X'}},
                 check_only("module E\ntype X = X | int\n"
                            "public atom F(X x)\nF(x) -> :ok\n")).

%% F28 — contractive aliases resolve through tuples, lists, and records.
a_contractive_alias_now_resolves_test() ->

    ?assertMatch({ok, _, _},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public atom F(Tree<int> t)\nF(t) -> :ok\n")),
    %% A bare recursive list reaches a separate algebra path from a tuple.
    ?assertMatch({ok, _, _},
                 check_only("module E\ntype Nest = :leaf | list<Nest>\n"
                            "public atom F(Nest n)\nF(n) -> :ok\n")),
    %% Recursive record fields exercise closed-map resolution.
    ?assertMatch({ok, _, _},
                 check_only("module E\nrecord Node { Kids: list<Node> }\n"
                            "public atom F(Node n)\nF(n) -> :ok\n")).

%% CLI prose distinguishes invalid recursion from an unavailable feature.
the_two_refusals_read_differently_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Bad = "module E\ntype X = X | int\n"
                  "public atom F(X x)\nF(x) -> :ok\n",
            Good = "module E\ntype Tree = :leaf | (:node, Tree, Tree)\n"
                   "public atom F(Tree t)\nF(t) -> :ok\n",
            with_src("in.bs", Bad,
                     fun(P, R) ->
                             O = run_cli("--src-root " ++ R ++ " " ++ P),
                             ?assert(string:find(O, "not a missing feature") =/= nomatch),
                             ?assertEqual(nomatch, string:find(O, "not built yet"))
                     end),
            %% F28 — a contractive tree compiles without refusal messages.
            with_src("in.bs", Good,
                     fun(P, R) ->
                             O = run_cli("--src-root " ++ R ++ " " ++ P),
                             ?assertEqual(nomatch, string:find(O, "not built yet")),
                             ?assertEqual(nomatch, string:find(O, "gap in this")),
                             ?assertEqual(nomatch, string:find(O, "not a missing feature"))
                     end)
    end.

%% Sibling uses and terminating alias chains are not cycles.
a_repeated_alias_is_not_a_cycle_test() ->
    Src = "module Twice\n"
          "type Pair<T> = (T, T)\n"
          "type Both = (Pair<int>, Pair<atom>)\n"
          "type Deep = Pair<Pair<int>>\n"
          "public atom F(Both b, Deep d)\n"
          "F(b, d) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.9 — angle brackets remain comparisons in value position.
angle_brackets_did_not_reach_value_position_test() ->
    M = build_and_load("module Cmp\n"
                       "public bool Both(int a, int b, int c, int d)\n"
                       "Both(a, b, c, d) -> a < b and c > d\n", 'Cmp'),
    ?assertEqual(true,  M:'Both'(1, 2, 5, 3)),
    ?assertEqual(false, M:'Both'(1, 2, 3, 5)).

%% The call-in-guard error proves parsing succeeds before the BEAM restriction.
a_guard_with_comparisons_still_parses_test() ->
    Src = "module G\n"
          "public int Total(int x)\n"
          "Total(x) -> x\n"
          "public atom Cmp((int, int) p)\n"
          "Cmp((x, y)) when x < y and Total(x) > 0 -> :yes\n"
          "Cmp(p)                                 -> :no\n",
    ?assertMatch([{error, _, 'Cmp', {call_in_guard, 'Total'}}], errors(Src)).

%% F6.10 — the emitted spec contains the expanded ground type.
the_emitted_spec_is_the_expanded_ground_type_test() ->
    {ok, _} = compile("module Opt\n"
                      "public option<int> Keep(option<int> o)\n"
                      "Keep(o) -> o\n"),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Opt.beam", [abstract_code]),
    [Spec] = [S || S = {attribute, _, spec, _} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "integer()") =/= nomatch),
    ?assert(string:find(Printed, "nothing") =/= nomatch),
    %% No parametric alias name survives in the published spec.
    ?assertEqual(nomatch, string:find(Printed, "option")).
