-module(heads_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1,
                          showcase_src/0]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% The showcase: N clauses in, N native clause heads out
%%% ---------------------------------------------------------------------------

showcase_runs_test() ->
    M = build_and_load(showcase_src(), 'Readings'),
    ?assertEqual(positive, M:'Classify'({ok, 5})),
    ?assertEqual(zero,     M:'Classify'({ok, 0})),
    ?assertEqual(negative, M:'Classify'({ok, -3})),
    ?assertEqual(unknown,  M:'Classify'({error, timeout})).

four_clauses_become_four_clause_heads_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    %% The set permits type metadata but rejects extra generated helpers.
    ?assertEqual([{'Classify', 1}, {'bs@type_atoms', 0}],
                 lists:sort([{N, A} || {function, _, N, A, _} <- Forms])),
    [{function, _, 'Classify', 1, Clauses}] =
        [F || F = {function, _, 'Classify', 1, _} <- Forms],
    ?assertEqual(4, length(Clauses)).

spec_is_emitted_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    Specs = [F || F = {attribute, _, spec, _} <- Forms],
    ?assertMatch([_], Specs),
    Printed = lists:flatten(erl_pp:attribute(hd(Specs))),
    ?assert(string:find(Printed, "{ok, integer()}") =/= nomatch),
    ?assert(string:find(Printed, "{error, atom()}") =/= nomatch).

%% erlc retains a failure arm for values outside the declared input type.
foreign_term_crashes_rather_than_lying_test() ->
    M = build_and_load(showcase_src(), 'Readings'),
    ?assertError(function_clause, M:'Classify'(not_a_reading)).

%%% ---------------------------------------------------------------------------
%%% Exhaustiveness
%%% ---------------------------------------------------------------------------

inexhaustive_is_rejected_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _, _}}], Diags).

residual_names_the_missing_case_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, [{error, _, _, {inexhaustive, Residual, _}}]} = check_only(Src),
    ?assertEqual("((:ok, int <= 0))", bs_types:to_string(Residual)).

%% Control: the earlier clause covers this clause's entire domain.
unreachable_clause_is_warned_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n))            -> :positive\n"
          "Classify((:ok, n)) when n > 0 -> :zero\n"
          "Classify((:error, e))         -> :unknown\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Classify', {unreachable_clause, 2}}], Diags).

%%% --- Clause diagnostics ----------------------------------------------------
%%% A sole clause cannot be shadowed by an earlier clause.

vacuous_clause_is_not_reported_as_shadowed_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'F', {vacuous_clause, 1, _}},
                  {error,   _, 'F', {inexhaustive, _, _}}], Diags).

vacuous_clause_carries_the_domain_it_is_not_a_member_of_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n",
    {error, [{warning, _, 'F', {vacuous_clause, 1, Domain}} | _]} = check_only(Src),
    ?assertEqual("(:a | :b)", bs_types:to_string(Domain)).

%% A vacuous clause only warns when the other clauses cover the domain.
vacuous_clause_does_not_make_a_covered_function_inexhaustive_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n"
          "F(:a)         -> 1\n"
          "F(:b)         -> 2\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'F', {vacuous_clause, 1, _}}], Diags).

%% The pattern belongs to `int`; only the guard makes it impossible.
unsatisfiable_guard_is_its_own_diagnostic_test() ->
    Src = "module R\n"
          "public int G(int n)\n"
          "G(n) when n > 5 and n < 3 -> 0\n"
          "G(n)                      -> 1\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'G', {unsatisfiable_guard, 1}}], Diags).

%% A comparison between variables is opaque, not unsatisfiable.
an_untranslatable_guard_is_not_called_unsatisfiable_test() ->
    Src = "module R\n"
          "public int G(int n, int m)\n"
          "G(n, m) when n > m -> 0\n"
          "G(n, m)            -> 1\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).
