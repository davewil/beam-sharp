-module(boundary_range_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F37 — the range half of the boundary guard: a refined `int` parameter is
%%% inside its refinement at the exported boundary
%%%
%%% TICKET 46, resolved 2026-08-23 and never built. F24 built the *kind* half —
%%% `is_integer/1`, ticket 58 — and recorded this one as owed at `F24:150`.
%%% Measured on the corpus before this feature:
%%%
%%%     $ bsc --src-root examples examples/Wire Classify 300
%%%     :reserved
%%%     $ bsc --src-root examples examples/Wire Band -5
%%%     :low
%%%     $ bsc --src-root examples examples/Wire Sizing 300
%%%     :high
%%%
%%% All three parameters are declared `Octet`, which publishes `0..255`. `300`
%%% and `-5` are integers, so F24's type test lets them through; nothing then
%%% asks whether they are in the domain the `-spec` advertises.
%%%
%%% THE RULE IS SUBTRACTION, NOT A FLAG (46 §2). `constrains_kind/1` is a boolean
%%% because a tag either is or is not constrained; a bound can be HALF proved.
%%% `Classify(>= 9)` proves the lower half of `0..255` and owes the upper, so it
%%% carries `=< 255` and nothing else. `Classify(1)` and `Classify(>= 4 and <= 7)`
%%% carry nothing: a literal and a two-sided span prove themselves inside the
%%% domain. Over `wire.bs` that is six of eleven clauses emitting nothing and six
%%% comparisons among the other five, against twenty-two for a naive
%%% two-per-clause emission — which is why `a_clause_carries_only_what_it_has_not_proved`
%%% asserts the COUNT and not just the behaviour. Behaviour alone cannot tell
%%% subtraction from the naive form: both crash on `300`.
%%%
%%% AN UNREADABLE GUARD IS ITS OWN CASE, and
%%% `an_unreadable_guard_is_credited_with_nothing` is built on it. A guard the
%%% checker cannot read credits an UNINHABITED type for that clause, and an
%%% emitter that subtracts the declared type from an uninhabited one finds
%%% nothing to emit — so the clause would lose its guard entirely, which is the
%%% one direction a boundary must never fail in. `bs_check:positions/2` answers
%%% `term` at such a position instead, so the clause is over-guarded.
%%%
%%% MEASURED 2026-09-08, AND THE MEASUREMENT CORRECTED THIS COMMENT. It claimed
%%% that reading the checker's `Certain` bound rather than `Possible` would make
%%% this test fail. Swapping them leaves all ten tests green: `Certain` is
%%% either `none` or identical to `Possible`, and `positions/2` maps `none` to
%%% `term`. So this test defends that fallback, not the choice of bound — which
%%% is worth defending, because a fallback that looks incidental is what a later
%%% tidy-up deletes. F37.4 carries the whole correction.
%%%
%%% Implements ticket 46. Decides nothing.
%%% ---------------------------------------------------------------------------

octet() -> "type Octet = int where value >= 0 and value <= 255\n".

%% The printed source of one emitted function, so a test can assert on the head
%% the compiler actually wrote and not only on the outcome. Both registers are
%% needed for the same reason F24 gives: `function_clause` proves that no clause
%% matched, never that this guard is why.
emitted(Mod, Name) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam",
                        [abstract_code]),
    [F] = [F || F = {function, _, N, _, _} <- Forms, N =:= Name],
    lists:flatten(erl_pp:function(F)).

count_substr(Hay, Needle) ->
    length(string:split(Hay, Needle, all)) - 1.

%% The whole of `wire.bs`'s `Classify`, because `Octet` is a CLOSED domain and
%% ticket 12 §2 makes a catch-all over one an error — so this fixture cannot be
%% trimmed to the clauses an assertion is about.
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

%%% --- F37.1 — the reported escape, above the domain --------------------------

%% Ticket 46's own measurement, as an assertion. `300` reaches `Classify(>= 9)`
%% because `300 >= 9`, and that clause publishes `0..255`.
an_integer_above_the_domain_does_not_reach_a_refined_parameter_test() ->
    Src = "module Wire\n" ++ octet() ++ classify(),
    M = build_and_load(Src, 'Wire'),
    %% The domain still answers. Both INCLUSIVE EDGES are asserted, because an
    %% off-by-one at the bound is the failure this shape invites and `100` alone
    %% would not see it.
    ?assertEqual(method, M:'Classify'(1)),
    ?assertEqual(reserved, M:'Classify'(0)),
    ?assertEqual(reserved, M:'Classify'(255)),
    ?assertEqual(reserved, M:'Classify'(100)),
    %% THE DEFECT.
    ?assertError(function_clause, M:'Classify'(300)),
    ?assertError(function_clause, M:'Classify'(256)),
    %% F24's half must still hold: this feature adds a bound, it does not
    %% replace the type test. `100.5` passes every comparison in the module.
    ?assertError(function_clause, M:'Classify'(100.5)).

%%% --- F37.2 — the escape BELOW the domain, which the ticket did not frame -----

%% 46 §2: *"`Band(n) when n <= 64` emits the LOWER bound and is what catches
%% `Band(-5)`, which returns `:low` today: the ticket framed the question
%% entirely around values above the domain, and half the escapes are below it."*
%% Asserted separately from F37.1 so a fix that emits only upper bounds — the
%% shape the ticket's own prose suggests — is visible as a partial fix.
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
    %% THE DEFECT, at the clause that proves only the upper half.
    ?assertError(function_clause, M:'Band'(-5)),
    ?assertError(function_clause, M:'Band'(-1)),
    %% And above, at the two clauses that prove only the lower half.
    ?assertError(function_clause, M:'Band'(256)).

%%% --- F37.3 — subtraction, asserted as a count -------------------------------

%% THE ASSERTION BEHAVIOUR CANNOT MAKE. A naive two-comparisons-per-clause
%% emission crashes on exactly the same inputs as the decided one, so every
%% probe above passes under it. What separates them is what the compiler WROTE,
%% and the emitted form is the compiler's own published output — the same
%% boundary `--api` and the `-spec` are read at.
%%
%% 46 §2's table, clause by clause:
%%
%%   Classify(1) (0,1,2,3,8)        nothing   a literal proves itself in 0..255
%%   Classify(>= 4 and <= 7)        nothing   a two-sided span proves itself
%%   Classify(>= 9)                 =< 255    the lower half is proved
%%
%% Six clauses, one comparison. Naive emission would write fourteen.
a_clause_carries_only_what_it_has_not_proved_test() ->
    Src = "module Wire\n" ++ octet() ++ classify(),
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Classify'),
    %% One comparison in the whole function, on the `>= 9` clause. The `>=` in
    %% `Classify(>= 4 and <= 7)` is F2's RELATIONAL PATTERN and not a boundary
    %% guard, so `>=` cannot be counted; `=<` can, because no clause of this
    %% function writes one.
    ?assertEqual(1, count_substr(Printed, "=< 255")),
    %% And nothing on the clauses that prove themselves. `>= 0` is the lower
    %% bound of `Octet` and no `Classify` clause owes it: every clause is either
    %% a literal, a two-sided span, or `>= 9`.
    ?assertEqual(0, count_substr(Printed, ">= 0")).

%% The mirror of the count above, on the function whose clauses owe the lower
%% bound. `Band` is three clauses: two owe `=< 255` and one owes `>= 0`.
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

%%% --- F37.4 — the discriminator: Certain against Possible --------------------

%% THE CLAUSE THE CHECKER CANNOT READ, WHICH IS THE ONE AT RISK OF NO GUARD.
%%
%% A guard the checker cannot read credits `bs_types:none()` for that clause —
%% deliberately, because crediting an unread guard is what let
%% `F(n) when Weird(n)` report as exhaustive (ticket 08). An emitter that
%% subtracted the declared type from `none` would find nothing to emit and
%% `300` would walk in. `bs_check:positions/2` answers `term` for an
%% uninhabited type, so both bounds are emitted and the clause refuses it.
%%
%% This is a regression test on that fallback. See the header for what was
%% measured about the `Certain`/`Possible` choice, which is a separate and
%% weaker claim than this comment used to make.
%%
%% `n > m` is unreadable because `bs_check:comparison/1` translates a variable
%% against an INTEGER LITERAL and nothing else; two variables fall through to
%% `unknown`. No helper function is needed to build the case.
an_unreadable_guard_is_credited_with_nothing_test() ->
    Src = "module Wire\n" ++ octet() ++
          "public int Foo(Octet n, Octet m)\n"
          "Foo(n, m) when n > m -> 1\n"
          "Foo(n, m)            -> 0\n",
    M = build_and_load(Src, 'Wire'),
    %% The readable path still answers.
    ?assertEqual(1, M:'Foo'(200, 1)),
    ?assertEqual(0, M:'Foo'(1, 200)),
    %% `300 > 1` is true, so an emitter that left clause 1 unguarded would match
    %% it and return 1. Guarded, clause 1 fails and clause 2 — which is guarded
    %% either way — refuses it too.
    ?assertError(function_clause, M:'Foo'(300, 1)),
    ?assertError(function_clause, M:'Foo'(-5, -9)),
    %% Asserted in the emitted register as well, so a crash arriving from some
    %% other cause cannot certify this. Two parameters, two clauses, two bounds
    %% each: eight comparisons, none of which any clause proves.
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Foo'),
    ?assertEqual(4, count_substr(Printed, ">= 0")),
    ?assertEqual(4, count_substr(Printed, "=< 255")).

%%% --- F37.5 — scope: exported only -------------------------------------------

%% 46 §1, on 18 §4: rule C *"looks at the exported function's own clause heads
%% and body, and no further"*. A private function's every call site is a checked
%% B# call site, so site 1 already refused the out-of-domain argument and the
%% guard would be dead weight on every call.
%%
%% This matches F24's `is_integer` and deliberately NOT the record tag test,
%% which is emitted on private functions too — an asymmetry 46's *Corrections*
%% recorded as measured, and which ticket 59 (ENG-241) owns.
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

%%% --- F37.6 — a plain `int` owes nothing -------------------------------------

%% `int` is unrefined: its bounds are `neg_inf` and `pos_inf`, so there is no
%% comparison to make and F24's type test is the whole of the boundary. Asserted
%% because a guard that fires on every int parameter would pass every probe
%% above while putting two dead comparisons on every exported call in the corpus.
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
    %% F24's half is still there, so the absence above is a measurement of this
    %% feature rather than of a module that never compiled.
    ?assertEqual(1, count_substr(Printed, "is_integer")).

%%% --- F37.7 — a union parameter carries nothing, and the reason is ordering ---

%% `Octet | :none` is not int-only, so no range guard is emitted — the same gate
%% F24 puts on `is_integer`.
%%
%% THIS IS NOT MERELY CONSISTENCY. Erlang's term order puts atoms ABOVE every
%% number, so `none =< 255` is FALSE. A comparison emitted without the int-only
%% gate would refuse a legitimate `:none` caller at a parameter that declares it.
%% The guard is admissible only where the declared type has no other kind in it.
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

%%% --- F37.8 — a refinement with two ranges -----------------------------------

%% `int where value < 0 or value > 10` resolves to TWO ranges, and the language
%% admits it today — measured, not assumed. Ticket 20 §5 puts a guard-decidable
%% refinement in the O(1) tier, and this one still is: a disjunction of range
%% tests decides it in constant time, so it is inside 46's scope rather than
%% beside it.
%%
%% The interior bounds are never dropped. Only the LOWEST range's lower bound
%% and the HIGHEST range's upper bound may be, and only where the clause proves
%% no value escapes on that side — which is what keeps `wire.bs` at six
%% comparisons while leaving this shape correct.
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
    %% THE HOLE BETWEEN THE RANGES. Every one of these satisfies a single
    %% two-bound test built from the outermost bounds, so a fix that collapses a
    %% multi-range refinement to its hull passes nothing here.
    ?assertError(function_clause, M:'Grab'(0)),
    ?assertError(function_clause, M:'Grab'(5)),
    ?assertError(function_clause, M:'Grab'(10)).

%%% --- F37.9 — the switch subject is guarded at the clause head ---------------

%% `Sizing(300)` returned `:high`. The escape is at the CLAUSE HEAD, whose
%% pattern is a bare variable declared `Octet`, and not in the switch arms: by
%% the time the subject reaches an arm the head has proved it is an `Octet`.
%% Asserted so a later reader does not go looking for a second emission site in
%% `arm/2`, which ENG-330 amended for its own reason.
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
    %% One clause, a bare variable, so it proves neither bound: exactly two
    %% comparisons, and both on the head.
    {ok, _} = compile(Src),
    Printed = emitted('Wire', 'Sizing'),
    ?assertEqual(1, count_substr(Printed, ">= 0")),
    ?assertEqual(1, count_substr(Printed, "=< 255")).
