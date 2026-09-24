%%% Scenarios: compiler/features/F7-switch.md
-module(switch_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1]).

-define(OUT, bs_test_support:run_root()).

%%% F7 — switch expressions

%% F7.1 — a switch dispatches and runs.
a_switch_dispatches_and_runs_test() ->
    Src = "module Traffic\n"
          "type Verdict = :new | :gone | :unknown\n"
          "public Verdict Describe(atom status)\n"
          "Describe(s) -> s switch {\n"
          "    :placed  => :new,\n"
          "    :shipped => :gone,\n"
          "    _        => :unknown\n"
          "}\n",
    M = build_and_load(Src, 'Traffic'),
    ?assertEqual(new,     M:'Describe'(placed)),
    ?assertEqual(gone,    M:'Describe'(shipped)),
    ?assertEqual(unknown, M:'Describe'(frozen)).

%% F7.2 — tuple arms are exhaustive without a catch-all.
a_tuple_subject_is_exhaustive_without_a_catch_all_test() ->
    Src = "module Queue\n"
          "type Disposition = :ack | :dead_letter | :requeue\n"
          "public Disposition Decide(bool ok, bool permanent, bool redelivered)\n"
          "Decide(o, p, r) -> (o, p, r) switch {\n"
          "    (true,  _,     _)     => :ack,\n"
          "    (false, true,  _)     => :dead_letter,\n"
          "    (false, false, false) => :requeue,\n"
          "    (false, false, true)  => :requeue\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Queue'),
    ?assertEqual(ack,         M:'Decide'(true, false, false)),
    ?assertEqual(dead_letter, M:'Decide'(false, true, false)),
    ?assertEqual(requeue,     M:'Decide'(false, false, true)),
    ?assertEqual(requeue,     M:'Decide'(false, false, false)).

bare_true_and_false_are_atoms_not_variables_test() ->
    Src = "module Heads\n"
          "public atom Decide(bool ok)\n"
          "Decide(true)  -> :yes\n"
          "Decide(false) -> :no\n",
    {ok, _, Diags} = check_only(Src),
    %% Both clauses are live only if bare booleans match atoms.
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Heads'),
    ?assertEqual(yes, M:'Decide'(true)),
    ?assertEqual(no,  M:'Decide'(false)).

%% F7.3 — the residual names the missing arm.
an_inexhaustive_switch_names_the_missing_arm_test() ->
    Src = "module Missing\n"
          "type Event = :placed | :shipped | :cancelled\n"
          "public atom Which(Event e)\n"
          "Which(e) -> e switch {\n"
          "    :placed  => :new,\n"
          "    :shipped => :gone\n"
          "}\n",
    [{error, _, 'Which', {switch_inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual(":cancelled", bs_types:to_pattern(Residual)).

%% F7.4 — arm guards contribute to exhaustiveness.
%% The explicit zero arm is exhaustive only when both guards count.
a_guard_on_an_arm_is_credited_test() ->
    Src = "module Signs\n"
          "public atom Sign(int n)\n"
          "Sign(n) -> n switch {\n"
          "    m when m > 0 => :positive,\n"
          "    m when m < 0 => :negative,\n"
          "    0            => :zero\n"
          "}\n",
    M = build_and_load(Src, 'Signs'),
    ?assertEqual(positive, M:'Sign'(5)),
    ?assertEqual(negative, M:'Sign'(-3)),
    ?assertEqual(zero,     M:'Sign'(0)).

%% Without the zero arm, translated guards must leave exactly zero.
a_guard_on_an_arm_leaves_the_gap_it_should_test() ->
    Src = "module SignsControl\n"
          "public atom Sign(int n)\n"
          "Sign(n) -> n switch {\n"
          "    m when m > 0 => :positive,\n"
          "    m when m < 0 => :negative\n"
          "}\n",
    [{error, _, 'Sign', {switch_inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("0", bs_types:to_pattern(Residual)).

%% F7.5 — an unreadable arm guard contributes no coverage.
%% Remainder is legal on the BEAM but opaque to the coverage checker.
an_untranslatable_arm_guard_credits_nothing_test() ->
    Src = "module Opaque\n"
          "public atom Check(int n)\n"
          "Check(n) -> n switch {\n"
          "    m when m % 2 == 0 => :big\n"
          "}\n",
    [{error, _, 'Check', {switch_inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("int", bs_types:to_pattern(Residual)).

%% Coverage alone cannot show whether the arm body is checked.
%% The bad call must fail even when the guard contributes no coverage.
an_arm_body_under_an_unreadable_guard_is_still_checked_test() ->
    Src = "module Quiet\n"
          "public atom Tag(atom a)\n"
          "Tag(a) -> :seen\n"
          "public atom Check(int n)\n"
          "Check(n) -> n switch {\n"
          "    m when m % 2 == 0 => Tag(m),\n"
          "    _             => :small\n"
          "}\n",
    ?assertMatch([{error, _, 'Check', {arg_not_accepted, 'Tag', 1, _, _}}],
                 errors(Src)).

%% F7.6 — a covered arm receives an arm warning.
%% Open `atom` makes the catch-all legal, isolating the redundancy warning.
a_redundant_arm_is_a_warning_about_an_arm_test() ->
    Src = "module Dead\n"
          "public atom Which(atom a)\n"
          "Which(a) -> a switch {\n"
          "    _        => :other,\n"
          "    :placed  => :new\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Which', {unreachable_arm, 2}}], Diags).

%% F7.7 — an arm can read its own bindings.
an_arm_binds_its_own_names_test() ->
    Src = "module Scope\n"
          "public term Ok(term e)\n"
          "Ok(e) -> e switch {\n"
          "    (:ok, v) => v,\n"
          "    _        => :none\n"
          "}\n",
    M = build_and_load(Src, 'Scope'),
    ?assertEqual(42,   M:'Ok'({ok, 42})),
    ?assertEqual(none, M:'Ok'(other)).

%% F7.7 — a sibling arm cannot supply an unbound name.
an_unbound_name_in_an_arm_body_is_reported_test() ->
    Src = "module Scope\n"
          "public term Bad(term e)\n"
          "Bad(e) -> e switch {\n"
          "    (:ok, v) => w,\n"
          "    (:no, w) => w\n"
          "}\n",
    ?assertMatch([{error, _, 'Bad', {unbound_variable, w}}], errors(Src)).

%% F7.8 — an arm cannot rebind an in-scope name.
%% Erlang treats an already-bound pattern variable as an equality test.
an_arm_may_not_rebind_a_name_in_scope_test() ->
    Src = "module Rebind\n"
          "public atom Pick(int n, term e)\n"
          "Pick(n, e) -> e switch {\n"
          "    n => :same,\n"
          "    _ => :other\n"
          "}\n",
    ?assertMatch([{error, _, 'Pick', {rebinding, n}}], errors(Src)).

%% F7.9 — parameters used only in arms retain their names.
%% An underscored parameter makes the emitted arm fail to compile.
a_parameter_read_only_inside_an_arm_is_not_underscored_test() ->
    Src = "module Underscore\n"
          "public int Report(int n, atom tag)\n"
          "Report(n, tag) -> tag switch {\n"
          "    :double => n * 2,\n"
          "    _       => n\n"
          "}\n",
    M = build_and_load(Src, 'Underscore'),
    ?assertEqual(42, M:'Report'(21, double)),
    ?assertEqual(21, M:'Report'(21, plain)).

%% F7.10 — switch returns must satisfy the function signature.
a_switch_return_is_checked_against_the_signature_test() ->
    Src = "module Ret\n"
          "type Verdict = :new | :gone\n"
          "public Verdict Describe(atom s)\n"
          "Describe(s) -> s switch {\n"
          "    :placed => :new,\n"
          "    _       => :missing\n"
          "}\n",
    [{error, _, 'Describe', {return_not_declared, Residual, _}}] = errors(Src),
    ?assertEqual(":missing", bs_types:to_pattern(Residual)).

%% F7.11 — property patterns, construction and switches nest.
%% Bare property patterns put a brace directly after the switch brace;
%% a type prefix would bypass that grammar case.
braces_nest_three_ways_test() ->
    Src = "module Nesting\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public Order Normalise(Doc d)\n"
          "Normalise(d) -> d switch {\n"
          "    { Id: 9 } => Order{ Id = 1, Total = 2 },\n"
          "    { Id: i } => Order{ Id = i, Total = 4 }\n"
          "}\n"
          "public atom Pair(atom a, atom b)\n"
          "Pair(a, b) -> a switch {\n"
          "    :one => b switch {\n"
          "        :two => :onetwo,\n"
          "        _    => :one_other\n"
          "    },\n"
          "    _ => :other\n"
          "}\n",
    M = build_and_load(Src, 'Nesting'),
    ?assertEqual(onetwo,    M:'Pair'(one, two)),
    ?assertEqual(one_other, M:'Pair'(one, three)),
    ?assertEqual(other,     M:'Pair'(nine, two)),
    ?assertEqual(1, maps:get('Id', M:'Normalise'(#{'Kind' => 'Nesting.Order',
                                                   'Id' => 9, 'Total' => 9}))),
    ?assertEqual(4, maps:get('Id', M:'Normalise'(#{'Kind' => 'Nesting.Invoice',
                                                   'Id' => 4, 'Total' => 9}))).

%% F7.12 — switches are refused in guards.
%% The expression grammar accepts them, but Erlang guards forbid `case`.
a_switch_in_a_guard_is_refused_test() ->
    Src = "module GuardSwitch\n"
          "public atom F(atom x)\n"
          "F(x) when x switch { :a => true, _ => false } -> :yes\n"
          "F(x) -> :no\n",
    ?assertMatch([{error, _, 'F', switch_in_guard} | _], errors(Src)).

%% F7.15 — a switch can dispatch on a local binding.
a_binding_then_a_switch_on_the_bound_name_test() ->
    Src = "module Bound\n"
          "type Verdict = :large | :small\n"
          "record Order { Id: int, Total: int }\n"
          "public Verdict Grade(Order o)\n"
          "Grade(o) ->\n"
          "    var total = o.Total\n"
          "    total switch {\n"
          "        n when n > 100  => :large,\n"
          "        n when n <= 100 => :small\n"
          "    }\n",
    M = build_and_load(Src, 'Bound'),
    Order = fun(T) -> #{'Kind' => 'Bound.Order', 'Id' => 1, 'Total' => T} end,
    ?assertEqual(large, M:'Grade'(Order(500))),
    ?assertEqual(small, M:'Grade'(Order(50))).

%% Erlang would interpret the local name as an equality test.
an_arm_may_not_rebind_a_name_a_binding_introduced_test() ->
    Src = "module Bound2\n"
          "public atom Grade(int t)\n"
          "Grade(t) ->\n"
          "    var total = t + 1\n"
          "    total switch {\n"
          "        total => :same,\n"
          "        _     => :other\n"
          "    }\n",
    ?assertMatch([{error, _, 'Grade', {rebinding, total}} | _], errors(Src)).

%% Bytecode exposes stack growth: `call` and `call_ext` build frames.
a_switch_in_tail_position_keeps_the_tail_call_test() ->
    Src = "module LoopS\n"
          "public int Down(int n, int acc)\n"
          "Down(n, acc) -> n switch {\n"
          "    m when m <= 0 => acc,\n"
          "    m when m > 0  => Down(m - 1, acc + m)\n"
          "}\n",
    {ok, _} = compile(Src),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(?OUT ++ "/LoopS.beam"),
    Bad = [{Name, Op}
           || {function, Name, _A, _E, Is} <- Fns,
              Name =/= module_info,
              {Op} <- [{element(1, I)} || I <- Is, is_tuple(I)],
              Op =:= call orelse Op =:= call_ext],
    ?assertEqual([], Bad),
    M = build_and_load(Src, 'LoopS'),
    ?assertEqual(500500, M:'Down'(1000, 0)).

%%% --- Arm diagnostics -------------------------------------------------------
%%% A sole arm cannot be shadowed by an earlier arm.

a_vacuous_arm_is_not_reported_as_shadowed_test() ->
    Src = "module VacS\n"
          "type K = :a | :b\n"
          "public int H(K k)\n"
          "H(k) -> k switch {\n"
          "    (:some, x) => 0\n"
          "}\n",
    {error, Diags} = check_only(Src),
    ?assertEqual([{vacuous_arm, 1}],
                 [{T, N} || {warning, _, 'H', {T, N, _}} <- Diags]),
    ?assertMatch([{switch_inexhaustive, _, _}],
                 [P || {error, _, 'H', P = {switch_inexhaustive, _, _}} <- Diags]).

%% A switch subject is one value; a clause domain is a parameter product.
%% The subject therefore prints without the clause domain's parentheses.
a_vacuous_arm_carries_the_domain_it_is_not_a_member_of_test() ->
    Src = "module VacD\n"
          "type K = :a | :b\n"
          "public int H(K k)\n"
          "H(k) -> k switch {\n"
          "    (:some, x) => 0\n"
          "}\n",
    {error, Diags} = check_only(Src),
    [Domain] = [D || {warning, _, 'H', {vacuous_arm, 1, D}} <- Diags],
    ?assertEqual(":a | :b", bs_types:to_string(Domain)).

%% A vacuous arm in front of covering arms stays a warning, and the covering
%% arms still count, so the switch compiles.
a_vacuous_arm_does_not_make_a_covered_switch_inexhaustive_test() ->
    Src = "module VacC\n"
          "type K = :a | :b\n"
          "public int H(K k)\n"
          "H(k) -> k switch {\n"
          "    (:some, x) => 0,\n"
          "    :a         => 1,\n"
          "    :b         => 2\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'H', {vacuous_arm, 1, _}}], Diags).

%% The pattern belongs to `int`; only the guard makes the arm impossible.
an_unsatisfiable_arm_guard_is_its_own_diagnostic_test() ->
    Src = "module GuardS\n"
          "public int Grade(int n)\n"
          "Grade(n) -> n switch {\n"
          "    x when x > 5 and x < 3 => 0,\n"
          "    x                      => 1\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Grade', {unsatisfiable_arm_guard, 1}}], Diags).

%% A comparison between variables is opaque, not unsatisfiable.
an_untranslatable_arm_guard_is_not_called_unsatisfiable_test() ->
    Src = "module GuardU\n"
          "public int Cmp(int n, int m)\n"
          "Cmp(n, m) -> n switch {\n"
          "    x when x > m => 0,\n"
          "    x            => 1\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%% F7.13 — residual members print as separate, writable arms.
%% A record and an atom require both record spelling and union expansion.
a_switch_residual_is_spelled_as_a_head_spells_it_test() ->
    Src = "module SwR\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice | :nothing\n"
          "public atom Which(Doc d)\n"
          "Which(d) -> d switch {\n"
          "    Order o => :order\n"
          "}\n",
    [E = {error, _, 'Which', P}] = errors(Src),
    ?assertEqual(switch_inexhaustive, element(1, P)),
    Text = lists:flatten(bs_diag:format(bs_diag:descriptor("swr.bs", E))),
    ?assertNotEqual(nomatch, string:find(Text, ":nothing => ...")),
    ?assertNotEqual(nomatch, string:find(Text, "Invoice i => ...")),
    ?assertEqual(nomatch, string:find(Text, "Kind: :'")),
    %% A union on one line is not valid arm syntax.
    ?assertEqual(nomatch, string:find(Text, "|")).
