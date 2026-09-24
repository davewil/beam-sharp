%%% F50 — ToJson serialises values and refuses unencodable types.
%%% Compare decoded objects because JSON key order depends on the atom table.
%%% Refusals use the CLI's published descriptors, not internal checker terms.
%%% Scenarios: compiler/features/F50-to-json.md
-module(to_json_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, with_src/3]).

orders_src() ->
    "module TjOrders\n"
    "record Order  { Id: int, Total: int }\n"
    "record Parcel { Id: int, Note: option<int> }\n"
    "type Flag = :null | :true | :false | :ok\n"
    "public string OrderBody(Order o)\n"
    "OrderBody(o) -> ToJson<Order>(o)\n"
    "public string ParcelBody(Parcel p)\n"
    "ParcelBody(p) -> ToJson<Parcel>(p)\n"
    "public string Outcome(term t)\n"
    "Outcome(t) -> ValidateAs<Order>(t) switch {\n"
    "    (:error, e) => ToJson<ValidationError>(e),\n"
    "    o           => OrderBody(o)\n"
    "}\n"
    "public string Batch(list<Order> os)\n"
    "Batch(os) -> ToJson<list<Order>>(os)\n"
    "public string Flags(list<Flag> fs)\n"
    "Flags(fs) -> ToJson<list<Flag>>(fs)\n"
    "public string Counts(map<atom, int> m)\n"
    "Counts(m) -> ToJson<map<atom, int>>(m)\n".

an_order() -> #{'Kind' => 'TjOrders.Order', 'Id' => 1, 'Total' => 5}.

decoded(Bin) when is_binary(Bin) -> json:decode(Bin).

%%% F50.1 — a record goes on the wire as an object carrying its `Kind`

a_record_is_an_object_with_its_kind_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5},
                 decoded(M:'OrderBody'(an_order()))).

%%% F50.2 — `option<T>` at `:nothing` is the string `"nothing"`, key present

an_absent_option_is_the_string_nothing_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    Parcel = #{'Kind' => 'TjOrders.Parcel', 'Id' => 1},
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Parcel">>, <<"Id">> => 1,
                   <<"Note">> => <<"nothing">>},
                 decoded(M:'ParcelBody'(Parcel#{'Note' => nothing}))),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Parcel">>, <<"Id">> => 1, <<"Note">> => 3},
                 decoded(M:'ParcelBody'(Parcel#{'Note' => 3}))).

%%% F50.3 — a ValidationError record goes on the wire.

a_validation_error_goes_on_the_wire_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(#{<<"Kind">> => <<"ValidationError">>, <<"Path">> => [<<".Total">>],
                   <<"Expected">> => <<"int">>},
                 decoded(M:'Outcome'((an_order())#{'Total' => x}))),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5},
                 decoded(M:'Outcome'(an_order()))).

%%% F50.4 — lists, atoms and maps use the platform JSON mapping.

lists_atoms_and_maps_follow_the_platform_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(<<"[null,true,false,\"ok\"]">>, M:'Flags'([null, true, false, ok])),
    ?assertEqual([#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5}],
                 decoded(M:'Batch'([an_order()]))),
    ?assertEqual(<<"[]">>, M:'Batch'([])),
    ?assertEqual(#{<<"a">> => 1, <<"b">> => 2}, decoded(M:'Counts'(#{a => 1, b => 2}))).

%%% F50.8 — a value that does not inhabit `T` crashes rather than go out

%% The public parameter guard checks only the tag, so extra fields reach
%% the encoder's exact-field guard.
an_undeclared_field_is_not_published_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertError({to_json, #{'Kind' := 'ValidationError'}},
                 M:'OrderBody'((an_order())#{'Secret' => <<"hunter2">>})).

a_field_of_the_wrong_type_is_not_published_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertError({to_json, #{'Kind' := 'ValidationError', 'Path' := [<<".Total">>]}},
                 M:'OrderBody'((an_order())#{'Total' => <<"5">>})).

%%% F50.14 — a recursive type: the walk terminates, and still finds a tuple

tree_src(SlotType) ->
    "module TjTree\n"
    "record Node { Value: " ++ SlotType ++ ", Kids: list<Node> }\n"
    "public string Body(Node n)\n"
    "Body(n) -> ToJson<Node>(n)\n".

a_recursive_record_encodes_test() ->
    M = build_and_load(tree_src("int"), 'TjTree'),
    Leaf = #{'Kind' => 'TjTree.Node', 'Value' => 2, 'Kids' => []},
    ?assertEqual(#{<<"Kind">> => <<"TjTree.Node">>, <<"Value">> => 1,
                   <<"Kids">> => [#{<<"Kind">> => <<"TjTree.Node">>, <<"Value">> => 2,
                                    <<"Kids">> => []}]},
                 decoded(M:'Body'(#{'Kind' => 'TjTree.Node', 'Value' => 1,
                                    'Kids' => [Leaf]}))).

a_tuple_inside_a_recursive_record_is_refused_test() ->
    ?assertMatch(#{kind := tuple, path := [".Value"], member := "(int, int)"},
                 the_refusal(tree_src("(int, int)"))).

%%% The refusals, read off the published term

published(Src) ->
    with_src("in.bs", Src, fun(Path, Root) ->
        {Rc, Out, _} = bs_test_support:run_cli_split_result(
                         "--diagnostics term --src-root " ++ Root ++ " " ++ Path),
        {Rc, [parse_term(L) || L <- string:split(string:trim(Out), "\n", all), L =/= ""]}
    end).

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

the_refusal(Src) ->
    {Rc, Descs} = published(Src),
    ?assertEqual(1, Rc),
    [D] = [D || D = #{tag := unencodable_member} <- Descs],
    D.

%%% F50.5 — a `result` is refused, naming the tuple member

result_src() ->
    "module TjResult\n"
    "record Order { Id: int, Total: int }\n"
    "public string Outcome(result<Order, ValidationError> r)\n"
    "Outcome(r) -> ToJson<result<Order, ValidationError>>(r)\n".

a_result_is_refused_on_its_tuple_test() ->
    D = the_refusal(result_src()),
    %% An empty path means the type root; paths remain lists of segments.
    ?assertMatch(#{obligation := 'ToJson', kind := tuple, path := [],
                   function := 'Outcome', line := 4}, D),
    ?assertNotEqual(nomatch, string:find(maps:get(member, D), "(:error,")).

%%% F50.6 — the walk is over the normalised type, not the members as written

hidden_src() ->
    "module TjHidden\n"
    "type Pair = (int, int)\n"
    "type Slot = Pair | :empty\n"
    "record Box { Id: int, Slot: Slot }\n"
    "public string Boxes(list<Box> bs)\n"
    "Boxes(bs) -> ToJson<list<Box>>(bs)\n".

a_tuple_behind_aliases_is_found_test() ->
    D = the_refusal(hidden_src()),
    ?assertMatch(#{kind := tuple, path := ["[_]", ".Slot"], member := "(int, int)"}, D).

%%% F50.7 — an arrow, `binary` and `term` are refused; `string` is not

kinds_src(FieldType) ->
    "module TjKinds\n"
    "record Row { Id: int, Name: string, Data: " ++ FieldType ++ " }\n"
    "public string Body(Row r)\n"
    "Body(r) -> ToJson<Row>(r)\n".

an_arrow_is_refused_test() ->
    ?assertMatch(#{kind := arrow, path := [".Data"]}, the_refusal(kinds_src("fn(int) -> int"))).

a_binary_is_refused_whole_test() ->
    ?assertMatch(#{kind := binary, path := [".Data"]}, the_refusal(kinds_src("binary"))).

term_is_refused_test() ->
    ?assertMatch(#{kind := term, path := [".Data"]}, the_refusal(kinds_src("term"))).

a_string_field_is_accepted_test() ->
    {Rc, Descs} = published(kinds_src("list<string>")),
    ?assertEqual({0, []}, {Rc, Descs}).

a_tuple_map_key_is_refused_test() ->
    ?assertMatch(#{kind := tuple, path := [".Data", "[key]"]},
                 the_refusal(kinds_src("map<(int, int), int>"))).

%%% F50.9 — a codegen obligation needs a ground `T`

a_type_variable_is_refused_test() ->
    Src = "module TjPoly\n"
          "public string Body<T>(T v)\n"
          "Body(v) -> ToJson<T>(v)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := obligation_over_type_variable, obligation := 'ToJson'}],
                 [D || D = #{severity := error} <- Descs]).

%%% F50.10 — the argument must inhabit T.

an_argument_outside_t_is_refused_test() ->
    Src = "module TjArg\n"
          "record Order { Id: int, Total: int }\n"
          "public string Body(int n)\n"
          "Body(n) -> ToJson<Order>(n)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := arg_not_accepted}], [D || D = #{severity := error} <- Descs]).

%%% F50.12 — the prose names the obligation, the member and the path

the_prose_names_member_and_path_test() ->
    with_src("in.bs", hidden_src(), fun(Path, Root) ->
        {1, _, Err} = bs_test_support:run_cli_split_result(
                        "--src-root " ++ Root ++ " " ++ Path),
        ?assertNotEqual(nomatch, string:find(Err, "error: Boxes calls ToJson over a type with no wire form")),
        ?assertNotEqual(nomatch, string:find(Err, "in [_].Slot, `(int, int)` is a tuple"))
    end).
