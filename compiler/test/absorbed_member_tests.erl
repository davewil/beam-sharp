%%% F36 — declarations reject absorption and indiscriminable unions.
%%% Scenarios: compiler/features/F36-an-absorbed-member.md
-module(absorbed_member_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [check_only/1]).

%%% Helpers

alias(Mod, Body) ->
    "module " ++ Mod ++ "\n\n"
    "type T = " ++ Body ++ "\n\n"
    "public int Go(int id)\n"
    "Go(id) -> id\n".

%% A trivial body isolates declaration diagnostics.
decls(Mod, Decls) ->
    "module " ++ Mod ++ "\n\n" ++ Decls ++ "\n\n"
    "public int Go(int id)\n"
    "Go(id) -> id\n".

%%% F36.1 — absorption is refused outside the failure channel.

binary_absorbs_string_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A1", "binary | string"))).

%% Absorption takes precedence over indiscriminability.
cofinite_atom_absorbs_a_singleton_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A2", "atom | :ok"))).

term_absorbs_int_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A3", "term | int"))).

%% Comparing only outer constructors misses absorption within a list.
list_of_term_absorbs_list_of_int_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A4", "list<term> | list<int>"))).

%%% F36.2 — failure channels retain their specific hints.
%%% The discriminator selects the hint; the diagnostic tag is shared.

option_at_an_atom_top_keeps_the_nothing_hint_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(alias("A5", "option<atom>"))).

result_over_term_keeps_the_error_hint_test() ->
    ?assertError({absorbed_member, _, _, error, _, _},
                 check_only(alias("A6", "result<term, atom>"))).

%%% F36.3 — diagnostics identify the field or tuple component.

a_record_field_names_the_field_test() ->
    ?assertError({absorbed_member, _, "Job.Tag", _, _, _},
                 check_only(decls("A7", "record Job { Id: int, Tag: atom | :urgent }"))).

%% The path must follow the field, not just name the record.
the_path_follows_the_field_that_absorbs_test() ->
    ?assertError({absorbed_member, _, "Job.Owner", _, _, _},
                 check_only(decls("A8",
                                  "record Job { Id: int, Owner: atom | :nobody }"))).

a_tuple_component_names_its_position_test() ->
    ?assertError({absorbed_member, _, "Route.x.1", _, _, _},
                 check_only(decls("A9",
                                  "public string Route((atom | :ok, int) x)\n"
                                  "Route(x) -> \"ok\""))).

%%% F36.4 — inline unions are checked at every declaration site.

a_bare_inline_union_in_a_parameter_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A10",
                                  "public string H(atom | :ok x)\n"
                                  "H(x) -> \"ok\""))).

a_bare_inline_union_in_a_return_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A11",
                                  "public atom | :ok Go2(int n)\n"
                                  "Go2(n) -> :ok"))).

a_bare_inline_union_in_a_foreign_signature_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A12",
                                  "using :erlang {\n"
                                  "    atom | :ok node()\n"
                                  "}"))).

%%% F36.5 — domain maps with different value types are indiscriminable.

two_domain_maps_cannot_be_told_apart_test() ->
    ?assertError({indiscriminable_union, _, _, _, _},
                 check_only(alias("A13", "map<string, int> | map<string, binary>"))).

%%% F36.6 — patterns and guards distinguish these control cases.

%% A list pattern exposes the element to a guard.
two_lists_are_discriminable_by_pattern_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A14", "list<int> | list<binary>"))).

an_atom_and_an_int_are_discriminable_by_guard_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A15", "atom | int"))).

tagged_tuples_are_discriminable_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A16", "(:a, int) | (:b, binary)"))).

%% A map has no pattern, but `is_map` distinguishes it from an int.
a_domain_map_beside_an_int_is_discriminable_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A17", "map<string, int> | int"))).

%% Both members are integers; guards distinguish them inside a tuple.
disjoint_refined_ints_are_discriminable_by_guard_test() ->
    Src = decls("A18",
                "type Low = int where value >= 0 and value <= 9\n"
                "type High = int where value >= 10 and value <= 99\n"
                "type Pair = (Low | High, atom)"),
    ?assertMatch({ok, _, _}, check_only(Src)).

%% At top level the same refinements use relational patterns.
disjoint_refined_ints_at_the_top_are_discriminable_test() ->
    Src = decls("A19",
                "type Low = int where value >= 0 and value <= 9\n"
                "type High = int where value >= 10 and value <= 99\n"
                "type Span = Low | High"),
    ?assertMatch({ok, _, _}, check_only(Src)).

two_records_are_discriminable_test() ->
    Src = decls("A20",
                "record Order { Id: int }\n"
                "record Invoice { Id: int }\n"
                "type Doc = Order | Invoice"),
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% F36.7 — pairwise checks use normalised union members.

%% Normalisation exposes three members that guards can distinguish.
a_union_of_unions_is_paired_after_normalising_test() ->
    Src = decls("A21",
                "type A = map<string, int> | int\n"
                "type B = map<string, int> | atom\n"
                "type C = A | B"),
    ?assertMatch({ok, _, _}, check_only(Src)).

%% The list pattern must not hide the indistinguishable map pair.
an_indiscriminable_pair_hidden_in_a_lump_is_still_refused_test() ->
    Src = decls("A22",
                "type A = list<int> | map<string, int>\n"
                "type B = A | map<string, binary>"),
    ?assertError({indiscriminable_union, _, _, _, _}, check_only(Src)).
