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
