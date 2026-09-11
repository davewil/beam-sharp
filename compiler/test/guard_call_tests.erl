%%% F41 — a call in a guard is refused in B#'s voice (ENG-256).
%%%
%%% Erlang admits only its guard BIFs in a guard, never a user function, and
%%% B# emits the Erlang Abstract Format, so the restriction is inherited
%%% (ticket 63 Q4). Until F41 the author learned this from the Erlang
%%% compiler's own report, relayed under a `compile:` prefix: no term, no tag,
%%% `'IsAdmin'/1` for a function B# spells `IsAdmin(int)`, and for
%%% `ValidateAs<T>` the compiler's mangled internal name. 63d measured the
%%% class as every call form the grammar admits into a guard; each has a test
%%% here because a refusal wired at one site has missed the others before —
%%% the switch arm is classified by a different walk than the clause head.
%%%
%%% Tested at the boundary: the checker's diagnostic list, the CLI's stderr,
%%% and the `--diagnostics term` channel that the raw text could never reach.

-module(guard_call_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [errors/1, build_and_load/2, with_src/3, place/3,
                          run_cli_split_result/1, built/0]).

%%% ---------------------------------------------------------------------------
%%% The programs
%%% ---------------------------------------------------------------------------

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

%%% ---------------------------------------------------------------------------
%%% F41.1-F41.6 — every call form in a guard is refused, by the checker
%%% ---------------------------------------------------------------------------

a_local_call_in_a_clause_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(local_call_src())).

%% The switch arm is walked by `arms/9`, not `clause_diags/4`. A refusal wired
%% only at the clause leaves this program leaking.
a_local_call_in_a_switch_arm_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(arm_call_src())).

a_foreign_call_to_a_non_guard_bif_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {foreign_call_in_guard, ':string.length'}} | _],
                 errors(foreign_non_bif_src())).

%% `bs_lower:pipe_into/3` rewrites `u |> IsAdmin()` to `IsAdmin(u)` in the
%% parser, so the checker sees the local call and the callee is named as the
%% author's own function, not as a pipe.
a_pipe_in_a_guard_is_refused_as_the_call_it_lowers_to_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'IsAdmin'}} | _],
                 errors(pipe_src())).

%% Before F41 this one leaked `bs@validate@1@r/1` — the compiler's own
%% mangled name for the instantiation — which is the worst of the six.
an_instantiation_call_in_a_guard_is_refused_test() ->
    ?assertMatch([{error, _, 'Check', {call_in_guard, 'ValidateAs'}} | _],
                 errors(inst_src())).

%% One error per guard: the refusal names the guard once and does not cascade
%% into a second diagnostic about the same line.
the_refusal_is_the_only_error_test() ->
    [{error, _, 'Check', {call_in_guard, 'IsAdmin'}}] = errors(local_call_src()).

%% A valve in a guard was never a leak: `bs_lower:valves/1` turns it into a
%% two-armed switch before the checker runs, and a switch in a guard is refused
%% (F7). The stage call sits inside that switch, so a call walk that descended
%% into refused nodes reported TWO errors for one guard — 63d's G05, once its
%% helper type-checked. The switch is the one error; the call inside it is not
%% a second mistake.
a_valve_in_a_guard_is_one_error_and_it_is_the_switch_test() ->
    Src = "module Valved\n"
          "public result<int, atom> Half(int u)\n"
          "Half(u) -> u\n"
          "public atom Check(int u)\n"
          "Check(u) when (u |?> Half()) == 1 -> :one\n"
          "Check(_)                          -> :other\n",
    ?assertMatch([{error, _, 'Check', switch_in_guard}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F41.7-F41.8 — what stays legal, and runs
%%% ---------------------------------------------------------------------------

%% `:erlang.byte_size` IS a BEAM guard BIF, so this is legal by the same
%% inheritance that refuses the rest. The plausible-but-wrong fix refuses every
%% foreign call in a guard; this program is the one it breaks.
a_foreign_guard_bif_in_a_guard_compiles_and_runs_test() ->
    ?assertMatch({ok, _, []}, bs_test_support:check_only(foreign_bif_src())),
    Mod = build_and_load(foreign_bif_src(), 'GateBif'),
    ?assertEqual(long, Mod:'Check'(<<"abcd">>)),
    ?assertEqual(short, Mod:'Check'(<<"ab">>)).

a_comparison_guard_still_compiles_and_runs_test() ->
    Mod = build_and_load(comparison_src(), 'GateCmp'),
    ?assertEqual(admin, Mod:'Check'(1)),
    ?assertEqual(ordinary, Mod:'Check'(2)).

%%% ---------------------------------------------------------------------------
%%% F41.9-F41.12 — the CLI: B#'s voice, and the term channel the raw text
%%% could never reach
%%% ---------------------------------------------------------------------------

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
            %% None of the Erlang compiler's report: not its prefix, not its
            %% arity notation, not its wording.
            ?assertEqual(nomatch, string:find(Err, "compile:")),
            ?assertEqual(nomatch, string:find(Err, "'IsAdmin'/1")),
            ?assertEqual(nomatch, string:find(Err, "illegal in guard"))
        end)
    end).

%% The qualified call needs the sibling module on disk, so it is asserted here
%% rather than through `errors/1`.
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

%% Point 1 of ENG-256: the raw text was in no term, so it could not reach a
%% consumer of `--diagnostics term`. The refusal now can, and carries the
%% callee as the author spelled it.
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
