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
%%% Behaviours
%%% ---------------------------------------------------------------------------

counter_src() ->
    "module Counter\n"
    "behaviour GenServer\n"
    "type Request = :get | (:add, int)\n"
    "type Reply = (:reply, int, int)\n"
    "Reply HandleCall(Request request, term from, int state)\n"
    "HandleCall(:get, from, state)      -> (:reply, state, state)\n"
    "HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)\n".

behaviour_decl_emits_the_attribute_test() ->
    {ok, _} = compile(counter_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Counter.beam", [abstract_code]),
    ?assert(lists:member({attribute, 0, behaviour, gen_server},
                         [F || F = {attribute, _, behaviour, _} <- Forms])).

%% Two clauses cover `:get | (:add, int)` with no catch-all.
a_behaviour_callback_is_checked_exhaustive_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

a_behaviour_callback_runs_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    ?assertEqual({reply, 5, 5},   M:'HandleCall'(get, self(), 5)),
    ?assertEqual({reply, 12, 12}, M:'HandleCall'({add, 7}, self(), 5)).

%% `term` contains every tuple. Without a tuple top, a tuple pattern over a
%% `term` parameter was reported unreachable — which made the OTP callback shape
%% unwritable, since `handle_cast` and `handle_info` both take one.
a_tuple_pattern_over_term_is_reachable_test() ->
    Src = "module T\natom F(term x)\nF((:add, n)) -> :tuple\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% ...and a catch-all still removes every tuple, so this stays exhaustive.
a_catch_all_still_covers_every_tuple_test() ->
    Src = "module T\natom F(term x)\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% Calling Erlang
%%%
%%% The module is an atom, so the call site is Elixir's and nothing is renamed.
%%% ---------------------------------------------------------------------------

interop_src() ->
    "module Interop\n"
    "using :lists {\n"
    "    int sum(list<int> xs)\n"
    "    list<int> reverse(list<int> xs)\n"
    "}\n"
    "int Total(list<int> xs)\n"
    "Total(xs) -> :lists.sum(xs)\n"
    "list<int> Backwards(list<int> xs)\n"
    "Backwards(xs) -> :lists.reverse(xs)\n".

a_foreign_call_runs_test() ->
    M = build_and_load(interop_src(), 'Interop'),
    ?assertEqual(10, M:'Total'([1, 2, 3, 4])),
    ?assertEqual([3, 2, 1], M:'Backwards'([1, 2, 3])).

%% A `using` block is a declaration, not an unfinished function: it must not be
%% reported as a signature with no clauses.
a_foreign_block_is_not_a_stub_test() ->
    ?assertMatch({ok, _, []}, check_only(interop_src())).

%% It emits an ordinary BEAM remote call.
a_foreign_call_is_a_remote_call_test() ->
    {ok, _} = compile(interop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Interop.beam", [abstract_code]),
    Remotes = [{M, F} || {function, _, _, _, Cs} <- Forms,
                         {clause, _, _, _, Body} <- Cs,
                         {call, _, {remote, _, {atom, _, M}, {atom, _, F}}, _} <- Body],
    ?assert(lists:member({lists, sum}, Remotes)),
    ?assert(lists:member({lists, reverse}, Remotes)).

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

%%% ---------------------------------------------------------------------------
%%% F3 — records. Scenario ids are the feature file's, so a failure names the
%%% thing it was built to satisfy.
%%%
%%% Every claim here is routed through EXHAUSTIVENESS or through the emitted
%%% term, because `bs_check` never visits a function body — F3 §2. Three
%%% scenarios the feature reserves ids for (F3.3's call-site rejection, F3.8's
%%% projection error, F3.10's exact construction) are deferred with it and are
%%% NOT asserted below; a test claiming them would be testing a check site that
%%% does not exist.
%%% ---------------------------------------------------------------------------

shop_src() ->
    "module Shop\n"
    "record Order { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "type Doc = Order | Invoice\n"
    "Order Draft()\n"
    "Draft() -> Order { Id = 1, Total = 0 }\n"
    "Order Pay(Order o)\n"
    "Pay(o) -> o with { Total = 500 }\n"
    "int Amount(Order o)\n"
    "Amount(o) -> o.Total\n"
    "int Either(Doc d)\n"
    "Either(d) -> d.Total\n"
    "atom Which(Doc)\n"
    "Which({ Kind: :'Shop.Order' }) -> :order\n"
    "Which({ Kind: :'Shop.Invoice' }) -> :invoice\n"
    "int Total(int n)\n"
    "Total(n) -> n + 1\n".

an_order() -> #{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 0}.

shop_forms() ->
    {ok, _} = compile(shop_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Shop.beam", [abstract_code]),
    Forms.

%% How many times does an atom appear anywhere in a nested term?
count(Atom, Atom) -> 1;
count(T, Atom) when is_tuple(T) -> count(tuple_to_list(T), Atom);
count(L, Atom) when is_list(L) -> lists:sum([count(E, Atom) || E <- L]);
count(_, _) -> 0.

%% F3.1 — the term is a tagged map, and the tag mints from the QUALIFIED name.
a_record_constructs_a_tagged_map_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(an_order(), M:'Draft'()).

%% F3.2 — §1's own test that the minting is not nominality. Routed through
%% exhaustiveness: if the mint created an identity, `Either` would be a union of
%% two things and one clause would leave a residual.
a_hand_written_type_with_the_same_tag_is_the_same_type_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "type Spelled = { Kind: :'Shop.Order', Id: int, Total: int }\n"
          "type Either = Order | Spelled\n"
          "atom Which(Either)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F3.3 — identical field sets, different tags, two types. Under ticket 09
%% before the minting this WOULD have been exhaustive, which is the whole point.
two_records_over_identical_field_sets_are_two_types_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "atom Which(Doc)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    ?assertMatch({error, _}, check_only(Src)).

%% F3.4 — the residual synthesises the head you must write. Ticket 23: a head
%% derived from the residual cannot be wrong, and the discriminator is the whole
%% head — printing the full field set would paste `int` in as a VARIABLE name.
the_residual_over_records_synthesises_the_missing_head_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "atom Which(Doc)\n"
          "Which({ Kind: :'Shop.Order' }) -> :order\n",
    {error, Diags} = check_only(Src),
    [{error, _, 'Which', {inexhaustive, Residual}}] =
        [D || D <- Diags, element(1, D) =:= error],
    %% The residual's tuple part is the ARGUMENT LIST, so the head is built from
    %% its components — the same unpacking `bsc:heads/2` does to print it.
    #{tuples := [[Arg]]} = Residual,
    ?assertEqual("{ Kind: :'Shop.Invoice' }", bs_types:to_pattern(Arg)).

%% ...and pasting it in compiles clean, which is the half that makes it useful.
%%
%% The head is taken from the FAILING RUN and spliced in, rather than written
%% out here. Transcribing it would test that a head someone already knows works
%% works, which is adjacent to the claim: what F3.4 asserts is that the string
%% the compiler *emits* is something you can paste. Ticket 23 — the compiler
%% synthesises the head and a head derived from the residual cannot be wrong —
%% is only worth anything if that is checked rather than assumed.
the_synthesised_head_compiles_when_pasted_in_test() ->
    Base = "module Shop\n"
           "record Order { Id: int, Total: int }\n"
           "record Invoice { Id: int, Total: int }\n"
           "type Doc = Order | Invoice\n"
           "atom Which(Doc)\n"
           "Which({ Kind: :'Shop.Order' }) -> :order\n",
    {error, Diags} = check_only(Base),
    [{error, _, 'Which', {inexhaustive, Residual}}] =
        [D || D <- Diags, element(1, D) =:= error],
    #{tuples := [[Arg]]} = Residual,
    Synthesised = "Which(" ++ bs_types:to_pattern(Arg) ++ ") -> :invoice\n",
    M = build_and_load(Base ++ Synthesised, 'Shop'),
    ?assertEqual(invoice, M:'Which'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    ?assertEqual(order, M:'Which'(an_order())).

%% F3.5 — `with` is width-preserving and the tag survives it. §2's sentence,
%% which is what pays ticket 27 §7's debt rather than reopening row polymorphism.
with_is_width_preserving_and_keeps_the_tag_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(#{'Kind' => 'Shop.Order', 'Id' => 1, 'Total' => 500},
                 M:'Pay'(an_order())).

%% ...and it cannot WIDEN, because `:=` raises rather than adding a key. That is
%% the mechanism behind §5 closing row polymorphism rather than deferring it.
with_cannot_add_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Grow(Order o)\n"
          "Grow(o) -> o with { Extra = 1 }\n",
    M = build_and_load(Src, 'Shop'),
    ?assertError({badkey, 'Extra'}, M:'Grow'(an_order())).

%% F3.6 — spread is not in the language. §2 refused it on a specific ground, so
%% the refusal gets a test rather than being an omission.
spread_is_not_in_the_language_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Grow(Order o)\n"
          "Grow(o) -> { ..o, Extra = 1 }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    ?assertMatch({error, _}, bs_parser:parse(Toks)).

%% F3.7 — the dot projects and is never a call, and the disambiguation is
%% LEXICAL: a lowercase receiver is a value. So a field and a function may share
%% a name, told apart by syntax rather than by resolution.
the_dot_projects_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Amount'(an_order())),
    ?assertEqual(8, M:'Total'(7)).

%% Counted in the BODY, because the guard has a `map_get` of its own — F3.9's
%% tag test. Two map_gets on this function is the correct number and they are
%% two different obligations; conflating them is what the split asserts against.
the_dot_emits_one_map_get_test() ->
    [{function, _, 'Amount', 1, [{clause, _, _, _Guards, Body}]}] =
        [F || F = {function, _, 'Amount', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Body, map_get)).

%% F3.8 — projection over a union is legal where every member carries the field,
%% and emits ONE map_get whichever member arrived. §3: the map erasure paid for
%% this without knowing it — under the tuple erasure §1 rejected, the field sits
%% at a different offset per member and this would need real dispatch.
union_projection_emits_one_map_get_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertEqual(0, M:'Either'(an_order())),
    ?assertEqual(9, M:'Either'(#{'Kind' => 'Shop.Invoice', 'Id' => 2, 'Total' => 9})),
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    ?assertEqual(1, count(Either, map_get)).

%% F3.9 — an exported record parameter's guard is ONE tag test and no more.
%% Ticket 26 §1's two-tier allocation: the tag test is unconditional because a
%% body projects fields and so can never object to the tag; the exact-set test
%% is second tier and belongs where a codegen obligation consumes the record,
%% and none exists yet — so its absence is the correct observation, not a gap.
an_exported_record_parameter_gets_one_tag_test_test() ->
    Forms = shop_forms(),
    [{function, _, 'Pay', 1, [{clause, _, _, Guards, _}]}] =
        [F || F = {function, _, 'Pay', 1, _} <- Forms],
    ?assertEqual(1, count(Guards, map_get)),
    %% No exact-field-set test — that is the second tier.
    ?assertEqual(0, count(Guards, has_map_fields) + count(Guards, map_size)).

%% The guard actually fires: a map wearing the wrong tag does not get in.
the_tag_test_rejects_a_foreign_term_test() ->
    M = build_and_load(shop_src(), 'Shop'),
    ?assertError(function_clause,
                 M:'Pay'(#{'Kind' => 'Shop.Invoice', 'Id' => 1, 'Total' => 0})).

%% A union parameter gets NO tag test — a disjunction over tags is a different
%% shape from the one F3.9 specifies. A deliberate narrowing, pinned so that
%% widening it later is a decision rather than a surprise.
a_union_parameter_gets_no_tag_test_test() ->
    [Either] = [F || F = {function, _, 'Either', 1, _} <- shop_forms()],
    {function, _, _, _, [{clause, _, _, Guards, _}]} = Either,
    ?assertEqual([], Guards).

%% F3.11 — there are no absent fields (§4). The kept form is
%% `Notes: option<int>`, which needs the angle brackets F4 has not landed, so
%% the diagnostic says what the language lacks rather than naming a spelling
%% that cannot yet parse.
there_is_no_optional_field_modifier_test() ->
    Src = "module Shop\nrecord Profile { Id: int, Notes?: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "no optional fields") =/= nomatch).

%% F3.12 — the emitted spec is a precise map type, not `map()` and not `any()`.
the_emitted_spec_is_a_precise_map_test() ->
    Forms = shop_forms(),
    [Spec] = [S || S = {attribute, _, spec, {{'Draft', 0}, _}} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "'Kind' := 'Shop.Order'") =/= nomatch),
    ?assert(string:find(Printed, "'Total' := integer()") =/= nomatch),
    ?assertEqual(nomatch, string:find(Printed, "map()")).

%% The tag is minted, so a record may not declare its own `Kind`. Erroring at
%% the DECLARATION rather than at a use is ticket 15's collapse rule again.
a_declared_kind_field_is_an_error_test() ->
    Src = "module Shop\nrecord Order { Kind: int, Total: int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertError({kind_field_is_minted, _, 'Order'}, bs_check:check(Decls)).

%% `Id:int` lexes `:int` as an atom, because longest-match prefers the sigil.
%% The parser catches the shape by name rather than letting it surface as an
%% opaque syntax error.
a_field_without_a_space_says_what_to_do_test() ->
    Src = "module Shop\nrecord Order { Id:int }\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Message}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Message), "lexes as an atom") =/= nomatch).

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

%%% ---------------------------------------------------------------------------
%%% The reader's diagnostics.
%%%
%%% Every case below is one David actually typed at the prompt on 2026-08-14.
%%% The reader used to answer all of them with `expected a call, e.g. Fib(5)` or,
%%% worse, by silently turning the text into a BINARY and letting it crash inside
%%% the function — `{badmap, <<"Order{Id = 1}">>}`, which shows a person their own
%%% source inside an error about a map. Ticket 23's rule is that the compiler
%%% hands you the thing to write, and the prompt is where that matters most.
%%% ---------------------------------------------------------------------------

%% Construction is not available in an argument: arguments are values.
an_unreadable_argument_says_what_it_could_not_read_test() ->
    {error, Msg} = bs_run:read_arg("Order{Id = 1, Total = 0}"),
    Flat = lists:flatten(Msg),
    ?assert(string:find(Flat, "Order{Id = 1, Total = 0}") =/= nomatch),
    ?assert(string:find(Flat, "record construction is not available") =/= nomatch).

%% ...and neither is a nested call.
a_call_in_an_argument_is_named_as_such_test() ->
    {error, Msg} = bs_run:read_arg("Pay(x)"),
    ?assert(string:find(lists:flatten(Msg), "arguments are values, not calls")
            =/= nomatch).

%% The record value itself still reads, and reads back to what the printer emits.
a_record_value_round_trips_through_the_reader_test() ->
    ?assertEqual({ok, an_order()},
                 bs_run:read_arg("{Kind = :'Shop.Order', Id = 1, Total = 0}")),
    ?assertEqual("{Kind = :'Shop.Order', Id = 1, Total = 0}",
                 lists:flatten(bs_run:format_value(an_order()))).

%% A name the REPL has bound resolves at any DEPTH, not only as a whole
%% argument. Without this the inner `t` fell through to the Erlang reader and
%% came back as the atom `t`, failing arithmetic three frames later — the same
%% silent-wrong-value shape as the binary fallback.
a_bound_name_resolves_inside_a_literal_test() ->
    Env = #{"t" => 9},
    ?assertEqual({ok, 9}, bs_run:read_arg("t", Env)),
    ?assertEqual({ok, #{'Kind' => 'Shop.Order', 'Total' => 9}},
                 bs_run:read_arg("{Kind = :'Shop.Order', Total = t}", Env)),
    ?assertEqual({ok, [1, 9]}, bs_run:read_arg("[1, t]", Env)),
    ?assertEqual({ok, {9, 2}}, bs_run:read_arg("(t, 2)", Env)).

%% ...and an empty environment behaves exactly as before, which is what makes
%% the change additive and leaves the CLI untouched.
an_empty_environment_changes_nothing_test() ->
    ?assertEqual(bs_run:read_arg("[1, 2]"), bs_run:read_arg("[1, 2]", #{})),
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("{ok,5}", #{"t" => 9})).

%% An Erlang term is still readable — the fallback that was removed was the
%% SILENT one, not this.
an_erlang_term_is_still_readable_test() ->
    ?assertEqual({ok, {ok, 5}}, bs_run:read_arg("{ok,5}")),
    ?assertEqual({ok, [1, 2]}, bs_run:read_arg("[1, 2]")).

%% The CLI reports it rather than crashing inside the function.
the_cli_reports_an_unreadable_argument_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            with_src("shop.bs", shop_src(), fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path ++ " Pay 'Order{Id = 1}'"),
                ?assert(string:find(R, "record construction is not available")
                        =/= nomatch),
                ?assertEqual(nomatch, string:find(R, "badmap"))
            end)
    end.

%%% ---------------------------------------------------------------------------
%%% The map partition's own laws.
%%%
%%% Tested directly rather than at the boundary for the reason the header gives:
%%% the algebra has no boundary to be reached through. These are the properties
%%% ticket 20's exactness rests on, at the fifth constructor.
%%% ---------------------------------------------------------------------------

rec(Tag, Fields) ->
    bs_types:map_closed(Fields#{'Kind' => bs_types:atom_lit(Tag)}).

pat(Fields) -> bs_types:map_open(Fields).

%% A closed record minus a pattern naming only its tag is EMPTY — this is what
%% makes one clause cover a whole record.
a_tag_pattern_covers_the_whole_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, P))).

%% ...and leaves the OTHER record untouched, which is what makes the residual
%% name the case you missed rather than an empty set.
a_tag_pattern_leaves_the_other_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    Doc = bs_types:union(Order, Invoice),
    P = pat(#{'Kind' => bs_types:atom_lit('Shop.Order')}),
    ?assertEqual("{ Kind: :'Shop.Invoice' }",
                 bs_types:to_pattern(bs_types:subtract(Doc, P))).

%% Union is exact — the two members do NOT collapse into one wider map. This is
%% the property ticket 20 exists to guarantee, at the new partition.
a_union_of_two_records_keeps_both_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    Invoice = rec('Shop.Invoice', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(Order, Invoice),
    ?assertEqual(2, length(Members)).

%% Two records over identical field sets with the same tag ARE one type, so the
%% union absorbs to a single member. F3.2's algebra half.
the_same_tag_absorbs_to_one_member_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int()}),
    #{maps := Members} = bs_types:union(A, B),
    ?assertEqual(1, length(Members)).

%% Different field sets are disjoint when both sides fix their domain, so
%% subtracting one from the other removes nothing.
different_field_sets_are_disjoint_test() ->
    A = rec('Shop.Order', #{'Id' => bs_types:int()}),
    B = rec('Shop.Order', #{'Id' => bs_types:int(), 'Total' => bs_types:int()}),
    ?assertEqual(A, bs_types:subtract(A, B)).

%% A catch-all removes every map, because `term` contains the map top and
%% `anything \ top` is empty. Without this, `_` would not close a record union.
a_catch_all_covers_every_record_test() ->
    Order = rec('Shop.Order', #{'Id' => bs_types:int()}),
    ?assert(bs_types:is_none(bs_types:subtract(Order, bs_types:term()))).

%% A guard over a record field still credits its clause. Written because the
%% obvious implementation — treating a field as unaddressable, the way a list
%% element is — makes `refine_all/3` credit NOTHING, so a record pattern plus a
%% guard would report inexhaustive. Routed through the checker, not the algebra.
a_guard_over_a_record_field_still_credits_the_clause_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "atom Band(Order o)\n"
          "Band({ Total: t }) when t > 0 -> :paid\n"
          "Band({ Total: t }) when t <= 0 -> :unpaid\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% F5 — the body check site. Ticket 33.
%%%
%%% Five obligation sites, every one of them a place a type was already
%%% declared. Three of the tests below assert scenarios F3 wrote down with their
%%% ids RESERVED and could not run, because F3 had no body check to raise them
%%% from: F3.3's call-site enforcement, F3.8's projection error, and F3.10.
%%% ---------------------------------------------------------------------------

errors(Src) ->
    {error, Diags} = check_only(Src),
    [D || D <- Diags, element(1, D) =:= error].

docs_src() ->
    "module Shop\n"
    "record Order   { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "Order Update(Order o)\n"
    "Update(o) -> o with { Total = 0 }\n".

%% F5.1 — site 4. Without it beam-sharp emits a `-spec` claiming what its own
%% body does not deliver, which is the defect ticket 18 measured in Gleam.
a_body_must_produce_the_declared_return_type_test() ->
    Src = "module M\nint Answer(int n)\nAnswer(n) -> :oops\n",
    ?assertMatch([{error, _, 'Answer', {return_not_declared, _}}], errors(Src)).

a_body_producing_the_declared_type_compiles_test() ->
    Src = "module M\natom Answer(int n)\nAnswer(n) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.2 — site 1, and F3.3's deferred half: ticket 26 §1's requirement as David
%% phrased it. F3 established aggregate identity in the algebra and had nowhere
%% to enforce it.
a_call_rejects_the_wrong_record_test() ->
    Src = docs_src() ++
          "Order Wrong(Invoice i)\n"
          "Wrong(i) -> Update(i)\n",
    ?assertMatch([{error, _, 'Wrong', {arg_not_accepted, 'Update', 1, _, _}}],
                 errors(Src)).

a_call_with_the_right_record_compiles_test() ->
    Src = docs_src() ++
          "Order Right(Order o)\n"
          "Right(o) -> Update(o)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.3 — the residual IS the clause the caller must write, and it proposes an
%% edit to the function being checked rather than to the callee: ticket 18 §4's
%% function-local rule showing up in a diagnostic.
the_call_site_residual_is_the_callers_clause_head_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = docs_src() ++
                  "Order Wrong(Invoice i)\n"
                  "Wrong(i) -> Update(i)\n",
            with_src("callsite.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                ?assert(string:find(R, "Wrong({ Kind: :'Shop.Invoice' }) -> ...")
                        =/= nomatch),
                %% Never a suggestion to widen the callee.
                ?assertEqual(nomatch, string:find(R, "Update({"))
            end)
    end.

%% F5.4 — site 2, and F3.10: the single largest hole F3 shipped with. A body
%% could build a map wearing an `Order` tag without `Order`'s fields.
construction_must_supply_every_declared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', ['Total'], []}}],
                 errors(Src)).

construction_may_not_supply_an_undeclared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n, Extra = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', [], ['Extra']}}],
                 errors(Src)).

construction_with_the_exact_field_set_compiles_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n }\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.5 — site 3, and F3.8's deferred sentence. The residual IS the member that
%% lacks the field, so the fix — discriminate on the tag first — is handed back
%% rather than described.
projecting_a_field_one_member_lacks_names_that_member_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Note  { Id: int }\n"
          "type Doc = Order | Note\n"
          "int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    [{error, _, 'Amount', {field_absent, 'Total', Residual}}] = errors(Src),
    ?assertEqual("{ Kind: :'Shop.Note' }",
                 lists:flatten(bs_types:to_pattern(Residual))).

%% F3.8's live half, unchanged: legal where every member carries the field.
projecting_a_field_every_member_carries_compiles_test() ->
    Src = "module Shop\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.6 — a body variable's type comes from the clause's REFINED DOMAIN, so an
%% earlier clause narrows a later body with nothing written. Ticket 08's
%% "narrowing is always written" falling out: the earlier clause head IS the
%% narrowing.
narrow_src(Clauses) ->
    "module Narrow\n"
    "type Flag = :on | :off\n"
    "atom Only(:on f)\n"
    "Only(f) -> :ok\n"
    "atom Run(Flag f)\n" ++ Clauses.

an_earlier_clause_narrows_a_later_body_test() ->
    ?assertMatch({ok, _, _},
                 check_only(narrow_src("Run(:off) -> :no\nRun(f) -> Only(f)\n"))).

%% The control, and it is the load-bearing half: without the earlier clause the
%% same body is an error, so the narrowing is the residual's contribution and
%% not the pattern's.
without_the_earlier_clause_the_same_body_is_an_error_test() ->
    ?assertMatch([{error, _, 'Run', {arg_not_accepted, 'Only', 1, _, _}} | _],
                 errors(narrow_src("Run(f) -> Only(f)\n"))).

%% F5.7 — the domain is `Possible`, never `Certain`. An untranslatable guard
%% makes `Certain` none, and a body typed against none does not fail loudly: it
%% silently stops checking, because every containment over none passes. So this
%% asserts an error that the WRONG build omits.
an_untranslatable_guard_leaves_the_body_typed_test() ->
    Src = "module Guarded\n"
          "atom Weird(int n)\n"
          "Weird(n) -> :yes\n"
          "atom Classify(int n)\n"
          "Classify(n) when Weird(n) -> n.Total\n"
          "Classify(n)               -> :other\n",
    ?assertMatch([{error, _, 'Classify', {field_absent, 'Total', _}}], errors(Src)).

%% F5.8 — ticket 32 dissolved the foreign case. `collect/1` excludes foreign
%% declarations by design, which is right for clause checking and wrong for a
%% callee environment, so this fails if the env is built from signatures alone.
a_foreign_callee_is_checked_like_any_other_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "int Bad(atom a)\n"
          "Bad(a) -> :lists.sum(a)\n",
    ?assertMatch([{error, _, 'Bad', {arg_not_accepted, _, 1, _, _}}], errors(Src)).

a_foreign_call_with_the_declared_type_compiles_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "int Good(list<int> xs)\n"
          "Good(xs) -> :lists.sum(xs)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.9 — a binding declares no type, so it is synthesis only. `t : int` has to
%% come from somewhere it did not before.
a_binding_carries_its_type_into_the_rest_of_the_body_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "atom Wrong(Order o)\n"
          "Wrong(o) ->\n"
          "    t = o.Total\n"
          "    t\n",
    ?assertMatch([{error, _, 'Wrong', {return_not_declared, _}}], errors(Src)).

%% F5.10 — site 5, the destructuring bind ticket 34 deferred here rather than
%% refusing. Provably irrefutable IFF the residual is empty.
a_destructuring_bind_that_cannot_fail_runs_test() ->
    Src = "module Pairs\n"
          "int Sum((int, int) pair)\n"
          "Sum(pair) ->\n"
          "    (a, b) = pair\n"
          "    a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

a_destructuring_bind_that_can_fail_is_an_error_test() ->
    Src = "module Pairs\n"
          "type Thing = (int, int) | :nothing\n"
          "atom Sum(Thing thing)\n"
          "Sum(thing) ->\n"
          "    (a, b) = thing\n"
          "    :done\n",
    [{error, _, 'Sum', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual(":nothing", lists:flatten(bs_types:to_pattern(Residual))).

%% A plain `x = e` still produces ticket 34's node, so nothing downstream of the
%% parser learns a new shape for the case that already worked.
a_plain_binding_still_parses_as_a_name_test() ->
    {ok, Toks, _} = bs_lexer:string("module M\nint F(int a)\nF(a) ->\n    t = 1\n    t\n"),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertMatch([{clause, _, 'F', _, _, {e_block, _, [{bind, _, t, _}], _}}],
                 [D || D = {clause, _, _, _, _, _} <- Decls]).

%% F5.11 — `_` is an expression only so that `(a, _) = pair` parses. As a value
%% it is rejected here, not by erlc against a file the author did not write.
a_wildcard_may_stand_on_the_left_of_a_bind_test() ->
    Src = "module Pairs\n"
          "int First((int, int) pair)\n"
          "First(pair) ->\n"
          "    (a, _) = pair\n"
          "    a\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(3, M:'First'({3, 4})).

a_wildcard_used_as_a_value_is_an_error_test() ->
    Src = "module M\nint Bad(int n)\nBad(n) -> _\n",
    ?assertMatch([{error, _, 'Bad', wildcard_as_value}], errors(Src)).

%% A guard is not typed — no site is a guard — but `_` in one is the same
%% authoring mistake, and it is a hole F5's own grammar opened: before `_` was an
%% expression this did not parse. Left alone it reached `bs_emit:expr/2` as a
%% function-clause CRASH, which is worse than the erlc error F4.7 prevents.
a_wildcard_in_a_guard_is_an_error_not_a_crash_test() ->
    Src = "module M\natom F(int n)\nF(n) when _ > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', wildcard_as_value}], errors(Src)).

%% The same gap for names, which predates F5 and was the one place F4's rule was
%% false: `variable 'X' is unbound` from erlc, against a file nobody wrote.
an_unbound_name_in_a_guard_is_caught_by_bsc_test() ->
    Src = "module M\natom F(int n)\nF(n) when x > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', {unbound_variable, x}}], errors(Src)).

%% ...and a guard calling a user function still names only its ARGUMENTS, so the
%% callee is not mistaken for an unbound variable.
a_guard_calling_a_function_is_not_an_unbound_name_test() ->
    Src = "module M\n"
          "atom Weird(int n)\n"
          "Weird(n) -> :yes\n"
          "atom F(int n)\n"
          "F(n) when Weird(n) -> :yes\n"
          "F(n)               -> :no\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% Everything else on the left of `=` is a parse error naming what belongs
%% there, rather than an obscure failure further down.
a_non_pattern_on_the_left_of_a_bind_is_rejected_test() ->
    {ok, Toks, _} = bs_lexer:string(
                      "module M\nint F(int a)\nF(a) ->\n    a + 1 = 2\n    a\n"),
    ?assertMatch({error, {_, _, _}}, bs_parser:parse(Toks)).

%% F5.12 — same lookup as site 1. Without it the author meets
%% `function 'Nope'/1 undefined` against an emitted file they never wrote.
a_call_to_an_undeclared_name_is_caught_by_bsc_test() ->
    Src = "module M\nint F(int n)\nF(n) -> Nope(n)\n",
    ?assertMatch([{error, _, 'F', {unknown_callee, 'Nope', 1}}], errors(Src)).

a_call_with_the_wrong_arity_is_caught_by_bsc_test() ->
    Src = "module M\nint F(int n)\nF(n) -> F(n, n)\n",
    ?assertMatch([{error, _, 'F', {arity_mismatch, 'F', 2, 1}}], errors(Src)).

%% F5.13 — the corpus. F5 adds four new ways to be rejected, and the README's
%% own rule is that a capability which closes a residual must not make
%% previously-valid programs invalid. This is the gate that was run before any
%% rejection test above was written.
every_example_still_compiles_test() ->
    Dir = project_root() ++ "/examples",
    {ok, Names} = file:list_dir(Dir),
    Sources = [filename:join(Dir, N) || N <- lists:sort(Names),
                                        filename:extension(N) =:= ".bs"],
    ?assert(length(Sources) >= 6),
    [?assertMatch({N, {ok, _}}, {N, bsc:file_to_dir(N, ?OUT)}) || N <- Sources].

%% A list element is bound at a REAL path now, because the body check has to
%% read `rest` back out and answer `list<int>`. Answering `term` rejects this —
%% a shipped example, with a checker working correctly on wrong information.
a_list_tail_keeps_its_element_type_in_a_body_test() ->
    Src = "module L\n"
          "list<int> Reverse(list<int> xs, list<int> acc)\n"
          "Reverse([], acc)          -> acc\n"
          "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% ...and the guard side is exactly as conservative as it was: a path through a
%% list step is unrefinable, so this stays inexhaustive rather than silently
%% becoming exhaustive on an address the algebra cannot narrow.
a_guard_over_a_list_element_still_credits_nothing_test() ->
    Src = "module L\n"
          "atom Sign(list<int> xs)\n"
          "Sign([])             -> :empty\n"
          "Sign([x, ..r]) when x > 0  -> :positive\n"
          "Sign([x, ..r]) when x <= 0 -> :nonpositive\n",
    ?assertMatch([{error, _, 'Sign', {inexhaustive, _}}], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F6 — angle brackets and parametric types
%%%
%%% Ticket 27 §(a) and §(b) only. §(c) — polymorphic function SIGNATURES — is
%%% not built, and the ticket's own "the costs are asymmetric and they do not
%%% chain" is why that is a cut rather than a shortfall. Everything below is
%%% substitution with ground arguments: the variable is gone before `bs_types`
%%% sees anything, so no test here reaches into the algebra for a new node,
%%% because there isn't one.
%%% ---------------------------------------------------------------------------

parcel_src() ->
    "module Parcel\n"
    "type Weighed = result<int, atom>\n"
    "atom Grade(Weighed w)\n"
    "Grade((:error, e))     -> e\n"
    "Grade(n) when n > 1000 -> :heavy\n"
    "Grade(n)               -> :light\n".

%% F6.1 — a two-argument bracket parses, resolves, and dispatches. Both arms
%% run, which is what says `result<int, atom>` became `int | (:error, atom)`
%% rather than a type the checker merely accepted.
a_two_argument_bracket_dispatches_test() ->
    M = build_and_load(parcel_src(), 'Parcel'),
    ?assertEqual(heavy,   M:'Grade'(1500)),
    ?assertEqual(light,   M:'Grade'(3)),
    ?assertEqual(timeout, M:'Grade'({error, timeout})).

%% F6.1's control. Drop the arms that cover the payload and the residual is the
%% payload — so the expansion reaches the exhaustiveness check, and the residual
%% printer needs nothing new to talk about a bracket.
%%
%% Note which arm is dropped: a bare variable covers the whole union, so
%% deleting the `(:error, e)` clause proves nothing. The check is real only
%% against the clause that does not.
the_residual_of_a_bracket_is_its_payload_test() ->
    Src = "module Parcel\n"
          "type Weighed = result<int, atom>\n"
          "atom Grade(Weighed w)\n"
          "Grade((:error, e)) -> e\n",
    ?assertMatch([{error, _, 'Grade', {inexhaustive, _}}], errors(Src)).

%% F6.2 — ticket 26 §4 says there are no absent fields, and `option<T>` is what
%% that costs a field. Until F6 the compiler could not let anyone obey the rule.
an_option_field_is_declarable_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Notes: option<int> }\n"
          "atom Describe(Order o)\n"
          "Describe({ Notes: :nothing }) -> :bare\n"
          "Describe(o)                   -> :annotated\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.3 — THE scenario that distinguishes expansion from a second constructor.
%% If `option<int>` were a node the algebra knew about, these two would be
%% different types and the call site would reject. Ticket 27 §(b): the variable
%% is gone before the algebra sees anything, so they are one type.
an_option_and_its_spelling_are_one_type_test() ->
    Src = "module Same\n"
          "type Spelled = int | :nothing\n"
          "atom Take(option<int> o)\n"
          "Take(:nothing) -> :none\n"
          "Take(n)        -> :some\n"
          "atom Hand(Spelled s)\n"
          "Hand(s) -> Take(s)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.4 — a user's own parametric alias. PascalCase, because a user type is
%% PascalCase and lowercase is the prelude's namespace.
a_user_parametric_alias_runs_test() ->
    Src = "module Pairs\n"
          "type Pair<T> = (T, T)\n"
          "int Sum(Pair<int> p)\n"
          "Sum((a, b)) -> a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

%% F6.5 — nesting. Ticket 28 §4 found `>>` is not a token, so this parses; and
%% it recorded the finding as OWED when binaries land, because ticket 20's
%% `<<_:M, _:_*N>>` needs `>>` as a delimiter and meets it at these two
%% characters. Pinned here so F8 trips an existing test instead of discovering
%% the collision.
nested_generics_parse_because_there_is_no_shift_operator_test() ->
    Src = "module Nest\n"
          "int Depth(list<list<int>> xss)\n"
          "Depth([])        -> 0\n"
          "Depth([xs, ..r]) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.6 — a bracket the compiler KNOWS at the wrong arity is a different mistake
%% from one it does not know, and it needs a different edit to fix.
a_bracket_at_the_wrong_arity_says_so_test() ->
    ?assertError({generic_arity, result, 2, 1},
                 check_only("module E\ntype B = result<int>\n"
                            "atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, option, 1, 2},
                 check_only("module E\ntype B = option<int, atom>\n"
                            "atom F(B b)\nF(b) -> :ok\n")),
    ?assertError({generic_arity, list, 1, 2},
                 check_only("module E\natom F(list<int, atom> xs)\nF(xs) -> :ok\n")).

%% A parametric name written without its bracket. `option` alone is not an
%% unknown type — it is a known one missing an argument, and the lowercase
%% (prelude) and PascalCase (user) halves reach that answer down different
%% resolver arms, so both are asserted.
a_parametric_name_without_its_bracket_says_so_test() ->
    ?assertError({needs_type_args, option, 1},
                 check_only("module E\natom F(option o)\nF(o) -> :ok\n")),
    ?assertError({needs_type_args, 'Pair', 1},
                 check_only("module E\ntype Pair<T> = (T, T)\n"
                            "atom F(Pair p)\nF(p) -> :ok\n")).

%% ...and its mirror: a bracket on a name that takes none.
a_bracket_on_a_ground_type_says_so_test() ->
    ?assertError({not_parametric, 'Plain'},
                 check_only("module E\ntype Plain = int\n"
                            "atom F(Plain<int> p)\nF(p) -> :ok\n")),
    ?assertError({unknown_generic, stack},
                 check_only("module E\natom F(stack<int> s)\nF(s) -> :ok\n")).

%% F6.7 — a type variable and a user type are the SAME token class (ticket 27
%% §4 forced declaration for exactly that reason), so nothing but the parameter
%% list tells them apart. `U` is therefore a type name, and there isn't one.
an_undeclared_variable_in_an_alias_body_is_caught_test() ->
    ?assertError({unknown_type, 'U'},
                 check_only("module E\ntype Wrong<T> = (T, U)\n"
                            "atom F(Wrong<int> w)\nF(w) -> :ok\n")).

%% F6.8 — the control for this one is not a red test, it is a HANG. Measured on
%% master before F6: `type A = B` / `type B = A` spins until killed, because
%% `type_env/1` resolved a reference by resolving whatever it found and its own
%% comment said the slice had no recursive aliases. A parameter is what makes a
%% recursive alias the natural thing to write, so the guard ships with F6.
%%
%% It REFUSES rather than implements: ticket 09 decided recursion is
%% equirecursive and contractive, and the algebra cannot hold one — the list
%% part is a pair of flags and a tuple is a finite product.
a_cyclic_alias_is_an_error_and_not_a_hang_test() ->
    ?assertError({cyclic_type, 'A'},
                 check_only("module E\ntype A = B\ntype B = A\n"
                            "atom F(A a)\nF(a) -> :ok\n")),
    ?assertError({cyclic_type, 'Tree'},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "atom F(Tree<int> t)\nF(t) -> :ok\n")).

%% ...and the same guard must not reject a name used twice as SIBLINGS. A
%% repeated application is not a cycle, and a chain that terminates is not one
%% either — the guard tracks the resolution path, not the set of names seen.
a_repeated_alias_is_not_a_cycle_test() ->
    Src = "module Twice\n"
          "type Pair<T> = (T, T)\n"
          "type Both = (Pair<int>, Pair<atom>)\n"
          "type Deep = Pair<Pair<int>>\n"
          "atom F(Both b, Deep d)\n"
          "F(b, d) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.9 — F6 puts `<` and `>` around a comma-separated list in TYPE position for
%% the first time. This is the scenario that says the expression grammar did not
%% learn it: ticket 28's `F(a < b, c > d)` is two comparisons, and ticket 08's
%% guard shape still parses.
%%
%% The conflict count is NOT the check. 28a's own header records that yecc
%% resolves shift/reduce conflicts silently through the precedence table — every
%% one of its four variants reported zero conflicts, including the variant that
%% read the ambiguous case wrong. So this asserts the parse.
angle_brackets_did_not_reach_value_position_test() ->
    M = build_and_load("module Cmp\n"
                       "bool Both(int a, int b, int c, int d)\n"
                       "Both(a, b, c, d) -> a < b && c > d\n", 'Cmp'),
    ?assertEqual(true,  M:'Both'(1, 2, 5, 3)),
    ?assertEqual(false, M:'Both'(1, 2, 3, 5)).

%% Ticket 08's own example, which ticket 28 §3 ran through four patched grammar
%% variants. Run here against the real one, now that the real one has brackets.
a_guard_with_comparisons_still_parses_test() ->
    Src = "module G\n"
          "int Total(int x)\n"
          "Total(x) -> x\n"
          "atom Cmp((int, int) p)\n"
          "Cmp((x, y)) when x < y && Total(x) > 0 -> :yes\n"
          "Cmp(p)                                 -> :no\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F6.10 — the expansion is already ground, so ticket 13 §6 has nothing to widen
%% and the spec is exact. This is also why 27 §6's finding (a polymorphic -spec
%% is inert under Dialyzer) does not arrive with F6: it emits no polymorphic
%% spec, because it builds no polymorphic function.
the_emitted_spec_is_the_expanded_ground_type_test() ->
    {ok, _} = compile("module Opt\n"
                      "option<int> Keep(option<int> o)\n"
                      "Keep(o) -> o\n"),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Opt.beam", [abstract_code]),
    [Spec] = [S || S = {attribute, _, spec, _} <- Forms],
    Printed = lists:flatten(erl_pp:attribute(Spec)),
    ?assert(string:find(Printed, "integer()") =/= nomatch),
    ?assert(string:find(Printed, "nothing") =/= nomatch),
    %% Nothing parametric survives into what is published.
    ?assertEqual(nomatch, string:find(Printed, "option")).

%%% ---------------------------------------------------------------------------
%%% Every shipped surface form is demonstrated by a program that runs
%%%
%%% Asked for on 2026-08-14, after F6, by David: *"are there actual example bs
%%% files showing all the language capabilities as they are built?"* Measured,
%%% and the answer was no — record CONSTRUCTION, destructuring binds, `bool` and
%%% a user-declared parametric alias had all shipped with tests and no example.
%%% Construction is the sharpest of those: `shop.bs` demonstrated every record
%%% operation except building one.
%%%
%%% WHAT THIS CHECKS, AND WHAT IT DOES NOT
%%% It checks the CORPUS, not the compiler. Paired with
%%% `every_example_still_compiles_test` above it means: every surface form below
%%% appears in a file that compiles and runs. It cannot check a capability whose
%%% whole behaviour is a REJECTION — every example must compile, so the call-site
%%% check, the projection error and exact field sets are covered by tests up
%%% there and can never be covered down here. That split is the reason the
%%% language has three gated surfaces rather than one: examples must run,
%%% LANGUAGE.md's blocks must compile (or must not, if tagged `not-yet`), and the
%%% suite carries what only a rejection can show.
%%%
%%% THE LIST IS HAND-MAINTAINED, DELIBERATELY
%%% There is no way to derive it: a capability is a sentence about the language
%%% and a probe is a token, and only a person can say which token demonstrates
%%% which sentence. The cost is one row per feature; the point is that the row
%%% has to be written, so a capability cannot ship with nothing to look at.
%%% ---------------------------------------------------------------------------

%% {what it demonstrates, a regex that finds it}. Anchored on distinctive
%% tokens, so a probe fails loudly rather than matching something adjacent.
demonstrated_surface() ->
    [{"a module declaration",                    "^module "},
     {"a type alias",                            "^type [A-Z]"},
     {"a union in a type",                       "^type .*\\|"},
     {"a user-declared parametric alias",        "^type [A-Z][A-Za-z]*<"},
     {"a parametric type applied",               "<int"},
     {"a record declaration",                    "^record "},
     %% A declaration has a space before its brace (`record Order   { Id`) and a
     %% construction does not (`Order{ Id = ...`), which is what tells them apart.
     {"record construction",                     "[A-Za-z]\\{"},
     {"a width-preserving update",               " with \\{"},
     {"a field projection",                      "\\.[A-Z]"},
     {"a tag or property pattern",               "\\{ [A-Z][A-Za-z]*:"},
     {"a guard",                                 " when "},
     {"a conjunction in a guard",                "&&"},
     {"an empty-list pattern",                   "\\[\\]"},
     {"a list pattern with a rest",              "\\[[a-z]+, \\.\\."},
     {"a local binding",                         "^ +[a-z][A-Za-z]* = "},
     {"a destructuring bind",                    "^ +\\([a-z]"},
     {"a foreign module declaration",            "^using :"},
     {"a foreign call",                          ":[a-z]+\\.[a-z_]+\\("},
     {"an OTP behaviour",                        "^behaviour "},
     {"bool as a declared type",                 "^bool "},
     {"an atom literal",                         ":[a-z]"}].

every_shipped_surface_form_has_an_example_test() ->
    Dir = project_root() ++ "/examples",
    {ok, Names} = file:list_dir(Dir),
    Corpus =
        [begin
             {ok, Bin} = file:read_file(filename:join(Dir, N)),
             %% Comments are stripped, so a form mentioned in prose does not
             %% count as demonstrated. Several of these files DISCUSS what they
             %% do not do.
             Lines = [L || L <- string:split(binary_to_list(Bin), "\n", all),
                           not lists:prefix("//", string:trim(L, leading))],
             string:join(Lines, "\n")
         end || N <- lists:sort(Names), filename:extension(N) =:= ".bs"],
    Text = string:join(Corpus, "\n"),
    Missing = [What || {What, Re} <- demonstrated_surface(),
                       re:run(Text, Re, [multiline, {capture, none}]) =:= nomatch],
    %% Named rather than counted: the failure has to say which capability nobody
    %% can look at, or it is a puzzle rather than a diagnostic.
    ?assertEqual([], Missing).

%% ...and the mirror, which is the half that rots silently. A probe matching
%% nothing would be caught above; a probe that no longer means what it says
%% would not, so the two most delicate ones are pinned against text that must
%% NOT match them.
the_construction_probe_does_not_match_a_declaration_test() ->
    ?assertEqual(nomatch,
                 re:run("record Order   { Id: int }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("New(id) -> Order{ Id = id }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])).

%% eunit runs from _build/test/lib/bsc, so walk back to the project.
project_root() ->
    filename:join(lists:takewhile(fun(C) -> C =/= "_build" end,
                                  filename:split(element(2, file:get_cwd())))).
