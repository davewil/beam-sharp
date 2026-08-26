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

%% Ticket 01's finding, now produced by a compiler rather than by hand.
four_clauses_become_four_clause_heads_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    [{function, _, 'Classify', 1, Clauses}] =
        [F || F = {function, _, _, _, _} <- Forms],
    ?assertEqual(4, length(Clauses)).

%% Ticket 13: a -spec is emitted for every function whose type is known.
spec_is_emitted_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    Specs = [F || F = {attribute, _, spec, _} <- Forms],
    ?assertMatch([_], Specs),
    Printed = lists:flatten(erl_pp:attribute(hd(Specs))),
    %% Precise, not widened to term(): the union survives into the emitted spec.
    ?assert(string:find(Printed, "{ok, integer()}") =/= nomatch),
    ?assert(string:find(Printed, "{error, atom()}") =/= nomatch).

%% Ticket 12: the failure arm is retained, so a foreign term crashes honestly
%% rather than returning a wrong answer. Ticket 13 found `erlc` inserts it on
%% this target and it cannot be suppressed, so this asserts the platform's
%% behaviour is what the decision assumed.
foreign_term_crashes_rather_than_lying_test() ->
    M = build_and_load(showcase_src(), 'Readings'),
    ?assertError(function_clause, M:'Classify'(not_a_reading)).

%%% ---------------------------------------------------------------------------
%%% Exhaustiveness — ticket 04's mechanism
%%% ---------------------------------------------------------------------------

inexhaustive_is_rejected_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _}}], Diags).

%% The residual IS the missing case — not a count, not "some value".
residual_names_the_missing_case_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("((:ok, int <= 0))", bs_types:to_string(Residual)).

unreachable_clause_is_warned_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n))            -> :positive\n"
          "Classify((:ok, n)) when n > 0 -> :zero\n"
          "Classify((:error, e))         -> :unknown\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Classify', {unreachable_clause, 2}}], Diags).
