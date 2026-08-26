-module(generics_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F6 — angle brackets and parametric types
%%%
%%% Ticket 27 §(a) and §(b) only. §(c) — polymorphic function SIGNATURES — is
%%% not built, and the ticket's own "the costs are asymmetric and they do not
%%% chain" is why that is a cut rather than a shortfall. Everything below is
%%% substitution with ground arguments: the variable is gone before `bs_types`
%%% sees anything, so no test here reaches into the algebra for a new node,
%%% because there isn't one.
%%% ---------------------------------------------------------------------------

parcel_src() ->
    "module Parcel\n"
    "type Weighed = result<int, atom>\n"
    "public atom Grade(Weighed w)\n"
    "Grade((:error, e))     -> e\n"
    "Grade(n) when n > 1000 -> :heavy\n"
    "Grade(n)               -> :light\n".

%% F6.1 — a two-argument bracket parses, resolves, and dispatches. Both arms
%% run, which is what says `result<int, atom>` became `int | (:error, atom)`
%% rather than a type the checker merely accepted.
a_two_argument_bracket_dispatches_test() ->
    M = build_and_load(parcel_src(), 'Parcel'),
    ?assertEqual(heavy,   M:'Grade'(1500)),
    ?assertEqual(light,   M:'Grade'(3)),
    ?assertEqual(timeout, M:'Grade'({error, timeout})).

%% F6.1's control. Drop the arms that cover the payload and the residual is the
%% payload — so the expansion reaches the exhaustiveness check, and the residual
%% printer needs nothing new to talk about a bracket.
%%
%% Note which arm is dropped: a bare variable covers the whole union, so
%% deleting the `(:error, e)` clause proves nothing. The check is real only
%% against the clause that does not.
the_residual_of_a_bracket_is_its_payload_test() ->
    Src = "module Parcel\n"
          "type Weighed = result<int, atom>\n"
          "public atom Grade(Weighed w)\n"
          "Grade((:error, e)) -> e\n",
    ?assertMatch([{error, _, 'Grade', {inexhaustive, _}}], errors(Src)).

%% F6.2 — ticket 26 §4 says there are no absent fields, and `option<T>` is what
%% that costs a field. Until F6 the compiler could not let anyone obey the rule.
an_option_field_is_declarable_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Notes: option<int> }\n"
          "public atom Describe(Order o)\n"
          "Describe({ Notes: :nothing }) -> :bare\n"
          "Describe(o)                   -> :annotated\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.3 — THE scenario that distinguishes expansion from a second constructor.
%% If `option<int>` were a node the algebra knew about, these two would be
%% different types and the call site would reject. Ticket 27 §(b): the variable
%% is gone before the algebra sees anything, so they are one type.
an_option_and_its_spelling_are_one_type_test() ->
    Src = "module Same\n"
          "type Spelled = int | :nothing\n"
          "public atom Take(option<int> o)\n"
          "Take(:nothing) -> :none\n"
          "Take(n)        -> :some\n"
          "public atom Hand(Spelled s)\n"
          "Hand(s) -> Take(s)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.4 — a user's own parametric alias. PascalCase, because a user type is
%% PascalCase and lowercase is the prelude's namespace.
a_user_parametric_alias_runs_test() ->
    Src = "module Pairs\n"
          "type Pair<T> = (T, T)\n"
          "public int Sum(Pair<int> p)\n"
          "Sum((a, b)) -> a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

%% F6.5 — nesting. Ticket 28 §4 found `>>` is not a token, so this parses; and
%% it recorded the finding as OWED when binaries land, because ticket 20's
%% `<<_:M, _:_*N>>` needs `>>` as a delimiter and meets it at these two
%% characters. Pinned here so F8 trips an existing test instead of discovering
%% the collision.
nested_generics_parse_because_there_is_no_shift_operator_test() ->
    Src = "module Nest\n"
          "public int Depth(list<list<int>> xss)\n"
          "Depth([])        -> 0\n"
          "Depth([xs, ..r]) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.6 — a bracket the compiler KNOWS at the wrong arity is a different mistake
%% from one it does not know, and it needs a different edit to fix.
a_bracket_at_the_wrong_arity_says_so_test() ->
    ?assertError({generic_arity, result, 2, 1},
                 check_only("module E\ntype B = result<int>\n"
                            "public atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, option, 1, 2},
                 check_only("module E\ntype B = option<int, atom>\n"
                            "public atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, list, 1, 2},
                 check_only("module E\npublic atom F(list<int, atom> xs)\nF(xs) -> :ok\n")).

%% A parametric name written without its bracket. `option` alone is not an
%% unknown type — it is a known one missing an argument, and the lowercase
%% (prelude) and PascalCase (user) halves reach that answer down different
%% resolver arms, so both are asserted.
a_parametric_name_without_its_bracket_says_so_test() ->
    ?assertError({needs_type_args, option, 1},
                 check_only("module E\npublic atom F(option o)\nF(o) -> :ok\n")),
    ?assertError({needs_type_args, 'Pair', 1},
                 check_only("module E\ntype Pair<T> = (T, T)\n"
                            "public atom F(Pair p)\nF(p) -> :ok\n")).

%% ...and its mirror: a bracket on a name that takes none.
a_bracket_on_a_ground_type_says_so_test() ->
    ?assertError({not_parametric, 'Plain'},
                 check_only("module E\ntype Plain = int\n"
                            "public atom F(Plain<int> p)\nF(p) -> :ok\n")),
    ?assertError({unknown_generic, stack},
                 check_only("module E\npublic atom F(stack<int> s)\nF(s) -> :ok\n")).

%% F6.7 — a type variable and a user type are the SAME token class (ticket 27
%% §4 forced declaration for exactly that reason), so nothing but the parameter
%% list tells them apart. `U` is therefore a type name, and there isn't one.
an_undeclared_variable_in_an_alias_body_is_caught_test() ->
    ?assertError({unknown_type, 'U'},
                 check_only("module E\ntype Wrong<T> = (T, U)\n"
                            "public atom F(Wrong<int> w)\nF(w) -> :ok\n")).

%% F6.8 — the control for this one is not a red test, it is a HANG. Measured on
%% master before F6: `type A = B` / `type B = A` spins until killed, because
%% `type_env/1` resolved a reference by resolving whatever it found and its own
%% comment said the slice had no recursive aliases. A parameter is what makes a
%% recursive alias the natural thing to write, so the guard ships with F6.
%%
%% It REFUSES rather than implements: ticket 09 decided recursion is
%% equirecursive and contractive, and the algebra cannot hold one — the list
%% part is a pair of flags and a tuple is a finite product.
%%
%% THE REFUSAL IS NOW SPLIT IN TWO, and this test changed with it. It used to
%% assert `cyclic_type` for BOTH cases below, which was the conflation: `A = B` /
%% `B = A` is meaningless and always will be, while `Tree<T> = (T, list<Tree<T>>)`
%% is contractive — ticket 09 §3's own well-formedness rule — and denotes a
%% perfectly good regular tree nobody has built. Asserting one term for both is
%% what let the compiler tell an author their mistake was a missing feature.
a_non_contractive_alias_is_a_permanent_error_test() ->
    %% Through an alias chain: no constructor anywhere on the path.
    ?assertError({cyclic_type, 'A'},
                 check_only("module E\ntype A = B\ntype B = A\n"
                            "public atom F(A a)\nF(a) -> :ok\n")),
    %% And through a UNION, which is the canonical case and the one that proves
    %% the marker is not simply "did we walk anywhere". A union is a Boolean
    %% connective, not a constructor, so it must not make `X` contractive.
    ?assertError({cyclic_type, 'X'},
                 check_only("module E\ntype X = X | int\n"
                            "public atom F(X x)\nF(x) -> :ok\n")).

a_contractive_alias_is_an_unbuilt_feature_test() ->
    %% Through a tuple, and through a `list<T>` inside it.
    ?assertError({recursive_type, 'Tree'},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public atom F(Tree<int> t)\nF(t) -> :ok\n")),
    %% Through a bare `list<T>`, with no tuple involved at all — the list part
    %% is algebra-primitive and resolved in its own clause, so it is a separate
    %% path to the same conclusion.
    ?assertError({recursive_type, 'Nest'},
                 check_only("module E\ntype Nest = :leaf | list<Nest>\n"
                            "public atom F(Nest n)\nF(n) -> :ok\n")),
    %% And through a record field, which resolves as a closed map.
    ?assertError({recursive_type, 'Node'},
                 check_only("module E\nrecord Node { Kids: list<Node> }\n"
                            "public atom F(Node n)\nF(n) -> :ok\n")).

%% The split only matters if the AUTHOR is told two different things, which a
%% diagnostic term does not prove — so it is asserted where they read it. The
%% old message said a recursive type "has no representation in the checker's
%% algebra YET", and the whole defect was that `type X = X | int` was told to
%% wait for a feature that cannot exist.
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
            with_src("in.bs", Good,
                     fun(P, R) ->
                             O = run_cli("--src-root " ++ R ++ " " ++ P),
                             ?assert(string:find(O, "not built yet") =/= nomatch),
                             ?assert(string:find(O, "gap in this") =/= nomatch),
                             ?assertEqual(nomatch, string:find(O, "not a missing feature"))
                     end)
    end.

%% ...and the same guard must not reject a name used twice as SIBLINGS. A
%% repeated application is not a cycle, and a chain that terminates is not one
%% either — the guard tracks the resolution path, not the set of names seen.
a_repeated_alias_is_not_a_cycle_test() ->
    Src = "module Twice\n"
          "type Pair<T> = (T, T)\n"
          "type Both = (Pair<int>, Pair<atom>)\n"
          "type Deep = Pair<Pair<int>>\n"
          "public atom F(Both b, Deep d)\n"
          "F(b, d) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.9 — F6 puts `<` and `>` around a comma-separated list in TYPE position for
%% the first time. This is the scenario that says the expression grammar did not
%% learn it: ticket 28's `F(a < b, c > d)` is two comparisons, and ticket 08's
%% guard shape still parses.
%%
%% The conflict count is NOT the check. 28a's own header records that yecc
%% resolves shift/reduce conflicts silently through the precedence table — every
%% one of its four variants reported zero conflicts, including the variant that
%% read the ambiguous case wrong. So this asserts the parse.
angle_brackets_did_not_reach_value_position_test() ->
    M = build_and_load("module Cmp\n"
                       "public bool Both(int a, int b, int c, int d)\n"
                       "Both(a, b, c, d) -> a < b and c > d\n", 'Cmp'),
    ?assertEqual(true,  M:'Both'(1, 2, 5, 3)),
    ?assertEqual(false, M:'Both'(1, 2, 3, 5)).

%% Ticket 08's own example, which ticket 28 §3 ran through four patched grammar
%% variants. Run here against the real one, now that the real one has brackets.
a_guard_with_comparisons_still_parses_test() ->
    Src = "module G\n"
          "public int Total(int x)\n"
          "Total(x) -> x\n"
          "public atom Cmp((int, int) p)\n"
          "Cmp((x, y)) when x < y and Total(x) > 0 -> :yes\n"
          "Cmp(p)                                 -> :no\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.10 — the expansion is already ground, so ticket 13 §6 has nothing to widen
%% and the spec is exact. This is also why 27 §6's finding (a polymorphic -spec
%% is inert under Dialyzer) does not arrive with F6: it emits no polymorphic
%% spec, because it builds no polymorphic function.
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
    %% Nothing parametric survives into what is published.
    ?assertEqual(nomatch, string:find(Printed, "option")).
