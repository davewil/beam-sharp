%%% Scenarios: compiler/features/F22-record-pattern-and-binder.md
-module(record_pattern_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1]).

%%% Record patterns and binders

prelude() ->
    "module Wire\n"
    "record Method { Channel: int }\n"
    "record Header { Channel: int }\n"
    "type Frame = Method | Header\n".

%%% Parsing, checking and execution

%% F22.1 — a type-prefixed pattern dispatches like the Kind spelling.
a_type_prefixed_pattern_dispatches_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Method { Channel: 7 }) -> :seven\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(seven,  M:'Which'(#{'Kind' => 'Wire.Method', 'Channel' => 7})),
    ?assertEqual(method, M:'Which'(#{'Kind' => 'Wire.Method', 'Channel' => 9})),
    ?assertEqual(header, M:'Which'(#{'Kind' => 'Wire.Header', 'Channel' => 1})).

%% F22.2 — the binder binds the whole record, not the projected field.
a_binder_binds_the_whole_record_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan(Method { Channel: 7 } f) -> f.Channel\n"
          "Chan(Method m) -> 0 - m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(7,   M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 7})),
    ?assertEqual(-41, M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 41})),
    ?assertEqual(3,   M:'Chan'(#{'Kind' => 'Wire.Header', 'Channel' => 3})).

%% F22.3 — a type and binder match without naming fields.
a_bare_type_and_binder_matches_any_record_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan(Method m) -> m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(12, M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 12})).

%% F22.4 — a bare property pattern accepts a binder.
a_bare_property_pattern_takes_a_binder_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan({ Channel: 7 } f) -> f.Channel\n"
          "Chan(Method m) -> 0 - m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(7,  M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 7})),
    ?assertEqual(-8, M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 8})).

%% F22.9 — a record binder works inside a tuple.
a_binder_nested_in_a_tuple_test() ->
    Src = prelude() ++
          "public int Chan((Frame, int))\n"
          "Chan((Method { Channel: 7 } f, rest)) -> f.Channel + rest\n"
          "Chan((Method m, rest)) -> m.Channel\n"
          "Chan((Header h, rest)) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(107, M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 7}, 100})),
    ?assertEqual(9,   M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 9}, 100})).

%% F22.11 — a type-prefixed binder works in a switch arm.
a_type_prefixed_binder_works_in_a_switch_arm_test() ->
    Src = prelude() ++
          "public int Chan((Frame, int))\n"
          "Chan(pair) -> pair switch {\n"
          "    (Method { Channel: 7 } f, rest) => f.Channel + rest,\n"
          "    (Method m, rest) => m.Channel,\n"
          "    (Header h, rest) => 0 - h.Channel\n"
          "}\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(107, M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 7}, 100})),
    ?assertEqual(9,   M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 9}, 100})),
    ?assertEqual(-3,  M:'Chan'({#{'Kind' => 'Wire.Header', 'Channel' => 3}, 100})).

%%% Pattern errors

%% F22.5 — an undeclared pattern type raises an error.
%% Resolution raises here; the CLI boundary converts it to a diagnostic.
an_undeclared_type_in_a_pattern_is_an_error_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Nope { Channel: 1 }) -> :no\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    ?assertError({unknown_type, 'Nope'}, check_only(Src)).

%% F22.6 — an unknown pattern field reports the record's declared fields.
%% The generated `Kind` field is not an author-writable suggestion.
a_field_the_record_lacks_is_an_error_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Method { Nope: 1 }) -> :no\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    ?assertError({pattern_field_unknown, _, 'Method', 'Nope', ['Channel']},
                 check_only(Src)).

%%% Exhaustiveness across both spellings

covering(kind) ->
    prelude() ++
    "public atom Which(Frame)\n"
    "Which({ Kind: :'Wire.Method' }) -> :method\n"
    "Which({ Kind: :'Wire.Header' }) -> :header\n";
covering(prefix) ->
    prelude() ++
    "public atom Which(Frame)\n"
    "Which(Method m) -> :method\n"
    "Which(Header h) -> :header\n".

partial(kind) ->
    prelude() ++
    "public atom Which(Frame)\n"
    "Which({ Kind: :'Wire.Method' }) -> :method\n";
partial(prefix) ->
    prelude() ++
    "public atom Which(Frame)\n"
    "Which(Method m) -> :method\n".

%% Compare verdicts independently of diagnostic wording.
verdict(Src) ->
    case check_only(Src) of
        {ok, _, _}  -> ok;
        {error, Ds} -> {error, [element(1, D) || D <- Ds, element(1, D) =:= error] =/= []}
    end.

%% F22.7 — a covering pair is exhaustive in both spellings.
%% Agreement alone would also pass if both spellings were rejected.
a_type_prefixed_cover_is_exhaustive_test() ->
    ?assertEqual(ok, verdict(covering(kind))),
    ?assertEqual(verdict(covering(kind)), verdict(covering(prefix))).

%% F22.8 — a partial cover is inexhaustive in both spellings.
a_type_prefixed_partial_cover_is_inexhaustive_test() ->
    ?assertMatch({error, true}, verdict(partial(kind))),
    ?assertEqual(verdict(partial(kind)), verdict(partial(prefix))).

%%% Emitted Erlang

%% F22.10 — unused binders lower to underscored names; used binders keep names.
%% Inspect emitted forms because compilation can succeed with unused warnings.
emitted_forms(Src) ->
    {ok, _} = bs_test_support:compile(Src),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(filename:join(bs_test_support:run_root(), "Wire.beam"),
                        [abstract_code]),
    Forms.

an_unused_binder_lowers_to_an_underscored_name_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Method { Channel: 7 } f) -> :seven\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    Forms = emitted_forms(Src),
    ?assertEqual(0, bs_test_support:count(Forms, 'F')),
    ?assert(bs_test_support:count(Forms, '_F') > 0).

a_used_binder_keeps_its_name_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan(Method { Channel: 7 } f) -> f.Channel\n"
          "Chan(Method m) -> 0 - m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    Forms = emitted_forms(Src),
    ?assert(bs_test_support:count(Forms, 'F') > 0),
    ?assertEqual(0, bs_test_support:count(Forms, '_F')).
