-module(boundary_kind_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F24 — the kind half of the boundary guard: an `int` parameter is an integer
%%%
%%% TICKET 58, which is a DEFECT rather than a question. Ticket 18 §1 rule C case
%%% (b) decided this on 2026-08-13 and §5 refused an opt-out; the rule was never
%%% in the emitter. Measured on the corpus before the fix:
%%%
%%%     $ bsc examples/Wire Classify 100.5
%%%     :reserved
%%%
%%% `Classify` publishes `-spec 'Classify'(0..255)`, so a float came back with an
%%% answer from a parameter whose declared type is a range of integers — ticket
%%% 18's outcome 3, *"the only outcome that makes the type system a lie"*.
%%%
%%% THE CASE THAT DECIDES WHETHER THE FIX WORKS IS `100.5`, NOT `300.5`, and the
%%% difference is the whole reason this file leads with it. `100.5` reaches the
%%% `Classify(>= 9)` clause, because `100.5 >= 9` is true. A fix derived from
%%% ticket 46's range subtraction emits `=< 255` on that clause and nothing else,
%%% and `100.5 =< 255` is true as well — so `300.5` would start crashing while
%%% `100.5` kept returning `:reserved`, and a gate written around `300.5` would go
%%% green over a defect that had not moved. A comparison proves ORDERING, not
%%% kind; only a type test closes the tower.
%%%
%%% Implements ticket 18 §1(b) and §4. Decides nothing.
%%% ---------------------------------------------------------------------------

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%% The printed source of one emitted function, so a test can assert on the head
%% the compiler actually wrote rather than on the outcome alone. Both halves are
%% needed: `function_clause` on its own does not say the guard fired — the BEAM
%% raises it for a head that never matched for some other reason.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

%%% --- F24.1 — the reported defect --------------------------------------------

%% The run from ticket 58's own measurement, as an assertion.
a_float_does_not_reach_a_refined_int_parameter_test() ->
    %% Every clause of `wire.bs`, because `Octet` is a CLOSED domain and ticket
    %% 12 §2 makes a catch-all over one an error — so this fixture cannot be
    %% trimmed to the clauses the assertion is about. 0, 1, 2, 3, 4..7, 8 and
    %% >= 9 is the whole of 0..255 and nothing less compiles.
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
    %% The integers still answer — the guard must not have closed the door on
    %% the domain it was written to protect.
    ?assertEqual(method, M:'Classify'(1)),
    ?assertEqual(heartbeat, M:'Classify'(8)),
    ?assertEqual(reserved, M:'Classify'(100)),
    %% THE DEFECT. `100.5` reached `>= 9` and answered `:reserved`.
    ?assertError(function_clause, M:'Classify'(100.5)),
    %% The easy case, kept beside the hard one so a partial fix is visible as a
    %% partial fix rather than as a pass.
    ?assertError(function_clause, M:'Classify'(300.5)).

%% The emitted half of the same claim. Without this a `function_clause` from any
%% cause would certify the fix.
the_head_carries_the_type_test_where_the_pattern_does_not_pin_it_test() ->
    Src = "module Wire\n" ++ octet() ++
          "public int Classify(Octet)\n"
          "Classify(>= 9) -> 1\n"
          "Classify(n)    -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Classify'),
    %% Two clauses, neither of which pins the kind: a relational pattern is a
    %% comparison and a bare variable tests nothing.
    ?assertEqual(2, count_substr(Printed, "is_integer")).

%%% --- F24.2 — a clause that already pins the kind gets nothing ---------------

%% Ticket 18 §1(a): the body already objects, so nothing is emitted. An integer
%% literal in the head IS the objection, and a second test beside it is dead
%% weight. This is `constrains_kind/1`'s rule, read onto a different type.
a_literal_pattern_gets_no_test_test() ->
    %% A domain small enough that literals close it, for the same ticket 12 §2
    %% reason the fixture above carries all seven of `wire.bs`'s clauses.
    Src = "module Lit\n"
          "type Bit = int where value >= 0 and value <= 1\n"
          "public int Only(Bit)\n"
          "Only(0) -> 10\n"
          "Only(1) -> 11\n",
    {ok, _} = compile(Src),
    Printed = emitted('Lit', 'Only'),
    ?assertEqual(0, count_substr(Printed, "is_integer")),
    %% And the literals still keep a float out, which is why nothing is owed.
    M = build_and_load(Src, 'Lit'),
    ?assertError(function_clause, M:'Only'(1.0)).

%%% --- F24.3 — a plain `int` is 18 §1(b)'s own worked example -----------------

%% 18 §1(b) is `add(1.5, 2.5)` returning `4.0`, with no refinement anywhere in
%% it. A refined `int` is an `int`, so the rule cannot be scoped to refinements
%% without inventing a restriction 18 does not state.
a_plain_int_parameter_is_guarded_too_test() ->
    Src = "module Math\n"
          "public int Add(int a, int b)\n"
          "Add(a, b) -> a + b\n",
    M = build_and_load(Src, 'Math'),
    ?assertEqual(4, M:'Add'(1, 3)),
    ?assertError(function_clause, M:'Add'(1.5, 2.5)),
    %% One test per int parameter, not one per clause.
    ?assertEqual(2, count_substr(emitted('Math', 'Add'), "is_integer")).

%%% --- F24.4 — exported only, which is 18 §4 ----------------------------------

%% 18 §4: the analysis is function-local and looks at the exported function. A
%% private function's every call site is a checked beam-sharp call site, so site
%% 1 has already rejected the out-of-domain argument and the guard is dead
%% weight. Measured as an absence, so it is asserted against a module that
%% COMPILED — an absence found in a failed build is not an absence.
a_private_function_is_not_guarded_test() ->
    Src = "module Priv\n"
          "int Inner(int n)\n"
          "Inner(n) -> n\n"
          "public int Outer(int n)\n"
          "Outer(n) -> Inner(n)\n",
    {ok, _} = compile(Src),
    ?assertEqual(0, count_substr(emitted('Priv', 'Inner'), "is_integer")),
    %% The control for the control: the exported one beside it IS guarded, so a
    %% run in which nothing was emitted anywhere cannot pass this test.
    ?assertEqual(1, count_substr(emitted('Priv', 'Outer'), "is_integer")).

%%% --- F24.5 — the types this does not reach yet ------------------------------

%% F24 builds the numeric kind channel and no other. An `atom` or a `binary`
%% parameter is the same rule with a different test and is OWED rather than
%% decided differently — asserted here so the boundary is a measurement in the
%% suite rather than a sentence in a feature file that could drift from it.
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
