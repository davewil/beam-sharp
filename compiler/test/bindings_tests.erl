-module(bindings_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, count/2,
                          errors/1, escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F4 — local bindings. Ticket 34.
%%%
%%% A body is bindings followed by one expression. The lowering needs no block:
%%% an Erlang clause body is already a sequence and `{match, …}` is an ordinary
%%% form, which was measured before this was built rather than assumed.
%%% ---------------------------------------------------------------------------

bind_src() ->
    "module Bind\n"
    "record Order { Id: int, Total: int }\n"
    "public int Squared(Order o)\n"
    "Squared(o) ->\n"
    "    var t = o.Total\n"
    "    t * t\n"
    "public int Steps(int a, int b)\n"
    "Steps(a, b) ->\n"
    "    var x = a + b\n"
    "    var y = x * 2\n"
    "    y + 1\n"
    "public Order Bump(Order o)\n"
    "Bump(o) ->\n"
    "    var next = o.Total + 1\n"
    "    o with { Total = next }\n".

an_order_of(Total) -> #{'Kind' => 'Bind.Order', 'Id' => 1, 'Total' => Total}.

a_binding_names_a_value_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(49, M:'Squared'(an_order_of(7))).

several_bindings_run_in_order_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(15, M:'Steps'(3, 4)).

%% The reason David wanted them: name a value, then use it. Reads once, and the
%% emitted code reads the field once too.
a_binding_reads_a_projection_once_test() ->
    M = build_and_load(bind_src(), 'Bind'),
    ?assertEqual(an_order_of(42), M:'Bump'(an_order_of(41))),
    [Bump] = [F || F = {function, _, 'Bump', 1, _} <- forms_of('Bind')],
    %% One in the boundary guard, one in the binding — and NOT a third, which is
    %% what writing `o.Total` twice would have cost.
    ?assertEqual(2, count(Bump, map_get)).

forms_of(Mod) ->
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/" ++ atom_to_list(Mod) ++ ".beam", [abstract_code]),
    Forms.

%% The body stays a flat list rather than a `begin` block, so the last
%% expression is still in tail position.
a_binding_before_a_self_call_stays_a_tail_call_test() ->
    Src = "module Loop\n"
          "public int Down(int n, int acc)\n"
          "Down(n, acc) when n <= 0 -> acc\n"
          "Down(n, acc) when n > 0 ->\n"
          "    var next = acc + n\n"
          "    Down(n - 1, next)\n",
    M = build_and_load(Src, 'Loop'),
    ?assertEqual(500500, M:'Down'(1000, 0)).

%% A name means one thing in a clause. There is no mutation to assign with.
rebinding_a_name_is_an_error_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    var t = 1\n    var t = 2\n    t\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, t}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% ...including rebinding something the clause head already bound.
a_binding_may_not_shadow_a_parameter_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    var a = 1\n    a\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, a}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% Caught here rather than by erlc against the emitted .abstr — a file the
%% author did not write. Ticket 33 is about whether a body is TYPED; this is a
%% name question and needs no types.
an_unbound_name_is_caught_before_erlc_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    total * 2\n",
    {error, Diags} = check_only(Src),
    %% Line 3 is the clause, not line 4 where the name appears: the final
    %% expression carries no line of its own, so it is reported against the
    %% smallest span that is certainly right.
    ?assertMatch([{error, 3, 'F', {unbound_variable, total}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% A bound name nothing later mentions is legal and warning-free: naming a value
%% to say what it IS is a reason to write one.
an_unused_binding_compiles_without_a_warning_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Src = "module U\npublic int F(int a)\nF(a) ->\n    var unused = a + 1\n    a\n",
            with_src("u.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "Warning"))
            end)
    end.


%%% ---------------------------------------------------------------------------
%%% F8 — `var` binds, `=` matches, and `== name` matches a bound value.
%%% ---------------------------------------------------------------------------

%% F8.3 — the message NAMES THE FIX. This is the single most common thing a
%% reader of the old dialect will type, so the diagnostic has to do more than
%% refuse.
a_bare_binding_refuses_and_names_var_test() ->
    Src = "module E\npublic int F(int a)\nF(a) ->\n    t = 1\n    t\n",
    ?assertMatch({error, {_, bs_parser, _}}, catch_parse(Src)),
    ?assert(string:find(parse_message(Src), "var t = ") =/= nomatch).

%% ...and the same for a pattern on the left, which is the case `var` exists to
%% make expressible at all.
a_bare_destructuring_bind_refuses_test() ->
    Src = "module E\npublic int F((int, int) p)\nF(p) ->\n    (a, b) = p\n    a + b\n",
    ?assert(string:find(parse_message(Src), "var a = ") =/= nomatch).

%% F8.4 — a bare `=` that introduces NOTHING is still a match, and still one the
%% compiler proves cannot fail. Pinned against the grammar change rather than
%% re-decided.
a_bare_match_that_introduces_nothing_still_works_test() ->
    M = build_and_load("module Ok\npublic int F(int a)\nF(a) ->\n    1 = 1\n    a\n", 'Ok'),
    ?assertEqual(5, M:'F'(5)).

%% F8.2 — THE MARKER PAID, and this is the receipt. `{ Kind: k } = o` could never
%% reach the old narrowing, because a record pattern is not an expression; F5
%% recorded map destructuring as out of scope for exactly that reason. Taking a
%% `pattern` directly makes it fall out with no work.
var_makes_map_destructuring_reachable_test() ->
    Src = "module MD\n"
          "record Order { Id: int, Total: int }\n"
          "public int Total(Order o)\n"
          "Total(o) ->\n"
          "    var { Total: t } = o\n"
          "    t\n",
    M = build_and_load(Src, 'MD'),
    ?assertEqual(500, M:'Total'(#{'Kind' => 'MD.Order', 'Id' => 1, 'Total' => 500})).

%% F8.5 — THE CAPABILITY. A name in a pattern, marked, matches the value it
%% holds. Erlang has this for free because a bound variable in a pattern IS a
%% match; beam-sharp forbids rebinding and so had no way to say it at all.
a_marked_name_matches_the_value_it_holds_test() ->
    Src = "module RL\n"
          "public int Run(int head, list<int> xs)\n"
          "Run(head, [])                -> 0\n"
          "Run(head, [== head, ..rest]) -> 1 + Run(head, rest)\n"
          "Run(head, [_, ..rest])       -> 0\n",
    M = build_and_load(Src, 'RL'),
    ?assertEqual(3, M:'Run'(3, [3, 3, 3, 9, 3])),
    ?assertEqual(0, M:'Run'(9, [3, 3, 3])),
    ?assertEqual(0, M:'Run'(1, [])).

%% ...and it emits NO GUARD, because the target does the work. Asserted on the
%% abstract format rather than on behaviour, since a guard-based lowering would
%% pass the test above while costing what the comment claims it does not.
a_marked_name_emits_no_guard_test() ->
    Src = "module RG\n"
          "public int Run(int head, list<int> xs)\n"
          "Run(head, [])                -> 0\n"
          "Run(head, [== head, ..rest]) -> 1\n"
          "Run(head, [_, ..rest])       -> 0\n",
    _ = build_and_load(Src, 'RG'),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/RG.beam", [abstract_code]),
    [{function, _, 'Run', 2, Clauses}] =
        [F || F = {function, _, 'Run', 2, _} <- Forms],
    %% No COMPARISON in any clause guard...
    %%
    %% AMENDED BY F24 (ticket 58), 2026-08-23. This asserted `[[], [], []]` —
    %% that every guard was empty — which was a proxy for the claim F8 actually
    %% makes, and the proxy stopped holding for a reason that has nothing to do
    %% with F8. `head` is an exported parameter declared `int` and bound by a
    %% bare variable, so ticket 18 §1(b) now puts `is_integer/1` on it. That
    %% guard was always owed here and was never emitted; the case was in scope
    %% of a decided rule and simply never exercised.
    %%
    %% So the assertion is narrowed to what this test is about: the `== head`
    %% marker emits no comparison, because the repeated variable below IS the
    %% equality. A lowering that reintroduced an `=:=` still fails.
    Guards = [G || {clause, _, _, G, _} <- Clauses],
    ?assertEqual(3, length(Guards)),
    ?assertEqual([], [Op || G <- Guards, Op <- lists:flatten(G),
                            element(1, Op) =:= op]),
    %% ...and the matching clause names the SAME variable twice, which is the
    %% equality test itself.
    [_, {clause, _, [{var, _, V}, {cons, _, {var, _, V}, _}], _, _}, _] = Clauses,
    ?assertEqual('Head', V).

%% F8.7 — A MATCHED NAME DOES NOT POISON THE TYPES AROUND IT.
%%
%% `pattern_type/3` answers `term()` for `p_eqvar` rather than looking the name's
%% type up, and the argument for why that is enough was REASONED rather than
%% measured: `walk/5` intersects `Possible` with the running residual, which
%% comes from the DECLARED domain, so a body should read the declared type at
%% that position regardless. This test is that argument's discriminating check,
%% because an argument written into a source comment is still an argument.
%%
%% Two call sites do the work, and both would reject if the reasoning were wrong:
%% `Twice(head)` needs `head` to be `int`, and `Sum(head, rest)` needs the SIBLING
%% of the matched element — bound in the same pattern — to still be `list<int>`
%% rather than `term`. That sibling is the case F8.7 actually names.
a_matched_name_does_not_widen_its_neighbours_test() ->
    Src = "module N7\n"
          "public int Twice(int n)\n"
          "Twice(n) -> n * 2\n"
          "public int Sum(int head, list<int> xs)\n"
          "Sum(head, [])                -> 0\n"
          "Sum(head, [== head, ..rest]) -> Twice(head) + Sum(head, rest)\n"
          "Sum(head, [_, ..rest])       -> 0\n",
    M = build_and_load(Src, 'N7'),
    %% [3, 3, 9] with head 3: two elements match at Twice(3) = 6 each, then 9
    %% takes the catch-all and stops the walk. 12, not 6 — the first version of
    %% this assertion said 6 and the compiler was right.
    ?assertEqual(12, M:'Sum'(3, [3, 3, 9])),
    ?assertEqual(0, M:'Sum'(3, [])),
    %% Nothing matches, so the recursion never runs and no call site is exercised
    %% by luck.
    ?assertEqual(0, M:'Sum'(1, [3, 3])).

%% F8.6 — A MATCHED NAME CREDITS NOTHING TO `Certain`, and this asserts an error
%% the WRONG build omits.
%%
%% A build that credited the arm would accept this single clause as exhaustive
%% over `(int, int)` and get QUIETER, not louder. That is the shape of every
%% soundness defect this project has found — F5's vacuous containment, F6's hang,
%% F9's byte count — so the test has to be for the diagnostic's PRESENCE.
a_marked_name_credits_nothing_to_certain_test() ->
    Src = "module NC\npublic atom F(int acc, int m)\nF(acc, == acc) -> :same\n",
    ?assertMatch([{error, _, 'F', {inexhaustive, _, _}}], errors(Src)).

%% F8.10 — A REPEATED BARE NAME IN A HEAD IS AN ERROR, AND UNTIL 2026-08-16 IT
%% WAS A LIVE SOUNDNESS HOLE.
%%
%% `F(acc, acc) -> :same` as the only clause was accepted as EXHAUSTIVE over
%% `(int, int)`, and `F(1, 2)` crashed with `function_clause`: a function the
%% compiler proved total, crashing on a value of its declared input type.
%%
%% The checker read the second `acc` as a fresh variable covering the domain,
%% while the emitter wrote `_Acc` twice and Erlang's repeated-variable rule made
%% that a real equality test. So B# had pin-by-default in heads by accident, via
%% the emitter, with the checker unaware. The merge site is why it was invisible:
%% `pattern_row/2` folds the binding maps with `maps:merge/2`, which keeps the
%% rightmost silently — the same mechanism as `type_env/1`'s duplicate
%% declaration, one bug shape in two places.
a_repeated_bare_name_in_a_head_is_an_error_test() ->
    Src = "module RB\npublic atom F(int a, int b)\nF(acc, acc) -> :same\nF(_, _) -> :diff\n",
    ?assertMatch([{error, _, 'F', {repeated_in_head, acc}}],
                 [D || D <- errors(Src), element(1, D) =:= error]).

%% The same shape nested, since a head is not the only place two names meet.
a_repeated_bare_name_inside_a_pattern_is_an_error_test() ->
    Src = "module RN\npublic atom F((int, int) p)\nF((acc, acc)) -> :same\nF(_) -> :diff\n",
    ?assertMatch([{error, _, 'F', {repeated_in_head, acc}}],
                 [D || D <- errors(Src), element(1, D) =:= error]).

%% `== name` READS a name, so it must resolve. Caught here rather than reaching
%% erlc as `variable 'Acc' is unbound` against a file the author did not write.
%% Asserted by MEMBERSHIP rather than as the only error, because the clause is
%% also inexhaustive — `== acc` credits nothing to `Certain`, so a lone clause
%% cannot cover `int`. Both diagnostics are right and F8.6 is the second one
%% firing on its own account; demanding a single error would have made this test
%% a change detector for how many true things the compiler noticed.
a_marked_name_that_is_not_bound_is_an_error_test() ->
    Src = "module UB\npublic atom F(int m)\nF(== acc) -> :same\n",
    Errs = [D || D <- errors(Src), element(1, D) =:= error],
    ?assert(lists:member({error, 3, 'F', {unbound_variable, acc}}, Errs)).

%% --- helpers ----------------------------------------------------------------

catch_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    bs_parser:parse(Toks).

parse_message(Src) ->
    case catch_parse(Src) of
        {error, {_, bs_parser, Msg}} -> lists:flatten(Msg);
        Other -> lists:flatten(io_lib:format("~p", [Other]))
    end.
