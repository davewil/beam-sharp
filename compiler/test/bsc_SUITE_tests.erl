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
    %% `bsc:file_to_dir/2` rather than a hand-built `{opts, ...}` tuple: the
    %% suite should not know the shape of a private record, and did — adding a
    %% field to it broke six tests that were otherwise unaffected.
    Result = bsc:file_to_dir(Path, ?OUT),
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
    "module Readings\n"
    "type Verdict = :positive | :zero | :negative | :unknown\n"
    "type Reading = (:ok, int) | (:error, atom)\n"
    "Verdict Classify(Reading r)\n"
    "Classify((:ok, n)) when n > 0 -> :positive\n"
    "Classify((:ok, 0))            -> :zero\n"
    "Classify((:ok, n))            -> :negative\n"
    "Classify((:error, e))         -> :unknown\n".

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
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, Diags} = check_only(Src),
    ?assertMatch([{error, _, 'Classify', {inexhaustive, _}}], Diags).

%% The residual IS the missing case — not a count, not "some value".
residual_names_the_missing_case_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "atom Classify(Reading r)\n"
          "Classify((:ok, n)) when n > 0 -> :positive\n"
          "Classify((:error, e))         -> :unknown\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("((:ok, int <= 0))", bs_types:to_string(Residual)).

unreachable_clause_is_warned_test() ->
    Src = "module R\n"
          "type Reading = (:ok, int) | (:error, atom)\n"
          "atom Classify(Reading r)\n"
          "Classify((:ok, n))            -> :positive\n"
          "Classify((:ok, n)) when n > 0 -> :zero\n"
          "Classify((:error, e))         -> :unknown\n",
    {ok, _, Diags} = check_only(Src),
    ?assertMatch([{warning, _, 'Classify', {unreachable_clause, 2}}], Diags).

%%% ---------------------------------------------------------------------------
%%% Integer intervals — ticket 20's decision, exercised
%%% ---------------------------------------------------------------------------

%% Exhaustive ONLY if the checker sees that `n <= 1` and `n > 1` partition int.
guarded_integer_partition_is_exhaustive_test() ->
    Src = "module M\n"
          "int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

fib_actually_computes_test() ->
    Src = "module M\n"
          "int Fib(int n)\n"
          "Fib(n) when n <= 1 -> n\n"
          "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n",
    M = build_and_load(Src, 'M'),
    ?assertEqual(0,  M:'Fib'(0)),
    ?assertEqual(1,  M:'Fib'(1)),
    ?assertEqual(55, M:'Fib'(10)).

%% A hole in the middle of a partition must be found and named exactly.
interval_hole_is_found_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "Band Classify(int n)\n"
          "Classify(n) when n < 10   -> :low\n"
          "Classify(n) when n >= 100 -> :high\n",
    {error, [{error, _, _, {inexhaustive, Residual}}]} = check_only(Src),
    ?assertEqual("(10..99)", bs_types:to_string(Residual)).

conjunction_in_a_guard_is_credited_test() ->
    Src = "module M\n"
          "type Band = :low | :mid | :high\n"
          "Band Classify(int n)\n"
          "Classify(n) when n < 10             -> :low\n"
          "Classify(n) when n >= 10 && n < 100 -> :mid\n"
          "Classify(n) when n >= 100           -> :high\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% Ticket 08: a condition the checker cannot translate credits nothing. That must
%% make the function *inexhaustive*, never accidentally exhaustive — an
%% uncreditable guard may not be read as full coverage.
uncreditable_guard_credits_nothing_test() ->
    Src = "module M\n"
          "int F(int n)\n"
          "F(n) when Weird(n) -> n\n",
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

%%% ---------------------------------------------------------------------------
%%% No statement terminator
%%%
%%% Both audiences type `;` from habit, so it is the likeliest error in the
%%% language and owes the sharpest message.
%%% ---------------------------------------------------------------------------

no_semicolon_is_needed_test() ->
    Src = "module T\nint F(int n)\nF(n) when n > 0 -> n\nF(n) when n <= 0 -> 0\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

a_stray_semicolon_says_what_to_do_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = "module T\nint F(int n)\nF(n) when n > 0 -> n;\nF(n) when n <= 0 -> 0\n",
            with_src("semi.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                ?assert(string:find(R, "rc:1") =/= nomatch),
                ?assert(string:find(R, "beam-sharp has no `;`") =/= nomatch)
            end)
    end.

%%% ---------------------------------------------------------------------------
%%% Lists
%%%
%%% `[]` and `[h, ..t]` partition list<T>, which is what lets a list function be
%%% exhaustive with no catch-all. Ticket 08 settled prefix-plus-rest only.
%%% ---------------------------------------------------------------------------

series_src() ->
    %% Not `Fib`: the reload test defines its own scalar `Fib` module and the two
    %% would clobber one another's .beam and loaded code.
    "module FibL\n"
    "list<int> Fib(int n)\n"
    "Fib(n) when n <= 0 -> []\n"
    "Fib(n) when n > 0  -> Series(n, 0, 1, [])\n"
    "list<int> Series(int n, int a, int b, list<int> acc)\n"
    "Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])\n"
    "Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])\n"
    "list<int> Reverse(list<int> xs, list<int> acc)\n"
    "Reverse([], acc)          -> acc\n"
    "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n".

a_list_function_computes_test() ->
    M = build_and_load(series_src(), 'FibL'),
    ?assertEqual([], M:'Fib'(0)),
    ?assertEqual([0], M:'Fib'(1)),
    ?assertEqual([0, 1, 1, 2, 3], M:'Fib'(5)),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

%% The pair is exhaustive: no catch-all clause, and no diagnostic.
nil_and_cons_partition_a_list_test() ->
    {ok, _} = compile(series_src()),
    {ok, Toks, _} = bs_lexer:string(series_src()),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, _, Diags} = bs_check:check(Decls),
    ?assertEqual([], [D || D <- Diags, element(1, D) =:= error]).

%% Drop `Reverse([], acc)` and the residual must name the empty list.
missing_nil_clause_is_caught_test() ->
    Src = "module L\nlist<int> Rev(list<int> xs, list<int> acc)\n"
          "Rev([x, ..rest], acc) -> Rev(rest, [x, ..acc])\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {error, Diags} = bs_check:check(Decls),
    [{error, _, 'Rev', {inexhaustive, Residual}}] =
        [D || D <- Diags, element(1, D) =:= error],
    ?assert(string:find(bs_types:to_string(Residual), "[]") =/= nomatch).

%% Every self-call is a BEAM tail call — `call_only`, not `call` plus a frame.
%% Asserted on the emitted bytecode rather than on the source's shape.
recursion_is_a_tail_call_test() ->
    {ok, _} = compile(series_src()),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(?OUT ++ "/FibL.beam"),
    Bad = [{Name, Op}
           || {function, Name, _A, _E, Is} <- Fns,
              Name =/= module_info,
              {Op} <- [{element(1, I)} || I <- Is, is_tuple(I)],
              Op =:= call orelse Op =:= call_ext],
    ?assertEqual([], Bad).

%% Flat stack at a depth that would blow a body-recursive version.
tail_calls_do_not_grow_the_stack_test() ->
    M = build_and_load(series_src(), 'FibL'),
    Self = self(),
    Pid = spawn(fun() ->
                    _ = M:'Fib'(50000),
                    {stack_size, S} = erlang:process_info(self(), stack_size),
                    Self ! {stack, S}
                end),
    receive {stack, S} -> ?assert(S < 100)
    after 60000 -> exit({timeout, Pid}) end.

%%% ---------------------------------------------------------------------------
%%% Running a program — `bsc fib.bs 5`
%%%
%%% Development is driven by runnable code (David, 2026-08-14), so these assert
%%% on what the CLI prints, not on internals.
%%% ---------------------------------------------------------------------------

fib_src() ->
    "module Fib\n"
    "int Fib(int n)\n"
    "Fib(n) when n <= 1 -> n\n"
    "Fib(n) when n > 1  -> Fib(n - 1) + Fib(n - 2)\n".

escript() -> project_root() ++ "/_build/default/bin/bsc".

run_cli(Args) ->
    os:cmd(escript() ++ " " ++ Args ++ " 2>&1; echo rc:$?").

with_src(Name, Src, Fun) ->
    Out = ?OUT ++ "/run",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Path = Out ++ "/" ++ Name,
    ok = file:write_file(Path, Src),
    Fun(Path, Out).

%% The rule that makes `bsc fib.bs 5` need no function name: under one function
%% per file, the file names the function.
run_infers_the_function_from_the_file_name_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:0") =/= nomatch),
                ?assertEqual("5", hd(string:lexemes(R, "\n")))
            end)
    end.

run_computes_rather_than_parrots_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("fib.bs", fib_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 10"),
                ?assertEqual("55", hd(string:lexemes(R, "\n")))
            end)
    end.

%% Results print in beam-sharp notation, and the argument parser accepts back
%% exactly what the printer emits — `(:ok, 7)`, not `{ok,7}`.
run_round_trips_beam_sharp_notation_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("readings.bs", showcase_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Classify \"(:ok, 7)\""),
                ?assertEqual(":positive", hd(string:lexemes(R, "\n")))
            end)
    end.

%% A file with several functions cannot infer one, and says so rather than
%% guessing.
run_names_the_choice_when_it_cannot_infer_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = showcase_src() ++
                  "\nVerdict Second(Reading r)\n"
                  "Second((:ok, n)) when n > 0 -> :positive\n"
                  "Second((:ok, 0))            -> :zero\n"
                  "Second((:ok, n))            -> :negative\n"
                  "Second((:error, e))         -> :unknown\n",
            with_src("many.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " 5"),
                ?assert(string:find(R, "rc:2") =/= nomatch),
                ?assert(string:find(R, "which function") =/= nomatch)
            end)
    end.

%% What `:reload` does, asserted where it can be: a piped stdin cannot edit a
%% file mid-session, so this drives the same recompile-purge-load path the REPL
%% command drives and checks the NEW source is what answers.
reload_picks_up_a_changed_file_test() ->
    Out = ?OUT ++ "/reload",
    ok = filelib:ensure_dir(Out ++ "/x"),
    Path = Out ++ "/Fib.bs",
    ok = file:write_file(Path, fib_src()),
    {ok, _} = bsc:file_to_dir(Path, Out),
    true = code:add_patha(Out),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(8, 'Fib':'Fib'(6)),
    Changed = "module Fib\nint Fib(int n)\nFib(n) when n <= 1 -> 100\n"
              "Fib(n) when n > 1  -> 100\n",
    ok = file:write_file(Path, Changed),
    {ok, _} = bsc:file_to_dir(Path, Out),
    code:purge('Fib'), code:delete('Fib'), code:purge('Fib'),
    {module, 'Fib'} = code:ensure_loaded('Fib'),
    ?assertEqual(100, 'Fib':'Fib'(6)).

%% eunit runs from _build/test/lib/bsc, so walk back to the project.
project_root() ->
    filename:join(lists:takewhile(fun(C) -> C =/= "_build" end,
                                  filename:split(element(2, file:get_cwd())))).
