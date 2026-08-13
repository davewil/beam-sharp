%%% End-to-end tests for the walking skeleton.
%%%
%%% Tested at the boundary — source text in, a callable `.beam` out — rather than
%%% against the checker's internals, so a change to how the type algebra is
%%% represented does not break the suite. The one exception is the algebra's own
%%% laws, which have no boundary to be reached through.

-module(bsc_SUITE_tests).

-include_lib("eunit/include/eunit.hrl").

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

compile(Src) ->
    ok = filelib:ensure_dir(?OUT ++ "/x"),
    Path = ?OUT ++ "/in.bs",
    ok = file:write_file(Path, Src),
    Result = bsc:file(Path, {opts, ?OUT, true, false}),
    code:add_patha(?OUT),
    Result.

%% Compile, load, and hand back the module so a test can call into it.
build_and_load(Src, Mod) ->
    {ok, _} = compile(Src),
    code:purge(Mod),
    {module, Mod} = code:load_abs(?OUT ++ "/" ++ atom_to_list(Mod)),
    Mod.

check_only(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    bs_check:check(Decls).

%%% ---------------------------------------------------------------------------
%%% The showcase: N clauses in, N native clause heads out
%%% ---------------------------------------------------------------------------

showcase_src() ->
    "module Readings;\n"
    "type Verdict = :positive | :zero | :negative | :unknown;\n"
    "type Reading = (:ok, int) | (:error, atom);\n"
    "Verdict Classify(Reading r);\n"
    "Classify((:ok, n)) when n > 0 -> :positive;\n"
    "Classify((:ok, 0))            -> :zero;\n"
    "Classify((:ok, n))            -> :negative;\n"
    "Classify((:error, e))         -> :unknown;\n".

showcase_runs_test() ->
    M = build_and_load(showcase_src(), 'Readings'),
    ?assertEqual(positive, M:'Classify'({ok, 5})),
    ?assertEqual(zero,     M:'Classify'({ok, 0})),
    ?assertEqual(negative, M:'Classify'({ok, -3})),
    ?assertEqual(unknown,  M:'Classify'({error, timeout})).

%% Ticket 01's finding, now produced by a compiler rather than by hand.
four_clauses_become_four_clause_heads_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    [{function, _, 'Classify', 1, Clauses}] =
        [F || F = {function, _, _, _, _} <- Forms],
    ?assertEqual(4, length(Clauses)).

%% Ticket 13: a -spec is emitted for every function whose type is known.
spec_is_emitted_test() ->
    {ok, _} = compile(showcase_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Readings.beam", [abstract_code]),
    Specs = [F || F = {attribute, _, spec, _} <- Forms],
    ?assertMatch([_], Specs),
    Printed = lists:flatten(erl_pp:attribute(hd(Specs))),
    %% Precise, not widened to term(): the union survives into the emitted spec.
    ?assert(string:find(Printed, "{ok, integer()}") =/= nomatch),
    ?assert(string:find(Printed, "{error, atom()}") =/= nomatch).

%% Ticket 12: the failure arm is retained, so a foreign term crashes honestly
%% rather than returning a wrong answer. Ticket 13 found `erlc` inserts it on
%% this target and it cannot be suppressed, so this asserts the platform's
%% behaviour is what the decision assumed.
foreign_term_crashes_rather_than_lying_test() ->
    M = build_and_load(showcase_src(), 'Readings'),
    ?assertError(function_clause, M:'Classify'(not_a_reading)).

%%% ---------------------------------------------------------------------------
%%% Exhaustiveness — ticket 04's mechanism
%%% ---------------------------------------------------------------------------

inexhaustive_is_rejected_test() ->
    Src = "module R;\n"
          "type Reading = (:ok, int) | (:error, atom);\n"
          "atom Classify(Reading r);\n"
          "Classify((:ok, n)) when n > 0 -> :positive;\n"
          "Classify((:error, e))         -> :unknown;\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _}}], Diags).

%% The residual IS the missing case — not a count, not "some value".
residual_names_the_missing_case_test() ->
    Src = "module R;\n"
          "type Reading = (:ok, int) | (:error, atom);\n"
          "atom Classify(Reading r);\n"
          "Classify((:ok, n)) when n > 0 -> :positive;\n"
          "Classify((:error, e))         -> :unknown;\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("((:ok, int <= 0))", bs_types:to_string(Residual)).

unreachable_clause_is_warned_test() ->
    Src = "module R;\n"
          "type Reading = (:ok, int) | (:error, atom);\n"
          "atom Classify(Reading r);\n"
          "Classify((:ok, n))            -> :positive;\n"
          "Classify((:ok, n)) when n > 0 -> :zero;\n"
          "Classify((:error, e))         -> :unknown;\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Classify', {unreachable_clause, 2}}], Diags).

%%% ---------------------------------------------------------------------------
%%% Integer intervals — ticket 20's decision, exercised
%%% ---------------------------------------------------------------------------

%% Exhaustive ONLY if the checker sees that `n <= 1` and `n > 1` partition int.
guarded_integer_partition_is_exhaustive_test() ->
    Src = "module M;\n"
          "int Fib(int n);\n"
          "Fib(n) when n <= 1 -> n;\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2);\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

fib_actually_computes_test() ->
    Src = "module M;\n"
          "int Fib(int n);\n"
          "Fib(n) when n <= 1 -> n;\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2);\n",
    M = build_and_load(Src, 'M'),
    ?assertEqual(0,  M:'Fib'(0)),
    ?assertEqual(1,  M:'Fib'(1)),
    ?assertEqual(55, M:'Fib'(10)).

%% A hole in the middle of a partition must be found and named exactly.
interval_hole_is_found_test() ->
    Src = "module M;\n"
          "type Band = :low | :mid | :high;\n"
          "Band Classify(int n);\n"
          "Classify(n) when n < 10   -> :low;\n"
          "Classify(n) when n >= 100 -> :high;\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("(10..99)", bs_types:to_string(Residual)).

conjunction_in_a_guard_is_credited_test() ->
    Src = "module M;\n"
          "type Band = :low | :mid | :high;\n"
          "Band Classify(int n);\n"
          "Classify(n) when n < 10             -> :low;\n"
          "Classify(n) when n >= 10 && n < 100 -> :mid;\n"
          "Classify(n) when n >= 100           -> :high;\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% Ticket 08: a condition the checker cannot translate credits nothing. That must
%% make the function *inexhaustive*, never accidentally exhaustive — an
%% uncreditable guard may not be read as full coverage.
uncreditable_guard_credits_nothing_test() ->
    Src = "module M;\n"
          "int F(int n);\n"
          "F(n) when Weird(n) -> n;\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'F', {inexhaustive, _}}], Diags).

%%% ---------------------------------------------------------------------------
%%% The algebra's own laws — no boundary reaches these
%%% ---------------------------------------------------------------------------

%% The precise failures measured against erl_types in prototype 20c.
interval_subtraction_is_exact_test() ->
    A = bs_types:range(1, 1000),
    B = bs_types:range(500, 2000),
    ?assertEqual("1..499", bs_types:to_string(bs_types:subtract(A, B))),
    ?assertNot(bs_types:is_none(bs_types:subtract(A, B))).

interval_subtyping_is_not_symmetric_test() ->
    Gt5 = bs_types:range(6, pos_inf),
    Gt0 = bs_types:range(1, pos_inf),
    ?assert(bs_types:is_subtype(Gt5, Gt0)),
    ?assertNot(bs_types:is_subtype(Gt0, Gt5)).

%% Ticket 20: the union does not widen. Two exact members stay two members, and
%% subtracting both empties the residual.
union_is_exact_test() ->
    A = bs_types:range(32, 32),
    B = bs_types:range(64, 64),
    U = bs_types:union(A, B),
    ?assertNot(bs_types:is_subtype(bs_types:range(96, 96), U)),
    ?assert(bs_types:is_none(bs_types:subtract(bs_types:subtract(U, A), B))).

%% Ticket 10: the atom universe is open, so `atom` is cofinite and the complement
%% of a singleton has to be representable.
cofinite_atoms_test() ->
    Rest = bs_types:subtract(bs_types:atom_top(), bs_types:atom_lit(ok)),
    ?assertNot(bs_types:is_none(Rest)),
    ?assert(bs_types:is_none(bs_types:intersect(Rest, bs_types:atom_lit(ok)))),
    ?assert(bs_types:is_subtype(bs_types:atom_lit(other), Rest)).

%% Componentwise subtraction would be wrong; the product decomposition is not.
tuple_subtraction_decomposes_test() ->
    Ok = bs_types:atom_lit(ok),
    Err = bs_types:atom_lit(error),
    T = bs_types:union(bs_types:tuple([Ok, bs_types:int()]),
                       bs_types:tuple([Err, bs_types:atom_top()])),
    R = bs_types:subtract(T, bs_types:tuple([Ok, bs_types:int()])),
    ?assertEqual("(:error, atom)", bs_types:to_string(R)),
    ?assert(bs_types:is_none(bs_types:subtract(R, bs_types:tuple([Err, bs_types:atom_top()])))).

%%% ---------------------------------------------------------------------------
%%% The built escript
%%%
%%% `escript_emu_args` named a module that does not exist (`bsc_cli`), so the
%%% README's documented quickstart died with `undefined function bsc_cli:main/1`
%%% while every test above passed — because none of them executed the artefact
%%% users are told to run. Found by a teammate building the OTP corpus, who had
%%% to route around it.
%%%
%%% Two tests: one that reads the config and needs no build, so it fails wherever
%%% it is run; one that executes the escript when it has been built.
%%% ---------------------------------------------------------------------------

escript_entry_point_exists_test() ->
    {ok, Terms} = file:consult(project_root() ++ "/rebar.config"),
    Args = proplists:get_value(escript_emu_args, Terms),
    ?assertNotEqual(undefined, Args),
    %% "%%! -escript main bsc\n" -> bsc
    [_, "-escript", "main", ModStr | _] = string:lexemes(Args, " \n"),
    Mod = list_to_atom(ModStr),
    ?assertMatch({module, Mod}, code:ensure_loaded(Mod)),
    ?assert(erlang:function_exported(Mod, main, 1)).

built_escript_compiles_a_file_test() ->
    Escript = project_root() ++ "/_build/default/bin/bsc",
    case filelib:is_regular(Escript) of
        false ->
            %% Nothing built; the config test above still guards the regression.
            ok;
        true ->
            Out = ?OUT ++ "/escript",
            ok = filelib:ensure_dir(Out ++ "/x"),
            Src = Out ++ "/in.bs",
            ok = file:write_file(Src, showcase_src()),
            Result = os:cmd(Escript ++ " -o " ++ Out ++ " " ++ Src ++ " 2>&1; echo rc:$?"),
            ?assert(string:find(Result, "rc:0") =/= nomatch),
            ?assert(filelib:is_regular(Out ++ "/Readings.beam"))
    end.

%% eunit runs from _build/test/lib/bsc, so walk back to the project.
project_root() ->
    filename:join(lists:takewhile(fun(C) -> C =/= "_build" end,
                                  filename:split(element(2, file:get_cwd())))).
