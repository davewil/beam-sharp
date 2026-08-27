-module(records_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          shop_src/0, an_order/0, count/2]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F3 — records. Scenario ids are the feature file's, so a failure names the
%%% thing it was built to satisfy.
%%%
%%% Every claim here is routed through EXHAUSTIVENESS or through the emitted
%%% term, because `bs_check` never visits a function body — F3 §2. Three
%%% scenarios the feature reserves ids for (F3.3's call-site rejection, F3.8's
%%% projection error, F3.10's exact construction) are deferred with it and are
%%% NOT asserted below; a test claiming them would be testing a check site that
%%% does not exist.
%%% ---------------------------------------------------------------------------


shop_forms() ->
    {ok, _} = compile(shop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Shop.beam", [abstract_code]),
    Forms.


%% F3.1 — the term is a tagged map, and the tag mints from the QUALIFIED name.
a_record_constructs_a_tagged_map_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(an_order(), M:'Draft'()).

%% F3.2 — §1's own test that the minting is not nominality. Routed through
%% exhaustiveness: if the mint created an identity, `Either` would be a union of
%% two things and one clause would leave a residual.
a_hand_written_type_with_the_same_tag_is_the_same_type_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "type Spelled = { Kind: :'Shop.Order', Id: int, Total: int }\n"
          "type Either = Order | Spelled\n"
          "public atom Which(Either)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F3.3 — identical field sets, different tags, two types. Under ticket 09
%% before the minting this WOULD have been exhaustive, which is the whole point.
two_records_over_identical_field_sets_are_two_types_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public atom Which(Doc)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    ?assertMatch({error, _}, check_only(Src)).

%% F3.4 — the residual synthesises the head you must write. Ticket 23: a head
%% derived from the residual cannot be wrong, and the discriminator is the whole
%% head — printing the full field set would paste `int` in as a VARIABLE name.
the_residual_over_records_synthesises_the_missing_head_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public atom Which(Doc)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    {error, Diags} = check_only(Src),
    [{error, _, 'Which', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    %% The residual's tuple part is the ARGUMENT LIST, so the head is built from
    %% its components — the same unpacking `bsc:heads/2` does to print it.
    #{tuples := [[Arg]]} = Residual,
    ?assertEqual("{ Kind: :'Shop.Invoice' }", bs_types:to_pattern(Arg)).

%% ...and pasting it in compiles clean, which is the half that makes it useful.
%%
%% The head is taken from the FAILING RUN and spliced in, rather than written
%% out here. Transcribing it would test that a head someone already knows works
%% works, which is adjacent to the claim: what F3.4 asserts is that the string
%% the compiler *emits* is something you can paste. Ticket 23 — the compiler
%% synthesises the head and a head derived from the residual cannot be wrong —
%% is only worth anything if that is checked rather than assumed.
the_synthesised_head_compiles_when_pasted_in_test() ->
    Base = "module Shop\n"
           "record Order { Id: int, Total: int }\n"
           "record Invoice { Id: int, Total: int }\n"
           "type Doc = Order | Invoice\n"
           "public atom Which(Doc)\n"
           "Which({ Kind: :'Shop.Order' }) -> :order\n",
    {error, Diags} = check_only(Base),
    [{error, _, 'Which', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    #{tuples := [[Arg]]} = Residual,
    Synthesised = "Which(" ++ bs_types:to_pattern(Arg) ++ ") -> :invoice\n",
    M = build_and_load(Base ++ Synthesised, 'Shop'),
    ?assertEqual(invoice, M:'Which'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    ?assertEqual(order, M:'Which'(an_order())).

%% F3.5 — `with` is width-preserving and the tag survives it. §2's sentence,
%% which is what pays ticket 27 §7's debt rather than reopening row polymorphism.
with_is_width_preserving_and_keeps_the_tag_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(#{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 500},
                 M:'Pay'(an_order())).

%% ...and it cannot WIDEN, because `:=` raises rather than adding a key. That is
%% the mechanism behind §5 closing row polymorphism rather than deferring it.
%% F21 / ticket 36 REWROTE THIS TEST, and the old body is why the ticket exists.
%%
%% It used to build the module, call it, and assert `{badkey, 'Extra'}` — that
%% is, it certified that `with` cannot add a field *by observing the BEAM raise*.
%% 26 §2 is real, but F3 was enforcing it at RUN time and this test recorded
%% that as the intended behaviour, so nothing was left to notice the compiler
%% had never checked. Measuring ticket 36 found it: a proved-exhaustive program
%% that crashes, the shape ticket 54 was about.
%%
%% The claim is now made where 26 §2 belongs. The runtime half needs no test: it
%% is `erlc`'s `:=`, and it can no longer be reached from source that compiles.
with_cannot_add_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> o with { Extra = 1 }\n",
    ?assertMatch([{error, _, 'Grow',
                   {field_set_mismatch, 'Order', update, [], ['Extra']}}],
                 errors(Src)).

%% F3.6 — spread is not in the language. §2 refused it on a specific ground, so
%% the refusal gets a test rather than being an omission.
spread_is_not_in_the_language_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> { ..o, Extra = 1 }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    ?assertMatch({error, _}, bs_parser:parse(Toks)).

%% F3.7 — the dot projects and is never a call, and the disambiguation is
%% LEXICAL: a lowercase receiver is a value. So a field and a function may share
%% a name, told apart by syntax rather than by resolution.
the_dot_projects_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Amount'(an_order())),
    ?assertEqual(8, M:'Total'(7)).

%% Counted in the BODY, because the guard has a `map_get` of its own — F3.9's
%% tag test. Two map_gets on this function is the correct number and they are
%% two different obligations; conflating them is what the split asserts against.
the_dot_emits_one_map_get_test() ->
    [{function, _, 'Amount', 1, [{clause, _, _, _Guards, Body}]}] =
        [F || F = {function, _, 'Amount', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Body, map_get)).

%% F3.8 — projection over a union is legal where every member carries the field,
%% and emits ONE map_get whichever member arrived. §3: the map erasure paid for
%% this without knowing it — under the tuple erasure §1 rejected, the field sits
%% at a different offset per member and this would need real dispatch.
union_projection_emits_one_map_get_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Either'(an_order())),
    ?assertEqual(9, M:'Either'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Either, map_get)).

%% F3.9 — an exported record parameter's guard is ONE tag test and no more.
%% Ticket 26 §1's two-tier allocation: the tag test is unconditional because a
%% body projects fields and so can never object to the tag; the exact-set test
%% is second tier and belongs where a codegen obligation consumes the record,
%% and none exists yet — so its absence is the correct observation, not a gap.
an_exported_record_parameter_gets_one_tag_test_test() ->
    Forms = shop_forms(),
    [{function, _, 'Pay', 1, [{clause, _, _, Guards, _}]}] =
        [F || F = {function, _, 'Pay', 1, _} <- Forms],
    ?assertEqual(1, count(Guards, map_get)),
    %% No exact-field-set test — that is the second tier.
    ?assertEqual(0, count(Guards, has_map_fields) + count(Guards, map_size)).

%% The guard actually fires: a map wearing the wrong tag does not get in.
the_tag_test_rejects_a_foreign_term_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertError(function_clause,
                 M:'Pay'(#{'Kind' => 'Shop.Invoice', 'Id' => 1, 'Total' => 0})).

%% A union parameter gets NO tag test — a disjunction over tags is a different
%% shape from the one F3.9 specifies. A deliberate narrowing, pinned so that
%% widening it later is a decision rather than a surprise.
a_union_parameter_gets_no_tag_test_test() ->
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    {function, _, _, _, [{clause, _, _, Guards, _}]} = Either,
    ?assertEqual([], Guards).

%% F3.11 — there are no absent fields (§4). The kept form is
%% `Notes: option<int>`, which needs the angle brackets F4 has not landed, so
%% the diagnostic says what the language lacks rather than naming a spelling
%% that cannot yet parse.
there_is_no_optional_field_modifier_test() ->
    Src = "module Shop\nrecord Profile { Id: int, Notes?: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "no optional fields") =/= nomatch).

%% F3.12 — the emitted spec is a precise map type, not `map()` and not `any()`.
the_emitted_spec_is_a_precise_map_test() ->
    Forms = shop_forms(),
    [Spec] = [S || S = {attribute, _, spec, {{'Draft', 0}, _}} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "'Kind' := 'Shop.Order'") =/= nomatch),
    ?assert(string:find(Printed, "'Total' := integer()") =/= nomatch),
    ?assertEqual(nomatch, string:find(Printed, "map()")).

%% The tag is minted, so a record may not declare its own `Kind`. Erroring at
%% the DECLARATION rather than at a use is ticket 15's collapse rule again.
a_declared_kind_field_is_an_error_test() ->
    Src = "module Shop\nrecord Order { Kind: int, Total: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertError({kind_field_is_minted, _, 'Order'}, bs_check:check(Decls)).

%% `Id:int` lexes `:int` as an atom, because longest-match prefers the sigil.
%% The parser catches the shape by name rather than letting it surface as an
%% opaque syntax error.
a_field_without_a_space_says_what_to_do_test() ->
    Src = "module Shop\nrecord Order { Id:int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "lexes as an atom") =/= nomatch).
