%%% Scenarios: compiler/features/F34-raise.md
%%% Scenarios: compiler/features/F38-writable-bottom.md
%%% Refusals use diagnostics, CLI prose and parser messages; runtime tests
%%% compare exception classes and reasons.

-module(raise_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          with_src/3, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% Fixtures
%%% ---------------------------------------------------------------------------

unwrap_src() ->
    "module Raising\n"
    "type Fetched = int | (:error, atom)\n"
    "public int Unwrap(Fetched r)\n"
    "Unwrap((:error, e)) -> raise e\n"
    "Unwrap(v)           -> v\n".

%%% ---------------------------------------------------------------------------
%%% The class and the reason
%%% ---------------------------------------------------------------------------

%% Compare the class as well as the reason: a throw can carry the same term.
classify(F) ->
    try F() of
        V -> {value, V}
    catch
        Class:Reason -> {Class, Reason}
    end.

a_raise_produces_the_error_class_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertEqual({error, bad_key},
                 classify(fun () -> M:'Unwrap'({error, bad_key}) end)).

a_raise_carries_its_reason_unchanged_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertError(bad_key, M:'Unwrap'({error, bad_key})).

a_tagged_tuple_reason_arrives_whole_test() ->
    Src = "module Raising\n"
          "public int Reject(int code)\n"
          "Reject(code) -> raise (:bad_request, code)\n",
    M = build_and_load(Src, 'Raising'),
    ?assertError({bad_request, 400}, M:'Reject'(400)).

%%% ---------------------------------------------------------------------------
%%% The bottom type
%%% ---------------------------------------------------------------------------

%% The returning clause rules out an implementation that always raises.
a_raising_clause_stands_beside_a_returning_one_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertEqual(7, M:'Unwrap'(7)).

%% An empty diagnostic list also excludes a signature-widening warning.
a_raising_clause_does_not_widen_the_declared_return_test() ->
    {ok, _, Diags} = check_only(unwrap_src()),
    ?assertEqual([], Diags).

a_switch_arm_may_raise_beside_arms_that_return_test() ->
    Src = "module Raising\n"
          "public int Width(atom a)\n"
          "Width(a) -> a switch {\n"
          "    :narrow => 1,\n"
          "    :wide   => 2,\n"
          "    other   => raise (:unknown_width, other)\n"
          "}\n",
    M = build_and_load(Src, 'Raising'),
    ?assertEqual(2, M:'Width'(wide)),
    ?assertError({unknown_width, tall}, M:'Width'(tall)).

%%% ---------------------------------------------------------------------------
%%% How far the reason extends
%%% ---------------------------------------------------------------------------

%% A tighter parse raises `n` before the addition; the reason distinguishes it.
a_reason_extends_past_an_operator_test() ->
    Src = "module Raising\n"
          "public int Boom(int n)\n"
          "Boom(n) -> raise n + 1\n",
    M = build_and_load(Src, 'Raising'),
    ?assertError(6, M:'Boom'(5)).

%% A tighter parse raises `a` without evaluating the switch arms.
a_reason_extends_over_a_switch_test() ->
    Src = "module Raising\n"
          "public int Pick(atom a)\n"
          "Pick(a) -> raise a switch {\n"
          "    :x   => :chose_x,\n"
          "    else => else\n"
          "}\n",
    M = build_and_load(Src, 'Raising'),
    ?assertError(chose_x, M:'Pick'(x)),
    ?assertError(other, M:'Pick'(other)).

%%% ---------------------------------------------------------------------------
%%% Writable bottom type
%%% ---------------------------------------------------------------------------

reject_src() ->
    "module Rejecting\n"
    "public none Reject(term r)\n"
    "Reject(r) -> raise (:rejected, r)\n".

%% Calling the loaded function checks more than acceptance of its signature.
a_none_return_may_be_declared_and_the_function_runs_test() ->
    M = build_and_load(reject_src(), 'Rejecting'),
    ?assertError({rejected, 7}, M:'Reject'(7)).

%% A successful load and crash alone would not exclude a widening warning.
a_none_return_declares_without_a_diagnostic_test() ->
    {ok, _, Diags} = check_only(reject_src()),
    ?assertEqual([], Diags).

%% A returned value distinguishes `none` from `term`; both admit a raise.
a_none_return_refuses_a_returned_value_test() ->
    Src = "module Rejecting\n"
          "public none Reject(term r)\n"
          "Reject(r) -> r\n",
    ?assertMatch([{error, _, 'Reject', {return_not_declared, _, _}} | _],
                 errors(Src)).

%% The alias checks that the correction uses the resolved type, not its name.
a_none_behind_an_alias_is_still_the_bottom_test() ->
    Src = "module Rejecting\n"
          "type Never = none\n"
          "public Never Reject(term r)\n"
          "Reject(r) -> r\n",
    %% Read the suggested signature at the CLI, where the author reads it.
    Out = with_src("Rejecting.bs", Src,
                   fun(Path, Root) ->
                           run_cli("--src-root " ++ Root ++ " " ++ filename:dirname(Path))
                   end),
    ?assert(string:find(Out, "    public term Reject(term r)\n") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "Never |")).

%% The first clause raises; checking only that clause would miss the return.
a_returning_clause_beside_a_raising_one_is_still_refused_test() ->
    Src = "module Rejecting\n"
          "public none Reject(term r)\n"
          "Reject(:ok) -> raise :not_ok\n"
          "Reject(r)   -> r\n",
    ?assertMatch([{error, _, 'Reject', {return_not_declared, _, _}} | _],
                 errors(Src)).

%%% ---------------------------------------------------------------------------
%%% Where the word may not appear
%%% ---------------------------------------------------------------------------

%% The guard parses, so the compiler must reject it before erlc sees it.
a_raise_in_a_guard_is_refused_test() ->
    Src = "module Raising\n"
          "public int F(int x)\n"
          "F(x) when raise :boom -> x\n"
          "F(_)                  -> 0\n",
    ?assertMatch([{error, _, 'F', raise_in_guard} | _], errors(Src)).

%% Matching the keyword in the message excludes an unrelated parse failure.
a_raise_may_not_be_used_as_a_name_test() ->
    Src = "module Raising\n"
          "public int F(int raise)\n"
          "F(raise) -> raise\n",
    {error, {_Line, bs_parser, Message}} = catch_parse(Src),
    ?assert(string:find(lists:flatten(Message), "raise") =/= nomatch).

catch_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    bs_parser:parse(Toks).

a_raised_reason_is_checked_like_any_expression_test() ->
    Src = "module Raising\n"
          "public int F(int x)\n"
          "F(_) -> raise _\n",
    ?assertMatch([{error, _, 'F', wildcard_as_value} | _], errors(Src)).
