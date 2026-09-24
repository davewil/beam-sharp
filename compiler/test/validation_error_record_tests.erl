%%% F49 — ValidationError is a record.
%%% Scenarios: compiler/features/F49-validation-error-record.md
-module(validation_error_record_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2]).

orders_src() ->
    "module VeOrders\n"
    "record Order { Id: int, Total: int }\n"
    "public result<Order, ValidationError> Decode(term t)\n"
    "Decode(t) -> ValidateAs<Order>(t)\n"
    "public list<string> Rejected(ValidationError e)\n"
    "Rejected(ValidationError { Path: p }) -> p\n"
    "public list<string> Where(term t)\n"
    "Where(t) -> Decode(t) switch {\n"
    "    (:error, e) => Rejected(e),\n"
    "    o           => []\n"
    "}\n"
    "public string Expected(ValidationError e)\n"
    "Expected(e) -> e.Expected\n"
    "public ValidationError Built(list<string> p)\n"
    "Built(p) -> ValidationError { Path = p, Expected = \"int\" }\n"
    "public list<string> RoundTrip(list<string> p)\n"
    "RoundTrip(p) -> Rejected(Built(p))\n".

bad_order() -> #{'Kind' => 'VeOrders.Order', 'Id' => 1, 'Total' => x}.

%% F49.1 — a record pattern reads the value the validator emits.
a_record_pattern_takes_apart_what_the_validator_returns_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertEqual([<<".Total">>], M:'Where'(bad_order())),
    ?assertEqual([], M:'Where'((bad_order())#{'Total' => 5})).

%% F49.2 — the validator returns a bare-tagged map inside the error wrapper.
the_validator_returns_the_record_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertEqual({error, #{'Kind' => 'ValidationError',
                           'Path' => [<<".Total">>],
                           'Expected' => <<"int">>}},
                 M:'Decode'(bad_order())).

%% F49.3 — a projection reads a field.
a_projection_reads_the_expected_type_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    {error, E} = M:'Decode'(bad_order()),
    ?assertEqual(<<"int">>, M:'Expected'(E)).

%% F49.4 — hand-built values carry the validator tag and match the same heads.
a_hand_built_value_carries_the_bare_tag_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertEqual(#{'Kind' => 'ValidationError', 'Path' => [<<"x">>],
                   'Expected' => <<"int">>},
                 M:'Built'([<<"x">>])),
    ?assertEqual([<<"x">>], M:'RoundTrip'([<<"x">>])).

%% F49.5 — the public record parameter rejects a tuple at its tag guard.
the_old_tuple_is_refused_at_the_boundary_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertError(function_clause, M:'Rejected'({[<<".Total">>], <<"int">>})).

%% F49.6 — the platform JSON encoder accepts the validation error.
the_value_goes_on_the_wire_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    {error, E} = M:'Decode'(bad_order()),
    Json = iolist_to_binary(json:encode(E)),
    ?assertEqual(#{<<"Kind">> => <<"ValidationError">>,
                   <<"Path">> => [<<".Total">>],
                   <<"Expected">> => <<"int">>},
                 json:decode(Json)).
