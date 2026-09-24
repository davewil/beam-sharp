%%% Scenarios: compiler/features/F3-records.md
-module(records_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          shop_src/0, an_order/0, count/2]).

-define(OUT, bs_test_support:run_root()).

%%% F3 — records.

shop_forms() ->
    {ok, _} = compile(shop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Shop.beam", [abstract_code]),
    Forms.

%% F3.1 — a record constructs a map tagged with its qualified name.
a_record_constructs_a_tagged_map_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(an_order(), M:'Draft'()).

%% F3.2 — a hand-written type with the same tag is the same type.
%% Absorption rejects this union only if both spellings denote the same type.
a_hand_written_type_with_the_same_tag_is_the_same_type_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "type Spelled = { Kind: :'Shop.Order', Id: int, Total: int }\n"
          "type Either = Order | Spelled\n"
          "public atom Which(Either)\n"
          "Which(Order o) -> :order\n",
    ?assertError({absorbed_member, _, _, none, _, _}, check_only(Src)).

%% F3.3 — identical fields with different tags form distinct types.
two_records_over_identical_field_sets_are_two_types_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public atom Which(Doc)\n"
          "Which(Order o) -> :order\n",
    ?assertMatch({error, _}, check_only(Src)).

%% F3.4 — the residual synthesises the missing record head.
%% Printing field types as patterns would bind int as a variable.
the_residual_over_records_synthesises_the_missing_head_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public atom Which(Doc)\n"
          "Which(Order o) -> :order\n",
    {error, Diags} = check_only(Src),
    [{error, _, 'Which', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    %% The residual tuple holds the argument list; its member is the pattern.
    #{tuples := [[Arg]]} = Residual,
    ?assertEqual("{ Kind: :'Shop.Invoice' }", bs_types:to_pattern(Arg)).

%% Paste the emitted head: a hand-written equivalent cannot test its spelling.
the_synthesised_head_compiles_when_pasted_in_test() ->
    Base = "module Shop\n"
           "record Order { Id: int, Total: int }\n"
           "record Invoice { Id: int, Total: int }\n"
           "type Doc = Order | Invoice\n"
           "public atom Which(Doc)\n"
           "Which(Order o) -> :order\n",
    {error, Diags} = check_only(Base),
    [{error, _, 'Which', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    #{tuples := [[Arg]]} = Residual,
    Synthesised = "Which(" ++ bs_types:to_pattern(Arg) ++ ") -> :invoice\n",
    M = build_and_load(Base ++ Synthesised, 'Shop'),
    ?assertEqual(invoice, M:'Which'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    ?assertEqual(order, M:'Which'(an_order())).

%% F3.5 — with preserves the field set and tag.
with_is_width_preserving_and_keeps_the_tag_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(#{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 500},
                 M:'Pay'(an_order())).

with_cannot_add_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> o with { Extra = 1 }\n",
    ?assertMatch([{error, _, 'Grow',
                   {field_set_mismatch, 'Order', update, [], ['Extra']}}],
                 errors(Src)).

%% F3.6 — spread is refused.
spread_is_not_in_the_language_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> { ..o, Extra = 1 }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    ?assertMatch({error, _}, bs_parser:parse(Toks)).

%% F3.7 — the dot projects; a lowercase receiver distinguishes a value.
the_dot_projects_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Amount'(an_order())),
    ?assertEqual(8, M:'Total'(7)).

%% Count only the body: the guard has a separate map_get for the tag.
the_dot_emits_one_map_get_test() ->
    [{function, _, 'Amount', 1, [{clause, _, _, _Guards, Body}]}] =
        [F || F = {function, _, 'Amount', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Body, map_get)).

%% F3.8 — union projection emits one map_get for a shared field.
union_projection_emits_one_map_get_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Either'(an_order())),
    ?assertEqual(9, M:'Either'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Either, map_get)).

%% F3.9 — an exported record parameter receives only a tag test.
an_exported_record_parameter_gets_one_tag_test_test() ->
    Forms = shop_forms(),
    [{function, _, 'Pay', 1, [{clause, _, _, Guards, _}]}] =
        [F || F = {function, _, 'Pay', 1, _} <- Forms],
    ?assertEqual(1, count(Guards, map_get)),
    %% Exact-field checks belong where code generation consumes the record.
    ?assertEqual(0, count(Guards, has_map_fields) + count(Guards, map_size)).

the_tag_test_rejects_a_foreign_term_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertError(function_clause,
                 M:'Pay'(#{'Kind' => 'Shop.Invoice', 'Id' => 1, 'Total' => 0})).

a_union_parameter_gets_no_tag_test_test() ->
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    {function, _, _, _, [{clause, _, _, Guards, _}]} = Either,
    ?assertEqual([], Guards).

%% F3.11 — optional field modifiers are refused.
there_is_no_optional_field_modifier_test() ->
    Src = "module Shop\nrecord Profile { Id: int, Notes?: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "no optional fields") =/= nomatch).

%% F3.12 — the emitted spec is a precise map type.
the_emitted_spec_is_a_precise_map_test() ->
    Forms = shop_forms(),
    [Spec] = [S || S = {attribute, _, spec, {{'Draft', 0}, _}} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "'Kind' := 'Shop.Order'") =/= nomatch),
    ?assert(string:find(Printed, "'Total' := integer()") =/= nomatch),
    ?assertEqual(nomatch, string:find(Printed, "map()")).

a_declared_kind_field_is_an_error_test() ->
    Src = "module Shop\nrecord Order { Kind: int, Total: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertError({kind_field_is_minted, _, 'Order'}, bs_check:check(Decls)).

%% Longest-match lexing treats :int in Id:int as an atom.
a_field_without_a_space_says_what_to_do_test() ->
    Src = "module Shop\nrecord Order { Id:int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "lexes as an atom") =/= nomatch).
