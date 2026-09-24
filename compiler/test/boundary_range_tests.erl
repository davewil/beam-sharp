%%% Scenarios: compiler/features/F37-boundary-range.md
-module(boundary_range_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% F37 — exported parameters enforce their declared ranges.

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%% Emitted guards distinguish range enforcement from other clause failures.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

count_substr(Hay, Needle) ->
    length(string:split(Hay, Needle, all)) - 1.

%% The closed Octet domain requires full coverage and rejects a catch-all.
classify() ->
    "type FrameType = :method | :header | :body | :heartbeat | :reserved\n"
    "public FrameType Classify(Octet)\n"
    "Classify(1)             -> :method\n"
    "Classify(2)             -> :header\n"
    "Classify(3)             -> :body\n"
    "Classify(8)             -> :heartbeat\n"
    "Classify(0)             -> :reserved\n"
    "Classify(>= 4 and <= 7) -> :reserved\n"
    "Classify(>= 9)          -> :reserved\n".

%%% F37.1 — a refined parameter rejects integers above its domain.

an_integer_above_the_domain_does_not_reach_a_refined_parameter_test() ->
    Src = "module Wire\n" ++ octet() ++ classify(),
    M = build_and_load(Src, 'Wire'),
    %% Both inclusive edges catch off-by-one bounds that 100 cannot expose.
    ?assertEqual(method, M:'Classify'(1)),
    ?assertEqual(reserved, M:'Classify'(0)),
    ?assertEqual(reserved, M:'Classify'(255)),
    ?assertEqual(reserved, M:'Classify'(100)),
    ?assertError(function_clause, M:'Classify'(300)),
    ?assertError(function_clause, M:'Classify'(256)),
    %% 100.5 passes the range comparisons, so the kind guard must reject it.
    ?assertError(function_clause, M:'Classify'(100.5)).

%%% F37.2 — a refined parameter rejects integers below its domain.

an_integer_below_the_domain_does_not_reach_a_refined_parameter_test() ->
    Src = "module Wire\n" ++ octet() ++
          "type Size = :low | :mid | :high\n"
          "public Size Band(Octet n)\n"
          "Band(n) when n > 128 -> :high\n"
          "Band(n) when n > 64  -> :mid\n"
          "Band(n) when n <= 64 -> :low\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(low, M:'Band'(0)),
    ?assertEqual(low, M:'Band'(64)),
    ?assertEqual(mid, M:'Band'(65)),
    ?assertEqual(high, M:'Band'(255)),
    %% These inputs reach the clause that proves only the upper bound.
    ?assertError(function_clause, M:'Band'(-5)),
    ?assertError(function_clause, M:'Band'(-1)),
    %% Above-domain inputs reach clauses that prove only the lower bound.
    ?assertError(function_clause, M:'Band'(256)).

%%% F37.3 — each clause emits only the bounds it does not prove.

%% Redundant comparisons behave identically; emitted counts distinguish them.
a_clause_carries_only_what_it_has_not_proved_test() ->
    Src = "module Wire\n" ++ octet() ++ classify(),
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Classify'),
    %% Relational patterns also emit comparisons; only this upper bound
    %% uniquely identifies the boundary guard.
    ?assertEqual(1, count_substr(Printed, "=< 255")),
    %% Every clause proves the lower bound; no boundary comparison is owed.
    ?assertEqual(0, count_substr(Printed, ">= 0")).

the_bound_emitted_is_the_one_the_clause_owes_test() ->
    Src = "module Wire\n" ++ octet() ++
          "type Size = :low | :mid | :high\n"
          "public Size Band(Octet n)\n"
          "Band(n) when n > 128 -> :high\n"
          "Band(n) when n > 64  -> :mid\n"
          "Band(n) when n <= 64 -> :low\n",
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Band'),
    ?assertEqual(2, count_substr(Printed, "=< 255")),
    ?assertEqual(1, count_substr(Printed, ">= 0")).

%%% F37.4 — an unreadable guard receives both boundary bounds.

%% The checker cannot read comparisons between two variables. Its empty
%% credit falls back to term at the boundary, so both bounds remain required.
an_unreadable_guard_is_credited_with_nothing_test() ->
    Src = "module Wire\n" ++ octet() ++
          "public int Foo(Octet n, Octet m)\n"
          "Foo(n, m) when n > m -> 1\n"
          "Foo(n, m)            -> 0\n",
    M = build_and_load(Src, 'Wire'),
    %% Valid inputs exercise both clauses before out-of-domain rejection.
    ?assertEqual(1, M:'Foo'(200, 1)),
    ?assertEqual(0, M:'Foo'(1, 200)),
    %% Both pairs satisfy n > m, so only the boundary guards reject them.
    ?assertError(function_clause, M:'Foo'(300, 1)),
    ?assertError(function_clause, M:'Foo'(-5, -9)),
    %% Counts identify the guards responsible for rejection: two bounds per
    %% parameter in each clause.
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Foo'),
    ?assertEqual(4, count_substr(Printed, ">= 0")),
    ?assertEqual(4, count_substr(Printed, "=< 255")).

%%% F37.5 — private functions carry no range guard.

a_private_function_carries_no_range_guard_test() ->
    Src = "module Priv\n" ++ octet() ++
          "int Inner(Octet n)\n"
          "Inner(n) -> n\n"
          "public int Outer(Octet n)\n"
          "Outer(n) -> Inner(n)\n",
    {ok, _} = compile(Src),
    ?assertEqual(0, count_substr(emitted('Priv', 'Inner'), "=< 255")),
    ?assertEqual(0, count_substr(emitted('Priv', 'Inner'), ">= 0")),
    ?assertEqual(1, count_substr(emitted('Priv', 'Outer'), "=< 255")),
    ?assertEqual(1, count_substr(emitted('Priv', 'Outer'), ">= 0")).

%%% F37.6 — an unrefined int carries no range comparisons.

an_unrefined_int_carries_no_comparison_test() ->
    Src = "module Plain\n"
          "public int Twice(int n)\n"
          "Twice(n) -> n + n\n",
    M = build_and_load(Src, 'Plain'),
    ?assertEqual(600, M:'Twice'(300)),
    ?assertEqual(-10, M:'Twice'(-5)),
    Printed = emitted('Plain', 'Twice'),
    ?assertEqual(0, count_substr(Printed, "=<")),
    ?assertEqual(0, count_substr(Printed, ">=")),
    %% The kind test makes the zero counts non-vacuous: compiled boundary
    %% code is present, and only the range comparisons are absent.
    ?assertEqual(1, count_substr(Printed, "is_integer")).

%%% F37.7 — a union parameter carries no range comparisons.

%% Erlang orders atoms above numbers: an upper bound would reject valid none.
a_union_parameter_carries_no_comparison_test() ->
    Src = "module Un\n" ++ octet() ++
          "public int Maybe(Octet | :none)\n"
          "Maybe(:none) -> 0\n"
          "Maybe(n)     -> n\n",
    M = build_and_load(Src, 'Un'),
    ?assertEqual(0, M:'Maybe'(none)),
    ?assertEqual(7, M:'Maybe'(7)),
    Printed = emitted('Un', 'Maybe'),
    ?assertEqual(0, count_substr(Printed, "=< 255")),
    ?assertEqual(0, count_substr(Printed, ">= 0")).

%%% F37.8 — a refinement enforces both ranges.

a_two_range_refinement_is_guarded_on_both_ranges_test() ->
    Src = "module Multi\n"
          "type Split = int where value < 0 or value > 10\n"
          "public int Grab(Split n)\n"
          "Grab(n) -> n\n",
    M = build_and_load(Src, 'Multi'),
    ?assertEqual(-1, M:'Grab'(-1)),
    ?assertEqual(-500, M:'Grab'(-500)),
    ?assertEqual(11, M:'Grab'(11)),
    ?assertEqual(500, M:'Grab'(500)),
    %% These values expose a guard that replaces the ranges with their hull.
    ?assertError(function_clause, M:'Grab'(0)),
    ?assertError(function_clause, M:'Grab'(5)),
    ?assertError(function_clause, M:'Grab'(10)).

%%% F37.9 — the clause head guards a switch subject.

a_switch_subject_is_guarded_at_the_head_test() ->
    Src = "module Wire\n" ++ octet() ++
          "type Size = :low | :mid | :high\n"
          "public Size Sizing(Octet n)\n"
          "Sizing(n) -> n switch {\n"
          "    >= 129           => :high,\n"
          "    >= 65 and <= 128 => :mid,\n"
          "    <= 64            => :low\n"
          "}\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(low, M:'Sizing'(0)),
    ?assertEqual(high, M:'Sizing'(255)),
    ?assertError(function_clause, M:'Sizing'(300)),
    ?assertError(function_clause, M:'Sizing'(-5)),
    %% Both comparisons belong to the head; the switch needs no range guard.
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Sizing'),
    ?assertEqual(1, count_substr(Printed, ">= 0")),
    ?assertEqual(1, count_substr(Printed, "=< 255")).
