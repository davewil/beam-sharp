%%% Scenarios: compiler/features/F39-parse-atom.md
%%% F39 — ParseAtom<T> parses a member of a finite atom union.
-module(parse_atom_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F39.1 — a finite atom union parses member names.
%%% ---------------------------------------------------------------------------

outcome_src() ->
    "module PaOutcome\n"
    "type Outcome = :ok | :error\n"
    "type Parsed = :ok | :error | :nothing\n"
    "public Parsed Parse(string s)\n"
    "Parse(s) -> ParseAtom<Outcome>(s)\n".

a_member_name_parses_to_that_member_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(ok, M:'Parse'(<<"ok">>)),
    ?assertEqual(error, M:'Parse'(<<"error">>)).

a_name_outside_the_union_is_nothing_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(nothing, M:'Parse'(<<"zzz">>)),
    ?assertEqual(nothing, M:'Parse'(<<"">>)).

%% Matching uses the whole binary, so both prefixes and extensions miss.
a_prefix_of_a_member_is_not_that_member_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(nothing, M:'Parse'(<<"o">>)),
    ?assertEqual(nothing, M:'Parse'(<<"okay">>)).

%%% ---------------------------------------------------------------------------
%%% F39.2 — it does not touch the atom table
%%% ---------------------------------------------------------------------------

%% A return value cannot show atom creation. Measure the delta because
%% eunit itself interns atoms during the suite.
parsing_an_unknown_name_does_not_mint_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    Before = erlang:system_info(atom_count),
    ?assertEqual(nothing, M:'Parse'(<<"zzz_never_seen_before_xyz">>)),
    After = erlang:system_info(atom_count),
    ?assertEqual(Before, After),
    %% The lookup also confirms that the input name is absent from the table.
    ?assertError(badarg,
                 binary_to_existing_atom(<<"zzz_never_seen_before_xyz">>, utf8)).

%% Reading the atom chunk checks that members reach the emitted artifact.
the_members_reach_the_atom_chunk_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    {ok, {_, [{atoms, As}]}} = beam_lib:chunks(code:which(M), [atoms]),
    Names = [N || {_, N} <- As],
    ?assert(lists:member(ok, Names)),
    ?assert(lists:member(error, Names)),
    ?assert(lists:member(nothing, Names)).

%%% F39.3 — parsing uses the resolved members and their printed names.

a_union_of_unions_parses_every_member_test() ->
    Src = "module PaNested\n"
          "type Warm = :red | :orange\n"
          "type Colour = Warm | :blue\n"
          "type Parsed = :red | :orange | :blue | :nothing\n"
          "public Parsed Go(string s)\n"
          "Go(s) -> ParseAtom<Colour>(s)\n",
    M = build_and_load(Src, 'PaNested'),
    ?assertEqual(red, M:'Go'(<<"red">>)),
    ?assertEqual(orange, M:'Go'(<<"orange">>)),
    ?assertEqual(blue, M:'Go'(<<"blue">>)),
    ?assertEqual(nothing, M:'Go'(<<"green">>)).

%% Quotes belong to source spelling, not the bytes of the printed name.
a_quoted_member_parses_on_its_printed_name_test() ->
    Src = "module PaQuoted\n"
          "type Tag = :'Sw.Invoice' | :plain\n"
          "type Parsed = :'Sw.Invoice' | :plain | :nothing\n"
          "public Parsed Go(string s)\n"
          "Go(s) -> ParseAtom<Tag>(s)\n",
    M = build_and_load(Src, 'PaQuoted'),
    ?assertEqual('Sw.Invoice', M:'Go'(<<"Sw.Invoice">>)),
    ?assertEqual(plain, M:'Go'(<<"plain">>)),
    ?assertEqual(nothing, M:'Go'(<<"Sw">>)).

a_single_member_union_still_has_a_residual_test() ->
    Src = "module PaOne\n"
          "type Only = :solo\n"
          "type Parsed = :solo | :nothing\n"
          "public Parsed Go(string s)\n"
          "Go(s) -> ParseAtom<Only>(s)\n",
    M = build_and_load(Src, 'PaOne'),
    ?assertEqual(solo, M:'Go'(<<"solo">>)),
    ?assertEqual(nothing, M:'Go'(<<"other">>)).

%%% ---------------------------------------------------------------------------
%%% F39.4 — `T` must be a finite atom union
%%% ---------------------------------------------------------------------------

a_cofinite_type_argument_is_refused_test() ->
    Src = "module PaCofinite\n"
          "public atom Go(string s)\n"
          "Go(s) -> ParseAtom<atom>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

a_non_atom_type_argument_is_refused_test() ->
    Src = "module PaInt\n"
          "public int Go(string s)\n"
          "Go(s) -> ParseAtom<int>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%% A finite atom part alone is insufficient: accepting it would drop int.
a_union_mixing_atoms_with_another_kind_is_refused_test() ->
    Src = "module PaMixed\n"
          "type Odd = :a | int\n"
          "public Odd Go(string s)\n"
          "Go(s) -> ParseAtom<Odd>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

a_term_type_argument_is_refused_test() ->
    Src = "module PaTerm\n"
          "public term Go(string s)\n"
          "Go(s) -> ParseAtom<term>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F39.5 — parsing requires one type and returns a residual.
%%% ---------------------------------------------------------------------------

two_type_arguments_are_refused_test() ->
    Src = "module PaTwoTypes\n"
          "type Outcome = :ok | :error\n"
          "public atom Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome, int>(s)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ParseAtom', 2, 1}}],
                 errors(Src)).

%% Match the return-type diagnostic to rule out unrelated refusals.
a_return_type_without_nothing_is_refused_test() ->
    Src = "module PaNarrow\n"
          "type Outcome = :ok | :error\n"
          "public Outcome Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome>(s)\n",
    ?assertMatch([{error, _, 'Go', {return_not_declared, _, _}}], errors(Src)).

the_correction_offers_the_residual_test() ->
    Src = "module PaNarrow2\n"
          "type Outcome = :ok | :error\n"
          "public Outcome Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome>(s)\n",
    [{error, _, 'Go', {return_not_declared, Undeclared, Corrected}}] = errors(Src),
    ?assertEqual(<<":nothing">>, iolist_to_binary(bs_types:to_string(Undeclared))),
    ?assertNotEqual(none, Corrected).

%%% ---------------------------------------------------------------------------
%%% F39.7 — the argument must be binary.
%%% ---------------------------------------------------------------------------

%% Non-binary inputs must be refused, rather than treated as unmatched names.
a_term_argument_is_refused_test() ->
    Src = "module PaArgTerm\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(term t)\n"
          "Go(t) -> ParseAtom<Outcome>(t)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_arg, _}}], errors(Src)).

an_int_argument_is_refused_test() ->
    Src = "module PaArgInt\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(int n)\n"
          "Go(n) -> ParseAtom<Outcome>(n)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_arg, _}}], errors(Src)).

%% Binary is accepted too: matching does not require UTF-8 validation.
a_binary_argument_is_accepted_test() ->
    Src = "module PaArgBin\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(binary b)\n"
          "Go(b) -> ParseAtom<Outcome>(b)\n",
    M = build_and_load(Src, 'PaArgBin'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)).

%%% ---------------------------------------------------------------------------
%%% F39.6 — a pipe supplies the string argument.
%%% ---------------------------------------------------------------------------

%% The pipeline supplies the value argument omitted inside the parentheses.
the_pipe_form_parses_the_piped_string_test() ->
    Src = "module PaPipe\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(string s)\n"
          "Go(s) -> s |> ParseAtom<Outcome>()\n",
    M = build_and_load(Src, 'PaPipe'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)),
    ?assertEqual(nothing, M:'Go'(<<"nope">>)).
