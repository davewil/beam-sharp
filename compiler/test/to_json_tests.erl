%%% F50 — `ToJson<T>`, the serialisation obligation (ticket 77).
%%%
%%% AT THE BOUNDARY, TWICE OVER. What an encoder MEANS is the text a compiled
%%% module returns, so the behavioural half compiles B#, loads the `.beam` and
%%% calls it. What a refusal MEANS is the diagnostic `bsc` publishes, so the
%%% refusal half runs the built escript with `--diagnostics term` and reads the
%%% descriptor off stdout — the channel ticket 23 publishes — rather than the
%%% tuple the checker raises on the way there.
%%%
%%% THE WIRE IS COMPARED DECODED, NEVER AS TEXT. `json:encode` writes a map's
%%% keys in the order the VM created their atoms (measured 2026-09-15, OTP
%%% 28.5), so the same record can come out `{"Kind":…,"Id":…}` in one program
%%% and `{"Id":…,"Kind":…}` in another. A test pinning the text would be
%%% pinning atom-table history (ENG-349 is the same effect on the term channel).
%%%
%%% THE PAIR THAT MATTERS IS F50.5 BESIDE F50.6. `result<Order, ValidationError>`
%%% hides its tuple behind a parametric alias; `Slot` hides one behind two plain
%%% aliases and a record field. A walk over the members as WRITTEN sees neither.
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

%%% ---------------------------------------------------------------------------
%%% F50.1 — a record goes on the wire as an object carrying its `Kind`
%%% ---------------------------------------------------------------------------

a_record_is_an_object_with_its_kind_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5},
                 decoded(M:'OrderBody'(an_order()))).

%%% ---------------------------------------------------------------------------
%%% F50.2 — `option<T>` at `:nothing` is the string `"nothing"`, key present
%%% ---------------------------------------------------------------------------

an_absent_option_is_the_string_nothing_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    Parcel = #{'Kind' => 'TjOrders.Parcel', 'Id' => 1},
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Parcel">>, <<"Id">> => 1,
                   <<"Note">> => <<"nothing">>},
                 decoded(M:'ParcelBody'(Parcel#{'Note' => nothing}))),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Parcel">>, <<"Id">> => 1, <<"Note">> => 3},
                 decoded(M:'ParcelBody'(Parcel#{'Note' => 3}))).

%%% ---------------------------------------------------------------------------
%%% F50.3 — the 422 body: `ValidationError` is a record since F49
%%% ---------------------------------------------------------------------------

a_validation_error_goes_on_the_wire_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(#{<<"Kind">> => <<"ValidationError">>, <<"Path">> => [<<".Total">>],
                   <<"Expected">> => <<"int">>},
                 decoded(M:'Outcome'((an_order())#{'Total' => x}))),
    ?assertEqual(#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5},
                 decoded(M:'Outcome'(an_order()))).

%%% ---------------------------------------------------------------------------
%%% F50.4 — the rest of the mapping reads off the platform
%%% ---------------------------------------------------------------------------

%% `:null`, `:true` and `:false` are JSON's own literals; any other atom is its
%% name. A list is an array, a `map<K, V>` an object with the key stringified.
lists_atoms_and_maps_follow_the_platform_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertEqual(<<"[null,true,false,\"ok\"]">>, M:'Flags'([null, true, false, ok])),
    ?assertEqual([#{<<"Kind">> => <<"TjOrders.Order">>, <<"Id">> => 1, <<"Total">> => 5}],
                 decoded(M:'Batch'([an_order()]))),
    ?assertEqual(<<"[]">>, M:'Batch'([])),
    ?assertEqual(#{<<"a">> => 1, <<"b">> => 2}, decoded(M:'Counts'(#{a => 1, b => 2}))).

%%% ---------------------------------------------------------------------------
%%% F50.8 — a value that does not inhabit `T` crashes rather than go out
%%% ---------------------------------------------------------------------------

%% Ticket 18 §1(c): generated code consuming a value is guarded unconditionally,
%% and 26 §4 names this site as where the exact field set is tested. A public
%% `Order` parameter is guarded on its tag alone, so an extra field reaches the
%% body; without the guard the encoder would publish a field no type declares.
an_undeclared_field_is_not_published_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertError({to_json, #{'Kind' := 'ValidationError'}},
                 M:'OrderBody'((an_order())#{'Secret' => <<"hunter2">>})).

%% The same guard, one field down: the tag is right and a field's type is not.
a_field_of_the_wrong_type_is_not_published_test() ->
    M = build_and_load(orders_src(), 'TjOrders'),
    ?assertError({to_json, #{'Kind' := 'ValidationError', 'Path' := [<<".Total">>]}},
                 M:'OrderBody'((an_order())#{'Total' => <<"5">>})).

%%% ---------------------------------------------------------------------------
%%% F50.14 — a recursive type: the walk terminates, and still finds a tuple
%%% ---------------------------------------------------------------------------

%% The walk carries a `Seen` list of binder names, as `has_arrow/2` does. Without
%% it a self-referential record does not refuse or accept — it hangs, which no
%% other assertion here would catch.
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

%%% ---------------------------------------------------------------------------
%%% The refusals, read off the published term
%%% ---------------------------------------------------------------------------

%% Every descriptor `bsc --diagnostics term` prints for `Src`, and its status.
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

%%% ---------------------------------------------------------------------------
%%% F50.5 — a `result` is refused, naming the tuple member
%%% ---------------------------------------------------------------------------

result_src() ->
    "module TjResult\n"
    "record Order { Id: int, Total: int }\n"
    "public string Outcome(result<Order, ValidationError> r)\n"
    "Outcome(r) -> ToJson<result<Order, ValidationError>>(r)\n".

a_result_is_refused_on_its_tuple_test() ->
    D = the_refusal(result_src()),
    %% The path is a list of segments, and empty at the top: an empty STRING
    %% would go out on the JSON channel as `[]`, an array (F47's list rule).
    ?assertMatch(#{obligation := 'ToJson', kind := tuple, path := [],
                   function := 'Outcome', line := 4}, D),
    ?assertNotEqual(nomatch, string:find(maps:get(member, D), "(:error,")).

%%% ---------------------------------------------------------------------------
%%% F50.6 — the walk is over the normalised type, not the members as written
%%% ---------------------------------------------------------------------------

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

%%% ---------------------------------------------------------------------------
%%% F50.7 — an arrow, `binary` and `term` are refused; `string` is not
%%% ---------------------------------------------------------------------------

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

%% A map key is a position too: the platform stringifies an atom, an integer or
%% a binary, and refuses a tuple.
a_tuple_map_key_is_refused_test() ->
    ?assertMatch(#{kind := tuple, path := [".Data", "[key]"]},
                 the_refusal(kinds_src("map<(int, int), int>"))).

%%% ---------------------------------------------------------------------------
%%% F50.9 — a codegen obligation needs a ground `T`
%%% ---------------------------------------------------------------------------

a_type_variable_is_refused_test() ->
    Src = "module TjPoly\n"
          "public string Body<T>(T v)\n"
          "Body(v) -> ToJson<T>(v)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := obligation_over_type_variable, obligation := 'ToJson'}],
                 [D || D = #{severity := error} <- Descs]).

%%% ---------------------------------------------------------------------------
%%% F50.10 — and the value handed over must be a `T`
%%% ---------------------------------------------------------------------------

an_argument_outside_t_is_refused_test() ->
    Src = "module TjArg\n"
          "record Order { Id: int, Total: int }\n"
          "public string Body(int n)\n"
          "Body(n) -> ToJson<Order>(n)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := arg_not_accepted}], [D || D = #{severity := error} <- Descs]).

%%% ---------------------------------------------------------------------------
%%% F50.12 — the prose names the obligation, the member and the path
%%% ---------------------------------------------------------------------------

the_prose_names_member_and_path_test() ->
    with_src("in.bs", hidden_src(), fun(Path, Root) ->
        {1, _, Err} = bs_test_support:run_cli_split_result(
                        "--src-root " ++ Root ++ " " ++ Path),
        ?assertNotEqual(nomatch, string:find(Err, "error: Boxes calls ToJson over a type with no wire form")),
        ?assertNotEqual(nomatch, string:find(Err, "in [_].Slot, `(int, int)` is a tuple"))
    end).
