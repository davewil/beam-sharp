%%% F18 — `ValidateAs<T>`, the generated deep validator.
%%%
%%% AT THE BOUNDARY, AND THE BOUNDARY HERE IS A RUNNING PROGRAM. What
%%% `ValidateAs<T>` means is what a compiled module RETURNS when handed a term,
%%% so almost every test below compiles source, loads the `.beam` and calls it.
%%% Nothing asserts on the shape of the generated abstract format: rearranging
%%% how the traversal is emitted must not turn this file red, and the one test
%%% that does look at the module asks `module_info/1` how many functions there
%%% are, which is a fact about the artefact rather than about the emitter.
%%%
%%% THE REFUSALS CANNOT LIVE IN `examples/`, which is why they are the bulk of
%%% this file. Every example must compile; a capability whose whole behaviour is
%%% a rejection has nowhere else to be looked at.
-module(validate_as_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

%%% ---------------------------------------------------------------------------
%%% F18.1, F18.2 — the simplest type there is
%%% ---------------------------------------------------------------------------

int_src() ->
    "module VaInt\n"
    "public result<int, ValidationError> Number(term t)\n"
    "Number(t) -> ValidateAs<int>(t)\n".

%% Success is UNTAGGED — `result<T, E>` is `T | (:error, E)` (ticket 15 §2), so a
%% caller gets the value back and not a wrapper around it.
a_valid_term_comes_back_unwrapped_test() ->
    M = build_and_load(int_src(), 'VaInt'),
    ?assertEqual(7, M:'Number'(7)).

%% The empty path is the term itself, which is the common case and has to read
%% as one rather than as a missing value.
a_failing_term_names_an_empty_path_and_the_expected_type_test() ->
    M = build_and_load(int_src(), 'VaInt'),
    ?assertEqual({error, {[], <<"int">>}}, M:'Number'(seven)).

%%% ---------------------------------------------------------------------------
%%% F18.3, F18.4 — a list, and the index in the path
%%% ---------------------------------------------------------------------------

list_src() ->
    "module VaList\n"
    "public result<list<int>, ValidationError> Numbers(term t)\n"
    "Numbers(t) -> ValidateAs<list<int>>(t)\n".

a_list_of_the_right_element_type_passes_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual([1, 2, 3], M:'Numbers'([1, 2, 3])).

an_empty_list_passes_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual([], M:'Numbers'([])).

%% Zero-based, because the segment is an INDEX into the term rather than an
%% ordinal for a reader.
a_bad_element_names_its_index_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual({error, {[<<"[1]">>], <<"int">>}}, M:'Numbers'([1, two, 3])).

%% `is_list/1` IS TRUE OF AN IMPROPER LIST, so a validator written as a guard
%% would have accepted `[1|2]` as a `list<int>`. The blame is the list, not an
%% element of it: no element was wrong.
an_improper_list_is_rejected_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual({error, {[], <<"list<int>">>}}, M:'Numbers'([1 | 2])).

a_non_list_is_rejected_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual({error, {[], <<"list<int>">>}}, M:'Numbers'(42)).

%%% ---------------------------------------------------------------------------
%%% F18.5 – F18.8 — records, which is what a deep validator mostly walks
%%% ---------------------------------------------------------------------------

order_src() ->
    "module VaOrder\n"
    "record Line { Sku: string, Price: int }\n"
    "record Order { Id: int, Lines: list<Line> }\n"
    "public result<Order, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Order>(t)\n".

line(Sku, Price) -> #{'Kind' => 'VaOrder.Line', 'Sku' => Sku, 'Price' => Price}.
order(Id, Lines) -> #{'Kind' => 'VaOrder.Order', 'Id' => Id, 'Lines' => Lines}.

a_well_formed_record_passes_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    O = order(1, [line(<<"axle">>, 500)]),
    ?assertEqual(O, M:'Decode'(O)).

a_field_of_the_wrong_type_names_the_field_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    ?assertEqual({error, {[<<".Id">>], <<"int">>}},
                 M:'Decode'(order(one, []))).

%% F18.7 — THE PATH COMPOSES, and this is the test the whole path design exists
%% for. Three segments of three different kinds in one answer.
a_nested_failure_composes_the_whole_path_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Bad = order(1, [line(<<"axle">>, 500), line(<<"hub">>, free)]),
    ?assertEqual({error, {[<<".Lines">>, <<"[1]">>, <<".Price">>], <<"int">>}},
                 M:'Decode'(Bad)).

%% TICKET 26 §4 — a declared map type is CLOSED. A wider map is a different type,
%% so `#{...}` alone would have been wrong: it matches a map that merely HAS
%% those keys.
an_extra_key_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Wide = (order(1, []))#{'Note' => <<"hi">>},
    %% The expectation names the whole record type, because the wider map is not
    %% a wrong FIELD — it is a different type.
    ?assertEqual({error, {[], <<"{ Kind: :'VaOrder.Order', Id: int, "
                                "Lines: list<{ Kind: :'VaOrder.Line', "
                                "Price: int, Sku: string }> }">>}},
                 M:'Decode'(Wide)).

a_missing_key_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    ?assertMatch({error, {[], _}}, M:'Decode'(#{'Kind' => 'VaOrder.Order',
                                                'Id' => 1})).

%% The minted tag is ordinary data in the term (26 §1), so it validates like any
%% other field — and a map wearing the wrong tag is not this record.
a_wrong_tag_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Wrong = (order(1, []))#{'Kind' => 'VaOrder.Line'},
    ?assertEqual({error, {[<<".Kind">>], <<":'VaOrder.Order'">>}},
                 M:'Decode'(Wrong)).

%%% ---------------------------------------------------------------------------
%%% F18.15 — `string`, and ticket 20 §4's owed membership check
%%% ---------------------------------------------------------------------------

string_src() ->
    "module VaStr\n"
    "public result<string, ValidationError> Text(term t)\n"
    "Text(t) -> ValidateAs<string>(t)\n"
    "public result<binary, ValidationError> Bytes(term t)\n"
    "Bytes(t) -> ValidateAs<binary>(t)\n".

a_utf8_binary_is_a_string_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual(<<"h", 195, 169, "llo">>, M:'Text'(<<"h", 195, 169, "llo">>)).

%% THE CHECK `PRELUDE.md` HAS BEEN RECORDING AS OWED. Until this feature a
%% literal was the only thing that could establish valid UTF-8, and it did so at
%% compile time — nothing could establish it for a term that arrived from
%% outside, which is the only place the question is interesting.
a_non_utf8_binary_is_not_a_string_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual({error, {[], <<"string">>}}, M:'Text'(<<255, 254>>)).

%% The refinement is a SUBSET, so the base accepts what the refinement refuses.
a_non_utf8_binary_is_still_a_binary_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual(<<255, 254>>, M:'Bytes'(<<255, 254>>)).

%%% ---------------------------------------------------------------------------
%%% F18.17, F18.18 — blame across a union
%%% ---------------------------------------------------------------------------

reading_src() ->
    "module VaReading\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "public result<Reading, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<Reading>(t)\n".

either_member_of_the_union_passes_test() ->
    M = build_and_load(reading_src(), 'VaReading'),
    ?assertEqual({ok, 5}, M:'Read'({ok, 5})),
    ?assertEqual({error, nope}, M:'Read'({error, nope})).

%% F18.17 — the first component picks out ONE candidate, so the descent is
%% unambiguous and the blame is exact: component 2, expected `int`.
a_union_discriminated_by_a_tag_blames_the_component_test() ->
    M = build_and_load(reading_src(), 'VaReading'),
    ?assertEqual({error, {[<<"(2)">>], <<"int">>}}, M:'Read'({ok, nope})).

pair_src() ->
    "module VaPair\n"
    "type Pair = (int, int) | (atom, atom)\n"
    "public result<Pair, ValidationError> Both(term t)\n"
    "Both(t) -> ValidateAs<Pair>(t)\n".

both_members_of_an_ambiguous_union_pass_test() ->
    M = build_and_load(pair_src(), 'VaPair'),
    ?assertEqual({1, 2}, M:'Both'({1, 2})),
    ?assertEqual({a, b}, M:'Both'({a, b})).

%% F18.18 — NOTHING STRUCTURAL CHOOSES between two products of the same arity, so
%% the blame stays at this node with this node's whole type as the expectation.
%% Descending into a guessed candidate would be blame tracking, and nothing has
%% decided a rule for picking the winner among failed alternatives.
%% The EXPECTATION is the assertion, not the empty path: blaming the node is only
%% honest if what it reports is the whole union rather than one candidate's type.
an_ambiguous_union_blames_the_node_not_a_candidate_test() ->
    M = build_and_load(pair_src(), 'VaPair'),
    ?assertEqual({error, {[], <<"(int, int) | (atom, atom)">>}},
                 M:'Both'({1, b})).

%% A UNION OF RECORDS IS THE TAGGED CASE ONE CONSTRUCTOR OVER, and the two here
%% have IDENTICAL field names — so a field set cannot tell them apart and only
%% the minted `Kind` can. This is `shop.bs`'s own `Doc = Order | Invoice`.
doc_src() ->
    "module VaDoc\n"
    "record Order { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: atom }\n"
    "type Doc = Order | Invoice\n"
    "public result<Doc, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Doc>(t)\n".

each_record_in_a_union_passes_test() ->
    M = build_and_load(doc_src(), 'VaDoc'),
    O = #{'Kind' => 'VaDoc.Order', 'Id' => 1, 'Total' => 500},
    I = #{'Kind' => 'VaDoc.Invoice', 'Id' => 2, 'Total' => unpaid},
    ?assertEqual(O, M:'Decode'(O)),
    ?assertEqual(I, M:'Decode'(I)).

%% The tag chose, so the blame is exact even though both members have the same
%% two field names.
the_minted_tag_discriminates_a_record_union_test() ->
    M = build_and_load(doc_src(), 'VaDoc'),
    Bad = #{'Kind' => 'VaDoc.Order', 'Id' => 1, 'Total' => unpaid},
    ?assertEqual({error, {[<<".Total">>], <<"int">>}}, M:'Decode'(Bad)).

a_tag_belonging_to_neither_is_rejected_test() ->
    M = build_and_load(doc_src(), 'VaDoc'),
    Bad = #{'Kind' => 'Other.Thing', 'Id' => 1, 'Total' => 5},
    ?assertMatch({error, {[], _}}, M:'Decode'(Bad)).

%%% ---------------------------------------------------------------------------
%%% Ticket 61 — the path descends into a tuple component, and the expectation
%%% is printed the way the author would write it
%%%
%%% Raised by exemplar 25d: a result set crosses the boundary as a list of
%%% tuple rows, and the error stopped at the row. The descent machinery was
%%% never the gap — `t_absorb/1` kept two copies of an identical product, so
%%% the element type arrived as a two-member union and the discriminator saw
%%% ambiguity where there was none. `m_absorb/1` had already fixed exactly
%%% this for records, which is why F18.7 above always passed.
%%% ---------------------------------------------------------------------------

wire_src() ->
    "module VaWire\n"
    "type WireRow = (int, string, term)\n"
    "public result<list<WireRow>, ValidationError> Rows(term t)\n"
    "Rows(t) -> ValidateAs<list<WireRow>>(t)\n".

%% 25d §3's expectation, verbatim: the row, the component, and the narrow
%% expected type — `(["[1]", "(2)"], "string")`, not a stop at the row.
a_bad_tuple_component_names_row_and_component_test() ->
    M = build_and_load(wire_src(), 'VaWire'),
    ?assertEqual({error, {[<<"[1]">>, <<"(2)">>], <<"string">>}},
                 M:'Rows'([{1, <<"ada">>, x}, {2, bad, y}])).

a_clean_tuple_rowset_passes_test() ->
    M = build_and_load(wire_src(), 'VaWire'),
    ?assertEqual([{1, <<"ada">>, x}], M:'Rows'([{1, <<"ada">>, x}])).

%% `l_elem` unions the spine's prefix with its tail, and for `list<P>` the two
%% are the same type — the expectation must not say so twice.
a_list_element_expectation_prints_once_test() ->
    Src = "module VaPairList\n"
          "type P = (int, int)\n"
          "public result<list<P>, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<list<P>>(t)\n",
    M = build_and_load(Src, 'VaPairList'),
    ?assertEqual({error, {[<<"[0]">>], <<"(int, int)">>}}, M:'Go'([x])).

%% `term` is not an alias that erased by diagnostic time — it is the name of
%% the top, and printing its six-way decomposition is strictly worse.
term_prints_as_term_in_an_expectation_test() ->
    Src = "module VaTermField\n"
          "type Tagged = (:ok, term)\n"
          "public result<Tagged, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<Tagged>(t)\n",
    M = build_and_load(Src, 'VaTermField'),
    ?assertEqual({error, {[], <<"(:ok, term)">>}}, M:'Go'(42)).

%%% ---------------------------------------------------------------------------
%%% The type is the ALGEBRA's, not the surface's
%%% ---------------------------------------------------------------------------

%% F6.3's property one layer down: `option<int>` and a hand-written
%% `int | :nothing` are the same type by the time the generator sees either, so
%% they cannot generate validators that disagree.
option_src() ->
    "module VaOption\n"
    "type Maybe = int | :nothing\n"
    "public result<option<int>, ValidationError> ViaPrelude(term t)\n"
    "ViaPrelude(t) -> ValidateAs<option<int>>(t)\n"
    "public result<Maybe, ValidationError> ViaAlias(term t)\n"
    "ViaAlias(t) -> ValidateAs<Maybe>(t)\n".

a_prelude_alias_and_a_written_union_validate_alike_test() ->
    M = build_and_load(option_src(), 'VaOption'),
    ?assertEqual(3, M:'ViaPrelude'(3)),
    ?assertEqual(3, M:'ViaAlias'(3)),
    ?assertEqual(nothing, M:'ViaPrelude'(nothing)),
    ?assertEqual(nothing, M:'ViaAlias'(nothing)),
    ?assertEqual(M:'ViaPrelude'(x), M:'ViaAlias'(x)).

%%% ---------------------------------------------------------------------------
%%% F18.16 — one validator per type, not per call site
%%% ---------------------------------------------------------------------------

%% Ticket 27 §8 requires monomorphic AT every use site; emitting the identical
%% traversal twice would satisfy that and waste the module. Counted through
%% `module_info/1`, which is a fact about the artefact rather than about how the
%% emitter is written.
two_call_sites_on_one_type_share_one_validator_test() ->
    One = "module VaOnce\n"
          "record Tag { Name: string }\n"
          "public result<Tag, ValidationError> One(term t)\n"
          "One(t) -> ValidateAs<Tag>(t)\n",
    Two = "module VaTwice\n"
          "record Tag { Name: string }\n"
          "public result<Tag, ValidationError> One(term t)\n"
          "One(t) -> ValidateAs<Tag>(t)\n"
          "public result<Tag, ValidationError> Two(term t)\n"
          "Two(t) -> ValidateAs<Tag>(t)\n",
    M1 = build_and_load(One, 'VaOnce'),
    M2 = build_and_load(Two, 'VaTwice'),
    %% The second call site adds nothing to the module — same validators, same
    %% single root wrapper, and both entry points reach it.
    ?assertEqual(generated(M1), generated(M2)),
    ?assertEqual(1, length([N || N <- generated(M2),
                                 lists:suffix("@r", atom_to_list(N))])),
    Tag = #{'Kind' => 'VaTwice.Tag', 'Name' => <<"a">>},
    ?assertEqual(Tag, M2:'One'(Tag)),
    ?assertEqual(Tag, M2:'Two'(Tag)).

generated(M) ->
    lists:sort([N || {N, _} <- M:module_info(functions),
                     lists:prefix("bs@validate@", atom_to_list(N))]).

%%% ---------------------------------------------------------------------------
%%% F18.9 – F18.14 — the refusals
%%% ---------------------------------------------------------------------------

%% TICKET 15 §1, met at an instantiation rather than at a declaration. `term` is
%% the only type that absorbs the tagged failure member, and it is also the one
%% instantiation that is vacuous: every term inhabits `term`.
validate_as_term_is_refused_test() ->
    Src = "module VaTerm\n"
          "public result<term, ValidationError> Any(term t)\n"
          "Any(t) -> ValidateAs<term>(t)\n",
    ?assertMatch([{error, _, 'Any', {validate_collapses, _}}], errors(Src)).

%% Ticket 28's closed set. A name outside it is not a syntax error — which is
%% what a lexical implementation of the rule could only have produced — it is a
%% named diagnostic that says which names DO take a bracket.
a_name_outside_the_closed_set_is_refused_test() ->
    Src = "module VaEncode\n"
          "public int Go(term t)\n"
          "Go(t) -> Encode<int>(t)\n",
    ?assertMatch([{error, _, 'Go', {not_an_obligation, 'Encode'}}], errors(Src)).

%% THE OTHER TWO MEMBERS OF THE SET ARE A DIFFERENT SENTENCE. `ParseAtom<T>` is
%% decided (10 §4) and simply unbuilt; telling that apart from "never going to
%% work" is the whole reason the set is enforced in the checker.
a_decided_but_unbuilt_obligation_says_so_test() ->
    Src = "module VaParse\n"
          "type Colour = :red | :green\n"
          "public Colour Go(term t)\n"
          "Go(t) -> ParseAtom<Colour>(t)\n",
    ?assertMatch([{error, _, 'Go', {obligation_unbuilt, 'ParseAtom'}}],
                 errors(Src)).

to_existing_atom_is_also_unbuilt_test() ->
    Src = "module VaExisting\n"
          "public atom Go(term t)\n"
          "Go(t) -> ToExistingAtom<atom>(t)\n",
    ?assertMatch([{error, _, 'Go', {obligation_unbuilt, 'ToExistingAtom'}}],
                 errors(Src)).

%% One type argument and one value. A codegen obligation is not a function, so
%% "wrong arity" is about the shape of the construct rather than about a
%% signature nobody wrote.
two_type_arguments_are_refused_test() ->
    Src = "module VaTwoTypes\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int, atom>(t)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ValidateAs', 2, 1}}],
                 errors(Src)).

two_values_are_refused_test() ->
    Src = "module VaTwoArgs\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int>(t, t)\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ValidateAs', 1, 2}}],
                 errors(Src)).

no_value_at_all_is_refused_test() ->
    Src = "module VaNoArgs\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int>()\n",
    ?assertMatch([{error, _, 'Go', {obligation_arity, 'ValidateAs', 1, 0}}],
                 errors(Src)).

%% F18.13 — an unknown `T` here is the same mistake as an unknown `T` in a
%% signature and reads the same way. The site adds no diagnostic of its own.
an_unknown_type_argument_is_the_ordinary_diagnostic_test() ->
    Src = "module VaUnknown\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<Nowhere>(t)\n",
    ?assertError({unknown_type, 'Nowhere'}, check_only(Src)).

%% F18.14 — the return type is checked by site 4 exactly as any other body is.
%% Declaring the bare success type is an ordinary `return_not_declared`, and the
%% residual it names is the failure member.
declaring_the_bare_success_type_is_refused_test() ->
    Src = "module VaBareRet\n"
          "public int Go(term t)\n"
          "Go(t) -> ValidateAs<int>(t)\n",
    ?assertMatch([{error, _, 'Go', {return_not_declared, _, _}}], errors(Src)).

declaring_the_result_type_is_accepted_test() ->
    Src = "module VaGoodRet\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int>(t)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% Stratum 2 of the prelude
%%% ---------------------------------------------------------------------------

%% `PRELUDE.md`: stratum 2 is compiler-known and *"a user may not add to this
%% stratum"*. Refused at the DECLARATION rather than resolved by shadowing —
%% shadowing would leave the author with a type error somewhere else and nothing
%% pointing at the line that caused it.
redeclaring_a_compiler_known_type_is_refused_test() ->
    Src = "module VaShadow\n"
          "type ValidationError = int\n"
          "public int Go(int n)\n"
          "Go(n) -> n\n",
    ?assertError({compiler_known_type, 'ValidationError', _}, check_only(Src)).

a_record_may_not_take_the_name_either_test() ->
    Src = "module VaShadowRec\n"
          "record ValidationError { Why: string }\n"
          "public int Go(int n)\n"
          "Go(n) -> n\n",
    ?assertError({compiler_known_type, 'ValidationError', _}, check_only(Src)).

%% And the name is usable without any import, which is what "prelude" means.
validation_error_is_in_scope_with_no_declaration_test() ->
    Src = "module VaInScope\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int>(t)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% The five new diagnostics, as the AUTHOR receives them
%%%
%%% EVERY ASSERTION ABOVE IS AT THE TERM LEVEL, AND THAT IS NOT ENOUGH HERE.
%%% `bin/check-diagnostics.sh` compares the SET of tags minted in `descriptor/2`
%%% against the SET rendered in `message/1`, textually — so a `message/1` clause
%%% that never dispatches, because a broader clause above it matches first,
%%% leaves both sets identical and the gate green. The term tests pass too: the
%%% term is right. The only thing wrong is the sentence, and nothing else in this
%%% repo looks at it.
%%%
%%% So this drives `bsc` as a subprocess and asks the three questions a term
%%% cannot answer: did the run fail, is the author's sentence there, and did the
%%% renderer crash instead of rendering. The third is the one that catches a
%%% missing clause outright — `message/1` has no catch-all on purpose, so an
%%% unrendered tag is `function_clause` at the moment of reporting.
%%%
%%% THE FOURTH ASSERTION IS THE TAG'S OWN ATOM BEING ABSENT. A renderer that
%%% falls through to printing the descriptor would satisfy the first three — the
%%% run failed, and a term dump contains most of the words — while handing the
%%% author `#{tag => validate_collapses, ...}`. The tag name appears in no
%%% message's prose, so its absence is exactly the assertion that the reader got
%%% a sentence rather than a map.
%%%
%%% MEASURED FAILING BEFORE IT WAS BELIEVED, 2026-08-18. `message/1`'s
%%% `validate_collapses` clause head was renamed so the tag no longer dispatched.
%%% This block went red on the FRAGMENT assertion — and in the same run
%%% `validate_as_term_is_refused_test`, the term-level test for the identical
%%% tag, still passed. That is the whole argument for this block in one run: the
%%% term was right, its test was green, and the author's sentence was gone.
%%% ---------------------------------------------------------------------------

%% {tag, source, a fragment of the sentence that appears on ONE line}
prose_cases() ->
    [{validate_collapses,
      "module VaProseCollapse\n"
      "public result<term, ValidationError> Any(term t)\n"
      "Any(t) -> ValidateAs<term>(t)\n",
      "absorbs its own"},
     {obligation_arity,
      "module VaProseArity\n"
      "public result<int, ValidationError> Go(term t)\n"
      "Go(t) -> ValidateAs<int, atom>(t)\n",
      "codegen obligation, not a function"},
     {obligation_unbuilt,
      "module VaProseUnbuilt\n"
      "public atom Go(term t)\n"
      "Go(t) -> ToExistingAtom<atom>(t)\n",
      "decided and not built yet"},
     {not_an_obligation,
      "module VaProseNotOne\n"
      "public int Go(term t)\n"
      "Go(t) -> Encode<int>(t)\n",
      "is not a codegen obligation"},
     {compiler_known_type,
      "module VaProseShadow\n"
      "type ValidationError = int\n"
      "public int Go(int n)\n"
      "Go(n) -> n\n",
      "compiler-known type and cannot be redeclared"}].

every_new_diagnostic_reaches_the_author_as_prose_test_() ->
    [{atom_to_list(Tag), fun() -> assert_prose(Tag, Src, Fragment) end}
     || {Tag, Src, Fragment} <- prose_cases()].

assert_prose(Tag, Src, Fragment) ->
    %% Asserted rather than skipped-if-absent. `rebar.config`'s pre-eunit hook
    %% builds the escript precisely so this path runs, and a test that quietly
    %% returns `ok` when the artefact is missing is the shape that let
    %% `cli_tests` never execute in CI at all.
    ?assert(filelib:is_regular(bs_test_support:escript())),
    bs_test_support:with_src(
      "in.bs", Src,
      fun(Path, Root) ->
              Out = bs_test_support:run_cli(
                      "-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
              ?assertNotEqual(nomatch, string:find(Out, "rc:1")),
              ?assertNotEqual(nomatch, string:find(Out, Fragment)),
              ?assertEqual(nomatch, string:find(Out, "escript: exception")),
              ?assertEqual(nomatch, string:find(Out, atom_to_list(Tag)))
      end).

%%% ---------------------------------------------------------------------------
%%% The bracket, and what it did NOT change
%%% ---------------------------------------------------------------------------

%% F6.9's assertion, re-run against the grammar F18 changed. The whole reason
%% ticket 28 restricted the bracket to a closed set was that `<` must stay a
%% comparison everywhere else, and the new production is only reachable after a
%% `uident` — which is never the left operand of a comparison.
a_comparison_is_still_a_comparison_test() ->
    Src = "module VaCompare\n"
          "public bool Less(int a, int b)\n"
          "Less(a, b) -> a < b\n",
    M = build_and_load(Src, 'VaCompare'),
    ?assertEqual(true, M:'Less'(1, 2)),
    ?assertEqual(false, M:'Less'(2, 1)).

%% Ticket 18 §7 writes `EtsLookup(:orders, id) |> ValidateAs<list<Order>>()`, so
%% the empty argument list is not decoration: `expr '|>' call` means the pipe's
%% right operand has to parse as a call with no arguments.
the_pipe_reaches_the_bracket_test() ->
    Src = "module VaPipe\n"
          "public result<list<int>, ValidationError> Go(term t)\n"
          "Go(t) -> t |> ValidateAs<list<int>>()\n",
    M = build_and_load(Src, 'VaPipe'),
    ?assertEqual([1, 2], M:'Go'([1, 2])),
    ?assertEqual({error, {[<<"[0]">>], <<"int">>}}, M:'Go'([x])).

%%% ---------------------------------------------------------------------------
%%% Consuming the result the way an author would
%%% ---------------------------------------------------------------------------

%% The point of returning a value rather than crashing (ticket 15): the failure
%% is ordinary control flow, and `switch` is how it is read.
a_switch_reads_the_result_test() ->
    Src = "module VaConsume\n"
          "public string Describe(term t)\n"
          "Describe(t) -> ValidateAs<int>(t) switch {\n"
          "    (:error, e) => \"no\",\n"
          "    n           => \"yes\"\n"
          "}\n",
    M = build_and_load(Src, 'VaConsume'),
    ?assertEqual(<<"yes">>, M:'Describe'(4)),
    ?assertEqual(<<"no">>, M:'Describe'(four)).
