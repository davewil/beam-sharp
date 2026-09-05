%%% `raise` — the producing half of the error model (ticket 12 §5, ticket 15 §3).
%%%
%%% ASSERTED AT THE BOUNDARY: source text in, a loaded `.beam` called, and the
%%% way the call FAILS compared. A deliberate crash has no return value to
%%% inspect, so the observable is the exception the BEAM raises — its class and
%%% its reason — which is exactly what ticket 12 §5 decided and nothing less.
%%%
%%% THE CLASS IS THE DECISION, NOT AN IMPLEMENTATION DETAIL. 12 §5 rejected
%%% C#'s `throw` on semantics: the BEAM already uses `throw` for the CATCHABLE
%%% non-local-return class, so a BEAM reader would read recoverable where the
%%% language means fatal. `a_raise_produces_the_error_class_test` is that
%%% sentence written as an assertion — it is the one test here that would still
%%% matter if every other line of this file were deleted.
%%%
%%% The two refusals (`raise` in a guard, `raise` as a name) are asserted
%%% through `check_only/1` rather than the CLI because both are decisions about
%%% where the word may appear, and the diagnostic tag is the stable surface.

-module(raise_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1]).

%%% ---------------------------------------------------------------------------
%%% Fixtures
%%% ---------------------------------------------------------------------------

%% Ticket 15 §3's own example, written at a ground instantiation because
%% polymorphic signatures are not built (ENG-295). The shape is the point: a
%% raised reason and a carried reason are the same kind of thing, so escalating
%% from the `result` channel to a crash is an ordinary clause and needs no `?`,
%% no `unwrap` primitive and no new construct.
unwrap_src() ->
    "module Raising\n"
    "type Fetched = int | (:error, atom)\n"
    "public int Unwrap(Fetched r)\n"
    "Unwrap((:error, e)) -> raise e\n"
    "Unwrap(v)           -> v\n".

%%% ---------------------------------------------------------------------------
%%% The class and the reason
%%% ---------------------------------------------------------------------------

%% Runs `F` and reports which of the BEAM's three exception classes came out,
%% because that is the distinction the feature was chosen on and `?assertError`
%% alone cannot see it: a `throw` that carried the same reason would satisfy an
%% assertion about the reason and violate the decision.
classify(F) ->
    try F() of
        V -> {value, V}
    catch
        Class:Reason -> {Class, Reason}
    end.

%% THE DECISION, IN ONE ASSERTION. `raise` produces the ERROR class — the one
%% that kills processes and that `function_clause` belongs to — and not `throw`
%% and not `exit` (12 §5, verified there against Elixir 1.19.5 in
%% `prototypes/12b_raise_classes.exs`).
a_raise_produces_the_error_class_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertEqual({error, bad_key},
                 classify(fun () -> M:'Unwrap'({error, bad_key}) end)).

%% The reason is data the function was handed, passed through untouched. `raise`
%% takes any term (15 §3), so nothing wraps, tags or normalises it on the way
%% out — a reason that arrived as an atom leaves as that atom.
a_raise_carries_its_reason_unchanged_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertError(bad_key, M:'Unwrap'({error, bad_key})).

%% 15 §3 recommends an atom or a tagged tuple, so the tuple case is not an
%% afterthought: it is half the recommended vocabulary, and it shares that
%% vocabulary with `result`'s `E`.
a_tagged_tuple_reason_arrives_whole_test() ->
    Src = "module Raising\n"
          "public int Reject(int code)\n"
          "Reject(code) -> raise (:bad_request, code)\n",
    M = build_and_load(Src, 'Raising'),
    ?assertError({bad_request, 400}, M:'Reject'(400)).

%%% ---------------------------------------------------------------------------
%%% The bottom type — `raise` type-checks wherever a value is declared
%%% ---------------------------------------------------------------------------

%% The other half of `unwrap_src`: the clause that returns still returns. Stated
%% separately from the crash because a build that made every clause raise would
%% pass the assertion above and be useless.
a_raising_clause_stands_beside_a_returning_one_test() ->
    M = build_and_load(unwrap_src(), 'Raising'),
    ?assertEqual(7, M:'Unwrap'(7)).

%% `raise` has type `none`, which is a subtype of every type (12 §4), so a
%% raising clause contributes NOTHING to the type its clauses justify. Without
%% this, F25's corrected-signature check would read the crash as a returned
%% value and demand the author widen `int` to admit it — the signature would be
%% a lie in the one place the language promises it is not.
%% Asserted as the EMPTY diagnostic list rather than as `{ok, _, _}`, because
%% the corrected-signature report is a warning in some shapes: a check that
%% only asked "did it compile" would pass while the compiler told the author to
%% widen `int` to admit a crash.
a_raising_clause_does_not_widen_the_declared_return_test() ->
    {ok, _, Diags} = check_only(unwrap_src()),
    ?assertEqual([], Diags).

%% A `switch` arm may raise while its siblings return, which is the property
%% ticket 12 §5 took from Gleam's `panic` (verified there on Gleam 1.18.1: it
%% compiles in a `case` arm whose siblings return `String`). The arm's type is
%% `none`, so the switch's type is the union of the OTHER arms alone.
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
%%%
%%% `raise` is the loosest thing in the operator table, so its operand runs to
%%% the end of the expression. Both tests below are written so that the WRONG
%%% parse is not a compile error but a different observable value — a program
%%% that raises the wrong reason. Asserting that the grammar has no conflicts
%%% would not have caught either: zero conflicts says the table is buildable,
%%% not that it is the table that was wanted.
%%% ---------------------------------------------------------------------------

%% `raise n + 1` is `raise (n + 1)`. Were `raise` to bind tighter it would be
%% `(raise n) + 1`, which raises `n` and never reaches the addition — so the
%% reason tells the two parses apart.
a_reason_extends_past_an_operator_test() ->
    Src = "module Raising\n"
          "public int Boom(int n)\n"
          "Boom(n) -> raise n + 1\n",
    M = build_and_load(Src, 'Raising'),
    ?assertError(6, M:'Boom'(5)).

%% The same question against the tightest thing in the table. `raise a switch
%% { … }` raises the switch's VALUE; the tighter parse, `(raise a) switch { … }`,
%% would raise `a` itself and discard the arms. Both parse, so only the reason
%% distinguishes them.
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
%%% Where the word may not appear
%%% ---------------------------------------------------------------------------

%% A guard shares the whole expression grammar, so `when raise :boom` parses.
%% Left alone it reaches the author as `illegal guard expression` from `erlc`,
%% against a file they did not write — the same fault `switch_in_guard` exists
%% to prevent, and the same shape of refusal.
a_raise_in_a_guard_is_refused_test() ->
    Src = "module Raising\n"
          "public int F(int x)\n"
          "F(x) when raise :boom -> x\n"
          "F(_)                  -> 0\n",
    ?assertMatch([{error, _, 'F', raise_in_guard} | _], errors(Src)).

%% `raise` is a keyword, not a prelude function (12 §5 settled that half on
%% read cost: a function would be lexically identical to a call, with its
%% signature in a different file and no single token that finds every crash
%% site). So it cannot also be a parameter name — the same consequence the
%% lexer already records for `and` and `or` under ticket 44.
%% The message is asserted, not just the failure: `{error, _}` alone would pass
%% if the fixture failed to parse for some unrelated reason, and then the test
%% would go on passing after the keyword was reverted.
a_raise_may_not_be_used_as_a_name_test() ->
    Src = "module Raising\n"
          "public int F(int raise)\n"
          "F(raise) -> raise\n",
    {error, {_Line, bs_parser, Message}} = catch_parse(Src),
    ?assert(string:find(lists:flatten(Message), "raise") =/= nomatch).

catch_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    bs_parser:parse(Toks).

%% The reason is an ordinary expression and is checked as one: `_` is not a
%% value anywhere else in the language and gains no exemption by being raised.
a_raised_reason_is_checked_like_any_expression_test() ->
    Src = "module Raising\n"
          "public int F(int x)\n"
          "F(_) -> raise _\n",
    ?assertMatch([{error, _, 'F', wildcard_as_value} | _], errors(Src)).
