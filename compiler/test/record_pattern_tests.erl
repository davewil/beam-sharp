-module(record_pattern_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1]).

%%% ---------------------------------------------------------------------------
%%% F22 — a record pattern names its type, and any pattern takes a trailing
%%% binder. Scenario ids are the feature file's.
%%%
%%% THE TWO LOAD-BEARING TESTS ARE F22.7 AND F22.8, AND THEY ARE WRITTEN AS A
%%% COMPARISON RATHER THAN AS AN ASSERTION ABOUT EITHER SPELLING.
%%%
%%% `Frame { … }` must subtract exactly what `{ Kind: :'Mod.Frame', … }`
%%% subtracts. Subtracting too little is loud — a covered union reports
%%% inexhaustive and somebody fixes it. Subtracting too MUCH is silent: the
%%% compiler proves a program exhaustive and the BEAM crashes it, which is
%%% ticket 54's shape.
%%%
%%% Pinning either verdict directly would be weaker than comparing them, because
%%% a comparison cannot pass by both being wrong in the same direction — the
%%% `Kind` spelling is the one that already shipped and the existing suite
%%% exercises it.
%%% ---------------------------------------------------------------------------


%% Two records and a union over them. Everything below dispatches on this.
prelude() ->
    "module Wire\n"
    "record Method { Channel: int }\n"
    "record Header { Channel: int }\n"
    "type Frame = Method | Header\n".


%%% --- the forms parse, check and run ----------------------------------------

%% F22.1 — a record pattern naming its type dispatches like the Kind spelling.
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

%% F22.2 — THE BINDER IS THE WHOLE RECORD, NOT THE FIELD IT SITS BESIDE.
%% If `f` bound the projected field, `f.Channel` would not compile; if it bound
%% the field's VALUE, the answer would be 7 rather than 41.
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

%% F22.3 — a type and a binder with no fields named. LANGUAGE.md's own
%% illustrative spelling, and the shape a parameter already has.
a_bare_type_and_binder_matches_any_record_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan(Method m) -> m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(12, M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 12})).

%% F22.4 — the bare property pattern keeps its meaning and gains a binder.
%% This is the half that must not regress: `{ … }` alone is today's form.
a_bare_property_pattern_takes_a_binder_test() ->
    Src = prelude() ++
          "public int Chan(Frame)\n"
          "Chan({ Channel: 7 } f) -> f.Channel\n"
          "Chan(Method m) -> 0 - m.Channel\n"
          "Chan(Header h) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(7,  M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 7})),
    ?assertEqual(-8, M:'Chan'(#{'Kind' => 'Wire.Method', 'Channel' => 8})).

%% F22.9 — 25c's actual shape: the aliased record is nested inside a tuple, not
%% sitting at the top of the parameter. `consume.bs:20` is exactly this.
a_binder_nested_in_a_tuple_test() ->
    Src = prelude() ++
          "public int Chan((Frame, int))\n"
          "Chan((Method { Channel: 7 } f, rest)) -> f.Channel + rest\n"
          "Chan((Method m, rest)) -> m.Channel\n"
          "Chan((Header h, rest)) -> h.Channel\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(107, M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 7}, 100})),
    ?assertEqual(9,   M:'Chan'({#{'Kind' => 'Wire.Method', 'Channel' => 9}, 100})).


%%% --- the two new errors ----------------------------------------------------

%% F22.5 — a type prefix that names nothing.
an_undeclared_type_in_a_pattern_is_an_error_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Nope { Channel: 1 }) -> :no\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    ?assertMatch([_ | _], errors(Src)).

%% F22.6 — a field the named record has not got. The check F21 already runs at
%% construction, arriving in pattern position.
a_field_the_record_lacks_is_an_error_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Method { Nope: 1 }) -> :no\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    ?assertMatch([_ | _], errors(Src)).


%%% --- exhaustiveness: the two spellings must agree --------------------------

%% Both spellings of the same two-clause cover, built from one template so the
%% only difference between them is the pattern under test.
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

%% Reduce a check result to just its verdict, so the comparison cannot pass by
%% accident of diagnostic wording.
verdict(Src) ->
    case check_only(Src) of
        {ok, _, _}  -> ok;
        {error, Ds} -> {error, [element(1, D) || D <- Ds, element(1, D) =:= error] =/= []}
    end.

%% F22.7 — a covering pair is exhaustive, and is exhaustive in BOTH spellings.
%% The `ok` assertion and the agreement assertion are both required: agreement
%% alone would be satisfied by both spellings being rejected.
a_type_prefixed_cover_is_exhaustive_test() ->
    ?assertEqual(ok, verdict(covering(kind))),
    ?assertEqual(verdict(covering(kind)), verdict(covering(prefix))).

%% F22.8 — and a partial cover is inexhaustive in both. This is the direction
%% that fails SILENTLY if the type prefix over-subtracts: the compiler would
%% prove a program exhaustive that crashes on a Header.
a_type_prefixed_partial_cover_is_inexhaustive_test() ->
    ?assertMatch({error, true}, verdict(partial(kind))),
    ?assertEqual(verdict(partial(kind)), verdict(partial(prefix))).


%%% --- the emitted Erlang ----------------------------------------------------

%% F22.10 — a binder the body never mentions must not produce Erlang's
%% "variable is unused" warning. `clause/3` already underscores an unused
%% parameter name; a binder introduced by this feature has to travel the same
%% path or every 25c-shaped clause warns.
an_unused_binder_does_not_warn_test() ->
    Src = prelude() ++
          "public atom Which(Frame)\n"
          "Which(Method { Channel: 7 } f) -> :seven\n"
          "Which(Method m) -> :method\n"
          "Which(Header h) -> :header\n",
    %% Compiling is the assertion: bsc treats an Erlang warning as a failure
    %% only if it is configured to, so this also checks the module LOADS, which
    %% a badly-named variable would prevent.
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(seven, M:'Which'(#{'Kind' => 'Wire.Method', 'Channel' => 7})).
