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

%% THE CONTROL for the three tests below, and the reason this one is left
%% untouched: clause 2 IS covered by clause 1, so "matched by an earlier clause"
%% is the true statement about it. ENG-259 splits the tag; it must not move this.
unreachable_clause_is_warned_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:ok, n))            -> :positive\n"
          "Classify((:ok, n)) when n > 0 -> :zero\n"
          "Classify((:error, e))         -> :unknown\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Classify', {unreachable_clause, 2}}], Diags).

%%% --- ENG-259: three faults shared one diagnostic ----------------------------
%%%
%%% `is_none(intersect(Possible, Residual))` is true of a clause an earlier
%%% clause covers, of a clause whose pattern is not a member of the declared
%%% input, AND of a clause whose guard admits nothing. Only the first is
%%% "matched by an earlier clause", and that was the prose all three got.
%%%
%%% The measurement that matters is the SOLE-CLAUSE case: there is no earlier
%%% clause at all, so the message cannot be read as loosely true.

vacuous_clause_is_not_reported_as_shadowed_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'F', {vacuous_clause, 1, _}},
                  {error,   _, 'F', {inexhaustive, _}}], Diags).

%% The domain is what the author is missing — `(:some, x)` is what a reader
%% arriving from C#, Rust or F# writes for an untagged `option<T>` — so the
%% descriptor carries it rather than leaving the accompanying residual to hint.
vacuous_clause_carries_the_domain_it_is_not_a_member_of_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n",
    {error, [{warning, _, 'F', {vacuous_clause, 1, Domain}} | _]} = check_only(Src),
    ?assertEqual("(:a | :b)", bs_types:to_string(Domain)).

%% A vacuous clause standing in front of clauses that DO cover the domain is the
%% case that pins severity. This program compiles today, so the split must not
%% turn it into a rejection — and the two covering clauses must still count, or
%% the fix has broken exhaustiveness while fixing prose.
vacuous_clause_does_not_make_a_covered_function_inexhaustive_test() ->
    Src = "module R\n"
          "type K = :a | :b\n"
          "public int F(K k)\n"
          "F((:some, x)) -> 0\n"
          "F(:a)         -> 1\n"
          "F(:b)         -> 2\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'F', {vacuous_clause, 1, _}}], Diags).

%% The THIRD fault, which ENG-259 did not name and the probe found: the pattern
%% is a perfectly good member of `int`; it is the guard that admits nothing. So
%% this cannot share `vacuous_clause`'s prose either — that message names a type
%% the pattern is not in, and here the pattern IS in it.
unsatisfiable_guard_is_its_own_diagnostic_test() ->
    Src = "module R\n"
          "public int G(int n)\n"
          "G(n) when n > 5 and n < 3 -> 0\n"
          "G(n)                      -> 1\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'G', {unsatisfiable_guard, 1}}], Diags).

%% THE CONTROL THAT STOPS THE NEW TAG CRYING WOLF. `n > m` compares two
%% variables, which `comparison/1` answers `unknown` for — and an untranslatable
%% guard returns `Possible` UNREDUCED (`{none(), Ty}`), precisely so the checker
%% never claims a clause matches nothing merely because it could not read the
%% guard. If `unsatisfiable_guard` ever fires here it is reporting its own
%% ignorance as the author's mistake.
an_untranslatable_guard_is_not_called_unsatisfiable_test() ->
    Src = "module R\n"
          "public int G(int n, int m)\n"
          "G(n, m) when n > m -> 0\n"
          "G(n, m)            -> 1\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).
