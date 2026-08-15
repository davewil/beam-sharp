-module(generics_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1]).

-define(OUT, "/tmp/bsc_eunit").

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
    "atom Grade(Weighed w)\n"
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
          "atom Grade(Weighed w)\n"
          "Grade((:error, e)) -> e\n",
    ?assertMatch([{error, _, 'Grade', {inexhaustive, _}}], errors(Src)).

%% F6.2 — ticket 26 §4 says there are no absent fields, and `option<T>` is what
%% that costs a field. Until F6 the compiler could not let anyone obey the rule.
an_option_field_is_declarable_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Notes: option<int> }\n"
          "atom Describe(Order o)\n"
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
          "atom Take(option<int> o)\n"
          "Take(:nothing) -> :none\n"
          "Take(n)        -> :some\n"
          "atom Hand(Spelled s)\n"
          "Hand(s) -> Take(s)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.4 — a user's own parametric alias. PascalCase, because a user type is
%% PascalCase and lowercase is the prelude's namespace.
a_user_parametric_alias_runs_test() ->
    Src = "module Pairs\n"
          "type Pair<T> = (T, T)\n"
          "int Sum(Pair<int> p)\n"
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
          "int Depth(list<list<int>> xss)\n"
          "Depth([])        -> 0\n"
          "Depth([xs, ..r]) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.6 — a bracket the compiler KNOWS at the wrong arity is a different mistake
%% from one it does not know, and it needs a different edit to fix.
a_bracket_at_the_wrong_arity_says_so_test() ->
    ?assertError({generic_arity, result, 2, 1},
                 check_only("module E\ntype B = result<int>\n"
                            "atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, option, 1, 2},
                 check_only("module E\ntype B = option<int, atom>\n"
                            "atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, list, 1, 2},
                 check_only("module E\natom F(list<int, atom> xs)\nF(xs) -> :ok\n")).

%% A parametric name written without its bracket. `option` alone is not an
%% unknown type — it is a known one missing an argument, and the lowercase
%% (prelude) and PascalCase (user) halves reach that answer down different
%% resolver arms, so both are asserted.
a_parametric_name_without_its_bracket_says_so_test() ->
    ?assertError({needs_type_args, option, 1},
                 check_only("module E\natom F(option o)\nF(o) -> :ok\n")),
    ?assertError({needs_type_args, 'Pair', 1},
                 check_only("module E\ntype Pair<T> = (T, T)\n"
                            "atom F(Pair p)\nF(p) -> :ok\n")).

%% ...and its mirror: a bracket on a name that takes none.
a_bracket_on_a_ground_type_says_so_test() ->
    ?assertError({not_parametric, 'Plain'},
                 check_only("module E\ntype Plain = int\n"
                            "atom F(Plain<int> p)\nF(p) -> :ok\n")),
    ?assertError({unknown_generic, stack},
                 check_only("module E\natom F(stack<int> s)\nF(s) -> :ok\n")).

%% F6.7 — a type variable and a user type are the SAME token class (ticket 27
%% §4 forced declaration for exactly that reason), so nothing but the parameter
%% list tells them apart. `U` is therefore a type name, and there isn't one.
an_undeclared_variable_in_an_alias_body_is_caught_test() ->
    ?assertError({unknown_type, 'U'},
                 check_only("module E\ntype Wrong<T> = (T, U)\n"
                            "atom F(Wrong<int> w)\nF(w) -> :ok\n")).

%% F6.8 — the control for this one is not a red test, it is a HANG. Measured on
%% master before F6: `type A = B` / `type B = A` spins until killed, because
%% `type_env/1` resolved a reference by resolving whatever it found and its own
%% comment said the slice had no recursive aliases. A parameter is what makes a
%% recursive alias the natural thing to write, so the guard ships with F6.
%%
%% It REFUSES rather than implements: ticket 09 decided recursion is
%% equirecursive and contractive, and the algebra cannot hold one — the list
%% part is a pair of flags and a tuple is a finite product.
a_cyclic_alias_is_an_error_and_not_a_hang_test() ->
    ?assertError({cyclic_type, 'A'},
                 check_only("module E\ntype A = B\ntype B = A\n"
                            "atom F(A a)\nF(a) -> :ok\n")),
    ?assertError({cyclic_type, 'Tree'},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "atom F(Tree<int> t)\nF(t) -> :ok\n")).

%% ...and the same guard must not reject a name used twice as SIBLINGS. A
%% repeated application is not a cycle, and a chain that terminates is not one
%% either — the guard tracks the resolution path, not the set of names seen.
a_repeated_alias_is_not_a_cycle_test() ->
    Src = "module Twice\n"
          "type Pair<T> = (T, T)\n"
          "type Both = (Pair<int>, Pair<atom>)\n"
          "type Deep = Pair<Pair<int>>\n"
          "atom F(Both b, Deep d)\n"
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
                       "bool Both(int a, int b, int c, int d)\n"
                       "Both(a, b, c, d) -> a < b && c > d\n", 'Cmp'),
    ?assertEqual(true,  M:'Both'(1, 2, 5, 3)),
    ?assertEqual(false, M:'Both'(1, 2, 3, 5)).

%% Ticket 08's own example, which ticket 28 §3 ran through four patched grammar
%% variants. Run here against the real one, now that the real one has brackets.
a_guard_with_comparisons_still_parses_test() ->
    Src = "module G\n"
          "int Total(int x)\n"
          "Total(x) -> x\n"
          "atom Cmp((int, int) p)\n"
          "Cmp((x, y)) when x < y && Total(x) > 0 -> :yes\n"
          "Cmp(p)                                 -> :no\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.10 — the expansion is already ground, so ticket 13 §6 has nothing to widen
%% and the spec is exact. This is also why 27 §6's finding (a polymorphic -spec
%% is inert under Dialyzer) does not arrive with F6: it emits no polymorphic
%% spec, because it builds no polymorphic function.
the_emitted_spec_is_the_expanded_ground_type_test() ->
    {ok, _} = compile("module Opt\n"
                      "option<int> Keep(option<int> o)\n"
                      "Keep(o) -> o\n"),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Opt.beam", [abstract_code]),
    [Spec] = [S || S = {attribute, _, spec, _} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "integer()") =/= nomatch),
    ?assert(string:find(Printed, "nothing") =/= nomatch),
    %% Nothing parametric survives into what is published.
    ?assertEqual(nomatch, string:find(Printed, "option")).

