%%% F39 — `ParseAtom<T>`, the type-directed atom parser.
%%%
%%% AT THE BOUNDARY, AND THE BOUNDARY HERE IS A RUNNING PROGRAM, the same
%%% standard `validate_as_tests` sets for the sibling obligation: what
%%% `ParseAtom<T>` MEANS is what a compiled module returns when handed a
%%% string, so the behavioural tests compile source, load the `.beam` and call
%%% it. Nothing asserts on the shape of the emitted abstract format.
%%%
%%% THE REFUSALS CANNOT LIVE IN `examples/`, which is why they are half of this
%%% file: every example must compile, and a rule whose whole content is a
%%% rejection has nowhere else to be looked at.
%%%
%%% The one test that reads the artefact rather than calling it is
%%% `parsing_an_unknown_name_does_not_mint_test`. It is here because ticket
%%% 10 §4's claim is not "the answer is `:nothing`" — that is ordinary — but
%%% "the atom table is not touched", and no return value can show that.
-module(parse_atom_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F39.1 — the decided case: a finite atom union
%%% ---------------------------------------------------------------------------

outcome_src() ->
    "module PaOutcome\n"
    "type Outcome = :ok | :error\n"
    "type Parsed = :ok | :error | :nothing\n"
    "public Parsed Parse(string s)\n"
    "Parse(s) -> ParseAtom<Outcome>(s)\n".

%% A member's printed name comes back as that member. The atom returned is a
%% compile-time literal, not a value read out of the table.
a_member_name_parses_to_that_member_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(ok, M:'Parse'(<<"ok">>)),
    ?assertEqual(error, M:'Parse'(<<"error">>)).

%% The residual. Ticket 10 §4 spells the result `T | :nothing`, so a string
%% naming nothing in `T` is the honest weak answer rather than a crash.
a_name_outside_the_union_is_nothing_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(nothing, M:'Parse'(<<"zzz">>)),
    ?assertEqual(nothing, M:'Parse'(<<"">>)).

%% A near miss is not a match: the lowering is an equality on the whole
%% binary, not a prefix test. `Frame`'s `Method` needed the opposite and says
%% so, which is why this is worth pinning.
a_prefix_of_a_member_is_not_that_member_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    ?assertEqual(nothing, M:'Parse'(<<"o">>)),
    ?assertEqual(nothing, M:'Parse'(<<"okay">>)).

%%% ---------------------------------------------------------------------------
%%% F39.2 — it does not touch the atom table
%%% ---------------------------------------------------------------------------

%% Ticket 10 §4 (a). The lowering returns compile-time-known literals and
%% never calls `binary_to_existing_atom`, so a runtime-built string that names
%% no member cannot grow the table. This is the property the whole design
%% turns on — §4 chose the type-directed form over `ToExistingAtom` precisely
%% because it can promise this — and it is invisible in the return value.
%%
%% Measured as a delta rather than an absolute: eunit itself interns atoms
%% while the suite runs, so only the change across the call is meaningful.
parsing_an_unknown_name_does_not_mint_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    Before = erlang:system_info(atom_count),
    ?assertEqual(nothing, M:'Parse'(<<"zzz_never_seen_before_xyz">>)),
    After = erlang:system_info(atom_count),
    ?assertEqual(Before, After),
    %% and the name it was handed is still not an atom
    ?assertError(badarg,
                 binary_to_existing_atom(<<"zzz_never_seen_before_xyz">>, utf8)).

%% The cure, ticket 10 §4 (b): the members reach the atom chunk BECAUSE the
%% lowering puts them in value position. A union whose members appear only in
%% a type is §6.2's interning gap; one that is parsed is not.
the_members_reach_the_atom_chunk_test() ->
    M = build_and_load(outcome_src(), 'PaOutcome'),
    {ok, {_, [{atoms, As}]}} = beam_lib:chunks(code:which(M), [atoms]),
    Names = [N || {_, N} <- As],
    ?assert(lists:member(ok, Names)),
    ?assert(lists:member(error, Names)),
    ?assert(lists:member(nothing, Names)).

%%% ---------------------------------------------------------------------------
%%% F39.3 — the members are the NORMALISED ones
%%% ---------------------------------------------------------------------------

%% A union naming another union. The members to match on are the constituents
%% of the resolved type, not the names written at the declaration — the
%% distinction that `bs_types:constituents/1` exists for, and the one a
%% written-members implementation gets wrong only for this shape.
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

%% A quoted atom is matched on its PRINTED name, which is the text between the
%% quotes and not the source spelling with them.
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

%% A single-member union is still a union, and its residual still carries
%% `:nothing` — the degenerate case a "more than one member" guard would drop.
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

%% Ticket 10 §4, in as many words: "a cofinite `T` is an error at the call".
%% There is no finite member list to enumerate, so there is nothing to emit —
%% the refusal is about generation, not about taste.
a_cofinite_type_argument_is_refused_test() ->
    Src = "module PaCofinite\n"
          "public atom Go(string s)\n"
          "Go(s) -> ParseAtom<atom>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%% Not an atom union at all.
a_non_atom_type_argument_is_refused_test() ->
    Src = "module PaInt\n"
          "public int Go(string s)\n"
          "Go(s) -> ParseAtom<int>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%% THE MIXED CASE IS THE ONE THAT MATTERS. A union carrying atoms AND
%% something else has a finite atom part, so an implementation that reads only
%% the atom part accepts this and silently drops the `int` half — the value
%% `7` could never be produced by the parse, and the declared type would
%% promise it.
a_union_mixing_atoms_with_another_kind_is_refused_test() ->
    Src = "module PaMixed\n"
          "type Odd = :a | int\n"
          "public Odd Go(string s)\n"
          "Go(s) -> ParseAtom<Odd>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%% `term` contains every atom and everything else; it is the cofinite case
%% wearing the top type's name.
a_term_type_argument_is_refused_test() ->
    Src = "module PaTerm\n"
          "public term Go(string s)\n"
          "Go(s) -> ParseAtom<term>(s)\n",
    ?assertMatch([{error, _, 'Go', {parse_atom_not_finite, _}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F39.5 — the construct's shape
%%% ---------------------------------------------------------------------------

%% One type argument and one value, as for the sibling: "wrong arity" is about
%% the shape of the construct, not about a signature anyone wrote.
two_type_arguments_are_refused_test() ->
    Src = "module PaTwoTypes\n"
          "type Outcome = :ok | :error\n"
          "public atom Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome, int>(s)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ParseAtom', 2, 1}}],
                 errors(Src)).

%% The declared return must admit the residual. `:nothing` is a member of what
%% `ParseAtom` produces, so a signature promising only the union's members is
%% a narrowing the checker refuses.
%%
%% NAMING THE TAG MATTERS HERE. While `ParseAtom` was unbuilt this source was
%% refused too — as `obligation_unbuilt` — so a test asserting merely "some
%% error" passed before the feature existed and would have gone on passing if
%% the result type were wrong in any other way.
a_return_type_without_nothing_is_refused_test() ->
    Src = "module PaNarrow\n"
          "type Outcome = :ok | :error\n"
          "public Outcome Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome>(s)\n",
    ?assertMatch([{error, _, 'Go', {return_not_declared, _, _}}], errors(Src)).

%% F25's correction must offer the residual, not merely report it: the whole
%% point of the corrected signature is that it can be pasted back.
the_correction_offers_the_residual_test() ->
    Src = "module PaNarrow2\n"
          "type Outcome = :ok | :error\n"
          "public Outcome Go(string s)\n"
          "Go(s) -> ParseAtom<Outcome>(s)\n",
    [{error, _, 'Go', {return_not_declared, Undeclared, Corrected}}] = errors(Src),
    ?assertEqual(<<":nothing">>, iolist_to_binary(bs_types:to_string(Undeclared))),
    ?assertNotEqual(none, Corrected).

%%% ---------------------------------------------------------------------------
%%% F39.7 — the argument is a string
%%% ---------------------------------------------------------------------------

%% The generated match is over binaries, so a value of another kind could only
%% ever fall to the catch-all and answer `:nothing`. That is a residual which
%% reads "no member has that name" when the truth is "that was never a name",
%% so it is refused instead. `term` is the case that will actually happen: a
%% value straight off a boundary, before a clause head has matched it.
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

%% A `binary` passes as well as a `string`: a string IS a binary here (F9), and
%% the match does not care which of the two the author declared.
a_binary_argument_is_accepted_test() ->
    Src = "module PaArgBin\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(binary b)\n"
          "Go(b) -> ParseAtom<Outcome>(b)\n",
    M = build_and_load(Src, 'PaArgBin'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)).

%%% ---------------------------------------------------------------------------
%%% F39.6 — the pipe form
%%% ---------------------------------------------------------------------------

%% `bs_parser.yrl:490` admits the empty argument list precisely so an
%% obligation can sit in a pipeline. F14's rewrite fills the argument, and it
%% must fill it for THIS obligation and not only for the built sibling.
the_pipe_form_parses_the_piped_string_test() ->
    Src = "module PaPipe\n"
          "type Outcome = :ok | :error\n"
          "type Parsed = :ok | :error | :nothing\n"
          "public Parsed Go(string s)\n"
          "Go(s) -> s |> ParseAtom<Outcome>()\n",
    M = build_and_load(Src, 'PaPipe'),
    ?assertEqual(ok, M:'Go'(<<"ok">>)),
    ?assertEqual(nothing, M:'Go'(<<"nope">>)).
