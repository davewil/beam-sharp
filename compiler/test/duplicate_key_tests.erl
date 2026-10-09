%%% F71 — FromJson refuses JSON with a repeated key, and text after the value.
%%% Scenarios: compiler/features/F71-duplicate-key.md
-module(duplicate_key_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/3]).

src() ->
    "module DkIntake\n"
    "type W = { \"a\": int }\n"
    "type Open = { \"a\": int, .. }\n"
    "type Deep = { \"in\": W, \"all\": list<W> }\n"
    "public result<W, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<W>(body)\n"
    "public result<Open, ValidationError> ReadOpen(string body)\n"
    "ReadOpen(body) -> FromJson<Open>(body)\n"
    "public result<Deep, ValidationError> ReadDeep(string body)\n"
    "ReadDeep(body) -> FromJson<Deep>(body)\n"
    "public result<int, ValidationError> ReadInt(string body)\n"
    "ReadInt(body) -> FromJson<int>(body)\n"
    "public string Why(string body)\n"
    "Why(body) -> Read(body) switch {\n"
    "    (:error, ValidationError { Reason: :duplicate_key, Expected: e }) => e,\n"
    "    (:error, e) => \"another reason\",\n"
    "    w           => \"fine\"\n"
    "}\n".

intake() -> build_and_load(src(), 'DkIntake').

repeated(Key) ->
    validation_error([], <<"\"", Key/binary, "\" once">>, duplicate_key).

not_json() -> validation_error([], <<"JSON">>, not_json).

%%% F71.1 — a repeated key is refused, and the error carries the key

a_repeated_key_is_refused_test() ->
    ?assertEqual(repeated(<<"a">>), (intake()):'Read'(<<"{\"a\":1,\"a\":\"x\"}">>)).

%% The second value is the one the old decoder dropped unvalidated, so the
%% order of the two must not matter.
a_repeated_key_is_refused_whichever_value_is_wrong_test() ->
    ?assertEqual(repeated(<<"a">>), (intake()):'Read'(<<"{\"a\":\"x\",\"a\":1}">>)).

%%% F71.2 — `Path` is `[]` however deep the object sits

a_repeated_key_in_a_nested_object_is_refused_at_the_top_test() ->
    ?assertEqual(repeated(<<"a">>),
                 (intake()):'ReadDeep'(<<"{\"in\":{\"a\":1,\"a\":2},\"all\":[]}">>)).

a_repeated_key_in_a_list_element_is_refused_at_the_top_test() ->
    ?assertEqual(repeated(<<"a">>),
                 (intake()):'ReadDeep'(
                   <<"{\"in\":{\"a\":1},\"all\":[{\"a\":1},{\"a\":1,\"a\":2}]}">>)).

%% One key in two objects is each object's own key, not a repeat.
the_same_key_in_two_objects_is_not_a_repeat_test() ->
    ?assertEqual(#{<<"in">> => #{<<"a">> => 1},
                   <<"all">> => [#{<<"a">> => 2}, #{<<"a">> => 3}]},
                 (intake()):'ReadDeep'(
                   <<"{\"in\":{\"a\":1},\"all\":[{\"a\":2},{\"a\":3}]}">>)).

%%% F71.3 — refused when the two values are equal, and when the type is open
%%% and does not name the key

two_equal_values_are_still_a_repeat_test() ->
    ?assertEqual(repeated(<<"a">>), (intake()):'Read'(<<"{\"a\":1,\"a\":1}">>)).

a_repeated_key_an_open_type_does_not_name_is_refused_test() ->
    M = intake(),
    ?assertEqual(repeated(<<"cost">>),
                 M:'ReadOpen'(<<"{\"a\":1,\"cost\":1,\"cost\":2}">>)),
    ?assertEqual(#{<<"a">> => 1, <<"cost">> => 1},
                 M:'ReadOpen'(<<"{\"a\":1,\"cost\":1}">>)).

%% Two spellings of one key are one key: the decoder compares what the
%% escapes decode to.
a_key_repeated_under_an_escape_is_a_repeat_test() ->
    ?assertEqual(repeated(<<"a">>), (intake()):'Read'(<<"{\"a\":1,\"\\u0061\":2}">>)).

%% The repeat is found by the decoder, before the type is consulted.
a_repeat_is_reported_before_what_the_type_would_say_test() ->
    ?assertEqual(repeated(<<"b">>), (intake()):'Read'(<<"{\"b\":1,\"b\":2}">>)),
    ?assertEqual(repeated(<<"a">>), (intake()):'ReadInt'(<<"{\"a\":1,\"a\":2}">>)).

%%% F71.4 — a clause head reads the reason and the key

a_clause_matches_the_reason_test() ->
    M = intake(),
    ?assertEqual(<<"\"a\" once">>, M:'Why'(<<"{\"a\":1,\"a\":2}">>)),
    ?assertEqual(<<"another reason">>, M:'Why'(<<"{}">>)),
    ?assertEqual(<<"fine">>, M:'Why'(<<"{\"a\":1}">>)).

%%% F71.5 — text after the value is not JSON; whitespace after it is nothing

text_after_the_value_is_not_json_test() ->
    M = intake(),
    ?assertEqual(not_json(), M:'Read'(<<"{\"a\":1} x">>)),
    ?assertEqual(not_json(), M:'Read'(<<"{\"a\":1}{\"a\":1}">>)),
    ?assertEqual(not_json(), M:'ReadInt'(<<"12x">>)),
    ?assertEqual(not_json(), M:'ReadInt'(<<"1 2">>)),
    ?assertEqual(not_json(), M:'Read'(<<"{\"a\":1}", 16#FF>>)).

whitespace_around_the_value_is_accepted_test() ->
    M = intake(),
    ?assertEqual(#{<<"a">> => 1}, M:'Read'(<<" {\"a\":1} \t\r\n">>)),
    ?assertEqual(7, M:'ReadInt'(<<"7\n">>)),
    ?assertEqual(7, M:'ReadInt'(<<"7">>)).

%% A form feed is whitespace to some parsers and not to JSON.
whitespace_json_does_not_name_is_text_test() ->
    ?assertEqual(not_json(), (intake()):'Read'(<<"{\"a\":1}\f">>)).

%% Text that stops inside the second value never pushes it.
text_that_ends_inside_a_repeat_is_not_json_test() ->
    ?assertEqual(not_json(), (intake()):'Read'(<<"{\"a\":1,\"a\":">>)).
