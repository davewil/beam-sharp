%%% Scenarios: compiler/features/F41-call-in-guard.md
%%% F41 — calls in guards receive B# diagnostics.
%%% Erlang permits only guard BIFs in guards; B# inherits that restriction.

-module(guard_call_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [errors/1, build_and_load/2, with_src/3, place/3,
                          run_cli_split_result/1, built/0]).

%%% Programs

local_call_src() ->
    "module Gate\n"
    "public atom IsAdmin(int u)\n"
    "IsAdmin(1) -> :yes\n"
    "IsAdmin(_) -> :no\n"
    "public atom Check(int u)\n"
    "Check(u) when IsAdmin(u) == :yes -> :admin\n"
    "Check(_)                         -> :ordinary\n".

arm_call_src() ->
    "module Gate\n"
    "public atom IsAdmin(int u)\n"
    "IsAdmin(1) -> :yes\n"
    "IsAdmin(_) -> :no\n"
    "public atom Check(int u)\n"
    "Check(u) -> u switch {\n"
    "    n when IsAdmin(n) == :yes => :admin,\n"
    "    _                         => :ordinary\n"
    "}\n".

foreign_non_bif_src() ->
    "module Gate\n"
    "using :string {\n"
    "    int length(binary s)\n"
    "}\n"
    "public atom Check(binary s)\n"
    "Check(s) when :string.length(s) > 2 -> :long\n"
    "Check(_)                            -> :short\n".

pipe_src() ->
    "module Gate\n"
    "public atom IsAdmin(int u)\n"
    "IsAdmin(1) -> :yes\n"
    "IsAdmin(_) -> :no\n"
    "public atom Check(int u)\n"
    "Check(u) when (u |> IsAdmin()) == :yes -> :admin\n"
    "Check(_)                               -> :ordinary\n".

inst_src() ->
    "module Gate\n"
    "public atom Check(term t)\n"
    "Check(t) when ValidateAs<int>(t) == (:ok, 1) -> :one\n"
    "Check(_)                                     -> :other\n".

foreign_bif_src() ->
    "module GateBif\n"
    "using :erlang {\n"
    "    int byte_size(binary b)\n"
    "}\n"
    "public atom Check(binary b)\n"
    "Check(b) when :erlang.byte_size(b) > 2 -> :long\n"
    "Check(_)                               -> :short\n".

comparison_src() ->
    "module GateCmp\n"
    "public atom Check(int u)\n"
    "Check(u) when u == 1 -> :admin\n"
    "Check(_)             -> :ordinary\n".

%%% F41.1–F41.6 — the checker refuses calls outside the guard BIF set.

a_local_call_in_a_clause_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(local_call_src())).

%% arms/10 checks switch guards separately from clause_diags/5.
%% A refusal wired only at the clause leaves the arm call unchecked.
a_local_call_in_a_switch_arm_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(arm_call_src())).

a_foreign_call_to_a_non_guard_bif_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {foreign_call_in_guard, ':string.length'}} | _],
                 errors(foreign_non_bif_src())).

%% Pipe lowering exposes IsAdmin as the callee to name in the diagnostic.
a_pipe_in_a_guard_is_refused_as_the_call_it_lowers_to_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(pipe_src())).

an_instantiation_call_in_a_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'ValidateAs'}} | _],
                 errors(inst_src())).

the_refusal_is_the_only_error_test() ->
    [{error, _, 'Check', {call_in_guard, 'IsAdmin'}}] = errors(local_call_src()).

%% A valve lowers to a switch. The switch refusal covers the nested call,
%% so that call must not produce a second error.
a_valve_in_a_guard_is_one_error_and_it_is_the_switch_test() ->
    Src = "module Valved\n"
          "public result<int, atom> Half(int u)\n"
          "Half(u) -> u\n"
          "public atom Check(int u)\n"
          "Check(u) when (u |?> Half()) == 1 -> :one\n"
          "Check(_)                          -> :other\n",
    ?assertMatch([{error, _, 'Check', switch_in_guard}], errors(Src)).

%%% F41.7–F41.8 — guard BIFs and comparisons compile and run.

%% byte_size is a guard BIF: rejecting every foreign call would reject it.
a_foreign_guard_bif_in_a_guard_compiles_and_runs_test() ->
    ?assertMatch({ok, _, []}, bs_test_support:check_only(foreign_bif_src())),
    Mod = build_and_load(foreign_bif_src(), 'GateBif'),
    ?assertEqual(long, Mod:'Check'(<<"abcd">>)),
    ?assertEqual(short, Mod:'Check'(<<"ab">>)).

a_comparison_guard_still_compiles_and_runs_test() ->
    Mod = build_and_load(comparison_src(), 'GateCmp'),
    ?assertEqual(admin, Mod:'Check'(1)),
    ?assertEqual(ordinary, Mod:'Check'(2)).

%%% F41.9–F41.12 — the CLI reports B# diagnostics as text and terms.

guarded(Fun) ->
    case built() of
        false -> ok;
        true  -> Fun()
    end.

the_author_reads_the_refusal_in_bsharp_test() ->
    guarded(fun() ->
        with_src("in.bs", local_call_src(), fun(Path, Root) ->
            {Rc, _, Err} = run_cli_split_result("--src-root " ++ Root ++ " " ++ Path),
            ?assertEqual(1, Rc),
            ?assertNotEqual(nomatch, string:find(Err, "error: Check calls IsAdmin in a guard")),
            ?assertNotEqual(nomatch, string:find(Err, "Move the call into the")),
            %% Exclude Erlang diagnostic wording and arity notation.
            ?assertEqual(nomatch, string:find(Err, "compile:")),
            ?assertEqual(nomatch, string:find(Err, "'IsAdmin'/1")),
            ?assertEqual(nomatch, string:find(Err, "illegal in guard"))
        end)
    end).

%% The qualified call needs a sibling module on disk, beyond errors/1.
a_qualified_call_in_a_guard_is_refused_test() ->
    guarded(fun() ->
        Helper = "module Gate.Helper\n"
                 "public atom IsAdmin(int u)\n"
                 "IsAdmin(1) -> :yes\n"
                 "IsAdmin(_) -> :no\n",
        Main = "module Gate\n"
               "public atom Check(int u)\n"
               "Check(u) when Helper.IsAdmin(u) == :yes -> :admin\n"
               "Check(_)                                -> :ordinary\n",
        with_src("in.bs", Main, fun(Path, Root) ->
            _ = place(Root, "helper.bs", Helper),
            {Rc, _, Err} = run_cli_split_result("--src-root " ++ Root ++ " " ++ Path),
            ?assertEqual(1, Rc),
            ?assertNotEqual(nomatch, string:find(Err, "error: Check calls Helper.IsAdmin in a guard")),
            ?assertEqual(nomatch, string:find(Err, "compile:")),
            ?assertEqual(nomatch, string:find(Err, "illegal guard expression"))
        end)
    end).

the_foreign_refusal_names_the_beam_guard_set_test() ->
    guarded(fun() ->
        with_src("in.bs", foreign_non_bif_src(), fun(Path, Root) ->
            {Rc, _, Err} = run_cli_split_result("--src-root " ++ Root ++ " " ++ Path),
            ?assertEqual(1, Rc),
            ?assertNotEqual(nomatch, string:find(Err, "error: Check calls :string.length in a guard")),
            ?assertNotEqual(nomatch, string:find(Err, "guard functions")),
            ?assertEqual(nomatch, string:find(Err, "compile:"))
        end)
    end).

the_refusal_is_a_term_test() ->
    guarded(fun() ->
        with_src("in.bs", local_call_src(), fun(Path, Root) ->
            {1, Out, _} = run_cli_split_result("--diagnostics term --src-root " ++
                                               Root ++ " " ++ Path),
            ?assertMatch(#{tag := call_in_guard, severity := error,
                           function := 'Check', callee := 'IsAdmin',
                           line := 6, column := 15},
                         parse_term(Out))
        end),
        with_src("in.bs", foreign_non_bif_src(), fun(Path, Root) ->
            {1, Out, _} = run_cli_split_result("--diagnostics term --src-root " ++
                                               Root ++ " " ++ Path),
            ?assertMatch(#{tag := foreign_call_in_guard, severity := error,
                           function := 'Check', callee := ':string.length'},
                         parse_term(Out))
        end)
    end).

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(string:trim(S) ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.
