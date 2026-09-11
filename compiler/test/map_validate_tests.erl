%%% F43 — the key walk over `map<K, V>` (ticket 18 §2's route, ticket 48, ENG-356).
%%%
%%% Ticket 18 §2 sends a structured foreign return through `term` and then
%%% `ValidateAs<T>`, and F40 refuses any `map<K, V>` narrower than
%%% `map<term, term>` at a foreign declaration with exactly that route as the
%%% edit. Until this feature the route was refused at its other end: F33
%%% shipped the type and `ValidateAs` over it said the walk was unbuilt. This
%%% is the walk.
%%%
%%% ASSERTED AT THE BOUNDARY: source text in, a loaded `.beam` called, and
%%% what it returns compared. Nothing here pins a function in `bs_emit`; a
%%% rearranged traversal must not turn this file red.
%%%
%%% The path segment for a map entry is the key in brackets, spelled as the
%%% key is written in the language: `["views"]`, `[:views]`, `[7]`. A key the
%%% language has no literal for is not spelled — the blame stops at the map,
%%% with the map's type expected — because rendering an arbitrary term to a
%%% string inside generated code is ticket 16 §4's unwritten mapping, and F18
%%% recorded that a validator-only spelling would be a second rendering.

-module(map_validate_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2]).

%%% ---------------------------------------------------------------------------
%%% Fixture — one target type per test, validated from a `term`
%%% ---------------------------------------------------------------------------

src(Ty, Decls) ->
    "module VaMap\n"
    ++ Decls ++
    "type Target = " ++ Ty ++ "\n"
    "public result<Target, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<Target>(t)\n".

load(Ty) -> load(Ty, "").
load(Ty, Decls) -> build_and_load(src(Ty, Decls), 'VaMap').

%%% ---------------------------------------------------------------------------
%%% F43.1 — the route exists: a domain map validates
%%% ---------------------------------------------------------------------------

a_well_formed_map_comes_back_unchanged_test() ->
    M = load("map<string, int>"),
    In = #{<<"views">> => 3, <<"clicks">> => 1},
    ?assertEqual(In, M:'Check'(In)).

%% `#{}` inhabits every domain: the constraint is on entries that exist.
an_empty_map_passes_test() ->
    M = load("map<string, int>"),
    ?assertEqual(#{}, M:'Check'(#{})).

something_that_is_not_a_map_blames_the_term_itself_test() ->
    M = load("map<string, int>"),
    ?assertEqual({error, {[], <<"map<string, int>">>}}, M:'Check'([{a, 1}])).

%%% ---------------------------------------------------------------------------
%%% F43.2 — blame: the entry is named by its key, and the expected type says
%%% which half of the entry was wrong
%%% ---------------------------------------------------------------------------

a_bad_value_is_blamed_at_its_key_with_the_value_type_expected_test() ->
    M = load("map<string, int>"),
    ?assertEqual({error, {[<<"[\"views\"]">>], <<"int">>}},
                 M:'Check'(#{<<"views">> => many})).

a_bad_key_is_blamed_at_itself_with_the_key_type_expected_test() ->
    M = load("map<string, int>"),
    ?assertEqual({error, {[<<"[:views]">>], <<"string">>}},
                 M:'Check'(#{views => 3})).

%% Deterministic, and statable: the first offending entry in key order.
the_first_offending_entry_in_key_order_is_blamed_test() ->
    M = load("map<string, int>"),
    ?assertEqual({error, {[<<"[\"b\"]">>], <<"int">>}},
                 M:'Check'(#{<<"c">> => x, <<"a">> => 1, <<"b">> => y})).

the_path_composes_through_a_map_test() ->
    M = load("map<string, list<int>>"),
    ?assertEqual({error, {[<<"[\"xs\"]">>, <<"[1]">>], <<"int">>}},
                 M:'Check'(#{<<"xs">> => [1, two, 3]})).

a_map_inside_a_record_composes_the_other_way_test() ->
    M = load("Site", "record Site { Name: string, Counts: map<string, int> }\n"),
    ?assertEqual({error, {[<<".Counts">>, <<"[\"views\"]">>], <<"int">>}},
                 M:'Check'(#{'Kind' => 'VaMap.Site', 'Name' => <<"a">>,
                             'Counts' => #{<<"views">> => many}})).

%%% ---------------------------------------------------------------------------
%%% F43.3 — how a key is spelled in the path
%%% ---------------------------------------------------------------------------

an_int_key_is_spelled_as_digits_test() ->
    M = load("map<int, atom>"),
    ?assertEqual({error, {[<<"[7]">>], <<"atom">>}}, M:'Check'(#{7 => <<"no">>})).

an_atom_key_the_sigil_can_spell_is_bare_test() ->
    M = load("map<atom, int>"),
    ?assertEqual({error, {[<<"[:views]">>], <<"int">>}}, M:'Check'(#{views => x})).

an_atom_key_the_sigil_cannot_spell_is_quoted_test() ->
    M = load("map<atom, int>"),
    ?assertEqual({error, {[<<"[:'Z.Order']">>], <<"int">>}},
                 M:'Check'(#{'Z.Order' => x})).

%% A tuple has a spelling as a value, not as a key the author can write in a
%% path, and a binary that is not text has none at all. Neither is rendered:
%% the map is blamed, with the map's type expected.
a_key_the_language_cannot_spell_blames_the_map_test() ->
    M = load("map<string, int>"),
    ?assertEqual({error, {[], <<"map<string, int>">>}}, M:'Check'(#{{1, 2} => x})),
    ?assertEqual({error, {[], <<"map<string, int>">>}}, M:'Check'(#{<<255>> => 1})).

%%% ---------------------------------------------------------------------------
%%% F43.4 — `Kind` is excluded (ticket 48 Q3), and `map<term, term>` is one test
%%% ---------------------------------------------------------------------------

a_record_is_not_a_domain_map_test() ->
    M = load("map<atom, term>"),
    ?assertEqual({error, {[], <<"map<atom, term>">>}},
                 M:'Check'(#{'Kind' => 'Z.Order', 'S' => 1})).

%% The segment is computed before an entry is checked and read only when a
%% check fails. A walker that treated an unspellable key as a failure on
%% sight would refuse this map, which is a member of the type.
an_unspellable_key_under_a_well_formed_entry_passes_test() ->
    M = load("map<term, int>"),
    In = #{{1, 2} => 3, <<255>> => 4},
    ?assertEqual(In, M:'Check'(In)),
    ?assertEqual({error, {[], <<"map<term, int>">>}}, M:'Check'(#{{1, 2} => bad})).

a_map_over_term_needs_only_to_be_a_map_without_a_kind_test() ->
    M = load("map<term, term>"),
    In = #{{1, 2} => [x], <<255>> => self()},
    ?assertEqual(In, M:'Check'(In)),
    ?assertEqual({error, {[], <<"map<term, term>">>}}, M:'Check'(#{'Kind' => x})),
    ?assertEqual({error, {[], <<"map<term, term>">>}}, M:'Check'(7)).

%%% ---------------------------------------------------------------------------
%%% F43.5 — a domain member beside the other map kinds (F18's blame rule:
%%% descend where exactly one candidate can match, blame here where more can)
%%% ---------------------------------------------------------------------------

%% A record carries `Kind` and the domain excludes it, so the two are disjoint
%% and each keeps its own blame.
a_record_beside_a_domain_keeps_its_own_blame_test() ->
    M = load("Order | map<atom, term>", "record Order { S: int }\n"),
    ?assertEqual({error, {[<<".S">>], <<"int">>}},
                 M:'Check'(#{'Kind' => 'VaMap.Order', 'S' => bad})),
    Bare = #{'S' => bad},
    ?assertEqual(Bare, M:'Check'(Bare)).

%% A brace clause selects by key set, and a domain admits every key set, so
%% the shape decides nothing: `#{X => 1}` fits the `{ X: string }` pattern and
%% is a member of `map<atom, int>`. Under a pattern-first walk it would have
%% been refused at `.X`. So neither is descended into: every candidate is
%% tried, a value in either passes, and a value in neither is blamed at the
%% node with the whole type expected.
a_bare_map_beside_a_domain_is_an_alternative_test() ->
    M = load("{ X: string } | map<atom, int>"),
    InDomain = #{'X' => 1},
    InBrace  = #{'X' => <<"s">>},
    ?assertEqual(InDomain, M:'Check'(InDomain)),
    ?assertEqual(InBrace, M:'Check'(InBrace)),
    ?assertEqual({error, {[], <<"{ X: string } | map<atom, int>">>}},
                 M:'Check'(#{'X' => 1.5})).

%% Two domains in one type — `map<string, int> | map<atom, atom>` — never reach
%% the validator: no pattern reaches either member and no guard separates
%% them, so the declaration is refused as an indiscriminable union (F29).
%% The emitter still treats the shape as alternatives rather than crashing.

%%% ---------------------------------------------------------------------------
%%% F43.6 — the ticket's program, through the CLI
%%% ---------------------------------------------------------------------------

analytics_src() ->
    "module Analytics\n"
    "type ViewCounts = map<string, int>\n"
    "using :maps {\n"
    "    map<term, term> from_list(list<term> pairs)\n"
    "}\n"
    "public result<ViewCounts, ValidationError> PageViews(list<term> rows)\n"
    "PageViews(rows) -> ValidateAs<ViewCounts>(:maps.from_list(rows))\n".

the_foreign_map_route_is_whole_test() ->
    M = build_and_load(analytics_src(), 'Analytics'),
    ?assertEqual(#{<<"views">> => 3}, M:'PageViews'([{<<"views">>, 3}])),
    ?assertEqual({error, {[<<"[\"views\"]">>], <<"int">>}},
                 M:'PageViews'([{<<"views">>, many}])).
