%%% F49 — `ValidationError` as a record (ticket 79).
%%%
%%% AT THE BOUNDARY, WHICH IS A RUNNING PROGRAM. Every test compiles B#, loads
%%% the `.beam` and calls it, so what is asserted is the value a caller gets and
%%% the clause heads that value reaches — never the stratum entry or the emitted
%%% abstract format.
%%%
%%% THE PAIR THAT MATTERS IS F49.1 BESIDE F49.4. A build that changes the type
%%% and leaves the validator emitting the tuple compiles every program here and
%%% fails F49.1 at run time; a build that leaves construction minting
%%% `'VeOrders.ValidationError'` fails F49.4. Neither is visible to the checker.
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

%% F49.1 — the record pattern reads the value the validator emits. The pattern
%% compiling is the checker's half; this is the half only a run can see.
a_record_pattern_takes_apart_what_the_validator_returns_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertEqual([<<".Total">>], M:'Where'(bad_order())),
    ?assertEqual([], M:'Where'((bad_order())#{'Total' => 5})).

%% F49.2 — the value itself: a map carrying the bare tag, inside the unchanged
%% `(:error, …)` wrapper.
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

%% F49.4 — construction by hand carries the tag the validator emits, so a value
%% a program builds reaches the same clause heads as one the validator returns.
a_hand_built_value_carries_the_bare_tag_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertEqual(#{'Kind' => 'ValidationError', 'Path' => [<<"x">>],
                   'Expected' => <<"int">>},
                 M:'Built'([<<"x">>])),
    ?assertEqual([<<"x">>], M:'RoundTrip'([<<"x">>])).

%% F49.5 — a public `ValidationError` parameter is guarded on the tag, as every
%% record parameter is: the tuple F18 used to return is not one.
the_old_tuple_is_refused_at_the_boundary_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    ?assertError(function_clause, M:'Rejected'({[<<".Total">>], <<"int">>})).

%% F49.6 — the platform's encoder takes the value, which is why the carrier
%% moved (ticket 77): the tuple it replaced raised `unsupported_type`.
the_value_goes_on_the_wire_test() ->
    M = build_and_load(orders_src(), 'VeOrders'),
    {error, E} = M:'Decode'(bad_order()),
    Json = iolist_to_binary(json:encode(E)),
    ?assertEqual(#{<<"Kind">> => <<"ValidationError">>,
                   <<"Path">> => [<<".Total">>],
                   <<"Expected">> => <<"int">>},
                 json:decode(Json)).
