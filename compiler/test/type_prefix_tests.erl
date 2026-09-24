%%% Scenarios: compiler/features/F53-numeric-union-dispatch.md
-module(type_prefix_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, errors/1, check_only/1]).

%%% F53 — numeric unions dispatch through type prefixes.

ledger() ->
    "module Ledger\n\n"
    "type Side = :debit | :credit\n\n"
    "public Side Post(int | float amount)\n\n"
    "Post(int a)   when a < 0   -> :credit\n"
    "Post(int a)                -> :debit\n"
    "Post(float f) when f < 0.0 -> :credit\n"
    "Post(float f)              -> :debit\n".

%%% F53.1 — the advised dispatch runs for both numeric parts.

the_advised_dispatch_posts_both_parts_test() ->
    M = build_and_load(ledger(), 'Ledger'),
    ?assertEqual(credit, M:'Post'(-250)),
    ?assertEqual(credit, M:'Post'(-2.50)),
    ?assertEqual(debit, M:'Post'(250)),
    ?assertEqual(debit, M:'Post'(2.50)),
    %% Zero is a debit in both spellings: the boundary of each part.
    ?assertEqual(debit, M:'Post'(0)),
    ?assertEqual(debit, M:'Post'(0.0)).

%% Each prefix narrows its binding before the guard checks the literal.
the_prefix_narrows_the_binding_for_the_guard_test() ->
    ?assertEqual([], diags(ledger())).

%%% F53.2 — type prefixes contribute to exhaustiveness.

%% Dropping the float clauses checks that the prefix earns coverage.
dropping_a_part_reports_inexhaustive_test() ->
    Src = "module Half\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(int a) -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(inexhaustive, element(1, element(4, D))),
    Residual = element(2, element(4, D)),
    %% Parentheses represent the one-argument clause product.
    ?assertEqual("(float)", bs_types:to_string(Residual)).

%%% F53.3 — prefixes accept only types a runtime test distinguishes.

a_non_numeric_pair_dispatches_too_test() ->
    Src = "module Norm\n\n"
          "public int Norm(atom | int x)\n\n"
          "Norm(atom a) -> 0\n"
          "Norm(int n)  -> n\n",
    M = build_and_load(Src, 'Norm'),
    ?assertEqual(0, M:'Norm'(missing)),
    ?assertEqual(7, M:'Norm'(7)).

%% `is_list` accepts both members and cannot distinguish their elements.
a_member_no_single_test_decides_is_refused_test() ->
    Src = "module Counts\n\n"
          "type Xs = list<int> | list<binary>\n\n"
          "public int Count(Xs xs)\n\n"
          "Count(list<int> ns)    -> 1\n"
          "Count(list<binary> bs) -> 0\n",
    D = refusal(Src),
    ?assertMatch({type_prefix_undecidable, _, _, {narrower, is_list}}, D),
    Prose = prose(D),
    ?assert(string:find(Prose, "list<int>") =/= nomatch),
    %% The test exists but accepts more values than the named type.
    ?assert(string:find(Prose, "is_list") =/= nomatch),
    %% The type remains usable even though its pattern form is unavailable.
    ?assert(string:find(Prose, "declared, passed and") =/= nomatch),
    ?assert(string:find(Prose, "never matched on") =/= nomatch),
    ?assert(string:find(Prose, "not built") =/= nomatch),
    ?assert(string:find(Prose, "temporary by construction") =/= nomatch).

%% PascalCase names take the record path, even for numeric refinements.
a_refinement_in_prefix_position_is_refused_test() ->
    Src = "module Trip\n\n"
          "type Meters = int where value >= 0\n\n"
          "public int Far(Meters | float d)\n\n"
          "Far(Meters m) -> m\n"
          "Far(float f)  -> 0\n",
    ?assertMatch({not_a_record, _, 'Meters'}, refusal(Src)).

term_in_prefix_position_is_refused_test() ->
    Src = "module Any\n\n"
          "public int Go(int | float x)\n\n"
          "Go(term t) -> 0\n",
    D = refusal(Src),
    ?assertMatch({type_prefix_undecidable, _, "term", several_parts}, D),
    %% `term` spans several parts; the message must distinguish that reason.
    ?assert(string:find(prose(D), "more than one part") =/= nomatch).

%% An uppercase alias takes the record path, not the builtin part path.
an_alias_to_a_union_is_still_refused_and_says_what_to_write_test() ->
    Src = "module Amounts\n\n"
          "type Amount = int | float\n\n"
          "public atom Post(Amount a)\n\n"
          "Post(Amount x) -> :debit\n",
    D = refusal(Src),
    ?assertMatch({not_a_record, _, 'Amount'}, D),
    %% The diagnostic also points to the lowercase part-prefix form.
    ?assert(string:find(prose(D), "part") =/= nomatch).

%%% F53.4 — switch arms accept prefixes and reject nested forms.

the_arm_dispatches_the_parts_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a switch {\n"
          "    int n   => n * 100,\n"
          "    float f => 0\n"
          "}\n",
    M = build_and_load(Src, 'Pence'),
    ?assertEqual(25000, M:'Owed'(250)),
    ?assertEqual(0, M:'Owed'(2.50)).

the_arm_refuses_what_the_head_refuses_test() ->
    Src = "module Sums\n\n"
          "type Xs = list<int> | list<binary>\n\n"
          "public int Count(Xs xs)\n\n"
          "Count(xs) -> xs switch {\n"
          "    list<int> ns    => 1,\n"
          "    list<binary> bs => 0\n"
          "}\n",
    ?assertMatch({type_prefix_undecidable, _, _, {narrower, is_list}},
                 refusal(Src)).

a_nested_type_prefix_is_refused_rather_than_crashing_test() ->
    Src = "module Nest\n\n"
          "public int Go((int | float, atom) pair)\n\n"
          "Go((int n, a))   -> n\n"
          "Go((float f, a)) -> 0\n",
    D = refusal(Src),
    ?assertMatch({type_prefix_nested, _}, D),
    %% A guard cannot dispatch a part nested inside the destructured value.
    ?assert(string:find(prose(D), "whole argument") =/= nomatch).

a_nested_type_prefix_in_an_arm_is_refused_too_test() ->
    Src = "module NestArm\n\n"
          "public int Go((int | float, atom) pair)\n\n"
          "Go(p) -> p switch {\n"
          "    (int n, a)   => n,\n"
          "    (float f, a) => 0\n"
          "}\n",
    ?assertMatch({type_prefix_nested, _}, refusal(Src)).

%%% F53.5 — operators refuse numeric unions and advise dispatch.

a_numeric_union_at_an_operator_is_refused_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a * 100\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

the_refusal_reaches_a_guard_too_test() ->
    Src = "module Ledger\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(a) when a < 0 -> :credit\n"
          "Post(_)            -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

%% A float literal still conflicts with the union's int member.
the_float_literal_spelling_goes_too_test() ->
    Src = "module Ledger\n\n"
          "public atom Post(int | float amount)\n\n"
          "Post(a) when a < 0.0 -> :credit\n"
          "Post(_)              -> :debit\n",
    [D | _] = errors(Src),
    ?assertEqual(numeric_union_operand, element(1, element(4, D))).

%% Literal or conversion advice cannot resolve a union operand.
the_advice_names_the_dispatch_and_not_the_literal_test() ->
    Src = "module Pence\n\n"
          "public int Owed(int | float amount)\n\n"
          "Owed(a) -> a * 100\n",
    [D | _] = errors(Src),
    Prose = prose(D),
    ?assertEqual(nomatch, string:find(Prose, "0.0")),
    ?assertEqual(nomatch, string:find(Prose, "Float.FromInt")),
    ?assert(string:find(Prose, "int | float") =/= nomatch),
    ?assert(string:find(Prose, "Owed(int") =/= nomatch),
    ?assert(string:find(Prose, "Owed(float") =/= nomatch).

%%% F53.6 — advice preserves every parameter position.

%% The union is the second parameter, so a first-position template is wrong.
the_advice_writes_a_head_of_the_right_arity_test() ->
    Src = "module Sum\n\n"
          "public int Total(int count, int | float amount)\n\n"
          "Total(c, a) -> c * a\n",
    [D | _] = errors(Src),
    Prose = prose(D),
    ?assert(string:find(Prose, "Total(count, int amount)") =/= nomatch),
    ?assert(string:find(Prose, "Total(count, float amount)") =/= nomatch).

%% The union comes from a local binding; no parameter head can dispatch it.
the_advice_names_the_site_when_no_parameter_carries_the_union_test() ->
    Src = "module Bound\n\n"
          "public int Go(int | float x)\n\n"
          "Go(int n)   -> n\n"
          "Go(float f) -> Twice(f)\n\n"
          "private int Twice(int | float y)\n\n"
          "Twice(y) -> 2\n\n"
          "public int Body(int n)\n\n"
          "Body(n) -> var a = Pick(n)\n"
          "           a * 100\n\n"
          "private int | float Pick(int n)\n\n"
          "Pick(0) -> 0\n"
          "Pick(_) -> 1.5\n",
    [D | _] = [X || X <- errors(Src),
                    element(1, element(4, X)) =:= numeric_union_operand],
    Prose = prose(D),
    ?assert(string:find(Prose, "where the value enters the function") =/= nomatch),
    %% No fabricated clause head accompanies the advice.
    ?assertEqual(nomatch, string:find(Prose, "-> ...")).

every_operator_but_the_boolean_pair_refuses_test() ->
    Refused = fun(Op) ->
        Src = "module Ops\n\n"
              "public int Go(int | float x)\n\n"
              "Go(a) -> a " ++ Op ++ " 2\n",
        case errors(Src) of
            [D | _] -> element(1, element(4, D));
            []      -> none
        end
    end,
    [?assertEqual({Op, numeric_union_operand}, {Op, Refused(Op)})
     || Op <- ["+", "-", "*", "/", "%"]],
    %% Exact equality makes an int unequal to a float of the same value.
    Cmp = fun(Op) ->
        Src = "module Cmps\n\n"
              "public bool Go(int | float x)\n\n"
              "Go(a) -> a " ++ Op ++ " 2\n",
        case errors(Src) of
            [D | _] -> element(1, element(4, D));
            []      -> none
        end
    end,
    [?assertEqual({Op, numeric_union_operand}, {Op, Cmp(Op)})
     || Op <- ["<", ">", "<=", ">=", "==", "!="]],
    %% `and`/`or` are outside the operator set: the same set as the
    %% `{int, float}` pair's refusal, so the two stay in step.
    Bool = "module Bools\n\n"
           "public bool Go(int | float x, bool b)\n\n"
           "Go(a, b) -> b and b\n",
    ?assertEqual([], [D || D <- diags(Bool),
                           element(1, element(4, D)) =:= numeric_union_operand]).

%% A union containing a nonnumeric part is outside this refusal's scope.
a_union_with_a_non_numeric_part_is_unmoved_test() ->
    Src = "module Wide\n\n"
          "public int Go(int | float | :none x)\n\n"
          "Go(a) -> a * 100\n",
    ?assertEqual([], [D || D <- diags(Src),
                           element(1, element(4, D)) =:= numeric_union_operand]).

%% A single float beside an int literal still needs literal-spelling advice.
the_existing_mixed_pair_keeps_its_own_advice_test() ->
    Src = "module One\n\n"
          "public float Go(float x)\n\n"
          "Go(a) -> a * 2\n",
    [D | _] = errors(Src),
    ?assertEqual(mixed_operands, element(1, element(4, D))),
    ?assert(string:find(prose(D), "2.0") =/= nomatch).

%%% --- Helpers ---

prose(D) ->
    Desc = bs_diag:descriptor("m.bs", D),
    unicode:characters_to_list(bs_diag:format(Desc)).

%% Unlike errors/1, this helper also accepts a successful check.
diags(Src) ->
    case check_only(Src) of
        {error, Ds} -> [D || D <- Ds, element(1, D) =:= error];
        _           -> []
    end.

%% Type-prefix refusals raise and stop checking the file.
refusal(Src) ->
    try check_only(Src) of
        Other -> erlang:error({expected_a_refusal_but_got, Other})
    catch
        error:{expected_a_refusal_but_got, _} = E -> erlang:error(E);
        error:Reason                              -> Reason
    end.
