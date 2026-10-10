%%% F73 — under FromJson, a float position reads a JSON integer.
%%% Scenarios: compiler/features/F73-float-reads-integer.md
-module(float_reads_integer_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/2, validation_error/3]).

src() ->
    "module FrPrices\n"
    "type F = { \"price\": float }\n"
    "type Deep = { \"all\": list<float>, \"by\": map<string, float>,\n"
    "              \"in\": F, \"tip\": option<float> }\n"
    "type Tagged = { \"t\": \"a\", \"v\": float } | { \"t\": \"b\", \"v\": string }\n"
    "type Shapes = { \"a\": float } | { \"b\": float }\n"
    "type Alts = { \"v\": float } | { \"v\": string }\n"
    "type Split = { \"v\": float } | { \"v\": int }\n"
    "type SplitOpen = { \"a\": int, .. } | { \"a\": float, .. }\n"
    "type Pair = { \"v\": float, \"w\": float } | { \"v\": int, \"w\": float }\n"
    "type Whole = { \"a\": int }\n"
    "type Either = { \"n\": int | float }\n"
    "type Pct = int where value >= 0 and value <= 100\n"
    "type Small = { \"n\": Pct | float }\n"
    "public result<F, ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<F>(body)\n"
    "public result<float, ValidationError> ReadFloat(string body)\n"
    "ReadFloat(body) -> FromJson<float>(body)\n"
    "public result<Deep, ValidationError> ReadDeep(string body)\n"
    "ReadDeep(body) -> FromJson<Deep>(body)\n"
    "public result<Tagged, ValidationError> ReadTagged(string body)\n"
    "ReadTagged(body) -> FromJson<Tagged>(body)\n"
    "public result<Shapes, ValidationError> ReadShapes(string body)\n"
    "ReadShapes(body) -> FromJson<Shapes>(body)\n"
    "public result<Alts, ValidationError> ReadAlts(string body)\n"
    "ReadAlts(body) -> FromJson<Alts>(body)\n"
    "public result<float | string, ValidationError> ReadEitherTop(string body)\n"
    "ReadEitherTop(body) -> FromJson<float | string>(body)\n"
    "public result<Split, ValidationError> ReadSplit(string body)\n"
    "ReadSplit(body) -> FromJson<Split>(body)\n"
    "public result<list<SplitOpen>, ValidationError> ReadSplitOpen(string body)\n"
    "ReadSplitOpen(body) -> FromJson<list<SplitOpen>>(body)\n"
    "public result<Pair, ValidationError> ReadPair(string body)\n"
    "ReadPair(body) -> FromJson<Pair>(body)\n"
    "public result<Whole, ValidationError> ReadWhole(string body)\n"
    "ReadWhole(body) -> FromJson<Whole>(body)\n"
    "public result<Either, ValidationError> ReadEither(string body)\n"
    "ReadEither(body) -> FromJson<Either>(body)\n"
    "public result<Small, ValidationError> ReadSmall(string body)\n"
    "ReadSmall(body) -> FromJson<Small>(body)\n"
    "public result<F, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<F>(t)\n"
    "public result<Deep, ValidationError> CheckDeep(term t)\n"
    "CheckDeep(t) -> ValidateAs<Deep>(t)\n"
    "public float Doubled(string body)\n"
    "Doubled(body) -> FromJson<F>(body) switch {\n"
    "    (:error, e)    => 0.0,\n"
    "    { \"price\": p } => p + p\n"
    "}\n".

prices() -> build_and_load(src(), 'FrPrices').

price(Text) -> <<"{\"price\":", Text/binary, "}">>.

not_a_float(Path) -> validation_error(Path, <<"float">>).

%%% F73.1 — a float field given a JSON integer holds that float

a_float_field_reads_an_integer_test() ->
    M = prices(),
    ?assertEqual(#{<<"price">> => 1.0}, M:'Read'(price(<<"1">>))),
    ?assertEqual(#{<<"price">> => -3.0}, M:'Read'(price(<<"-3">>))),
    ?assertEqual(#{<<"price">> => 0.0}, M:'Read'(price(<<"0">>))),
    ?assertEqual(#{<<"price">> => 0.5}, M:'Read'(price(<<"0.5">>))).

%% What comes back is a float to the program that reads it.
the_value_read_is_a_float_to_the_program_test() ->
    ?assertEqual(2.0, (prices()):'Doubled'(price(<<"1">>))).

%%% F73.2 — at the top level, in a list, a map value and a union member

a_float_at_the_top_reads_an_integer_test() ->
    M = prices(),
    ?assertEqual(7.0, M:'ReadFloat'(<<"7">>)),
    ?assertEqual(7.0, M:'ReadEitherTop'(<<"7">>)),
    ?assertEqual(<<"x">>, M:'ReadEitherTop'(<<"\"x\"">>)).

a_float_in_a_list_a_map_and_a_nested_object_reads_an_integer_test() ->
    ?assertEqual(#{<<"all">> => [1.0, 2.5, 3.0], <<"by">> => #{<<"a">> => 4.0},
                   <<"in">> => #{<<"price">> => 5.0}, <<"tip">> => 6.0},
                 (prices()):'ReadDeep'(
                   <<"{\"all\":[1,2.5,3],\"by\":{\"a\":4},\"in\":{\"price\":5},\"tip\":6}">>)).

%% F61's fill and this conversion in one read.
an_absent_option_key_is_still_filled_beside_a_converted_float_test() ->
    ?assertEqual(#{<<"all">> => [1.0], <<"by">> => #{},
                   <<"in">> => #{<<"price">> => 5.0}, <<"tip">> => nothing},
                 (prices()):'ReadDeep'(<<"{\"all\":[1],\"by\":{},\"in\":{\"price\":5}}">>)).

a_float_in_a_tagged_union_member_reads_an_integer_test() ->
    M = prices(),
    ?assertEqual(#{<<"t">> => <<"a">>, <<"v">> => 2.0},
                 M:'ReadTagged'(<<"{\"t\":\"a\",\"v\":2}">>)),
    ?assertEqual(validation_error([<<"[\"v\"]">>], <<"string">>),
                 M:'ReadTagged'(<<"{\"t\":\"b\",\"v\":2}">>)).

%% Members told apart by their keys, and members tried in turn: the one that
%% takes the value answers with its own.
a_float_in_an_untagged_union_member_reads_an_integer_test() ->
    M = prices(),
    ?assertEqual(#{<<"b">> => 2.0}, M:'ReadShapes'(<<"{\"b\":2}">>)),
    ?assertEqual(#{<<"v">> => 2.0}, M:'ReadAlts'(<<"{\"v\":2}">>)),
    ?assertEqual(#{<<"v">> => <<"x">>}, M:'ReadAlts'(<<"{\"v\":\"x\"}">>)).

%%% F73.3 — an integer with no exact float is refused, expecting `float`

an_integer_with_no_exact_float_is_refused_test() ->
    M = prices(),
    %% 2^53 + 1 is the first integer a float cannot hold; 2^53 is held.
    ?assertEqual(not_a_float([<<"[\"price\"]">>]), M:'Read'(price(<<"9007199254740993">>))),
    ?assertEqual(#{<<"price">> => 9007199254740992.0},
                 M:'Read'(price(<<"9007199254740992">>))),
    ?assertEqual(#{<<"price">> => 1152921504606846976.0},
                 M:'Read'(price(<<"1152921504606846976">>))),
    ?assertEqual(not_a_float([]), M:'ReadFloat'(<<"-9007199254740993">>)).

%% Past the largest float there is none to round to.
an_integer_past_the_largest_float_is_refused_test() ->
    Huge = iolist_to_binary([$1 | lists:duplicate(400, $0)]),
    ?assertEqual(not_a_float([<<"[\"price\"]">>]), (prices()):'Read'(price(Huge))).

%%% F73.4 — an int position still refuses a JSON number with a fraction part

an_int_position_still_refuses_a_float_test() ->
    ?assertEqual(validation_error([<<"[\"a\"]">>], <<"int">>),
                 (prices()):'ReadWhole'(<<"{\"a\":1.0}">>)).

%%% F73.5 — ValidateAs over a term holding an integer is unchanged

validate_as_still_refuses_an_integer_at_a_float_test() ->
    M = prices(),
    ?assertEqual(not_a_float([<<"[\"price\"]">>]), M:'Check'(#{<<"price">> => 1})),
    ?assertEqual(#{<<"price">> => 1.0}, M:'Check'(#{<<"price">> => 1.0})),
    ?assertEqual(not_a_float([<<"[\"all\"]">>, <<"[0]">>]),
                 M:'CheckDeep'(#{<<"all">> => [1], <<"by">> => #{},
                                 <<"in">> => #{<<"price">> => 5.0}})).

%%% F73.6 — where the type holds the integer itself, the integer is returned

an_int_or_float_position_keeps_the_integer_test() ->
    M = prices(),
    ?assertEqual(#{<<"n">> => 1}, M:'ReadEither'(<<"{\"n\":1}">>)),
    ?assertEqual(#{<<"n">> => 1.5}, M:'ReadEither'(<<"{\"n\":1.5}">>)),
    %% No float is needed for an integer an `int` holds, however large.
    ?assertEqual(#{<<"n">> => 9007199254740993},
                 M:'ReadEither'(<<"{\"n\":9007199254740993}">>)).

%% Only the integers the type names stay integers.
an_integer_the_type_does_not_name_is_read_as_the_float_test() ->
    M = prices(),
    ?assertEqual(#{<<"n">> => 50}, M:'ReadSmall'(<<"{\"n\":50}">>)),
    ?assertEqual(#{<<"n">> => 200.0}, M:'ReadSmall'(<<"{\"n\":200}">>)).

%%% F73.9 — `int | float` written as two members keeps the integer too

%% Members tried in turn are each asked for the value as it is before any is
%% asked to read it as a float, whichever is written first.
an_integer_one_member_holds_is_not_read_as_another_members_float_test() ->
    M = prices(),
    ?assertEqual(#{<<"v">> => 1}, M:'ReadSplit'(<<"{\"v\":1}">>)),
    ?assertEqual(#{<<"v">> => 1.5}, M:'ReadSplit'(<<"{\"v\":1.5}">>)),
    ?assertEqual(#{<<"v">> => 9007199254740993},
                 M:'ReadSplit'(<<"{\"v\":9007199254740993}">>)),
    ?assertEqual([#{<<"a">> => 1}, #{<<"a">> => 0.5, <<"x">> => 2}],
                 M:'ReadSplitOpen'(<<"[{\"a\":1},{\"a\":0.5,\"x\":2}]">>)).

%% Where no member holds the value as it is, one that can read it does. Which
%% of two that both can is the compiler's order of the members, so only what
%% both agree on is asserted.
a_member_that_must_read_a_float_is_still_found_test() ->
    M = prices(),
    ?assertMatch(#{<<"w">> := 2.0}, M:'ReadPair'(<<"{\"v\":1,\"w\":2}">>)),
    ?assertEqual(#{<<"v">> => 1, <<"w">> => 2.5}, M:'ReadPair'(<<"{\"v\":1,\"w\":2.5}">>)).
