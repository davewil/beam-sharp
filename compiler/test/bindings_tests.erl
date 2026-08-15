-module(bindings_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, count/2,
                          escript/0, run_cli/1, with_src/3]).

-define(OUT, "/tmp/bsc_eunit").

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
    "int Squared(Order o)\n"
    "Squared(o) ->\n"
    "    t = o.Total\n"
    "    t * t\n"
    "int Steps(int a, int b)\n"
    "Steps(a, b) ->\n"
    "    x = a + b\n"
    "    y = x * 2\n"
    "    y + 1\n"
    "Order Bump(Order o)\n"
    "Bump(o) ->\n"
    "    next = o.Total + 1\n"
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
          "int Down(int n, int acc)\n"
          "Down(n, acc) when n <= 0 -> acc\n"
          "Down(n, acc) when n > 0 ->\n"
          "    next = acc + n\n"
          "    Down(n - 1, next)\n",
    M = build_and_load(Src, 'Loop'),
    ?assertEqual(500500, M:'Down'(1000, 0)).

%% A name means one thing in a clause. There is no mutation to assign with.
rebinding_a_name_is_an_error_test() ->
    Src = "module E\nint F(int a)\nF(a) ->\n    t = 1\n    t = 2\n    t\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, t}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% ...including rebinding something the clause head already bound.
a_binding_may_not_shadow_a_parameter_test() ->
    Src = "module E\nint F(int a)\nF(a) ->\n    a = 1\n    a\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {rebinding, a}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% Caught here rather than by erlc against the emitted .abstr — a file the
%% author did not write. Ticket 33 is about whether a body is TYPED; this is a
%% name question and needs no types.
an_unbound_name_is_caught_before_erlc_test() ->
    Src = "module E\nint F(int a)\nF(a) ->\n    total * 2\n",
    {error, Diags} = check_only(Src),
    %% Line 3 is the clause, not line 4 where the name appears: the final
    %% expression carries no line of its own, so it is reported against the
    %% smallest span that is certainly right.
    ?assertMatch([{error, 3, 'F', {unbound_variable, total}}],
                 [D || D <- Diags, element(1, D) =:= error]).

%% A bound name nothing later mentions is legal and warning-free: naming a value
%% to say what it IS is a reason to write one.
an_unused_binding_compiles_without_a_warning_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = "module U\nint F(int a)\nF(a) ->\n    unused = a + 1\n    a\n",
            with_src("u.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "Warning"))
            end)
    end.

