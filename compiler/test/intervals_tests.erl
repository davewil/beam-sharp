-module(intervals_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          run_cli/1, with_src/3]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% F2 — interval refinements, and the interval patterns that had to land with
%%% them.
%%%
%%% THE COUPLING IS THE FEATURE. Ticket 25c measured it and neither ticket
%%% recorded it: today a parameter declared `int` has an OPEN residual, so a wire
%%% dispatch gets its `_` for free. The moment `type Octet = int where value >= 0
%%% and value <= 255` exists that residual CLOSES — 252 unnamed values for an
%%% AMQP frame type — and ticket 12 §2 makes a catch-all over a closed residual an
%%% error. So a refinement shipped without a way to name a span would have turned
%%% working programs into rejected ones, which is why F2.2 and F2.3 are tested
%%% next to each other and in that order: the second is what discharges the first.
%%%
%%% Implements tickets 20 §5, 42, 43, 12 §2 and 04. Decides nothing.
%%% ---------------------------------------------------------------------------

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%%% --- F2.1 — a refinement narrows the emitted spec ---------------------------

%% THE SCENARIO THAT MAKES `bs_emit:int_part/1`'s BOUNDED BRANCHES REACHABLE.
%% They were written for the walking skeleton and could not be run: intervals
%% only ever arose from a GUARD, and a guard refines a clause rather than a
%% signature, so a parameter declared `int` was `integer()` in the spec whatever
%% its clauses tested. A teammate found them measuring emitter coverage and they
%% have been dead code ever since.
a_refined_parameter_narrows_the_spec_test() ->
    Src = "module Wire\n" ++ octet() ++
          "Octet Clamp(Octet)\n"
          "Clamp(n) -> n\n",
    {ok, _} = compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Wire.beam", [abstract_code]),
    [Spec] = [F || F = {attribute, _, spec, _} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "0..255") =/= nomatch),
    %% The control, and it is the half that would pass by accident: a spec that
    %% said `integer()` would also contain no `0..255`, so assert the widening is
    %% GONE rather than only that the range is present.
    ?assertEqual(nomatch, string:find(Printed, "integer()")).

%% A refinement is a SUBSET of its base, not a type beside it — so this needs no
%% conversion, no cast and no coercion rule. Ticket 20 §5's whole claim.
a_refinement_is_a_subtype_of_its_base_test() ->
    Src = "module Sub\n" ++ octet() ++
          "int Widen(Octet n)\n"
          "Widen(n) -> n\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% ...and the reverse does not hold, which is what makes the narrowing mean
%% anything. Site 1: the call argument.
the_base_is_not_a_subtype_of_the_refinement_test() ->
    Src = "module Narrow\n" ++ octet() ++
          "atom Take(Octet n)\n"
          "Take(n) -> :ok\n"
          "atom Give(int n)\n"
          "Give(n) -> Take(n)\n",
    ?assertMatch([{error, _, 'Give', {arg_not_accepted, 'Take', 1, _, _}}],
                 errors(Src)).

%% Ticket 20 §5's two tiers, and the cut is on what the predicate SAYS. An
%% unreadable predicate is an ERROR rather than a silent widening — the failure
%% that would otherwise ship is a `type Email = string where WellFormed(value)`
%% that means `string` and says nothing, which is the opaque tier arriving
%% through the back door with 29's placement rule unenforced.
%%
%% This asserts an error a WRONG BUILD OMITS, which is the shape F5.7, F6's hang
%% and F9's byte count all needed: crediting the base type here makes the
%% compiler quieter, not redder.
an_unreadable_refinement_predicate_is_an_error_test() ->
    Src = "module Opaque\n"
          "atom WellFormed(int n)\n"
          "WellFormed(n) -> :yes\n"
          "type Email = int where WellFormed(value)\n"
          "atom Take(Email e)\n"
          "Take(e) -> :ok\n",
    ?assertError({opaque_refinement, _}, check_only(Src)).

%% The same rule reached from the other side: a predicate the checker CAN read,
%% about something that is not the subject.
a_refinement_naming_something_other_than_value_is_an_error_test() ->
    Src = "module Elsewhere\n"
          "type Odd = int where n > 0\n"
          "atom Take(Odd o)\n"
          "Take(o) -> :ok\n",
    ?assertError({opaque_refinement, _}, check_only(Src)).

a_self_contradictory_refinement_is_an_error_test() ->
    Src = "module Empty\n"
          "type Nothing = int where value > 0 and value < 0\n"
          "atom Take(Nothing n)\n"
          "Take(n) -> :ok\n",
    ?assertError({empty_refinement, _}, check_only(Src)).

%%% --- F2.2 — a closed residual refuses a catch-all ---------------------------

%% TICKET 12 §2, AND F2 IS WHAT MAKES IT REACHABLE ON NUMBERS. Before the
%% refinement there was no closed integer domain to declare, so `_` over one was
%% always legal. This is the scenario that would silently break 25c if F2.3 did
%% not exist, and it is worth running BEFORE F2.3 to see the failure it prevents.
a_catch_all_over_a_closed_residual_is_an_error_test() ->
    Src = "module Frame\n" ++ octet() ++
          "atom Classify(Octet)\n"
          "Classify(1) -> :method\n"
          "Classify(2) -> :header\n"
          "Classify(3) -> :body\n"
          "Classify(8) -> :heartbeat\n"
          "Classify(_) -> :reserved\n",
    [{error, _, 'Classify', {catch_all_over_closed, Residual}}] = errors(Src),
    %% The residual IS the checklist — ticket 04 — so assert what it says and not
    %% merely that something was said. 25c predicted exactly this shape.
    ?assertEqual("(0 | 4..7 | 9..255)", bs_types:to_pattern(Residual)).

%% THE CONTROL, and without it the test above proves nothing: the same program
%% over a BARE `int` must still be accepted, because that residual has an
%% unbounded top and a foreign sender chooses the inhabitants. Ticket 12 §2's
%% second bullet, which is the half that keeps `handle_info` writable.
a_catch_all_over_an_open_residual_is_legal_test() ->
    Src = "module Open\n"
          "atom Classify(int n)\n"
          "Classify(1) -> :one\n"
          "Classify(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% `_` is the trigger and a bare NAME is not, which is ticket 12 §2 read
%% literally — *"`_` here is an error: name the case"*. The narrowing is
%% principled: `_` discards the value, and extending the rule to named binders
%% would make every single-clause function over a record type an error.
a_named_binder_is_not_a_catch_all_test() ->
    Src = "module Named\n" ++ octet() ++
          "atom Classify(Octet)\n"
          "Classify(1) -> :one\n"
          "Classify(n) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% A guard means the clause is saying something about the values, so it is not a
%% catch-all whatever its pattern looks like — and the two diagnostics are what
%% tells the cases apart. This guard is untranslatable, so the clause credits
%% NOTHING and the function is plainly inexhaustive; what matters is that it is
%% reported as `inexhaustive` and not as a discarded case, because the author's
%% mistake and the fix are different ones.
a_guarded_wildcard_is_not_a_catch_all_test() ->
    Src = "module Guarded\n" ++ octet() ++
          "atom Classify(Octet)\n"
          "Classify(_) when 1 > 0 -> :anything\n",
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _}}], errors(Src)).

%% Ticket 12 §2 at the switch. An arm is the clause head's own pattern grammar
%% one level down (F7), so a rule about what a head may discard is a rule about
%% what an arm may discard.
a_catch_all_arm_over_a_closed_residual_is_an_error_test() ->
    Src = "module Arms\n"
          "type Event = :placed | :shipped | :cancelled\n"
          "atom Which(Event e)\n"
          "Which(e) -> e switch {\n"
          "    :placed => :new,\n"
          "    _       => :other\n"
          "}\n",
    ?assertMatch([{error, _, 'Which', {catch_all_over_closed, _}}], errors(Src)).

%%% --- F2.3 — an interval pattern names a span --------------------------------

%% TICKET 42's OWN WORKED EXAMPLE, run. Seven clauses, 256 values, no catch-all
%% — and it is the program F2.2 above rejects, with the one construct that lets
%% it be written at all.
an_interval_pattern_discharges_a_closed_residual_test() ->
    M = build_and_load(frame_src(), 'Frame2'),
    ?assertEqual(method,    M:'Classify'(1)),
    ?assertEqual(heartbeat, M:'Classify'(8)),
    ?assertEqual(reserved,  M:'Classify'(0)),
    %% Inside the span, and at BOTH ENDS of it. The inclusivity of the bounds is
    %% the question ticket 42 was raised to answer, and `4..7` half-open would
    %% have left 7 to another clause — so 4 and 7 are the assertions that would
    %% have caught the borrow this language refused.
    ?assertEqual(reserved,  M:'Classify'(4)),
    ?assertEqual(reserved,  M:'Classify'(7)),
    ?assertEqual(reserved,  M:'Classify'(9)),
    ?assertEqual(reserved,  M:'Classify'(255)).

frame_src() ->
    "module Frame2\n" ++ octet() ++
    "type FrameType = :method | :header | :body | :heartbeat | :reserved\n"
    "FrameType Classify(Octet)\n"
    "Classify(1)             -> :method\n"
    "Classify(2)             -> :header\n"
    "Classify(3)             -> :body\n"
    "Classify(8)             -> :heartbeat\n"
    "Classify(0)             -> :reserved\n"
    "Classify(>= 4 and <= 7) -> :reserved\n"
    "Classify(>= 9)          -> :reserved\n".

%% Ticket 42: *"identical to what a guard would have produced, so nothing
%% downstream changes."* One variable per relational SUBTREE and not per test —
%% `>= 4 and <= 7` constrains a single value twice, so two variables would make
%% the head match two different things and mean neither.
an_interval_pattern_lowers_to_a_variable_and_a_guard_test() ->
    {ok, _} = compile(frame_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Frame2.beam", [abstract_code]),
    [{function, _, 'Classify', 1, Clauses}] =
        [F || F = {function, _, _, _, _} <- Forms],
    Span = lists:nth(6, Clauses),
    {clause, _, [{var, _, V}], [[Guard]], _} = Span,
    ?assertMatch({op, _, 'andalso',
                  {op, _, '>=', {var, _, V}, {integer, _, 4}},
                  {op, _, '=<', {var, _, V}, {integer, _, 7}}}, Guard).

%% A span is EXACT, unlike `== acc`, so it credits `Certain` in full — which is
%% the whole reason it can close a residual. The control that shows the credit is
%% real: drop the span and exactly its own values must come back.
dropping_the_span_leaves_exactly_the_span_test() ->
    Src = "module Gap\n" ++ octet() ++
          "atom Classify(Octet)\n"
          "Classify(>= 0 and <= 3) -> :low\n"
          "Classify(>= 8)          -> :high\n",
    [{error, _, 'Classify', {inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("(4..7)", bs_types:to_pattern(Residual)).

%% A NEGATIVE BOUND, which is the residual's own spelling for the lower half of
%% `int` — so the head ticket 23 §2 synthesises has to be one the parser accepts
%% back. `Classify(<= -1)` is that head.
a_negative_bound_parses_and_dispatches_test() ->
    Src = "module Signs\n"
          "atom Classify(int n)\n"
          "Classify(<= -1)         -> :negative\n"
          "Classify(>= 0 and <= 3) -> :low\n"
          "Classify(>= 4)          -> :high\n",
    M = build_and_load(Src, 'Signs'),
    ?assertEqual(negative, M:'Classify'(-1)),
    ?assertEqual(low,      M:'Classify'(0)),
    ?assertEqual(high,     M:'Classify'(4)).

%% `or` is union and `and` is intersection, both already in the algebra — F2's
%% claim that it adds no theory, asserted rather than repeated.
the_or_combinator_is_a_union_test() ->
    Src = "module Either\n"
          "atom Classify(int n)\n"
          "Classify(<= 0 or >= 10) -> :outer\n"
          "Classify(>= 1 and <= 9) -> :inner\n",
    M = build_and_load(Src, 'Either'),
    ?assertEqual(outer, M:'Classify'(0)),
    ?assertEqual(outer, M:'Classify'(10)),
    ?assertEqual(inner, M:'Classify'(5)).

%% An arm takes the same lowering, because F7 made a switch the clause head's
%% pattern grammar one level down rather than a copy of it.
an_interval_pattern_works_in_a_switch_arm_test() ->
    Src = "module Sizing\n"
          "atom Size(int n)\n"
          "Size(n) -> n switch {\n"
          "    >= 129           => :high,\n"
          "    >= 65 and <= 128 => :mid,\n"
          "    <= 64            => :low\n"
          "}\n",
    M = build_and_load(Src, 'Sizing'),
    ?assertEqual(high, M:'Size'(200)),
    ?assertEqual(mid,  M:'Size'(70)),
    ?assertEqual(low,  M:'Size'(1)).

%% F2 SHIPS THE CONSTRUCT IN THE PARAMETER POSITION ONLY, and the omission is
%% chosen rather than forgotten — the feature file records it and this enforces
%% the record. The grammar gives nesting away for free (`pat_field -> uident ':'
%% pattern`), and shipping a capability nothing tests because a production
%% happened to compose is how a language acquires behaviour nobody decided on.
a_relational_pattern_inside_a_record_pattern_is_refused_test() ->
    Src = "module Nested\n"
          "record Order { Total: int }\n"
          "atom Big(Order o)\n"
          "Big({ Total: >= 100 }) -> :big\n",
    ?assertError({relational_pattern_nested, _}, check_only(Src)).

a_relational_pattern_inside_a_tuple_is_refused_test() ->
    Src = "module Tup\n"
          "atom Big((int, int) p)\n"
          "Big((>= 100, x)) -> :big\n",
    ?assertError({relational_pattern_nested, _}, check_only(Src)).

%% A BIND IS NOT A HEAD. `var >= 4 = n` parses, binds nothing, and is refused
%% here rather than left to the residual check — because the degenerate case
%% where it IS irrefutable would pass that check and reach an emitter with no
%% guard to hang the test on.
a_relational_pattern_in_a_bind_is_refused_test() ->
    Src = "module Bound\n" ++ octet() ++
          "atom Take(Octet n)\n"
          "Take(n) ->\n"
          "    var >= 0 = n\n"
          "    :ok\n",
    ?assertMatch([{error, _, 'Take', relational_in_bind} | _], errors(Src)).

%%% --- F2.4 — the residual stays legible at width -----------------------------

%% TICKET 43, AND ITS OWN MEASURED INPUT. Forty scattered singletons leave 41
%% disjoint intervals — scattered on purpose, because `i_norm/1` merges ADJACENT
%% ranges, so a stride of 1 would coalesce to one interval and truncate nothing.
%%
%% The expected string is exact. 43 measured the untruncated line at 453
%% characters and one head rather than 41 — `heads/2` splits on the tuple part,
%% so a union of intervals stays inside a single argument. That correction is
%% what made the rule "three CASES" rather than "three heads", which would have
%% truncated nothing at all today.
the_residual_truncates_at_three_cases_test() ->
    Src = ["module Scattered\natom Classify(int n)\n"
           | [io_lib:format("Classify(~p) -> :known\n", [N * 10])
              || N <- lists:seq(1, 40)]],
    with_src("scattered.bs", lists:flatten(Src),
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(
                               Got,
                               "Classify(int <= 9 | 11..19 | 21..29 | "
                               "... (38 more)) -> ...") =/= nomatch)
             end).

%% THE HEAD-LINE HALF OF 43's RULE, AND IT IS NEEDED TODAY RATHER THAN AFTER
%% TICKET 23 §2. 43 §3 puts head-counting in the future tense, and its own reason
%% for having that half is what makes it reachable now: a residual over a
%% two-argument function is a PRODUCT, and `heads/2` has always printed one line
%% per product. So a second argument is all it takes — no §2 involved.
%%
%% Measured before the cap was added: this program printed **41 head lines**, one
%% of them itself truncated. Both units are live at once, which is what *"at most
%% three of whatever it is enumerating"* means when the printer enumerates two
%% things at two depths.
the_head_lines_truncate_at_three_too_test() ->
    Src = ["module Two\natom Classify(int n, atom a)\n"
           | [io_lib:format("Classify(~p, :x) -> :known\n", [N * 10])
              || N <- lists:seq(1, 40)]],
    with_src("two.bs", lists:flatten(Src),
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     Lines = [L || L <- string:split(Got, "\n", all),
                                   string:find(L, "Classify(") =/= nomatch],
                     ?assertEqual(3, length(Lines)),
                     ?assert(string:find(Got, "    ... (38 more)") =/= nomatch),
                     %% The inner truncation still runs inside the first line, so
                     %% the two depths compose rather than one shadowing the other.
                     ?assert(string:find(
                               Got,
                               "Classify(int <= 9 | 11..19 | 21..29 | "
                               "... (38 more), atom) -> ...") =/= nomatch)
             end).

%% AND THE HALF THAT MAKES IT ONE FORMAT RATHER THAN TWO. At three cases or fewer
%% it prints byte-identically to what the compiler printed before any of this
%% existed, so there is no threshold to tune and no *"why did the format change"*
%% to explain. Every other shape ticket 43 priced has to switch.
a_small_residual_is_not_truncated_test() ->
    Src = "module Small\n"
          "atom Classify(int n)\n"
          "Classify(0) -> :zero\n",
    with_src("small.bs", Src,
             fun(Path, Out) ->
                     Got = run_cli("-o " ++ Out ++ " " ++ Path),
                     ?assert(string:find(
                               Got, "Classify(int <= -1 | int >= 1) -> ...")
                             =/= nomatch),
                     ?assertEqual(nomatch, string:find(Got, "more)"))
             end).

%%% --- F2.5 — a guard refinement and a type refinement agree ------------------

%% They go through ONE translator — `alternatives/1` reads a refinement predicate
%% and a guard alike — so this is true by construction rather than by luck. The
%% failure it rules out is double-counting: the residual after the clause is
%% `0..128` and not `int <= 128`, which is what a build that forgot the declared
%% bound would say.
a_guard_and_a_type_refinement_do_not_double_count_test() ->
    Src = "module Band\n" ++ octet() ++
          "atom Big(Octet n)\n"
          "Big(n) when n > 128 -> :big\n",
    [{error, _, 'Big', {inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("(0..128)", bs_types:to_pattern(Residual)).

%%% --- openness, which is the discriminator all of F2.2 rests on --------------

%% `is_open/1` decides whether a residual can be enumerated, and every component
%% of the algebra has to answer. The map pattern in it is partial, so a component
%% forgotten there does not fail — which is the trap `is_none/1` documents and
%% the reason these are asserted one by one rather than through one program.
openness_is_answered_by_every_component_test() ->
    ?assertNot(bs_types:is_open(bs_types:range(0, 255))),
    ?assert(bs_types:is_open(bs_types:int())),
    ?assert(bs_types:is_open(bs_types:range(0, pos_inf))),
    ?assertNot(bs_types:is_open(bs_types:atom_lit(ok))),
    %% Ticket 10 made the atom universe open, so the cofinite top cannot be
    %% enumerated however few atoms have been excluded from it.
    ?assert(bs_types:is_open(bs_types:atom_top())),
    ?assertNot(bs_types:is_open(bs_types:nil())),
    %% A list part admitting a non-empty list is unbounded in LENGTH, whatever
    %% its element type — so a closed element type does not close the list.
    ?assert(bs_types:is_open(bs_types:list(bs_types:range(0, 1)))),
    ?assert(bs_types:is_open(bs_types:binary_top())),
    ?assert(bs_types:is_open(bs_types:string())),
    ?assert(bs_types:is_open(bs_types:term())),
    %% Componentwise: a product is open if any factor is.
    ?assertNot(bs_types:is_open(
                 bs_types:tuple([bs_types:range(0, 1), bs_types:atom_lit(ok)]))),
    ?assert(bs_types:is_open(
              bs_types:tuple([bs_types:range(0, 1), bs_types:int()]))),
    ?assertNot(bs_types:is_open(
                 bs_types:map_closed(#{'Id' => bs_types:range(0, 1)}))),
    ?assert(bs_types:is_open(
              bs_types:map_closed(#{'Id' => bs_types:int()}))),
    %% An `open` member is *at least* these fields, so it admits maps carrying
    %% arbitrary others — the same unbounded top the name already says.
    ?assert(bs_types:is_open(
              bs_types:map_open(#{'Id' => bs_types:range(0, 1)}))).
