%%% Scenarios: compiler/features/F14-pipe-and-valve.md
-module(pipe_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          escript/0, run_cli/1, with_src/3]).

%%% F14 — pipes pass values; valves short-circuit errors.

%% The escript exposes diagnostic prose and exit status.
cli(Src, Assert) ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("in.bs", Src,
                     fun(Path, Root) ->
                             Assert(run_cli("--src-root " ++ Root ++ " " ++ Path))
                     end)
    end.

res_src() ->
    "module Res\n"
    "type Res = int | (:error, atom)\n"
    "public Res Start(int n)\n"
    "Start(n) when n > 0  -> n\n"
    "Start(n) when n <= 0 -> (:error, :bad)\n".

%%% --- the pipe ---------------------------------------------------------------

%% F14.1 — the piped value becomes the first argument.
the_piped_value_becomes_the_first_argument_test() ->
    Src = "module P\n"
          "public int Add(int a, int b)\n"
          "Add(a, b) -> a + b\n"
          "public int Double(int n)\n"
          "Double(n) -> n |> Add(n)\n",
    M = build_and_load(Src, 'P'),
    ?assertEqual(8, M:'Double'(4)).

%% F14.2 — chains associate left; subtraction distinguishes the order.
a_chain_is_left_associative_test() ->
    Src = "module C\n"
          "public int Sub(int a, int b)\n"
          "Sub(a, b) -> a - b\n"
          "public int Run(int n)\n"
          "Run(n) -> n |> Sub(1) |> Sub(2) |> Sub(3)\n",
    M = build_and_load(Src, 'C'),
    %% Right association gives 102.
    ?assertEqual(94, M:'Run'(100)).

%% F14.5 — pipes bind below arithmetic and above bindings.
the_pipe_is_looser_than_arithmetic_test() ->
    Src = "module A\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int a, int b)\n"
          "Run(a, b) -> a + b |> Twice()\n",
    M = build_and_load(Src, 'A'),
    %% Binding tighter than addition gives 11.
    ?assertEqual(14, M:'Run'(3, 4)).

the_pipe_is_tighter_than_a_binding_test() ->
    Src = "module B\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) ->\n"
          "  var d = n |> Twice()\n"
          "  d + 1\n",
    M = build_and_load(Src, 'B'),
    ?assertEqual(11, M:'Run'(5)).

%% F14.4 — a bare name is a syntax error, observed through the CLI.
a_bare_name_after_the_pipe_is_a_syntax_error_test() ->
    Src = "module X\n"
          "public int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |> Twice\n",
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "syntax error") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%%% --- the valve --------------------------------------------------------------

%% F14.6–F14.7 — errors return unchanged without running later stages.
%% Either arithmetic stage raises if it receives the error tuple.
a_valve_short_circuits_on_the_error_member_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "private Res Confirm(int v)\n"
          "Confirm(v) -> v + 6\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge() |?> Confirm()\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(12, M:'Place'(3)),
    ?assertEqual({error, bad}, M:'Place'(-1)).

%% F14.8 — stages accept the type remaining after errors are removed.
a_stage_declared_over_the_narrowed_type_is_accepted_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

a_stage_that_accepts_only_the_error_member_is_refused_test() ->
    Src = res_src() ++
          "private Res Charge((:error, atom) v)\n"
          "Charge(v) -> (:error, :nope)\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    %% The residual must be `int`; any error alone cannot prove narrowing.
    [{error, _, 'Place', {arg_not_accepted, 'Charge', 1, Residual, _}}] =
        errors(Src),
    ?assertEqual("int", lists:flatten(bs_types:to_pattern(Residual))).

%% F14.9 — an infallible valve subject receives an error naming `|>`.
a_valve_over_a_value_that_cannot_fail_is_an_error_test() ->
    Src = "module W\n"
          "private int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |?> Twice()\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "cannot fail") =/= nomatch),
                     ?assert(string:find(Out, "Write |> instead") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%% Absence of the expanded union distinguishes `term` from its decomposition.
the_infallible_subject_prints_term_as_term_test() ->
    Src = "module W2\n"
          "type Row = (:ok, term, term)\n"
          "public term Run(Row r)\n"
          "Run(r) -> r |?> Shaped()\n"
          "private term Shaped(Row r)\n"
          "Shaped((:ok, cols, rows)) -> rows\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "(:ok, term, term)") =/= nomatch),
                     ?assertEqual(nomatch, string:find(Out, "atom | int"))
             end).

%% Generated switch arms must not produce user-facing warnings.
a_well_formed_valve_produces_no_diagnostics_at_all_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%% Nesting in an argument lowers the inner valve inside the outer value arm.
%% Reusing its binder turns a fresh binding into an Erlang match.
a_valve_nested_in_an_argument_gets_its_own_binder_test() ->
    Src = res_src() ++
          "private Res Add(int v, Res other)\n"
          "Add(v, (:error, e)) -> (:error, e)\n"
          "Add(v, o) when o > 0  -> v + o\n"
          "Add(v, o) when o <= 0 -> v + o\n"
          "public Res Nested(int a, int b)\n"
          "Nested(a, b) -> Start(a) |?> Add(Start(b) |?> Add(0))\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(7, M:'Nested'(3, 4)),
    ?assertEqual({error, bad}, M:'Nested'(3, -1)),
    ?assertEqual({error, bad}, M:'Nested'(-1, 4)).

a_parameter_read_only_inside_a_valve_stage_is_not_dropped_test() ->
    Src = res_src() ++
          "private Res Add(int v, int w)\n"
          "Add(v, w) -> v + w\n"
          "public Res Place(int n, int bonus)\n"
          "Place(n, bonus) -> Start(n) |?> Add(bonus)\n",
    M = build_and_load(Src, 'Res'),
    ?assertEqual(9, M:'Place'(4, 5)).

%%% --- the diagnosis ----------------------------------------------------------

%% F14.10 — diagnostics name the pipe line.
%% Separate lines distinguish the pipe location from the call location.
a_diagnostic_inside_a_piped_call_names_the_pipes_line_test() ->
    Src = "module L\n"
          "private int Twice(int v, int w)\n"
          "Twice(v, w) -> v * w\n"
          "public int Run(int n)\n"
          "Run(n) -> n |>\n"
          "  Twice(:oops)\n",
    %% Leave the column open: indentation does not change the blamed line.
    [{error, {5, _}, 'Run', _}] = errors(Src).
