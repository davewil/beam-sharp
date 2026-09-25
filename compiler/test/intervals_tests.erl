%%% Scenarios: compiler/features/F2-interval-refinements.md
-module(intervals_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% F2 — interval refinements and patterns.

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%%% F2.1 — a refinement narrows the emitted spec.

a_refined_parameter_narrows_the_spec_test() ->
    Src = "module Wire\n" ++ octet() ++
          "public Octet Clamp(Octet)\n"
          "Clamp(n) -> n\n",
    {ok, _} = compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Wire.beam", [abstract_code]),
    [Spec] = [F || F = {attribute, _, spec, _} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "0..255") =/= nomatch),
    %% A range alongside integer() would still admit every integer.
    ?assertEqual(nomatch, string:find(Printed, "integer()")).

a_refinement_is_a_subtype_of_its_base_test() ->
    Src = "module Sub\n" ++ octet() ++
          "public int Widen(Octet n)\n"
          "Widen(n) -> n\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

the_base_is_not_a_subtype_of_the_refinement_test() ->
    Src = "module Narrow\n" ++ octet() ++
          "public atom Take(Octet n)\n"
          "Take(n) -> :ok\n"
          "public atom Give(int n)\n"
          "Give(n) -> Take(n)\n",
    ?assertMatch([{error, _, 'Give', {arg_not_accepted, 'Take', 1, _, _}}],
                 errors(Src)).

%% An unreadable predicate must not silently widen to the base type.
an_unreadable_refinement_predicate_is_an_error_test() ->
    Src = "module Opaque\n"
          "public atom WellFormed(int n)\n"
          "WellFormed(n) -> :yes\n"
          "type Email = int where WellFormed(value)\n"
          "public atom Take(Email e)\n"
          "Take(e) -> :ok\n",
    ?assertError({opaque_refinement, _}, check_only(Src)).

a_refinement_naming_something_other_than_value_is_an_error_test() ->
    Src = "module Elsewhere\n"
          "type Odd = int where n > 0\n"
          "public atom Take(Odd o)\n"
          "Take(o) -> :ok\n",
    ?assertError({opaque_refinement, _}, check_only(Src)).

a_self_contradictory_refinement_is_an_error_test() ->
    Src = "module Empty\n"
          "type Nothing = int where value > 0 and value < 0\n"
          "public atom Take(Nothing n)\n"
          "Take(n) -> :ok\n",
    ?assertError({empty_refinement, _}, check_only(Src)).

%%% F2.2 — a closed residual refuses a catch-all.

a_catch_all_over_a_closed_residual_is_an_error_test() ->
    Src = "module Frame\n" ++ octet() ++
          "public atom Classify(Octet)\n"
          "Classify(1) -> :method\n"
          "Classify(2) -> :header\n"
          "Classify(3) -> :body\n"
          "Classify(8) -> :heartbeat\n"
          "Classify(_) -> :reserved\n",
    [{error, _, 'Classify', {catch_all_over_closed, Residual, _}}] = errors(Src),
    %% The diagnostic must identify exactly the unhandled octet ranges.
    ?assertEqual("(0 | 4..7 | 9..255)", bs_types:to_pattern(Residual)).

%% An unbounded integer residual permits a catch-all.
a_catch_all_over_an_open_residual_is_legal_test() ->
    Src = "module Open\n"
          "public atom Classify(int n)\n"
          "Classify(1) -> :one\n"
          "Classify(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% A named binder keeps the value; only a wildcard discards it.
a_named_binder_is_not_a_catch_all_test() ->
    Src = "module Named\n" ++ octet() ++
          "public atom Classify(Octet)\n"
          "Classify(1) -> :one\n"
          "Classify(n) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% The untranslatable guard credits no values but prevents a catch-all error.
a_guarded_wildcard_is_not_a_catch_all_test() ->
    Src = "module Guarded\n" ++ octet() ++
          "public atom Classify(Octet)\n"
          "Classify(_) when 1 > 0 -> :anything\n",
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _, _}}], errors(Src)).

a_catch_all_arm_over_a_closed_residual_is_an_error_test() ->
    Src = "module Arms\n"
          "type Event = :placed | :shipped | :cancelled\n"
          "public atom Which(Event e)\n"
          "Which(e) -> e switch {\n"
          "    :placed => :new,\n"
          "    _       => :other\n"
          "}\n",
    ?assertMatch([{error, _, 'Which', {catch_all_over_closed, _, _}}], errors(Src)).

%% ENG-402, ticket 101: a record member closes on its tag whatever its fields
%% hold, so an `int` field leaves the residual as nameable as an atom field.
events() ->
    "module Orders\n"
    "record OrderPlaced    { Id: int }\n"
    "record OrderShipped   { Id: int }\n"
    "record OrderCancelled { Id: int }\n"
    "type Event = OrderPlaced | OrderShipped | OrderCancelled\n".

a_catch_all_over_records_with_an_int_field_is_an_error_test() ->
    Src = events() ++
          "public atom Handle(Event e)\n"
          "Handle(OrderPlaced p)  -> :placed\n"
          "Handle(OrderShipped s) -> :shipped\n"
          "Handle(_)              -> :other\n",
    with_src("orders.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(Got, "Handle discards cases the compiler can name")
                             =/= nomatch),
                     ?assert(string:find(Got, "Handle(OrderCancelled o) -> ...") =/= nomatch),
                     ?assert(string:find(Got, "rc:1") =/= nomatch)
             end).

a_catch_all_arm_over_records_with_an_int_field_is_an_error_test() ->
    Src = events() ++
          "public atom Handle(Event e)\n"
          "Handle(e) -> e switch {\n"
          "    OrderPlaced p  => :placed,\n"
          "    OrderShipped s => :shipped,\n"
          "    _              => :other\n"
          "}\n",
    ?assertMatch([{error, _, 'Handle', {catch_all_over_closed, _, _}}], errors(Src)).

%% The open atom universe beside the records still admits `_`.
a_catch_all_over_records_and_atom_is_legal_test() ->
    Src = events() ++
          "type Input = Event | atom\n"
          "public atom Handle(Input e)\n"
          "Handle(OrderPlaced p)  -> :placed\n"
          "Handle(OrderShipped s) -> :shipped\n"
          "Handle(_)              -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% A tuple does not close on its first element: `(:ok, int)` stays open.
a_catch_all_over_a_tuple_with_an_int_part_is_legal_test() ->
    Src = "module Reading\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "public atom Classify(Reading r)\n"
          "Classify((:error, e)) -> :failed\n"
          "Classify(_)           -> :read\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

a_catch_all_over_a_tuple_of_literals_is_still_an_error_test() ->
    Src = "module Pairs\n"
          "type Pair = (:a, :x) | (:b, :y)\n"
          "public atom Classify(Pair p)\n"
          "Classify((:a, :x)) -> :first\n"
          "Classify(_)       -> :second\n",
    ?assertMatch([{error, _, 'Classify', {catch_all_over_closed, _, _}}], errors(Src)).

%%% F2.3 — an interval pattern names a span.

an_interval_pattern_discharges_a_closed_residual_test() ->
    M = build_and_load(frame_src(), 'Frame2'),
    ?assertEqual(method,    M:'Classify'(1)),
    ?assertEqual(heartbeat, M:'Classify'(8)),
    ?assertEqual(reserved,  M:'Classify'(0)),
    %% Both endpoints belong to the span.
    ?assertEqual(reserved,  M:'Classify'(4)),
    ?assertEqual(reserved,  M:'Classify'(7)),
    ?assertEqual(reserved,  M:'Classify'(9)),
    ?assertEqual(reserved,  M:'Classify'(255)).

frame_src() ->
    "module Frame2\n" ++ octet() ++
    "type FrameType = :method | :header | :body | :heartbeat | :reserved\n"
    "public FrameType Classify(Octet)\n"
    "Classify(1)             -> :method\n"
    "Classify(2)             -> :header\n"
    "Classify(3)             -> :body\n"
    "Classify(8)             -> :heartbeat\n"
    "Classify(0)             -> :reserved\n"
    "Classify(>= 4 and <= 7) -> :reserved\n"
    "Classify(>= 9)          -> :reserved\n".

%% Both comparisons must constrain the same variable.
an_interval_pattern_lowers_to_a_variable_and_a_guard_test() ->
    {ok, _} = compile(frame_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Frame2.beam", [abstract_code]),
    %% The set includes type metadata and rejects extra generated helpers.
    ?assertEqual([{'Classify', 1}, {'bs@type_atoms', 0}],
                 lists:sort([{N, A} || {function, _, N, A, _} <- Forms])),
    [{function, _, 'Classify', 1, Clauses}] =
        [F || F = {function, _, 'Classify', 1, _} <- Forms],
    Span = lists:nth(6, Clauses),
    %% Ordering does not establish kind; the integer test precedes the span.
    {clause, _, [{var, _, V}], [[Whole]], _} = Span,
    {op, _, 'andalso', Kind, Guard} = Whole,
    ?assertMatch({call, _, {remote, _, {atom, _, erlang}, {atom, _, is_integer}},
                  [{var, _, V}]}, Kind),
    ?assertMatch({op, _, 'andalso',
                  {op, _, '>=', {var, _, V}, {integer, _, 4}},
                  {op, _, '=<', {var, _, V}, {integer, _, 7}}}, Guard).

dropping_the_span_leaves_exactly_the_span_test() ->
    Src = "module Gap\n" ++ octet() ++
          "public atom Classify(Octet)\n"
          "Classify(>= 0 and <= 3) -> :low\n"
          "Classify(>= 8)          -> :high\n",
    [{error, _, 'Classify', {inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("(4..7)", bs_types:to_pattern(Residual)).

a_negative_bound_parses_and_dispatches_test() ->
    Src = "module Signs\n"
          "public atom Classify(int n)\n"
          "Classify(<= -1)         -> :negative\n"
          "Classify(>= 0 and <= 3) -> :low\n"
          "Classify(>= 4)          -> :high\n",
    M = build_and_load(Src, 'Signs'),
    ?assertEqual(negative, M:'Classify'(-1)),
    ?assertEqual(low,      M:'Classify'(0)),
    ?assertEqual(high,     M:'Classify'(4)).

the_or_combinator_is_a_union_test() ->
    Src = "module Either\n"
          "public atom Classify(int n)\n"
          "Classify(<= 0 or >= 10) -> :outer\n"
          "Classify(>= 1 and <= 9) -> :inner\n",
    M = build_and_load(Src, 'Either'),
    ?assertEqual(outer, M:'Classify'(0)),
    ?assertEqual(outer, M:'Classify'(10)),
    ?assertEqual(inner, M:'Classify'(5)).

an_interval_pattern_works_in_a_switch_arm_test() ->
    Src = "module Sizing\n"
          "public atom Size(int n)\n"
          "Size(n) -> n switch {\n"
          "    >= 129           => :high,\n"
          "    >= 65 and <= 128 => :mid,\n"
          "    <= 64            => :low\n"
          "}\n",
    M = build_and_load(Src, 'Sizing'),
    ?assertEqual(high, M:'Size'(200)),
    ?assertEqual(mid,  M:'Size'(70)),
    ?assertEqual(low,  M:'Size'(1)).

%% F2 — relational patterns are refused inside records and tuples.
a_relational_pattern_inside_a_record_pattern_is_refused_test() ->
    Src = "module Nested\n"
          "record Order { Total: int }\n"
          "public atom Big(Order o)\n"
          "Big({ Total: >= 100 }) -> :big\n",
    ?assertError({relational_pattern_nested, _}, check_only(Src)).

a_relational_pattern_inside_a_tuple_is_refused_test() ->
    Src = "module Tup\n"
          "public atom Big((int, int) p)\n"
          "Big((>= 100, x)) -> :big\n",
    ?assertError({relational_pattern_nested, _}, check_only(Src)).

%% Even an irrefutable relational bind has no guard site for its test.
a_relational_pattern_in_a_bind_is_refused_test() ->
    Src = "module Bound\n" ++ octet() ++
          "public atom Take(Octet n)\n"
          "Take(n) ->\n"
          "    var >= 0 = n\n"
          "    :ok\n",
    ?assertMatch([{error, _, 'Take', relational_in_bind} | _], errors(Src)).

%%% F2.4 — the residual stays legible at width.

%% The stride prevents adjacent ranges merging, leaving 41 residual cases.
the_residual_truncates_at_three_cases_test() ->
    Src = ["module Scattered\npublic atom Classify(int n)\n"
           | [io_lib:format("Classify(~p) -> :known\n", [N * 10])
              || N <- lists:seq(1, 40)]],
    with_src("scattered.bs", lists:flatten(Src),
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     Lines = [L || L <- string:split(Got, "\n", all),
                                   string:find(L, "Classify(") =/= nomatch],
                     ?assertEqual(3, length(Lines)),
                     ?assert(string:find(Got, "Classify(<= 9) -> ...") =/= nomatch),
                     ?assert(string:find(Got, "Classify(>= 11 and <= 19) -> ...")
                             =/= nomatch),
                     ?assert(string:find(Got, "... (38 more)") =/= nomatch),
                     %% Suggested heads use patterns, not type prefixes.
                     ?assertEqual(nomatch, string:find(Got, "Classify(int"))
             end).

%% The second argument makes the residual a product of integer and atom cases.
the_head_lines_truncate_at_three_too_test() ->
    Src = ["module Two\npublic atom Classify(int n, atom a)\n"
           | [io_lib:format("Classify(~p, :x) -> :known\n", [N * 10])
              || N <- lists:seq(1, 40)]],
    with_src("two.bs", lists:flatten(Src),
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     Lines = [L || L <- string:split(Got, "\n", all),
                                   string:find(L, "Classify(") =/= nomatch],
                     ?assertEqual(3, length(Lines)),
                     ?assert(string:find(Got, "    ... (38 more)") =/= nomatch),
                     %% The unspellable atom products need a separate cap.
                     ?assert(string:find(Got, "Classify(<= 9, a) -> ...")
                             =/= nomatch),
                     ?assert(string:find(Got, "and no pattern spells:")
                             =/= nomatch),
                     ?assert(string:find(Got, "(400, atom \\ (:x))") =/= nomatch),
                     ?assert(string:find(Got, "... (37 more)") =/= nomatch)
             end).

a_small_residual_is_not_truncated_test() ->
    Src = "module Small\n"
          "public atom Classify(int n)\n"
          "Classify(0) -> :zero\n",
    with_src("small.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(Got, "Classify(<= -1) -> ...") =/= nomatch),
                     ?assert(string:find(Got, "Classify(>= 1) -> ...") =/= nomatch),
                     ?assertEqual(nomatch, string:find(Got, "more)"))
             end).

%%% F2.5 — a guard refinement and a type refinement agree.

%% The residual retains the declared lower bound after guard subtraction.
a_guard_and_a_type_refinement_do_not_double_count_test() ->
    Src = "module Band\n" ++ octet() ++
          "public atom Big(Octet n)\n"
          "Big(n) when n > 128 -> :big\n",
    [{error, _, 'Big', {inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("(0..128)", bs_types:to_pattern(Residual)).

%%% --- Openness ------------------------------------------------------------

%% bs_types:is_open/1 uses a partial map pattern: omitting a component need
%% not fail. Probe components separately because one program can miss that.
openness_is_answered_by_every_component_test() ->
    ?assertNot(bs_types:is_open(bs_types:range(0, 255))),
    ?assert(bs_types:is_open(bs_types:int())),
    ?assert(bs_types:is_open(bs_types:range(0, pos_inf))),
    ?assertNot(bs_types:is_open(bs_types:atom_lit(ok))),
    %% The atom universe is open even when finitely many atoms are excluded.
    ?assert(bs_types:is_open(bs_types:atom_top())),
    ?assertNot(bs_types:is_open(bs_types:nil())),
    %% Non-empty lists have unbounded length even with a finite element type.
    ?assert(bs_types:is_open(bs_types:list(bs_types:range(0, 1)))),
    ?assert(bs_types:is_open(bs_types:binary_top())),
    ?assert(bs_types:is_open(bs_types:string())),
    ?assert(bs_types:is_open(bs_types:term())),
    %% A product is open if any factor is.
    ?assertNot(bs_types:is_open(
                 bs_types:tuple([bs_types:range(0, 1), bs_types:atom_lit(ok)]))),
    ?assert(bs_types:is_open(
              bs_types:tuple([bs_types:range(0, 1), bs_types:int()]))),
    ?assertNot(bs_types:is_open(
                 bs_types:map_closed(#{'Id' => bs_types:range(0, 1)}))),
    ?assert(bs_types:is_open(
              bs_types:map_closed(#{'Id' => bs_types:int()}))),
    %% An open record admits additional fields.
    ?assert(bs_types:is_open(
              bs_types:map_open(#{'Id' => bs_types:range(0, 1)}))).
