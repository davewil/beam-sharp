%%% Scenarios: compiler/features/F68-string-literal-types.md
%%% F68 — a string literal is a type.
%%%
%%% The fixture is a streaming API's events, which are told apart by the value
%%% at `"type"` and by nothing else: `message_stop` and `ping` carry no other
%%% key. `{ "type": "ping", .. }` is a member a clause head can name, and a
%%% union of such members is covered without `_`.

-module(string_literal_type_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1]).

tags(Src) -> [element(1, element(4, E)) || E <- errors(Src)].

events_src(Clauses) ->
    "module Ev1\n"
    "type Start = { \"type\": \"content_block_start\", \"index\": int, .. }\n"
    "type Stop  = { \"type\": \"message_stop\", .. }\n"
    "type Ping  = { \"type\": \"ping\", .. }\n"
    "type Event = Start | Stop | Ping\n"
    "public atom Kind(Event e)\n" ++ Clauses.

all_three() ->
    "Kind({ \"type\": \"content_block_start\" }) -> :start\n"
    "Kind({ \"type\": \"message_stop\" })        -> :stop\n"
    "Kind({ \"type\": \"ping\" })                -> :ping\n".

%% F68.1 — a union tagged by a string literal is covered without `_`, and runs.
a_literal_tagged_union_is_exhaustive_test() ->
    M = build_and_load(events_src(all_three()), 'Ev1'),
    ?assertEqual(stop, M:'Kind'(#{<<"type">> => <<"message_stop">>})),
    ?assertEqual(ping, M:'Kind'(#{<<"type">> => <<"ping">>, <<"extra">> => 1})),
    ?assertEqual(start, M:'Kind'(#{<<"type">> => <<"content_block_start">>,
                                   <<"index">> => 0})).

%% F68.2 — a member left out is named by its tag, at `bsc`.
the_residual_names_the_missing_tag_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("ev2.bs",
             "module Ev2\n"
             "type Stop  = { \"type\": \"message_stop\", .. }\n"
             "type Ping  = { \"type\": \"ping\", .. }\n"
             "public atom Kind(Stop | Ping e)\n"
             "Kind({ \"type\": \"message_stop\" }) -> :stop\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "Kind({ \"type\": \"ping\" }) -> ...")),
                 ?assertEqual(nomatch, string:find(Output, "message_stop\" }) -> ..."))
             end)
     end}.

levels_src(Clauses) ->
    "module Lv\n"
    "type Level = \"low\" | \"high\"\n"
    "public int Rank(Level l)\n" ++ Clauses.

%% F68.3 — a union of literals is a type on its own, and its clauses close it.
a_union_of_literals_is_covered_by_its_literals_test() ->
    M = build_and_load(levels_src("Rank(\"low\")  -> 1\nRank(\"high\") -> 2\n"), 'Lv'),
    ?assertEqual(2, M:'Rank'(<<"high">>)),
    ?assertEqual([inexhaustive], tags(levels_src("Rank(\"low\") -> 1\n"))).

%% F68.4 — `string` stays open: literals over it still need a catch-all, and
%% the catch-all is legal.
string_stays_open_test() ->
    Src = fun(Last) ->
              "module St\n"
              "public int Rank(string l)\n"
              "Rank(\"low\")  -> 1\n"
              "Rank(\"high\") -> 2\n" ++ Last
          end,
    ?assertEqual([inexhaustive], tags(Src(""))),
    M = build_and_load(Src("Rank(_) -> 0\n"), 'St'),
    ?assertEqual({1, 0}, {M:'Rank'(<<"low">>), M:'Rank'(<<"other">>)}).

wire_src() ->
    "module Wr\n"
    "type Stop  = { \"type\": \"message_stop\" }\n"
    "type Ping  = { \"type\": \"ping\", \"seq\": int }\n"
    "type Event = Stop | Ping\n"
    "public Ping Make(int n)\n"
    "Make(n) -> { \"type\" = \"ping\", \"seq\" = n }\n"
    "public result<Event, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<Event>(t)\n"
    "public string Body(Event e)\n"
    "Body(e) -> ToJson<Event>(e)\n".

%% F68.5 — a literal expression has its own string as its type, so a brace
%% builds a literal-tagged member, and the wrong literal is refused.
a_brace_builds_a_literal_tagged_member_test() ->
    M = build_and_load(wire_src(), 'Wr'),
    ?assertEqual(#{<<"type">> => <<"ping">>, <<"seq">> => 3}, M:'Make'(3)),
    ?assertEqual([return_not_declared],
                 tags("module Wr2\n"
                      "public { \"type\": \"ping\" } Make()\n"
                      "Make() -> { \"type\" = \"pong\" }\n")).

%% F68.5b — the refusal says which literal the clause built, at `bsc`.
the_refusal_names_the_literal_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("wr2.bs",
             "module Wr2\n"
             "public { \"type\": \"ping\" } Make()\n"
             "Make() -> { \"type\" = \"pong\" }\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "{ \"type\": \"pong\" }"))
             end)
     end}.

%% F68.6 — `ValidateAs` compares the value with the literal, and says which
%% literal it wanted.
validate_as_compares_the_literal_test() ->
    M = build_and_load(wire_src(), 'Wr'),
    Stop = #{<<"type">> => <<"message_stop">>},
    Ping = #{<<"type">> => <<"ping">>, <<"seq">> => 1},
    ?assertEqual(Stop, M:'Read'(Stop)),
    ?assertEqual(Ping, M:'Read'(Ping)),
    ?assertMatch({error, #{'Kind' := 'ValidationError'}},
                 M:'Read'(#{<<"type">> => <<"error">>})),
    M1 = build_and_load("module Wr3\n"
                        "public result<{ \"type\": \"ping\" }, ValidationError> Read(term t)\n"
                        "Read(t) -> ValidateAs<{ \"type\": \"ping\" }>(t)\n", 'Wr3'),
    {error, #{'Path' := P, 'Expected' := E}} = M1:'Read'(#{<<"type">> => <<"pong">>}),
    ?assertEqual({[<<"[\"type\"]">>], <<"\"ping\"">>}, {P, E}),
    {error, #{'Expected' := E2}} = M1:'Read'(#{<<"type">> => 7}),
    ?assertEqual(<<"\"ping\"">>, E2).

%% F68.7 — `ToJson` writes the literal unchanged.
to_json_writes_the_literal_test() ->
    M = build_and_load(wire_src(), 'Wr'),
    ?assertEqual(#{<<"type">> => <<"message_stop">>},
                 json:decode(M:'Body'(#{<<"type">> => <<"message_stop">>}))).

%% F68.8 — a `switch` over a union of literals closes as clause heads do.
a_switch_over_literals_closes_test() ->
    Src = fun(Arms) ->
              "module Sw\n"
              "type Level = \"low\" | \"high\"\n"
              "public int Rank(Level l)\n"
              "Rank(l) -> l switch {\n" ++ Arms ++ "}\n"
          end,
    M = build_and_load(Src("  \"low\" => 1,\n  \"high\" => 2\n"), 'Sw'),
    ?assertEqual(1, M:'Rank'(<<"low">>)),
    ?assertEqual([switch_inexhaustive], tags(Src("  \"low\" => 1\n"))).

%% F68.9 — members that differ only in their literal are told apart by
%% `ValidateAs`, open or not.
validate_as_tells_open_members_apart_by_the_literal_test() ->
    M = build_and_load(events_src(all_three()) ++
                       "public result<Event, ValidationError> Read(term t)\n"
                       "Read(t) -> ValidateAs<Event>(t)\n", 'Ev1'),
    Ping = #{<<"type">> => <<"ping">>, <<"id">> => 9},
    ?assertEqual(Ping, M:'Read'(Ping)),
    ?assertMatch({error, #{'Kind' := 'ValidationError'}},
                 M:'Read'(#{<<"type">> => <<"content_block_start">>})),
    ?assertMatch({error, #{'Kind' := 'ValidationError'}},
                 M:'Read'(#{<<"type">> => <<"unknown">>})).

%% F68.10 — a foreign function declared to return literals is guarded by them.
a_foreign_return_of_literals_is_guarded_test() ->
    M = build_and_load("module Fl\n"
                       "type Level = \"low\" | \"high\"\n"
                       "using :erlang {\n"
                       "    Level hd(list<term> xs)\n"
                       "}\n"
                       "public Level First(list<term> xs)\n"
                       "First(xs) -> :erlang.hd(xs)\n", 'Fl'),
    ?assertEqual(<<"low">>, M:'First'([<<"low">>])),
    ?assertError({case_clause, <<"mid">>}, M:'First'([<<"mid">>])).

%% F68.11 — a guard's `==` against a literal is read as the literal pattern is.
a_guard_comparing_a_literal_closes_test() ->
    M = build_and_load(levels_src("Rank(l) when l == \"low\"  -> 1\n"
                                  "Rank(l) when l == \"high\" -> 2\n"), 'Lv'),
    ?assertEqual({1, 2}, {M:'Rank'(<<"low">>), M:'Rank'(<<"high">>)}).

%% F68.12 — a literal with a quote or a control character prints as source
%% writes it, so the head handed back can be pasted.
a_residual_literal_is_escaped_as_source_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("esc.bs",
             "module Esc\n"
             "type L = \"a\\\"q\\n\" | \"b\"\n"
             "public int A(L l)\n"
             "A(\"b\") -> 1\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "A(\"a\\\"q\\n\") -> ..."))
             end)
     end}.

%% F68.13 — the signature offered for a mismatched return says `string` where
%% a clause returned a literal.
the_offered_signature_says_string_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("off.bs",
             "module Off\n"
             "public int Pick(bool b)\n"
             "Pick(true)  -> 1\n"
             "Pick(false) -> \"none\"\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch,
                                 string:find(Output, "public int | string Pick(bool b)"))
             end)
     end}.

%% F68.14 — ticket 117 Q1: a field set closes on its literal tag as a record
%% does on `Kind`, so `_` over leftover tagged members is refused naming them,
%% whether they are open or hold an unbounded field.
a_catch_all_over_tagged_members_is_refused_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("ev14.bs",
             "module Ev14\n"
             "type Start = { \"type\": \"content_block_start\", \"index\": int, .. }\n"
             "type Stop  = { \"type\": \"message_stop\", .. }\n"
             "type Ping  = { \"type\": \"ping\", \"seq\": int }\n"
             "public atom Kind(Start | Stop | Ping e)\n"
             "Kind({ \"type\": \"content_block_start\" }) -> :start\n"
             "Kind(_) -> :other\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "discards cases the compiler can name")),
                 ?assertNotEqual(nomatch, string:find(Output, "\"type\": \"message_stop\" }) -> ...")),
                 ?assertNotEqual(nomatch, string:find(Output, "\"type\": \"ping\" }) -> ..."))
             end)
     end}.

%% F68.15 — an untagged open field set stays open, and `_` stays legal over it.
a_catch_all_over_an_untagged_open_member_is_legal_test() ->
    M = build_and_load("module Ev15\n"
                       "type A = { \"a\": int, .. }\n"
                       "type B = { \"b\": string, .. }\n"
                       "public int Go(A | B x)\n"
                       "Go({ \"a\": _ }) -> 1\n"
                       "Go(_) -> 0\n", 'Ev15'),
    ?assertEqual(0, M:'Go'(#{<<"b">> => <<"x">>})).

%% F68.16 — a tag key with several literals left gets one head per literal, so
%% the refusal names each case and no pasted head is a catch-all in disguise.
each_leftover_literal_gets_its_own_head_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("ev16.bs",
             "module Ev16\n"
             "type S = { \"type\": \"stop\" | \"halt\" | \"end\", \"n\": int }\n"
             "public atom Kind(S e)\n"
             "Kind({ \"type\": \"stop\" }) -> :stop\n"
             "Kind(_) -> :other\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "\"type\": \"halt\" }) -> ...")),
                 ?assertNotEqual(nomatch, string:find(Output, "\"type\": \"end\" }) -> ...")),
                 ?assertEqual(nomatch, string:find(Output, "\"type\": _"))
             end)
     end}.
