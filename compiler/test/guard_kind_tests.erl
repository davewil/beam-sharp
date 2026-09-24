%%% Scenarios: compiler/features/F24-boundary-kind.md
-module(guard_kind_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% Ordering guards establish integer kind when narrowing a union.

union() -> "type T = int | atom\n".

%% The private helper has no boundary guard to reject a wrong-kind value.
tag() -> "int Tag(int x)\n"
         "Tag(x) -> x\n".

%% A runtime rejection alone cannot identify which guard rejects the value.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

count_substr(S, Sub) -> length(string:split(S, Sub, all)) - 1.

%%% F24.8–F24.9 — ordering guards reject atoms and floats.

an_atom_does_not_enter_a_clause_narrowed_by_an_ordering_guard_test() ->
    Src = "module Nar2\n" ++ union() ++ tag() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> Tag(n)\n"
          "Bump(n)             -> 0\n",
    M = build_and_load(Src, 'Nar2'),
    %% Valid integers still enter the guarded clause.
    ?assertEqual(7, M:'Bump'(7)),
    ?assertEqual(0, M:'Bump'(-1)),
    %% BEAM term ordering makes foo >= 0 true.
    ?assertEqual(0, M:'Bump'(foo)).

%% A float passes the comparison too; excluding atoms alone is insufficient.
a_float_does_not_enter_a_clause_narrowed_by_an_ordering_guard_test() ->
    Src = "module Nar3\n" ++ union() ++ tag() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> Tag(n)\n"
          "Bump(n)             -> 0\n",
    M = build_and_load(Src, 'Nar3'),
    ?assertEqual(7, M:'Bump'(7)),
    ?assertEqual(0, M:'Bump'(1.5)).

%%% F24.10 — relational patterns reject atoms and floats.

an_atom_does_not_match_a_relational_pattern_test() ->
    Src = "module Rel1\n" ++ union() ++
          "public int Bump(T n)\n"
          "Bump(>= 0) -> 1\n"
          "Bump(n)    -> 0\n",
    M = build_and_load(Src, 'Rel1'),
    ?assertEqual(1, M:'Bump'(7)),
    ?assertEqual(0, M:'Bump'(-1)),
    ?assertEqual(0, M:'Bump'(foo)),
    ?assertEqual(0, M:'Bump'(1.5)).

%%% F24.10 — a relational switch arm rejects atoms.

%% Switch arms lower through arm/2, separately from clause/4.
%% A clause-only kind check leaves the arm accepting atoms; a vacuous
%% arm is only a warning, so compilation alone cannot catch that error.
an_atom_does_not_match_a_relational_switch_arm_test() ->
    Src = "module Sw1\n" ++ union() ++
          "public int Pick(T n)\n"
          "Pick(n) -> n switch {\n"
          "    >= 0 => 1,\n"
          "    _    => 0\n"
          "}\n",
    M = build_and_load(Src, 'Sw1'),
    ?assertEqual(1, M:'Pick'(7)),
    ?assertEqual(0, M:'Pick'(-1)),
    ?assertEqual(0, M:'Pick'(foo)).

%%% F24.11 — the atom alternative beside an ordering survives.

%% The integer test belongs on the comparison; guarding the whole disjunction
%% would reject the valid atom alternative.
an_atom_alternative_beside_an_ordering_survives_test() ->
    Src = "module Alt1\n" ++ union() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 or n == :ok -> 1\n"
          "Bump(n)                         -> 0\n",
    M = build_and_load(Src, 'Alt1'),
    ?assertEqual(1, M:'Bump'(7)),
    %% A whole-guard integer test would reject this valid alternative.
    ?assertEqual(1, M:'Bump'(ok)),
    %% Other atoms still fall through despite BEAM term ordering.
    ?assertEqual(0, M:'Bump'(foo)),
    ?assertEqual(0, M:'Bump'(-1)).

%%% F24.8–F24.9 — the emitted narrowing guard carries the integer test.

the_narrowing_guard_carries_the_type_test_test() ->
    Src = "module Emt1\n" ++ union() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> 1\n"
          "Bump(n)             -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Emt1', 'Bump'),
    %% The union has no boundary kind test; only the comparison adds one.
    ?assertEqual(1, count_substr(Printed, "is_integer")).

%%% F24.12 — an integer-only parameter gains no redundant test.

an_int_only_parameter_gains_no_second_test_test() ->
    Src = "module Ctl1\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "public int Classify(Octet n)\n"
          "Classify(n) when n >= 9 -> 1\n"
          "Classify(n)             -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Ctl1', 'Classify'),
    %% One boundary test per clause; narrowing adds none.
    ?assertEqual(2, count_substr(Printed, "is_integer")),
    M = build_and_load(Src, 'Ctl1'),
    ?assertEqual(1, M:'Classify'(10)),
    ?assertEqual(0, M:'Classify'(3)).
