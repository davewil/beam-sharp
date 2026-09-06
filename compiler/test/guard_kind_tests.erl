-module(guard_kind_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% An ordering comparison the checker READ AS A TYPE must be one in the code
%%%
%%% ENG-330, a defect. Ticket 58 settled the sentence this file enforces — *"a
%%% comparison proves ORDERING, not kind"* — for a refined `int` parameter at the
%%% exported boundary (F24). The same sentence was never applied one level in,
%%% where the checker reads kind out of a comparison to NARROW a union. Measured
%%% at 8f87cad, before the fix:
%%%
%%%     type T = int | atom
%%%     int Tag(int x)
%%%     Tag(x) -> x
%%%     public int Bump(T n)
%%%     Bump(n) when n >= 0 -> Tag(n)
%%%     Bump(n)             -> 0
%%%
%%%     bs> Bump(:foo)
%%%     :foo
%%%
%%% An atom returned from a function declared `public int`, with no crash and no
%%% diagnostic. `apply_guard/3` intersects `n` with `range(0, pos_inf)`, so `Tag(n)`
%%% type-checks against an `int` parameter; the emitter writes a bare `n >= 0`, and
%%% every atom sorts above every integer on the BEAM, so clause 1 is entered with
%%% an atom bound. This is ticket 06's third outcome, SILENT UNSOUNDNESS.
%%%
%%% THE PRIVATE CALLEE IS WHAT MAKES IT SILENT. With `Tag` declared `public` the
%%% same program raises `function_clause`, because the callee's own `int_guard/5`
%%% catches the atom — which is why this first measured as ticket 25 §5's decided
%%% arithmetic cost. A private helper called from a guarded clause is an entirely
%%% ordinary shape, and it has no boundary guard of its own (ticket 18 §4).
%%%
%%% THE TEST MUST BE `is_integer`, NOT `not is_atom`. A float passes `>= 0` by the
%%% same ordering, and there is no `float` in the language to declare it away with
%%% — ticket 58's own probe is `100.5`. Only a type test closes the tower.
%%%
%%% Implements ticket 18 §1(b) and ticket 58's rule at the narrowing site. Decides
%%% nothing.
%%% ---------------------------------------------------------------------------

union() -> "type T = int | atom\n".

%% A PRIVATE callee, which is the half that turns the defect silent: it gets no
%% boundary guard, so it accepts whatever the guarded clause hands it.
tag() -> "int Tag(int x)\n"
         "Tag(x) -> x\n".

%% The printed source of one emitted function, so a test can assert on the guard
%% the compiler actually wrote rather than on the outcome alone. Both registers
%% are needed for the same reason F24 gives: `function_clause` proves that no
%% clause matched, never that this guard is why.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

count_substr(S, Sub) -> length(string:split(S, Sub, all)) - 1.

%%% --- F24.8, F24.9 — the reported defect, the `when` path --------------------

%% ENG-330's own program, as an assertion. `:foo` must fall through to clause 2.
an_atom_does_not_enter_a_clause_narrowed_by_an_ordering_guard_test() ->
    Src = "module Nar2\n" ++ union() ++ tag() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> Tag(n)\n"
          "Bump(n)             -> 0\n",
    M = build_and_load(Src, 'Nar2'),
    %% The domain the guard was written for still answers — a fix that closed
    %% the door on the integers would pass the assertion below and be useless.
    ?assertEqual(7, M:'Bump'(7)),
    ?assertEqual(0, M:'Bump'(-1)),
    %% THE DEFECT. `:foo >= 0` is true on the BEAM, so clause 1 was entered and
    %% `:foo` came back out of a function declared `public int`.
    ?assertEqual(0, M:'Bump'(foo)).

%% The same hole reached by a float rather than an atom, which is why the
%% injected test is `is_integer` and not `not is_atom`. There is no `float` type
%% in the language, so this value cannot be declared away — it arrives as a term.
a_float_does_not_enter_a_clause_narrowed_by_an_ordering_guard_test() ->
    Src = "module Nar3\n" ++ union() ++ tag() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> Tag(n)\n"
          "Bump(n)             -> 0\n",
    M = build_and_load(Src, 'Nar3'),
    ?assertEqual(7, M:'Bump'(7)),
    ?assertEqual(0, M:'Bump'(1.5)).

%%% --- F24.10 — the relational-pattern path, and the arm that shares it -------

%% `rel_expr/2` lowers `>= 0` in PATTERN position, a second site with the same
%% defect and a different route into it. Measured separately at 8f87cad:
%% `Bump(:foo)` answered 1.
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

%%% --- F24.10, continued — the switch arm -------------------------------------

%% An arm does not pass through `clause/4`; it lowers through `arm/2`, which
%% repeats the same two steps. A fix wired only into the clause head leaves this
%% arm matching an atom, and a vacuous arm is only a warning — so the program
%% would still compile and still be wrong.
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

%%% --- F24.11 — the alternative that must survive -----------------------------

%% THE TRAP THIS FILE EXISTS TO SET. `alternatives/1` splits `n >= 0 or n == :ok`
%% into two, crediting the first as `int` and the second as the atom `:ok`, and
%% BOTH are values clause 1 legitimately takes. A fix that conjoins `is_integer`
%% onto the whole guard kills the second alternative: emit would then refuse a
%% value the checker proved the clause matches, the residual it subtracted would
%% be wrong, and `:ok` would fall off the end as `function_clause`. The injection
%% must land ON THE COMPARISON NODE, never on the guard.
an_atom_alternative_beside_an_ordering_survives_test() ->
    Src = "module Alt1\n" ++ union() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 or n == :ok -> 1\n"
          "Bump(n)                         -> 0\n",
    M = build_and_load(Src, 'Alt1'),
    ?assertEqual(1, M:'Bump'(7)),
    %% The alternative the naive fix destroys.
    ?assertEqual(1, M:'Bump'(ok)),
    %% And the defect itself, still closed.
    ?assertEqual(0, M:'Bump'(foo)),
    ?assertEqual(0, M:'Bump'(-1)).

%%% --- F24.8 — the emitted half -----------------------------------------------

%% What the compiler WROTE, so a `function_clause` from any other cause cannot
%% certify the fix.
the_narrowing_guard_carries_the_type_test_test() ->
    Src = "module Emt1\n" ++ union() ++
          "public int Bump(T n)\n"
          "Bump(n) when n >= 0 -> 1\n"
          "Bump(n)             -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Emt1', 'Bump'),
    %% Exactly one: clause 1's comparison gains the test, and clause 2 has no
    %% comparison to gain one from. `T` is not int-only, so `boundary_guards/5`
    %% contributes none of its own.
    ?assertEqual(1, count_substr(Printed, "is_integer")).

%%% --- F24.12 — the control that keeps this from firing on everything ---------

%% AN INT-ONLY PARAMETER GAINS NOTHING. Its kind is already established — by the
%% boundary guard when the function is public (F24), and by the B# call site when
%% it is private (ticket 18 §4) — so a second test would be redundant, and a fix
%% that emitted one everywhere would pass every assertion above while making
%% every guard in the corpus wider. This is the probe such a fix fails.
an_int_only_parameter_gains_no_second_test_test() ->
    Src = "module Ctl1\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "public int Classify(Octet n)\n"
          "Classify(n) when n >= 9 -> 1\n"
          "Classify(n)             -> 0\n",
    {ok, _} = compile(Src),
    Printed = emitted('Ctl1', 'Classify'),
    %% Two, and both are the boundary guard's: one per clause, from `int_guard/5`.
    %% The narrowing injection must add nothing here.
    ?assertEqual(2, count_substr(Printed, "is_integer")),
    M = build_and_load(Src, 'Ctl1'),
    ?assertEqual(1, M:'Classify'(10)),
    ?assertEqual(0, M:'Classify'(3)).
