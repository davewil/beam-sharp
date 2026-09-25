%%% Scenarios: compiler/features/F61-absent-option-key.md
%%% F61 — `ValidateAs` reads an absent key at an `option<T>` field as `:nothing`.
%%%
%%% Ticket 26 §4: a record has no absent fields, and the boundary turns an
%%% absent key into `:nothing`. Ticket 78 Q8 extended that to wire types and
%%% kept JSON `null` apart. Each test runs the compiled validator on a term and
%%% asserts the value it returns.

-module(absent_option_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/2]).

src(Ty, Decls) ->
    "module Absent\n"
    ++ Decls ++
    "type Target = " ++ Ty ++ "\n"
    "public result<Target, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<Target>(t)\n".

load(Ty) -> load(Ty, "").
load(Ty, Decls) -> build_and_load(src(Ty, Decls), 'Absent').

wire() -> "{ Id: option<string>, Model: string }".
rec()  -> "record R { Id: option<string>, Model: string }\n".

%%% F61.1 — a field set: absent is filled, present is kept.

an_absent_option_key_in_a_field_set_is_nothing_test() ->
    M = load(wire()),
    ?assertEqual(#{'Id' => nothing, 'Model' => <<"m">>}, M:'Check'(#{'Model' => <<"m">>})).

a_present_option_key_comes_back_unchanged_test() ->
    M = load(wire()),
    In = #{'Id' => <<"x">>, 'Model' => <<"m">>},
    ?assertEqual(In, M:'Check'(In)).

%%% F61.2 — a record: the same, with its tag kept.

an_absent_option_field_in_a_record_is_nothing_test() ->
    M = load("R", rec()),
    ?assertEqual(#{'Kind' => 'Absent.R', 'Id' => nothing, 'Model' => <<"m">>},
                 M:'Check'(#{'Kind' => 'Absent.R', 'Model' => <<"m">>})).

%%% F61.3 — JSON `null` is not absent.

null_at_an_option_field_is_still_refused_at_its_key_test() ->
    M = load(wire()),
    ?assertEqual(validation_error([<<".Id">>], <<":nothing | string">>),
                 M:'Check'(#{'Id' => null, 'Model' => <<"m">>})).

an_option_that_admits_null_keeps_null_and_fills_absent_test() ->
    M = load("{ Id: option<string | :null>, Model: string }"),
    Null = #{'Id' => null, 'Model' => <<"m">>},
    ?assertEqual(Null, M:'Check'(Null)),
    ?assertEqual(#{'Id' => nothing, 'Model' => <<"m">>}, M:'Check'(#{'Model' => <<"m">>})).

%%% F61.4 — the fill reaches every depth the validator walks.

a_record_inside_a_record_is_filled_test() ->
    M = load("Outer", rec() ++ "record Outer { Inner: R, N: int }\n"),
    In = #{'Kind' => 'Absent.Outer', 'N' => 1,
           'Inner' => #{'Kind' => 'Absent.R', 'Model' => <<"m">>}},
    ?assertEqual(In#{'Inner' => #{'Kind' => 'Absent.R', 'Id' => nothing, 'Model' => <<"m">>}},
                 M:'Check'(In)).

a_list_element_is_filled_and_its_neighbours_kept_test() ->
    M = load("list<" ++ wire() ++ ">"),
    Kept = #{'Id' => <<"a">>, 'Model' => <<"m">>},
    ?assertEqual([Kept, #{'Id' => nothing, 'Model' => <<"n">>}],
                 M:'Check'([Kept, #{'Model' => <<"n">>}])).

a_tuple_component_is_filled_test() ->
    M = load("(int, " ++ wire() ++ ")"),
    ?assertEqual({1, #{'Id' => nothing, 'Model' => <<"m">>}},
                 M:'Check'({1, #{'Model' => <<"m">>}})).

a_map_value_is_filled_test() ->
    M = load("map<string, " ++ wire() ++ ">"),
    ?assertEqual(#{<<"a">> => #{'Id' => nothing, 'Model' => <<"m">>},
                   <<"b">> => #{'Id' => <<"x">>, 'Model' => <<"m">>}},
                 M:'Check'(#{<<"a">> => #{'Model' => <<"m">>},
                             <<"b">> => #{'Id' => <<"x">>, 'Model' => <<"m">>}})).

a_failure_deeper_than_a_fill_keeps_its_path_test() ->
    M = load("list<" ++ wire() ++ ">"),
    ?assertEqual(validation_error([<<"[1]">>, <<".Model">>], <<"string">>),
                 M:'Check'([#{'Model' => <<"m">>}, #{'Model' => 7}])).

%%% F61.5 — only an `option<T>` field is filled.

an_absent_atom_field_is_refused_test() ->
    M = load("{ Tag: atom, Model: string }"),
    ?assertEqual(validation_error([], <<"{ Model: string, Tag: atom }">>),
                 M:'Check'(#{'Model' => <<"m">>})).

an_absent_required_key_is_refused_test() ->
    M = load(wire()),
    ?assertEqual(validation_error([], <<"{ Id: :nothing | string, Model: string }">>),
                 M:'Check'(#{'Id' => <<"x">>})).

an_unknown_key_beside_an_absent_option_is_refused_test() ->
    M = load(wire()),
    ?assertEqual(validation_error([], <<"{ Id: :nothing | string, Model: string }">>),
                 M:'Check'(#{'Model' => <<"m">>, 'Extra' => 1})).

%%% F61.6 — ticket 78 Q8's program on both providers' replies.

reply_src() ->
    "module Reply61\n"
    "type ReplyWire = { \"id\": option<string>, \"model\": string, "
    "\"refusal\": string | :null, .. }\n"
    "public result<ReplyWire, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<ReplyWire>(t)\n".

typesafe_reply_gets_nothing_and_keeps_its_extras_test() ->
    M = build_and_load(reply_src(), 'Reply61'),
    Doc = json:decode(<<"{\"model\":\"typesafe/jev-1.13\",\"refusal\":null,\"usage\":{}}">>),
    ?assertEqual(Doc#{<<"id">> => nothing}, M:'Read'(Doc)).

openrouter_reply_keeps_its_id_test() ->
    M = build_and_load(reply_src(), 'Reply61'),
    Doc = json:decode(<<"{\"id\":\"gen-jev-test\",\"model\":\"typesafe/jev-1.13\","
                        "\"refusal\":null}">>),
    ?assertEqual(Doc, M:'Read'(Doc)).

%%% F61.7 — each member gets its own attempt, in turn.

the_second_member_fills_when_the_first_cannot_test() ->
    M = load("A | B", "type A = { Id: option<string>, Model: string }\n"
                      "type B = { Model: string, Note: option<string>, Tag: option<int> }\n"),
    ?assertEqual(#{'Model' => <<"m">>, 'Note' => <<"n">>, 'Tag' => nothing},
                 M:'Check'(#{'Model' => <<"m">>, 'Note' => <<"n">>})).

%%% F61.8 — `ToJson` converts nothing.

to_json_src() ->
    "module Json61\n"
    ++ rec() ++
    "public string Body(R r)\n"
    "Body(r) -> ToJson<R>(r)\n".

to_json_on_an_absent_option_still_crashes_test() ->
    M = build_and_load(to_json_src(), 'Json61'),
    ?assertError({to_json, #{'Kind' := 'ValidationError', 'Path' := []}},
                 M:'Body'(#{'Kind' => 'Json61.R', 'Model' => <<"m">>})).

%% The blame is where the key is missing, as it was before F61, not the root.
to_json_blames_an_absent_option_at_its_depth_test() ->
    M = build_and_load("module Json61b\n" ++ rec() ++
                       "public string Body(list<R> rs)\n"
                       "Body(rs) -> ToJson<list<R>>(rs)\n", 'Json61b'),
    ?assertError({to_json, #{'Path' := [<<"[0]">>],
                             'Expected' := <<"{ Kind: :'Json61b.R', Id: :nothing | string, Model: string }">>}},
                 M:'Body'([#{'Kind' => 'Json61b.R', 'Model' => <<"m">>}])).

to_json_on_a_whole_value_encodes_nothing_as_before_test() ->
    M = build_and_load(to_json_src(), 'Json61'),
    ?assertEqual(#{<<"Kind">> => <<"Json61.R">>, <<"Id">> => <<"nothing">>,
                   <<"Model">> => <<"m">>},
                 json:decode(M:'Body'(#{'Kind' => 'Json61.R', 'Id' => nothing,
                                        'Model' => <<"m">>}))).
