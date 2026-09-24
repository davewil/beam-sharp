%%% F43 — ValidateAs checks map keys and values.

%%% Scenarios: compiler/features/F43-map-key-walk.md
-module(map_validate_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/2]).

%%% Fixture — one target type per test, validated from a `term`

src(Ty, Decls) ->
    "module VaMap\n"
    ++ Decls ++
    "type Target = " ++ Ty ++ "\n"
    "public result<Target, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<Target>(t)\n".

load(Ty) -> load(Ty, "").
load(Ty, Decls) -> build_and_load(src(Ty, Decls), 'VaMap').

%%% F43.1 — valid maps pass and non-maps blame the root.

a_well_formed_map_comes_back_unchanged_test() ->
    M = load("map<string, int>"),
    In = #{<<"views">> => 3, <<"clicks">> => 1},
    ?assertEqual(In, M:'Check'(In)).

an_empty_map_passes_test() ->
    M = load("map<string, int>"),
    ?assertEqual(#{}, M:'Check'(#{})).

something_that_is_not_a_map_blames_the_term_itself_test() ->
    M = load("map<string, int>"),
    ?assertEqual(validation_error([], <<"map<string, int>">>), M:'Check'([{a, 1}])).

%%% F43.2 — blame names the key and the failing half of the entry.

a_bad_value_is_blamed_at_its_key_with_the_value_type_expected_test() ->
    M = load("map<string, int>"),
    ?assertEqual(validation_error([<<"[\"views\"]">>], <<"int">>),
                 M:'Check'(#{<<"views">> => many})).

a_bad_key_is_blamed_at_itself_with_the_key_type_expected_test() ->
    M = load("map<string, int>"),
    ?assertEqual(validation_error([<<"[:views]">>], <<"string">>),
                 M:'Check'(#{views => 3})).

the_first_offending_entry_in_key_order_is_blamed_test() ->
    M = load("map<string, int>"),
    ?assertEqual(validation_error([<<"[\"b\"]">>], <<"int">>),
                 M:'Check'(#{<<"c">> => x, <<"a">> => 1, <<"b">> => y})).

the_path_composes_through_a_map_test() ->
    M = load("map<string, list<int>>"),
    ?assertEqual(validation_error([<<"[\"xs\"]">>, <<"[1]">>], <<"int">>),
                 M:'Check'(#{<<"xs">> => [1, two, 3]})).

a_map_inside_a_record_composes_the_other_way_test() ->
    M = load("Site", "record Site { Name: string, Counts: map<string, int> }\n"),
    ?assertEqual(validation_error([<<".Counts">>, <<"[\"views\"]">>], <<"int">>),
                 M:'Check'(#{'Kind' => 'VaMap.Site', 'Name' => <<"a">>,
                             'Counts' => #{<<"views">> => many}})).

%%% F43.3 — paths use the language spelling of each key.

an_int_key_is_spelled_as_digits_test() ->
    M = load("map<int, atom>"),
    ?assertEqual(validation_error([<<"[7]">>], <<"atom">>), M:'Check'(#{7 => <<"no">>})).

an_atom_key_the_sigil_can_spell_is_bare_test() ->
    M = load("map<atom, int>"),
    ?assertEqual(validation_error([<<"[:views]">>], <<"int">>), M:'Check'(#{views => x})).

an_atom_key_the_sigil_cannot_spell_is_quoted_test() ->
    M = load("map<atom, int>"),
    ?assertEqual(validation_error([<<"[:'Z.Order']">>], <<"int">>),
                 M:'Check'(#{'Z.Order' => x})).

%% Tuple and non-text binary keys have no path spelling, so blame stays here.
a_key_the_language_cannot_spell_blames_the_map_test() ->
    M = load("map<string, int>"),
    ?assertEqual(validation_error([], <<"map<string, int>">>), M:'Check'(#{{1, 2} => x})),
    ?assertEqual(validation_error([], <<"map<string, int>">>), M:'Check'(#{<<255>> => 1})).

%%% F43.4 — Kind is excluded and map<term, term> checks only map shape.

a_record_is_not_a_domain_map_test() ->
    M = load("map<atom, term>"),
    ?assertEqual(validation_error([], <<"map<atom, term>">>),
                 M:'Check'(#{'Kind' => 'Z.Order', 'S' => 1})).

%% An unspellable key affects blame only; it does not invalidate a good entry.
an_unspellable_key_under_a_well_formed_entry_passes_test() ->
    M = load("map<term, int>"),
    In = #{{1, 2} => 3, <<255>> => 4},
    ?assertEqual(In, M:'Check'(In)),
    ?assertEqual(validation_error([], <<"map<term, int>">>), M:'Check'(#{{1, 2} => bad})).

a_map_over_term_needs_only_to_be_a_map_without_a_kind_test() ->
    M = load("map<term, term>"),
    In = #{{1, 2} => [x], <<255>> => self()},
    ?assertEqual(In, M:'Check'(In)),
    ?assertEqual(validation_error([], <<"map<term, term>">>), M:'Check'(#{'Kind' => x})),
    ?assertEqual(validation_error([], <<"map<term, term>">>), M:'Check'(7)).

%%% F43.5 — maps beside other map types retain the appropriate blame.

%% Kind separates records from domain maps, allowing field-level blame.
a_record_beside_a_domain_keeps_its_own_blame_test() ->
    M = load("Order | map<atom, term>", "record Order { S: int }\n"),
    ?assertEqual(validation_error([<<".S">>], <<"int">>),
                 M:'Check'(#{'Kind' => 'VaMap.Order', 'S' => bad})),
    Bare = #{'S' => bad},
    ?assertEqual(Bare, M:'Check'(Bare)).

%% The key set fits both alternatives. Trying only the brace shape would
%% reject the valid domain member; failure must blame the whole union.
a_bare_map_beside_a_domain_is_an_alternative_test() ->
    M = load("{ X: string } | map<atom, int>"),
    InDomain = #{'X' => 1},
    InBrace  = #{'X' => <<"s">>},
    ?assertEqual(InDomain, M:'Check'(InDomain)),
    ?assertEqual(InBrace, M:'Check'(InBrace)),
    ?assertEqual(validation_error([], <<"{ X: string } | map<atom, int>">>),
                 M:'Check'(#{'X' => 1.5})).

%%% F43.6 — a foreign map passes through validation.

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
    ?assertEqual(validation_error([<<"[\"views\"]">>], <<"int">>),
                 M:'PageViews'([{<<"views">>, many}])).
