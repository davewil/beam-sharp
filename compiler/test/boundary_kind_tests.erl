%%% Scenarios: compiler/features/F24-boundary-kind.md
-module(boundary_kind_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% F24 — integer parameters reject floats at the boundary.

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%% `function_clause` alone cannot identify why a head rejects the value.
%% Inspecting the emitted guard distinguishes a type check from other causes.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

%%% F24.1 — a refined integer parameter rejects a float.
%%% F24.2 — a valid integer still reaches its clause.

a_float_does_not_reach_a_refined_int_parameter_test() ->
    %% Cover the closed domain explicitly; a catch-all is refused.
    Src = "module Wire\n" ++ octet() ++
          "type FrameType = :method | :header | :body | :heartbeat | :reserved\n"
          "public FrameType Classify(Octet)\n"
          "Classify(1)             -> :method\n"
          "Classify(2)             -> :header\n"
          "Classify(3)             -> :body\n"
          "Classify(8)             -> :heartbeat\n"
          "Classify(0)             -> :reserved\n"
          "Classify(>= 4 and <= 7) -> :reserved\n"
          "Classify(>= 9)          -> :reserved\n",
    M = build_and_load(Src, 'Wire'),
    ?assertEqual(method, M:'Classify'(1)),
    ?assertEqual(heartbeat, M:'Classify'(8)),
    ?assertEqual(reserved, M:'Classify'(100)),
    %% 100.5 passes the range comparisons, so rejection needs a kind check.
    ?assertError(function_clause, M:'Classify'(100.5)),
    ?assertError(function_clause, M:'Classify'(300.5)).

%%% F24.3 — relational and bare-variable heads both carry the kind test.

the_head_carries_the_type_test_where_the_pattern_does_not_pin_it_test() ->
    Src = "module Wire\n" ++ octet() ++
          "public int Classify(Octet)\n"
          "Classify(>= 9) -> 1\n"
          "Classify(n)    -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Classify'),
    %% Neither a relational pattern nor a bare variable establishes kind.
    ?assertEqual(2, count_substr(Printed, "is_integer")).

%%% F24.4 — literal patterns need no additional kind guard.

a_literal_pattern_gets_no_test_test() ->
    %% This domain is small enough for literals to cover it exhaustively.
    Src = "module Lit\n"
          "type Bit = int where value >= 0 and value <= 1\n"
          "public int Only(Bit)\n"
          "Only(0) -> 10\n"
          "Only(1) -> 11\n",
    {ok, _} = compile(Src),
    Printed = emitted('Lit', 'Only'),
    ?assertEqual(0, count_substr(Printed, "is_integer")),
    M = build_and_load(Src, 'Lit'),
    ?assertError(function_clause, M:'Only'(1.0)).

%%% F24.5 — plain integer parameters receive kind guards.

a_plain_int_parameter_is_guarded_too_test() ->
    Src = "module Math\n"
          "public int Add(int a, int b)\n"
          "Add(a, b) -> a + b\n",
    M = build_and_load(Src, 'Math'),
    ?assertEqual(4, M:'Add'(1, 3)),
    ?assertError(function_clause, M:'Add'(1.5, 2.5)),
    %% Each integer parameter needs its own guard.
    ?assertEqual(2, count_substr(emitted('Math', 'Add'), "is_integer")).

%%% F24.6 — only exported functions receive kind guards.

%% Private calls are checked at their call sites.
a_private_function_is_not_guarded_test() ->
    Src = "module Priv\n"
          "int Inner(int n)\n"
          "Inner(n) -> n\n"
          "public int Outer(int n)\n"
          "Outer(n) -> Inner(n)\n",
    {ok, _} = compile(Src),
    ?assertEqual(0, count_substr(emitted('Priv', 'Inner'), "is_integer")),
    %% The exported control rules out a compiler that emits no guards.
    ?assertEqual(1, count_substr(emitted('Priv', 'Outer'), "is_integer")).

%%% F24.7 — an atom parameter is untouched: only the integer kind is built,
%%% and the kind test for `atom` is owed.

a_non_int_parameter_is_untouched_test() ->
    Src = "module Atomic\n"
          "public atom Echo(atom a)\n"
          "Echo(a) -> a\n",
    {ok, _} = compile(Src),
    Printed = emitted('Atomic', 'Echo'),
    ?assertEqual(0, count_substr(Printed, "is_atom")),
    ?assertEqual(0, count_substr(Printed, "is_integer")).

%%% --- helpers ----------------------------------------------------------------

count_substr(Haystack, Needle) ->
    length(string:split(Haystack, Needle, all)) - 1.
