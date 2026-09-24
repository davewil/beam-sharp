%%% F18 — `ValidateAs<T>` validates terms deeply.
%%% Scenarios: compiler/features/F18-validate-as.md
%%% Scenarios: compiler/features/F6-angle-brackets.md
-module(validate_as_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1,
                          validation_error/2]).

%%% F18.1, F18.2 — integers pass; other terms name the expected type.

int_src() ->
    "module VaInt\n"
    "public result<int, ValidationError> Number(term t)\n"
    "Number(t) -> ValidateAs<int>(t)\n".

a_valid_term_comes_back_unwrapped_test() ->
    M = build_and_load(int_src(), 'VaInt'),
    ?assertEqual(7, M:'Number'(7)).

a_failing_term_names_an_empty_path_and_the_expected_type_test() ->
    M = build_and_load(int_src(), 'VaInt'),
    ?assertEqual(validation_error([], <<"int">>), M:'Number'(seven)).

%%% F18.3, F18.4 — lists validate elements and report their indices.

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

a_bad_element_names_its_index_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual(validation_error([<<"[1]">>], <<"int">>), M:'Numbers'([1, two, 3])).

%% The improper tail invalidates the list; no element has the wrong type.
an_improper_list_is_rejected_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual(validation_error([], <<"list<int>">>), M:'Numbers'([1 | 2])).

a_non_list_is_rejected_test() ->
    M = build_and_load(list_src(), 'VaList'),
    ?assertEqual(validation_error([], <<"list<int>">>), M:'Numbers'(42)).

%%% F18.5 – F18.8 — records validate fields and reject extra keys.

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
    ?assertEqual(validation_error([<<".Id">>], <<"int">>),
                 M:'Decode'(order(one, []))).

%% F18.7 — nested failures compose field and index paths.
a_nested_failure_composes_the_whole_path_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Bad = order(1, [line(<<"axle">>, 500), line(<<"hub">>, free)]),
    ?assertEqual(validation_error([<<".Lines">>, <<"[1]">>, <<".Price">>], <<"int">>),
                 M:'Decode'(Bad)).

an_extra_key_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Wide = (order(1, []))#{'Note' => <<"hi">>},
    %% Extra keys invalidate the whole record, not a single field.
    ?assertEqual(validation_error([], <<"{ Kind: :'VaOrder.Order', Id: int, "
                                "Lines: list<{ Kind: :'VaOrder.Line', "
                                "Price: int, Sku: string }> }">>),
                 M:'Decode'(Wide)).

a_missing_key_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    ?assertMatch({error, #{'Kind' := 'ValidationError', 'Path' := []}},
                 M:'Decode'(#{'Kind' => 'VaOrder.Order', 'Id' => 1})).

a_wrong_tag_is_rejected_test() ->
    M = build_and_load(order_src(), 'VaOrder'),
    Wrong = (order(1, []))#{'Kind' => 'VaOrder.Line'},
    ?assertEqual(validation_error([<<".Kind">>], <<":'VaOrder.Order'">>),
                 M:'Decode'(Wrong)).

%%% F18.15 — strings require valid UTF-8.

string_src() ->
    "module VaStr\n"
    "public result<string, ValidationError> Text(term t)\n"
    "Text(t) -> ValidateAs<string>(t)\n"
    "public result<binary, ValidationError> Bytes(term t)\n"
    "Bytes(t) -> ValidateAs<binary>(t)\n".

a_utf8_binary_is_a_string_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual(<<"h", 195, 169, "llo">>, M:'Text'(<<"h", 195, 169, "llo">>)).

a_non_utf8_binary_is_not_a_string_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual(validation_error([], <<"string">>), M:'Text'(<<255, 254>>)).

a_non_utf8_binary_is_still_a_binary_test() ->
    M = build_and_load(string_src(), 'VaStr'),
    ?assertEqual(<<255, 254>>, M:'Bytes'(<<255, 254>>)).

%%% F18.17, F18.18 — union blame follows structural discrimination.

reading_src() ->
    "module VaReading\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "public result<Reading, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<Reading>(t)\n".

either_member_of_the_union_passes_test() ->
    M = build_and_load(reading_src(), 'VaReading'),
    ?assertEqual({ok, 5}, M:'Read'({ok, 5})),
    ?assertEqual({error, nope}, M:'Read'({error, nope})).

%% F18.17 — a tag selects one member, so blame reaches its component.
a_union_discriminated_by_a_tag_blames_the_component_test() ->
    M = build_and_load(reading_src(), 'VaReading'),
    ?assertEqual(validation_error([<<"(2)">>], <<"int">>), M:'Read'({ok, nope})).

pair_src() ->
    "module VaPair\n"
    "type Pair = (int, int) | (atom, atom)\n"
    "public result<Pair, ValidationError> Both(term t)\n"
    "Both(t) -> ValidateAs<Pair>(t)\n".

both_members_of_an_ambiguous_union_pass_test() ->
    M = build_and_load(pair_src(), 'VaPair'),
    ?assertEqual({1, 2}, M:'Both'({1, 2})),
    ?assertEqual({a, b}, M:'Both'({a, b})).

%% F18.18 — ambiguous unions blame the node and name the whole union.
an_ambiguous_union_blames_the_node_not_a_candidate_test() ->
    M = build_and_load(pair_src(), 'VaPair'),
    ?assertEqual(validation_error([], <<"(int, int) | (atom, atom)">>),
                 M:'Both'({1, b})).

%% Identical field names force discrimination by `Kind`.
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

the_minted_tag_discriminates_a_record_union_test() ->
    M = build_and_load(doc_src(), 'VaDoc'),
    Bad = #{'Kind' => 'VaDoc.Order', 'Id' => 1, 'Total' => unpaid},
    ?assertEqual(validation_error([<<".Total">>], <<"int">>), M:'Decode'(Bad)).

a_tag_belonging_to_neither_is_rejected_test() ->
    M = build_and_load(doc_src(), 'VaDoc'),
    Bad = #{'Kind' => 'Other.Thing', 'Id' => 1, 'Total' => 5},
    ?assertMatch({error, #{'Kind' := 'ValidationError', 'Path' := []}},
                 M:'Decode'(Bad)).

%%% Tuple paths and expectations

wire_src() ->
    "module VaWire\n"
    "type WireRow = (int, string, term)\n"
    "public result<list<WireRow>, ValidationError> Rows(term t)\n"
    "Rows(t) -> ValidateAs<list<WireRow>>(t)\n".

a_bad_tuple_component_names_row_and_component_test() ->
    M = build_and_load(wire_src(), 'VaWire'),
    ?assertEqual(validation_error([<<"[1]">>, <<"(2)">>], <<"string">>),
                 M:'Rows'([{1, <<"ada">>, x}, {2, bad, y}])).

a_clean_tuple_rowset_passes_test() ->
    M = build_and_load(wire_src(), 'VaWire'),
    ?assertEqual([{1, <<"ada">>, x}], M:'Rows'([{1, <<"ada">>, x}])).

a_list_element_expectation_prints_once_test() ->
    Src = "module VaPairList\n"
          "type P = (int, int)\n"
          "public result<list<P>, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<list<P>>(t)\n",
    M = build_and_load(Src, 'VaPairList'),
    ?assertEqual(validation_error([<<"[0]">>], <<"(int, int)">>), M:'Go'([x])).

term_prints_as_term_in_an_expectation_test() ->
    Src = "module VaTermField\n"
          "type Tagged = (:ok, term)\n"
          "public result<Tagged, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<Tagged>(t)\n",
    M = build_and_load(Src, 'VaTermField'),
    ?assertEqual(validation_error([], <<"(:ok, term)">>), M:'Go'(42)).

%%% Equivalent types

%% F6.3 — a prelude alias and its expanded union validate alike.
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

%%% F18.16 — call sites share one validator per type.

%% `module_info/1` counts generated functions in the compiled artefact.
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
    ?assertEqual(generated(M1), generated(M2)),
    ?assertEqual(1, length([N || N <- generated(M2),
                                 lists:suffix("@r", atom_to_list(N))])),
    Tag = #{'Kind' => 'VaTwice.Tag', 'Name' => <<"a">>},
    ?assertEqual(Tag, M2:'One'(Tag)),
    ?assertEqual(Tag, M2:'Two'(Tag)).

generated(M) ->
    lists:sort([N || {N, _} <- M:module_info(functions),
                     lists:prefix("bs@validate@", atom_to_list(N))]).

%%% F18.9 – F18.14 — invalid validation requests are refused.

%% `result<int, ValidationError>` keeps the declaration valid so the
%% refusal comes from the validation target.
validate_as_term_is_refused_test() ->
    Src = "module VaTerm\n"
          "public result<int, ValidationError> Any(term t)\n"
          "Any(t) -> ValidateAs<term>(t)\n",
    ?assertMatch([{error, _, 'Any', {validate_collapses, _}}], errors(Src)).

%% An unknown obligation name parses, then receives a named diagnostic.
a_name_outside_the_closed_set_is_refused_test() ->
    Src = "module VaEncode\n"
          "public int Go(term t)\n"
          "Go(t) -> Encode<int>(t)\n",
    ?assertMatch([{error, _, 'Go', {not_an_obligation, 'Encode'}}], errors(Src)).

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

%% F18.13 — unknown type arguments receive the ordinary type diagnostic.
an_unknown_type_argument_is_the_ordinary_diagnostic_test() ->
    Src = "module VaUnknown\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<Nowhere>(t)\n",
    ?assertError({unknown_type, 'Nowhere'}, check_only(Src)).

%% F18.14 — a bare success return type rejects the failure member.
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

%%% Prelude types

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

validation_error_is_in_scope_with_no_declaration_test() ->
    Src = "module VaInScope\n"
          "public result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<int>(t)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% Diagnostic prose
%%% The CLI checks rendering and exit status, which terms cannot show.
%%% A missing tag name distinguishes prose from a raw diagnostic dump.

prose_cases() ->
    %% The valid return declaration lets the obligation reach its diagnostic.
    [{validate_collapses,
      "module VaProseCollapse\n"
      "public result<int, ValidationError> Any(term t)\n"
      "Any(t) -> ValidateAs<term>(t)\n",
      "absorbs its own"},
     {obligation_arity,
      "module VaProseArity\n"
      "public result<int, ValidationError> Go(term t)\n"
      "Go(t) -> ValidateAs<int, atom>(t)\n",
      "codegen obligation, not a function"},
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
      "compiler-known type and cannot be redeclared"},
     {validate_indiscriminable,
      payload_src("Batch<int> | Batch<binary>"),
      "whose members no clause head can tell apart"}].

every_new_diagnostic_reaches_the_author_as_prose_test_() ->
    [{atom_to_list(Tag), fun() -> assert_prose(Tag, Src, Fragment) end}
     || {Tag, Src, Fragment} <- prose_cases()].

assert_prose(Tag, Src, Fragment) ->
    %% The pre-eunit hook builds the required escript.
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

%%% Brackets and comparison

%% F6.9 — angle brackets leave value comparisons unchanged.
a_comparison_is_still_a_comparison_test() ->
    Src = "module VaCompare\n"
          "public bool Less(int a, int b)\n"
          "Less(a, b) -> a < b\n",
    M = build_and_load(Src, 'VaCompare'),
    ?assertEqual(true, M:'Less'(1, 2)),
    ?assertEqual(false, M:'Less'(2, 1)).

%% The pipe supplies the argument to the empty bracketed call.
the_pipe_reaches_the_bracket_test() ->
    Src = "module VaPipe\n"
          "public result<list<int>, ValidationError> Go(term t)\n"
          "Go(t) -> t |> ValidateAs<list<int>>()\n",
    M = build_and_load(Src, 'VaPipe'),
    ?assertEqual([1, 2], M:'Go'([1, 2])),
    ?assertEqual(validation_error([<<"[0]">>], <<"int">>), M:'Go'([x])).

%%% Consuming validation results

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

%%% F18.22 — validation rejects members no clause head can distinguish.

payload_src(Payload) ->
    "module VaPayload\n"
    "type Batch<T> = list<map<string, T>>\n"
    "type Payload = " ++ Payload ++ "\n"
    "public result<Payload, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Payload>(t)\n".

%% The declaration is legal: list patterns cover both members. Validation
%% rejects it because no element guard distinguishes the map value types.
validating_into_an_untagged_payload_is_refused_test() ->
    ?assertMatch([{error, _, 'Decode', {validate_indiscriminable, _, _, _}}],
                 errors(payload_src("Batch<int> | Batch<binary>"))).

the_untagged_payload_is_still_legal_to_declare_test() ->
    Src = "module VaPayloadDecl\n"
          "type Batch<T> = list<map<string, T>>\n"
          "type Payload = Batch<int> | Batch<binary>\n"
          "public Payload Pass(Payload p)\n"
          "Pass(p) -> p\n",
    M = build_and_load(Src, 'VaPayloadDecl'),
    ?assertEqual([], M:'Pass'([])).

the_refusal_names_both_members_and_the_repair_test() ->
    ?assert(filelib:is_regular(bs_test_support:escript())),
    bs_test_support:with_src(
      "in.bs", payload_src("Batch<int> | Batch<binary>"),
      fun(Path, Root) ->
              Out = bs_test_support:run_cli(
                      "-o " ++ Root ++ "/out " ++ filename:dirname(Path)),
              ?assertNotEqual(nomatch, string:find(Out, "rc:1")),
              ?assertNotEqual(nomatch, string:find(Out, "`[map<string, int>, ..]`")),
              ?assertNotEqual(nomatch, string:find(Out, "`[map<string, binary>, ..]`")),
              ?assertNotEqual(nomatch, string:find(Out, "Tag the members"))
      end).

a_tagged_payload_validates_test() ->
    M = build_and_load(payload_src("(:nums, Batch<int>) | (:text, Batch<binary>)"),
                       'VaPayload'),
    Nums = {nums, [#{<<"a">> => 1}]},
    Text = {text, [#{<<"a">> => <<"b">>}]},
    ?assertEqual(Nums, M:'Decode'(Nums)),
    ?assertEqual(Text, M:'Decode'(Text)),
    ?assertMatch({error, _}, M:'Decode'({nums, [#{<<"a">> => <<"b">>}]})).

%% An inline target bypasses declaration checks.
an_undeclared_target_is_refused_test() ->
    Src = "module VaInlinePair\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<map<string, int> | map<string, binary>>(t)\n",
    ?assertMatch([{error, _, 'Decode', {validate_indiscriminable, _, _, _}}],
                 errors(Src)).

a_pair_in_a_tuple_slot_is_refused_test() ->
    Src = "module VaSlotPair\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<(int, map<string, int>) | (int, map<string, binary>)>(t)\n",
    ?assertMatch([{error, _, 'Decode', {validate_indiscriminable, _, _, _}}],
                 errors(Src)).

%% A guard on the second slot distinguishes these members.
a_guard_on_one_slot_tells_the_members_apart_test() ->
    Src = "module VaSlotGuard\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<(int, int) | (int, atom)>(t)\n",
    M = build_and_load(Src, 'VaSlotGuard'),
    ?assertEqual({1, 2}, M:'Decode'({1, 2})),
    ?assertEqual({1, a}, M:'Decode'({1, a})).

%% A first-element guard distinguishes nonempty lists; both accept `[]`.
a_guard_on_the_first_element_tells_two_lists_apart_test() ->
    Src = "module VaListGuard\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<list<int> | list<atom>>(t)\n",
    M = build_and_load(Src, 'VaListGuard'),
    ?assertEqual([1, 2], M:'Decode'([1, 2])),
    ?assertEqual([a], M:'Decode'([a])),
    ?assertEqual([], M:'Decode'([])).

%% `Tree` contains no integer, so a first-element guard suffices.
a_recursive_element_beside_a_guardable_one_is_accepted_test() ->
    Src = "module VaTreeList\n"
          "type Tree = :leaf | (:node, Tree, Tree)\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<list<Tree> | list<int>>(t)\n",
    M = build_and_load(Src, 'VaTreeList'),
    ?assertEqual([{node, leaf, leaf}], M:'Decode'([{node, leaf, leaf}])),
    ?assertEqual([7], M:'Decode'([7])).

records_with_different_fields_are_accepted_test() ->
    Src = "module VaShapes\n"
          "record Point { X: int }\n"
          "record Label { Text: string }\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<Point | Label>(t)\n",
    M = build_and_load(Src, 'VaShapes'),
    P = #{'Kind' => 'VaShapes.Point', 'X' => 1},
    L = #{'Kind' => 'VaShapes.Label', 'Text' => <<"hi">>},
    ?assertEqual(P, M:'Decode'(P)),
    ?assertEqual(L, M:'Decode'(L)).

%% Collapse takes precedence even when the target is also inseparable.
a_collapsing_target_reports_only_the_collapse_test() ->
    Src = "module VaBoth\n"
          "public term Decode(term t)\n"
          "Decode(t) -> ValidateAs<result<map<string, int> | map<string, binary>, ValidationError>>(t)\n",
    ?assertMatch([{error, _, 'Decode', {validate_collapses, _}}], errors(Src)).
