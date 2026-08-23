-module(switch_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% F7 — `switch`, ticket 17 §6
%%%
%%% The one structural move run backwards: ticket 01 moved C#'s pattern grammar
%%% OUT of switch arms and into the parameter position, and this puts the same
%%% grammar back into expression position. So most of what is asserted below is
%%% that a switch inherits behaviour rather than acquiring it — the residual, the
%%% redundancy warning, the Certain/Possible split and the guard translation are
%%% all the clause head's, reached through a second door.
%%% ---------------------------------------------------------------------------

%% F7.1. `LANGUAGE.md` §5's own first block, which the reference called `not-yet`
%% from the day it was written until this feature.
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

%% F7.2. The tuple subject, and the property that matters is the ABSENCE of a
%% catch-all: a `_` would satisfy the compiler here, and nothing needs one.
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

%% THE DEFECT F7.2 FOUND, and it has nothing to do with `switch`.
%%
%% `LANGUAGE.md` §4 said `true` and `false` are the only keyword atoms and marked
%% it **shipped**. The lexer had `:true` and `:false` and no bare rule, so a bare
%% `true` in a pattern was an ordinary lowercase identifier — a VARIABLE, which
%% matches everything. This program compiled on master and answered `:ack` for
%% `false`, with nothing but an unreachable-clause warning to say so.
%%
%% Asserted at the CLAUSE HEAD, where the defect lived, rather than at the arm
%% that found it.
bare_true_and_false_are_atoms_not_variables_test() ->
    Src = "module Heads\n"
          "public atom Decide(bool ok)\n"
          "Decide(true)  -> :yes\n"
          "Decide(false) -> :no\n",
    {ok, _, Diags} = check_only(Src),
    %% No unreachable-clause warning: the second clause is live, which is only
    %% true if the first one matched an atom rather than binding a name.
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Heads'),
    ?assertEqual(yes, M:'Decide'(true)),
    ?assertEqual(no,  M:'Decide'(false)).

%% F7.3. The residual IS the missing arm — ticket 04 at a third site — and it is
%% printed as an arm rather than through `heads/2`, which would have said
%% `Which(:cancelled) -> ...` for a construct with no clauses and a different
%% arrow.
an_inexhaustive_switch_names_the_missing_arm_test() ->
    Src = "module Missing\n"
          "type Event = :placed | :shipped | :cancelled\n"
          "public atom Which(Event e)\n"
          "Which(e) -> e switch {\n"
          "    :placed  => :new,\n"
          "    :shipped => :gone\n"
          "}\n",
    [{error, _, 'Which', {switch_inexhaustive, Residual}}] = errors(Src),
    ?assertEqual(":cancelled", bs_types:to_pattern(Residual)).

%% F7.4. An arm guard is credited to the exhaustiveness check, which is
%% `math.bs` one level down — and it is the first thing ever to ask `refine_at/3`
%% to refine a WHOLE value. A clause-head path always begins with a parameter
%% index, so it is never empty; a switch subject is one value, so it always is.
%% Without the empty-path clause this does not report, it crashes.
%%
%% THE LAST ARM WAS `_` UNTIL F2, and what changed it is ticket 12 §2 reaching
%% further than that ticket's own examples suggested. 12 §2 illustrates a closed
%% residual with a declared union of atoms; its operative definition is *contains
%% an unbounded top*, and after the two guards the residual here is `0` — one
%% integer, no top, closed. So `_` now discards a case the compiler can name, and
%% naming it is both legal and better: the arm says what it covers, and a later
%% edit to either guard cannot be silently absorbed.
%%
%% The test's point survives intact and sharpens. It exists to show the guards
%% were credited, and `0 => :zero` only type-checks as exhaustive if they were.
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

%% ...and the control, aimed at the arm that does not cover. F6.1 cost a scenario
%% by learning that a green control reads exactly like a passing one: delete the
%% catch-all and the two intervals must leave `0` behind, which is only true if
%% the guards were translated rather than ignored.
a_guard_on_an_arm_leaves_the_gap_it_should_test() ->
    Src = "module SignsControl\n"
          "public atom Sign(int n)\n"
          "Sign(n) -> n switch {\n"
          "    m when m > 0 => :positive,\n"
          "    m when m < 0 => :negative\n"
          "}\n",
    [{error, _, 'Sign', {switch_inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("0", bs_types:to_pattern(Residual)).

%% F7.5. F5.7's lesson at a second site, and the reason this test exists rather
%% than a passing one: build the arm's domain from `Certain` instead of
%% `Possible` and the compiler does not break, it goes QUIET. `Certain` is `none`
%% under a guard the checker cannot read, every containment over `none` passes
%% vacuously, and the arm stops being checked with nothing to notice.
%%
%% So the assertion is on an error the wrong build OMITS.
an_untranslatable_arm_guard_credits_nothing_test() ->
    Src = "module Opaque\n"
          "public bool Big(int n)\n"
          "Big(n) -> n > 100\n"
          "public atom Check(int n)\n"
          "Check(n) -> n switch {\n"
          "    m when Big(m) => :big\n"
          "}\n",
    [{error, _, 'Check', {switch_inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("int", bs_types:to_pattern(Residual)).

%% ...and this is the one that actually catches the mutation, which the test
%% above does NOT: the residual is computed from `Certain` either way, so
%% asserting it says nothing about the domain the body is typed against.
%%
%% Here the arm's body hands an `int` to a function declared over `atom`. Built
%% with `Possible`, `m` is `int` and site 1 rejects it. Built with `Certain`,
%% `m` is `none` under the unreadable guard, `subtract(none, atom)` is empty, and
%% the call is accepted in silence. A check that fails by going quiet cannot be
%% caught by a passing test — only by asserting the error the wrong build omits.
an_arm_body_under_an_unreadable_guard_is_still_checked_test() ->
    Src = "module Quiet\n"
          "public bool Big(int n)\n"
          "Big(n) -> n > 100\n"
          "public atom Tag(atom a)\n"
          "Tag(a) -> :seen\n"
          "public atom Check(int n)\n"
          "Check(n) -> n switch {\n"
          "    m when Big(m) => Tag(m),\n"
          "    _             => :small\n"
          "}\n",
    ?assertMatch([{error, _, 'Check', {arg_not_accepted, 'Tag', 1, _, _}}],
                 errors(Src)).

%% F7.6. Arm, not clause. The word is the whole of the message's usefulness.
%%
%% THE SUBJECT WAS A DECLARED UNION UNTIL F2, and it had to move to `atom` for a
%% reason that is about a different rule entirely: ticket 12 §2 now makes a `_`
%% over a CLOSED residual an error, so the old source reported two things and this
%% test could no longer see the one it is about. `atom` is the cofinite top —
%% ticket 10 made the atom universe open — so the catch-all is legal there, which
%% is 12 §2's own second bullet: a foreign sender chooses the inhabitants and
%% there is nothing to enumerate.
a_redundant_arm_is_a_warning_about_an_arm_test() ->
    Src = "module Dead\n"
          "public atom Which(atom a)\n"
          "Which(a) -> a switch {\n"
          "    _        => :other,\n"
          "    :placed  => :new\n"
          "}\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Which', {unreachable_arm, 2}}], Diags).

%% F7.7, the good half. An arm's pattern names are readable in that arm, and a
%% build whose `expr_vars/1` answers `[]` for a switch also passes this — which
%% is why the mirror below exists.
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

%% F7.7, the half that is unfalsifiable without the other. The subtraction is
%% PER ARM: subtract the whole switch's names and a typo in one arm is covered by
%% a sibling that happens to bind the same name.
an_unbound_name_in_an_arm_body_is_reported_test() ->
    Src = "module Scope\n"
          "public term Bad(term e)\n"
          "Bad(e) -> e switch {\n"
          "    (:ok, v) => w,\n"
          "    (:no, w) => w\n"
          "}\n",
    ?assertMatch([{error, _, 'Bad', {unbound_variable, w}}], errors(Src)).

%% F7.8. Stronger than ticket 34's rule applied evenly: in Erlang a `case` arm
%% pattern naming an already-bound variable is not a binding, it is an EQUALITY
%% TEST against the existing value. Accepting it would emit a silently different
%% program from the one that reads like a fresh binding.
an_arm_may_not_rebind_a_name_in_scope_test() ->
    Src = "module Rebind\n"
          "public atom Pick(int n, term e)\n"
          "Pick(n, e) -> e switch {\n"
          "    n => :same,\n"
          "    _ => :other\n"
          "}\n",
    ?assertMatch([{error, _, 'Pick', {rebinding, n}}], errors(Src)).

%% F7.9. A parameter read ONLY inside an arm body. If `used_vars/2` does not
%% descend into arms, the head lowers to `_N` and the arm body emits `N` — which
%% is a compile ERROR in the emitted Erlang, not a warning, so this test fails at
%% `build_and_load/2` rather than on an assertion.
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

%% F7.10. A switch synthesises and declares nothing, so it opens no sixth site —
%% ticket 33 enumerated five. What it does is make site 4 reachable from a place
%% it could not be reached from before.
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

%% F7.11. The grammar already spends `{` on record declarations, anonymous map
%% types, property patterns, record construction and `with`. Asserted by PARSE,
%% not by conflict count — F6.9's note stands: yecc resolves shift/reduce
%% silently through the precedence table, and every one of ticket 28a's four
%% variants reported zero conflicts including the one that read the case wrong.
braces_nest_three_ways_test() ->
    Src = "module Nesting\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public Order Normalise(Doc d)\n"
          "Normalise(d) -> d switch {\n"
          "    { Kind: :'Nesting.Order' }   => Order{ Id = 1, Total = 2 },\n"
          "    { Kind: :'Nesting.Invoice' } => Order{ Id = 3, Total = 4 }\n"
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
                                                   'Id' => 9, 'Total' => 9}))).

%% F7.12. F7's grammar opens this the way F5's opened `_`-as-a-value: a guard
%% shares the whole expression grammar, so a switch parses inside one. Erlang's
%% guards are a restricted sublanguage with no `case`, so left alone this arrives
%% as `illegal guard expression` from `erlc`, against the `.abstr` the author did
%% not write — which is F4.7's rule.
a_switch_in_a_guard_is_refused_test() ->
    Src = "module GuardSwitch\n"
          "public atom F(atom x)\n"
          "F(x) when x switch { :a => true, _ => false } -> :yes\n"
          "F(x) -> :no\n",
    ?assertMatch([{error, _, 'F', switch_in_guard} | _], errors(Src)).

%% F7.15. The first shape that puts F4 and F7 through the same clause, and
%% ticket 17 §6's own stated reason for the construct: *"you can branch on an
%% intermediate without inventing a parameter to dispatch on"* — 01b's friction.
%%
%% Four paths meet here and every one is new or changed by F7: `check_scope/5` →
%% `name_diags/5` → `rebinds/3` in the scope pass, `bind_step/3` → `type_of/3`
%% for the subject, and `binds/3` → `expr/2` in the emitter. Nothing else in this
%% section crosses that seam, and `examples/queue.bs` has no bindings at all.
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

%% ...and F7.8's rule reached from the other side: there the name came from a
%% clause head, here from a binding above the switch. Erlang would have turned
%% this into an equality test against the bound value.
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

%% A `switch` in tail position keeps the tail call. `bs_emit`'s header says the
%% body is a flat list rather than a `begin` block precisely so the last
%% expression stays in tail position, and F7 makes a switch the ordinary thing to
%% put there — an OTP process loop branches on a message and recurses in one arm.
%% Erlang's `case` preserves it; nothing asserted that until now.
%%
%% Asserted on the emitted bytecode, like `recursion_is_a_tail_call_test`: a
%% `call` or `call_ext` op means a stack frame was built.
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

