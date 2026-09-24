%%% Scenarios: compiler/features/F31-collapse-at-the-declaration.md
%%% Scenarios: compiler/features/F28-recursive-types.md
%%% F31 — a declared failure channel survives normalisation.
-module(collapse_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [check_only/1, build_and_load/2]).

%%% Helpers

ret(Mod, Ty) -> ret(Mod, Ty, "").

ret(Mod, Ty, Extra) ->
    "module " ++ Mod ++ "\n\n" ++
        case Extra of "" -> ""; _ -> Extra ++ "\n\n" end ++
        "public " ++ Ty ++ " Go(int id)\n"
        "Go(id) -> :nothing\n".

%%% F31.1 — collapsing types are refused; disjoint types compile.

option_at_the_atom_top_is_refused_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(ret("S3", "option<atom>"))).

%% The inner union absorbs the outer `:nothing` without an atom top.
nested_option_is_refused_though_no_top_is_involved_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(ret("S4", "option<option<int>>"))).

option_at_term_is_refused_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(ret("S5", "option<term>"))).

result_at_term_is_refused_test() ->
    ?assertError({absorbed_member, _, _, error, _, _},
                 check_only(ret("S7", "result<term, binary>"))).

%% The error tuple is a subtype of the success tuple without an atom top.
result_whose_success_type_shadows_the_error_tuple_is_refused_test() ->
    ?assertError({absorbed_member, _, _, error, _, _},
                 check_only(ret("S8", "result<(atom, binary), binary>"))).

%% Absorption depends on the type, including aliases of the same shape.
a_hand_written_alias_of_the_same_shape_is_refused_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(ret("S9", "M", "type M = atom | :nothing"))).

%%% Disjoint controls

%% Running the controls proves they compile; checking only for exceptions can
%% miss returned errors.
option_at_a_disjoint_type_still_compiles_test() ->
    M = build_and_load(ret("S1", "option<int>"), 'S1'),
    ?assertEqual(nothing, M:'Go'(1)).

%% `option<bool>` is three literal atoms, so nothing is absorbed.
option_at_bool_still_compiles_test() ->
    M = build_and_load(ret("S2", "option<bool>"), 'S2'),
    ?assertEqual(nothing, M:'Go'(1)).

result_with_a_tagged_failure_still_compiles_test() ->
    Src = "module S6\n\npublic result<int, binary> Go(int id)\nGo(id) -> 1\n",
    M = build_and_load(Src, 'S6'),
    ?assertEqual(1, M:'Go'(1)).

the_map_fetch_shape_still_compiles_test() ->
    Src = "module S10\n\ntype F = (:ok, term) | :absent\n\n"
          "public F Go(int id)\nGo(id) -> :absent\n",
    M = build_and_load(Src, 'S10'),
    ?assertEqual(absent, M:'Go'(1)).

a_hand_written_tagged_union_still_compiles_test() ->
    Src = "module S11\n\ntype R = atom | (:error, binary)\n\n"
          "public R Go(int id)\nGo(id) -> :ok\n",
    M = build_and_load(Src, 'S11'),
    ?assertEqual(ok, M:'Go'(1)).

%%% F31.2 — every declaration site rejects collapsing types.

a_collapsing_signature_PARAMETER_is_refused_test() ->
    Src = "module P1\n\npublic :ok Go(option<atom> x)\nGo(x) -> :ok\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

a_collapsing_RECORD_FIELD_is_refused_test() ->
    Src = "module P2\n\nrecord Box { Id: int, Note: option<atom> }\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

a_collapsing_TYPE_ALIAS_body_is_refused_test() ->
    Src = "module P3\n\ntype M = atom | :nothing\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

a_collapsing_FOREIGN_return_is_refused_test() ->
    Src = "module P4\n\nusing :lists {\n    option<atom> last(list<atom> xs)\n}\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

a_collapsing_FOREIGN_parameter_is_refused_test() ->
    Src = "module P5\n\nusing :lists {\n    atom last(option<atom> xs)\n}\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

a_collapsing_TUPLE_COMPONENT_is_refused_test() ->
    Src = "module P6\n\npublic (option<atom>, int) Go(int id)\n"
          "Go(id) -> (:nothing, 1)\n",
    ?assertError({absorbed_member, _, _, nothing, _, _}, check_only(Src)).

%% The API query resolves declarations through a separate check path.
the_api_query_path_refuses_it_too_test() ->
    {ok, _, Decls} = bs_parser_support_parse("module A1\n\n"
                                             "public option<atom> Go(int id)\n"
                                             "Go(id) -> :nothing\n"),
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 bs_check:exports_of(Decls)).

bs_parser_support_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, undefined, Decls}.

%%% F31.3 — the collapse check terminates on recursive aliases.

%% F28 — contractive aliases terminate and resolve.
a_contractive_alias_terminates_and_resolves_test() ->
    ?assertMatch({ok, _, _},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public atom F(Tree<int> t)\nF(t) -> :ok\n")),
    ?assertMatch({ok, _, _},
                 check_only("module E\ntype Nest = :leaf | list<Nest>\n"
                            "public atom F(Nest n)\nF(n) -> :ok\n")).

%% The failure member forces a comparison against the recursive alias.
a_contractive_alias_under_a_failure_member_terminates_test() ->
    ?assertMatch({ok, _, _},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public option<Tree<int>> F(int n)\nF(n) -> :nothing\n")).

%%% F31.4 — the diagnostic names the declaration and explains the collapse.

%% Type expressions lack positions; the line comes from the declaration.
the_refusal_names_the_line_of_the_declaration_test() ->
    Src = "module L1\n\n// a comment\n\npublic option<atom> Go(int id)\n"
          "Go(id) -> :nothing\n",
    ?assertError({absorbed_member, {5, _}, _, nothing, _, _}, check_only(Src)).

%% The tagging hint applies only to an untagged failure member.
the_message_says_the_channel_did_not_survive_normalisation_test() ->
    D = bs_diag:descriptor("x.bs", {absorbed_member, {5, 21}, "Go", nothing,
                                    bs_types:atom_lit(nothing),
                                    bs_types:atom_top()}),
    S = lists:flatten(io_lib:format(element(1, bs_diag:message(D)),
                                    element(2, bs_diag:message(D)))),
    ?assert(string:find(S, "does not survive normalisation") =/= nomatch),
    ?assert(string:find(S, "tag it") =/= nomatch).

the_error_channel_is_not_told_to_tag_what_is_already_tagged_test() ->
    D = bs_diag:descriptor("x.bs", {absorbed_member, {5, 21}, "Go", error,
                                    bs_types:atom_lit(error),
                                    bs_types:atom_top()}),
    S = lists:flatten(io_lib:format(element(1, bs_diag:message(D)),
                                    element(2, bs_diag:message(D)))),
    ?assert(string:find(S, "does not survive normalisation") =/= nomatch),
    ?assertEqual(nomatch, string:find(S, "tag it")).

%%% F31.4 — ValidateAs reports its own obligation diagnostic.

%% The declaration must not collapse: only the obligation argument does.
the_obligation_site_still_reports_under_its_own_tag_test() ->
    Src = "module V1\n\npublic result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<term>(t)\n",
    Errs = bs_test_support:errors(Src),
    ?assert(lists:any(fun({error, _, _, {validate_collapses, _}}) -> true;
                         (_) -> false
                      end, Errs)).

%%% Inline and aliased unions

a_bare_inline_union_in_a_return_position_collapses_test() ->
    Src = "module B1\n\npublic atom | :nothing Go(int n)\n"
          "Go(n) when n > 0  -> :yes\n"
          "Go(n) when n <= 0 -> :nothing\n",
    ?assertError({absorbed_member, {3, _}, _, nothing, _, _},
                 check_only(Src)).

%% The line names the alias declaration, not the signature that uses it.
the_aliased_spelling_of_the_same_union_collapses_identically_test() ->
    Src = "module B2\n\ntype M = atom | :nothing\n\npublic M Go(int n)\n"
          "Go(n) when n > 0  -> :yes\n"
          "Go(n) when n <= 0 -> :nothing\n",
    ?assertError({absorbed_member, {3, _}, _, nothing, _, _},
                 check_only(Src)).
