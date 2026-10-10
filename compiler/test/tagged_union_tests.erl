%%% F72 — a union tagged by a string-literal key is validated by that key first.
%%% Scenarios: compiler/features/F72-tagged-union.md
-module(tagged_union_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/3]).

src() ->
    "module TuAnswers\n"
    "type AnswerWire = { \"type\": \"choice\", \"choice\": string, .. }\n"
    "                | { \"type\": \"score\", \"score\": int, .. }\n"
    "type Reply = { \"answers\": map<string, AnswerWire> }\n"
    "type Shape = { \"t\": \"circle\", \"r\": int } | { \"t\": \"rect\", \"w\": int, \"h\": int }\n"
    "type Noted = { \"type\": \"choice\", \"choice\": string, \"note\": option<string>, .. }\n"
    "           | { \"type\": \"score\", \"score\": int, .. }\n"
    "type NoTag = { \"a\": int } | { \"b\": int }\n"
    "type Wide = { \"t\": \"a\", \"x\": int } | { \"t\": string, \"y\": int }\n"
    "public result<AnswerWire, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<AnswerWire>(body)\n"
    "public result<AnswerWire, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<AnswerWire>(t)\n"
    "public result<Reply, ValidationError> ReadReply(string body)\n"
    "ReadReply(body) -> FromJson<Reply>(body)\n"
    "public result<list<AnswerWire>, ValidationError> ReadAll(string body)\n"
    "ReadAll(body) -> FromJson<list<AnswerWire>>(body)\n"
    "public result<Shape, ValidationError> ReadShape(string body)\n"
    "ReadShape(body) -> FromJson<Shape>(body)\n"
    "public string WriteShape(Shape s)\n"
    "WriteShape(s) -> ToJson<Shape>(s)\n"
    "public result<AnswerWire | :null, ValidationError> ReadMaybe(string body)\n"
    "ReadMaybe(body) -> FromJson<AnswerWire | :null>(body)\n"
    "public result<Noted, ValidationError> ReadNoted(string body)\n"
    "ReadNoted(body) -> FromJson<Noted>(body)\n"
    "public result<NoTag, ValidationError> ReadNoTag(string body)\n"
    "ReadNoTag(body) -> FromJson<NoTag>(body)\n"
    "public result<Wide, ValidationError> ReadWide(string body)\n"
    "ReadWide(body) -> FromJson<Wide>(body)\n".

answers() -> build_and_load(src(), 'TuAnswers').

tags() -> <<"\"choice\" | \"score\"">>.
at_tag(Reason) -> validation_error([<<"[\"type\"]">>], tags(), Reason).

%%% F72.1 — the three values ENG-618 names

a_tag_no_member_names_is_a_mismatch_at_the_tag_test() ->
    ?assertEqual(at_tag(mismatch),
                 (answers()):'Read'(<<"{\"type\":\"tri\",\"choice\":\"x\"}">>)).

a_named_tag_validates_against_its_member_alone_test() ->
    ?assertEqual(validation_error([<<"[\"score\"]">>], <<"int">>, mismatch),
                 (answers()):'Read'(<<"{\"type\":\"score\",\"score\":\"x\"}">>)).

an_absent_tag_is_missing_at_the_tag_test() ->
    ?assertEqual(at_tag(missing), (answers()):'Read'(<<"{\"choice\":\"x\"}">>)).

%%% F72.2 — a value that inhabits a member is returned as before

each_member_is_still_accepted_test() ->
    M = answers(),
    ?assertEqual(#{<<"type">> => <<"choice">>, <<"choice">> => <<"x">>, <<"extra">> => 1},
                 M:'Read'(<<"{\"type\":\"choice\",\"choice\":\"x\",\"extra\":1}">>)),
    ?assertEqual(#{<<"type">> => <<"score">>, <<"score">> => 3},
                 M:'Read'(<<"{\"type\":\"score\",\"score\":3}">>)).

%%% F72.3 — inside the member the tag names, F70's rules apply

a_key_the_named_member_requires_is_missing_at_that_key_test() ->
    ?assertEqual(validation_error([<<"[\"score\"]">>], <<"int">>, missing),
                 (answers()):'Read'(<<"{\"type\":\"score\"}">>)).

%% The other member's key says nothing about this one.
the_other_members_keys_do_not_excuse_this_one_test() ->
    ?assertEqual(validation_error([<<"[\"score\"]">>], <<"int">>, missing),
                 (answers()):'Read'(<<"{\"type\":\"score\",\"choice\":\"x\"}">>)).

an_exact_member_names_a_key_it_does_not_have_test() ->
    M = answers(),
    ?assertEqual(#{<<"t">> => <<"circle">>, <<"r">> => 2},
                 M:'ReadShape'(<<"{\"t\":\"circle\",\"r\":2}">>)),
    ?assertEqual(validation_error([<<"[\"w\"]">>], <<"\"r\" | \"t\"">>, unknown_key),
                 M:'ReadShape'(<<"{\"t\":\"circle\",\"r\":2,\"w\":3}">>)),
    ?assertEqual(validation_error([<<"[\"h\"]">>], <<"int">>, missing),
                 M:'ReadShape'(<<"{\"t\":\"rect\",\"w\":3}">>)),
    ?assertEqual(validation_error([<<"[\"t\"]">>], <<"\"circle\" | \"rect\"">>, mismatch),
                 M:'ReadShape'(<<"{\"t\":\"tri\",\"r\":2}">>)).

%%% F72.4 — a tag that is not a string, and a value that is not a map

a_tag_of_another_type_is_a_mismatch_at_the_tag_test() ->
    M = answers(),
    ?assertEqual(at_tag(mismatch), M:'Read'(<<"{\"type\":7,\"score\":1}">>)),
    ?assertEqual(at_tag(mismatch), M:'Read'(<<"{\"type\":null}">>)).

a_value_that_is_not_a_map_is_the_whole_union_test() ->
    ?assertMatch({error, #{'Path' := [], 'Reason' := mismatch}},
                 (answers()):'Read'(<<"7">>)).

%%% F72.5 — the path is the union's own path followed by the tag's

the_tag_is_blamed_under_a_map_entry_test() ->
    M = answers(),
    ?assertEqual(validation_error([<<"[\"answers\"]">>, <<"[\"q\"]">>, <<"[\"type\"]">>],
                                  tags(), mismatch),
                 M:'ReadReply'(<<"{\"answers\":{\"q\":{\"type\":\"tri\"}}}">>)),
    ?assertEqual(validation_error([<<"[\"answers\"]">>, <<"[\"q\"]">>, <<"[\"score\"]">>],
                                  <<"int">>, mismatch),
                 M:'ReadReply'(<<"{\"answers\":{\"q\":{\"type\":\"score\",\"score\":\"x\"}}}">>)).

the_tag_is_blamed_under_a_list_element_test() ->
    ?assertEqual(validation_error([<<"[1]">>, <<"[\"type\"]">>], tags(), missing),
                 (answers()):'ReadAll'(
                   <<"[{\"type\":\"score\",\"score\":1},{\"score\":2}]">>)).

%%% F72.6 — a member that is not a map stands beside the tagged ones

a_non_map_member_is_accepted_and_the_rest_use_the_tag_test() ->
    M = answers(),
    ?assertEqual(null, M:'ReadMaybe'(<<"null">>)),
    ?assertEqual(#{<<"type">> => <<"score">>, <<"score">> => 3},
                 M:'ReadMaybe'(<<"{\"type\":\"score\",\"score\":3}">>)),
    ?assertEqual(at_tag(mismatch), M:'ReadMaybe'(<<"{\"type\":\"tri\"}">>)),
    ?assertEqual(at_tag(missing), M:'ReadMaybe'(<<"{}">>)).

%%% F72.7 — the named member still fills its absent option key (F61)

the_named_member_fills_its_absent_option_key_test() ->
    M = answers(),
    ?assertEqual(#{<<"type">> => <<"choice">>, <<"choice">> => <<"x">>, <<"note">> => nothing},
                 M:'ReadNoted'(<<"{\"type\":\"choice\",\"choice\":\"x\"}">>)),
    ?assertEqual(#{<<"type">> => <<"choice">>, <<"choice">> => <<"x">>, <<"note">> => <<"n">>},
                 M:'ReadNoted'(<<"{\"type\":\"choice\",\"choice\":\"x\",\"note\":\"n\"}">>)),
    ?assertEqual(validation_error([<<"[\"choice\"]">>], <<"string">>, missing),
                 M:'ReadNoted'(<<"{\"type\":\"choice\"}">>)),
    ?assertEqual(validation_error([<<"[\"type\"]">>], tags(), mismatch),
                 M:'ReadNoted'(<<"{\"type\":\"tri\"}">>)).

%%% F72.8 — ValidateAs shares it

validate_as_reads_the_tag_first_test() ->
    M = answers(),
    ?assertEqual(at_tag(mismatch), M:'Check'(#{<<"type">> => <<"tri">>})),
    ?assertEqual(at_tag(missing), M:'Check'(#{<<"choice">> => <<"x">>})),
    ?assertEqual(validation_error([<<"[\"score\"]">>], <<"int">>, mismatch),
                 M:'Check'(#{<<"type">> => <<"score">>, <<"score">> => 1.5})),
    ?assertEqual(#{<<"type">> => <<"score">>, <<"score">> => 1},
                 M:'Check'(#{<<"type">> => <<"score">>, <<"score">> => 1})).

%%% F72.9 — ToJson's guard is the same validator, strict

to_json_writes_a_tagged_member_and_names_what_is_wrong_test() ->
    M = answers(),
    ?assertEqual(#{<<"t">> => <<"rect">>, <<"w">> => 1, <<"h">> => 2},
                 json:decode(M:'WriteShape'(#{<<"t">> => <<"rect">>, <<"w">> => 1, <<"h">> => 2}))),
    ?assertError({to_json, #{'Path' := [<<"[\"h\"]">>], 'Reason' := missing}},
                 M:'WriteShape'(#{<<"t">> => <<"rect">>, <<"w">> => 1})).

%%% F72.10 — a union with no such key is reported as before

a_union_with_no_shared_key_is_reported_whole_test() ->
    M = answers(),
    ?assertEqual(#{<<"a">> => 1}, M:'ReadNoTag'(<<"{\"a\":1}">>)),
    ?assertMatch({error, #{'Path' := [], 'Reason' := mismatch}},
                 M:'ReadNoTag'(<<"{\"c\":1}">>)).

%% One member's `"t"` is any string, so `"t"` does not say which member.
a_key_that_is_a_literal_in_one_member_only_is_not_a_tag_test() ->
    M = answers(),
    ?assertEqual(#{<<"t">> => <<"a">>, <<"x">> => 1}, M:'ReadWide'(<<"{\"t\":\"a\",\"x\":1}">>)),
    ?assertEqual(#{<<"t">> => <<"q">>, <<"y">> => 1}, M:'ReadWide'(<<"{\"t\":\"q\",\"y\":1}">>)),
    ?assertMatch({error, #{'Path' := [], 'Reason' := mismatch}},
                 M:'ReadWide'(<<"{\"t\":7}">>)).

%%% F72.12 — which key is the tag, and a member with several literals

more_src() ->
    "module TuMore\n"
    "type Two = { \"kind\": \"a\", \"type\": \"x\" } | { \"kind\": \"b\", \"type\": \"y\" }\n"
    "type Several = { \"t\": \"a\" | \"b\", \"x\": int } | { \"t\": \"c\", \"y\": int }\n"
    "record Circle { Shape: \"circle\", R: int }\n"
    "record Rect { Shape: \"rect\", W: int }\n"
    "public result<Two, ValidationError> ReadTwo(string body)\n"
    "ReadTwo(body) -> FromJson<Two>(body)\n"
    "public result<Several, ValidationError> ReadSeveral(string body)\n"
    "ReadSeveral(body) -> FromJson<Several>(body)\n"
    "public result<Circle | Rect, ValidationError> CheckShape(term t)\n"
    "CheckShape(t) -> ValidateAs<Circle | Rect>(t)\n".

%% Either key would serve; the first in key order is read.
of_two_keys_that_would_serve_the_first_in_key_order_is_the_tag_test() ->
    M = build_and_load(more_src(), 'TuMore'),
    ?assertEqual(validation_error([<<"[\"kind\"]">>], <<"\"a\" | \"b\"">>, mismatch),
                 M:'ReadTwo'(<<"{\"kind\":\"q\",\"type\":\"q\"}">>)),
    ?assertEqual(validation_error([<<"[\"type\"]">>], <<"\"x\"">>, mismatch),
                 M:'ReadTwo'(<<"{\"kind\":\"a\",\"type\":\"y\"}">>)).

a_member_may_be_named_by_several_literals_test() ->
    M = build_and_load(more_src(), 'TuMore'),
    ?assertEqual(#{<<"t">> => <<"b">>, <<"x">> => 1}, M:'ReadSeveral'(<<"{\"t\":\"b\",\"x\":1}">>)),
    ?assertEqual(validation_error([<<"[\"x\"]">>], <<"int">>, missing),
                 M:'ReadSeveral'(<<"{\"t\":\"b\",\"y\":1}">>)),
    ?assertEqual(validation_error([<<"[\"t\"]">>], <<"\"a\" | \"b\" | \"c\"">>, mismatch),
                 M:'ReadSeveral'(<<"{\"t\":\"d\"}">>)).

%% Two records sharing a literal field: the field picks the record, and the
%% record's own validator then asks about `Kind` (F70).
records_sharing_a_literal_field_are_told_apart_by_it_test() ->
    M = build_and_load(more_src(), 'TuMore'),
    Circle = #{'Kind' => 'TuMore.Circle', 'Shape' => <<"circle">>, 'R' => 1},
    ?assertEqual(Circle, M:'CheckShape'(Circle)),
    ?assertEqual(validation_error([<<".R">>], <<"int">>, mismatch),
                 M:'CheckShape'(Circle#{'R' := <<"x">>})),
    ?assertEqual(validation_error([<<".Kind">>], <<":'TuMore.Circle'">>, missing),
                 M:'CheckShape'(#{'Shape' => <<"circle">>, 'R' => 1})),
    ?assertEqual(validation_error([<<".Shape">>], <<"\"circle\" | \"rect\"">>, mismatch),
                 M:'CheckShape'(Circle#{'Shape' := <<"tri">>})).
