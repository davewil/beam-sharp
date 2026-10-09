%%% F70 — ValidationError carries a Reason, and an absent or unknown key is
%%% blamed at its own path.
%%% Scenarios: compiler/features/F70-validation-reason.md
-module(validation_reason_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, with_src/3]).

err(Path, Expected, Reason) ->
    {error, #{'Kind' => 'ValidationError', 'Path' => Path,
              'Expected' => Expected, 'Reason' => Reason}}.

explain_clauses() ->
    ["Explain(ValidationError { Reason: :not_json })      -> \"the body is not JSON\"\n",
     "Explain(ValidationError { Reason: :missing })       -> \"a field is absent\"\n",
     "Explain(ValidationError { Reason: :unknown_key })   -> \"a field is not one of ours\"\n",
     "Explain(ValidationError { Reason: :duplicate_key }) -> \"a field is repeated\"\n",
     "Explain(ValidationError { Reason: :mismatch })      -> \"a field has the wrong type\"\n"].

intake_src(Mod, Clauses) ->
    "module " ++ Mod ++ "\n"
    "type W = { \"a\": int }\n"
    "public result<W, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<W>(body)\n"
    "public result<W, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<W>(t)\n"
    "public string Explain(ValidationError e)\n" ++ lists:append(Clauses) ++
    "public string Why(string body)\n"
    "Why(body) -> Read(body) switch {\n"
    "    (:error, e) => Explain(e),\n"
    "    w           => \"fine\"\n"
    "}\n".

intake() -> build_and_load(intake_src("VrIntake", explain_clauses()), 'VrIntake').

%%% F70.1 — the four reasons FromJson reports today

a_wrong_value_is_a_mismatch_at_its_key_test() ->
    ?assertEqual(err([<<"[\"a\"]">>], <<"int">>, mismatch),
                 (intake()):'Read'(<<"{\"a\":\"x\"}">>)).

an_absent_key_is_missing_at_its_own_path_test() ->
    ?assertEqual(err([<<"[\"a\"]">>], <<"int">>, missing),
                 (intake()):'Read'(<<"{}">>)).

an_unknown_key_is_named_test() ->
    ?assertEqual(err([<<"[\"b\"]">>], <<"\"a\"">>, unknown_key),
                 (intake()):'Read'(<<"{\"a\":1,\"b\":2}">>)).

text_that_is_not_json_says_so_test() ->
    ?assertEqual(err([], <<"JSON">>, not_json), (intake()):'Read'(<<"nope">>)).

a_value_that_inhabits_the_type_is_returned_test() ->
    ?assertEqual(#{<<"a">> => 1}, (intake()):'Read'(<<"{\"a\":1}">>)).

%%% F70.2 — ValidateAs reports the same two over a term

validate_as_reports_missing_and_unknown_test() ->
    M = intake(),
    ?assertEqual(err([<<"[\"a\"]">>], <<"int">>, missing), M:'Check'(#{})),
    ?assertEqual(err([<<"[\"b\"]">>], <<"\"a\"">>, unknown_key),
                 M:'Check'(#{<<"a">> => 1, <<"b">> => 2})).

%%% F70.3 — the reasons are a closed union a clause head covers

one_clause_per_reason_is_exhaustive_test() ->
    M = intake(),
    ?assertEqual(<<"the body is not JSON">>, M:'Why'(<<"nope">>)),
    ?assertEqual(<<"a field is absent">>, M:'Why'(<<"{}">>)),
    ?assertEqual(<<"a field is not one of ours">>, M:'Why'(<<"{\"a\":1,\"b\":2}">>)),
    ?assertEqual(<<"a field has the wrong type">>, M:'Why'(<<"{\"a\":\"x\"}">>)),
    ?assertEqual(<<"fine">>, M:'Why'(<<"{\"a\":1}">>)),
    ?assertEqual(<<"a field is repeated">>,
                 M:'Explain'(#{'Kind' => 'ValidationError', 'Path' => [],
                               'Expected' => <<"\"a\" once">>, 'Reason' => duplicate_key})).

%% The residual prints the record whole, as any record's does; which reason
%% is uncovered is not in it.
four_clauses_for_five_reasons_are_refused_test_() ->
    {timeout, 60,
     fun() ->
         [NotJson, Missing, Unknown, _Duplicate, Mismatch] = explain_clauses(),
         Src = intake_src("VrShort", [NotJson, Missing, Unknown, Mismatch]),
         with_src("vrshort.bs", Src,
             fun(Path, _Out) ->
                 {Rc, Output} = bs_test_support:run_cli_result(Path),
                 ?assertEqual(1, Rc),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "error: Explain is not exhaustive"))
             end)
     end}.

%%% F70.4 — the key's path follows its parent's

nested_src() ->
    "module VrNested\n"
    "type Usage = { \"in\": int, \"out\": int }\n"
    "type Reply = { \"usage\": Usage, \"rows\": list<Usage> }\n"
    "public result<Reply, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<Reply>(body)\n".

an_absent_key_inside_an_object_carries_the_parents_path_test() ->
    M = build_and_load(nested_src(), 'VrNested'),
    ?assertEqual(err([<<"[\"usage\"]">>, <<"[\"out\"]">>], <<"int">>, missing),
                 M:'Read'(<<"{\"usage\":{\"in\":1},\"rows\":[]}">>)).

an_absent_key_inside_a_list_element_carries_the_index_test() ->
    M = build_and_load(nested_src(), 'VrNested'),
    ?assertEqual(err([<<"[\"rows\"]">>, <<"[1]">>, <<"[\"in\"]">>], <<"int">>, missing),
                 M:'Read'(<<"{\"usage\":{\"in\":1,\"out\":2},"
                            "\"rows\":[{\"in\":1,\"out\":2},{\"out\":2}]}">>)),
    ?assertEqual(err([<<"[\"rows\"]">>, <<"[0]">>, <<"[\"x\"]">>],
                     <<"\"in\" | \"out\"">>, unknown_key),
                 M:'Read'(<<"{\"usage\":{\"in\":1,\"out\":2},"
                            "\"rows\":[{\"in\":1,\"out\":2,\"x\":3}]}">>)).

%%% F70.5 — an open type takes extras; an option key is not required

open_src() ->
    "module VrOpen\n"
    "type Reply = { \"id\": option<string>, \"model\": string, .. }\n"
    "public result<Reply, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<Reply>(body)\n".

an_open_type_keeps_a_key_it_does_not_name_test() ->
    M = build_and_load(open_src(), 'VrOpen'),
    ?assertEqual(#{<<"id">> => nothing, <<"model">> => <<"jev">>, <<"cost">> => 2},
                 M:'Read'(<<"{\"model\":\"jev\",\"cost\":2}">>)).

an_absent_required_key_beside_an_absent_option_key_is_missing_test() ->
    M = build_and_load(open_src(), 'VrOpen'),
    ?assertEqual(err([<<"[\"model\"]">>], <<"string">>, missing),
                 M:'Read'(<<"{\"cost\":2}">>)),
    ?assertEqual(err([<<"[\"model\"]">>], <<"string">>, missing),
                 M:'Read'(<<"{\"id\":\"g\"}">>)).

%%% F70.6 — a record's fields

record_src() ->
    "module VrOrders\n"
    "record Order { Id: int, Total: int }\n"
    "public result<Order, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Order>(t)\n".

a_records_absent_field_is_missing_test() ->
    M = build_and_load(record_src(), 'VrOrders'),
    ?assertEqual(err([<<".Total">>], <<"int">>, missing),
                 M:'Decode'(#{'Kind' => 'VrOrders.Order', 'Id' => 1})).

a_records_extra_field_is_unknown_test() ->
    M = build_and_load(record_src(), 'VrOrders'),
    ?assertEqual(err([<<".Extra">>], <<"Id | Total">>, unknown_key),
                 M:'Decode'(#{'Kind' => 'VrOrders.Order', 'Id' => 1, 'Total' => 2,
                              'Extra' => 3})).

%%% F70.12 — a record's tag, and keys the path cannot spell

parcel_src() ->
    "module VrParcel\n"
    "record Parcel { Id: int, Note: option<string> }\n"
    "type Doc = { Kind: :invoice }\n"
    "public result<Parcel, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Parcel>(t)\n"
    "public result<Doc, ValidationError> Tagged(term t)\n"
    "Tagged(t) -> ValidateAs<Doc>(t)\n".

a_map_without_the_tag_is_missing_it_test() ->
    M = build_and_load(parcel_src(), 'VrParcel'),
    ?assertEqual(err([<<".Kind">>], <<":'VrParcel.Parcel'">>, missing),
                 M:'Decode'(#{'Id' => 1, 'Note' => nothing})).

another_records_tag_is_a_mismatch_at_the_tag_test() ->
    M = build_and_load(parcel_src(), 'VrParcel'),
    Wrong = err([<<".Kind">>], <<":'VrParcel.Parcel'">>, mismatch),
    ?assertEqual(Wrong, M:'Decode'(#{'Kind' => 'Other.Order', 'Id' => 1, 'Note' => nothing})),
    %% The same answer beside an extra key, and beside an absent option key.
    ?assertEqual(Wrong, M:'Decode'(#{'Kind' => 'Other.Order', 'Id' => 1, 'Note' => nothing,
                                     'Extra' => 2})),
    ?assertEqual(Wrong, M:'Decode'(#{'Kind' => 'Other.Order', 'Id' => 1})),
    %% Another record altogether is not this one with a field absent.
    ?assertEqual(Wrong, M:'Decode'(#{'Kind' => 'Other.Thing', 'Name' => 1})).

an_unknown_key_beside_an_absent_option_key_is_named_test() ->
    M = build_and_load(parcel_src(), 'VrParcel'),
    ?assertEqual(err([<<".Extra">>], <<"Id | Note">>, unknown_key),
                 M:'Decode'(#{'Kind' => 'VrParcel.Parcel', 'Id' => 1, 'Extra' => 2})),
    ?assertEqual(#{'Kind' => 'VrParcel.Parcel', 'Id' => 1, 'Note' => nothing},
                 M:'Decode'(#{'Kind' => 'VrParcel.Parcel', 'Id' => 1})).

%% A type naming no field but its tag has no keys to list, so it is printed.
a_type_with_only_a_tag_expects_itself_test() ->
    M = build_and_load(parcel_src(), 'VrParcel'),
    ?assertEqual(err([<<".Extra">>], <<"{ Kind: :invoice }">>, unknown_key),
                 M:'Tagged'(#{'Kind' => invoice, 'Extra' => 1})).

%% A key with no spelling moves the blame to the map, as F43's does. A key
%% that is not a name is spelled as a map entry's is.
unknown_keys_that_are_not_names_test() ->
    M = intake(),
    ?assertEqual(err([], <<"{ \"a\": int }">>, mismatch),
                 M:'Check'(#{<<"a">> => 1, {1, 2} => 3})),
    ?assertEqual(err([<<"[7]">>], <<"\"a\"">>, unknown_key),
                 M:'Check'(#{<<"a">> => 1, 7 => 3})).

%% An unknown key is found before a named key's value is looked at.
an_unknown_key_is_reported_before_a_wrong_value_test() ->
    ?assertEqual(err([<<"[\"b\"]">>], <<"\"a\"">>, unknown_key),
                 (intake()):'Read'(<<"{\"a\":\"x\",\"b\":2}">>)).

%%% F70.7 — several keys: which is reported, and what Expected lists

pair_src() ->
    "module VrPair\n"
    "type P = { \"a\": int, \"c\": int }\n"
    "public result<P, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<P>(body)\n".

an_absent_key_is_reported_before_an_unknown_one_test() ->
    M = build_and_load(pair_src(), 'VrPair'),
    ?assertEqual(err([<<"[\"c\"]">>], <<"int">>, missing),
                 M:'Read'(<<"{\"a\":1,\"b\":2}">>)).

the_first_absent_key_in_key_order_is_reported_test() ->
    M = build_and_load(pair_src(), 'VrPair'),
    ?assertEqual(err([<<"[\"a\"]">>], <<"int">>, missing), M:'Read'(<<"{}">>)).

expected_lists_every_key_the_type_names_test() ->
    M = build_and_load(pair_src(), 'VrPair'),
    ?assertEqual(err([<<"[\"z\"]">>], <<"\"a\" | \"c\"">>, unknown_key),
                 M:'Read'(<<"{\"a\":1,\"c\":2,\"z\":3,\"zz\":4}">>)).

%%% F70.8 — one field-set member beside others; several members

union_src() ->
    "module VrUnion\n"
    "type W = { \"a\": int }\n"
    "type V = { \"b\": int }\n"
    "public result<W | :null, ValidationError> One(string body)\n"
    "One(body) -> FromJson<W | :null>(body)\n"
    "public result<W | V, ValidationError> Two(string body)\n"
    "Two(body) -> FromJson<W | V>(body)\n".

one_field_set_beside_an_atom_still_names_the_key_test() ->
    M = build_and_load(union_src(), 'VrUnion'),
    ?assertEqual(null, M:'One'(<<"null">>)),
    ?assertEqual(err([<<"[\"a\"]">>], <<"int">>, missing), M:'One'(<<"{}">>)).

%% A `map<K, V>` member is a second member a map could belong to.
a_field_set_beside_a_domain_map_is_reported_whole_test() ->
    M = build_and_load("module VrDom\n"
                       "type W = { \"a\": int }\n"
                       "public result<W | map<int, int>, ValidationError> Check(term t)\n"
                       "Check(t) -> ValidateAs<W | map<int, int>>(t)\n", 'VrDom'),
    ?assertMatch({error, #{'Path' := [], 'Reason' := mismatch}},
                 M:'Check'(#{<<"a">> => 1, <<"b">> => 2})).

several_field_sets_are_reported_whole_as_a_mismatch_test() ->
    M = build_and_load(union_src(), 'VrUnion'),
    ?assertEqual(err([], <<"{ \"a\": int } | { \"b\": int }">>, mismatch),
                 M:'Two'(<<"{}">>)).

%%% F70.9 — the record has three fields wherever it is written

built_src(Fields) ->
    "module VrBuilt\n"
    "public ValidationError Built()\n"
    "Built() -> ValidationError { " ++ Fields ++ " }\n"
    "public atom Why(ValidationError e)\n"
    "Why(e) -> e.Reason\n".

a_hand_built_error_names_its_reason_test() ->
    M = build_and_load(built_src("Path = [], Expected = \"int\", Reason = :missing"),
                       'VrBuilt'),
    ?assertEqual(#{'Kind' => 'ValidationError', 'Path' => [],
                   'Expected' => <<"int">>, 'Reason' => missing},
                 M:'Built'()),
    ?assertEqual(missing, M:'Why'(M:'Built'())).

a_hand_built_error_without_a_reason_is_refused_test_() ->
    {timeout, 60,
     fun() ->
         with_src("vrbuilt.bs", built_src("Path = [], Expected = \"int\""),
             fun(Path, _Out) ->
                 {Rc, Output} = bs_test_support:run_cli_result(Path),
                 ?assertEqual(1, Rc),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "builds an ValidationError with the wrong fields")),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "missing, and must be supplied:\n    Reason"))
             end)
     end}.

a_reason_outside_the_five_is_refused_test_() ->
    {timeout, 60,
     fun() ->
         with_src("vrbuilt.bs",
             built_src("Path = [], Expected = \"int\", Reason = :other"),
             fun(Path, _Out) ->
                 {Rc, Output} = bs_test_support:run_cli_result(Path),
                 ?assertEqual(1, Rc),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "assigns Reason a value ValidationError does not accept")),
                 ?assertNotEqual(nomatch, string:find(Output, ":other"))
             end)
     end}.

%%% F70.10 — what is not a map is a mismatch of the whole type

a_value_that_is_not_an_object_is_a_mismatch_test() ->
    M = intake(),
    ?assertEqual(err([], <<"{ \"a\": int }">>, mismatch), M:'Read'(<<"[1]">>)),
    ?assertEqual(err([], <<"{ \"a\": int }">>, mismatch), M:'Check'(7)).
